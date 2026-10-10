"""Figures: network digraph, split-pipe scheme, solution algorithm, cost charts.

The figures are drawn with matplotlib only (no Graphviz dependency). A small, fixed
categorical palette is used so that element types keep the same colour everywhere.
"""

from __future__ import annotations

from collections.abc import Sequence

import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import pandas as pd
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle

from cwnet.design.results import DesignStudy, NetworkDesign
from cwnet.model import DesignCase, PipeStatus

PALETTE = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
COLOR_PIPE, COLOR_EXCHANGER, COLOR_PUMP = PALETTE[0], PALETTE[1], PALETTE[2]
TEXT_PRIMARY, TEXT_SECONDARY, GRID = "#0b0b0b", "#52514e", "#e4e3df"


def _style(ax: Axes) -> None:
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.tick_params(colors=TEXT_SECONDARY, labelsize=9)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


# ------------------------------------------------------------------ digraph layout
def _longest_path_from(g: nx.DiGraph, source: int) -> dict[int, int]:
    dist = {source: 0}
    for n in nx.topological_sort(g):
        if n not in dist:
            continue
        for m in g.successors(n):
            dist[m] = max(dist.get(m, 0), dist[n] + 1)
    return dist


def butterfly_layout(case: DesignCase) -> dict[int, tuple[float, float]] | None:
    """Layout for parallel cooling networks: supply tree, exchangers column, return tree.

    Returns ``None`` when the supply or return side is not a tree (then a generic layered
    layout is used instead).
    """
    net = case.network
    he_edges = {h.edge: net.edge(h.edge) for h in case.exchangers}
    g = nx.DiGraph()
    g.add_nodes_from(net.node_ids)
    for e in net.edges:
        g.add_edge(e.tail, e.head, id=e.id)
    if not nx.is_directed_acyclic_graph(g):
        return None
    supply, demand = net.supply_nodes()[0], net.demand_nodes()[0]
    non_he = nx.DiGraph()
    non_he.add_nodes_from(net.node_ids)
    for e in net.edges:
        if e.id not in he_edges:
            non_he.add_edge(e.tail, e.head)
    supply_side = nx.descendants(non_he, supply) | {supply}
    return_side = nx.ancestors(non_he, demand) | {demand}
    if supply_side & return_side:
        return None
    sup_tree = non_he.subgraph(supply_side)
    ret_tree = non_he.subgraph(return_side).reverse()
    if not (nx.is_arborescence(sup_tree) and nx.is_arborescence(ret_tree)):
        return None

    # order the exchangers by a depth-first traversal of the supply tree
    he_by_tail = {e.tail: e for e in he_edges.values()}
    order: list[int] = []
    for n in nx.dfs_preorder_nodes(sup_tree, supply):
        if n in he_by_tail:
            order.append(n)
    y: dict[int, float] = {}
    for i, tail in enumerate(order):
        y[tail] = float(len(order) - 1 - i)
        y[he_by_tail[tail].head] = y[tail]
    # supply tree: y = mean of the exchangers in the subtree; return tree likewise
    for n in reversed(list(nx.topological_sort(sup_tree))):
        if n not in y:
            kids = [y[m] for m in sup_tree.successors(n) if m in y]
            y[n] = float(np.mean(kids)) if kids else 0.0
    for n in reversed(list(nx.topological_sort(ret_tree))):
        if n not in y:
            kids = [y[m] for m in ret_tree.successors(n) if m in y]
            y[n] = float(np.mean(kids)) if kids else 0.0
    fwd = _longest_path_from(sup_tree, supply)
    bwd = _longest_path_from(ret_tree, demand)
    x: dict[int, float] = {n: float(fwd[n]) for n in supply_side}
    depth = max(x[t] for t in order) + 1.0
    for tail in order:
        x[tail] = depth - 1.0
        x[he_by_tail[tail].head] = depth
    width = max(depth + bwd[he_by_tail[t].head] for t in order)
    for n in return_side:
        x.setdefault(n, width - bwd[n])
    # keep the exchanger tails aligned in one column (shift upstream branches if needed)
    return {n: (x[n], y[n]) for n in net.node_ids}


