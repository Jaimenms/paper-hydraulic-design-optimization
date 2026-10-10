"""Build and execute the reproduction notebooks.

Usage: ``uv run python scripts/build_notebooks.py [--no-execute] [--only NAME ...]``

The notebooks are generated from this script so that they can be rebuilt after changes in
the library; executed copies (with outputs) are written to ``notebooks/``.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import nbformat
from nbclient import NotebookClient
from nbformat.v4 import new_code_cell, new_markdown_cell, new_notebook

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "notebooks"

HEADER = """import warnings
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from cwnet import load_case, run_design_study
from cwnet.reporting import plots, tables

warnings.filterwarnings("ignore")
pd.set_option("display.width", 160)
pd.set_option("display.max_columns", 30)
CASES = Path("../cases")
"""


def md(text: str):
    return new_markdown_cell(text.strip("\n"))


def code(src: str):
    return new_code_cell(src.strip("\n"))


def notebook(cells, title: str):
    nb = new_notebook(cells=cells)
    nb.metadata["kernelspec"] = {
        "name": "python3",
        "display_name": "Python 3",
        "language": "python",
    }
    nb.metadata["language_info"] = {"name": "python"}
    nb.metadata["title"] = title
    return nb


# ============================================================================ 00 tutorial
def tutorial() -> nbformat.NotebookNode:
    cells = [
        md("""
# 00 · Tutorial: configurar a rede, os parâmetros e otimizar

Este notebook mostra como **definir uma rede de água de resfriamento do zero** com a API
Python do pacote `cwnet`, como todos os parâmetros do problema são configurados (fluido,
catálogo de diâmetros, bombas, trocadores, custos, cenários e opções do algoritmo), como
executar o estudo de projeto (tradicional + LP split-pipe por bomba), como ler os resultados
e como guardar/carregar o caso em YAML.

O método implementado é o de Souza et al. (2014) e a extensão multi-cenário de Costa,
Tonassi e Souza (2016); ver `docs/formulation.md` para o mapeamento equações ↔ código.
"""),
        code(HEADER),
        md("""
## 1. Desenhar a rede (digrafo)

A rede é um digrafo: **nós** (vértices) e **arestas** orientadas no sentido do escoamento.
Cada aresta é uma tubulação, a bomba ou um trocador. O nó de suprimento (bacia da torre)
só tem arestas de saída e o nó de demanda (topo da torre) só tem arestas de entrada; os nós
de conexão referenciados pelas arestas são criados automaticamente.

Vamos construir uma rede pequena com 3 trocadores em paralelo.
"""),
        code("""
from cwnet import (
    DesignCase, DesignOptions, Economics, Edge, Fluid, HeatExchanger, Network, Node,
    PipeCatalog, PipeSection, PumpCurve, PumpUnit, Scenario,
)

network = Network(
    nodes=[
        Node(id=1, tag="Bacia da torre", elevation=0.0, pressure=0.0),   # suprimento
        Node(id=8, tag="Topo da torre", elevation=6.0, pressure=0.0),    # demanda (6 m acima)
    ],
    edges=[
        Edge(id=1, tail=1, head=2),   # sucção
        Edge(id=2, tail=2, head=3),   # bomba
        Edge(id=3, tail=3, head=4),   # coletor de suprimento
        Edge(id=4, tail=4, head=5),   # ramal para E-1
        Edge(id=5, tail=4, head=6),   # ramal para E-2
        Edge(id=6, tail=4, head=7),   # ramal para E-3
        Edge(id=7, tail=5, head=9),   # E-1
        Edge(id=8, tail=6, head=10),  # E-2
        Edge(id=9, tail=7, head=11),  # E-3
        Edge(id=10, tail=9, head=12),
        Edge(id=11, tail=10, head=12),
        Edge(id=12, tail=11, head=12),
        Edge(id=13, tail=12, head=8), # coletor de retorno
    ],
)
print("nós:", network.node_ids)
print("suprimento:", network.supply_nodes(), "demanda:", network.demand_nodes())
"""),
        md("""
## 2. Elementos das arestas e parâmetros

* `PipeSection`: comprimento equivalente, rugosidade, L/D de acidentes, perda localizada fixa,
  `status` (`new` = diâmetro livre; `existing` = instalado, manter custa zero; `fixed` = imposto).
* `PumpUnit` + `pump_catalog`: a aresta da bomba e as alternativas comerciais (curva
  polinomial `H = a0 + a1 q + a2 q²`, eficiência, vazão nominal para o custo).
* `HeatExchanger`: vazão e perda de carga de projeto (curva `F = F_d (k/k_d)^1.8`) e,
  opcionalmente, os dados térmicos para a verificação ε-NTU.
* `PipeCatalog`: diâmetros comerciais candidatos (padrão: ASME B36.10 STD, 1/2" a 24").
* `Economics`: preço da energia, juros, horizonte, horas/ano, correlações de custo.
* `Scenario`: vazões demandadas por trocador (um ou vários cenários com frações de tempo).
* `DesignOptions`: velocidade máxima, válvulas, método tradicional, solver, etc.
"""),
        code("""
