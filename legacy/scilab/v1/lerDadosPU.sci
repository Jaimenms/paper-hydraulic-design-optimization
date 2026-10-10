function dados = lerDadosPU(arquivo,dados)
  // Programa que permite ler o arquivo de dados da rede
    
  campos = ['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated'];  
  dados.PUMPCURVE = lerObjetos(arquivo,'PUMPCURVE',campos);
  
  campos = ['eta';'Nop';'pc';'in';'ny'];
  dados.PUMPCOST = lerObjetos(arquivo,'PUMPCOST',campos);
  
endfunction