def layered_layout(case: DesignCase, sweeps: int = 6) -> dict[int, tuple[float, float]]:
    """Left-to-right layout of the digraph.

    The butterfly layout is used for the usual parallel networks; otherwise a generic
    longest-path layering with barycenter ordering is applied.
    """
    pos = butterfly_layout(case)
    if pos is not None:
        return pos
    g = nx.DiGraph()
    g.add_nodes_from(case.network.node_ids)
    for e in case.network.edges:
        g.add_edge(e.tail, e.head, id=e.id)
    if not nx.is_directed_acyclic_graph(g):
        spring = nx.spring_layout(g, seed=0)
        return {n: (float(a), float(b)) for n, (a, b) in spring.items()}
    layer: dict[int, int] = {}
    for n in nx.topological_sort(g):
        preds = list(g.predecessors(n))
        layer[n] = 0 if not preds else max(layer[p] for p in preds) + 1
    layers: dict[int, list[int]] = {}
    for n, lv in layer.items():
        layers.setdefault(lv, []).append(n)
    order = {lv: sorted(nodes) for lv, nodes in layers.items()}
    y: dict[int, float] = {}
    for nodes in order.values():
        for i, n in enumerate(nodes):
            y[n] = i - (len(nodes) - 1) / 2.0
    for _ in range(sweeps):
        for lv in sorted(order):
            nodes = order[lv]
            bary = {}
            for n in nodes:
                neigh = list(g.predecessors(n)) + list(g.successors(n))
                bary[n] = float(np.mean([y[m] for m in neigh])) if neigh else y[n]
            nodes.sort(key=lambda n: (bary[n], n))
            for i, n in enumerate(nodes):
                y[n] = i - (len(nodes) - 1) / 2.0
    return {n: (float(layer[n]), float(y[n])) for n in g.nodes}


def plot_digraph(
    case: DesignCase,
    ax: Axes | None = None,
    design: NetworkDesign | None = None,
    show_tags: bool = True,
    title: str | None = None,
) -> Axes:
    """Draw the network digraph (Figures 2 and 5 of the paper).

    Pipes are blue, the pump is green, heat exchangers are orange. Existing pipes of a
    revamp problem are dashed, new ones solid. When ``design`` is given, pipe labels
    include the selected diameters.
    """
    pos = layered_layout(case)
    if ax is None:
        width = 1.1 * (max(x for x, _ in pos.values()) + 2)
        height = 0.9 * (max(y for _, y in pos.values()) - min(y for _, y in pos.values()) + 2)
        _, ax = plt.subplots(figsize=(max(8, width), max(4, height)))
    g = nx.DiGraph()
    for e in case.network.edges:
        g.add_edge(e.tail, e.head, id=e.id)
    pipe_edges = {p.edge: p for p in case.pipes}
    he_edges = {h.edge: h for h in case.exchangers}

    nx.draw_networkx_nodes(
        g,
        pos,
        ax=ax,
        node_size=330,
        node_color="#f3f2ee",
        edgecolors=TEXT_SECONDARY,
        linewidths=0.8,
    )
    nx.draw_networkx_labels(g, pos, ax=ax, font_size=7, font_color=TEXT_PRIMARY)
    for e in case.network.edges:
        if e.id in pipe_edges:
            pipe = pipe_edges[e.id]
            color, style = COLOR_PIPE, "--" if pipe.status != PipeStatus.NEW else "-"
            label = str(e.id)
            if design is not None:
                label += f'\n{design.pipes[e.id].describe(case)[0]}"'
        elif e.id in he_edges:
            color, style = COLOR_EXCHANGER, "-"
            label = f"{e.id} ({he_edges[e.id].tag})" if show_tags else str(e.id)
        else:
            color, style = COLOR_PUMP, "-" if not case.pump.existing else "--"
            label = f"{e.id} ({case.pump.tag})" if show_tags else str(e.id)
        nx.draw_networkx_edges(
            g,
            pos,
            edgelist=[(e.tail, e.head)],
            ax=ax,
            edge_color=color,
            style=style,
            width=1.6,
            arrows=True,
            arrowsize=11,
            node_size=330,
            connectionstyle="arc3,rad=0.0",
        )
        (x0, y0), (x1, y1) = pos[e.tail], pos[e.head]
        dx, dy = x1 - x0, y1 - y0
        norm = float(np.hypot(dx, dy)) or 1.0
        off = 0.09
        ax.text(
            (x0 + x1) / 2 - off * dy / norm,
            (y0 + y1) / 2 + off * dx / norm,
            label,
            fontsize=6.5,
            color=TEXT_SECONDARY,
            ha="center",
            va="center",
        )
    handles = [
        plt.Line2D([], [], color=COLOR_PIPE, lw=1.6, label="Pipe section"),
        plt.Line2D([], [], color=COLOR_PUMP, lw=1.6, label="Pump"),
        plt.Line2D([], [], color=COLOR_EXCHANGER, lw=1.6, label="Heat exchanger"),
    ]
    if case.is_revamp:
        handles.append(plt.Line2D([], [], color=COLOR_PIPE, lw=1.6, ls="--", label="Existing pipe"))
    ax.legend(handles=handles, loc="upper left", fontsize=7, frameon=False, ncol=4)
    ax.set_axis_off()
    ax.set_title(title or f"Digraph of {case.name}", fontsize=10, color=TEXT_PRIMARY, loc="left")
    ax.margins(0.08)
    return ax


