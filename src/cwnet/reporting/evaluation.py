"""Comparison of the recomputed results with the published tables (``cwnet eval``)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from cwnet.design.results import DesignStudy
from cwnet.model import DesignCase


@dataclass
class Comparison:
    item: str
    label: str
    published: float
    computed: float
    unit: str = ""
    note: str = ""

    @property
    def deviation(self) -> float:
        return self.computed - self.published

    @property
    def relative(self) -> float:
        return self.deviation / self.published if self.published else float("nan")


def _cost_rows(
    item: str, table: dict, study: DesignStudy, label_map: dict[str, str] | None = None
) -> list[Comparison]:
    rows: list[Comparison] = []
    evaluations = {f"Traditional ({k})": e for k, e in study.traditional.items()}
    evaluations.update({f"Proposed / {e.design.pump_curve}": e for e in study.lp if e.feasible})
    for label, values in table.items():
        key = (label_map or {}).get(label, label)
        ev = evaluations.get(key)
        if ev is None:
            continue
        c = ev.costs
        computed = {
            "total": c.total,
            "operating": c.operating,
            "pump": c.pump_capital_annualized,
            "pipe": c.pipe_capital,
        }
        units = {"total": "USD/y", "operating": "USD/y", "pump": "USD/y", "pipe": "USD"}
        for col, pub in values.items():
            rows.append(
                Comparison(item, f"{label} - {col}", float(pub), float(computed[col]), units[col])
            )
    return rows


def evaluate_study(
    name: str, case: DesignCase, study: DesignStudy, published: dict
) -> list[Comparison]:
    """Build the list of published-vs-computed comparisons for one paper case."""
    pub = published[name]
    rows: list[Comparison] = []
    if name == "paper1_grassroots":
        rows += _cost_rows("Table XI", pub["table_xi"], study)
        trad = study.traditional["edgar_himmelblau"]
        rows.append(
            Comparison(
                "Traditional design",
                "required pump head",
                pub["traditional_required_head_m"],
                trad.design.required_pump_head or 0.0,
                "m",
            )
        )
        se = trad.scenarios[0]
        tags = [h.tag for h in case.exchangers]
        for h, tag in enumerate(tags):
            t = pub["table_x"][tag]
            rows.append(
                Comparison(
                    "Table X",
                    f"{tag} simulated flow",
                    t["simulated_flow"],
                    float(se.exchanger_flows[h]),
                    "kg/s",
                )
            )
            if se.thermal is not None:
                rows.append(
                    Comparison(
                        "Table X",
                        f"{tag} simulated hot outlet",
                        t["simulated_hot_outlet"],
                        float(se.thermal.hot_outlet[h]),
                        "degC",
                        "different thermal model (see docs/reproduction.md)",
                    )
                )
        rows.append(
            Comparison(
                "Table X",
                "total simulated flow",
                pub["table_x"]["Total"]["simulated_flow"],
                float(se.exchanger_flows.sum()),
                "kg/s",
            )
        )
    elif name == "paper1_revamp":
        rows += _cost_rows(
            "Table XVI", pub["table_xvi"], study, {"Traditional (as published)": "__skip__"}
        )
        best = study.best
        for tag, v in pub["valve_head_loss_m"].items():
            rows.append(
                Comparison(
                    "Table XIV valves",
                    f"{tag} valve head loss",
                    float(v),
                    best.design.valve_head(case.scenarios[0].name, tag),
                    "m",
                )
            )
        trad = study.traditional["edgar_himmelblau"]
        rows.append(
            Comparison(
                "Traditional design",
                "required pump head",
                pub["traditional_required_head_m"],
                trad.design.required_pump_head or 0.0,
                "m",
                "pump 3 is sufficient (docs/errata.md)",
            )
        )
    elif name == "paper2_multiscenario":
        best, trad = study.best, study.traditional["towler"]
        t7 = pub["table_7"]
        rows.append(
            Comparison(
                "Table 7",
                "pipe capital - optimization",
                t7["pipe_capital"]["optimization"],
                best.costs.pipe_capital,
                "USD",
            )
        )
        rows.append(
            Comparison(
                "Table 7",
                "pipe capital - traditional",
                t7["pipe_capital"]["traditional"],
                trad.costs.pipe_capital,
                "USD",
            )
        )
        rows.append(
            Comparison(
                "Table 7",
                "pump capital (annualized) - optimization",
                t7["pump_capital_annualized"]["optimization"],
                best.costs.pump_capital_annualized,
                "USD/y",
            )
        )
        t9 = pub["table_9_operating"]
        rows.append(
            Comparison(
                "Table 9",
                "operating - optimization",
                t9["optimization"],
                best.costs.operating,
                "USD/y",
            )
        )
        rows.append(
            Comparison(
                "Table 9",
                "operating - traditional",
                t9["traditional"],
                trad.costs.operating,
                "USD/y",
            )
        )
        r = case.economics.annualizing_factor
        t10 = pub["table_10_total_annualized"]
        for label, ev in (("optimization", best), ("traditional", trad)):
            paper_arithmetic = ev.costs.operating + r * (
                ev.costs.pipe_capital + ev.costs.pump_capital_annualized
            )
            rows.append(
                Comparison(
                    "Table 10",
                    f"total (paper arithmetic) - {label}",
                    t10[label],
                    paper_arithmetic,
                    "USD/y",
                    "published totals annualize the pump cost twice (docs/errata.md)",
                )
            )
        se = trad.scenarios[0]
        for h, he in enumerate(case.exchangers):
            rows.append(
                Comparison(
                    "Table 8",
                    f"{he.tag} traditional flow",
                    pub["table_8_traditional_flows"][he.tag],
                    float(se.exchanger_flows[h]),
                    "kg/s",
                )
            )
        for he in case.exchangers:
            for m, sc in enumerate(case.scenarios):
                rows.append(
                    Comparison(
                        "Table 6",
                        f"{he.tag} valve {sc.name}",
                        pub["table_6_valves_m"][he.tag][m],
                        best.design.valve_head(sc.name, he.tag),
                        "m",
                        "depends on the alternative LP optimum (docs/reproduction.md)",
                    )
                )
    return rows


def comparisons_to_frame(rows: list[Comparison]) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Item": [r.item for r in rows],
            "Quantity": [r.label for r in rows],
            "Unit": [r.unit for r in rows],
            "Published": [r.published for r in rows],
            "Computed": [np.round(r.computed, 3) for r in rows],
            "Deviation": [np.round(r.deviation, 3) for r in rows],
            "Relative (%)": [
                np.round(100 * r.relative, 2) if r.published else np.nan for r in rows
            ],
            "Note": [r.note for r in rows],
        }
    )


def write_evaluation(
    out_dir: Path, results: dict[str, pd.DataFrame], references: dict[str, str]
) -> Path:
    """Write one CSV per case and a markdown report; return the report path."""
    out_dir.mkdir(parents=True, exist_ok=True)
    lines = ["# Evaluation against the published values", ""]
    for name, df in results.items():
        df.to_csv(out_dir / f"{name}.csv", index=False)
        lines += [f"## {name}", "", references.get(name, ""), ""]
        shown = df.drop(columns=["Note"])
        lines.append(shown.to_markdown(index=False))
        worst = (
            df.loc[df["Relative (%)"].abs().idxmax()] if df["Relative (%)"].notna().any() else None
        )
        if worst is not None:
            lines += [
                "",
                f"Largest relative deviation: {worst['Quantity']} "
                f"({worst['Relative (%)']:+.2f} %).",
            ]
        notes = df[df["Note"] != ""]
        if not notes.empty:
            lines += ["", "Notes:"] + [
                f"- {q}: {n}" for q, n in zip(notes["Quantity"], notes["Note"], strict=True)
            ]
        lines.append("")
    report = out_dir / "report.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    return report
