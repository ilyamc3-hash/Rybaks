-- ============================================================
-- Схема базы данных для приложения "Клёв" (чат + барахолка)
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

-- Барахолка: объявления пользователей. Каждое объявление создаёт
-- авторизованный пользователь и привязано к его текущему региону —
-- список объявлений региона показывается на вкладке «Барахолка».
-- price опционально (объявления вида «куплю» могут быть без цены;
-- в приложении пустая цена показывается как «Цена договорная»).
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

-- Основной запрос вкладки: активные объявления региона, свежие сверху.
create index if not exists listings_region_status_created_idx
  on listings (region_id, status, created_at desc);

-- «Мои объявления» в профиле — выборка по автору.
create index if not exists listings_seller_id_idx on listings (seller_id);

-- ============================================================
-- Row Level Security: включена на всех таблицах.
--
-- Чтение регионов/сообщений/объявлений открыто всем, включая анонимных
-- клиентов — приложение разрешает просматривать регионы, чат и барахолку
-- без входа по SMS (в т.ч. через локальный dev-режим входа, который не
-- создаёт настоящую сессию Supabase). Запись же требует настоящей
-- авторизованной сессии — dev-режим ничего не пишет в реальные таблицы.
-- ============================================================

alter table regions enable row level security;
alter table users enable row level security;
alter table messages enable row level security;
alter table listings enable row level security;

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

create policy "Объявления барахолки видны всем" on listings
  for select using (true);

create policy "Автор создаёт объявление от своего имени" on listings
  for insert with check (auth.uid() = seller_id);

create policy "Автор редактирует только свои объявления" on listings
  for update using (auth.uid() = seller_id);

create policy "Автор удаляет только свои объявления" on listings
  for delete using (auth.uid() = seller_id);