# -------------------------------------------------------------- schematic figures
def plot_system_schematic(case: DesignCase, ax: Axes | None = None) -> Axes:
    """Schematic of a recirculating cooling water system (Figure 1 of the paper)."""
    if ax is None:
        _, ax = plt.subplots(figsize=(8, 4.2))
    n = len(case.exchangers)
    ax.add_patch(
        FancyBboxPatch(
            (0.3, 1.0), 1.4, 2.4, boxstyle="round,pad=0.05", fc="#f3f2ee", ec=TEXT_SECONDARY
        )
    )
    ax.text(1.0, 2.2, "Cooling\ntower", ha="center", va="center", fontsize=9, color=TEXT_PRIMARY)
    ax.add_patch(plt.Circle((2.6, 0.6), 0.28, fc="white", ec=COLOR_PUMP, lw=1.8))
    ax.text(2.6, 0.1, case.pump.tag, ha="center", fontsize=8, color=TEXT_SECONDARY)
    ax.plot([1.0, 1.0, 2.32], [1.0, 0.6, 0.6], color=COLOR_PIPE, lw=1.8)
    ax.plot([2.88, 3.6, 3.6], [0.6, 0.6, 4.2], color=COLOR_PIPE, lw=1.8)
    ax.text(3.75, 4.25, "supply header", fontsize=8, color=TEXT_SECONDARY)
    ax.plot([8.4, 8.4, 1.0, 1.0], [4.2, 4.6, 4.6, 3.4], color=COLOR_PIPE, lw=1.8)
    ax.text(5.0, 4.7, "return header", fontsize=8, color=TEXT_SECONDARY)
    ys = np.linspace(1.2, 3.8, n)
    for he, y in zip(case.exchangers, ys, strict=True):
        ax.plot([3.6, 5.2], [y, y], color=COLOR_PIPE, lw=1.4)
        ax.add_patch(Rectangle((5.2, y - 0.22), 1.6, 0.44, fc="white", ec=COLOR_EXCHANGER, lw=1.6))
        ax.text(6.0, y, he.tag, ha="center", va="center", fontsize=7.5, color=TEXT_PRIMARY)
        ax.plot([6.8, 8.4], [y, y], color=COLOR_PIPE, lw=1.4)
    ax.plot([8.4, 8.4], [ys[0], 4.2], color=COLOR_PIPE, lw=1.8)
    ax.set_xlim(0, 9.2)
    ax.set_ylim(-0.2, 5.1)
    ax.set_aspect("equal")
    ax.set_axis_off()
    ax.set_title("Typical structure of a cooling water system", fontsize=10, loc="left")
    return ax