pipes = [
    PipeSection(edge=1, length=15.0),
    PipeSection(edge=3, length=120.0, fittings_ld=60.0),        # com acidentes (L/D = 60)
    PipeSection(edge=4, length=30.0),
    PipeSection(edge=5, length=45.0),
    PipeSection(edge=6, length=60.0),
    PipeSection(edge=10, length=30.0),
    PipeSection(edge=11, length=45.0),
    PipeSection(edge=12, length=60.0),
    PipeSection(edge=13, length=140.0),
]
exchangers = [
    HeatExchanger(edge=7, tag="E-1", design_flow=20.0, design_head_loss=4.5),
    HeatExchanger(edge=8, tag="E-2", design_flow=35.0, design_head_loss=6.0),
    HeatExchanger(edge=9, tag="E-3", design_flow=12.0, design_head_loss=3.0),
]
pump_catalog = [
    PumpCurve(tag="B-A", coefficients=[28.0, -120.0, -400.0], efficiency=0.62),
    PumpCurve(tag="B-B", coefficients=[34.0, -140.0, -450.0], efficiency=0.62),
    PumpCurve(tag="B-C", coefficients=[40.0, -160.0, -500.0], efficiency=0.62),
]
case = DesignCase(
    name="Tutorial - rede com 3 trocadores",
    fluid=Fluid(density=995.0, viscosity=0.72e-3),
    network=network,
    pipes=pipes,
    pump=PumpUnit(edge=2, tag="P-1"),
    pump_catalog=pump_catalog,
    exchangers=exchangers,
    pipe_catalog=PipeCatalog.ansi_b36_10_std(),
    economics=Economics(energy_price=0.08, interest_rate=0.10, project_years=15,
                        objective_basis="annualized"),
    scenarios=[Scenario(name="projeto", time_fraction=1.0,
                        flows={"E-1": 20.0, "E-2": 35.0, "E-3": 12.0})],
    options=DesignOptions(max_velocity=3.0, allow_valves=True, traditional_method="towler"),
)
ax = plots.plot_digraph(case)
"""),
        md("""
## 3. Executar o estudo de projeto

`run_design_study` faz: balanço de massa (Eq. 6), circuitos hidráulicos (Eq. 10), coeficientes
de perda de carga, projeto tradicional (velocidade econômica), um LP por alternativa de bomba
(Eqs. 27-31/34-36), avaliação de custos e **simulação rigorosa** de cada projeto.
"""),
        code("""
study = run_design_study(case, traditional_methods=["towler", "edgar_himmelblau"])
display(tables.mass_flow_table(study))
display(tables.cost_comparison_table(study))
print("melhor alternativa:", study.best.label)
"""),
        code("""
display(tables.design_comparison_table(study, traditional="towler"))
display(tables.valve_table(study.best, case))
display(tables.pipe_results_table(study.best, case))
ax = plots.plot_cost_comparison(study)
"""),
        md("""
## 4. Alterar o desenho da rede e os parâmetros

Tudo é um objeto pydantic: podemos copiar o caso, inserir um trocador novo, mudar o catálogo,
fixar um diâmetro, declarar a bomba como existente, acrescentar cenários, etc.
"""),
        code("""
revamp = case.model_copy(deep=True)
# novo trocador E-4 em paralelo, alimentado por um ramal novo a partir do nó 4
revamp.network.edges += [Edge(id=14, tail=4, head=13), Edge(id=15, tail=13, head=14), Edge(id=16, tail=14, head=12)]
revamp.network = Network(nodes=revamp.network.nodes, edges=revamp.network.edges)  # revalida / cria nós novos
revamp.pipes += [PipeSection(edge=14, length=50.0), PipeSection(edge=16, length=50.0)]
revamp.exchangers.append(HeatExchanger(edge=15, tag="E-4", design_flow=18.0, design_head_loss=4.0))
# a rede existente foi construída com o projeto ótimo anterior: manter custa zero
best = study.best.design
for p in revamp.pipes:
    if p.edge in best.pipes and not best.pipes[p.edge].is_split:
        p.status = "existing"
        p.diameter = best.pipes[p.edge].labels(case)[0]
revamp.pump = PumpUnit(edge=2, tag="P-1", existing=True, curve=best.pump_curve)
revamp.scenarios = [Scenario(name="expansão", flows={"E-1": 20.0, "E-2": 35.0, "E-3": 12.0, "E-4": 18.0})]
revamp = DesignCase.model_validate(revamp.model_dump())
study2 = run_design_study(revamp, traditional_methods=["towler"])
ax = plots.plot_digraph(revamp, design=study2.best.design, title="Revamp: tubos existentes tracejados")
display(tables.cost_comparison_table(study2))
display(tables.design_comparison_table(study2, traditional="towler"))
"""),
        md("""
## 5. Guardar e carregar em YAML; linha de comando

O caso completo pode ser guardado em YAML/JSON e editado à mão (ver `cases/*.yaml`, com
comentários em cada parâmetro). A CLI `cwnet` executa o mesmo estudo a partir do ficheiro.
"""),
        code("""
from cwnet import save_case
save_case(revamp, "tutorial_revamp.yaml")
print(Path("tutorial_revamp.yaml").read_text()[:1200], "...")
again = load_case("tutorial_revamp.yaml")
assert again.model_dump() == revamp.model_dump()
Path("tutorial_revamp.yaml").unlink()
"""),
        code("""
import subprocess, sys
print(subprocess.run([sys.executable, "-m", "cwnet.cli", "--help"], capture_output=True, text=True).stdout)
print(subprocess.run([sys.executable, "-m", "cwnet.cli", "validate", str(CASES / "paper1_grassroots.yaml")],
                     capture_output=True, text=True).stdout)
