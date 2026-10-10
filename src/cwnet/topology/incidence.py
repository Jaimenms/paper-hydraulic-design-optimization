"""Matrix description of the network digraph (Souza et al., 2014, Eqs. 1-3, 7-10)."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from cwnet.model import DesignCase


class TopologyError(ValueError):
    """The network does not satisfy the structural assumptions of the formulation."""


@dataclass
class NetworkTopology:
    """Matrices describing the interconnection of the network elements.

    Attributes
    ----------
    node_ids, edge_ids:
        Ordered ids; matrix rows/columns follow these orders.
    incidence:
        ``K`` (N x S): +1 if the edge enters the node, -1 if it leaves it.
    u_supply, u_demand, u_connection:
        Node classification vectors ``u_PS``, ``u_PD``, ``u_CN`` (Eqs. 1-3).
    select_pipes, select_pump, select_exchangers:
        Selection matrices ``Psi_PI``, ``Psi_PU``, ``Psi_HE`` (Eqs. 7-9), rows ordered as
        ``case.pipes``, ``[case.pump]`` and ``case.exchangers``.
    specification:
        ``E`` (N_E x S): one specification per heat exchanger (``E = Psi_HE``).
    circuits:
        ``Lambda`` (N_HY x S), Eq. (10): 1 if the edge belongs to the hydraulic circuit.
    """

    node_ids: list[int]
    edge_ids: list[int]
    incidence: np.ndarray
    u_supply: np.ndarray
    u_demand: np.ndarray
    u_connection: np.ndarray
    select_pipes: np.ndarray
    select_pump: np.ndarray
    select_exchangers: np.ndarray
    specification: np.ndarray
    circuits: np.ndarray
    pipe_edges: list[int] = field(default_factory=list)
    exchanger_edges: list[int] = field(default_factory=list)
    pump_edge: int = 0

    # convenience ------------------------------------------------------------
    @property
    def n_nodes(self) -> int:
        return len(self.node_ids)

    @property
    def n_edges(self) -> int:
        return len(self.edge_ids)

    @property
    def n_circuits(self) -> int:
        return self.circuits.shape[0]

    @property
    def circuits_pipes(self) -> np.ndarray:
        """``Lambda Psi_PI^T`` (N_HY x S_PI): pipes present in each circuit."""
        return self.circuits @ self.select_pipes.T

    @property
    def circuits_exchangers(self) -> np.ndarray:
        """``Lambda Psi_HE^T`` (N_HY x S_HE): exchangers present in each circuit."""
        return self.circuits @ self.select_exchangers.T

    @property
    def supply_node(self) -> int:
        return self.node_ids[int(np.argmax(self.u_supply))]

    @property
    def demand_node(self) -> int:
        return self.node_ids[int(np.argmax(self.u_demand))]

    def edge_index(self, edge_id: int) -> int:
        return self.edge_ids.index(edge_id)

    def node_index(self, node_id: int) -> int:
        return self.node_ids.index(node_id)


def _selection_matrix(edge_ids: list[int], selected: list[int]) -> np.ndarray:
    m = np.zeros((len(selected), len(edge_ids)))
    for i, e in enumerate(selected):
        m[i, edge_ids.index(e)] = 1.0
    return m


def build_topology(case: DesignCase) -> NetworkTopology:
    """Build incidence, classification, selection and circuit matrices of a case."""
    net = case.network
    node_ids, edge_ids = net.node_ids, net.edge_ids
    n, s = len(node_ids), len(edge_ids)

    k = np.zeros((n, s))
    for j, e in enumerate(net.edges):
        k[node_ids.index(e.tail), j] = -1.0
        k[node_ids.index(e.head), j] = +1.0

    ones = np.ones(s)
    u_ps = 1.0 - np.sign((np.abs(k) + k) @ ones)  # Eq. (1)
    u_pd = 1.0 - np.sign((np.abs(k) - k) @ ones)  # Eq. (2)
    u_cn = 1.0 - u_ps - u_pd  # Eq. (3)
    if int(u_ps.sum()) != 1 or int(u_pd.sum()) != 1:
        raise TopologyError(
            "the network must have exactly one supply node (only outgoing edges) and one "
            f"demand node (only incoming edges); found {int(u_ps.sum())} supply and "
            f"{int(u_pd.sum())} demand nodes"
        )

    pipe_edges = [p.edge for p in case.pipes]
    he_edges = [h.edge for h in case.exchangers]
    psi_pi = _selection_matrix(edge_ids, pipe_edges)
    psi_pu = _selection_matrix(edge_ids, [case.pump.edge])
    psi_he = _selection_matrix(edge_ids, he_edges)

    n_e = s + 2 - n
    if n_e != len(he_edges):
        raise TopologyError(
            f"the network needs {n_e} flow specifications (S+2-N) but has {len(he_edges)} "
            "heat exchangers; the formulation requires one specification per exchanger "
            "(parallel coolers, tree-like supply and return headers)"
        )
    spec = psi_he

    # Circuit matrix, Eq. (10): Lambda = ([I 0 0] sign(B^-1) [0; I])^T
    big = np.block([[k, u_ps[:, None], -u_pd[:, None]], [spec, np.zeros((n_e, 2))]])
    try:
        inv = np.linalg.inv(big)
    except np.linalg.LinAlgError as exc:
        raise TopologyError("singular mass-balance system: check the network connectivity") from exc
    a = np.hstack([np.eye(s), np.zeros((s, 2))])
    c = np.vstack([np.zeros((n, n_e)), np.eye(n_e)])
    circuits = (a @ np.sign(np.round(inv, 12)) @ c).T

    _validate_circuits(circuits, psi_pu, psi_he)
    return NetworkTopology(
        node_ids=node_ids,
        edge_ids=edge_ids,
        incidence=k,
        u_supply=u_ps,
        u_demand=u_pd,
        u_connection=u_cn,
        select_pipes=psi_pi,
        select_pump=psi_pu,
        select_exchangers=psi_he,
        specification=spec,
        circuits=circuits,
        pipe_edges=pipe_edges,
        exchanger_edges=he_edges,
        pump_edge=case.pump.edge,
    )


def _validate_circuits(circuits: np.ndarray, psi_pu: np.ndarray, psi_he: np.ndarray) -> None:
    if not np.all(np.isin(circuits, (0.0, 1.0))):
        raise TopologyError(
            "the hydraulic circuits could not be identified (negative or fractional "
            "entries): the network topology is outside the assumptions of the formulation"
        )
    pump_in = circuits @ psi_pu.T
    if not np.all(pump_in == 1.0):
        raise TopologyError("the pump edge must be present in all hydraulic circuits")
    he_in = circuits @ psi_he.T
    if not np.all(he_in.sum(axis=1) == 1.0):
        raise TopologyError("each hydraulic circuit must contain exactly one heat exchanger")
    if np.linalg.matrix_rank(circuits) != circuits.shape[0]:
        raise TopologyError("the hydraulic circuits are not independent")
