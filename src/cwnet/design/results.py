"""Result containers of the design algorithms."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

import numpy as np

from cwnet.model import DesignCase
from cwnet.model.pipes import nominal_label

if TYPE_CHECKING:  # pragma: no cover
    from cwnet.hydraulics.headloss import HydraulicTables
    from cwnet.simulation.network_sim import SimulationResult
    from cwnet.simulation.thermal import ThermalResult
    from cwnet.topology.incidence import NetworkTopology
    from cwnet.topology.massbalance import MassBalance


@dataclass
class PipeDesign:
    """Diameters of one pipe section as (catalogue index, length fraction) subsections."""

    edge: int
    subsections: list[tuple[int, float]]

    @property
    def is_split(self) -> bool:
        return len(self.subsections) > 1

    def labels(self, case: DesignCase) -> list[str]:
        return [case.pipe_catalog.sizes[i].label for i, _ in self.subsections]

    def nominal(self, case: DesignCase) -> list[float]:
        return [case.pipe_catalog.sizes[i].nominal for i, _ in self.subsections]

    def fractions(self) -> list[float]:
        return [f for _, f in self.subsections]

    def describe(self, case: DesignCase, sep: str = "/") -> tuple[str, str]:
        """Return ``("8/10", "0.399/0.601")`` like Table IX of the paper."""
        labels = sep.join(self.labels(case))
        fracs = sep.join(f"{f:.3f}" for f in self.fractions())
        return labels, fracs


@dataclass
class NetworkDesign:
    """A complete network design: pump alternative, pipe diameters and valve settings."""

    method: str
    pump_curve: str
    pipes: dict[int, PipeDesign]
    valves: dict[str, dict[str, float]] = field(default_factory=dict)
    feasible: bool = True
    message: str = ""
    fractions: np.ndarray | None = None
    required_pump_head: float | None = None
    lp_objective: float | None = None
    extra: dict[str, Any] = field(default_factory=dict)

    @property
    def n_split_pipes(self) -> int:
        return sum(1 for p in self.pipes.values() if p.is_split)

    def valve_head(self, scenario: str, exchanger_tag: str) -> float:
        return self.valves.get(scenario, {}).get(exchanger_tag, 0.0)

    def fraction_matrix(self, case: DesignCase) -> np.ndarray:
        """Length fraction matrix ``X`` (S_PI x N_D) rebuilt from the subsections."""
        x = np.zeros((len(case.pipes), len(case.pipe_catalog)))
        for i, pipe in enumerate(case.pipes):
            for n, frac in self.pipes[pipe.edge].subsections:
                x[i, n] = frac
        return x

    @staticmethod
    def from_fraction_matrix(
        case: DesignCase,
        x: np.ndarray,
        method: str,
        pump_curve: str,
        valves: dict[str, dict[str, float]] | None = None,
        tol: float = 1e-6,
        **extra: Any,
    ) -> NetworkDesign:
        """Build the design from a fraction matrix, dropping negligible subsections."""
        x = np.array(x, dtype=float)
        x[x < tol] = 0.0
        x[x > 1.0 - tol] = 1.0
        pipes: dict[int, PipeDesign] = {}
        for i, pipe in enumerate(case.pipes):
            row = x[i]
            total = row.sum()
            if total <= 0:
                raise ValueError(f"pipe {pipe.edge} has no diameter assigned")
            row = row / total
            subs = [(int(n), float(row[n])) for n in np.nonzero(row)[0]]
            pipes[pipe.edge] = PipeDesign(edge=pipe.edge, subsections=subs)
            x[i] = row
        return NetworkDesign(
            method=method,
            pump_curve=pump_curve,
            pipes=pipes,
            valves=valves or {},
            fractions=x,
            **extra,
        )

    def diameter_label(self, case: DesignCase, edge: int) -> str:
        return self.pipes[edge].describe(case)[0]


@dataclass
class CostBreakdown:
    """Cost components of an evaluated design (USD and USD/year)."""

    pipe_capital: float
    pump_capital: float
    operating: float
    operating_by_scenario: list[float]
    annualizing_factor: float
    basis: str = "published"

    @property
    def pipe_capital_annualized(self) -> float:
        return self.annualizing_factor * self.pipe_capital

    @property
    def pump_capital_annualized(self) -> float:
        return self.annualizing_factor * self.pump_capital

    @property
    def total_published(self) -> float:
        """Total used in the published tables: operating + r*pump capital + pipe capital."""
        return self.operating + self.pump_capital_annualized + self.pipe_capital

    @property
    def total_annualized(self) -> float:
        """Fully annualized total: operating + r*(pump capital + pipe capital)."""
        return self.operating + self.pump_capital_annualized + self.pipe_capital_annualized

    @property
    def total(self) -> float:
        return self.total_annualized if self.basis == "annualized" else self.total_published

    def as_dict(self) -> dict[str, float]:
        return {
            "total": self.total,
            "operating": self.operating,
            "pump_capital_annualized": self.pump_capital_annualized,
            "pipe_capital": self.pipe_capital,
            "pump_capital": self.pump_capital,
            "pipe_capital_annualized": self.pipe_capital_annualized,
            "total_published": self.total_published,
            "total_annualized": self.total_annualized,
        }


@dataclass
class ScenarioEvaluation:
    """Simulated behaviour of a design in one scenario."""

    scenario: str
    time_fraction: float
    simulation: SimulationResult
    thermal: ThermalResult | None
    pump_flow: float
    pump_head: float
    operating_cost: float
    specified_exchanger_flows: np.ndarray

    @property
    def exchanger_flows(self) -> np.ndarray:
        return self.simulation.exchanger_flows

    @property
    def max_flow_deviation(self) -> float:
        """Largest relative deviation between simulated and specified exchanger flows."""
        spec = self.specified_exchanger_flows
        return float(np.max(np.abs(self.exchanger_flows - spec) / np.maximum(spec, 1e-12)))


@dataclass
class DesignEvaluation:
    """A design together with its simulation and cost evaluation."""

    design: NetworkDesign
    scenarios: list[ScenarioEvaluation]
    costs: CostBreakdown
    label: str = ""

    @property
    def feasible(self) -> bool:
        return self.design.feasible

    @property
    def hydraulically_balanced(self) -> bool:
        return all(s.max_flow_deviation < 1e-3 for s in self.scenarios)


@dataclass
class DesignStudy:
    """All the results of a design study (traditional and LP designs for every pump)."""

    case: DesignCase
    topology: NetworkTopology
    balances: list[MassBalance]
    hydraulics: HydraulicTables
    cost_matrix: np.ndarray
    traditional: dict[str, DesignEvaluation]
    lp: list[DesignEvaluation]
    best: DesignEvaluation | None

    @property
    def feasible_lp(self) -> list[DesignEvaluation]:
        return [e for e in self.lp if e.feasible]

    def lp_for_pump(self, tag: str) -> DesignEvaluation:
        for e in self.lp:
            if e.design.pump_curve == tag:
                return e
        raise KeyError(tag)


def nominal_text(value: float) -> str:
    return nominal_label(value)
