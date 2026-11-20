def facts(m):
    return {"assignment_gap_percent": m["max_imbalance_bp"]/100, "investigation_threshold_percent": 5,
            "data_source": "synthetic fixture"}
