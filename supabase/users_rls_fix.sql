-- ============================================================
-- Фикс утечки телефонов из public.users.
--
-- Было: политика SELECT `using (auth.role() = 'authenticated')` —
-- любой залогиненный пользователь мог прочитать ВСЕ строки users,
-- включая чужие номера телефонов (проверено живым запросом к проду).
--
-- Стало: свою строку users видит только сам пользователь
-- (`auth.uid() = id`). Для показа имени/аватара продавца/собеседника/
-- автора сообщения — отдельное представление user_public_profiles
-- БЕЗ телефона.
--
-- Выполнить в SQL Editor проекта Supabase. Идемпотентно.
-- ============================================================

-- 1. Убираем «широкую» политику чтения профилей.
drop policy if exists "Пользователь видит все профили" on users;
drop policy if exists "Пользователь видит свой профиль" on users;
create policy "Пользователь видит свой профиль" on users
  for select using (auth.uid() = id);

-- 2. Публичный профиль без телефона — для embed-запросов
--    (seller/buyer/author) и точечной подгрузки автора в чате.
--
--    security_invoker = false (значение по умолчанию, указано явно —
--    от него зависит вся схема): представление выполняется с правами
--    владельца (postgres) и обходит RLS таблицы users, отдавая
--    ТОЛЬКО безопасные колонки. Телефона здесь нет вообще.
create or replace view public.user_public_profiles
  with (security_invoker = false) as
  select id, name, avatar_url, region_id, created_at
  from public.users;

grant select on public.user_public_profiles to authenticated, anon;
