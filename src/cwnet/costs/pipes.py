"""Pipe capital costs (Narang et al., 2009), Eq. (17), and the revamp cost matrix (Eq. 34)."""

from __future__ import annotations

import numpy as np

from cwnet.constants import FOOT
from cwnet.model import DesignCase, PipeStatus
from cwnet.model.economics import PipeCostModel


def pipe_unit_cost(nominal_inches, model: PipeCostModel):  # type: ignore[no-untyped-def]
    """Installed cost per metre (USD/m) of a pipe of nominal diameter ``D_nom`` (in)."""
    dn = np.asarray(nominal_inches, dtype=float)
    return model.c1 / FOOT * (dn / 12.0) ** model.m


def pipe_cost_matrix(case: DesignCase) -> np.ndarray:
    """Capital cost (USD) of each pipe section ``p`` built entirely with diameter ``n``.

    For existing pipe sections the entry of the installed diameter is zero (keeping the
    pipe costs nothing), which turns the vector ``c_PI`` of the grassroots problem into
    the matrix ``C_PI`` of the revamp problem (Eq. 34).
    """
    unit = pipe_unit_cost(case.pipe_catalog.nominal, case.economics.pipe_cost)
    lengths = np.array([p.length for p in case.pipes])
    cost = lengths[:, None] * unit[None, :]
    for i, pipe in enumerate(case.pipes):
        if pipe.status in (PipeStatus.EXISTING, PipeStatus.FIXED):
            cost[i, case.pipe_catalog.index_of(pipe.diameter)] = 0.0
    return cost
