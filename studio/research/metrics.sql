, segments AS (
  SELECT scenario, segment,
         10000.0 * (MAX(CASE WHEN arm='compass' THEN 1.0*deliveries/exposures END)
                  - MAX(CASE WHEN arm='control' THEN 1.0*deliveries/exposures END)) AS lift_bp,
         CASE WHEN 20 * (CAST(MAX(exposures) AS BIGINT) - MIN(exposures)) > SUM(exposures) THEN 1 ELSE 0 END AS flagged,
         10000.0 * (MAX(exposures)-MIN(exposures))/SUM(exposures) AS imbalance
  FROM samples GROUP BY scenario, segment
)
SELECT scenario, MAX(flagged) AS assignment_flag, CAST(ROUND(MAX(imbalance)) AS INT) AS max_imbalance_bp,
       CAST(ROUND(SUM(lift_bp * CASE WHEN segment='solo' THEN 0.8 ELSE 0.2 END)) AS INT) AS solo_heavy_lift_bp,
       CAST(ROUND(SUM(lift_bp * CASE WHEN segment='solo' THEN 0.2 ELSE 0.8 END)) AS INT) AS crew_heavy_lift_bp
FROM segments GROUP BY scenario ORDER BY scenario
