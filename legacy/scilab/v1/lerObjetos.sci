function saida = lerObjetos(arquivo,nomeObjeto,camposObjeto)
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