"""cwnet - hydraulic design optimization of cooling water pipe networks.

The package implements the matrix formulation of Souza et al. (2014,
Chem. Eng. Comm. 201:1054-1076) and its multi-scenario extension
(Costa, Tonassi & Souza, 2016, Chem. Eng. Trans. 52) in Python:

* network topology (incidence, selection and hydraulic-circuit matrices),
* mass balance of the digraph,
* split-pipe linear programming design for each pump alternative
  (grassroots, revamp and multi-scenario problems),
* traditional (economic velocity) designs for comparison,
* rigorous steady-state simulation of the designed network and
  effectiveness-NTU thermal verification of the heat exchangers,
* cost evaluation and reporting helpers (tables and figures).
"""

from cwnet.design.optimizer import run_design_study
from cwnet.design.results import DesignStudy, NetworkDesign
from cwnet.io.yaml_io import load_case, save_case
from cwnet.model import (
    DesignCase,
    DesignOptions,
    Economics,
    Edge,
    Fluid,
    HeatExchanger,
    Network,
    Node,
    PipeCatalog,
    PipeSection,
    PipeSize,
    PipeStatus,
    PumpCurve,
    PumpUnit,
    Scenario,
    ThermalDesign,
)
from cwnet.simulation.network_sim import simulate_design

__all__ = [
    "DesignCase",
    "DesignOptions",
    "DesignStudy",
    "Economics",
    "Edge",
    "Fluid",
    "HeatExchanger",
    "Network",
    "NetworkDesign",
    "Node",
    "PipeCatalog",
    "PipeSection",
    "PipeSize",
    "PipeStatus",
    "PumpCurve",
    "PumpUnit",
    "Scenario",
    "ThermalDesign",
    "load_case",
    "run_design_study",
    "save_case",
    "simulate_design",
]

__version__ = "0.1.0"