"""),
    ]
    return notebook(cells, "Tutorial")


# ============================================================================ 01 paper 1
PUB_TABLE_IX = """
PUBLISHED_TABLE_IX = {   # edge: (traditional, optimization diameters, length fractions)
    1: ("12", "10", "1.000"), 3: ("12", "12", "1.000"), 4: ("8", "8", "1.000"),
    5: ("5", "6", "1.000"), 6: ("5", "6", "1.000"), 7: ("8", "8/10", "0.399/0.601"),
    8: ("12", "10/12", "0.810/0.190"), 9: ("4", "3 1/2", "1.000"), 10: ("6", "6", "1.000"),
    11: ("8", "8", "1.000"), 12: ("5", "6", "1.000"), 13: ("2 1/2", "1 1/2/2", "0.225/0.775"),
    14: ("4", "3 1/2/4", "0.203/0.797"), 15: ("6", "6", "1.000"), 16: ("8", "6/8", "0.353/0.647"),
    17: ("5", "6", "1.000"), 18: ("2 1/2", "2", "1.000"),
}
PUBLISHED_TABLE_X = {  # tag: (design flow, design Tho, simulated flow, simulated Tho)
    "E-101": (11.8, 65.0, 13.8, 63.2), "E-102": (28.7, 80.0, 32.2, 78.2), "E-103": (35.6, 40.0, 39.8, 39.1),
    "E-104": (15.6, 41.0, 12.7, 41.7), "E-105": (3.1, 41.0, 4.2, 38.6),
}
PUBLISHED_TABLE_XI = {  # (total, operating, pump, pipe) USD/y
    "Traditional (edgar_himmelblau)": (42815, 23184, 3209, 16422),
    "Proposed / Curve 1": (39811, 20183, 3045, 16583), "Proposed / Curve 2": (41768, 24220, 3209, 14339),
    "Proposed / Curve 3": (43939, 26911, 3312, 13716), "Proposed / Curve 4": (46292, 29602, 3409, 13281),
}
"""


def paper1_grassroots() -> nbformat.NotebookNode:
    cells = [
        md("""
# 01 · Artigo 1 — projeto *grassroots* (Souza, Ventin, Tavares & Costa, 2014)

**A matrix approach for optimization of pipe networks in cooling water systems**,
*Chem. Eng. Comm.* 201:1054-1076, DOI 10.1080/00986445.2013.800484.

Este notebook reproduz, com o pacote `cwnet`, as figuras e tabelas da parte *grassroots*:
Figuras 1-4 e Tabelas I-XI. Os valores publicados estão embutidos nas células de
comparação; as diferenças são comentadas (ver também `docs/reproduction_notes.md`).
"""),
        code(HEADER),
        code(
            'case = load_case(CASES / "paper1_grassroots.yaml")\nprint(case.name)\nprint(case.description)'
        ),
        md("## Figura 1 — estrutura típica de um sistema de água de resfriamento"),
        code("ax = plots.plot_system_schematic(case)"),
        md("""
## Figura 2 — digrafo da rede

23 arestas (5 trocadores, 1 bomba, 17 tubulações) e 20 nós. Os nós 1 e 10 são a bacia e o
topo da torre (suprimento e demanda); as demais são nós de conexão.
"""),
        code(
            'ax = plots.plot_digraph(case, title="Figura 2 - digrafo do sistema de água de resfriamento")'
        ),
        md("## Figura 3 — descrição *split-pipe* de uma tubulação"),
        code("ax = plots.plot_split_pipe(case)"),
        md("## Figura 4 — algoritmo de solução"),
        code("ax = plots.plot_solution_algorithm()"),
        md("## Tabelas I a VII — dados do problema"),
        code("""
print("Tabela I - comprimentos das tubulações"); display(tables.pipe_lengths_table(case))
print("Tabela II - diâmetros comerciais"); display(tables.pipe_catalog_table(case))
print("Tabela III - bombas disponíveis"); display(tables.pump_catalog_table(case))
print("Tabela IV - fatores de custo da bomba"); display(tables.pump_cost_factors_table(case))
print("Tabela V - parâmetros"); display(tables.problem_parameters_table(case))
print("Tabela VI - tarefas térmicas"); display(tables.thermal_tasks_table(case))
print("Tabela VII - dados de projeto dos trocadores"); display(tables.exchanger_design_table(case))
"""),
        md("""
## Matrizes da formulação (Eqs. 1-3, 7-10)

A matriz de incidência `K`, os vetores de classificação dos nós e a matriz de circuitos
hidráulicos `Λ` (Eq. 10) são construídos automaticamente a partir do digrafo.
"""),
        code("""
study = run_design_study(case, traditional_methods=["edgar_himmelblau", "towler"])
topo = study.topology
print("K:", topo.incidence.shape, "| nós de suprimento/demanda:", topo.supply_node, topo.demand_node)
print("circuitos hidráulicos (Λ):")
display(tables.circuit_table(study))
"""),
        md("## Tabela VIII — vazões mássicas da rede (balanço de massa, Eq. 6)"),
        code("display(tables.mass_flow_table(study))"),
        md("""
## Tabela IX — projeto tradicional (Edgar & Himmelblau) e projeto otimizado (LP)

O LP para a bomba 1 é o mais barato. O ótimo do LP é **degenerado**: tubulações em série
com a mesma vazão (por exemplo 1, 3 e 8 no coletor principal) podem trocar entre si os
trechos de diâmetro sem alterar o custo; o vértice publicado e o encontrado aqui diferem
apenas nessa escolha. A célula seguinte verifica que, em cada grupo de tubulações em série,
o comprimento total de cada diâmetro é o mesmo que o publicado.
"""),
        code(
            PUB_TABLE_IX
            + """
design_tbl = tables.design_comparison_table(study, traditional="edgar_himmelblau")
design_tbl["Published traditional"] = [PUBLISHED_TABLE_IX[e][0] for e in design_tbl["Edge"]]
design_tbl["Published optimization"] = [PUBLISHED_TABLE_IX[e][1] for e in design_tbl["Edge"]]
design_tbl["Published fraction"] = [PUBLISHED_TABLE_IX[e][2] for e in design_tbl["Edge"]]
display(design_tbl)
"""
        ),
        code("""
def length_by_diameter(design, edges):
    out = {}
    for e in edges:
        for n, f in design.pipes[e].subsections:
            dn = case.pipe_catalog.sizes[n].label
            out[dn] = out.get(dn, 0.0) + f * case.pipe(e).length
    return {k: round(v, 2) for k, v in sorted(out.items())}

