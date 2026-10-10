"""Network mass balance (Eqs. 4-9 of Souza et al., 2014)."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from cwnet.model import DesignCase, Scenario
from cwnet.topology.incidence import NetworkTopology


@dataclass
class MassBalance:
    """Mass flow rates (kg/s) of all edges for one scenario."""

    scenario: str
    edge_flows: np.ndarray
    supply_flow: float
    demand_flow: float
    pipe_flows: np.ndarray
    pump_flow: float
    exchanger_flows: np.ndarray
    supply_node: int
    demand_node: int
    time_fraction: float = 1.0

    def flow_of_edge(self, topology: NetworkTopology, edge_id: int) -> float:
        return float(self.edge_flows[topology.edge_index(edge_id)])


def solve_mass_balance(
    case: DesignCase, topology: NetworkTopology, scenario: Scenario
) -> MassBalance:
    """Solve Eq. (6) for the edge flows and the external supply/demand flows."""
    k, u_ps, u_pd = topology.incidence, topology.u_supply, topology.u_demand
    spec = topology.specification
    n, s = k.shape
    n_e = spec.shape[0]
    e = np.asarray(case.scenario_flows(scenario), dtype=float)
    big = np.block([[k, u_ps[:, None], -u_pd[:, None]], [spec, np.zeros((n_e, 2))]])
    rhs = np.concatenate([np.zeros(n), e])
    x = np.linalg.solve(big, rhs)
    flows = x[:s]
    return MassBalance(
        scenario=scenario.name,
        edge_flows=flows,
        supply_flow=float(x[s]),
        demand_flow=float(x[s + 1]),
        pipe_flows=topology.select_pipes @ flows,
        pump_flow=float((topology.select_pump @ flows)[0]),
        exchanger_flows=topology.select_exchangers @ flows,
        supply_node=topology.supply_node,
        demand_node=topology.demand_node,
        time_fraction=scenario.time_fraction,
    )


def solve_all_scenarios(case: DesignCase, topology: NetworkTopology) -> list[MassBalance]:
    return [solve_mass_balance(case, topology, sc) for sc in case.scenarios]
