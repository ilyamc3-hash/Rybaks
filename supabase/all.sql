-- Клёв: полная инициализация БД. Выполнять в SQL Editor проекта nwerzgirwbrfcbtdotlf.
-- Сгенерирован из schema.sql + seed.sql + storage.sql.

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


-- ============================================================
-- Seed-скрипт для локальной разработки/тестирования.
-- Выполнить в SQL Editor проекта Supabase ПОСЛЕ supabase/schema.sql.
-- Безопасно выполнять повторно — вставки идут через "where not exists"
-- (дублей не будет), обновления фото товаров идут через update по title.
-- ============================================================

-- На случай, если schema.sql уже выполнялся раньше в старой версии,
-- где seller_id был обязательным полем — снимаем ограничение, иначе
-- тестовые товары без владельца не вставятся.
alter table products alter column seller_id drop not null;

-- Регионы -------------------------------------------------------
-- Полный список 85 субъектов РФ (22 республики, 9 краёв, 46 областей,
-- 3 города федерального значения, 1 автономная область, 4 автономных
-- округа). Вставка идёт через "where not exists" по имени, поэтому
-- безопасно выполнять повторно и поверх уже существующих Москвы/СПб —
-- их описания не перезатрутся. Фактический порядок сортировки в
-- приложении задаёт запрос `.order('name', ascending: true)`
-- (lib/features/regions/providers/regions_provider.dart) — список ниже
-- просто перечислен в алфавитном порядке для удобства чтения/поддержки.
insert into regions (name, description)
select v.name, v.description
from (values
  ('Алтайский край', null),
  ('Амурская область', null),
  ('Архангельская область', null),
  ('Астраханская область', null),
  ('Белгородская область', null),
  ('Брянская область', null),
  ('Владимирская область', null),
  ('Волгоградская область', null),
  ('Вологодская область', null),
  ('Воронежская область', null),
  ('Еврейская автономная область', null),
  ('Забайкальский край', null),
  ('Ивановская область', null),
  ('Иркутская область', null),
  ('Кабардино-Балкарская Республика', null),
  ('Калининградская область', null),
  ('Калужская область', null),
  ('Камчатский край', null),
  ('Карачаево-Черкесская Республика', null),
  ('Кемеровская область (Кузбасс)', null),
  ('Кировская область', null),
  ('Костромская область', null),
  ('Краснодарский край', null),
  ('Красноярский край', null),
  ('Курганская область', null),
  ('Курская область', null),
  ('Ленинградская область', null),
  ('Липецкая область', null),
  ('Магаданская область', null),
  ('Москва', 'Московская область и ближайшие водоёмы'),
  ('Московская область', null),
  ('Мурманская область', null),
  ('Ненецкий автономный округ', null),
  ('Нижегородская область', null),
  ('Новгородская область', null),
  ('Новосибирская область', null),
  ('Омская область', null),
  ('Оренбургская область', null),
  ('Орловская область', null),
  ('Пензенская область', null),
  ('Пермский край', null),
  ('Приморский край', null),
  ('Псковская область', null),
  ('Республика Адыгея', null),
  ('Республика Алтай', null),
  ('Республика Башкортостан', null),
  ('Республика Бурятия', null),
  ('Республика Дагестан', null),
  ('Республика Ингушетия', null),
  ('Республика Калмыкия', null),
  ('Республика Карелия', null),
  ('Республика Коми', null),
  ('Республика Крым', null),
  ('Республика Марий Эл', null),
  ('Республика Мордовия', null),
  ('Республика Саха (Якутия)', null),
  ('Республика Северная Осетия — Алания', null),
  ('Республика Татарстан', null),
  ('Республика Тыва', null),
  ('Республика Хакасия', null),
  ('Ростовская область', null),
  ('Рязанская область', null),
  ('Самарская область', null),
  ('Санкт-Петербург', 'Финский залив, Ладога и Нева'),
  ('Саратовская область', null),
  ('Сахалинская область', null),
  ('Свердловская область', null),
  ('Севастополь', null),
  ('Смоленская область', null),
  ('Ставропольский край', null),
  ('Тамбовская область', null),
  ('Тверская область', null),
  ('Томская область', null),
  ('Тульская область', null),
  ('Тюменская область', null),
  ('Удмуртская Республика', null),
  ('Ульяновская область', null),
  ('Хабаровский край', null),
  ('Ханты-Мансийский автономный округ — Югра', null),
  ('Челябинская область', null),
  ('Чеченская Республика', null),
  ('Чувашская Республика', null),
  ('Чукотский автономный округ', null),
  ('Ямало-Ненецкий автономный округ', null),
  ('Ярославская область', null)
) as v(name, description)
where not exists (select 1 from regions r where r.name = v.name);

