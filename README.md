# cwnet — hydraulic design optimization of cooling water pipe networks

Python reimplementation of two papers on the hydraulic design of cooling water distribution
networks (split-pipe linear programming on a matrix description of the network, revamp and
multi-scenario problems), with a rigorous network simulator for verification:

> J. N. M. Souza, F. F. Ventin, V. B. G. Tavares, A. L. H. Costa, **A matrix approach for
> optimization of pipe networks in cooling water systems**, *Chemical Engineering Communications*
> 201 (8) (2014) 1054–1076. https://doi.org/10.1080/00986445.2013.800484

> A. L. H. Costa, E. L. R. Tonassi, J. N. M. Souza, **Hydraulic design optimization of
> multi-scenario of cooling water distribution system**, *Chemical Engineering Transactions*
> 52 (2016) 1189–1194. https://doi.org/10.3303/CET1652199

The original work was developed in Scilab (2014) and GAMS/CPLEX (2016); the Scilab code is kept in
`legacy/scilab/`. This repository rebuilds the method in Python (NumPy/SciPy with the HiGHS LP
solver, pydantic data model), reproduces every table and figure of the two papers in Jupyter
notebooks and compares them with the published values. The network topology and **every**
parameter are configuration data (YAML), so other cooling water systems can be designed with the
same code. The repository follows the conventions of a series of paper-reproduction repositories
([`docs/conventions.md`](docs/conventions.md)).

## What it does

Given a cooling water network (digraph of pipe sections, one pump and coolers in parallel), the
cooling water flow rate demanded by each cooler in one or several operating scenarios, a catalogue
of commercial diameters, a set of pump alternatives and the economic data, `cwnet`:

1. solves the network mass balance and identifies the hydraulic circuits automatically
   (incidence, selection and circuit matrices, Eqs. 1–10 of the 2014 paper);
2. designs the network by the traditional economic-velocity rules (Edgar & Himmelblau,
   Towler & Sinnott) for comparison;
3. solves, for each pump alternative, the split-pipe linear program that gives the length fraction
   of each commercial diameter in each pipe section (and the valve head losses that balance revamped
   or multi-scenario networks), then selects the cheapest alternative;
4. simulates every design rigorously (Newton solution of the mass and mechanical-energy balances)
   and checks the thermal performance of the coolers (effectiveness-NTU);
5. reports the tables and figures of the papers and the deviations from the published values.

## What is reproduced

| Paper item | Notebook | Status |
|---|---|---|
| 2014, Figures 1–4 and Tables I–VIII | 01 | exact (inputs, mass balance, circuits) |
| 2014, Table IX (grassroots diameters) | 01 | same cost and same length per diameter on each series group (the LP optimum is degenerate) |
| 2014, Table X (traditional network behaviour) | 01 | flows exact; outlet temperatures within 1 °C (different thermal model) |
| 2014, Table XI (grassroots costs) | 01 | within 3 USD/y |
| 2014, Figure 5, Tables XII–XVI (revamp) and the E-101 valve of 3.763 m | 02 | LP results within 3 USD/y; traditional column only with the former E-101 flow (see errata) |
| 2016, Figure 1, Tables 1–9 (multi-scenario) | 03 | within 0.3 % (Table 5 up to LP degeneracy; valves within 0.04 m) |
| 2016, Table 10 (totals) | 03 | published arithmetic reproduced; consistent totals also given (see errata) |
| Energy-price sensitivity of the submitted manuscript | 04 | reproduced |

Details in [`docs/reproduction.md`](docs/reproduction.md); the formal errata of both papers are in
[`docs/errata.md`](docs/errata.md).

## Quick start

```bash
make setup            # .venv with uv (Python 3.12) and all extras
make test             # regression tests against the published tables (~1 min)
make run              # design study of the three paper cases -> results/<case>/
make eval             # deviations from the published values -> results/eval/report.md
make figures          # figures and tables of the papers -> figures/
make notebooks        # regenerate and execute notebooks/
```

Command line (`uv run cwnet ...` or `.venv/bin/cwnet ...`):

```bash
cwnet info                                        # papers, paper cases, version
cwnet validate cases/paper1_grassroots.yaml       # schema + topology check (file or case name)
cwnet run paper1_revamp --out results             # one case (default: all three)
cwnet eval --case paper2_multiscenario            # compare with the published tables
cwnet figures --out figures
cwnet simulate paper1_grassroots                  # hydraulic results of the optimal design
cwnet convert-legacy legacy/scilab/v2.2/Dados/caso2.txt my_case.yaml
```

Python:

```python
from cwnet import load_case, run_design_study
from cwnet.reporting import plots, tables

case = load_case("cases/paper1_grassroots.yaml")
study = run_design_study(case, traditional_methods=["edgar_himmelblau"])
print(tables.cost_comparison_table(study))        # Table XI
print(tables.design_comparison_table(study))      # Table IX
best = study.best                                 # cheapest LP design (pump, diameters, valves)
print(best.design.pipes[7].describe(case))        # ('8/10', '0.399/0.601')
plots.plot_digraph(case, design=best.design)      # Figure 2 with the selected diameters
```

