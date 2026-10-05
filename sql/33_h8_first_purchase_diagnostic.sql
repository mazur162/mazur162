-- 33_h8_first_purchase_diagnostic.sql
-- H8: проверка определения «новый покупатель» ПЕРЕД основными выгрузками.
--
-- Новый покупатель = клиент, чья ПЕРВАЯ за всю историю успешная оплата билета
-- пришлась на анализируемый день. Поэтому историю берём БЕЗ фильтра
-- dimension_5 > 13: иначе клиент, купивший в «грязных» тиражах <= 13,
-- ошибочно считался бы новым.
--
-- Что смотрим: месячное распределение первых покупок. Если у начала истории
-- аномальный всплеск «первых» покупок — это левое цензурирование (лог начинается
-- позже запуска продукта), и окно для H8 нужно сдвигать вправо.

WITH purchases AS (
    SELECT
        dimension_1                       AS client_id,
        timestamp_day::DATE               AS purchase_date
    FROM retail.event_log
    WHERE application_id  = 'jackflow'
      AND event_category  = 'Lottery'
      AND event_name      = 'Success'
      AND event_label IN ('Ticket payment', 'Ticket%20payment', 'TicketPayment')
      AND dimension_1 IS NOT NULL
),
first_purchase AS (
    SELECT client_id, MIN(purchase_date) AS first_date
    FROM purchases
    GROUP BY client_id
)
SELECT
    DATE_TRUNC('month', first_date)::DATE AS first_purchase_month,
    COUNT(*)                              AS first_time_buyers,
    MIN(first_date)                       AS min_first_date,
    MAX(first_date)                       AS max_first_date
FROM first_purchase
GROUP BY 1
ORDER BY 1;
