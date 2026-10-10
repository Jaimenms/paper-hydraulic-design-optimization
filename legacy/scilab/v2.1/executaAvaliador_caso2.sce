clear

pasta = pwd();
arquivo   = 'caso2';

mprintf('\n')
mprintf('Instalando programas...\n')
genlib("avaliador",pasta)
mprintf('... instalação conclu�da.')

geraRelatorio(arquivo)
//geraRelatorioSaidas('Trad. Himmelblau Methodology',dados,saidas.CLASSIC,saidas.INITIAL,nome+'_TRAD')
//geraRelatorioSaidas('Trad. Towler Methodology',dados,saidas.CLASSIC2,saidas.INITIAL,nome+'_TRAD2')
//geraRelatorioSaidas('Proposed Methodology - LP',dados,saidas.SPLIT_LP,saidas.INITIAL,nome+'_PROP_LP')
//geraRelatorioSaidas('Proposed Methodology - QP',dados,saidas.SPLIT_QP,saidas.INITIAL,nome+'_PROP_QP')

mprintf('...relatório concluido.\n')