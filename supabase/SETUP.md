# Настройка инфраструктуры «Клёв» (Supabase)

Проект: **`nwerzgirwbrfcbtdotlf`**
URL: `https://nwerzgirwbrfcbtdotlf.supabase.co`
Publishable (anon) key: `sb_publishable_0PY0lp0IdYWWh-l8H_GOcw__Sabzpv7`

---

## 1. SQL: схема, регионы, storage

Открыть **SQL Editor** в дашборде проекта и выполнить по очереди:

1. `supabase/schema.sql` — таблицы `users` / `regions` / `messages` /
   `products` + RLS.
2. `supabase/seed.sql` — 85 субъектов РФ + тестовые товары
   (идемпотентно, спорные 4 региона из версии заказчика исключены).
3. `supabase/storage.sql` — бакеты `avatars` и `chat-photos` + политики.

Либо один файл `supabase/all.sql` (schema + seed + storage подряд).

После этого: **Database → Replication** (или **Publications**) →
включить Realtime для таблицы `messages` — иначе чат не обновляется
в реальном времени.

---

## 2. Телефонная авторизация + Send SMS Hook

Встроенные SMS-провайдеры (Twilio и пр.) не используются — код
отправляет Edge Function `send-sms-hook` через SMS Aero.

Всё делается в дашборде, CLI не нужен (на этой машине он залогинен под
другим аккаунтом и доступа к проекту не имеет).

### 2.1. Включить телефонный провайдер

**Authentication → Sign In / Providers → Phone**:

- Включить **Enable Phone provider**.
- Блок SMS-провайдера (Twilio и т.п.) не настраивать — доставку
  перехватывает хук. Если форма не сохраняется с пустыми полями Twilio —
  вписать любые заглушки (`Account SID` = `test` и т.д.), они не нужны.
- **Save**.

### 2.2. Создать Send SMS Hook и забрать его секрет

**Authentication → Hooks → Send SMS hook** → **Add hook / Enable**:

- Тип: **HTTPS**.
- Hook URL:
  `https://nwerzgirwbrfcbtdotlf.supabase.co/functions/v1/send-sms-hook`
- Поле **Secret** заполнится само — раскрыть и **скопировать целиком**
  (вид `v1,whsec_...`).
- **Create / Save**. Функции ещё нет — это нормально.

### 2.3. Задать секреты Edge Functions

**Project Settings → Edge Functions → Secrets** (или **Edge Functions →
вкладка Secrets**) → **Add new secret**:

| Ключ | Значение |
|------|----------|
| `SMSAERO_EMAIL` | `ilmak379@yandex.ru` |
| `SMSAERO_API_KEY` | `oxnicHOBTNBCicVM_-GyYjqyMMrzU1AE` |
| `SMSAERO_SIGN` | `SMS Aero` (пока своя подпись не одобрена) |
| `SEND_SMS_HOOK_SECRET` | секрет из шага 2.2, вставить как есть, вместе с `v1,` |

### 2.4. Задеплоить функцию

**Edge Functions → Create a new function** (редактор в браузере):

- Имя — ровно **`send-sms-hook`** (иначе URL хука из 2.2 не совпадёт).
- Вставить **полностью** код из
  `supabase/functions/send-sms-hook/index.ts`.
- Снять галку **Verify JWT** при создании; если её нет — задеплоить и
  затем открыть функцию → **Details / Settings** → выключить
  **Enforce JWT Verification**.
- **Deploy**.

JWT-проверку обязательно выключить: Auth-хук вызывает функцию без
пользовательского токена, подлинность проверяется по подписи Standard
Webhooks внутри самого кода. С включённым JWT функция вернёт 401.

### 2.5. Проверка

```bash
curl -s "https://nwerzgirwbrfcbtdotlf.supabase.co/auth/v1/settings" \
  -H "apikey: sb_publishable_0PY0lp0IdYWWh-l8H_GOcw__Sabzpv7"
# ожидаем "phone": true

curl -i -X POST "https://nwerzgirwbrfcbtdotlf.supabase.co/auth/v1/otp" \
  -H "apikey: sb_publishable_0PY0lp0IdYWWh-l8H_GOcw__Sabzpv7" \
  -H "Content-Type: application/json" \
  -d '{"phone":"+79XXXXXXXXX"}'
# ожидаем 200; придёт SMS «Ваш код авторизации в Клёв: XXXX»
```

Логи: **Edge Functions → send-sms-hook → Logs / Invocations**. Частое:
- `SEND_SMS_HOOK_SECRET is not configured` — секрет из 2.3 не сохранён;
- `Invalid webhook signature` — в `SEND_SMS_HOOK_SECRET` не тот секрет
  (нужен именно из Send SMS hook, с префиксом `v1,`);
- `SMS Aero rejected the request: ...` — ответ SMS Aero: нет баланса,
  номер-получатель не подтверждён в кабинете или подпись не одобрена.
  У новых аккаунтов SMS Aero часто можно слать только на свой
  подтверждённый номер и только с подписью `SMS Aero`.

---

## 3. Веб-деплой (GitHub Pages)

```powershell
powershell -File scripts/deploy_web.ps1   # base-href /Rybaks/, ключи новые
git add docs && git commit -m "Deploy web" && git push
```

Репозиторий: <https://github.com/ilyamc3-hash/Rybaks>
Живой сайт (после включения Pages → ветка `main`, папка `/docs`):
`https://ilyamc3-hash.github.io/Rybaks/`
