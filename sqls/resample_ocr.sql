WITH date_bounds AS (
    -- 1. Find the date boundaries of your dataset
    SELECT
        MIN(date) AS min_date,
        (now() AT TIME ZONE 'Pacific/Auckland')::date AS max_date
    FROM public.ocr
),
fridays AS (
    -- Extract the generate_series into a FROM clause so we can filter its output
    SELECT f_date::date AS target_friday
    FROM date_bounds,
         generate_series(
             (date_trunc('week', min_date) + interval '4 days')::date,
             (date_trunc('week', max_date) + interval '4 days')::date,
             interval '1 week'
         ) AS f_date
    WHERE f_date::date >= min_date -- <-- THIS PREVENTS THE INITIAL NULL ROW
      AND min_date IS NOT NULL
)
-- 3. Perform the "As Of" Join using LATERAL
SELECT
    f.target_friday as date,
    r.ocr
FROM fridays f
LEFT JOIN LATERAL (
    SELECT *
    FROM public.ocr amr
    WHERE amr.date <= f.target_friday
    ORDER BY amr.date DESC
    LIMIT 1
) r ON true
ORDER BY f.target_friday;