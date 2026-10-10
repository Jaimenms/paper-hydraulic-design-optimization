"""Evaluation of a design: rigorous simulation, thermal check and costs."""

from __future__ import annotations

import numpy as np

from cwnet.costs.pumps import pump_capital_cost, pump_operating_cost
from cwnet.design.results import CostBreakdown, DesignEvaluation, NetworkDesign, ScenarioEvaluation
from cwnet.model import DesignCase
from cwnet.simulation.network_sim import simulate_design
from cwnet.simulation.thermal import thermal_check
from cwnet.topology.incidence import NetworkTopology
from cwnet.topology.massbalance import MassBalance


def pump_rated_point(
    case: DesignCase, curve_tag: str, balances: list[MassBalance]
) -> tuple[float, float]:
    """Rated mass flow (kg/s) and head (m) used for the pump capital cost."""
    curve = case.pump_curve(curve_tag)
    if curve.rated_flow is not None:
        k_rated = curve.rated_flow * case.fluid.density
    else:
        k_rated = max(mb.pump_flow for mb in balances)
    return k_rated, float(curve.head_from_mass_flow(k_rated, case.fluid.density))


def pump_capital(case: DesignCase, curve_tag: str, balances: list[MassBalance]) -> float:
    """Installed pump cost (USD); zero when the existing pump is kept."""
    if case.pump.existing and case.pump.curve == curve_tag:
        return 0.0
    k_rated, head_rated = pump_rated_point(case, curve_tag, balances)
    return pump_capital_cost(k_rated, head_rated, case.fluid.density, case.economics.pump_cost)


def pipe_capital(case: DesignCase, design: NetworkDesign, cost_matrix: np.ndarray) -> float:
    """Investment in pipes (USD): sum of the subsection costs (zero for kept existing pipes)."""
    x = design.fraction_matrix(case)
    return float(np.sum(cost_matrix * x))


def evaluate_design(
    case: DesignCase,
    topology: NetworkTopology,
    balances: list[MassBalance],
    design: NetworkDesign,
    cost_matrix: np.ndarray,
    label: str = "",
    simulate: bool = True,
) -> DesignEvaluation:
    """Simulate the design in every scenario and compute the cost breakdown.

    The operating cost uses the simulated operating point of the pump, so unbalanced
    designs (e.g. the traditional one) are charged for the flow they actually deliver.
    """
    curve = case.pump_curve(design.pump_curve)
    evaluations: list[ScenarioEvaluation] = []
    for sc, mb in zip(case.scenarios, balances, strict=True):
        if simulate:
            sim = simulate_design(case, design, topology=topology, scenario=sc.name)
            k_pu, head = sim.pump_flow, sim.pump_head
        else:  # pragma: no cover - only for quick cost screening
            from cwnet.simulation.network_sim import design_point_simulation

            sim = design_point_simulation(case, design, topology, mb, sc.name)
            k_pu, head = (
                mb.pump_flow,
                float(curve.head_from_mass_flow(mb.pump_flow, case.fluid.density)),
            )
        thermal = (
            thermal_check(case, sim.exchanger_flows)
            if any(h.thermal is not None for h in case.exchangers)
            else None
        )
        op_cost = pump_operating_cost(k_pu, head, curve.efficiency, case.economics)
        evaluations.append(
            ScenarioEvaluation(
                scenario=sc.name,
                time_fraction=sc.time_fraction,
                simulation=sim,
                thermal=thermal,
                pump_flow=k_pu,
                pump_head=head,
                operating_cost=op_cost,
                specified_exchanger_flows=mb.exchanger_flows.copy(),
            )
        )
    operating = sum(e.operating_cost * e.time_fraction for e in evaluations)
    costs = CostBreakdown(
        pipe_capital=pipe_capital(case, design, cost_matrix),
        pump_capital=pump_capital(case, design.pump_curve, balances),
        operating=float(operating),
        operating_by_scenario=[e.operating_cost for e in evaluations],
        annualizing_factor=case.economics.annualizing_factor,
        basis=case.economics.objective_basis,
    )
    return DesignEvaluation(design=design, scenarios=evaluations, costs=costs, label=label)
