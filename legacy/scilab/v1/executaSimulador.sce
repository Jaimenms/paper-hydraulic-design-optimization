clc,clear

mprintf('___________________________________________________\n')
mprintf('Programa para Simulacao de Redes de Utilidade Fria\n')
mprintf('Vers�o: 1.0\n')
mprintf('___________________________________________________\n')

pasta = pwd();
arquivoDados    = 'rede01.txt';

mprintf('\n')
mprintf('Instalando programas...\n')
genlib("simulador",pasta)
mprintf('... instala��o conclu�da.')

mprintf('\n')
mprintf('Lendo arquivos de dados...\n')
dados  = lerDados(pasta+'\Dados\'+arquivoDados,[]);
mprintf('...leitura conclu�da.\n')

mprintf('\n')
mprintf('Executando simula��o da rede...\n')
[saidas,x,saidas0,x0]=simulaRede(dadosede);
mprintf('...simula��o conclu�da.\n')

mprintf('\n')
mprintf('Gerando relat�rio...\n')
geraRelatorio(dados,'Preliminar')
mprintf('...relat�rio concluido.\n')