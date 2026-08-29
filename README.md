# Клёв — региональный чат и маркетплейс (MVP-каркас)

Flutter-приложение: авторизация по SMS, список регионов, чат внутри
региона, каталог товаров, профиль пользователя.

## Стек

- **Flutter** (stable, Dart 3.11)
- **Supabase** — авторизация по номеру телефона (SMS), PostgreSQL
- **Riverpod** (`flutter_riverpod`) — управление состоянием

### Почему Riverpod, а не Provider

- Не завязан на `BuildContext` — провайдеры (auth, чат, каталог) можно
  читать и тестировать вне дерева виджетов.
- Ошибки конфигурации ловятся на этапе компиляции, а не в рантайме
  (в отличие от `Provider.of` с неверным типом).
- Из коробки есть `StateNotifierProvider.family` — то, что нужно для
  чата: отдельный стрим сообщений на каждый регион (`chatControllerProvider(regionId)`).
- `AsyncValue` даёт единый способ показывать loading/error/data для
  запросов к Supabase, не создавая свои enum-состояния вручную.

## Структура проекта

```
lib/
├── core/            # тема, цвета, константы, переиспользуемые виджеты
├── features/
│   ├── splash/      # экран-заставка
│   ├── auth/        # ввод телефона -> ввод SMS-кода
│   ├── main_navigation/  # нижний таб-бар (Регионы | Чат | Каталог | Профиль)
│   ├── regions/     # список регионов
│   ├── chat/        # чат региона
│   ├── catalog/     # каталог товаров
│   └── profile/     # профиль пользователя
├── services/        # SupabaseService — инициализация и auth-методы
├── models/          # User, Region, Message, Product
├── app.dart         # MaterialApp + тема
└── main.dart        # точка входа
supabase/
├── schema.sql       # SQL-схема таблиц users/regions/messages/products + RLS
└── seed.sql         # тестовые регионы (Москва, СПб) и товары каталога
```

## Текущее состояние

- Все экраны и переходы между ними работают.
- **Регионы и каталог** (`regions_provider.dart`, `catalog_provider.dart`) —
  реальные запросы к Supabase через `FutureProvider`, состояние —
  `AsyncValue` (loading/error/data) прямо из коробки Riverpod.
- **Чат** (`chat_provider.dart`) — история сообщений грузится из таблицы
  `messages`, новые сообщения приходят по Supabase Realtime
  (Postgres Changes на `insert`, отфильтровано по `region_id`) — без
  перезагрузки экрана и у всех участников комнаты одновременно.
- **Dev-режим** (`devTestUserProvider`, кнопка «Войти как тестовый
  пользователь») не создаёт настоящую сессию Supabase, поэтому не может
  писать в реальные таблицы (нет `auth.uid()`). Чтение регионов/каталога/
  чата ему доступно (RLS открыт на SELECT всем), а свои сообщения он
  добавляет только локально, в `ChatController`. Реальные
  авторизованные пользователи пишут напрямую в БД, и их сообщение
  возвращается всем участникам через realtime-подписку.
- `SupabaseService` реализует авторизацию по SMS (`sendOtp`/`verifyOtp`)
  и сразу после входа создаёт/обновляет профиль в таблице `users`
  (`upsertCurrentUserProfile`) — это нужно для внешнего ключа
  `messages.author_id → users.id`.
  Пока в `SupabaseConfig` стоят заглушки URL/ключа — см. ниже, как их задать.

## Настройка Supabase

Текущий проект: `nwerzgirwbrfcbtdotlf`
(URL `https://nwerzgirwbrfcbtdotlf.supabase.co`). Ключи уже прописаны
в `lib/core/constants/app_constants.dart` и `scripts/deploy_web.ps1`.

1. Authentication → Providers → **Phone** → включить провайдера.
   SMS отправляются не встроенным провайдером, а через **Send SMS Hook**
   (Edge Function `send-sms-hook` + SMS Aero) — см. `supabase/SETUP.md`.
2. Выполнить `supabase/schema.sql` в SQL Editor — создаст таблицы
   `users`, `regions`, `messages`, `products` с RLS-политиками (чтение
   регионов/чата/каталога публичное, запись — только для авторизованных
   пользователей и только от своего имени).
3. Выполнить `supabase/seed.sql` — добавит 85 субъектов РФ и несколько
   тестовых товаров каталога (скрипт идемпотентен, можно запускать
   повторно).
4. Выполнить `supabase/storage.sql` — создаст бакеты `avatars` и
   `chat-photos` с политиками.
5. В Database → Replication включить Realtime для таблицы `messages`
   (обязательно для работы чата в реальном времени).
6. Развернуть Send SMS Hook по инструкции в `supabase/SETUP.md`.

## Запуск

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxx
```

Без параметров `--dart-define` приложение тоже запустится (используются
заглушки из `SupabaseConfig`), но реальный вход по SMS работать не будет —
подойдёт для проверки навигации и UI.

## Проверка

```bash
flutter analyze   # статический анализ
flutter test      # unit/widget-тесты
flutter build apk --debug   # сборка под Android
```

## Дальнейшие шаги

- Загрузка фото в Supabase Storage вместо локального пути `image_picker`
  (сейчас фото-сообщения всегда локальные, даже у реальных пользователей).
- Отображать реальное имя/номер автора сообщения в чате (сейчас у
  сообщений из БД показывается общая подпись «Рыбак» — понадобится join
  с `users` или денормализованное поле).
- Публикация своих товаров в каталог из профиля пользователя.