def published_length_by_diameter(edges):
    out = {}
    for e in edges:
        labels = PUBLISHED_TABLE_IX[e][1].split("/") if "/" not in PUBLISHED_TABLE_IX[e][1].replace("1 1/2", "x").replace("3 1/2", "y") else None
        # labels with fractions such as "1 1/2/2" need care: use the catalogue labels
        cat = [s.label for s in case.pipe_catalog.sizes]
        text = PUBLISHED_TABLE_IX[e][1]
        parts = []
        for lab in sorted(cat, key=len, reverse=True):
            if text.startswith(lab):
                parts.append(lab); text = text[len(lab):].lstrip("/")
                if text:
                    parts.append(text)
                break
        fr = [float(x) for x in PUBLISHED_TABLE_IX[e][2].split("/")]
        for lab, f in zip(parts, fr):
            out[lab] = out.get(lab, 0.0) + f * case.pipe(e).length
    return {k: round(v, 2) for k, v in sorted(out.items())}

best = study.best.design
groups = {"coletor principal (1, 3, 8)": (1, 3, 8), "4 e 7": (4, 7), "9 e 14": (9, 14),
          "11 e 16": (11, 16), "13 e 18": (13, 18), "10 e 15": (10, 15), "5, 6": (5, 6), "12, 17": (12, 17)}
rows = []
for name, edges in groups.items():
    rows.append({"grupo em série": name, "comprimento por diâmetro (cwnet)": length_by_diameter(best, edges),
                 "comprimento por diâmetro (publicado)": published_length_by_diameter(edges)})
display(pd.DataFrame(rows))
print("custo de tubulação (LP, bomba 1): %.0f USD" % study.best.costs.pipe_capital)
"""),
        md("""
## Tabela X — comportamento da rede com o projeto tradicional

A rede tradicional é simulada rigorosamente (balanços de massa e energia mecânica com a
curva da bomba 2) e o desempenho térmico dos trocadores é avaliado pelo método ε-NTU
(rotina `heatcheck` do código original). As **vazões simuladas** coincidem com as
publicadas (102.7 kg/s no total; E-104 recebe só 81 % da vazão de projeto). As
**temperaturas** de saída diferem em até ~1 °C das publicadas porque o artigo usou o
simulador termo-hidráulico de Tavares et al. (2010), mais detalhado do que o modelo ε-NTU
disponível aqui.
"""),
        code("""
trad = study.traditional["edgar_himmelblau"]
tab_x = tables.network_behaviour_table(trad)
pub = pd.DataFrame([{"Heat exchanger": k, "Published simulated flow (kg/s)": v[2], "Published simulated hot outlet (degC)": v[3]}
                    for k, v in PUBLISHED_TABLE_X.items()])
display(tab_x.merge(pub, on="Heat exchanger", how="left"))
print("bomba selecionada pelo método tradicional:", trad.design.pump_curve,
      "| head mínimo requerido: %.2f m (artigo: 17.8 m)" % trad.design.required_pump_head)
"""),
        md("""
## Tabela XI — comparação econômica

Custos em USD/ano. Nota: na tabela publicada (e no código Scilab original) a coluna
*pipe cost* é o **investimento** em tubos (não anualizado), enquanto o custo da bomba é
anualizado; `objective_basis: published` reproduz essa convenção. A diferença de ~2 USD vem
do fator de conversão arredondado (3.281 ft/m) usado no código original.
"""),
        code("""
costs = tables.cost_comparison_table(study)
costs = costs[costs["Methodology / case"] != "Traditional (towler)"].copy()
for i, col in enumerate(["Total cost (USD/y)", "Operational cost (USD/y)", "Pump cost (USD/y)", "Pipe cost (USD)"]):
    costs[f"Published {col}"] = [PUBLISHED_TABLE_XI[m][i] for m in costs["Methodology / case"]]
    costs[f"Δ {col}"] = costs[col] - costs[f"Published {col}"]
display(costs)
best_total = study.best.costs.total; trad_total = trad.costs.total
print("redução de custo do projeto proposto (bomba 1) vs tradicional: %.1f %% (artigo: 7.0 %%)" % (100 * (1 - best_total / trad_total)))
"""),
        code("""
ax = plots.plot_cost_comparison(study)
ax2 = plots.plot_pump_curves(study)
"""),
        md("""
## Verificação do projeto ótimo

A simulação rigorosa da rede otimizada devolve exatamente as vazões especificadas (rede
hidraulicamente balanceada, sem válvulas), como afirmado no artigo.
"""),
        code("""
display(tables.pipe_results_table(study.best, case))
display(tables.network_behaviour_table(study.best))
print("balanceada:", study.best.hydraulically_balanced, "| válvulas:", study.best.design.valves)
"""),
        md("""
## Nota: ranking com custos totalmente anualizados

Aplicando o fator de anualização também ao investimento em tubos (Eqs. 15-18 do artigo),
o ranking das bombas neste caso não muda (bomba 1 continua a melhor):
"""),
        code("""
display(tables.cost_comparison_table(study, basis="annualized"))
"""),
    ]
    return notebook(cells, "Artigo 1 - grassroots")


# ============================================================================ 02 revamp
def paper1_revamp() -> nbformat.NotebookNode:
    cells = [
        md("""
# 02 · Artigo 1 — problema de *revamp* (Souza et al., 2014)

Reprodução da Figura 5 e das Tabelas XII-XVI: a rede ótima do problema *grassroots* é
expandida com os trocadores E-105B (em paralelo com E-105, modelado como E-105A/B) e E-106,
alimentado pelas tubulações novas 29 e 30. As tubulações divididas da solução anterior
(7, 8, 13, 14 e 16) tornaram-se arestas separadas (24-28). A bomba existente (curva 1) e os
tubos existentes podem ser mantidos a custo zero; válvulas (perdas `y_h`) entram como
variáveis de decisão (Eqs. 34-36).
"""),
        code(HEADER),
        code(
            'case = load_case(CASES / "paper1_revamp.yaml")\nprint(case.name); print(case.description)'
        ),
        md("## Figura 5 — digrafo da rede revampeada (tubos existentes tracejados)"),
        code('ax = plots.plot_digraph(case, title="Figura 5 - digrafo do sistema revampeado")'),
        md("## Tabela XII — comprimentos das tubulações"),
        code("display(tables.pipe_lengths_table(case))"),
        md("## Tabela XIII — vazões mássicas após a expansão"),
        code("""
