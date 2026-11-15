WITH funnel AS (
    SELECT
        segment,
        variant,
        sum(count_value) FILTER (WHERE event = 'exposed')::INTEGER AS exposed,
        sum(count_value) FILTER (WHERE event = 'pickup_90')::INTEGER AS pickups,
        sum(count_value) FILTER (WHERE event = 'delivered_90')::INTEGER AS deliveries,
        sum(count_value) FILTER (WHERE event = 'caught_90')::INTEGER AS catches
    FROM event_counts
    GROUP BY segment, variant
)
SELECT
    *,
    pickups / nullif(exposed, 0) AS pickup_rate,
    deliveries / nullif(exposed, 0) AS delivery_rate,
    catches / nullif(exposed, 0) AS catch_rate
FROM funnel
ORDER BY segment, variant;
