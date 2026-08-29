-- ============================================================
-- Схема базы данных для приложения "Клёв" (чат + маркетплейс)
-- Выполнить в SQL Editor проекта Supabase.
--
-- Авторизация по SMS настраивается отдельно в дашборде:
-- Authentication -> Providers -> Phone -> включить провайдера
-- и подключить SMS-провайдера (Twilio / MessageBird / Vonage и т.д.).
-- Это настройка проекта, а не SQL, поэтому в скрипте её нет.
-- ============================================================

-- Регионы: точки входа в приложение, у каждого региона свой чат.
create table if not exists regions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

-- Профили пользователей. Дополняют встроенную таблицу auth.users,
-- в которой Supabase уже хранит номер телефона после SMS-входа.
create table if not exists users (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text not null,
  name text,
  avatar_url text,
  region_id uuid references regions (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Сообщения регионального чата.
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id) on delete cascade,
  author_id uuid not null references users (id) on delete cascade,
  text text,
  photo_url text,
  created_at timestamptz not null default now(),
  constraint message_has_content check (text is not null or photo_url is not null)
);

create index if not exists messages_region_id_created_at_idx
  on messages (region_id, created_at);

-- Товары каталога. seller_id опционален: seed-товары для разработки
-- (см. supabase/seed.sql) создаются без привязки к продавцу.
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid references users (id) on delete set null,
  region_id uuid references regions (id) on delete set null,
  title text not null,
  description text,
  price numeric(10, 2) not null check (price >= 0),
  image_url text,
  created_at timestamptz not null default now()
);

create index if not exists products_region_id_idx on products (region_id);

-- ============================================================
-- Row Level Security: включена на всех таблицах.
--
-- Чтение регионов/сообщений/товаров открыто всем, включая анонимных
-- клиентов — приложение разрешает просматривать регионы, чат и каталог
-- без входа по SMS (в т.ч. через локальный dev-режим входа, который не
-- создаёт настоящую сессию Supabase). Запись же требует настоящей
-- авторизованной сессии — dev-режим ничего не пишет в реальные таблицы.
-- ============================================================

alter table regions enable row level security;
alter table users enable row level security;
alter table messages enable row level security;
alter table products enable row level security;

create policy "Регионы доступны всем" on regions
  for select using (true);

create policy "Пользователь видит все профили" on users
  for select using (auth.role() = 'authenticated');

create policy "Пользователь редактирует только свой профиль" on users
  for update using (auth.uid() = id);

create policy "Пользователь создаёт свой профиль" on users
  for insert with check (auth.uid() = id);

create policy "Сообщения чата видны всем" on messages
  for select using (true);

create policy "Пользователь пишет сообщения от своего имени" on messages
  for insert with check (auth.uid() = author_id);

create policy "Товары каталога видны всем" on products
  for select using (true);

create policy "Пользователь управляет только своими товарами" on products
  for insert with check (auth.uid() = seller_id);

create policy "Пользователь редактирует только свои товары" on products
  for update using (auth.uid() = seller_id);

create policy "Пользователь удаляет только свои товары" on products
  for delete using (auth.uid() = seller_id);
