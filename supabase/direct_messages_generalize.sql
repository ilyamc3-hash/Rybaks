-- ============================================================
-- Обобщение listing_threads / listing_messages: личная переписка не
-- только по объявлению, но и напрямую из общего чата региона (тап по
-- имени автора чужого сообщения). listing_id становится необязательным.
--
-- Отдельный файл миграции. Выполнить в SQL Editor проекта Supabase.
-- Идемпотентно, можно повторно.
--
-- listing_messages НЕ трогаем — её RLS через EXISTS по listing_threads
-- и от listing_id не зависит.
-- ============================================================

-- 1. listing_id теперь необязателен (NULL = прямой диалог из чата).
alter table listing_threads alter column listing_id drop not null;

-- 2. Защита от дублей прямого диалога одной и той же пары пользователей.
--    Старый unique (listing_id, buyer_id) здесь не работает: два NULL в
--    listing_id не считаются равными, поэтому одна пара могла бы завести
--    несколько "безlisting" тредов. Нормализуем пару через least/greatest
--    (диалог симметричен: buyer/seller — просто "кто инициировал").
--    Только для тредов без объявления; для тредов с объявлением остаётся
--    listing_thread_unique_buyer.
create unique index if not exists listing_thread_unique_direct_pair
  on listing_threads (least(buyer_id, seller_id), greatest(buyer_id, seller_id))
  where listing_id is null;

-- 3. INSERT-политика: две ветки в одном OR.
--    - с объявлением: seller_id обязан совпадать с listings.seller_id
--      (нельзя подставить произвольного продавца);
--    - без объявления: сверять не с чем — достаточно, что инициатор
--      пишет от своего имени и не сам себе.
drop policy if exists "Покупатель открывает тред по объявлению" on listing_threads;
drop policy if exists "Пользователь открывает тред" on listing_threads;
create policy "Пользователь открывает тред" on listing_threads
  for insert with check (
    auth.uid() = buyer_id
    and buyer_id <> seller_id
    and (
      listing_id is null
      or seller_id = (select l.seller_id from listings l where l.id = listing_id)
    )
  );

-- SELECT / listing_messages политики не меняются — они уже по участникам
-- (buyer_id / seller_id = auth.uid()), listing_id в них не участвует.
