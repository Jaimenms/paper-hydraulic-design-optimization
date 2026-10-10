clear

pasta = pwd();
arquivoSaidas   = 'rede13.dat';

mprintf('\n')
mprintf('Instalando programas...\n')
genlib("otimizador",pasta)
mprintf('... instalação conclu�da.')

mprintf('\n')
mprintf('Abrindo resultados...\n')
load(arquivoSaidas,'dados','saidas')
mprintf('...salvamento concluído.\n')

mprintf('\n')
mprintf('Gerando relatórios...\n')

nome='Relat13'
geraRelatorioOtimizador(dados,saidas,nome)
geraRelatorioSaidas('Trad. Himmelblau Methodology',dados,saidas.CLASSIC,saidas.INITIAL,nome+'_TRAD')
geraRelatorioSaidas('Trad. Towler Methodology',dados,saidas.CLASSIC2,saidas.INITIAL,nome+'_TRAD2')
geraRelatorioSaidas('Proposed Methodology - LP',dados,saidas.SPLIT_LP,saidas.INITIAL,nome+'_PROP_LP')
geraRelatorioSaidas('Proposed Methodology - QP',dados,saidas.SPLIT_QP,saidas.INITIAL,nome+'_PROP_QP')

mprintf('...relatório concluido.\n')