study = run_design_study(case)
display(tables.mass_flow_table(study))
"""),
        md("""
## Tabela XIV — diâmetros antes do revamp, projeto tradicional e projeto otimizado

A coluna *Optimization* corresponde ao LP com a bomba 3 (a mais barata, Tabela XVI). A
solução indica a válvula do E-101 com **3.763 m** de perda de carga e zero nos demais,
exatamente como no artigo. Como no caso *grassroots*, o LP é degenerado: trechos de
diâmetro podem trocar entre tubulações em série (por exemplo 10 e 15) sem alterar o custo.
"""),
        code("""
PUBLISHED_XIV_OPT = {1: "10", 3: "12", 4: "10", 5: "8", 6: "6/8 (0.041/0.959)", 7: "10/8 (0.355/0.645)", 8: "10",
    9: "3 1/2", 10: "6/8 (0.272/0.728)", 11: "8", 12: "6", 13: "3", 14: "3 1/2", 15: "6", 16: "6", 17: "6", 18: "3",
    24: "3/2 (0.388/0.612)", 25: "10", 26: "12", 27: "4", 28: "8", 29: "5", 30: "5/4 (0.063/0.937)"}
PUBLISHED_XIV_TRAD = {1: "12", 3: "12", 4: "10", 5: "8", 6: "8", 7: "10", 8: "12", 9: "4", 10: "6", 11: "8", 12: "6",
    13: "3", 14: "4", 15: "6", 16: "8", 17: "6", 18: "3", 24: "3", 25: "10", 26: "12", 27: "4", 28: "8", 29: "5", 30: "5"}
tbl = tables.design_comparison_table(study, traditional="edgar_himmelblau")
tbl["Published traditional"] = [PUBLISHED_XIV_TRAD[e] for e in tbl["Edge"]]
tbl["Published optimization"] = [PUBLISHED_XIV_OPT[e] for e in tbl["Edge"]]
display(tbl)
display(tables.valve_table(study.best, case))
"""),
        md("""
### Sobre a coluna tradicional publicada

Com a vazão nova do E-101 (7.5 kg/s) o head mínimo requerido é **14.36 m** (o artigo cita
14.4 m) e a **bomba 3** (15.57 m a 109.2 kg/s) já é suficiente; as tubulações 9 e 14 ficam
em 3 1/2". A tabela publicada, porém, mostra 4" para 9 e 14 e a **bomba 4** — resultado que
se obtém dimensionando as linhas do E-101 com a vazão antiga, 11.8 kg/s (vazão total
113.5 kg/s). O relatório Scilab original reaproveitou um ficheiro de resultados do projeto
tradicional gerado com essa versão anterior dos dados (a v2.2 do código não recalcula o
tradicional). As Tabelas XIV-XVI "como publicadas" são reproduzidas abaixo com essa
hipótese explícita.
"""),
        code("""
from cwnet.design.evaluate import evaluate_design
from cwnet.design.traditional import traditional_design
from cwnet.hydraulics.headloss import build_hydraulic_tables
from cwnet.topology.massbalance import solve_all_scenarios

alt = case.model_copy(deep=True)
alt.scenarios[0].flows["E-101"] = 11.8
bal_alt = solve_all_scenarios(alt, study.topology)
hyd_alt = build_hydraulic_tables(alt, bal_alt)
trad_pub_design = traditional_design(alt, study.topology, hyd_alt, bal_alt, "edgar_himmelblau")
trad_pub = evaluate_design(case, study.topology, study.balances, trad_pub_design, study.cost_matrix,
                           label="Traditional (as published: E-101 sized at 11.8 kg/s)")
print("bomba:", trad_pub_design.pump_curve, "| head requerido: %.2f m" % trad_pub_design.required_pump_head)
print("diâmetros 9, 14, 27:", [trad_pub_design.pipes[e].describe(case)[0] for e in (9, 14, 27)])
"""),
        md("## Tabela XV — comportamento da rede com o projeto tradicional (como publicado)"),
        code("""
PUBLISHED_XV = {"E-101": (7.5, 12.0), "E-102": (28.7, 28.0), "E-103": (35.6, 36.5), "E-104": (15.6, 15.5),
                "E-105A/B": (6.2, 8.3), "E-106": (15.6, 16.8)}
tab = tables.network_behaviour_table(trad_pub)
tab["Published simulated flow (kg/s)"] = [PUBLISHED_XV[t][1] if t in PUBLISHED_XV else 117.1 for t in tab["Heat exchanger"]]
display(tab)
"""),
        md("""
## Tabela XVI — comparação econômica

Os quatro LPs reproduzem a tabela publicada (bomba 3 é a melhor, 12.1 % mais barata que o
tradicional publicado). A linha *Traditional (consistent)* usa a vazão nova do E-101.
"""),
        code("""
PUBLISHED_XVI = {"Traditional": (37378, 24193, 3409, 9776), "Proposed / Curve 1": (43746, 18265, 0, 25481),
    "Proposed / Curve 2": (34622, 21918, 3209, 9495), "Proposed / Curve 3": (32857, 24353, 3312, 5192),
    "Proposed / Curve 4": (33142, 26789, 3409, 2944)}
rows = []
def row(label, ev, pub):
    c = ev.costs
    return {"Methodology / case": label, "Pump": ev.design.pump_curve, "Total (USD/y)": round(c.total),
            "Operational (USD/y)": round(c.operating), "Pump (USD/y)": round(c.pump_capital_annualized),
            "Pipe (USD)": round(c.pipe_capital), "Published total": pub[0], "Published operational": pub[1],
            "Published pump": pub[2], "Published pipe": pub[3]}
rows.append(row("Traditional (as published)", trad_pub, PUBLISHED_XVI["Traditional"]))
rows.append(row("Traditional (consistent, E-101 = 7.5 kg/s)", study.traditional["edgar_himmelblau"], (None,)*4))
for ev in study.lp:
    rows.append(row(ev.label, ev, PUBLISHED_XVI[ev.label]))
display(pd.DataFrame(rows))
print("redução vs tradicional publicado: %.1f %% (artigo: 12.1 %%)" % (100 * (1 - study.best.costs.total / trad_pub.costs.total)))
print("redução vs tradicional consistente: %.1f %%" % (100 * (1 - study.best.costs.total / study.traditional["edgar_himmelblau"].costs.total)))
"""),
        code("ax = plots.plot_cost_comparison(study)"),
        md("""
## Nota: ranking com custos totalmente anualizados

Se o investimento em tubos também for anualizado (Eq. 16), a melhor alternativa de revamp passa a
ser **manter a bomba existente (curva 1)**, com 21 676 USD/ano: o menor custo de energia compensa o
maior investimento em tubos (ver `docs/errata.md`):
"""),
        code('display(tables.cost_comparison_table(study, basis="annualized"))'),
        md("## Verificação: a rede otimizada entrega as vazões especificadas"),
        code("""
display(tables.network_behaviour_table(study.best))
print("balanceada:", study.best.hydraulically_balanced)
ax = plots.plot_digraph(case, design=study.best.design, title="Projeto ótimo (bomba 3)")
"""),
    ]
    return notebook(cells, "Artigo 1 - revamp")


# ============================================================================ 03 paper 2
def paper2() -> nbformat.NotebookNode:
    cells = [
        md("""
# 03 · Artigo 2 — projeto multi-cenário (Costa, Tonassi & Souza, 2016)

**Hydraulic design optimization of multi-scenario of cooling water distribution system**,
*Chemical Engineering Transactions* 52, 2016.

A mesma rede do Artigo 1 deve operar em quatro cenários de vazão (Tabela 3) com válvulas de
controle em cada circuito. O MILP do artigo (binárias para a escolha da bomba) é resolvido
aqui como um LP por alternativa de bomba (equivalente): variáveis `X_{p,n}` e
`y_{h,sc}`; restrições (1)-(3) replicadas por cenário. Preço da energia 0.05 USD/kWh;
método tradicional de Towler & Sinnott com o maior diâmetro entre os cenários.
"""),
        code(HEADER),
        code(
            'case = load_case(CASES / "paper2_multiscenario.yaml")\nprint(case.name); print(case.description)'
        ),
        md("## Figura 1 — rede exemplo"),
        code('ax = plots.plot_digraph(case, title="Figura 1 - rede exemplo (2016)")'),
        md("## Tabelas 1-4 — dados"),
        code("""
print("Tabela 1 - comprimentos"); display(tables.pipe_lengths_table(case))
print("Tabela 2 - diâmetros"); display(tables.pipe_catalog_table(case))
print("Tabela 3 - vazões por cenário e condição de projeto"); display(tables.scenario_table(case))
print("Tabela 4 - curvas das bombas"); display(tables.pump_catalog_table(case))
print("fator de anualização r = %.3f" % case.economics.annualizing_factor)
"""),
        md("""
## Otimização

A bomba 0 (6.3 m de head) não consegue vencer a perda de carga dos trocadores mais os 5 m
de elevação: o seu LP é inviável e é reportado como tal. Ambas as abordagens escolhem a
bomba 1, como no artigo.
"""),
        code("""
study = run_design_study(case)
display(tables.cost_comparison_table(study))
print("melhor:", study.best.label, "| tradicional:", study.traditional["towler"].design.pump_curve)
"""),
        md("""
## Tabela 5 — diâmetros (otimização × tradicional)

Como nos demais casos, o LP tem ótimos alternativos (degenerados): a solução publicada
coloca 48.4 % de 10" na tubulação 1; aqui o mesmo comprimento de 10" pode aparecer na
tubulação 8 do mesmo coletor. O custo de tubos é o mesmo (Tabela 7).
"""),
        code("""
PUBLISHED_T5 = {1: ("10 (48.4%) / 12 (51.6%)", "14"), 3: ("12", "14"), 4: ("8 (34.2%) / 10 (65.8%)", "10"),
    5: ("6", "6"), 6: ("6", "6"), 7: ("8", "10"), 8: ("12", "14"), 9: ("3 1/2", "5"), 10: ("6", "8"), 11: ("8", "8"),
    12: ("6", "6"), 13: ("1 1/2 (20%) / 2 (80%)", "2 1/2"), 14: ("3 1/2 (2.4%) / 4 (97.6%)", "5"), 15: ("6", "8"),
    16: ("6 (24.4%) / 8 (75.6%)", "8"), 17: ("6", "6"), 18: ("2", "2 1/2")}
tbl = tables.design_comparison_table(study, traditional="towler")
tbl["Published optimization"] = [PUBLISHED_T5[e][0] for e in tbl["Edge"]]
tbl["Published traditional"] = [PUBLISHED_T5[e][1] for e in tbl["Edge"]]
display(tbl)
"""),
        md("## Tabela 6 — perdas de carga nas válvulas por cenário"),
        code("""
PUBLISHED_T6 = pd.DataFrame({"Heat exchanger": ["E-101", "E-102", "E-103", "E-104", "E-105"],
    "Published S1": [1.58, 1.55, 1.52, 1.33, 1.21], "Published S2": [0.00, 0.00, 0.00, 0.25, 0.13],
    "Published S3": [15.3, 21.75, 21.52, 16.56, 16.44], "Published S4": [0.89, 0.91, 0.22, 0.00, 0.00]})
display(tables.valve_table(study.best, case).merge(PUBLISHED_T6, on="Heat exchanger"))
"""),
        md("""
As válvulas dependem do vértice degenerado escolhido (um pouco mais de perda num tubo
implica um pouco menos numa válvula do mesmo circuito), por isso os valores dos cenários 1,
2 e 4 podem diferir ligeiramente dos publicados; no cenário 3 (E-102 e E-103 fora de
serviço) as válvulas absorvem ~15-22 m, como no artigo.

## Tabelas 7, 9 e 10 — custos

O artigo reporta *pump capital costs* = 3 051 $; esse valor é o custo anualizado
`r·C_PU` (com FMS = 1.3). Na Tabela 10 o total anualizado foi obtido como
`operacional + r·(tubos + 3 051)`, ou seja, o custo da bomba foi anualizado duas vezes.
A célula seguinte mostra os componentes calculados, a aritmética do artigo e a aritmética
consistente (`objective_basis: annualized`).
"""),
        code("""
best, trad = study.best, study.traditional["towler"]
r = case.economics.annualizing_factor
rows = []
for label, ev, pub in (("Optimization approach", best, (17516, 3051, 8959, 11712)),
                       ("Traditional approach", trad, (20941, 3051, 9605, 12818))):
    c = ev.costs
    rows.append({"Item": label,
                 "Pipe capital (USD)": round(c.pipe_capital), "published": pub[0],
                 "r x pump capital (USD/y)": round(c.pump_capital_annualized), "published ": pub[1],
                 "Operating (USD/y)": round(c.operating), "published  ": pub[2],
                 "Total, paper arithmetic (USD/y)": round(c.operating + r * (c.pipe_capital + c.pump_capital_annualized)),
                 "published   ": pub[3],
                 "Total, consistent (USD/y)": round(c.total_annualized)})
display(pd.DataFrame(rows))
print("redução de custo total (aritmética consistente): %.1f %%" % (100 * (1 - best.costs.total_annualized / trad.costs.total_annualized)))
"""),
        md("## Tabela 8 — vazões simuladas com o projeto tradicional (sem válvulas)"),
        code("""
PUBLISHED_T8 = {"E-101": 13.2, "E-102": 30.1, "E-103": 39.6, "E-104": 16.4, "E-105": 4.6}
tab = tables.network_behaviour_table(trad)
tab["Published simulated flow (kg/s)"] = [PUBLISHED_T8.get(t, round(sum(PUBLISHED_T8.values()), 1)) for t in tab["Heat exchanger"]]
display(tab)
"""),
        md("## Verificação: com as válvulas, a rede otimizada entrega as vazões de cada cenário"),
        code("""
display(tables.exchanger_flows_by_scenario_table(best))
display(tables.pump_operating_table(study))
print("balanceada em todos os cenários:", best.hydraulically_balanced)
"""),
        code("""
ax = plots.plot_digraph(case, design=best.design, title="Projeto ótimo multi-cenário (bomba 1)")
ax2 = plots.plot_cost_comparison(study, basis="annualized")
"""),
    ]
    return notebook(cells, "Artigo 2 - multi-cenário")


# ============================================================================ 04 sensitivity
def sensitivity() -> nbformat.NotebookNode:
    cells = [
        md("""
# 04 · Análise de sensibilidade ao preço da energia

A versão submetida do Artigo 1 continha uma seção (7.6, Figuras 4-9) com a sensibilidade
dos projetos ao preço da energia, removida na versão publicada. O código Scilab original
(`otimizaRede13_sensib.sci`) varria o preço de 0.0025 a 0.20 USD/kWh. Reproduzimos aqui
essa análise com `cwnet.design.sensitivity.energy_price_sweep`.

No método de Edgar & Himmelblau o diâmetro econômico escala com `pc^0.164`, como no
código original.
"""),
        code(HEADER),
        code("""
from cwnet.design.sensitivity import energy_price_sweep
case = load_case(CASES / "paper1_grassroots.yaml")
prices = np.round(np.arange(0.01, 0.2001, 0.01), 4)
df = energy_price_sweep(case, prices)
df.head()
"""),
        md("## Figura 4 — função objetivo ótima de cada curva de bomba"),
        code("""
pumps = [c.tag for c in case.pump_catalog]
ax = plots.plot_sensitivity(df, "energy_price", [f"lp_{p}_total" for p in pumps], xlabel="Preço da energia (USD/kWh)",
                            ylabel="Custo total (USD/ano)", title="Custo ótimo por alternativa de bomba")
print("melhor bomba por preço:"); display(df[["energy_price", "best_pump", "best_total"]].T)
"""),
        md("## Figuras 5 e 6 — projeto proposto × métodos tradicionais e redução de custo"),
        code("""
ax = plots.plot_sensitivity(df, "energy_price", ["best_total", "traditional_edgar_himmelblau_total", "traditional_towler_total"],
                            xlabel="Preço da energia (USD/kWh)", ylabel="Custo total (USD/ano)",
                            title="Projeto proposto (melhor bomba) vs tradicionais", highlight="best_total")
df["reduction_vs_EH_%"] = 100 * (1 - df["best_total"] / df["traditional_edgar_himmelblau_total"])
df["reduction_vs_Towler_%"] = 100 * (1 - df["best_total"] / df["traditional_towler_total"])
ax2 = plots.plot_sensitivity(df, "energy_price", ["reduction_vs_EH_%", "reduction_vs_Towler_%"],
                             xlabel="Preço da energia (USD/kWh)", ylabel="Redução de custo (%)", title="Redução de custo do projeto proposto")
"""),
        md("## Figuras 7, 8 e 9 — custos operacionais, de bomba e de tubos"),
        code("""
fig, axes = plt.subplots(1, 3, figsize=(16, 4))
plots.plot_sensitivity(df, "energy_price", ["best_operating", "traditional_edgar_himmelblau_operating", "traditional_towler_operating"], ax=axes[0], ylabel="USD/ano", title="Custo operacional da bomba")
plots.plot_sensitivity(df, "energy_price", ["best_pump_cost", "traditional_edgar_himmelblau_pump", "traditional_towler_pump"], ax=axes[1], ylabel="USD/ano", title="Custo (anualizado) da bomba")
plots.plot_sensitivity(df, "energy_price", ["best_pipe", "traditional_edgar_himmelblau_pipe", "traditional_towler_pipe"], ax=axes[2], ylabel="USD", title="Investimento em tubos")
plt.tight_layout()
"""),
        code("df.round(0)"),
    ]
    return notebook(cells, "Sensibilidade")


# ============================================================================ 05 legacy
def legacy() -> nbformat.NotebookNode:
    cells = [
        md("""
# 05 · Casos legados do código Scilab (v2.2)

O código Scilab original lia ficheiros `caso*.txt`. O conversor `cwnet.io.load_legacy_case`
transforma-os em `DesignCase`; aqui executamos os cinco casos de `legacy/scilab/v2.2/Dados`
e comparamos com os relatórios HTML gerados pelo Scilab (`Relatorios/caso*.htm`).
"""),
        code(HEADER),
        code("""
from cwnet.io import load_legacy_case
LEGACY = Path("../legacy/scilab/v2.2/Dados")
SCILAB = {  # (total, operating, pump, pipe) kUSD/y from the Scilab reports; the traditional of caso2 is stale (see notebook 02)
    "caso1": {"Traditional (edgar_himmelblau)": (42.815, 23.184, 3.209, 16.422), "Curve 1": (39.811, 20.183, 3.045, 16.583), "Curve 2": (41.768, 24.22, 3.209, 14.339), "Curve 3": (43.939, 26.911, 3.312, 13.716), "Curve 4": (46.292, 29.602, 3.409, 13.281)},
    "caso2": {"Curve 1": (43.746, 18.265, 0, 25.481), "Curve 2": (34.622, 21.918, 3.209, 9.495), "Curve 3": (32.857, 24.353, 3.312, 5.192), "Curve 4": (33.142, 26.789, 3.409, 2.944)},
    "caso3": {"Traditional (edgar_himmelblau)": (46.754, 24.316, 3.409, 19.029), "Curve 1": (47.664, 18.265, 0, 29.399), "Curve 2": (44.418, 21.918, 3.209, 19.291), "Curve 3": (45.76, 24.353, 3.312, 18.095), "Curve 4": (47.27, 26.789, 3.409, 17.072)},
    "caso4": {"Traditional (edgar_himmelblau)": (43.441, 22.744, 3.209, 17.488), "Curve 1": (41.167, 19.940, 3.045, 18.182), "Curve 2": (42.872, 23.927, 3.209, 15.736), "Curve 3": (44.355, 26.587, 3.312, 14.456), "Curve 4": (46.503, 29.246, 3.409, 13.848)},
}
rows = []
for name in ["caso1", "caso2", "caso3", "caso4", "caso5"]:
    case = load_legacy_case(LEGACY / f"{name}.txt", pump_fms=1457.4 / 1123.6)
    study = run_design_study(case)
    evs = [(f"Traditional ({k})", e) for k, e in study.traditional.items()] + [(e.design.pump_curve, e) for e in study.lp]
    for label, ev in evs:
        c = ev.costs
        pub = SCILAB.get(name, {}).get(label, (None,) * 4)
        rows.append({"case": name, "project": case.name, "design": label, "pump": ev.design.pump_curve,
                     "total (kUSD/y)": round(c.total / 1e3, 3), "Scilab": pub[0],
                     "operating": round(c.operating / 1e3, 3), "Scilab ": pub[1],
                     "pump cost": round(c.pump_capital_annualized / 1e3, 3), "Scilab  ": pub[2],
                     "pipe cost": round(c.pipe_capital / 1e3, 3), "Scilab   ": pub[3],
                     "balanced": ev.hydraulically_balanced})
display(pd.DataFrame(rows))
"""),
        md("""
Notas: as linhas *Traditional* dos relatórios Scilab de `caso2` e `caso3` provêm de ficheiros de
resultados antigos (ver notebook 02); aqui o tradicional é recalculado com os dados atuais.
No `caso5` o ficheiro legado atribui `fop = 0.25` a um único cenário; o conversor
normaliza as frações de tempo para 1, pelo que o custo operacional é 4× o do relatório
Scilab. O `caso3` ("rebuild") projeta a rede do revamp como se fosse nova (todas as
tubulações `new`, bomba nova) — Tabela 19 do rascunho do artigo.
"""),
    ]
    return notebook(cells, "Casos legados")


NOTEBOOKS = {
    "00_configuration_tutorial.ipynb": tutorial,
    "01_paper1_grassroots.ipynb": paper1_grassroots,
    "02_paper1_revamp.ipynb": paper1_revamp,
    "03_paper2_multiscenario.ipynb": paper2,
    "04_energy_price_sensitivity.ipynb": sensitivity,
    "05_legacy_scilab_cases.ipynb": legacy,
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-execute", action="store_true")
    parser.add_argument("--only", nargs="*", help="names of notebooks to build")
    args = parser.parse_args(argv)
    OUT.mkdir(exist_ok=True)
    for name, builder in NOTEBOOKS.items():
        if args.only and name not in args.only:
            continue
        nb = builder()
        if not args.no_execute:
            client = NotebookClient(
                nb, timeout=1800, kernel_name="python3", resources={"metadata": {"path": str(OUT)}}
            )
            client.execute()
        nbformat.write(nb, OUT / name)
        print("written", OUT / name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
