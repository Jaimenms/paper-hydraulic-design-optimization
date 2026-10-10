# Mathematical formulation and its implementation

This note maps the equations of the two papers to the code of `cwnet`.

| Paper | Reference |
|---|---|
| **P1** | Souza, J.N.M., Ventin, F.F., Tavares, V.B.G., Costa, A.L.H. (2014). A matrix approach for optimization of pipe networks in cooling water systems. *Chem. Eng. Comm.* 201(8), 1054-1076. |
| **P2** | Costa, A.L.H., Tonassi, E.L.R., Souza, J.N.M. (2016). Hydraulic design optimization of multi-scenario of cooling water distribution system. *Chem. Eng. Trans.* 52. |

## 1. Network model (P1, Eqs. 1-10) — `cwnet.topology`

* Digraph with `S` edges and `N` nodes: `Network` (`model/network.py`). Edges are pipe
  sections (PI), the pump (PU) and heat exchangers (HE).
* Incidence matrix `K` (N×S), `K[t,k] = +1` if edge `k` enters node `t`, `-1` if it leaves:
  `NetworkTopology.incidence` (`topology/incidence.py`).
* Node classification `u_PS`, `u_PD`, `u_CN` (Eqs. 1-3): `u_supply`, `u_demand`, `u_connection`.
* Selection matrices `Ψ_PI`, `Ψ_PU`, `Ψ_HE` (Eqs. 7-9): `select_pipes`, `select_pump`,
  `select_exchangers`.
* Mass balance `K k + u_PS n_PS − u_PD n_PD = 0` with specifications `E k = e` (Eqs. 4-6):
  `topology/massbalance.py::solve_mass_balance`. For parallel coolers `E = Ψ_HE` and
  `N_E = S + 2 − N = S_HE` (checked, `TopologyError` otherwise).
* Hydraulic circuit matrix `Λ` (Eq. 10): `Λ = ([I 0 0] sign(B⁻¹) [0; I])ᵀ` with
  `B = [[K, u_PS, −u_PD], [E, 0, 0]]` — `NetworkTopology.circuits`. The structural
  assumptions (i)-(iv) of the paper are validated (`_validate_circuits`).

## 2. Hydraulics (P1, Eqs. 11-14) — `cwnet.hydraulics`

* Pump head: polynomial in `q = k/ρ` — `PumpCurve.head`.
* Pipe head loss (Darcy-Weisbach, Churchill 1977 friction factor for all regimes):
  `pipe_head_loss` = `(f L/D + f_T (L/D)_fittings) v²/(2g)`. The tables
  `HydraulicTables.pipe_loss[m, p, n]` hold `F_PI,p,n · L_p` for every scenario `m`, pipe `p`
  and catalogue diameter `n`.
* Heat exchanger head loss `F_HE = F^design (k/k^design)^α` (Mukherjee), α = 1.8:
  `HeatExchanger.head_loss`.

## 3. Costs (P1, Eqs. 15-22) — `cwnet.costs`

* Pipe unit cost (Narang et al. 2009) `c_PI,n = C1/0.3048 (D_nom/12)^m`: `pipe_unit_cost`.
  Revamp cost matrix `C_PI` with zeros for the installed diameter of existing pipes (Eq. 34):
  `pipe_cost_matrix`.
* Pump capital cost (Couper et al. 2005, Eqs. 19-21): `pump_capital_cost`, with
  `Z = q[gpm]·√H[ft]`, factors `F_I, F_MS, F_M, F_T`.
* Operating cost `C_OP = k g F_PU/η · N_OP p_c /1000` (Eq. 22): `pump_operating_cost`.
  Multi-scenario: `Σ_m φ_m C_OP,m` (P2, Eq. 5).
* Annualizing factor `r` (Eq. 18): `Economics.annualizing_factor`.
* Total cost: `CostBreakdown.total_published = C_OP + r·I_PU + C_PI` (as in the published
  tables and the original code) and `total_annualized = C_OP + r·(I_PU + C_PI)` (Eqs. 15-16);
  selected by `Economics.objective_basis`.

## 4. Optimization problem — `cwnet.design.lp`

For each pump alternative `s` the LP in the length fractions `X` (S_PI × N_D) and valve head
losses `y` (S_HE × N_SC) is (P1 Eqs. 27-36, P2 Eqs. 1-5):

```
min   Σ_p Σ_n C_PI[p,n] X[p,n]
s.t.  Σ_n X[p,n] = 1                                            ∀ p            (Eq. 25/30)
      Σ_p Λ[l,p] Σ_n F[m,p,n] X[p,n] + y[m,h(l)]
          = F_PU[m,s] + Δz − F_HE[m,h(l)] − Fac[l]              ∀ l, m         (Eq. 23/28/36, P2 Eq. 2)
      X[p,n] = 0  if v[m,p,n] > v_max for some m               (Eq. 24/29, P2 Eq. 3)
      0 ≤ X ≤ 1,  y ≥ 0                                         (Eqs. 26/31/35)
```

`build_lp` assembles the matrices; `lp_design` solves with `scipy.optimize.linprog`
(HiGHS dual simplex, returning a vertex). The grassroots problem of P1 has no `y`
(`options.allow_valves = False` reproduces it exactly; with valves the optimum is the same
unless the velocity limit is active). The pump choice `s` (integer, P2 binary `y_s`) is made
by enumerating the alternatives and comparing the totals (`run_design_study`), which is
equivalent to the MILP of P2.

Fixed pipes (`status: fixed`) restrict `X` to the installed diameter; existing pipes can
optionally not be downsized (`options.allow_downsizing_existing`).

## 5. Traditional design (P1, Eqs. 37-38) — `cwnet.design.traditional`

* Towler & Sinnott: `D = (k/ρ)^0.5`. Edgar & Himmelblau: `D[in] = c (p_c/p_c,ref)^0.164 k^0.459`
  with `c = 1.269` pre-evaluated for the paper's data (the original code used this constant and
  scaled it with `p_c^0.164` in the sensitivity analysis).
* The largest economic diameter over the scenarios (P2) and the velocity limit are rounded up
  to the next catalogue size; for existing pipes the installed diameter is kept when larger.
* The required head is the largest `Σ losses + F_HE − Δz` over circuits and scenarios; the
  smallest pump alternative with enough head at that scenario's flow is selected.

## 6. Verification — `cwnet.simulation`

* `network_sim.simulate_design`: unknowns `k` (edge flows), `p` (node pressures, bar) and
  `w` (external nodal flows); residuals = nodal mass balances, mechanical energy balances
  of pipes (with the subsections of the design, fittings and fixed losses), exchangers (with
  the valve losses of the scenario) and pump, and the boundary specifications (pressure at the
  tower nodes, zero external flow elsewhere). Newton's method with a numerical Jacobian
  from a linearized (laminar) initial guess; SciPy `root` as fallback. A balanced design
  returns exactly the specified exchanger flows.
* `thermal.thermal_check`: effectiveness-NTU evaluation of the coolers (port of the
  `heatcheck` routine: film coefficients corrected with the flow ratios, overall coefficient,
  1-N shell-and-tube effectiveness), giving outlet temperatures for the simulated flows.

## 7. Post-processing (manuscript Sec. 5.1) — `cwnet.design.postprocess`

Optional QP that maximizes `Σ X²` subject to the LP constraints and `cost ≤ C*`, to reduce
the number of split pipes among the alternative optima (local SLSQP solution; off by default).
