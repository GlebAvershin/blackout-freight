def facts(m):
    return {"assignment_above_five_percent_before_rounding": bool(m["assignment_flag"]),
            "rounded_gap_percent": m["max_imbalance_bp"] / 100, "data_source": "synthetic fixture"}
