// Supabase Auth "Send SMS Hook".
//
// Supabase Auth вызывает эту функцию вместо встроенной отправки SMS
// каждый раз, когда пользователь запрашивает вход по номеру телефона
// (signInWithOtp / resend). Функция отправляет код через российский
// SMS-шлюз SMS Aero.
//
// Секреты (задаются через `supabase secrets set`, в коде их нет):
//   SMSAERO_EMAIL        — email аккаунта SMS Aero
//   SMSAERO_API_KEY      — API-ключ SMS Aero
//   SMSAERO_SIGN         — подпись отправителя (необязательно, по
//     умолчанию "SMS Aero" — стандартная подпись, пока своя не одобрена)
//   SEND_SMS_HOOK_SECRET — секрет подписи хука из дашборда Supabase
//     (Authentication → Hooks → Send SMS hook), вида "v1,whsec_...".
//     Без проверки подписи вызвать функцию и получить бесплатную SMS
//     за ваш счёт мог бы кто угодно, кто узнает URL функции.

import { Webhook } from "npm:standardwebhooks@1.0.0";

const SMSAERO_EMAIL = Deno.env.get("SMSAERO_EMAIL");
const SMSAERO_API_KEY = Deno.env.get("SMSAERO_API_KEY");
const SMSAERO_SIGN = Deno.env.get("SMSAERO_SIGN") ?? "SMS Aero";
const HOOK_SECRET = Deno.env.get("SEND_SMS_HOOK_SECRET");

interface SendSmsHookPayload {
  user: { phone?: string };
  sms: { otp: string };
}

function hookError(httpCode: number, message: string): Response {
  console.error(`send-sms-hook: ${message}`);
  return new Response(
    JSON.stringify({ error: { http_code: httpCode, message } }),
    { status: httpCode, headers: { "Content-Type": "application/json" } },
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return hookError(405, "Method not allowed");
  }

  if (!HOOK_SECRET) {
    return hookError(500, "SEND_SMS_HOOK_SECRET is not configured");
  }

  const rawBody = await req.text();

  // Проверяем подпись запроса (Standard Webhooks) — гарантирует, что
  // запрос действительно пришёл от Supabase Auth, а не от третьих лиц.
  let payload: SendSmsHookPayload;
  try {
    // Дашборд Supabase выдаёт секрет вида "v1,whsec_...", а библиотека
    // standardwebhooks сама ожидает только часть "whsec_..." — сама
    // отрезает этот префикс и base64-декодирует остаток. Ведущий "v1,"
    // при этом не срезается автоматически и ломает декодирование.
    const secret = HOOK_SECRET.startsWith("v1,")
      ? HOOK_SECRET.slice(3)
      : HOOK_SECRET;
    const webhook = new Webhook(secret);
    payload = webhook.verify(
      rawBody,
      Object.fromEntries(req.headers),
    ) as SendSmsHookPayload;
  } catch (error) {
    return hookError(401, `Invalid webhook signature: ${error}`);
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;

  if (!phone || !otp) {
    return hookError(400, "Payload is missing user.phone or sms.otp");
  }

  if (!SMSAERO_EMAIL || !SMSAERO_API_KEY) {
    return hookError(500, "SMS Aero credentials are not configured");
  }

  // Название сервиса в тексте обязательно: SMS Aero (через МТС) блокирует
  // сообщения с кодом авторизации, если в тексте нет имени сервиса.
  const text = `Ваш код авторизации в Клёв: ${otp}`;
  const url = new URL("https://gate.smsaero.ru/v2/sms/send");
  // Supabase присылает номер без "+", но на всякий случай снимаем его,
  // если он всё же есть — SMS Aero ожидает номер в виде одних цифр.
  url.searchParams.set("number", phone.replace(/^\+/, ""));
  url.searchParams.set("text", text);
  url.searchParams.set("sign", SMSAERO_SIGN);

  const auth = btoa(`${SMSAERO_EMAIL}:${SMSAERO_API_KEY}`);

  let smsAeroResponse: Response;
  try {
    smsAeroResponse = await fetch(url, {
      method: "GET",
      headers: { Authorization: `Basic ${auth}` },
    });
  } catch (error) {
    return hookError(500, `Failed to reach SMS Aero: ${error}`);
  }

  const result = await smsAeroResponse.json().catch(() => null);

  if (!smsAeroResponse.ok || !result?.success) {
    return hookError(
      502,
      `SMS Aero rejected the request: ${result?.message ?? smsAeroResponse.status}`,
    );
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
