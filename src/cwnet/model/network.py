"""Digraph description of the network: nodes and directed edges."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Node(BaseModel):
    """A node of the digraph.

    Connection nodes carry no external stream. The supply node (cooling tower basin) and
    the demand node (top of the cooling tower) are identified automatically from the edge
    directions; their ``pressure`` (bar gauge) is used as boundary condition in the
    rigorous simulation.
    """

    id: int
    tag: str = ""
    elevation: float = Field(0.0, description="Elevation, m")
    pressure: float | None = Field(
        None, description="Specified pressure, bar gauge (supply/demand nodes)"
    )


class Edge(BaseModel):
    """A directed edge ``tail -> head`` (water flows from tail to head)."""

    model_config = ConfigDict(populate_by_name=True)

    id: int
    tail: int = Field(..., description="Upstream node id", alias="from")
    head: int = Field(..., description="Downstream node id", alias="to")


class Network(BaseModel):
    """Nodes and edges of the cooling water network digraph.

    Nodes that are referenced by edges but not declared are created automatically as
    connection nodes at elevation zero.
    """

    nodes: list[Node] = Field(default_factory=list)
    edges: list[Edge]

    @model_validator(mode="after")
    def _complete_and_validate(self) -> Network:
        ids = [e.id for e in self.edges]
        if len(set(ids)) != len(ids):
            raise ValueError("duplicated edge ids")
        node_ids = [n.id for n in self.nodes]
        if len(set(node_ids)) != len(node_ids):
            raise ValueError("duplicated node ids")
        known = set(node_ids)
        for e in self.edges:
            if e.tail == e.head:
                raise ValueError(f"edge {e.id} is a self loop")
            for nid in (e.tail, e.head):
                if nid not in known:
                    self.nodes.append(Node(id=nid))
                    known.add(nid)
        self.nodes.sort(key=lambda n: n.id)
        self.edges.sort(key=lambda e: e.id)
        return self

    @property
    def node_ids(self) -> list[int]:
        return [n.id for n in self.nodes]

    @property
    def edge_ids(self) -> list[int]:
        return [e.id for e in self.edges]

    def node(self, node_id: int) -> Node:
        for n in self.nodes:
            if n.id == node_id:
                return n
        raise KeyError(node_id)

    def edge(self, edge_id: int) -> Edge:
        for e in self.edges:
            if e.id == edge_id:
                return e
        raise KeyError(edge_id)

    def supply_nodes(self) -> list[int]:
        """Nodes with outgoing edges only."""
        heads = {e.head for e in self.edges}
        return [n.id for n in self.nodes if n.id not in heads]

    def demand_nodes(self) -> list[int]:
        """Nodes with incoming edges only."""
        tails = {e.tail for e in self.edges}
        return [n.id for n in self.nodes if n.id not in tails]
