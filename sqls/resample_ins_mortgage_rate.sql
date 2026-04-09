WITH repay_cycle AS (
    SELECT
        *,
        date_trunc('month', date - :repay_date * INTERVAL '1 day')
            + INTERVAL '1 month' AS shift_date
    FROM ins_mortgage_rate
    WHERE bank = :bank
      AND product = :product
)
SELECT
    EXTRACT(YEAR  FROM shift_date) AS year,
    EXTRACT(MONTH FROM shift_date) AS month,
    (array_agg(floating   ORDER BY date DESC) FILTER (WHERE floating   IS NOT NULL))[1] AS floating,
    (array_agg(_6_months  ORDER BY date DESC) FILTER (WHERE _6_months  IS NOT NULL))[1] AS _6_months,
    (array_agg(_1_year    ORDER BY date DESC) FILTER (WHERE _1_year    IS NOT NULL))[1] AS _1_year,
    (array_agg(_18_months ORDER BY date DESC) FILTER (WHERE _18_months IS NOT NULL))[1] AS _18_months,
    (array_agg(_2_years   ORDER BY date DESC) FILTER (WHERE _2_years   IS NOT NULL))[1] AS _2_years,
    (array_agg(_3_years   ORDER BY date DESC) FILTER (WHERE _3_years   IS NOT NULL))[1] AS _3_years,
    (array_agg(_4_years   ORDER BY date DESC) FILTER (WHERE _4_years   IS NOT NULL))[1] AS _4_years,
    (array_agg(_5_years   ORDER BY date DESC) FILTER (WHERE _5_years   IS NOT NULL))[1] AS _5_years
FROM repay_cycle
GROUP BY year, month
ORDER BY year, month;
