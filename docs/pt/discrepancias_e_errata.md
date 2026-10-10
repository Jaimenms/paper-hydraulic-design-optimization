# Discrepâncias e errata — otimização de redes de água de resfriamento

2026-10-10 · Jaime N. M. de Souza

## Resumo

A reimplementação em Python (`cwnet`) reproduz os resultados dos dois artigos e revelou doze pontos que justificam errata (quatro no Artigo 1, oito no Artigo 2), além de nove diferenças que não são erros dos artigos. Nenhum erro altera a validade do método; três alteram números das conclusões: a anualização do custo de tubos (E1.1), o projeto tradicional do revamp (E1.2) e o total anualizado do Artigo 2 (E2.2).

Artigos analisados:

- **Artigo 1**: Souza, J.N.M., Ventin, F.F., Tavares, V.B.G., Costa, A.L.H. (2014). A matrix approach for optimization of pipe networks in cooling water systems. *Chem. Eng. Comm.* 201(8), 1054-1076. [doi:10.1080/00986445.2013.800484](https://doi.org/10.1080/00986445.2013.800484)
- **Artigo 2**: Costa, A.L.H., Tonassi, E.L.R., Souza, J.N.M. (2016). Hydraulic design optimization of multi-scenario of cooling water distribution system. *Chem. Eng. Trans.* 52.

Critério de classificação:

- **Errata (erro no artigo)**: o texto, uma equação ou uma tabela publicada é internamente inconsistente ou contradiz os próprios dados do artigo; a correção é determinável a partir do artigo e do código original.
- **Discrepância (não é erro)**: diferença explicada por arredondamento, por escolha de modelo ou por ótimos alternativos do LP; o artigo está correto como publicado.

Método de verificação: cada tabela foi recalculada com os dados das próprias tabelas de entrada dos artigos, com o código Scilab original (`legacy/scilab`) como referência de implementação, e as páginas citadas foram conferidas no PDF publicado. Os números em USD/ano usam o fator de anualização r = 0.1339 (i = 12 %, 20 anos).

Síntese das erratas (detalhes nas seções seguintes):

| # | Artigo | Onde | Tipo | Impacto nas conclusões |
| --- | --- | --- | --- | --- |
| E1.1 | 1 | Tabelas XI e XVI; Eq. (16) | Numérico | Grassroots: redução 11.0 % (não 7.0 %); revamp: manter a bomba existente é a melhor opção (não a bomba 3) |
| E1.2 | 1 | p. 1071; Tabelas XIV, XV, XVI (tradicional) | Numérico | Bomba 3 (não 4); redução 8.4 % (não 12.1 %) |
| E1.3 | 1 | Tabela XV, total | Tipográfico | Nenhum |
| E1.4 | 1 | Eq. (38) | Omissão | Reprodutibilidade |
| E2.1 | 2 | Tabela 7 | Rótulo / unidade | Nenhum |
| E2.2 | 2 | Tabela 10; "about 9 %" | Numérico | Redução 7.1 % (não ~9 %) |
| E2.3 | 2 | Tabela 10, rótulo | Rótulo | Nenhum |
| E2.4 | 2 | Conclusões, 14.3 % | Numérico | Mistura de unidades |
| E2.5 | 2 | Seção 2.5 | Texto | Nenhum |
| E2.6 | 2 | Eq. (9) duplicada | Numeração | Nenhum |
| E2.7 | 2 | Seção 3 / Tabela 4 | Texto | Nenhum |
| E2.8 | 2 | Referências | Citação | Nenhum |

## Artigo 1 (2014) — erratas

O Artigo 1 tem dois erros numéricos com impacto nas conclusões (E1.1 e E1.2), um erro tipográfico (E1.3) e uma omissão (E1.4). O método, as Tabelas I a VIII e os resultados do LP estão corretos.

| # | Onde | Como está | Como deveria estar | Impacto |
| --- | --- | --- | --- | --- |
| E1.1 | Tabela XI (p. 1070) e Tabela XVI (p. 1073), colunas "Pipe cost (USD/y)" e "Total cost (USD/y)"; Eq. (16), p. 1060 | O custo de tubos tabelado é o investimento Σ c_PI X L em USD (16 583 para a curva 1) e não r · Σ c_PI X L (2 220 USD/ano) como define a Eq. (16); o total soma C_OP + r · C_PU + investimento | Aplicar a Eq. (16) às duas tabelas (tabelas corrigidas abaixo) ou mudar o cabeçalho para "Pipe capital cost (USD)" e declarar que o total não segue a Eq. (15) | Grassroots: a bomba 1 continua ótima e a redução face ao tradicional passa de 7.0 % para 11.0 %. Revamp: a melhor alternativa passa a ser **manter a bomba existente (curva 1), 21 676 USD/ano**, e não a bomba 3; a redução passa de 12.1 % para 25.0 % (21.3 % face ao tradicional corrigido de E1.2) |
| E1.2 | p. 1071, "requires a pump with a minimum head equivalent to 14.4 m at a design flow rate of 109.2 kg/s. These conditions impose the selection of pump number 4"; Tabela XIV (p. 1072), coluna "Traditional approach"; Tabela XV (p. 1073); Tabela XVI, linha "Traditional" | Com os coeficientes da Tabela III a bomba 3 fornece 15.57 m a 109.2 kg/s (bomba 4: 17.13 m) e seria a escolhida. A coluna tradicional publicada (tubos 9 e 14 em 4 in, bomba 4, 117.1 kg/s simulados, 37 378 USD/ano) corresponde ao ramal do E-101 dimensionado com a vazão anterior ao revamp, 11.8 kg/s (total 113.5 kg/s), em contradição com a Tabela XIII (7.5 kg/s) | Bomba 3; tubos 9 e 14 em 3½ in (os restantes diâmetros não mudam); Tabela XV e linha tradicional da Tabela XVI corrigidas abaixo | A redução de custo do projeto proposto (p. 1073, "12.1 % lower") passa a 8.4 % na base publicada |
| E1.3 | Tabela XV (p. 1073), linha "Total", coluna "Designed" | 117.2 | 109.2 (= 7.5 + 28.7 + 35.6 + 15.6 + 6.2 + 15.6) | Tipográfico |
| E1.4 | Eq. (38), p. 1065 | "where c is a conversion factor", sem valor nem unidades | Para os dados do artigo (Tabela V, Eq. 17): D [in] = 1.269 · (p_c / 0.10)^0.164 · k^0.459, k em kg/s; a constante absorve C1, μ e ρ | Omissão: a Tabela IX (coluna tradicional) não é reproduzível só com o artigo |

Tabela XI corrigida pela Eq. (16) (valores publicados de C_OP e C_PU; r = 0.1339; USD/ano):

| Methodology / case | Total cost | Operational cost | Pump cost | Pipe cost (r · investimento) |
| --- | --- | --- | --- | --- |
| Traditional | 28 592 | 23 184 | 3 209 | 2 199 |
| Proposed / Curve 1 | **25 448** | 20 183 | 3 045 | 2 220 |
| Proposed / Curve 2 | 29 349 | 24 220 | 3 209 | 1 920 |
| Proposed / Curve 3 | 32 059 | 26 911 | 3 312 | 1 836 |
| Proposed / Curve 4 | 34 789 | 29 602 | 3 409 | 1 778 |

Tabela XVI corrigida pela Eq. (16) (USD/ano; a linha "Traditional (corrigido)" incorpora E1.2):

| Methodology / case | Total cost | Operational cost | Pump cost | Pipe cost (r · investimento) |
| --- | --- | --- | --- | --- |
| Traditional (publicado, E-101 a 11.8 kg/s) | 28 911 | 24 193 | 3 409 | 1 309 |
| Traditional (corrigido, bomba 3) | 27 547 | 22 945 | 3 312 | 1 290 |
| Proposed / Curve 1 (bomba existente) | **21 676** | 18 265 | 0 | 3 411 |
| Proposed / Curve 2 | 26 398 | 21 918 | 3 209 | 1 271 |
| Proposed / Curve 3 | 28 360 | 24 353 | 3 312 | 695 |
| Proposed / Curve 4 | 30 592 | 26 789 | 3 409 | 394 |

Tabela XV corrigida (projeto tradicional com E-101 a 7.5 kg/s e bomba 3; kg/s):

| Heat exchanger | Designed | Simulated |
| --- | --- | --- |
| E-101 | 7.5 | 11.3 |
| E-102 | 28.7 | 27.4 |
| E-103 | 35.6 | 35.7 |
| E-104 | 15.6 | 15.2 |
| E-105A/B | 6.2 | 8.1 |
| E-106 | 15.6 | 16.4 |
| Total | 109.2 | 114.3 |

Linha "Traditional" da Tabela XVI corrigida na base publicada (E1.2, sem aplicar E1.1): total 35 888; operacional 22 945; bomba 3 312; tubos 9 632 USD/ano.

## Artigo 1 (2014) — discrepâncias que não são erros do artigo

Cinco diferenças entre os valores publicados e os recalculados têm explicação conhecida e não exigem correção do artigo.

| # | Onde | Publicado | Recalculado | Causa |
| --- | --- | --- | --- | --- |
| D1.1 | Tabela IX, p. 1069 (diâmetros ótimos); Tabela XIV, p. 1072 | 1: 10"; 8: 10/12 (0.810/0.190); 14: 3½/4; 16: 6/8 | 1: 12"; 8: 10/12 (0.860/0.140); 9: 3½/4; 11: 6/8 | O LP tem ótimos alternativos: tubulações em série com a mesma vazão trocam trechos de diâmetro sem alterar o custo (16 583 vs 16 581 USD) |
| D1.2 | Tabela X, p. 1069 (temperaturas de saída) | E-101 63.2 °C; E-105 38.6 °C | 63.9 °C; 39.5 °C (vazões iguais: 13.8 / 32.2 / 39.8 / 12.7 / 4.2 kg/s) | O artigo usou o simulador termo-hidráulico de Tavares et al. (2010); a rotina ε-NTU do código Scilab dá 64.1 °C para o E-101 já na condição de projeto (alvo 65.0 °C) |
| D1.3 | p. 1069, texto "minimum head equivalent to 17.8 m" | 17.8 m | 17.66 m | Diferença de 0.14 m dentro da precisão das correlações; a bomba 2 é selecionada nos dois casos |
| D1.4 | Tabelas XI e XVI, todas as linhas | p. ex. 16 583 | 16 581 | O código original converte ft/m com 3.281 em vez de 1/0.3048 = 3.2808 (0.012 %) |
| D1.5 | Tabelas III, IV e XII | a2 = −415.6; FMS = 1.3; L13 = 5.63 m | −415.5675; 1.2971; 5.625 m | Os resultados publicados usam os valores não arredondados dos ficheiros de dados (0.225 × 25 m = 5.625 m); com FMS = 1.3 o custo da bomba 1 seria 3 052 em vez de 3 045 USD/ano |

Equivalência dos ótimos alternativos da Tabela IX (comprimento de cada diâmetro por grupo de tubulações em série, publicado vs recalculado):

| Grupo em série | Diâmetro | Publicado (m) | Recalculado (m) |
| --- | --- | --- | --- |
| 1, 3, 8 (94.8 kg/s) | 10" / 12" | 172.0 / 238.0 | 172.0 / 238.0 |
| 4, 7 (54.3 kg/s) | 8" / 10" | 139.9 / 60.1 | 139.9 / 60.1 |
| 9, 14 (11.8 kg/s) | 3½" / 4" | 30.07 / 19.93 | 30.08 / 19.92 |
| 11, 16 (35.6 kg/s) | 6" / 8" | 8.82 / 41.17 | 8.82 / 41.18 |
| 13, 18 (3.1 kg/s) | 1½" / 2" | 5.62 / 44.38 | 5.63 / 44.37 |

A mesma degenerescência explica as diferenças na Tabela XIV (tubulações 10 e 15; 5 e 6; 7 e 25; 13, 18 e 24; 29 e 30), com custo de tubos idêntico (5 192 USD) e a mesma válvula no E-101 (3.763 m).

## Artigo 2 (2016) — erratas

O Artigo 2 tem um erro numérico (o custo da bomba é anualizado duas vezes na Tabela 10) e cinco erros de texto ou rótulo; o projeto ótimo e a escolha da bomba 1 estão corretos.

| # | Onde | Como está | Como deveria estar | Impacto |
| --- | --- | --- | --- | --- |
| E2.1 | Tabela 7 (p. 5), linha "Pump capital costs ($)" | 3 051 | 3 051 é r · C_PU, o custo **anualizado** (USD/ano); o investimento é ≈ 22 790 USD (Couper, FMS = 1.3) | A linha mistura unidades com a linha dos tubos (investimento) |
| E2.2 | Tabela 10 (p. 6) e texto "about 9 %" (p. 6 e Conclusões) | 11 712 / 12 818 USD/ano = C_OP + r · (C_tubos + 3 051): o termo da bomba foi anualizado duas vezes | Pela Eq. (5): 8 959 + 0.134 × 17 516 + 3 051 = **14 357**; 9 605 + 0.134 × 20 941 + 3 051 = **15 462** | Redução do custo total anualizado de **7.1 %**, não "about 9 %" (8.6 %) |
| E2.3 | Tabela 10 (p. 6), rótulo da linha | "Operational costs ($/year)" | "Total annualized costs ($/year)" | Rótulo repetido da Tabela 9 |
| E2.4 | Conclusões (p. 6), "capital ... reductions of 14.3 %" | 14.3 % = 1 − (17 516 + 3 051)/(20 941 + 3 051) | Soma um investimento com um valor anualizado; só tubos: 16.4 %; tubos + investimento na bomba (22 790 em ambos): 7.8 % | Número da conclusão depende do rótulo errado de E2.1 |
| E2.5 | Seção 2.5 (p. 3), após a Eq. (8) | "α ... 1.8 for turbulent flow inside the tubes (usually cooling water flow is allocated in the shell-side ... to ease the cleaning)" | A água de resfriamento escoa no **lado dos tubos** (como no Artigo 1, p. 1066, por incrustação); o parêntese contradiz a própria frase | Texto |
| E2.6 | Seção 2.5 e 2.7 (p. 3) | Duas equações numeradas (9): a curva da bomba e a regra de Towler | A regra de Towler deveria ser a Eq. (10) | Numeração |
| E2.7 | Seção 3 (p. 5), "There are four available pump options" e Tabela 4 | Quatro opções no texto; cinco bombas (0 a 4) na tabela | A bomba 0 (6.30 m) não alimenta a rede (perda dos trocadores + 5 m de elevação > head): retirar da Tabela 4 ou dizer que é inviável | Texto |
| E2.8 | Referências (p. 6) | "Souza J. N. M., Ventin F. Y., ..." | "Ventin F. F." (Fabyana F. Ventin) | Citação |

Tabela 10 corrigida (valores das Tabelas 7 e 9 do artigo, r = 0.134; entre parênteses os valores recalculados com `cwnet`):

| Item | Optimization approach | Traditional approach |
| --- | --- | --- |
| Pipe capital cost (USD) | 17 516 (17 512) | 20 941 (20 941) |
| Pump capital cost (USD) | 22 790 (22 790) | 22 790 (22 790) |
| Annualized capital, r · (pipe + pump) (USD/year) | 5 398 (5 396) | 5 857 (5 856) |
| Operational cost (USD/year) | 8 959 (8 968) | 9 605 (9 576) |
| Total annualized cost (USD/year) | 14 357 (14 364) | 15 462 (15 431) |
| Reduction | 7.1 % (6.9 %) | — |

## Artigo 2 (2016) — discrepâncias que não são erros do artigo

As Tabelas 5 a 9 são reproduzidas dentro de 0.3 %; as diferenças restantes vêm de ótimos alternativos do LP e de arredondamentos.

| # | Onde | Publicado | Recalculado | Causa |
| --- | --- | --- | --- | --- |
| D2.1 | Tabela 5 (p. 5), tubulações 1 e 8 | 1: 10" (48.4 %) / 12" (51.6 %); 8: 12" | 1: 12"; 8: 10" (2.6 %) / 12" (97.4 %) | Mesmo coletor em série (1, 3, 8): 4.84 m vs 5.2 m de 10", custo de tubos 17 516 vs 17 512 USD; ótimos alternativos |
| D2.2 | Tabela 6 (p. 5), válvulas | E-102, cenário 4: 0.91 m | 0.87 m (os outros 19 valores coincidem a ±0.02 m) | A perda na válvula compensa o trecho de 10" deslocado em D2.1 |
| D2.3 | Tabelas 8 e 9 (p. 6) | 13.2 / 30.1 / 39.6 / 16.4 / 4.6 kg/s; 8 959 e 9 605 USD/ano | 13.2 / 30.1 / 39.6 / 16.4 / 4.6 kg/s; 8 968 e 9 576 USD/ano | Coeficientes das bombas arredondados na Tabela 4 e fator de atrito (0.1 a 0.3 %) |
| D2.4 | Seção 2.6 (p. 3), MILP resolvido no GAMS/CPLEX | MILP com binárias y_s | Um LP por bomba e comparação dos totais | Formulações equivalentes: a bomba 1 é ótima em ambas |

A Tabela 7 (custo de tubos 17 516 vs 20 941 USD) e o custo anualizado da bomba (3 051 USD/ano com FMS = 1.3) são reproduzidos exatamente.

## Código Scilab original — o que explica os valores publicados

Três comportamentos do código Scilab v2.2 (`legacy/scilab/v2.2`) geraram os números das erratas E1.1 e E1.2; os demais são bugs sem efeito nos casos publicados.

| # | Ficheiro / rotina | Comportamento | Consequência |
| --- | --- | --- | --- |
| S1 | `otimizaRede_v01.sci`, `calcula_PI` e `calculaFob` | O custo de tubos entra na função objetivo e no relatório como investimento (sem o fator r); só a bomba é anualizada (`C_PU = r*I_PU`) | Origem de E1.1 (Tabelas XI e XVI) |
| S2 | `otimizaRede_v01.sci`, `executa_classico = 0`; `geraRelatorio.sci` carrega todos os `caso*.dat` | O projeto tradicional não é recalculado; o relatório reaproveita o ficheiro `caso2.02_HIMMELBLAU.dat` gerado com uma versão anterior dos dados (E-101 a 11.8 kg/s) | Origem de E1.2 e E1.3 (coluna tradicional das Tabelas XIV a XVI); o mesmo acontece no `caso3` |
| S3 | `calcula_PI`: `3.281^(beta+1)*L*alfa*(DN*0.0254)^beta` | Fator ft/m arredondado (3.281 vs 3.2808) | D1.4: 1 a 3 USD/ano nas tabelas |
| S4 | `geraParametros_opt` | A perda localizada `Fac` é somada aos coeficientes dos tubos e também subtraída no lado direito (contada duas vezes) | Sem efeito: `Fac = 0` em todos os casos |
| S5 | `determinaHimmelblau` e `determinaTowler` | O diâmetro de velocidade máxima é multiplicado por 0.0254 uma segunda vez, desativando a restrição de velocidade no projeto tradicional | Sem efeito: velocidades < 2 m/s nos casos publicados |
| S6 | `Dados/caso5.txt` | `fop = 0.25` num único cenário | O custo operacional do relatório é ¼ do real |

A reimplementação `cwnet` corrige S3 a S6, recalcula sempre o projeto tradicional (S2) e torna S1 uma opção (`economics.objective_basis`: `published` reproduz as tabelas, `annualized` aplica a Eq. 16).

## Textos de erratum em inglês (prontos para envio)

Os textos formais em inglês, com um item por erro (localização, texto publicado, correção, impacto), estão em [`../errata.md`](../errata.md).

## Como reproduzir cada verificação

Todas as verificações correm neste repositório (pacote `cwnet`): `make setup`, depois `make test` (39 testes), `make eval` (relatório de desvios em `results/eval/`) e `make notebooks`.

| Item | Notebook | Teste | Função / ficheiro |
| --- | --- | --- | --- |
| E1.1 (anualização do custo de tubos) | `01_paper1_grassroots`, última célula; `02_paper1_revamp`, "Nota: ranking com custos totalmente anualizados" | `tests/test_paper1_grassroots.py::test_table_xi_costs` | `tables.cost_comparison_table(study, basis="annualized")`; `CostBreakdown.total_annualized` |
| E1.2 (tradicional do revamp) | `02_paper1_revamp`, "Sobre a coluna tradicional publicada" | `test_paper1_revamp.py::test_traditional_revamp_consistent_with_new_flows` e `::test_traditional_revamp_as_published` | `design/traditional.py::traditional_design` |
| E1.3 (total da Tabela XV) | `02_paper1_revamp`, Tabela XV | `test_topology.py::test_revamp_mass_balance_table_xiii` | `topology/massbalance.py` |
| E1.4 (constante da Eq. 38) | `01_paper1_grassroots`, Tabela IX | `test_paper1_grassroots.py::test_traditional_design_table_ix` | `design/traditional.py::edgar_himmelblau_diameter` |
| E2.1 a E2.4 (Tabelas 7 e 10) | `03_paper2_multiscenario`, "Tabelas 7, 9 e 10" | `test_paper2_multiscenario.py::test_table_7_capital_costs`, `::test_table_9_operating_costs` | `costs/pumps.py::pump_capital_cost` |
| E2.7 (bomba 0 inviável) | `03_paper2_multiscenario`, "Otimização" | `test_paper2_multiscenario.py::test_pump_selection_and_infeasible_alternative` | `design/lp.py::lp_design` |
| D1.1, D2.1 (degenerescência) | `01`, célula "grupo em série"; `03`, Tabela 5 | `test_optimal_design_subsections_table_ix`; `test_table_5_and_6_design_and_valves` | comprimento por diâmetro por grupo |
| D1.2 (Tabela X) | `01_paper1_grassroots`, Tabela X | `test_traditional_simulation_table_x` | `simulation/thermal.py::thermal_check` |
| S1 a S6 (código Scilab) | `05_legacy_scilab_cases` | `test_io_and_cli.py` | `io/scilab_legacy.py`; `legacy/scilab/v2.2` |

Os ficheiros de caso com todos os parâmetros estão em `cases/paper1_grassroots.yaml`, `cases/paper1_revamp.yaml` e `cases/paper2_multiscenario.yaml`; o estado da reprodução está em `docs/reproduction.md` e as erratas formais em `docs/errata.md`.
