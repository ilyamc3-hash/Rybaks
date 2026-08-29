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

### 2.1. Включить телефонный провайдер

**Authentication → Sign In / Providers → Phone** → включить.
SMS-провайдера внутри выбирать не нужно (перекрывается хуком), но
провайдер Phone должен быть **Enabled**.

### 2.2. Задать секреты функции

**Project Settings → Edge Functions → Secrets** (или CLI, см. ниже) —
добавить:

| Ключ | Значение |
|------|----------|
| `SMSAERO_EMAIL` | e-mail аккаунта SMS Aero (тот, под которым выпущен ключ) |
| `SMSAERO_API_KEY` | `oxnicHOBTNBCicVM_-GyYjqyMMrzU1AE` |
| `SMSAERO_SIGN` | `SMS Aero` (пока своя подпись не одобрена) |
| `SEND_SMS_HOOK_SECRET` | заполнить на шаге 2.4 |

> `SMSAERO_EMAIL` знаете только вы — в задании его не было. Это e-mail,
> которым вы входите в личный кабинет SMS Aero.

### 2.3. Задеплоить функцию

**Вариант A — CLI** (нужен вход в аккаунт-владелец проекта, т.е. ваш
`ilyamc3@gmail.com`; на этой машине сейчас залогинен другой аккаунт):

```bash
supabase login
supabase link --project-ref nwerzgirwbrfcbtdotlf
supabase secrets set \
  SMSAERO_EMAIL="ваш-email@example.com" \
  SMSAERO_API_KEY="oxnicHOBTNBCicVM_-GyYjqyMMrzU1AE" \
  SMSAERO_SIGN="SMS Aero"
supabase functions deploy send-sms-hook --no-verify-jwt
```

`--no-verify-jwt` обязателен: хук вызывается без пользовательского JWT,
подлинность запроса функция проверяет сама по подписи Standard Webhooks.

**Вариант B — Дашборд:** **Edge Functions → Deploy a new function →**
имя `send-sms-hook`, вставить код из
`supabase/functions/send-sms-hook/index.ts`. После деплоя открыть
функцию → **Details** → выключить **Enforce JWT verification**.

### 2.4. Привязать хук

**Authentication → Hooks → Send SMS hook**:

- **Enable** → тип **HTTPS** (Edge Function).
- URL: `https://nwerzgirwbrfcbtdotlf.supabase.co/functions/v1/send-sms-hook`
- Скопировать сгенерированный **Signing secret** (вид `v1,whsec_...`).
- Вставить его в секрет `SEND_SMS_HOOK_SECRET` (шаг 2.2) и, если функция
  уже задеплоена, передеплоить/сохранить секреты.

### 2.5. Проверка

```bash
curl -s "https://nwerzgirwbrfcbtdotlf.supabase.co/auth/v1/settings" \
  -H "apikey: sb_publishable_0PY0lp0IdYWWh-l8H_GOcw__Sabzpv7"
# ожидаем "phone": true
```

Затем в приложении: ввести номер → должно прийти SMS
«Ваш код авторизации в Клёв: XXXX».

Логи хука: **Edge Functions → send-sms-hook → Logs**.

---

## 3. Веб-деплой (GitHub Pages)

```powershell
powershell -File scripts/deploy_web.ps1   # base-href /Rybaks/, ключи новые
git add docs && git commit -m "Deploy web" && git push
```

Репозиторий: <https://github.com/ilyamc3-hash/Rybaks>
Живой сайт (после включения Pages → ветка `main`, папка `/docs`):
`https://ilyamc3-hash.github.io/Rybaks/`
