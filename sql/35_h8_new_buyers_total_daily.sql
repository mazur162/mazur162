-- 35_h8_new_buyers_total_daily.sql
-- H8: перераспределение или реальный приток?
--
-- Если кнопка просто перехватывает тех новичков, которые и так купили бы
-- через другие точки входа, то число новых покупателей через кнопку вырастет,
-- а общее число новых покупателей лотереи — нет. Это главный контрольный
-- вопрос для H8: растёт ли ИТОГО по всем точкам входа.
--
-- Одна строка = день. Определение «новый» — как в 34 (первая покупка за всю историю).
--
-- Дополнительно: reactivated_buyers — клиенты, которые уже покупали раньше,
-- но не покупали >= 90 дней. Это не «совсем новые», но тоже возможный канал
-- притока; смешивать их с новичками нельзя.

WITH purchases AS (
    SELECT
        dimension_1          AS client_id,
        timestamp_day::DATE  AS purchase_date,
        dimension_3          AS purchase_ts
    FROM retail.event_log
    WHERE application_id  = 'jackflow'
      AND event_category  = 'Lottery'
      AND event_name      = 'Success'
      AND event_label IN ('Ticket payment', 'Ticket%20payment', 'TicketPayment')
      AND dimension_1 IS NOT NULL
),
client_days AS (
    -- один клиент = одна строка на день
    SELECT DISTINCT client_id, purchase_date
    FROM purchases
),
with_prev AS (
    SELECT
        client_id,
        purchase_date,
        LAG(purchase_date) OVER (PARTITION BY client_id ORDER BY purchase_date) AS prev_purchase_date
    FROM client_days
)
SELECT
    purchase_date,
    COUNT(*)                                                         AS all_buyers,
    SUM(CASE WHEN prev_purchase_date IS NULL THEN 1 ELSE 0 END)      AS new_buyers,
    SUM(CASE WHEN prev_purchase_date IS NOT NULL
              AND purchase_date - prev_purchase_date >= 90
             THEN 1 ELSE 0 END)                                      AS reactivated_buyers,
    SUM(CASE WHEN prev_purchase_date IS NOT NULL
              AND purchase_date - prev_purchase_date < 90
             THEN 1 ELSE 0 END)                                      AS active_buyers
FROM with_prev
WHERE purchase_date BETWEEN '2026-07-27' AND '2026-10-04'
GROUP BY purchase_date
ORDER BY purchase_date;
