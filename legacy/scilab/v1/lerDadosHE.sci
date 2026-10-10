function dados = lerDadosHE(arquivo,dados)
  // Programa que permite ler o arquivo de dados dos trocadores
  
  camposTASK = ['tag';'mh';'Cph';'Thi';'Tho_sp';'mc_sp';'Tco_sp'];
  camposDESIGN = ['tag';'mc_sp';'A';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it'];
    
  dados.HE_TASK   = lerObjetos(arquivo,'TASK',camposTASK);
  dados.HE_DESIGN = lerObjetos(arquivo,'DESIGN',camposDESIGN);
  
endfunction