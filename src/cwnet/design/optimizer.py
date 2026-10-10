"""Orchestration of a complete design study (Figure 4 of Souza et al., 2014)."""

from __future__ import annotations

import logging
from collections.abc import Iterable

from cwnet.costs.pipes import pipe_cost_matrix
from cwnet.design.evaluate import evaluate_design
from cwnet.design.lp import lp_design
from cwnet.design.postprocess import qp_simplify
from cwnet.design.results import DesignEvaluation, DesignStudy, NetworkDesign
from cwnet.design.traditional import traditional_design
from cwnet.hydraulics.headloss import build_hydraulic_tables
from cwnet.model import DesignCase
from cwnet.topology.incidence import build_topology
from cwnet.topology.massbalance import solve_all_scenarios

log = logging.getLogger(__name__)


def run_design_study(
    case: DesignCase,
    traditional_methods: Iterable[str] | None = None,
    pumps: Iterable[str] | None = None,
    simulate: bool = True,
) -> DesignStudy:
    """Run the complete study: mass balance, traditional designs, LP for every pump.

    Parameters
    ----------
    case:
        The design case.
    traditional_methods:
        Economic-velocity rules to evaluate (``"edgar_himmelblau"``, ``"towler"``);
        defaults to the method of ``case.options``.
    pumps:
        Tags of the pump alternatives to optimize (default: all of the catalogue).
    simulate:
        Evaluate each design with the rigorous simulation (recommended).
    """
    topology = build_topology(case)
    balances = solve_all_scenarios(case, topology)
    hydraulics = build_hydraulic_tables(case, balances)
    cost_matrix = pipe_cost_matrix(case)

    methods = (
        list(traditional_methods)
        if traditional_methods is not None
        else [case.options.traditional_method]
    )
    traditional: dict[str, DesignEvaluation] = {}
    for method in methods:
        design = traditional_design(case, topology, hydraulics, balances, method)
        traditional[method] = evaluate_design(
            case,
            topology,
            balances,
            design,
            cost_matrix,
            label=f"Traditional ({method})",
            simulate=simulate,
        )

    pump_tags = list(pumps) if pumps is not None else [c.tag for c in case.pump_catalog]
    lp_results: list[DesignEvaluation] = []
    for s, curve in enumerate(case.pump_catalog):
        if curve.tag not in pump_tags:
            continue
        design = lp_design(case, topology, hydraulics, cost_matrix, s)
        if design.feasible and case.options.qp_postprocess:
            design = qp_simplify(case, design)
        if not design.feasible:
            log.info("pump %s: %s", curve.tag, design.message)
            lp_results.append(_infeasible_evaluation(design, case))
            continue
        lp_results.append(
            evaluate_design(
                case,
                topology,
                balances,
                design,
                cost_matrix,
                label=f"Proposed / {curve.tag}",
                simulate=simulate,
            )
        )
    feasible = [e for e in lp_results if e.feasible]
    best = min(feasible, key=lambda e: e.costs.total) if feasible else None
    return DesignStudy(
        case=case,
        topology=topology,
        balances=balances,
        hydraulics=hydraulics,
        cost_matrix=cost_matrix,
        traditional=traditional,
        lp=lp_results,
        best=best,
    )


def _infeasible_evaluation(design: NetworkDesign, case: DesignCase) -> DesignEvaluation:
    from cwnet.design.results import CostBreakdown

    costs = CostBreakdown(
        pipe_capital=float("nan"),
        pump_capital=float("nan"),
        operating=float("nan"),
        operating_by_scenario=[],
        annualizing_factor=case.economics.annualizing_factor,
        basis=case.economics.objective_basis,
    )
    return DesignEvaluation(
        design=design, scenarios=[], costs=costs, label=f"Proposed / {design.pump_curve}"
    )


def optimize_network(case: DesignCase) -> DesignEvaluation:
    """Shortcut returning only the best LP design of the study."""
    study = run_design_study(case, traditional_methods=[])
    if study.best is None:
        raise RuntimeError("no feasible design was found for any pump alternative")
    return study.best
