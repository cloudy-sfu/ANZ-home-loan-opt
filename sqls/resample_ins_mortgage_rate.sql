WITH date_bounds AS (
    -- 1. Find boundaries specific to the filtered bank and product
    SELECT
        MIN(date) AS min_date,
        MAX(date) AS max_date
    FROM public.ins_mortgage_rate
    WHERE bank = :bank
      AND (
          (:special = TRUE  AND product LIKE 'Special%') OR
          (:special = FALSE AND product = 'Standard')
      )
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
-- 3. As Of Join applied to the specific filtered parameters
SELECT
    f.target_friday AS date,
    r.floating,
    r._6_months,
    r._1_year,
    r._18_months,
    r._2_years,
    r._3_years,
    r._4_years,
    r._5_years
FROM fridays f
LEFT JOIN LATERAL (
    SELECT *
    FROM public.ins_mortgage_rate imr
    WHERE imr.bank = :bank
      AND (
          (:special = TRUE  AND imr.product LIKE 'Special%') OR
          (:special = FALSE AND imr.product = 'Standard')
      )
      AND imr.date <= f.target_friday
    ORDER BY imr.date DESC
    LIMIT 1
) r ON true
ORDER BY f.target_friday;