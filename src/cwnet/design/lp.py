"""Split-pipe linear programming design for a given pump alternative (Eqs. 27-36).

For a fixed pump alternative ``s`` the problem is linear in the length fractions
``X_{p,n}`` (and in the valve head losses ``y_{h,m}`` for revamp / multi-scenario
problems)::

    min  sum_{p,n} C_PI[p,n] X[p,n]
    s.t. sum_n X[p,n] = 1                                   for every pipe p
         sum_p Lambda[l,p] sum_n F[m,p,n] X[p,n] + y[m,h(l)]
              = F_PU[m,s] + dz - F_HE[m,h(l)] - Fac[l]       for every circuit l, scenario m
         X[p,n] = 0  if the velocity limit is violated (n < n_min,p)
         0 <= X <= 1,  y >= 0
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.optimize import linprog

from cwnet.design.results import NetworkDesign
from cwnet.hydraulics.headloss import HydraulicTables
from cwnet.model import DesignCase, PipeStatus
from cwnet.topology.incidence import NetworkTopology


@dataclass
class LPProblem:
    """Matrices of the LP of one pump alternative (kept for inspection / post-processing)."""

    c: np.ndarray
    a_eq: np.ndarray
    b_eq: np.ndarray
    bounds: list[tuple[float, float | None]]
    n_x: int
    n_y: int
    n_pipes: int
    n_diameters: int
    allowed: np.ndarray


def allowed_subsections(case: DesignCase, hydraulics: HydraulicTables) -> np.ndarray:
    """Boolean matrix (S_PI x N_D) of the subsections admissible for each pipe.

    A subsection is excluded when its velocity exceeds the limit in any scenario
    (Eq. 24), when the pipe is fixed (only the installed diameter is admissible) or when
    an existing pipe may not be replaced by a smaller one.
    """
    v_max = case.options.max_velocity
    allowed = np.all(hydraulics.pipe_velocity < v_max, axis=0)
    catalog = case.pipe_catalog
    for i, pipe in enumerate(case.pipes):
        if pipe.status == PipeStatus.FIXED:
            allowed[i, :] = False
            allowed[i, catalog.index_of(pipe.diameter)] = True
        elif pipe.status == PipeStatus.EXISTING and not case.options.allow_downsizing_existing:
            allowed[i, : catalog.index_of(pipe.diameter)] = False
    return allowed


def build_lp(
    case: DesignCase,
    topology: NetworkTopology,
    hydraulics: HydraulicTables,
    cost_matrix: np.ndarray,
    pump_index: int,
) -> LPProblem:
    """Assemble the LP matrices for pump alternative ``pump_index``."""
    n_pi, n_d = cost_matrix.shape
    n_he = len(case.exchangers)
    n_sc = hydraulics.n_scenarios
    n_cir = topology.n_circuits
    allow_valves = case.options.allow_valves
    n_x = n_pi * n_d
    n_y = n_sc * n_he if allow_valves else 0
    allowed = allowed_subsections(case, hydraulics)

    c = np.concatenate([cost_matrix.ravel(), np.zeros(n_y)])

    rows_sum = np.zeros((n_pi, n_x + n_y))
    for p in range(n_pi):
        rows_sum[p, p * n_d : (p + 1) * n_d] = 1.0
    b_sum = np.ones(n_pi)

    lam_pi = topology.circuits_pipes  # (n_cir x n_pi)
    lam_he = topology.circuits_exchangers  # (n_cir x n_he)
    rows_hyd = np.zeros((n_sc * n_cir, n_x + n_y))
    b_hyd = np.zeros(n_sc * n_cir)
    for m in range(n_sc):
        # coefficients of X: Lambda_PI[l,p] * F[m,p,n]
        coef = lam_pi[:, :, None] * hydraulics.pipe_loss[m][None, :, :]  # (n_cir, n_pi, n_d)
        rows_hyd[m * n_cir : (m + 1) * n_cir, :n_x] = coef.reshape(n_cir, n_x)
        if allow_valves:
            rows_hyd[m * n_cir : (m + 1) * n_cir, n_x + m * n_he : n_x + (m + 1) * n_he] = lam_he
        b_hyd[m * n_cir : (m + 1) * n_cir] = (
            hydraulics.pump_head[m, pump_index]
            + hydraulics.elevation_term
            - lam_he @ hydraulics.exchanger_loss[m]
            - lam_pi @ hydraulics.pipe_fixed_loss
        )

    a_eq = np.vstack([rows_sum, rows_hyd])
    b_eq = np.concatenate([b_sum, b_hyd])
    bounds: list[tuple[float, float | None]] = []
    for p in range(n_pi):
        for n in range(n_d):
            bounds.append((0.0, 1.0) if allowed[p, n] else (0.0, 0.0))
    bounds.extend([(0.0, case.options.valve_max_head)] * n_y)
    return LPProblem(
        c=c,
        a_eq=a_eq,
        b_eq=b_eq,
        bounds=bounds,
        n_x=n_x,
        n_y=n_y,
        n_pipes=n_pi,
        n_diameters=n_d,
        allowed=allowed,
    )


def lp_design(
    case: DesignCase,
    topology: NetworkTopology,
    hydraulics: HydraulicTables,
    cost_matrix: np.ndarray,
    pump_index: int,
) -> NetworkDesign:
    """Solve the split-pipe LP for one pump alternative and return the network design."""
    problem = build_lp(case, topology, hydraulics, cost_matrix, pump_index)
    curve = case.pump_catalog[pump_index]
    result = linprog(
        problem.c,
        A_eq=problem.a_eq,
        b_eq=problem.b_eq,
        bounds=problem.bounds,
        method=case.options.lp_solver,
    )
    if not result.success:
        x = np.zeros((problem.n_pipes, problem.n_diameters))
        x[:, -1] = 1.0
        design = NetworkDesign.from_fraction_matrix(
            case,
            x,
            method="lp",
            pump_curve=curve.tag,
            feasible=False,
            message=f"LP infeasible for pump {curve.tag}: {result.message}",
        )
        design.extra["lp"] = problem
        return design

    z = result.x
    x = z[: problem.n_x].reshape(problem.n_pipes, problem.n_diameters)
    valves: dict[str, dict[str, float]] = {}
    if problem.n_y:
        y = z[problem.n_x :].reshape(hydraulics.n_scenarios, len(case.exchangers))
        for m, sc in enumerate(case.scenarios):
            valves[sc.name] = {
                he.tag: float(max(y[m, h], 0.0)) for h, he in enumerate(case.exchangers)
            }
    design = NetworkDesign.from_fraction_matrix(
        case,
        x,
        method="lp",
        pump_curve=curve.tag,
        valves=valves,
        lp_objective=float(result.fun),
    )
    design.extra["lp"] = problem
    design.extra["lp_raw_solution"] = z
    return design