-- Товары каталога -------------------------------------------------
-- Фото — свободные (Wikimedia Commons, CC/public domain), проверены
-- вручную на тематическое соответствие товару.
--
-- Обновляем image_url у уже существующих строк (на случай, если seed.sql
-- уже запускался раньше со старыми, нетематичными фото) — только вставки
-- через "where not exists" этого не сделают.
update products set image_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/A_spinning_reel_on_a_rod.jpg/500px-A_spinning_reel_on_a_rod.jpg'
  where title = 'Спиннинг Shimano Catana';

update products set image_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Abu_reel.jpg/500px-Abu_reel.jpg'
  where title = 'Катушка Daiwa Legalis';

update products set image_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Angeln_zubehoer_wobbler_01.jpg/500px-Angeln_zubehoer_wobbler_01.jpg'
  where title = 'Набор воблеров (5 шт.)';

update products set image_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Fishfinder_display_showing_the_mark_at_Flash_Pinnacle_P7280213.jpg/500px-Fishfinder_display_showing_the_mark_at_Flash_Pinnacle_P7280213.jpg'
  where title = 'Эхолот Lucky FF718';

update products set image_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Zan%C4%99ta_na_ryby_%28Murowana_Goslina%29%2C_groundbait.jpg/500px-Zan%C4%99ta_na_ryby_%28Murowana_Goslina%29%2C_groundbait.jpg'
  where title = 'Прикормка Sensas 3000';

insert into products (title, description, price, image_url)
select 'Спиннинг Shimano Catana', 'Длина 2.1м, тест 5-21г', 3490,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/A_spinning_reel_on_a_rod.jpg/500px-A_spinning_reel_on_a_rod.jpg'
where not exists (select 1 from products where title = 'Спиннинг Shimano Catana');

insert into products (title, description, price, image_url)
select 'Катушка Daiwa Legalis', 'Безынерционная, 2500 размер', 5200,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Abu_reel.jpg/500px-Abu_reel.jpg'
where not exists (select 1 from products where title = 'Катушка Daiwa Legalis');

insert into products (title, description, price, image_url)
select 'Набор воблеров (5 шт.)', 'Для ловли щуки и окуня', 1750,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Angeln_zubehoer_wobbler_01.jpg/500px-Angeln_zubehoer_wobbler_01.jpg'
where not exists (select 1 from products where title = 'Набор воблеров (5 шт.)');

insert into products (title, description, price, image_url)
select 'Эхолот Lucky FF718', 'Беспроводной, портативный', 4990,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Fishfinder_display_showing_the_mark_at_Flash_Pinnacle_P7280213.jpg/500px-Fishfinder_display_showing_the_mark_at_Flash_Pinnacle_P7280213.jpg'
where not exists (select 1 from products where title = 'Эхолот Lucky FF718');

insert into products (title, description, price, image_url)
select 'Прикормка Sensas 3000', 'Универсальная, 1 кг', 690,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Zan%C4%99ta_na_ryby_%28Murowana_Goslina%29%2C_groundbait.jpg/500px-Zan%C4%99ta_na_ryby_%28Murowana_Goslina%29%2C_groundbait.jpg'
where not exists (select 1 from products where title = 'Прикормка Sensas 3000');


-- ============================================================
-- Supabase Storage: бакет для аватаров профиля.
-- Выполнить в SQL Editor проекта Supabase (как schema.sql/seed.sql).
-- ============================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Аватары читает кто угодно (публичный URL показывается в профиле и чате).
create policy "Аватары доступны всем на чтение" on storage.objects
  for select using (bucket_id = 'avatars');

-- Пользователь загружает/меняет/удаляет только файлы в своей папке —
-- приложение сохраняет аватар по пути "<user_id>/avatar".
create policy "Пользователь загружает только свой аватар" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Пользователь обновляет только свой аватар" on storage.objects
  for update using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Пользователь удаляет только свой аватар" on storage.objects
  for delete using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================================
-- Supabase Storage: бакет для фото в чате региона.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('chat-photos', 'chat-photos', true)
on conflict (id) do nothing;

-- Фото в чате читает кто угодно (публичный URL показывается в сообщении).
create policy "Фото чата доступны всем на чтение" on storage.objects
  for select using (bucket_id = 'chat-photos');

-- Пользователь загружает фото только в свою папку — приложение сохраняет
-- фото по пути "<user_id>/<region_id>-<timestamp>.jpg". Обновление и
-- удаление не нужны: у каждой отправки фото свой уникальный путь.
create policy "Пользователь загружает фото чата только в свою папку" on storage.objects
  for insert with check (
    bucket_id = 'chat-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );
