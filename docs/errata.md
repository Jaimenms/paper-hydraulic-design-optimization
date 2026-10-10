# Errata

Formal errata of the two papers reimplemented in this repository, prepared from the
`cwnet` re-implementation. Every number is reproduced by the tests (`tests/test_paper1_*.py`,
`tests/test_paper2_multiscenario.py`) and by notebooks 01–03. A classified discussion in
Portuguese, including the discrepancies that are not errors of the papers, is in
[`pt/discrepancias_e_errata.md`](pt/discrepancias_e_errata.md); the reproduction status is in
[`reproduction.md`](reproduction.md).

## Paper 1 — Erratum to: Souza, J. N. M., Ventin, F. F., Tavares, V. B. G., Costa, A. L. H. (2014). A matrix approach for optimization of pipe networks in cooling water systems. *Chemical Engineering Communications* 201(8), 1054–1076. doi:10.1080/00986445.2013.800484


1. **Tables XI (p. 1070) and XVI (p. 1073), column "Pipe cost (USD/y)".** The values listed are the
   pipe capital costs in USD (Σ c_PI,n X_p,n L_p) and were not multiplied by the annualizing factor r
   as stated in Eq. (16); the column "Total cost (USD/y)" therefore adds the operating cost and the
   annualized pump cost to a non-annualized pipe cost. With Eq. (16) applied (r = 0.1339) the totals
   of Table XI become:

   | Methodology / case | Total cost (USD/y) | Operational cost (USD/y) | Pump cost (USD/y) | Pipe cost (USD/y) |
   |---|---|---|---|---|
   | Traditional | 28,592 | 23,184 | 3,209 | 2,199 |
   | Proposed / Curve 1 | **25,448** | 20,183 | 3,045 | 2,220 |
   | Proposed / Curve 2 | 29,349 | 24,220 | 3,209 | 1,920 |
   | Proposed / Curve 3 | 32,059 | 26,911 | 3,312 | 1,836 |
   | Proposed / Curve 4 | 34,789 | 29,602 | 3,409 | 1,778 |

   The conclusions for the grassroots problem are unchanged (pump 1 is the cheapest alternative);
   its cost is 11.0 % lower than the traditional design (not 7.0 %). For the revamp problem the
   totals of Table XVI become:

   | Methodology / case | Total cost (USD/y) | Operational cost (USD/y) | Pump cost (USD/y) | Pipe cost (USD/y) |
   |---|---|---|---|---|
   | Traditional (as published) | 28,911 | 24,193 | 3,409 | 1,309 |
   | Traditional (corrected, item 2) | 27,547 | 22,945 | 3,312 | 1,290 |
   | Proposed / Curve 1 (existing pump kept) | **21,676** | 18,265 | 0 | 3,411 |
   | Proposed / Curve 2 | 26,398 | 21,918 | 3,209 | 1,271 |
   | Proposed / Curve 3 | 28,360 | 24,353 | 3,312 | 695 |
   | Proposed / Curve 4 | 30,592 | 26,789 | 3,409 | 394 |

   The cheapest revamp alternative is to keep the existing pump (curve 1) rather than to install
   pump 3, with a cost 25.0 % lower than the traditional design (21.3 % with the corrected
   traditional design of item 2).

2. **Page 1071, "Traditional Methodology" (revamp), Table XIV (column "Traditional approach"),
   Table XV and Table XVI (row "Traditional").** The sentence "The set of pipe diameters found in the
   traditional approach requires a pump with a minimum head equivalent to 14.4 m at a design flow
   rate of 109.2 kg/s. These conditions impose the selection of pump number 4 in Table III" is
   inconsistent with Table III: pump 3 delivers 15.57 m at 109.2 kg/s and is the smallest sufficient
   alternative. The traditional results reported for the revamp were inadvertently computed with the
   pre-revamp flow rate of E-101 (11.8 kg/s, total 113.5 kg/s) instead of the value of Table XIII
   (7.5 kg/s). With the correct flow rate, pipe sections 9 and 14 are sized at 3½ in (not 4 in),
   pump 3 is selected, the simulated flow rates of Table XV are 11.3, 27.4, 35.7, 15.2, 8.1 and
   16.4 kg/s (total 114.3 kg/s) for E-101, E-102, E-103, E-104, E-105A/B and E-106, and the
   traditional row of Table XVI reads 35,888 (total), 22,945 (operational), 3,312 (pump) and 9,632
   (pipe) USD/y in the convention of the published table. The cost of the best proposed design is
   8.4 % lower than the corrected traditional design (not 12.1 %).

3. **Table XV (p. 1073), row "Total", column "Designed".** The value 117.2 should read 109.2 kg/s
   (7.5 + 28.7 + 35.6 + 15.6 + 6.2 + 15.6).

4. **Eq. (38), p. 1065.** The conversion factor c was not given. For the fluid properties and cost
   parameters of Table V and Eq. (17), the economical diameter used in the study is
   D [in] = 1.269 (p_c / 0.10)^0.164 k^0.459, with k in kg/s and p_c in USD/kWh.

## Paper 2 — Erratum to: Costa, A. L. H., Tonassi, E. L. R., Souza, J. N. M. (2016). Hydraulic design optimization of multi-scenario of cooling water distribution system. *Chemical Engineering Transactions* 52.


1. **Table 7 (p. 5), row "Pump capital costs ($)".** The value 3,051 is the annualized pump cost
   r · C_PU in $/year; the installed cost of the pump is 22,790 $ in both approaches.

2. **Table 10 (p. 6) and the sentence "a total cost reduction of about 9 %" (p. 6 and
   Conclusions).** The totals 11,712 and 12,818 $/year were obtained by annualizing the already
   annualized pump cost a second time. According to Eq. (5) the total annualized costs are
   14,357 $/year (optimization approach) and 15,462 $/year (traditional approach), a reduction of
   7.1 %:

   | Item | Optimization approach | Traditional approach |
   |---|---|---|
   | Pipe capital cost ($) | 17,516 | 20,941 |
   | Pump capital cost ($) | 22,790 | 22,790 |
   | Annualized capital cost, r · (pipe + pump) ($/year) | 5,398 | 5,857 |
   | Operational cost ($/year) | 8,959 | 9,605 |
   | Total annualized cost ($/year) | **14,357** | 15,462 |

   The row label of Table 10 should read "Total annualized costs ($/year)". In the Conclusions, the
   capital cost reduction of 14.3 % combines a capital cost with an annualized cost; the reduction
   of the pipe capital cost is 16.4 % and that of the total capital cost (pipes and pump) is 7.8 %.

3. **Section 2.5 (p. 3).** The parenthesis "(usually cooling water flow is allocated in the
   shell-side in heat exchangers in order to ease the cleaning)" should read "tube side",
   consistently with the exponent α = 1.8 for turbulent flow inside the tubes and with Souza et al.
   (2014).

4. **Section 2.7 (p. 3).** The equation of Towler and Sinnott is numbered (9), the same number as
   the pump curve equation of Section 2.5; it should be Eq. (10).

5. **Section 3 (p. 5).** "There are four available pump options" should read "five", or pump 0
   should be removed from Table 4: with a shut-off head of 6.30 m this alternative cannot supply the
   network (the design problem is infeasible for it).

6. **References.** "Ventin F. Y." should read "Ventin F. F.".
