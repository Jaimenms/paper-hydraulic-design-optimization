mprintf('___________________________________________________\n')
mprintf('Otimização de Redes de Utilidade Fria              \n')
mprintf('Versão: 2.0                                        \n')
mprintf('___________________________________________________\n')

clear,stacksize('max'),lines(0)
pasta = pwd();
genlib("jaime",pasta)

arquivoIN    = 'caso4.txt';
arquivoOUT   = part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'simulacao.dat';

mprintf('- Lendo arquivos de dados\n')
dados = lerArquivoDados(pasta+'\Dados\'+arquivoIN);

mprintf('- Executando otimização da rede\n')
[saidas] = otimizaRede_v01(arquivoIN,dados);