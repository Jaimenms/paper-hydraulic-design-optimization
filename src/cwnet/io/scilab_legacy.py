"""Reader of the legacy Scilab input format (``caso*.txt`` files of the original code).

Each line starts with a section name followed by ``<field:value>`` tokens, e.g.::

    REDE_ARESTA_LINHA: <ind:1> <tag:"1"> <L:10> <e:46> <DIA:"10"> <LDac:0> <Fac:0> ...

Units of the legacy files: viscosity in cP, roughness in micrometres, diameters in mm,
pump curve ``coef0..coef3`` (a0..a3), node pressure specification in bar.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from cwnet.model import (
    DesignCase,
    DesignOptions,
    Economics,
    Edge,
    FlowArrangement,
    Fluid,
    HeatExchanger,
    Network,
    Node,
    PipeCatalog,
    PipeCostModel,
    PipeSection,
    PipeSize,
    PipeStatus,
    PumpCurve,
    PumpUnit,
    Scenario,
    ThermalDesign,
)

_TOKEN = re.compile(r"<\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^>]*)>")


def _parse_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith('"') or raw.startswith("'"):
        return raw.strip("\"'").strip()
    try:
        return int(raw)
    except ValueError:
        pass
    try:
        return float(raw)
    except ValueError:
        return raw


def parse_legacy_file(path: str | Path) -> dict[str, list[dict[str, Any]]]:
    """Parse the file into ``{section: [record, ...]}``."""
    text = Path(path).read_bytes().decode("latin-1")
    sections: dict[str, list[dict[str, Any]]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        name, sep, rest = line.partition(":")
        if not sep or " " in name.strip():
            continue
        record = {k: _parse_value(v) for k, v in _TOKEN.findall(rest)}
        if record:
            sections.setdefault(name.strip(), []).append(record)
    return sections


def _merge(records: list[dict[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for r in records:
        out.update(r)
    return out


_STATUS = {
    "novo_otimo": PipeStatus.NEW,
    "novo": PipeStatus.NEW,
    "existente_otimo": PipeStatus.EXISTING,
    "existente": PipeStatus.EXISTING,
    "novo_fixo": PipeStatus.FIXED,
    "existente_fixo": PipeStatus.FIXED,
}


def load_legacy_case(path: str | Path, pump_fms: float | None = None) -> DesignCase:
    """Convert a legacy ``caso*.txt`` file into a :class:`DesignCase`.

    ``pump_fms`` overrides the Marshall & Swift factor; the legacy code used
    ``1457.4/1123.6``.
    """
    sec = parse_legacy_file(path)
    caso = _merge(sec.get("CASO", []))
    fl = _merge(sec.get("REDE_FLUIDO", []))
    fluid = Fluid(
        name=str(fl.get("tag", "Cooling water")),
        density=float(fl["dens"]),
        viscosity=float(fl["visc"]) / 1000.0,
        heat_capacity=float(fl.get("cp", 4187.0)),
        inlet_temperature=float(fl.get("temp", 32.0)),
    )
    nodes = [
        Node(
            id=int(r["ind_vertice"]),
            tag=str(r.get("tag_vertice", "")),
            elevation=float(r.get("z", 0.0)),
            pressure=float(r["esp"]) if str(r.get("tipo", "P")).upper() == "P" else None,
        )
        for r in sec.get("REDE_VERTICE", [])
    ]
    edges = [
        Edge(
            id=int(r["ind_aresta"]), tail=int(r["ind_noh_montante"]), head=int(r["ind_noh_jusante"])
        )
        for r in sec.get("REDE", [])
    ]
    catalog = PipeCatalog(
        sizes=[
            PipeSize(
                nominal=float(r["DN"]),
                inner_diameter=float(r["DIN"]) / 1000.0,
                outer_diameter=float(r["DOUT"]) / 1000.0 if "DOUT" in r else None,
            )
            for r in sec.get("OPT_OPCOES_LINHA", [])
        ]
        or PipeCatalog.ansi_b36_10_std().sizes
    )
    pipes = []
    for r in sec.get("REDE_ARESTA_LINHA", []):
        status = _STATUS.get(str(r.get("tipo", "novo_otimo")), PipeStatus.NEW)
        pipes.append(
            PipeSection(
                edge=int(r["ind"]),
                tag=str(r.get("tag", r["ind"])),
                length=float(r["L"]),
                roughness=float(r.get("e", 46.0)) * 1e-6,
                fittings_ld=float(r.get("LDac", 0.0)),
                fixed_head_loss=float(r.get("Fac", 0.0)),
                status=status,
                diameter=str(r["DIA"]) if status != PipeStatus.NEW else None,
            )
        )
    exchangers = []
    for r in sec.get("REDE_ARESTA_TROC", []):
        thermal = None
        if "A" in r and "mh" in r:
            thermal = ThermalDesign(
                area=float(r["A"]),
                h_tube=float(r["hi_sp"]),
                h_shell=float(r["he_sp"]),
                fouling_tube=float(r.get("Rfi", 0.0)),
                fouling_shell=float(r.get("Rfe", 0.0)),
                tube_conductivity=float(r.get("kt", 20.0)),
                tube_inner_diameter=float(r.get("Dti", 0.01575)),
                tube_outer_diameter=float(r.get("Dte", 0.01905)),
                arrangement=FlowArrangement(int(r.get("ic", 3))),
                cold_in_tubes=int(r.get("it", 1)) == 1,
                hot_flow=float(r["mh"]),
                hot_heat_capacity=float(r["Cph"]),
                hot_inlet_temperature=float(r["Thi"]),
                hot_outlet_temperature=float(r["Tho_sp"]),
                cold_outlet_temperature=float(r["Tco_sp"]),
            )
        exchangers.append(
            HeatExchanger(
                edge=int(r["ind"]),
                tag=str(r["tag"]),
                design_flow=float(r["k"]),
                design_head_loss=float(r["F"]),
                thermal=thermal,
            )
        )
    pump_rec = _merge(sec.get("REDE_ARESTA_BOMBA", []))
    pump = PumpUnit(
        edge=int(pump_rec["ind"]),
        tag=str(pump_rec.get("tag", "P-101")),
        existing=str(pump_rec.get("tipo", "novo")).strip().lower() == "existente",
        curve=str(pump_rec["curve"]) if "curve" in pump_rec else None,
    )
    curves = []
    for r in sec.get("OPT_CURVA", []):
        coefs = [float(r.get(f"coef{i}", 0.0)) for i in range(4)]
        curves.append(
            PumpCurve(
                tag=str(r["tag"]),
                coefficients=coefs,
                efficiency=float(r.get("eta", 0.6)),
                rated_flow=float(r["qrated"]) if r.get("qrated") else None,
            )
        )
    op = _merge(sec.get("OPT_CUSTO_OPERACIONAL", []))
    cost = _merge(sec.get("OPT_CUSTO_LINHA", []))
    economics = Economics(
        energy_price=float(op.get("pc", 0.10)),
        interest_rate=float(op.get("in", 0.12)),
        project_years=int(op.get("ny", 20)),
        operating_hours=float(op.get("Nop", 8760)),
        pipe_cost=PipeCostModel(
            c1=float(cost.get("alfa", 7.0386)), m=float(cost.get("beta", 1.4393))
        ),
    )
    if pump_fms is not None:
        economics.pump_cost.fms = pump_fms
    scen: dict[int, dict[str, float]] = {}
    fop: dict[int, float] = {}
    for r in sec.get("OPT_CENARIO", []):
        i = int(r.get("i", 1))
        he = next(h for h in exchangers if h.edge == int(r["ind"]))
        scen.setdefault(i, {})[he.tag] = float(r["k"])
        if "fop" in r:
            fop[i] = float(r["fop"])
        elif "Nop" in r:
            fop[i] = float(r["Nop"]) / economics.operating_hours
    scenarios = [
        Scenario(name=f"scenario {i}", time_fraction=fop.get(i, 1.0 / len(scen)), flows=flows)
        for i, flows in sorted(scen.items())
    ]
    if scenarios:
        total = sum(s.time_fraction for s in scenarios)
        for s in scenarios:
            s.time_fraction /= total
    options = DesignOptions(
        max_velocity=float(fl.get("v_PI_max", 3.7)),
        allow_downsizing_existing=int(cost.get("metodo", 1)) == 1,
        traditional_method="towler"
        if str(caso.get("executa_towler", "nao")).lower() == "sim"
        and str(caso.get("executa_himmelblau", "sim")).lower() != "sim"
        else "edgar_himmelblau",
    )
    return DesignCase(
        name=str(caso.get("projeto", Path(path).stem)),
        description=str(caso.get("desc_rede", "")) or str(caso.get("nome_rede", "")),
        author=str(caso.get("usuario", "")),
        date=str(caso.get("data", "")),
        fluid=fluid,
        network=Network(nodes=nodes, edges=edges),
        pipes=pipes,
        pump=pump,
        pump_catalog=curves,
        exchangers=exchangers,
        pipe_catalog=catalog,
        economics=economics,
        scenarios=scenarios,
        options=options,
    )
