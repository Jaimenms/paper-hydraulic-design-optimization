function saida = lerArquivoDados(arquivo)
  // Programa que permite ler o arquivo de dados
    
    campos('CASO')                  = ['projeto';'usuario';'data';'documento';'nome_rede';'desc_rede';'executa_towler';'executa_himmelblau'];
    campos('REDE_FLUIDO')           = ['tag';'dens';'visc';'cp';'temp';'v_PI_max'];
    campos('REDE_VERTICE')          = ['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
    campos('REDE_ARESTA_TROC')      = ['ind';'tag';'k';'F';'mh';'Cph';'Thi';'Tho_sp';'mc_sp';'Tco_sp';'A';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it';'Fac'];
    campos('REDE_ARESTA_BOMBA')     = ['ind';'tag';'curve';'tipo'];
    campos('REDE_ARESTA_LINHA')     = ['ind';'tag';'L';'e';'DIA';'LDac';'Fac';'DIAsplit';'xsplit';'tipo'];
    campos('REDE')                  = ['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
    campos('OPT_CURVA')             = ['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated';'eta'];
    campos('OPT_CUSTO_OPERACIONAL') = ['pc';'in';'ny';'Nop'];
    campos('OPT_OPCOES_LINHA')       = ['tag';'DOUT';'DIN';'DN'];
    campos('OPT_CUSTO_LINHA')         = ['alfa';'beta';'metodo'];
    campos('OPT_CENARIO')           = ['i';'ind';'tag';'k';'fop']; 
  
    v_nomeObjeto = fieldnames(campos);
    saida='';
    for i=1:size(v_nomeObjeto,1)
        nomeObjeto=v_nomeObjeto(i);
        camposObjeto=campos(nomeObjeto);
        saida(nomeObjeto)  = lerArquivosDados_fcn(arquivo,nomeObjeto,camposObjeto);
    end
  
endfunction

function saida = lerArquivosDados_fcn(arquivo,nomeObjeto,camposObjeto)
  // Função que faz a leitura dos arquivos de dados montando uma variavel
  // struct chamada de saida e que contem todas as informações descritas no
  // txt.
  
  saidas = [];
  
  txt=mgetl(arquivo,%inf);
  
  ntxt = size(txt,1);
  
  // Rastreando as linhas que t�m informa�oes sobre cada elemento  
  linhas = [];
  for i=1:ntxt,
    txti = txt(i);
    ix = strindex(txti,nomeObjeto);
    if ~isempty(ix), linhas = [linhas;i]; end
  end
  
  // Gerando os campos
  for i=1:size(camposObjeto,1)
    execstr('saida.'+camposObjeto(i)+'=[];')
  end
  
  for i = 1:length(linhas)
    txti = txt(linhas(i));
    ix1 = strindex(txti,'<');
    ix2 = strindex(txti,':');
    ix2(1)=[];
    ix3 = strindex(txti,'>');
    for j=1:length(ix1)
      campo = part(txti,(ix1(j)+1):(ix2(j)-1));
      valor = part(txti,(ix2(j)+1):(ix3(j)-1));
      if or(campo==camposObjeto)
        execstr('saida.'+campo+'=[saida.'+campo+';'+valor+'];')
      end
    end    
  end

endfunction