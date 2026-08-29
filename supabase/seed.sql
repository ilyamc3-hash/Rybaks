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