def plot_split_pipe(case: DesignCase | None = None, n_sub: int = 4, ax: Axes | None = None) -> Axes:
    """Split-pipe description of a pipe section (Figure 3 of the paper)."""
    if ax is None:
        _, ax = plt.subplots(figsize=(7, 2.4))
    fracs = np.array([0.35, 0.25, 0.25, 0.15])[:n_sub]
    fracs = fracs / fracs.sum()
    heights = np.linspace(0.35, 1.0, n_sub)
    x = 0.0
    labels = case.pipe_catalog.labels[-n_sub:] if case else [f"D_nom,{i + 1}" for i in range(n_sub)]
    for i, (f, h) in enumerate(zip(fracs, heights, strict=True)):
        ax.add_patch(Rectangle((x, -h / 2), f * 8, h, fc="#eef3fb", ec=COLOR_PIPE, lw=1.6))
        ax.text(
            x + f * 4, 0, f'{labels[i]}"', ha="center", va="center", fontsize=9, color=TEXT_PRIMARY
        )
        ax.annotate(
            "",
            xy=(x + f * 8, -0.75),
            xytext=(x, -0.75),
            arrowprops=dict(arrowstyle="<->", color=TEXT_SECONDARY, lw=0.8),
        )
        ax.text(
            x + f * 4,
            -0.95,
            f"$X_{{p,{i + 1}}} L_p$",
            ha="center",
            va="top",
            fontsize=8,
            color=TEXT_SECONDARY,
        )
        x += f * 8
    ax.annotate(
        "",
        xy=(8, 0.85),
        xytext=(0, 0.85),
        arrowprops=dict(arrowstyle="<->", color=TEXT_SECONDARY, lw=0.8),
    )
    ax.text(
        4,
        0.9,
        "$L_p$ (equivalent length of pipe section $p$)",
        ha="center",
        va="bottom",
        fontsize=8,
        color=TEXT_SECONDARY,
    )
    ax.set_xlim(-0.3, 8.3)
    ax.set_ylim(-1.4, 1.3)
    ax.set_axis_off()
    ax.set_title("Split-pipe description of a pipe section", fontsize=10, loc="left")
    return ax


def plot_solution_algorithm(ax: Axes | None = None) -> Axes:
    """Flowchart of the solution algorithm (Figure 4 of the paper)."""
    if ax is None:
        _, ax = plt.subplots(figsize=(5.5, 8.5))
    steps = [
        "Network data: digraph, lengths, catalogue,\npump alternatives, flow specifications",
        "Mass balance of the digraph (Eq. 6)\n-> flow rate of every edge",
        "Hydraulic circuits (Eq. 10) and head-loss\ncoefficients of pipes, exchangers and pumps",
        "For each pump alternative s = 1..N_PU:\nsolve the LP in X (and y) (Eqs. 27-31 / 34-36)",
        "Evaluate the total cost of each solution\n(pipes, pump capital, pumping energy)",
        "Select the cheapest feasible alternative\n-> diameters, pump and valves",
        "Verification: rigorous simulation and\nthermal check of the coolers",
    ]
    n = len(steps)
    ys = np.linspace(n - 1, 0, n)
    for i, (text, y) in enumerate(zip(steps, ys, strict=True)):
        fc = "#eef3fb" if i not in (0, n - 1) else "#f3f2ee"
        box = FancyBboxPatch(
            (-2.4, y - 0.36),
            4.8,
            0.72,
            boxstyle="round,pad=0.04",
            fc=fc,
            ec=COLOR_PIPE if i not in (0, n - 1) else TEXT_SECONDARY,
            lw=1.2,
        )
        ax.add_patch(box)
        ax.text(0, y, text, ha="center", va="center", fontsize=8, color=TEXT_PRIMARY)
        if i < n - 1:
            ax.add_patch(
                FancyArrowPatch(
                    (0, y - 0.4),
                    (0, ys[i + 1] + 0.4),
                    arrowstyle="-|>",
                    mutation_scale=12,
                    color=TEXT_SECONDARY,
                )
            )
    ax.text(2.55, ys[3], "loop over\npumps", fontsize=7.5, color=TEXT_SECONDARY, va="center")
    ax.set_xlim(-2.8, 3.4)
    ax.set_ylim(-0.6, n - 0.4)
    ax.set_axis_off()
    ax.set_title("Solution algorithm", fontsize=10, loc="left")
    return ax


