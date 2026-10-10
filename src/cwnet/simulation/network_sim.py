"""Rigorous steady-state simulation of an incompressible pipe network.

The unknowns are the edge mass flow rates ``k`` (kg/s), the node pressures ``p`` (bar)
and the external nodal flows ``w`` (kg/s). The model is the set of nodal mass balances,
the mechanical energy balance of every edge (pipes with one or more subsections, heat
exchangers with optional valves, pump) and the boundary specifications (pressure at the
supply and demand nodes, zero external flow elsewhere). It is solved by Newton's method
with a numerical Jacobian, starting from the solution of a linearized (laminar) model,
as in the original Scilab implementation; SciPy's root finder is used as fallback.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from scipy.optimize import root

from cwnet.constants import GRAVITY, PA_TO_BAR
from cwnet.design.results import NetworkDesign
from cwnet.hydraulics.headloss import pipe_head_loss, pipe_velocity
from cwnet.model import DesignCase
from cwnet.topology.incidence import NetworkTopology, build_topology
from cwnet.topology.massbalance import MassBalance


@dataclass
class SimulationResult:
    """Converged state of the network."""

    scenario: str
    edge_ids: list[int]
    node_ids: list[int]
    edge_flows: np.ndarray
    node_pressures: np.ndarray
    external_flows: np.ndarray
    pipe_flows: np.ndarray
    pipe_head_losses: np.ndarray
    pipe_velocities: list[list[float]]
    exchanger_flows: np.ndarray
    exchanger_head_losses: np.ndarray
    valve_head_losses: np.ndarray
    pump_flow: float
    pump_head: float
    converged: bool
    iterations: int
    residual_norm: float
    extra: dict = field(default_factory=dict)

    def pressure_at(self, node_id: int) -> float:
        return float(self.node_pressures[self.node_ids.index(node_id)])

    def flow_of(self, edge_id: int) -> float:
        return float(self.edge_flows[self.edge_ids.index(edge_id)])


@dataclass
class _Model:
    case: DesignCase
    topology: NetworkTopology
    design: NetworkDesign
    scenario: str
    z: np.ndarray
    spec_rows: np.ndarray
    spec_values: np.ndarray
    sub_diameters: list[np.ndarray]
    sub_lengths: list[np.ndarray]
    valves: np.ndarray

    @property
    def n(self) -> int:
        return self.topology.n_nodes

    @property
    def s(self) -> int:
        return self.topology.n_edges

    def split(self, x: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        s, n = self.s, self.n
        return x[:s], x[s : s + n], x[s + n : s + 2 * n]

    def pipe_losses(
        self, k_pi: np.ndarray, signed: bool = True
    ) -> tuple[np.ndarray, list[list[float]]]:
        fluid = self.case.fluid
        losses = np.zeros(len(self.case.pipes))
        velocities: list[list[float]] = []
        for i, pipe in enumerate(self.case.pipes):
            d, lengths = self.sub_diameters[i], self.sub_lengths[i]
            loss = pipe_head_loss(
                k_pi[i],
                d,
                lengths,
                density=fluid.density,
                viscosity=fluid.viscosity,
                roughness=pipe.roughness,
                fittings_ld=pipe.fittings_ld * lengths / max(pipe.length, 1e-12),
                signed=signed,
            )
            losses[i] = float(np.sum(loss)) + np.sign(k_pi[i]) * pipe.fixed_head_loss
            velocities.append(
                [float(v) for v in np.atleast_1d(pipe_velocity(k_pi[i], d, fluid.density))]
            )
        return losses, velocities

    def residuals(self, x: np.ndarray) -> np.ndarray:
        topo, case = self.topology, self.case
        k, p, w = self.split(x)
        rho_g = case.fluid.density * GRAVITY
        k_pi = topo.select_pipes @ k
        k_he = topo.select_exchangers @ k
        k_pu = float((topo.select_pump @ k)[0])
        curve = case.pump_curve(self.design.pump_curve)

        f_pi, _ = self.pipe_losses(k_pi)
        f_he = np.array([he.head_loss(k_he[h]) for h, he in enumerate(case.exchangers)])
        f_he = f_he + np.sign(k_he) * self.valves
        f_pu = float(curve.head_from_mass_flow(k_pu, case.fluid.density))

        k_pi_t, k_he_t, k_pu_t = topo.select_pipes.T, topo.select_exchangers.T, topo.select_pump.T
        kpi = topo.incidence @ k_pi_t  # (N x S_PI)
        khe = topo.incidence @ k_he_t
        kpu = topo.incidence @ k_pu_t
        zg = self.z * rho_g

        r_mass = topo.incidence @ k + w
        r_pi = kpi.T @ p + PA_TO_BAR * (rho_g * f_pi + kpi.T @ zg)
        r_he = khe.T @ p + PA_TO_BAR * (rho_g * f_he + khe.T @ zg)
        r_pu = kpu.T @ p + PA_TO_BAR * (-rho_g * f_pu + kpu.T @ zg)
        r_spec = self.spec_rows @ x - self.spec_values
        return np.concatenate([r_mass, r_pi, r_he, r_pu, r_spec])

    def laminar_guess(self) -> np.ndarray:
        """Solve the linearized model (laminar pipes, linear exchangers, constant pump head)."""
        topo, case = self.topology, self.case
        fluid = case.fluid
        rho_g = fluid.density * GRAVITY
        s, n = self.s, self.n
        kpi = topo.incidence @ topo.select_pipes.T
        khe = topo.incidence @ topo.select_exchangers.T
        kpu = topo.incidence @ topo.select_pump.T
        zg = self.z * rho_g
        # pipe: dP = 128 mu L k / (pi rho D^4) per subsection
        f_pi = np.zeros(len(case.pipes))
        for i in range(len(case.pipes)):
            d, lengths = self.sub_diameters[i], self.sub_lengths[i]
            f_pi[i] = float(
                np.sum(128.0 * fluid.viscosity * lengths / (np.pi * fluid.density * d**4))
            )
        f_he = np.array(
            [
                rho_g * (he.design_head_loss + self.valves[h]) / he.design_flow
                for h, he in enumerate(case.exchangers)
            ]
        )
        curve = case.pump_curve(self.design.pump_curve)
        h0 = float(curve.coefficients[0])
        n_pi, n_he, n_pu = len(case.pipes), len(case.exchangers), 1
        a = np.zeros((s + 2 * n, s + 2 * n))
        b = np.zeros(s + 2 * n)
        row = 0
        a[row : row + n, :s] = topo.incidence
        a[row : row + n, s + n :] = np.eye(n)
        row += n
        a[row : row + n_pi, :s] = PA_TO_BAR * np.diag(f_pi) @ topo.select_pipes
        a[row : row + n_pi, s : s + n] = kpi.T
        b[row : row + n_pi] = -PA_TO_BAR * (kpi.T @ zg)
        row += n_pi
        a[row : row + n_he, :s] = PA_TO_BAR * np.diag(f_he) @ topo.select_exchangers
        a[row : row + n_he, s : s + n] = khe.T
        b[row : row + n_he] = -PA_TO_BAR * (khe.T @ zg)
        row += n_he
        a[row : row + n_pu, s : s + n] = kpu.T
        b[row : row + n_pu] = PA_TO_BAR * (rho_g * h0 - (kpu.T @ zg))
        row += n_pu
        a[row:, :] = self.spec_rows
        b[row:] = self.spec_values
        return np.linalg.solve(a, b)


def _build_model(
    case: DesignCase, design: NetworkDesign, topology: NetworkTopology, scenario: str
) -> _Model:
    net = case.network
    n, s = topology.n_nodes, topology.n_edges
    z = np.array([net.node(i).elevation for i in topology.node_ids])
    spec_rows = np.zeros((n, s + 2 * n))
    spec_values = np.zeros(n)
    supply, demand = topology.supply_node, topology.demand_node
    for i, node_id in enumerate(topology.node_ids):
        node = net.node(node_id)
        if node.pressure is not None or node_id in (supply, demand):
            spec_rows[i, s + i] = 1.0
            spec_values[i] = node.pressure or 0.0
        else:
            spec_rows[i, s + n + i] = 1.0
            spec_values[i] = 0.0
    catalog = case.pipe_catalog
    sub_d, sub_l = [], []
    for pipe in case.pipes:
        subs = design.pipes[pipe.edge].subsections
        sub_d.append(np.array([catalog.sizes[idx].inner_diameter for idx, _ in subs]))
        sub_l.append(np.array([pipe.length * frac for _, frac in subs]))
    valves = np.array([design.valve_head(scenario, he.tag) for he in case.exchangers])
    return _Model(case, topology, design, scenario, z, spec_rows, spec_values, sub_d, sub_l, valves)


def _newton(
    model: _Model, x0: np.ndarray, tol: float, max_iter: int
) -> tuple[np.ndarray, bool, int, float]:
    x = x0.copy()
    f = model.residuals(x)
    res = float(np.linalg.norm(f))
    it = 0
    while res > tol and it < max_iter:
        jac = np.zeros((len(f), len(x)))
        for j in range(len(x)):
            h = 1e-6 * abs(x[j]) + 1e-9
            xp, xm = x.copy(), x.copy()
            xp[j] += h
            xm[j] -= h
            jac[:, j] = (model.residuals(xp) - model.residuals(xm)) / (2.0 * h)
        try:
            dx = np.linalg.solve(jac, f)
        except np.linalg.LinAlgError:
            dx = np.linalg.lstsq(jac, f, rcond=None)[0]
        x = x - dx
        f = model.residuals(x)
        res = float(np.linalg.norm(f))
        it += 1
        if not np.all(np.isfinite(x)):
            return x, False, it, float("inf")
    return x, res <= tol, it, res


def simulate_design(
    case: DesignCase,
    design: NetworkDesign,
    topology: NetworkTopology | None = None,
    scenario: str | None = None,
) -> SimulationResult:
    """Simulate the operation of a designed network (flows, pressures, heads).

    ``scenario`` selects the valve settings of the design (multi-scenario problems).
    """
    topology = topology or build_topology(case)
    scenario = scenario or case.scenarios[0].name
    model = _build_model(case, design, topology, scenario)
    x0 = model.laminar_guess()
    x, ok, it, res = _newton(
        model, x0, case.options.simulation_tolerance, case.options.simulation_max_iterations
    )
    if not ok:
        sol = root(model.residuals, x0, method="hybr", options={"xtol": 1e-12, "maxfev": 20000})
        x2 = sol.x
        res2 = float(np.linalg.norm(model.residuals(x2)))
        if res2 < res:
            x, res = x2, res2
            ok = res <= max(case.options.simulation_tolerance, 1e-7)
    return _collect(model, x, ok, it, res)


def _collect(model: _Model, x: np.ndarray, ok: bool, it: int, res: float) -> SimulationResult:
    topo, case = model.topology, model.case
    k, p, w = model.split(x)
    k_pi = topo.select_pipes @ k
    k_he = topo.select_exchangers @ k
    k_pu = float((topo.select_pump @ k)[0])
    losses, velocities = model.pipe_losses(k_pi)
    curve = case.pump_curve(model.design.pump_curve)
    f_he = np.array([float(he.head_loss(k_he[h])) for h, he in enumerate(case.exchangers)])
    return SimulationResult(
        scenario=model.scenario,
        edge_ids=list(topo.edge_ids),
        node_ids=list(topo.node_ids),
        edge_flows=k,
        node_pressures=p,
        external_flows=w,
        pipe_flows=k_pi,
        pipe_head_losses=losses,
        pipe_velocities=velocities,
        exchanger_flows=k_he,
        exchanger_head_losses=f_he,
        valve_head_losses=model.valves.copy(),
        pump_flow=k_pu,
        pump_head=float(curve.head_from_mass_flow(k_pu, case.fluid.density)),
        converged=ok,
        iterations=it,
        residual_norm=res,
    )


def design_point_simulation(
    case: DesignCase,
    design: NetworkDesign,
    topology: NetworkTopology,
    mb: MassBalance,
    scenario: str,
) -> SimulationResult:
    """Pseudo-simulation that assumes the specified flows (no pressure solution)."""
    model = _build_model(case, design, topology, scenario)
    losses, velocities = model.pipe_losses(mb.pipe_flows)
    curve = case.pump_curve(design.pump_curve)
    f_he = np.array(
        [float(he.head_loss(mb.exchanger_flows[h])) for h, he in enumerate(case.exchangers)]
    )
    return SimulationResult(
        scenario=scenario,
        edge_ids=list(topology.edge_ids),
        node_ids=list(topology.node_ids),
        edge_flows=mb.edge_flows,
        node_pressures=np.full(topology.n_nodes, np.nan),
        external_flows=np.zeros(topology.n_nodes),
        pipe_flows=mb.pipe_flows,
        pipe_head_losses=losses,
        pipe_velocities=velocities,
        exchanger_flows=mb.exchanger_flows,
        exchanger_head_losses=f_he,
        valve_head_losses=model.valves.copy(),
        pump_flow=mb.pump_flow,
        pump_head=float(curve.head_from_mass_flow(mb.pump_flow, case.fluid.density)),
        converged=True,
        iterations=0,
        residual_norm=0.0,
    )
