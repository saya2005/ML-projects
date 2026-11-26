-- Walmart: анализ недельных продаж
-- PostgreSQL | Исходная таблица: public.walmart_sales_raw
-- Каждый запрос можно выделить и выполнить отдельно в pgAdmin.


-- 1. Проверка данных после импорта.
-- Сколько строк, магазинов и недель? Какой период охватывают данные?
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT store) AS total_stores,
    COUNT(DISTINCT sales_date_raw) AS total_weeks,
    MIN(TO_DATE(sales_date_raw, 'DD-MM-YYYY')) AS first_week,
    MAX(TO_DATE(sales_date_raw, 'DD-MM-YYYY')) AS last_week
FROM public.walmart_sales_raw;


-- 2. Какие магазины принесли больше всего выручки за весь период?
SELECT
    store,
    SUM(weekly_sales) AS total_sales
FROM public.walmart_sales_raw
GROUP BY store
ORDER BY total_sales DESC;


-- 3. Магазин № 20: сколько было обычных и праздничных недель?
-- Какой была средняя выручка в каждой группе?
SELECT
    holiday_flag,
    COUNT(*) AS week_count,
    AVG(weekly_sales) AS avg_weekly_sales
FROM public.walmart_sales_raw
WHERE store = 20
GROUP BY holiday_flag
ORDER BY holiday_flag;


-- 4. Средняя выручка в обычные и праздничные недели по каждому магазину.
SELECT
    store,
    AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales END) AS avg_regular_sales,
    AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales END) AS avg_holiday_sales
FROM public.walmart_sales_raw
GROUP BY store
ORDER BY store;


-- 5. Топ-5 магазинов по абсолютной праздничной прибавке.
WITH store_averages AS (
    SELECT
        store,
        AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales END) AS avg_regular_sales,
        AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales END) AS avg_holiday_sales
    FROM public.walmart_sales_raw
    GROUP BY store
)
SELECT
    store,
    avg_regular_sales,
    avg_holiday_sales,
    avg_holiday_sales - avg_regular_sales AS sales_difference
FROM store_averages
ORDER BY sales_difference DESC
LIMIT 5;


-- 6. Топ-5 магазинов по праздничной прибавке в процентах.
WITH store_averages AS (
    SELECT
        store,
        AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales END) AS avg_regular_sales,
        AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales END) AS avg_holiday_sales
    FROM public.walmart_sales_raw
    GROUP BY store
)
SELECT
    store,
    (avg_holiday_sales - avg_regular_sales) * 100.0
        / NULLIF(avg_regular_sales, 0) AS growth_pct
FROM store_averages
ORDER BY growth_pct DESC NULLS LAST
LIMIT 5;


-- Дополнительная проверка к задаче 6.
-- Какая процентная прибавка у магазина № 10, лидера по прибавке в деньгах?
WITH store_averages AS (
    SELECT
        store,
        AVG(CASE WHEN holiday_flag = 0 THEN weekly_sales END) AS avg_regular_sales,
        AVG(CASE WHEN holiday_flag = 1 THEN weekly_sales END) AS avg_holiday_sales
    FROM public.walmart_sales_raw
    WHERE store = 10
    GROUP BY store
)
SELECT
    store,
    (avg_holiday_sales - avg_regular_sales) * 100.0
        / NULLIF(avg_regular_sales, 0) AS growth_pct
FROM store_averages;


-- 7а. Магазин № 35: определяем базу для сравнения.
SELECT AVG(weekly_sales) AS avg_regular_sales
FROM public.walmart_sales_raw
WHERE store = 35 AND holiday_flag = 0;


-- 7б. Проверяем каждую праздничную неделю магазина № 35.
WITH baseline AS (
    SELECT AVG(weekly_sales) AS avg_regular_sales
    FROM public.walmart_sales_raw
    WHERE store = 35 AND holiday_flag = 0
)
SELECT
    w.sales_date_raw,
    w.weekly_sales,
    b.avg_regular_sales,
    w.weekly_sales > b.avg_regular_sales AS above_baseline
FROM public.walmart_sales_raw AS w
CROSS JOIN baseline AS b
WHERE w.store = 35 AND w.holiday_flag = 1
ORDER BY TO_DATE(w.sales_date_raw, 'DD-MM-YYYY');


-- 7в. В какой доле праздничных недель магазин № 35 превысил базу?
-- Контрольный результат: 10 недель, 6 выше базы, доля 60 %.
WITH baseline AS (
    SELECT AVG(weekly_sales) AS avg_regular_sales
    FROM public.walmart_sales_raw
    WHERE store = 35 AND holiday_flag = 0
),
abv_bas AS (
    SELECT w.weekly_sales > b.avg_regular_sales AS above_baseline
    FROM public.walmart_sales_raw AS w
    CROSS JOIN baseline AS b
    WHERE w.store = 35 AND w.holiday_flag = 1
)
SELECT
    COUNT(*) AS total_holiday_weeks,
    COUNT(*) FILTER (WHERE above_baseline) AS weeks_above_baseline,
    COUNT(*) FILTER (WHERE above_baseline) * 100.0
        / NULLIF(COUNT(*), 0) AS proportion_pct
FROM abv_bas;


