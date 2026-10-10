"""Export of results (``cwnet run``), figures and tables (``cwnet figures``) to disk."""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

from cwnet.design.results import DesignEvaluation, DesignStudy  # noqa: E402
from cwnet.model import DesignCase  # noqa: E402
from cwnet.reporting import plots, tables  # noqa: E402


def evaluation_summary(ev: DesignEvaluation, case: DesignCase) -> dict:
    d = ev.design
    return {
        "label": ev.label,
        "feasible": ev.feasible,
        "pump": d.pump_curve,
        "costs": ev.costs.as_dict() if ev.feasible else {},
        "pipes": {
            str(p.edge): {
                "diameters_in": d.pipes[p.edge].labels(case),
                "fractions": d.pipes[p.edge].fractions(),
            }
            for p in case.pipes
        }
        if ev.feasible
        else {},
        "valves_m": d.valves,
        "scenarios": [
            {
                "scenario": se.scenario,
                "pump_flow_kg_s": se.pump_flow,
                "pump_head_m": se.pump_head,
                "operating_cost": se.operating_cost,
                "exchanger_flows_kg_s": {
                    h.tag: float(k)
                    for h, k in zip(case.exchangers, se.exchanger_flows, strict=True)
                },
                "converged": se.simulation.converged,
            }
            for se in ev.scenarios
        ],
        "hydraulically_balanced": ev.hydraulically_balanced if ev.feasible else None,
    }


def study_summary(study: DesignStudy) -> dict:
    case = study.case
    return {
        "case": case.name,
        "best": study.best.label if study.best else None,
        "traditional": {k: evaluation_summary(e, case) for k, e in study.traditional.items()},
        "lp": [evaluation_summary(e, case) for e in study.lp],
    }


def write_results(study: DesignStudy, out_dir: Path) -> None:
    """Write the JSON summary and the CSV tables of a study."""
    out_dir.mkdir(parents=True, exist_ok=True)
    case = study.case
    (out_dir / "summary.json").write_text(
        json.dumps(study_summary(study), indent=2), encoding="utf-8"
    )
    tables.cost_comparison_table(study).to_csv(out_dir / "costs.csv", index=False)
    tables.design_comparison_table(study).to_csv(out_dir / "design.csv", index=False)
    tables.mass_flow_table(study, grouped=False).to_csv(out_dir / "mass_flows.csv", index=False)
    if study.best is not None:
        tables.valve_table(study.best, case).to_csv(out_dir / "valves.csv", index=False)
        for i, sc in enumerate(case.scenarios):
            tables.pipe_results_table(study.best, case, i).to_csv(
                out_dir / f"pipes_{_slug(sc.name)}.csv", index=False
            )
            tables.network_behaviour_table(study.best, i).to_csv(
                out_dir / f"behaviour_best_{_slug(sc.name)}.csv", index=False
            )
    for key, ev in study.traditional.items():
        tables.network_behaviour_table(ev, 0).to_csv(
            out_dir / f"behaviour_traditional_{key}.csv", index=False
        )


def _slug(text: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "_" for ch in text).strip("_")


def _save(ax, path: Path) -> None:
    ax.figure.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(ax.figure)


def write_figures(study: DesignStudy, out_dir: Path, name: str) -> list[Path]:
    """Export the figures and tables of a case (digraphs, costs, pump curves, schematics)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    case = study.case
    written: list[Path] = []

    def fig(fname: str, ax) -> None:
        path = out_dir / f"{name}_{fname}.png"
        _save(ax, path)
        written.append(path)

    fig("digraph", plots.plot_digraph(case, title=f"Digraph - {case.name}"))
    if study.best is not None:
        fig(
            "digraph_optimal",
            plots.plot_digraph(
                case, design=study.best.design, title=f"Optimal design - {study.best.label}"
            ),
        )
    fig("costs", plots.plot_cost_comparison(study))
    fig("pump_curves", plots.plot_pump_curves(study))
    if not case.is_revamp:
        fig("system_schematic", plots.plot_system_schematic(case))
        fig("split_pipe", plots.plot_split_pipe(case))
        fig("solution_algorithm", plots.plot_solution_algorithm())
    for fname, df in {
        "costs": tables.cost_comparison_table(study),
        "design": tables.design_comparison_table(study),
        "mass_flows": tables.mass_flow_table(study),
        "pipe_lengths": tables.pipe_lengths_table(case),
        "pipe_catalog": tables.pipe_catalog_table(case),
        "pump_catalog": tables.pump_catalog_table(case),
        "parameters": tables.problem_parameters_table(case),
    }.items():
        path = out_dir / f"{name}_{fname}.md"
        path.write_text(df.to_markdown(index=False), encoding="utf-8")
        df.to_csv(out_dir / f"{name}_{fname}.csv", index=False)
        written.append(path)
    if study.best is not None and len(case.scenarios) > 1:
        path = out_dir / f"{name}_valves.md"
        tables.valve_table(study.best, case).to_markdown(path, index=False)
        written.append(path)
    return written