## Notebooks

Generated and executed by `scripts/build_notebooks.py` (`make notebooks`); the narrative is in
Portuguese.

| Notebook | Paper items |
|---|---|
| `00_configuration_tutorial` | build a network from scratch, change parameters and topology, revamp, YAML, CLI |
| `01_paper1_grassroots` | 2014: Figures 1–4, Tables I–XI, comparison with the published values |
| `02_paper1_revamp` | 2014: Figure 5, Tables XII–XVI (revamp, valves), traditional column as published and corrected |
| `03_paper2_multiscenario` | 2016: Figure 1, Tables 1–10 (four scenarios, control valves, infeasible pump) |
| `04_energy_price_sensitivity` | energy-price sensitivity (Figures 4–9 of the submitted manuscript) |
| `05_legacy_scilab_cases` | the five cases of the original Scilab code vs. its HTML reports |

## Configuring a case

`cases/*.yaml` hold the data of the papers with a comment on every parameter:

| File | Problem |
|---|---|
| `paper1_grassroots.yaml` | 2014 paper, grassroots design (Tables I–XI) |
| `paper1_revamp.yaml` | 2014 paper, revamp with existing pump/pipes and valves (Tables XII–XVI) |
| `paper2_multiscenario.yaml` | 2016 paper, four operating scenarios with control valves (Tables 1–10) |
| `legacy/scilab_caso*.yaml` | the five cases of the original Scilab code, converted |

Sections of a case: `fluid`, `network` (nodes and directed edges), `pipes` (length, roughness,
status new/existing/fixed), `pump` and `pump_catalog` (curves, efficiency, rated flow),
`exchangers` (design flow and head loss, optional thermal data), `pipe_catalog`, `economics`
(energy price, interest, horizon, cost correlations, objective basis), `scenarios` (flows and time
fractions) and `options` (velocity limit, valves, traditional method, solver). The pydantic model
in `src/cwnet/model/` documents and validates every field; `cwnet validate` checks a file and
`cwnet convert-legacy` imports the original Scilab text format. Notebook 00 builds a network
programmatically.

## Layout

```
README.md  CITATION.cff  LICENSE  CLAUDE.md  Makefile  pyproject.toml  uv.lock  .python-version
src/cwnet/        model/ io/ topology/ hydraulics/ costs/ design/ simulation/ reporting/ references.py cli.py
cases/            YAML cases of the papers (+ legacy/ conversions of the Scilab cases)
data/reference/   published values of the papers (published_values.json), used by `eval` and the tests
notebooks/        executed notebooks (generated by scripts/build_notebooks.py)
scripts/          build_notebooks.py
tests/            pytest suite (regression against the published tables)
docs/             formulation.md architecture.md reproduction.md errata.md conventions.md pt/
legacy/           original Scilab code (v1–v2.2) and the GAMS sketch of the LP
results/          outputs of `make run` and `make eval` (not versioned)
figures/          outputs of `make figures` (not versioned)
```

## Documents

* [`docs/formulation.md`](docs/formulation.md) — equations of the papers ↔ code.
* [`docs/architecture.md`](docs/architecture.md) — package layout and design decisions.
* [`docs/reproduction.md`](docs/reproduction.md) — reproduction status and the discrepancies that are not paper errors.
* [`docs/errata.md`](docs/errata.md) — formal errata of the two papers (location, published text, correction, impact).
* [`docs/pt/discrepancias_e_errata.md`](docs/pt/discrepancias_e_errata.md) — classified discussion in Portuguese with the corrected tables.
* [`docs/conventions.md`](docs/conventions.md) — conventions shared by the repositories of the series.

## Resumo em português

`cwnet` reimplementa em Python o método de otimização do projeto hidráulico de redes de água de
resfriamento dos artigos de 2014 (*Chem. Eng. Comm.*) e 2016 (*Chem. Eng. Trans.*): balanço de
massa matricial, circuitos hidráulicos automáticos, projeto *split-pipe* por programação linear
para cada bomba (grassroots, revamp e multi-cenário com válvulas), projeto tradicional por
velocidade econômica, simulação rigorosa e verificação térmica. Todos os parâmetros, inclusive o
desenho da rede, são configuráveis em YAML ou em Python. Os notebooks em `notebooks/` reproduzem
as tabelas e figuras dos dois artigos e comparam com os valores publicados; as diferenças
encontradas e as erratas estão em `docs/pt/discrepancias_e_errata.md` e `docs/errata.md`.
Comandos: `make setup`, `make test`, `make run`, `make eval`, `make figures`, `make notebooks`.

## License

MIT for the code (see `LICENSE`). The papers keep the copyright of their publishers and are not
distributed with this repository.
