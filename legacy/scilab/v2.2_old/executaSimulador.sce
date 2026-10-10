mprintf('___________________________________________________\n')
mprintf('Simulacao de Redes de Utilidade Fria               \n')
mprintf('Versão: 2.0                                        \n')
mprintf('___________________________________________________\n')

clear,stacksize('max'),lines(0)
pasta = pwd();
genlib("jaime",pasta)

arquivoIN    = 'caso1.txt';
arquivoOUT   = 'SIM.'+part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'.dat';

mprintf('\nLendo arquivos de dados...')
dados = lerArquivoDados(pasta+'\Dados\'+arquivoIN);
mprintf('concluído.\n')

mprintf('\nExecutando simulação da rede...\n')
[saidas,x] = simulaRede(dados);
mprintf('concluído.\n')

mprintf('\nArmazenando resultados...')
save(arquivoOUT,dados,saidas)
mprintf('concluído.\n')
