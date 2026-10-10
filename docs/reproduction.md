# Reproduction status and notes

Formal errata of the two papers are in [`errata.md`](errata.md); a classified discussion in
Portuguese (errata and discrepancies, with the corrected tables) is in
[`pt/discrepancias_e_errata.md`](pt/discrepancias_e_errata.md).

## Status per table and figure

| Paper item | Notebook | Status |
|---|---|---|
| 2014, Figures 1-4 (system, digraph, split pipe, algorithm) | 01 | drawn from the case data |
| 2014, Tables I-VIII (inputs, mass balance) | 01 | exact |
| 2014, Table IX (grassroots diameters) | 01 | same cost; same length per diameter on each series group (LP degenerate) |
| 2014, Table X (traditional network behaviour) | 01 | flows exact; outlet temperatures within 1 degC (different thermal model) |
| 2014, Table XI (grassroots costs) | 01 | within 3 USD/y |
| 2014, Figure 5, Tables XII-XIII (revamp inputs) | 02 | exact |
| 2014, Table XIV (revamp diameters), valve 3.763 m | 02 | reproduced up to LP degeneracy; traditional column only with the former E-101 flow |
| 2014, Tables XV-XVI (revamp behaviour and costs) | 02 | LP rows within 3 USD/y; traditional row as published only with E-101 at 11.8 kg/s |
| 2016, Figure 1, Tables 1-4 (inputs) | 03 | exact |
| 2016, Table 5 (diameters) | 03 | reproduced up to LP degeneracy |
| 2016, Table 6 (valves) | 03 | within 0.04 m |
| 2016, Tables 7-9 (capital, traditional flows, operating costs) | 03 | within 0.3 % |
| 2016, Table 10 (totals) | 03 | published arithmetic reproduced; consistent totals also given |
| Manuscript sensitivity figures (energy price) | 04 | reproduced qualitatively (section removed from the published paper) |

## Discrepancies and their causes

Differences between the results of `cwnet` and the published tables, and their causes.
All comparisons are automated in `tests/` and shown in the notebooks.

## Paper 1 (2014) — grassroots (Tables IX-XI)

1. **Table XI totals agree to ±3 USD/y.** The original Scilab code converted the pipe cost
   with the rounded factor 3.281 ft/m (`3.281^(m+1) C1 L (D·0.0254)^m`); `cwnet` uses
   `C1/0.3048 (D/12)^m` exactly. The difference is 0.012 % (≈2 USD on 16 583 USD).
2. **Pipe cost is not annualized in the published totals.** Eq. (16) multiplies the pipe
   capital by `r`, but the code and Table XI use the investment itself
   (16 583 USD for curve 1; `r·16 583 = 2 220`). `economics.objective_basis: published`
   reproduces this; `annualized` applies `r` to both capital terms (ranking unchanged
   for the grassroots case, see note 8 for the revamp).
3. **LP degeneracy.** Pipes in series carrying the same flow (1, 3, 8; 4, 7; 9, 14; 11, 16;
   13, 18; 10, 15) can exchange their diameter subsections at identical cost. The published
   vertex and the HiGHS vertex differ only in this allocation; the total length of each
   diameter per series group is the same (checked in `test_optimal_design_subsections_table_ix`).
4. **Required head of the traditional design.** The text says 17.8 m; recomputing with the
   data of Tables I-VII gives 17.66 m. Pump 2 is selected in both cases (17.84 m at 94.8 kg/s).
5. **Table X temperatures.** The simulated flows match (13.8/32.2/39.8/12.7/4.2 kg/s,
   total 102.7). The hot outlet temperatures differ by up to ~1 °C because the paper used the
   thermohydraulic simulator of Tavares et al. (2010); `cwnet` ships the simplified ε-NTU
   routine (`heatcheck`) found in the original Scilab code, which already at the design
   flows returns 64.1 °C for E-101 instead of the 65.0 °C target.
6. **Pump curve coefficients and FMS.** The published tables were computed with the unrounded
   coefficients of the data files (e.g. −415.5675 instead of −415.6) and with
   `F_MS = 1457.4/1123.6 = 1.2971` (Table IV prints 1.3). The YAML cases keep the unrounded values.

## Paper 1 (2014) — revamp (Tables XII-XVI)

7. **LP results reproduce Table XVI** (±3 USD/y) and the valve of E-101 (3.763 m).
   Table XIV optimal diameters agree up to the degeneracy of note 3.
8. With fully annualized costs the best revamp alternative becomes **Curve 1, i.e. keeping the
   existing pump** (21 676 USD/y; Curve 2: 26 398; Curve 3: 28 360) instead of Curve 3 (32 857 USD/y
   in the published convention). See `errata.md`.
9. **Traditional revamp design as published is inconsistent with Table XIII.** With E-101 at
   7.5 kg/s the required head is 14.36 m (14.4 m in the text) and pump 3 suffices; pipes 9
   and 14 stay at 3 1/2". The published traditional column (pipes 9 and 14 at 4", pump 4,
   37 378 USD/y, Table XV flows) is reproduced exactly when the E-101 branch is sized with the
   former flow of 11.8 kg/s (total 113.5 kg/s). The Scilab v2.2 driver did not recompute the
   traditional design (`executa_classico = 0`) and the report reused a stale result file
   produced with that earlier data. Both versions are shown in notebook 02.

## Paper 2 (2016) — multi-scenario (Tables 5-10)

10. **Capital costs (Table 7) and operating costs (Table 9) are reproduced**
    (17 516 / 20 941 USD; 8 959 / 9 605 USD/y) with `F_MS = 1.3` and `p_c = 0.05 USD/kWh`.
11. The "pump capital cost" of 3 051 USD is `r·C_PU` (annualized). The totals of Table 10
    (11 712 / 12 818 USD/y) equal `C_OP + r·(C_pipe + 3 051)`, i.e. the pump term was
    annualized twice. Notebook 03 shows both arithmetics; with the capital costs annualized
    once (`objective_basis: annualized`) the totals are 14 364 / 15 431 USD/y and the
    optimized design remains 6.9 % cheaper.
12. Table 5 is reproduced up to LP degeneracy (note 3); the valve head losses of Table 6
    depend on the chosen vertex (scenario 3 values of 15-22 m are reproduced).
13. Table 4 lists a "Pump 0" (6.3 m) that cannot feed the network; `cwnet` reports its LP as
    infeasible and ranks the remaining alternatives (pump 1 is optimal, as published).

## Original Scilab code

14. `geraParametros_opt` adds the fixed localized losses `Fac` both to the pipe coefficients and
    to the right-hand side (double counting); harmless because `Fac = 0` in all cases.
    `cwnet` counts them once.
15. `determinaHimmelblau/Towler` (v2.2) multiply the velocity-limited diameter by 0.0254 a
    second time, effectively disabling the velocity constraint in the traditional design;
    harmless for the published cases (velocities < 2 m/s).
16. The traditional entries of the Scilab reports of `caso2` and `caso3` come from stale
    result files (note 9); `cwnet` recomputes them with the current data (pump 3 instead of 4).
17. `caso5.txt` assigns `fop = 0.25` to a single scenario; `cwnet` normalizes the time
    fractions, so its operating cost is four times the Scilab report.
