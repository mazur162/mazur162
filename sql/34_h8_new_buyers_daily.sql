-- 34_h8_new_buyers_daily.sql
-- H8: основная выгрузка для дневного ITS и DiD.
-- Одна строка = день × группа точки входа ПЕРВОЙ покупки клиента.
--
-- Группы (entry_group):
--   button      = buyPackageButton И is_package = 'false'  (кнопка «Купить билет за 200 ₽»)
--   button_pkg  = buyPackageButton И is_package = 'true'   (карточки «Наборы билетов»)
--   mainBanner  = баннер на вкладке «Выгода»
--   other       = все остальные точки входа (контроль для DiD)
--
-- Метрики:
--   new_buyers          — клиенты, у которых ЭТО первая покупка за всю историю
--   all_buyers          — уникальные клиенты, купившие в этот день через группу (знаменатель доли)
--   new_share           — new_buyers / all_buyers
--   new_buyers_revenue  — выручка первых покупок, ₽
--
-- Почему считаем и абсолютное число, и долю: доля может вырасти из-за падения
-- знаменателя, а не из-за притока. Для вывода H8 главный показатель — new_buyers
-- (счётчик), доля — вспомогательный.
--
-- Окно: 2026-07-27 .. 2026-10-04 (как в дневных ITS остальных гипотез).
-- Первая покупка определяется по ВСЕЙ истории (без фильтра по тиражу).

WITH purchases AS (
    SELECT
        dimension_1                                  AS client_id,
        timestamp_day::DATE                          AS purchase_date,
        dimension_3                                  AS purchase_ts,
        dimension_7                                  AS entry_point,
        dimension_21                                 AS is_package,
        CAST(NULLIF(dimension_2, '') AS FLOAT)       AS revenue,
        CAST(NULLIF(dimension_5, '') AS INT)         AS draw_no
    FROM retail.event_log
    WHERE application_id  = 'jackflow'
      AND event_category  = 'Lottery'
      AND event_name      = 'Success'
      AND event_label IN ('Ticket payment', 'Ticket%20payment', 'TicketPayment')
      AND dimension_1 IS NOT NULL
),
tagged AS (
    SELECT
        p.*,
        CASE
            WHEN entry_point = 'buyPackageButton' AND is_package = 'false' THEN 'button'
            WHEN entry_point = 'buyPackageButton' AND is_package = 'true'  THEN 'button_pkg'
            WHEN entry_point = 'mainBanner'                                THEN 'mainBanner'
            ELSE 'other'
        END AS entry_group,
        -- первая покупка клиента: самая ранняя дата, внутри дня — по времени покупки
        ROW_NUMBER() OVER (
            PARTITION BY client_id
            ORDER BY purchase_date, purchase_ts
        ) AS purchase_rank
    FROM purchases p
),
new_by_day AS (
    SELECT
        purchase_date,
        entry_group,
        COUNT(*)      AS new_buyers,
        SUM(revenue)  AS new_buyers_revenue
    FROM tagged
    WHERE purchase_rank = 1
    GROUP BY purchase_date, entry_group
),
all_by_day AS (
    SELECT
        purchase_date,
        entry_group,
        COUNT(DISTINCT client_id) AS all_buyers,
        MIN(draw_no)              AS min_draw_no,
        MAX(draw_no)              AS max_draw_no
    FROM tagged
    GROUP BY purchase_date, entry_group
)
SELECT
    a.purchase_date,
    a.entry_group,
    COALESCE(n.new_buyers, 0)                                    AS new_buyers,
    a.all_buyers,
    COALESCE(n.new_buyers, 0)::FLOAT / NULLIF(a.all_buyers, 0)   AS new_share,
    COALESCE(n.new_buyers_revenue, 0)                            AS new_buyers_revenue,
    a.min_draw_no,
    a.max_draw_no                                                -- смена номера тиража помогает отметить draw_day
FROM all_by_day a
LEFT JOIN new_by_day n
       ON n.purchase_date = a.purchase_date
      AND n.entry_group   = a.entry_group
WHERE a.purchase_date BETWEEN '2026-07-27' AND '2026-10-04'
ORDER BY a.purchase_date, a.entry_group;
