"""Sensitivity of the optimal design to the energy price (Section 7.6 of the manuscript)."""

from __future__ import annotations

from collections.abc import Iterable

import pandas as pd

from cwnet.design.optimizer import run_design_study
from cwnet.model import DesignCase


def energy_price_sweep(
    case: DesignCase,
    prices: Iterable[float],
    traditional_methods: Iterable[str] = ("edgar_himmelblau", "towler"),
    simulate: bool = True,
) -> pd.DataFrame:
    """Run the full study for several energy prices and tabulate the costs.

    Returns one row per price with the total, operating, pump and pipe costs of every
    traditional method and LP pump alternative, plus the best LP alternative.
    """
    methods = list(traditional_methods)
    rows = []
    for pc in prices:
        c = case.model_copy(deep=True)
        c.economics.energy_price = float(pc)
        study = run_design_study(c, traditional_methods=methods, simulate=simulate)
        row: dict[str, float | str] = {"energy_price": float(pc)}
        for m, ev in study.traditional.items():
            row[f"traditional_{m}_total"] = ev.costs.total
            row[f"traditional_{m}_operating"] = ev.costs.operating
            row[f"traditional_{m}_pump"] = ev.costs.pump_capital_annualized
            row[f"traditional_{m}_pipe"] = ev.costs.pipe_capital
        for ev in study.lp:
            tag = ev.design.pump_curve
            row[f"lp_{tag}_total"] = ev.costs.total
            row[f"lp_{tag}_operating"] = ev.costs.operating
            row[f"lp_{tag}_pump"] = ev.costs.pump_capital_annualized
            row[f"lp_{tag}_pipe"] = ev.costs.pipe_capital
        if study.best is not None:
            row["best_pump"] = study.best.design.pump_curve
            row["best_total"] = study.best.costs.total
            row["best_operating"] = study.best.costs.operating
            row["best_pump_cost"] = study.best.costs.pump_capital_annualized
            row["best_pipe"] = study.best.costs.pipe_capital
        rows.append(row)
    return pd.DataFrame(rows)
