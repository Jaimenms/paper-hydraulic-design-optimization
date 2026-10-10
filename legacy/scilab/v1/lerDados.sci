function dados = lerDados(arquivo,dados)
  // Programa que permite ler o arquivo de dados da rede
    
  camposCASO = ['projeto';'usuario';'data';'documento';'nome_rede';'desc_rede'];
  camposFLUIDO = ['tag';'dens';'visc';'cp';'temp'];
  camposEQUIP = ['ind';'tag';'k';'F'];
  camposBOMBA = ['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated'];
  camposLINHA = ['ind';'tag';'L';'e';'di';'LDac';'Fac'];
  camposREDE = ['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
  camposVERTICE = ['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
  
  dados.CASO    = lerObjetos(arquivo,'CASO',camposCASO);
  dados.FLUIDO  = lerObjetos(arquivo,'FLUIDO',camposFLUIDO);
  dados.EQUIP   = lerObjetos(arquivo,'EQUIP',camposEQUIP);
  dados.BOMBA   = lerObjetos(arquivo,'BOMBA',camposBOMBA);
  dados.LINHA   = lerObjetos(arquivo,'LINHA',camposLINHA);
  dados.REDE    = lerObjetos(arquivo,'REDE',camposREDE);
  dados.VERTICE = lerObjetos(arquivo,'VERTICE',camposVERTICE);      
  
endfunction