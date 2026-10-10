"""Friction factor correlations."""

from __future__ import annotations

import numpy as np


def reynolds_number(density: float, viscosity: float, diameter, velocity):  # type: ignore[no-untyped-def]
    """Reynolds number ``Re = rho |v| D / mu`` (vectorized)."""
    return np.asarray(diameter) * np.abs(np.asarray(velocity)) * density / viscosity


def churchill_friction_factor(reynolds, relative_roughness):  # type: ignore[no-untyped-def]
    """Darcy friction factor by the Churchill (1977) correlation, valid for all regimes.

    ``f = 8 [ (8/Re)^12 + (A + B)^-1.5 ]^(1/12)`` with
    ``A = {2.457 ln[1 / ((7/Re)^0.9 + 0.27 e/D)]}^16`` and ``B = (37530/Re)^16``.
    """
    re = np.maximum(np.asarray(reynolds, dtype=float), 1e-12)
    eps = np.asarray(relative_roughness, dtype=float)
    a = (2.457 * np.log(1.0 / ((7.0 / re) ** 0.9 + 0.27 * eps))) ** 16
    b = (37530.0 / re) ** 16
    return 8.0 * ((8.0 / re) ** 12 + (a + b) ** -1.5) ** (1.0 / 12.0)


def fully_turbulent_friction_factor(relative_roughness):  # type: ignore[no-untyped-def]
    """Friction factor at very high Reynolds number (used for fittings, Crane method)."""
    return churchill_friction_factor(1e8, relative_roughness)
