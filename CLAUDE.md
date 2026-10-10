# cwnet — project guide for coding agents

Python reimplementation of Souza et al. (2014, *Chem. Eng. Comm.* 201:1054–1076) and Costa,
Tonassi & Souza (2016, *Chem. Eng. Trans.* 52) — hydraulic design optimization of cooling water
pipe networks. One of three repositories that follow the same conventions (`docs/conventions.md`).

## Commands
- `make setup` — `uv sync --all-extras` (Python 3.12, see `.python-version`).
- `make test` — regression tests against the published tables (`tests/`), ~1 min.
- `make lint` / `make format` — ruff.
- `make run` / `make eval` / `make figures` — `cwnet run|eval|figures` on the three paper cases.
- `make notebooks` — `scripts/build_notebooks.py` regenerates and executes `notebooks/`.
- CLI verbs: `info`, `validate`, `run`, `eval`, `figures`, `simulate`, `convert-legacy`.

## Layout
- `src/cwnet/model` pydantic data model (`DesignCase` root; YAML cases in `cases/`).
- `src/cwnet/topology` incidence / selection / circuit matrices, mass balance (Eqs. 1–10).
- `src/cwnet/hydraulics` Churchill friction factor, head-loss tables per scenario.
- `src/cwnet/costs` Narang pipe cost, Couper pump cost, operating cost.
- `src/cwnet/design` traditional sizing, LP per pump (SciPy/HiGHS), QP post-processing,
  evaluation (simulation + costs), orchestration, sensitivity.
- `src/cwnet/simulation` rigorous Newton simulation; ε-NTU thermal check.
- `src/cwnet/reporting` pandas tables, matplotlib figures, `eval` comparisons, exports.
- `src/cwnet/references.py` paper references, paper cases, `data/reference/published_values.json`.
- `legacy/scilab` original Scilab code (read-only); `docs/` formulation, architecture,
  reproduction, errata (English) and `docs/pt/` (Portuguese notes).
- Raw material of the papers (manuscripts, PDFs) is outside the repository:
  `~/code/personal/paper-raw-material/paper-hydraulic-design-optimization/`.

## Conventions
- SI units internally (m, kg/s, Pa.s, m of head); nominal diameters in inches; pressures bar g.
- `economics.objective_basis = "published"` reproduces the published totals (pipe capital not
  annualized); `"annualized"` applies `r` to both capital terms (Eqs. 15–18 of the 2014 paper).
- LP optima are degenerate: compare designs by cost and by total length per diameter along
  series groups, never by the exact split of one pipe.
- Keep tests green and ruff clean; notebooks are generated, do not edit the `.ipynb` by hand.