# -------------------------------------------------------------------- cost charts
def plot_cost_comparison(
    study: DesignStudy, ax: Axes | None = None, basis: str | None = None
) -> Axes:
    """Stacked bars of operating, pump and pipe costs of every design (Table XI as a chart)."""
    from cwnet.reporting.tables import cost_comparison_table

    df = cost_comparison_table(study, basis=basis)
    df = df[df["Feasible"]]
    if ax is None:
        _, ax = plt.subplots(figsize=(8, 4))
    labels = df["Methodology / case"].tolist()
    parts = [
        ("Operational cost", df["Operational cost (USD/y)"].to_numpy(float), PALETTE[0]),
        ("Pump cost (annualized)", df["Pump cost (USD/y)"].to_numpy(float), PALETTE[2]),
        ("Pipe cost", df["Pipe cost (USD)"].to_numpy(float), PALETTE[1]),
    ]
    bottom = np.zeros(len(labels))
    x = np.arange(len(labels))
    for name, values, color in parts:
        ax.bar(
            x, values, 0.6, bottom=bottom, color=color, edgecolor="white", linewidth=1.5, label=name
        )
        bottom += values
    for xi, total in zip(x, bottom, strict=True):
        ax.text(
            xi, total, f"{total:,.0f}", ha="center", va="bottom", fontsize=8, color=TEXT_PRIMARY
        )
    ax.set_xticks(x, labels, rotation=20, ha="right", fontsize=8)
    ax.set_ylabel("USD/year", fontsize=9, color=TEXT_SECONDARY)
    ax.legend(frameon=False, fontsize=8, ncol=3, loc="upper left", bbox_to_anchor=(0, 1.12))
    _style(ax)
    return ax


def plot_sensitivity(
    df: pd.DataFrame,
    x: str,
    series: Sequence[str],
    ax: Axes | None = None,
    ylabel: str = "USD/year",
    xlabel: str | None = None,
    title: str | None = None,
    highlight: str | None = None,
) -> Axes:
    """Line chart of one or more columns of a sensitivity table against ``x``."""
    if ax is None:
        _, ax = plt.subplots(figsize=(7, 4))
    for i, col in enumerate(series):
        color = PALETTE[i % len(PALETTE)]
        lw = 2.4 if col == highlight else 1.8
        ax.plot(df[x], df[col], color=color, lw=lw, label=col)
        ax.text(df[x].iloc[-1], df[col].iloc[-1], f" {col}", fontsize=7.5, color=color, va="center")
    ax.set_xlabel(xlabel or x, fontsize=9, color=TEXT_SECONDARY)
    ax.set_ylabel(ylabel, fontsize=9, color=TEXT_SECONDARY)
    if title:
        ax.set_title(title, fontsize=10, loc="left")
    if len(series) > 1:
        ax.legend(frameon=False, fontsize=8)
    _style(ax)
    ax.margins(x=0.12)
    return ax


def plot_pump_curves(study: DesignStudy, ax: Axes | None = None) -> Axes:
    """Characteristic curves of the pump alternatives with the design operating points."""
    case = study.case
    if ax is None:
        _, ax = plt.subplots(figsize=(7, 4))
    k_max = max(mb.pump_flow for mb in study.balances) * 1.4
    q = np.linspace(0, k_max / case.fluid.density, 100)
    for i, curve in enumerate(case.pump_catalog):
        color = PALETTE[i % len(PALETTE)]
        h = np.asarray(curve.head(q))
        ax.plot(q * case.fluid.density, h, color=color, lw=1.8, label=curve.tag)
    for ev in study.feasible_lp:
        for se in ev.scenarios:
            ax.plot(se.pump_flow, se.pump_head, "o", ms=6, mfc="white", mec=TEXT_PRIMARY, mew=1.2)
    for ev in study.traditional.values():
        for se in ev.scenarios:
            ax.plot(se.pump_flow, se.pump_head, "s", ms=6, mfc="white", mec=TEXT_SECONDARY, mew=1.2)
    ax.set_xlabel("Mass flow rate (kg/s)", fontsize=9, color=TEXT_SECONDARY)
    ax.set_ylabel("Head (m)", fontsize=9, color=TEXT_SECONDARY)
    ax.legend(frameon=False, fontsize=8)
    ax.set_ylim(bottom=0)
    _style(ax)
    return ax


def save(fig: Figure, path: str, dpi: int = 150) -> None:
    fig.savefig(path, dpi=dpi, bbox_inches="tight")
