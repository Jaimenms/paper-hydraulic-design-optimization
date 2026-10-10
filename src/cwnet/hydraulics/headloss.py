"""Head losses of pipes, heat exchangers and pumps, organised per scenario.

All head losses are expressed in metres of fluid column.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from cwnet.constants import GRAVITY
from cwnet.hydraulics.friction import (
    churchill_friction_factor,
    fully_turbulent_friction_factor,
    reynolds_number,
)
from cwnet.model import DesignCase
from cwnet.topology.massbalance import MassBalance


def pipe_velocity(mass_flow, diameter, density: float):  # type: ignore[no-untyped-def]
    """Mean velocity (m/s) of a mass flow (kg/s) in a circular pipe of inner diameter (m)."""
    area = np.pi * np.asarray(diameter, dtype=float) ** 2 / 4.0
    return np.asarray(mass_flow, dtype=float) / density / area


def pipe_head_loss(  # type: ignore[no-untyped-def]
    mass_flow,
    diameter,
    length,
    *,
    density: float,
    viscosity: float,
    roughness,
    fittings_ld=0.0,
    signed: bool = False,
):
    """Darcy-Weisbach head loss (m) of a pipe (or subsection) of given length.

    ``F = (f L/D + f_T (L/D)_fittings) v^2 / (2 g)``; when ``signed`` the loss carries the
    sign of the flow (``|v| v``), as needed by the simulation residuals.
    """
    v = pipe_velocity(mass_flow, diameter, density)
    re = reynolds_number(density, viscosity, diameter, v)
    rel = np.asarray(roughness, dtype=float) / np.asarray(diameter, dtype=float)
    f = churchill_friction_factor(re, rel)
    f_t = fully_turbulent_friction_factor(rel)
    ld = np.asarray(length, dtype=float) / np.asarray(diameter, dtype=float)
    kinetic = np.abs(v) * v if signed else v**2
    return 0.5 * (f * ld + f_t * np.asarray(fittings_ld, dtype=float)) * kinetic / GRAVITY


@dataclass
class HydraulicTables:
    """Head losses and velocities of every element, for every scenario and pump alternative.

    Shapes (``n_sc`` scenarios, ``n_pi`` pipes, ``n_d`` catalogue diameters, ``n_he``
    exchangers, ``n_pu`` pump alternatives):

    * ``pipe_loss[m, p, n]``: head loss of pipe ``p`` with diameter ``n`` in scenario ``m``,
      for its full length and fittings (m) - the coefficients ``F_PI,p,n L_p`` of Eq. (23);
    * ``pipe_velocity[m, p, n]``: corresponding velocity (m/s);
    * ``exchanger_loss[m, h]``: heat exchanger head loss, Eq. (14);
    * ``pump_head[m, s]``: head of pump alternative ``s`` at the scenario total flow;
    * ``pipe_fixed_loss[p]``: fixed localized losses of the pipes (m).
    """

    pipe_loss: np.ndarray
    pipe_velocity: np.ndarray
    exchanger_loss: np.ndarray
    pump_head: np.ndarray
    pipe_fixed_loss: np.ndarray
    elevation_term: float

    @property
    def n_scenarios(self) -> int:
        return self.pipe_loss.shape[0]


def build_hydraulic_tables(case: DesignCase, balances: list[MassBalance]) -> HydraulicTables:
    """Evaluate all head-loss coefficients needed by the design problem."""
    fluid = case.fluid
    d_in = np.asarray(case.pipe_catalog.inner_diameters)
    n_sc, n_pi, n_d = len(balances), len(case.pipes), len(d_in)
    n_he, n_pu = len(case.exchangers), len(case.pump_catalog)

    pipe_loss = np.zeros((n_sc, n_pi, n_d))
    pipe_vel = np.zeros((n_sc, n_pi, n_d))
    he_loss = np.zeros((n_sc, n_he))
    pump_head = np.zeros((n_sc, n_pu))
    fixed = np.array([p.fixed_head_loss for p in case.pipes], dtype=float)

    for m, mb in enumerate(balances):
        for p, pipe in enumerate(case.pipes):
            k = mb.pipe_flows[p]
            pipe_vel[m, p, :] = pipe_velocity(k, d_in, fluid.density)
            pipe_loss[m, p, :] = pipe_head_loss(
                k,
                d_in,
                pipe.length,
                density=fluid.density,
                viscosity=fluid.viscosity,
                roughness=pipe.roughness,
                fittings_ld=pipe.fittings_ld,
            )
        for h, he in enumerate(case.exchangers):
            he_loss[m, h] = float(he.head_loss(mb.exchanger_flows[h]))
        for s, curve in enumerate(case.pump_catalog):
            pump_head[m, s] = float(curve.head_from_mass_flow(mb.pump_flow, fluid.density))

    supply = case.network.node(mb.supply_node)
    demand = case.network.node(mb.demand_node)

    def head_of(node):  # type: ignore[no-untyped-def]
        return node.elevation + 1e5 * (node.pressure or 0.0) / (fluid.density * GRAVITY)

    delta_z = head_of(supply) - head_of(demand)
    return HydraulicTables(
        pipe_loss=pipe_loss,
        pipe_velocity=pipe_vel,
        exchanger_loss=he_loss,
        pump_head=pump_head,
        pipe_fixed_loss=fixed,
        elevation_term=delta_z,
    )