-- 8. Как часто каждый магазин превышал собственную базу в праздники?
WITH baseline AS (
    SELECT store, AVG(weekly_sales) AS avg_regular_sales
    FROM public.walmart_sales_raw
    WHERE holiday_flag = 0
    GROUP BY store
),
abv_bas AS (
    SELECT
        w.store,
        w.weekly_sales > b.avg_regular_sales AS above_baseline
    FROM public.walmart_sales_raw AS w
    JOIN baseline AS b ON w.store = b.store
    WHERE w.holiday_flag = 1
)
SELECT
    store,
    COUNT(*) AS total_holiday_weeks,
    COUNT(*) FILTER (WHERE above_baseline) AS weeks_above_baseline,
    COUNT(*) FILTER (WHERE above_baseline) * 100.0 / COUNT(*) AS proportion_pct
FROM abv_bas
GROUP BY store
ORDER BY proportion_pct DESC, store;


-- 9. В какие праздничные даты больше всего магазинов превысили свою базу?
WITH baseline AS (
    SELECT store, AVG(weekly_sales) AS avg_regular_sales
    FROM public.walmart_sales_raw
    WHERE holiday_flag = 0
    GROUP BY store
),
abv_bas AS (
    SELECT
        w.store,
        w.sales_date_raw,
        w.weekly_sales > b.avg_regular_sales AS above_baseline
    FROM public.walmart_sales_raw AS w
    JOIN baseline AS b ON w.store = b.store
    WHERE w.holiday_flag = 1
)
SELECT
    sales_date_raw,
    COUNT(store) AS cnt_store,
    SUM(CASE WHEN above_baseline THEN 1 ELSE 0 END) AS cnt_abv
FROM abv_bas
GROUP BY sales_date_raw
ORDER BY cnt_abv DESC, TO_DATE(sales_date_raw, 'DD-MM-YYYY');


-- 10а. Как менялась выручка магазина № 35 от недели к неделе?
WITH previous_week AS (
    SELECT
        store,
        TO_DATE(sales_date_raw, 'DD-MM-YYYY') AS sales_date,
        weekly_sales,
        LAG(weekly_sales) OVER (
            PARTITION BY store
            ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY')
        ) AS prev_week_sales
    FROM public.walmart_sales_raw
    WHERE store = 35
)
SELECT
    store,
    sales_date,
    weekly_sales,
    prev_week_sales,
    (weekly_sales - prev_week_sales) * 100.0
        / NULLIF(prev_week_sales, 0) AS growth_pct
FROM previous_week
ORDER BY sales_date;


-- 10б. Сравниваем два ноябрьских пика магазина № 35.
-- Отбираем даты после LAG(), чтобы в расчёт попали предыдущие недели.
WITH previous_week AS (
    SELECT
        sales_date_raw,
        weekly_sales,
        LAG(weekly_sales) OVER (
            PARTITION BY store
            ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY')
        ) AS prev_week_sales
    FROM public.walmart_sales_raw
    WHERE store = 35
)
SELECT
    sales_date_raw,
    weekly_sales,
    prev_week_sales,
    (weekly_sales - prev_week_sales) * 100.0
        / NULLIF(prev_week_sales, 0) AS growth_pct
FROM previous_week
WHERE sales_date_raw IN ('26-11-2010', '25-11-2011')
ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY');


-- 11а. Пять самых больших скачков продаж за две ноябрьские даты.
-- Одна строка рейтинга соответствует паре «магазин и неделя».
WITH previous_week AS (
    SELECT
        store,
        sales_date_raw,
        weekly_sales,
        LAG(weekly_sales) OVER (
            PARTITION BY store
            ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY')
        ) AS prev_week_sales
    FROM public.walmart_sales_raw
)
SELECT
    store,
    sales_date_raw,
    weekly_sales,
    prev_week_sales,
    (weekly_sales - prev_week_sales) * 100.0
        / NULLIF(prev_week_sales, 0) AS growth_pct
FROM previous_week
WHERE sales_date_raw IN ('26-11-2010', '25-11-2011')
ORDER BY growth_pct DESC NULLS LAST
LIMIT 5;


-- 11б. Какие пять магазинов показали наибольший рост к 25 ноября 2011 года?
WITH previous_week AS (
    SELECT
        store,
        sales_date_raw,
        weekly_sales,
        LAG(weekly_sales) OVER (
            PARTITION BY store
            ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY')
        ) AS prev_week_sales
    FROM public.walmart_sales_raw
)
SELECT
    store,
    sales_date_raw,
    weekly_sales,
    prev_week_sales,
    (weekly_sales - prev_week_sales) * 100.0
        / NULLIF(prev_week_sales, 0) AS growth_pct
FROM previous_week
WHERE sales_date_raw = '25-11-2011'
ORDER BY growth_pct DESC NULLS LAST
LIMIT 5;


-- Приложение. Что произошло через неделю у пяти лидеров задачи 11б?
WITH previous_week AS (
    SELECT
        store,
        sales_date_raw,
        weekly_sales,
        LAG(weekly_sales) OVER (
            PARTITION BY store
            ORDER BY TO_DATE(sales_date_raw, 'DD-MM-YYYY')
        ) AS prev_week_sales
    FROM public.walmart_sales_raw
    WHERE store IN (35, 29, 15, 7, 21)
)
SELECT
    store,
    sales_date_raw,
    weekly_sales,
    prev_week_sales,
    (weekly_sales - prev_week_sales) * 100.0
        / NULLIF(prev_week_sales, 0) AS growth_pct
FROM previous_week
WHERE sales_date_raw = '02-12-2011'
ORDER BY store;