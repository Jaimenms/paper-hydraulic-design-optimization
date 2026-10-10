mprintf('___________________________________________________\n')
mprintf('Programa para Otimização de Redes de Utilidade Fria\n')
mprintf('Versão: 1.0\n')
mprintf('___________________________________________________\n')

// Inicial
clear
stacksize('max')
lines(0)

// Arquivos de dados
arquivoDados    = 'rede04.txt';
arquivoDadosOpt = 'pi01.txt';
arquivoDadosHE  = 'he03.txt';
arquivoDadosPU  = 'pu03.txt';

// Arquivos de saidas
arquivoSaidas   = 'rede13.dat';

// Pasta local
pasta = pwd();

// Início da Rotina

mprintf('\n')
mprintf('Instalando programas...\n')
genlib("otimizador",pasta)
mprintf('... instalação conclu�da.')

mprintf('\n')
mprintf('Lendo arquivos de dados...\n')
dados  = lerDados(pasta+'\Dados\'+arquivoDados,[]);
dados  = lerDadosOpt(pasta+'\Dados\'+arquivoDadosOpt,dados);
dados  = lerDadosHE(pasta+'\Dados\'+arquivoDadosHE,dados);
dados  = lerDadosPU(pasta+'\Dados\'+arquivoDadosPU,dados);
mprintf('...leitura concluída.\n')

mprintf('\n')
mprintf('Executando otimização da rede...\n')
[saidas] = otimizaRede13(dados);
mprintf('...otimização concluída.\n')

mprintf('\n')
mprintf('Armazenando resultados...\n')
save(arquivoSaidas,dados,saidas)
mprintf('...salvamento concluído.\n')

// Fim da Rotina