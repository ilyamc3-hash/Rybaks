-- ============================================================
-- Инкрементальная миграция: «Каталог» (products) → «Барахолка» (listings).
--
-- Нужна ТОЛЬКО если вы уже выполняли старую версию schema.sql с таблицей
-- products. Если БД ещё чистая — просто выполните supabase/all.sql,
-- в нём таблица listings уже описана.
--
-- Выполнить в SQL Editor проекта Supabase. Идемпотентно.
-- ============================================================

-- 1. Убираем старую витрину каталога (в новой модели её нет).
drop table if exists products cascade;

-- 2. Объявления барахолки.
create table if not exists listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references users (id) on delete cascade,
  region_id uuid not null references regions (id) on delete cascade,
  title text not null,
  description text,
  price numeric(10, 2) check (price is null or price >= 0),
  photo_url text,
  status text not null default 'active'
    check (status in ('active', 'sold', 'archived')),
  created_at timestamptz not null default now()
);

create index if not exists listings_region_status_created_idx
  on listings (region_id, status, created_at desc);
create index if not exists listings_seller_id_idx on listings (seller_id);

alter table listings enable row level security;

drop policy if exists "Объявления барахолки видны всем" on listings;
create policy "Объявления барахолки видны всем" on listings
  for select using (true);

drop policy if exists "Автор создаёт объявление от своего имени" on listings;
create policy "Автор создаёт объявление от своего имени" on listings
  for insert with check (auth.uid() = seller_id);

drop policy if exists "Автор редактирует только свои объявления" on listings;
create policy "Автор редактирует только свои объявления" on listings
  for update using (auth.uid() = seller_id);

drop policy if exists "Автор удаляет только свои объявления" on listings;
create policy "Автор удаляет только свои объявления" on listings
  for delete using (auth.uid() = seller_id);

-- 3. Бакет Storage для фото объявлений.
insert into storage.buckets (id, name, public)
values ('listing-photos', 'listing-photos', true)
on conflict (id) do nothing;

-- Бакет публичный: показ фото идёт по прямому URL без RLS. Но
-- SELECT-политика нужна для upload (INSERT ... RETURNING *), иначе 403
-- "new row violates row-level security policy". Ограничиваем владельцем,
-- чтобы через .list() нельзя было перечислить чужие файлы.
drop policy if exists "Фото объявлений доступны всем на чтение" on storage.objects;

drop policy if exists "Владелец читает свои фото объявлений" on storage.objects;
create policy "Владелец читает свои фото объявлений" on storage.objects
  for select using (
    bucket_id = 'listing-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Пользователь загружает фото объявления только в свою папку" on storage.objects;
create policy "Пользователь загружает фото объявления только в свою папку" on storage.objects
  for insert with check (
    bucket_id = 'listing-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Пользователь удаляет фото только своих объявлений" on storage.objects;
create policy "Пользователь удаляет фото только своих объявлений" on storage.objects
  for delete using (
    bucket_id = 'listing-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );
