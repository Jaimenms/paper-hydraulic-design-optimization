# cwnet — hydraulic design optimization of cooling water pipe networks

Python implementation of the matrix / split-pipe linear programming approach for the
hydraulic design of cooling water distribution networks, including revamp and
multi-scenario problems, with a rigorous network simulator for verification.

* Souza, J. N. M., Ventin, F. F., Tavares, V. B. G., Costa, A. L. H. (2014).
  *A matrix approach for optimization of pipe networks in cooling water systems.*
  Chemical Engineering Communications 201(8), 1054-1076.
  [doi:10.1080/00986445.2013.800484](https://doi.org/10.1080/00986445.2013.800484)
* Costa, A. L. H., Tonassi, E. L. R., Souza, J. N. M. (2016).
  *Hydraulic design optimization of multi-scenario of cooling water distribution system.*
  Chemical Engineering Transactions 52.

The original Scilab code and the papers are kept under `docs/raw/` for reference; this
repository is a complete, tested re-implementation in Python (NumPy/SciPy/pandas, HiGHS LP
solver), designed so that **every parameter of the problem, including the network layout, is
configurable** from a YAML file or from Python.

## What it does

Given a cooling water network (digraph of pipe sections, one pump and coolers in parallel),
the cooling water flow rate demanded by each cooler (in one or several operating scenarios),
a catalogue of commercial pipe diameters, a set of pump alternatives and the economic data:

1. solves the network mass balance and identifies the hydraulic circuits automatically
   (incidence, selection and circuit matrices, Eqs. 1-10 of the 2014 paper);
2. designs the network by the **traditional** economic-velocity rules
   (Edgar & Himmelblau, Towler & Sinnott) for comparison;
3. solves, for each pump alternative, the **split-pipe linear program** that gives the length
   fraction of each commercial diameter in each pipe section (and the valve head losses needed
   to balance revamped or multi-scenario networks), then selects the cheapest alternative;
4. **simulates** every design rigorously (Newton solution of the mass and mechanical energy
   balances) and checks the thermal performance of the coolers (effectiveness-NTU);
5. reports the tables and figures of the papers (pandas / matplotlib).

## Installation

Requires Python ≥ 3.11 and [uv](https://docs.astral.sh/uv/) (or pip).

```bash
uv sync --extra dev --extra notebooks     # creates .venv with all dependencies
uv run pytest                              # regression tests against the published tables
```

With pip: `pip install -e ".[dev,notebooks]"`.

## Quick start

Command line:

```bash
uv run cwnet validate cases/paper1_grassroots.yaml
uv run cwnet optimize cases/paper1_grassroots.yaml --traditional edgar_himmelblau --out results/
uv run cwnet simulate cases/paper2_multiscenario.yaml
uv run cwnet convert-legacy docs/raw/scilab/v2.2/Dados/caso2.txt my_case.yaml
```

Python:

```python
from cwnet import load_case, run_design_study
from cwnet.reporting import plots, tables

case = load_case("cases/paper1_grassroots.yaml")
study = run_design_study(case, traditional_methods=["edgar_himmelblau"])

print(tables.cost_comparison_table(study))          # Table XI
print(tables.design_comparison_table(study))        # Table IX
best = study.best                                   # cheapest LP design (pump + diameters + valves)
print(best.design.pipes[7].describe(case))          # ('8/10', '0.399/0.601')
plots.plot_digraph(case, design=best.design)        # Figure 2 with the selected diameters
```

Building a case programmatically (see `notebooks/00_tutorial_configuracao.ipynb`):

```python
from cwnet import DesignCase, Edge, HeatExchanger, Network, Node, PipeSection, PumpCurve, PumpUnit, Scenario

case = DesignCase(
    name="my network",
    network=Network(
        nodes=[Node(id=1, elevation=0.0, pressure=0.0), Node(id=6, elevation=5.0, pressure=0.0)],
        edges=[Edge(id=1, tail=1, head=2), Edge(id=2, tail=2, head=3), Edge(id=3, tail=3, head=4),
               Edge(id=4, tail=4, head=5), Edge(id=5, tail=5, head=6)],
    ),
    pipes=[PipeSection(edge=1, length=10), PipeSection(edge=3, length=100), PipeSection(edge=5, length=100)],
    pump=PumpUnit(edge=2),
    pump_catalog=[PumpCurve(tag="A", coefficients=[31.5, -135.0, -415.6])],
    exchangers=[HeatExchanger(edge=4, tag="E-1", design_flow=30.0, design_head_loss=5.0)],
    scenarios=[Scenario(flows={"E-1": 30.0})],
)
```

## Case files

`cases/*.yaml` hold the data of the papers with comments on every parameter:

| File | Problem |
|---|---|
| `paper1_grassroots.yaml` | 2014 paper, grassroots design (Tables I-XI) |
| `paper1_revamp.yaml` | 2014 paper, revamp with existing pump/pipes and valves (Tables XII-XVI) |
| `paper2_multiscenario.yaml` | 2016 paper, four operating scenarios with control valves (Tables 1-10) |
| `legacy/scilab_caso*.yaml` | the five cases of the original Scilab v2.2 code, converted |

Sections of a case: `fluid`, `network` (nodes/edges), `pipes`, `pump`, `pump_catalog`,
`exchangers`, `pipe_catalog`, `economics`, `scenarios`, `options`. The pydantic model in
`src/cwnet/model/` documents and validates every field.

## Notebooks (Portuguese)

Generated and executed by `scripts/build_notebooks.py` (`make notebooks`):

| Notebook | Content |
|---|---|
| `00_tutorial_configuracao` | build a network from scratch, change parameters/topology, revamp, YAML, CLI |
| `01_artigo1_grassroots` | Figures 1-4 and Tables I-XI of the 2014 paper vs. published values |
| `02_artigo1_revamp` | Figure 5 and Tables XII-XVI (revamp, valves) |
| `03_artigo2_multicenario` | Figure 1 and Tables 1-10 of the 2016 paper (multi-scenario) |
| `04_sensibilidade_preco_energia` | energy-price sensitivity (Figures 4-9 of the submitted manuscript) |
| `05_casos_legados_scilab` | the legacy Scilab cases vs. the original HTML reports |

## Reproduction status

| Published result | Status |
|---|---|
| Table XI (grassroots costs, 5 designs) | reproduced within 3 USD/y (rounded unit conversion in the original code) |
| Table IX (grassroots diameters) | same cost; same length per diameter on each series group (LP is degenerate) |
| Table X (traditional network behaviour) | flows reproduced; outlet temperatures differ ≤ 1 °C (different thermal model) |
| Table XVI (revamp costs) and E-101 valve 3.763 m | reproduced |
| Table XIV traditional column | reproduced only with the previous E-101 flow (stale result in the original run) |
| 2016 Tables 6, 7, 8, 9 | reproduced; Table 10 totals annualize the pump cost twice (both shown) |

Details in [`docs/reproduction_notes.md`](docs/reproduction_notes.md); the mapping between
equations and code is in [`docs/formulation.md`](docs/formulation.md).

## Project layout

```
src/cwnet/
  model/        pydantic data model (DesignCase, Network, PipeSection, PumpCurve, ...)
  io/           YAML/JSON I/O and the legacy Scilab format reader
  topology/     incidence, selection and circuit matrices; mass balance
  hydraulics/   Churchill friction factor, head-loss tables
  costs/        pipe (Narang) and pump (Couper) capital costs, operating cost
  design/       traditional sizing, LP per pump, QP post-processing, evaluation, study, sensitivity
  simulation/   rigorous network simulation (Newton) and ε-NTU thermal check
  reporting/    pandas tables and matplotlib figures of the papers
  cli.py        `cwnet` command line
cases/          YAML cases   notebooks/   executed notebooks   tests/   pytest suite
docs/raw/       papers, drafts, references and the original Scilab/GAMS code
```

## Resumo em português

`cwnet` reimplementa em Python o método de otimização do projeto hidráulico de redes de água
de resfriamento dos artigos de 2014 (Chem. Eng. Comm.) e 2016 (Chem. Eng. Trans.): balanço
de massa matricial, circuitos hidráulicos automáticos, projeto *split-pipe* por programação
linear para cada bomba (grassroots, revamp e multi-cenário com válvulas), projeto tradicional
por velocidade econômica, simulação rigorosa e verificação térmica. Todos os parâmetros,
inclusive o desenho da rede, são configuráveis em YAML ou em Python. Os notebooks em
`notebooks/` reproduzem as tabelas e figuras dos dois artigos e comentam as diferenças
encontradas (`docs/reproduction_notes.md`).

## License

MIT (see `LICENSE`).
