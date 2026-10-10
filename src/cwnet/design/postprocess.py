"""Optional quadratic-programming post-processing of an LP design.

The LP optimum is usually not unique. Among the solutions with the same cost there may
be designs with fewer split pipes. Following Section 5.1 of the submitted manuscript
(removed from the published version), the post-processing maximizes
``sum X^2`` (which pushes the fractions towards 0/1) subject to the original constraints
and to the cost not exceeding the LP optimum. The problem is non-convex, so a local
solution started from the LP vertex is returned, and the LP design is kept whenever the
post-processing fails or does not reduce the number of split pipes.
"""

from __future__ import annotations

import numpy as np
from scipy.optimize import minimize

from cwnet.design.lp import LPProblem
from cwnet.design.results import NetworkDesign
from cwnet.model import DesignCase


def qp_simplify(case: DesignCase, design: NetworkDesign) -> NetworkDesign:
    problem: LPProblem | None = design.extra.get("lp")
    z0: np.ndarray | None = design.extra.get("lp_raw_solution")
    if problem is None or z0 is None or not design.feasible:
        return design
    n_x = problem.n_x
    cost_star = float(problem.c @ z0)

    def objective(z: np.ndarray) -> float:
        return -float(np.sum(z[:n_x] ** 2)) / problem.n_pipes

    def gradient(z: np.ndarray) -> np.ndarray:
        g = np.zeros_like(z)
        g[:n_x] = -2.0 * z[:n_x] / problem.n_pipes
        return g

    constraints = [
        {
            "type": "eq",
            "fun": lambda z: problem.a_eq @ z - problem.b_eq,
            "jac": lambda z: problem.a_eq,
        },
        {
            "type": "ineq",
            "fun": lambda z: cost_star - problem.c @ z + 1e-6 * max(1.0, abs(cost_star)),
            "jac": lambda z: -problem.c,
        },
    ]
    bounds = [(lo, hi if hi is not None else 1e6) for lo, hi in problem.bounds]
    try:
        res = minimize(
            objective,
            z0,
            jac=gradient,
            bounds=bounds,
            constraints=constraints,
            method="SLSQP",
            options={"maxiter": 500, "ftol": 1e-12},
        )
    except Exception:  # pragma: no cover - defensive
        return design
    if not res.success:
        return design
    z = res.x
    if np.max(np.abs(problem.a_eq @ z - problem.b_eq)) > 1e-6:
        return design
    x = z[:n_x].reshape(problem.n_pipes, problem.n_diameters)
    valves: dict[str, dict[str, float]] = {}
    if problem.n_y:
        y = z[n_x:].reshape(len(case.scenarios), len(case.exchangers))
        for m, sc in enumerate(case.scenarios):
            valves[sc.name] = {
                he.tag: float(max(y[m, h], 0.0)) for h, he in enumerate(case.exchangers)
            }
    candidate = NetworkDesign.from_fraction_matrix(
        case,
        x,
        method="lp+qp",
        pump_curve=design.pump_curve,
        valves=valves,
        lp_objective=float(problem.c @ z),
    )
    candidate.extra.update(design.extra)
    if candidate.n_split_pipes < design.n_split_pipes:
        return candidate
    return design
