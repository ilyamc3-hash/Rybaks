-- Клёв: полная инициализация БД. Выполнять в SQL Editor проекта nwerzgirwbrfcbtdotlf.
-- Сгенерирован из schema.sql + seed.sql + storage.sql.

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

-- ============================================================
-- Барахолка, фаза 1 личных сообщений: приватная переписка покупателя
-- с продавцом по конкретному объявлению. Отдельная сущность от
-- регионального чата (messages): здесь диалог 1:1, привязанный к
-- listings, а не групповой чат региона.
--
-- RLS здесь строго по участникам (buyer_id / seller_id = auth.uid()) —
-- НИКАКОЙ политики «виден всем авторизованным», в отличие от прошлой
-- версии политики на users, где так утекали чужие номера телефонов.
-- Полная миграция с комментариями — supabase/listing_threads.sql.
-- ============================================================

create table if not exists listing_threads (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings (id) on delete cascade,
  buyer_id uuid not null references users (id) on delete cascade,
  seller_id uuid not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint listing_thread_unique_buyer unique (listing_id, buyer_id),
  constraint listing_thread_distinct_parties check (buyer_id <> seller_id)
);

create index if not exists listing_threads_buyer_created_idx
  on listing_threads (buyer_id, created_at desc);
create index if not exists listing_threads_seller_created_idx
  on listing_threads (seller_id, created_at desc);
create index if not exists listing_threads_listing_idx
  on listing_threads (listing_id);

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
create index if not exists listing_messages_thread_unread_idx
  on listing_messages (thread_id) where read_at is null;

alter table listing_threads enable row level security;
alter table listing_messages enable row level security;

create policy "Участник видит свои треды по объявлению" on listing_threads
  for select using (auth.uid() = buyer_id or auth.uid() = seller_id);

create policy "Покупатель открывает тред по объявлению" on listing_threads
  for insert with check (
    auth.uid() = buyer_id
    and buyer_id <> seller_id
    and seller_id = (select l.seller_id from listings l where l.id = listing_id)
  );

create policy "Участник треда видит сообщения" on listing_messages
  for select using (
    exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

create policy "Участник треда пишет от своего имени" on listing_messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from listing_threads t
      where t.id = listing_messages.thread_id
        and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
    )
  );

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

do $$
begin
  execute 'alter publication supabase_realtime add table listing_messages';
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;


-- ============================================================
-- Seed-скрипт: справочник регионов.
-- Выполнить в SQL Editor проекта Supabase ПОСЛЕ supabase/schema.sql.
-- Безопасно выполнять повторно — вставки идут через "where not exists"
-- (дублей не будет).
--
-- Объявления барахолки (таблица listings) не сидируются — их создают
-- сами пользователи из приложения.
-- ============================================================

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


-- ============================================================
-- Supabase Storage: бакеты avatars / chat-photos / listing-photos /
-- thread-photos. Все публичные (buckets.public = true) — показ файлов
-- идёт по прямому URL /storage/v1/object/public/... в обход RLS.
--
-- SELECT-политика на storage.objects всё равно нужна: Storage API при
-- загрузке делает INSERT ... RETURNING *, и без SELECT-политики,
-- покрывающей новую строку, запрос падает с 403 "new row violates
-- row-level security policy" (для avatars это ещё и upsert → UPDATE).
-- SELECT ограничен владельцем (первый сегмент пути = auth.uid()), чтобы
-- через Storage API .list() нельзя было перечислить чужие файлы
-- (предупреждение дашборда "Clients can list all files").
-- ============================================================

-- ---------- avatars ----------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Аватары доступны всем на чтение" on storage.objects;

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
-- фото по пути "<user_id>/<region_id>-<timestamp>.jpg".
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

-- ---------- thread-photos ----------
-- Фото внутри личной переписки барахолки (listing_threads /
-- listing_messages). Путь файла: "<user_id>/<thread_id>-<timestamp>.jpg".
insert into storage.buckets (id, name, public)
values ('thread-photos', 'thread-photos', true)
on conflict (id) do nothing;

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
