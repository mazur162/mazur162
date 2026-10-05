-- 36_h8_new_buyers_by_draw.sql
-- H8: тот же вопрос на уровне тиража — единицы, как в H3.
-- Тиражи 15–24 дают базовое распределение (до 14.09), 25–27 — после.
-- Для каждого тиража считаем число новых покупателей через кнопку,
-- через остальные точки входа и итого. Дальше — z-score от базового уровня
-- тиражей 15–24 (тот же приём, что в H3).
--
-- Тираж новой покупки = dimension_5 той покупки, которая стала первой.
-- Тираж 27 использовать как финальный только после его закрытия.

WITH purchases AS (
    SELECT
        dimension_1                              AS client_id,
        timestamp_day::DATE                      AS purchase_date,
        dimension_3                              AS purchase_ts,
        dimension_7                              AS entry_point,
        dimension_21                             AS is_package,
        CAST(NULLIF(dimension_5, '') AS INT)     AS draw_no
    FROM retail.event_log
    WHERE application_id  = 'jackflow'
      AND event_category  = 'Lottery'
      AND event_name      = 'Success'
      AND event_label IN ('Ticket payment', 'Ticket%20payment', 'TicketPayment')
      AND dimension_1 IS NOT NULL
),
ranked AS (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY client_id
            ORDER BY purchase_date, purchase_ts
        ) AS purchase_rank
    FROM purchases p
),
first_purchases AS (
    SELECT *
    FROM ranked
    WHERE purchase_rank = 1
      AND draw_no BETWEEN 15 AND 27
)
SELECT
    draw_no,
    MIN(purchase_date)                                               AS draw_first_day,
    MAX(purchase_date)                                               AS draw_last_day,
    COUNT(*)                                                         AS new_buyers_total,
    SUM(CASE WHEN entry_point = 'buyPackageButton'
              AND is_package  = 'false' THEN 1 ELSE 0 END)           AS new_buyers_button,
    SUM(CASE WHEN entry_point = 'buyPackageButton'
              AND is_package  = 'true'  THEN 1 ELSE 0 END)           AS new_buyers_button_pkg,
    SUM(CASE WHEN entry_point = 'mainBanner' THEN 1 ELSE 0 END)      AS new_buyers_mainbanner,
    SUM(CASE WHEN COALESCE(entry_point, '') NOT IN ('buyPackageButton', 'mainBanner')
             THEN 1 ELSE 0 END)                                      AS new_buyers_other
FROM first_purchases
GROUP BY draw_no
ORDER BY draw_no;
