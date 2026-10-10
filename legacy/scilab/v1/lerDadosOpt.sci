function dados = lerDadosOpt(arquivo,dados)
  // Programa que permite ler o arquivo de dados do otimizador
    
  camposPIPE = ['tag';'DIN';'DOUT';'DN'];
  camposPIPECOST = ['alfa';'beta'];
  
  dados.PIPE      = lerObjetos(arquivo,'PIPE',camposPIPE);
  dados.PIPECOST  = lerObjetos(arquivo,'PIPECOST',camposPIPECOST);
  
endfunction