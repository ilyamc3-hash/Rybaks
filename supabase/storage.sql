-- ============================================================
-- Supabase Storage: политики для бакетов avatars / chat-photos /
-- listing-photos. Выполнить в SQL Editor проекта Supabase.
--
-- Про SELECT-политики. Все три бакета публичные (buckets.public = true),
-- поэтому ПОКАЗ файлов (в т.ч. чужих аватаров/фото) идёт по прямому URL
-- /storage/v1/object/public/... и RLS не затрагивает. Но SELECT-политика
-- на storage.objects всё равно НУЖНА: Storage API при загрузке делает
-- INSERT ... RETURNING *, и без SELECT-политики, покрывающей новую
-- строку, запрос падает с 403 "new row violates row-level security
-- policy" (для avatars это ещё и upsert → та же история с UPDATE).
--
-- Чтобы при этом клиент не мог через Storage API .list() перечислить
-- ЧУЖИЕ файлы (предупреждение дашборда "Clients can list all files"),
-- SELECT-политику ограничиваем владельцем: первый сегмент пути
-- "<user_id>/..." должен совпадать с auth.uid().
-- ============================================================

-- ---------- avatars ----------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Ранняя версия скрипта заводила бакет-широкую политику чтения — снимаем.
drop policy if exists "Аватары доступны всем на чтение" on storage.objects;

-- Владелец читает метаданные только своих файлов (нужно для upload
-- RETURNING и для .list() своей папки).
drop policy if exists "Владелец читает свой аватар" on storage.objects;
create policy "Владелец читает свой аватар" on storage.objects
  for select using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Пользователь загружает/меняет/удаляет только файлы в своей папке —
-- приложение сохраняет аватар по пути "<user_id>/avatar".
drop policy if exists "Пользователь загружает только свой аватар" on storage.objects;
create policy "Пользователь загружает только свой аватар" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Пользователь обновляет только свой аватар" on storage.objects;
create policy "Пользователь обновляет только свой аватар" on storage.objects
  for update using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Пользователь удаляет только свой аватар" on storage.objects;
create policy "Пользователь удаляет только свой аватар" on storage.objects
  for delete using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ---------- chat-photos ----------
insert into storage.buckets (id, name, public)
values ('chat-photos', 'chat-photos', true)
on conflict (id) do nothing;

drop policy if exists "Фото чата доступны всем на чтение" on storage.objects;

drop policy if exists "Владелец читает свои фото чата" on storage.objects;
create policy "Владелец читает свои фото чата" on storage.objects
  for select using (
    bucket_id = 'chat-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Пользователь загружает фото только в свою папку — приложение сохраняет
-- фото по пути "<user_id>/<region_id>-<timestamp>.jpg". Обновление и
-- удаление не нужны: у каждой отправки фото свой уникальный путь.
drop policy if exists "Пользователь загружает фото чата только в свою папку" on storage.objects;
create policy "Пользователь загружает фото чата только в свою папку" on storage.objects
  for insert with check (
    bucket_id = 'chat-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ---------- listing-photos ----------
insert into storage.buckets (id, name, public)
values ('listing-photos', 'listing-photos', true)
on conflict (id) do nothing;

drop policy if exists "Фото объявлений доступны всем на чтение" on storage.objects;

drop policy if exists "Владелец читает свои фото объявлений" on storage.objects;
create policy "Владелец читает свои фото объявлений" on storage.objects
  for select using (
    bucket_id = 'listing-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Пользователь загружает фото только в свою папку — приложение сохраняет
-- фото по пути "<user_id>/<timestamp>.jpg".
drop policy if exists "Пользователь загружает фото объявления только в свою папку" on storage.objects;
create policy "Пользователь загружает фото объявления только в свою папку" on storage.objects
  for insert with check (
    bucket_id = 'listing-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Автор может удалить фото своих объявлений (при удалении объявления).
drop policy if exists "Пользователь удаляет фото только своих объявлений" on storage.objects;
create policy "Пользователь удаляет фото только своих объявлений" on storage.objects
  for delete using (
    bucket_id = 'listing-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
