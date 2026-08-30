-- ============================================================
-- Фаза 1 личных сообщений в Барахолке: переписка покупателя с продавцом
-- по конкретному объявлению (в дополнение к «позвонить / скопировать
-- номер» в карточке объявления).
--
-- Отдельный файл миграции — как supabase/listings.sql. Выполнить в
-- SQL Editor проекта Supabase. Идемпотентно, можно повторно.
--
-- Региональный чат (таблица messages) НЕ затрагивается — это независимая
-- сущность: там плоский групповой чат по региону, здесь — приватный
-- диалог 1:1, привязанный к объявлению.
--
-- ВАЖНО про RLS. В схеме уже был прецедент, когда чтение профилей
-- (`users`, а с ними и номеров телефонов) было открыто всем
-- авторизованным (`using (auth.role() = 'authenticated')`). Здесь так
-- НЕ делаем: и треды, и сообщения видны строго участникам диалога
-- (`buyer_id` / `seller_id` = auth.uid()). Никакой политики вида
-- «виден всем авторизованным».
-- ============================================================

-- 1. Треды: один диалог на пару (объявление, покупатель). Продавец —
--    всегда владелец объявления на момент создания треда.
create table if not exists listing_threads (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings (id) on delete cascade,
  buyer_id uuid not null references users (id) on delete cascade,
  seller_id uuid not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- один тред на пару «объявление + покупатель»: повторное «Написать»
  -- по тому же объявлению должно открывать существующий диалог.
  constraint listing_thread_unique_buyer unique (listing_id, buyer_id),
  -- продавец не пишет сам себе по своему же объявлению.
  constraint listing_thread_distinct_parties check (buyer_id <> seller_id)
);

-- «Входящие» пользователя: его треды и как покупателя, и как продавца,
-- свежие сверху.
create index if not exists listing_threads_buyer_created_idx
  on listing_threads (buyer_id, created_at desc);
create index if not exists listing_threads_seller_created_idx
  on listing_threads (seller_id, created_at desc);
create index if not exists listing_threads_listing_idx
  on listing_threads (listing_id);

-- 2. Сообщения внутри треда. Как и в messages — обязателен хотя бы
--    text или photo_url. read_at — момент прочтения получателем (для
--    бейджа непрочитанных и, позже, для триггера push-уведомлений).
create table if not exists listing_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references listing_threads (id) on delete cascade,
  sender_id uuid not null references users (id) on delete cascade,
  text text,
  photo_url text,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint listing_message_has_content
    check (text is not null or photo_url is not null)
);

create index if not exists listing_messages_thread_created_idx
  on listing_messages (thread_id, created_at);
-- быстрый подсчёт непрочитанных по треду.
create index if not exists listing_messages_thread_unread_idx
  on listing_messages (thread_id) where read_at is null;

-- ============================================================
-- Row Level Security: доступ строго у участников диалога.
-- ============================================================

alter table listing_threads enable row level security;
alter table listing_messages enable row level security;

-- --- listing_threads ---------------------------------------------------

-- Видит тред только покупатель или продавец из этого треда.
drop policy if exists "Участник видит свои треды по объявлению" on listing_threads;
create policy "Участник видит свои треды по объявлению" on listing_threads
  for select using (auth.uid() = buyer_id or auth.uid() = seller_id);

-- Открыть тред может только покупатель (от своего имени), и только
-- с настоящим продавцом объявления. seller_id нельзя подставить
-- произвольный — он сверяется с listings.seller_id.
drop policy if exists "Покупатель открывает тред по объявлению" on listing_threads;
create policy "Покупатель открывает тред по объявлению" on listing_threads
  for insert with check (
    auth.uid() = buyer_id
    and buyer_id <> seller_id
    and seller_id = (select l.seller_id from listings l where l.id = listing_id)
  );

-- UPDATE/DELETE тредов на фазе 1 не нужны — политик нет, значит запрещено.

-- --- listing_messages ------------------------------------------------

-- Сообщения треда видны только его участникам.
drop policy if exists "Участник треда видит сообщения" on listing_messages;
create policy "Участник треда видит сообщения" on listing_messages
  for select using (
    exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

-- Отправить сообщение может только участник треда и только от своего
-- имени (sender_id = auth.uid()).
drop policy if exists "Участник треда пишет от своего имени" on listing_messages;
create policy "Участник треда пишет от своего имени" on listing_messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

-- Отметить сообщение прочитанным (проставить read_at) может только
-- получатель — то есть участник треда, который НЕ является отправителем
-- этого сообщения. Свои сообщения трогать нельзя.
drop policy if exists "Получатель отмечает сообщение прочитанным" on listing_messages;
create policy "Получатель отмечает сообщение прочитанным" on listing_messages
  for update using (
    sender_id <> auth.uid()
    and exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  )
  with check (
    sender_id <> auth.uid()
    and exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

-- ============================================================
-- Realtime: экран переписки подписывается на INSERT в listing_messages
-- по thread_id (см. lib/features/baraholka/providers/
-- listing_thread_provider.dart). То же самое можно включить в дашборде:
-- Database → Publications → supabase_realtime → добавить listing_messages.
-- ============================================================
do $$
begin
  execute 'alter publication supabase_realtime add table listing_messages';
exception
  when duplicate_object then null;  -- уже в публикации
  when undefined_object then null;  -- публикации нет (не-Supabase окружение)
end $$;

-- ============================================================
-- Storage: бакет для фото внутри переписки. Отдельно от listing-photos,
-- чтобы фото из личных диалогов не смешивались с фото витрины объявлений.
-- Путь файла: "<user_id>/<thread_id>-<timestamp>.jpg".
--
-- Бакет публичный: показ фото собеседнику идёт по прямому URL
-- (/storage/v1/object/public/thread-photos/...) в обход RLS. Но
-- SELECT-политика на storage.objects всё равно нужна — иначе upload
-- (INSERT ... RETURNING *) падает с 403 "new row violates row-level
-- security policy". Ограничиваем её владельцем: тогда через Storage API
-- .list() нельзя перечислить чужие файлы (иначе по путям
-- "<uid>/<thread_id>-..." было бы видно, кто с кем и по каким
-- объявлениям переписывается).
-- ============================================================

insert into storage.buckets (id, name, public)
values ('thread-photos', 'thread-photos', true)
on conflict (id) do nothing;

-- Первая версия миграции заводила бакет-широкую политику чтения
-- (дашборд предупреждал "Clients can list all files") — снимаем её.
drop policy if exists "Фото переписки доступны всем на чтение" on storage.objects;

drop policy if exists "Владелец читает свои фото переписки" on storage.objects;
create policy "Владелец читает свои фото переписки" on storage.objects
  for select using (
    bucket_id = 'thread-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Пользователь загружает фото переписки только в свою папку" on storage.objects;
create policy "Пользователь загружает фото переписки только в свою папку" on storage.objects
  for insert with check (
    bucket_id = 'thread-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
