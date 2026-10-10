function geraRelatorio(arquivo)
    
  dir_arquivos = dir(arquivo+'*.dat');
  arquivos=dir_arquivos.name;
  
  n = size(arquivos);
  for i=1:n(1)
      
      load(arquivos(i));
      
       // Casos
       D.nome(i)=arquivos(i);
       D.ind(i)=i;
       D.indice(i)=opti.indice;
       D.cenario(i)=simi.cenario;
       linking(i)=arquivos(i);
       D.fob(i)=round(1000*opti.fob*1e-3)/1000;
       D.Cop_PU(i)=round(1000*opti.Cop_PU*1e-3)/1000;
       D.C_PU(i)=round(1000*opti.C_PU*1e-3)/1000;
       D.C_PI(i)=round(1000*opti.C_PI*1e-3)/1000;
       D.fobPEN(i)=round(1000*opti.fobPEN)/1000;
       
  end

  txt = [];
  txt=[txt;parteInicial('Optimization Results <font color=red>'+dadosi.CASO.projeto+'</font>')];
  
  nomeCampo=['nome';'arquivo';'ind';'indice';'cenario';'fob';'Cop_PU';'C_PU';'C_PI';'fobPEN'];
  descCampo=['nome';'Index';'File';'Pump';'Case';'FOB';'Pump Op. Cost';'Pump Cost';'Pipe Cost';'Penalty'];
  unidCampo=['-';'-';'-';'-';'-';'(kUSD/y)';'(kUSD/y)';'(kUSD/y)';'(kUSD/y)';'-'];  
  txt=[txt;tabelaValores_com_link("Optimization Results",D,nomeCampo,descCampo,unidCampo,linking)];

  geraDiagrama(dadosi,arquivo)
  txt=[txt;figura0(arquivo)];

  for i=1:n(1)
      
      load(arquivos(i));
      
      txt=[txt;'<A NAME=""ancora'+string(i)+'""></A>'];
      txt=[txt;parteInicial(arquivos(i))];
      txt=[txt;'<A href=""#ancora0""><center>Voltar</center></A>'];

       R1=[];
       R1.ind=dadosi.REDE_ARESTA_TROC.ind;
       R1.tag=dadosi.REDE_ARESTA_TROC.tag;
       R1.u=round(1000*dadosi.REDE_ARESTA_TROC.Fac)./1000;
       nomeCampo=['ind';'tag';'u'];
       descCampo=['Indice';'Tag';'Perda de Carga'];
       unidCampo=['-';'-';'m'];
       txt=[txt;tabelaValoresVert("Calculated Heat Exchanger Valve",R1,nomeCampo,descCampo,unidCampo)];
      
       R2=[];
       R2.ind=dadosi.REDE_ARESTA_LINHA.ind;
       R2.custo_PI=opti.custo_PI;
       R2.tag=dadosi.REDE_ARESTA_LINHA.tag;
       R2.tipo=dadosi.REDE_ARESTA_LINHA.tipo;
       R2.xmin=round(1000*opti.xmin)./1000;
       R2.xmax=round(1000*opti.xmax)./1000;
       R2.DNmin=opti.DNmin;
       R2.DNmax=opti.DNmax;
       nomeCampo=['ind';'custo_PI';'tag';'tipo';'xmin';'xmax';'DNmin';'DNmax'];
       descCampo=['Indice';'custo_PI';'Tag';'Tipo';'Fracao_1';'Fracao_2';'Diametro_1';'Diametro_2'];
       unidCampo=['-';'-';'-';'-';'-';'-';'in.';'in.'];
       txt=[txt;tabelaValoresVert("Calculated Line Diameter",R2,nomeCampo,descCampo,unidCampo)];
        

       // Fluido
       G=dadosi.REDE_FLUIDO;
       
      nomeCampo=['tag';'dens';'visc';'cp';'temp';'v_PI_max'];
      descCampo=['Fluid Name';'Density';'Viscosity';'Thermal Capacity';'Inlet Temperature';'Vel. Maxima'];
      unidCampo=['-';'kg/m3';'cP';'J/(kgoC)';'oC';'m/s'];
      txt=[txt;tabelaValoresVert("Fluid",G,nomeCampo,descCampo,unidCampo)];
      
      
      
      // Aresta Linhas
       A = dadosi.REDE_ARESTA_LINHA;
       A.xmin=round(1000*opti.xmin)./1000;
       A.xmax=round(1000*opti.xmax)./1000;
       A.Dmin=opti.Dmin;
       A.Dmax=opti.Dmax;
       A.DNmin=opti.DNmin;
       A.DNmax=opti.DNmax;
       A.k_PI=round(1000*simi.k_PI)./1000;
       A.v1=round(1000*simi.v1)./1000;
       A.v2=round(1000*simi.v2)./1000;
       A.dPdL100=round(simi.dPdL100);
       A.F_PI1=round(1000*simi.F_PI1)./1000;
       A.F_PI2=round(1000*simi.F_PI2);
       A.F_PI=round(1000*simi.F_PI)./1000;
       A.p_PI_1=round(1000*simi.p_PI_1)./1000;
       A.p_PI_2=round(1000*simi.p_PI_2)./1000;

      nomeCampo=['ind';'tag';'L';'e';'DIA';'LDac';'Fac';'DIAsplit';'xsplit';'tipo';'di';'DINsplit';'xmin';'xmax';'Dmin';'Dmax';'DNmin';'DNmax';'k_PI';'v1';'v2';'dPdL100';'F_PI1';'F_PI2';'F_PI';'p_PI_1';'p_PI_2'];
      descCampo=['ind';'tag';'L';'e';'DIA';'LDac';'Fac';'DIAsplit';'xsplit';'Tipo';'di';'DINsplit';'xmin';'xmax';'Dmin';'Dmax';'DNmin';'DNmax';'k_PI';'v1';'v2';'dPdL100';'F_PI1';'F_PI2';'F_PI';'p_PI_1';'p_PI_2'];
      unidCampo=['ind';'tag';'L';'e';'DIA';'LDac';'Fac';'DIAsplit';'xsplit';'Tipo';'di';'DINsplit';'xmin';'xmax';'Dmin';'Dmax';'DNmin';'DNmax';'k_PI';'v1';'v2';'dPdL100';'F_PI1';'F_PI2';'F_PI';'p_PI_1';'p_PI_2'];
      txt=[txt;tabelaValoresVert("Pipes",A,nomeCampo,descCampo,unidCampo)];

       // Arestas Trocadores
       B = dadosi.REDE_ARESTA_TROC;
       B.k_HE=simi.k_HE;
       B.F_HE=simi.F_HE;
       B.p_HE_1=simi.p_HE_1;
       B.p_HE_2=simi.p_HE_2;
       B.Tco=heati.Tco;
       B.Tho=heati.Tho;
       B.DeltaTho=heati.DeltaTho;
       B.Ratiomc=heati.Ratiomc;
       B.U=heati.U;
       B.Q=heati.Q;
       
      nomeCampo=['ind';'tag';'k';'F';'mh';'Cph';'Thi';'Tho_sp';'mc_sp';'Tco_sp';'A';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it';'Fac';'k_HE';'F_HE';'p_HE_1';'p_HE_2';'Tco';'Tho';'DeltaTho';'Ratiomc';'U';'Q'];
      descCampo=['ind';'tag';'k';'F';'mh';'Cph';'Thi';'Tho_sp';'mc_sp';'Tco_sp';'A';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it';'Fac';'k_HE';'F_HE';'p_HE_1';'p_HE_2';'Tco';'Tho';'DeltaTho';'Ratiomc';'U';'Q'];
      unidCampo=['ind';'tag';'k';'F';'mh';'Cph';'Thi';'Tho_sp';'mc_sp';'Tco_sp';'A';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it';'Fac';'k_HE';'F_HE';'p_HE_1';'p_HE_2';'Tco';'Tho';'DeltaTho';'Ratiomc';'U';'Q'];
      txt=[txt;tabelaValoresVert("Heat Exchangers",B,nomeCampo,descCampo,unidCampo)];
       
       // Arestas Bombas
       C = dadosi.REDE_ARESTA_BOMBA;
       C.k_PU=round(1000*simi.k_PU)/1000;
       C.F_PU=round(1000*simi.F_PU)/1000;
       C.p_PU_1=round(1000*simi.p_PU_1)/1000;
       C.p_PU_2=round(1000*simi.p_PU_2)/1000;
      nomeCampo=['ind';'tag';'curve';'tipo';'coef3';'coef2';'coef1';'coef0';'qrated';'k_PU';'F_PU';'p_PU_1';'p_PU_2'];
      descCampo=['ind';'tag';'curve';'Tipo';'coef3';'coef2';'coef1';'coef0';'qrated';'k_PU';'F_PU';'p_PU_1';'p_PU_2'];
      unidCampo=['ind';'tag';'curve';'Tipo';'coef3';'coef2';'coef1';'coef0';'qrated';'k_PU';'F_PU';'p_PU_1';'p_PU_2'];
      txt=[txt;tabelaValores("Pump",C,nomeCampo,descCampo,unidCampo)];

       // Vertices
       E=[];
       E=dadosi.REDE_VERTICE;
      nomeCampo=['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
      descCampo=['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
      unidCampo=['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
      txt=[txt;tabelaValoresVert("Nodal Especifications",E,nomeCampo,descCampo,unidCampo)];

       E=[];
       E.w=round(1000*simi.w)/1000;
       E.p=round(1000*simi.p)/1000;
      nomeCampo=['w';'p'];
      descCampo=['w';'p'];
      unidCampo=['w';'p'];
      txt=[txt;tabelaValoresVert("Nodal Values",E,nomeCampo,descCampo,unidCampo)];

       
       // Rede
       F=dadosi.REDE;
       nomeCampo=['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
       descCampo=['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
       unidCampo=['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
       txt=[txt;tabelaValoresVert('Network',F,nomeCampo,descCampo,unidCampo)];

       // Curvas
       H=dadosi.OPT_CURVA;
       nomeCampo=['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated';'eta'];
       descCampo=['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated';'eta'];
       unidCampo=['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated';'eta'];
       txt=[txt;tabelaValoresVert('Pump Options',H,nomeCampo,descCampo,unidCampo)];
        
       // Custo
       I=dadosi.OPT_CUSTO_OPERACIONAL;
       I.alfa=dadosi.OPT_CUSTO_LINHA.alfa;
       I.beta=dadosi.OPT_CUSTO_LINHA.beta;
       
       nomeCampo=['alfa';'beta';'pc';'in';'ny';'Nop'];
       descCampo=['alfa';'beta';'pc';'in';'ny';'Nop'];
       unidCampo=['-';'-';'-';'-';'-';'-'];
       txt=[txt;tabelaValoresVert('Optimization Data',I,nomeCampo,descCampo,unidCampo)];

       // Opcoes Linhas
       J=dadosi.OPT_OPCOES_LINHA;
       nomeCampo=['tag';'DOUT';'DIN';'DN'];
       descCampo=['tag';'DOUT';'DIN';'DN'];
       unidCampo=['tag';'DOUT';'DIN';'DN'];
       txt=[txt;tabelaValoresVert('Pipe Options',J,nomeCampo,descCampo,unidCampo)];

       // Opcoes Cenarios
       H=dadosi.OPT_CENARIO;       
       nomeCampo=['i';'ind';'tag';'k';'Nop'];
       descCampo=['i';'ind';'tag';'k';'Nop'];
       unidCampo=['i';'ind';'tag';'k';'Nop'];
       txt=[txt;tabelaValoresVert('Cenarios',H,nomeCampo,descCampo,unidCampo)];


   
  end
          
  deletefile(pwd()+'\Relatorios\'+arquivo+'.htm');
  write(pwd()+'\Relatorios\'+arquivo+'.htm',txt);
  dos('start '+pwd()+'\Relatorios\'+arquivo+'.htm');

endfunction


function txt=parteInicial(nomeRelat)
  
  txt = [];
  txt(size(txt,1)+1)='<HTML>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<BODY bgcolor=#fdf1e3 leftMargin=20 marginheight=0 marginwidth=0>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<TABLE cellSpacing=0 cellPadding=0 width=""80%"" border=0>';
  txt(size(txt,1)+1)='<TR>';
  txt(size(txt,1)+1)='<TD WIDTH=500><FONT size=""5"">Cooling Water Pipe Network Design';
  txt(size(txt,1)+1)='</FONT><br>';
  txt(size(txt,1)+1)='<FONT size=""4"">ver 1.0';
  txt(size(txt,1)+1)='</FONT></TD>';
  txt(size(txt,1)+1)='</TR></TABLE>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<TABLE cellSpacing=0 cellPadding=0 width=""100%"" border=0>';
  txt(size(txt,1)+1)='  <TBODY>';
  txt(size(txt,1)+1)='  <TR>';
  txt(size(txt,1)+1)='    <TD align=left width=""25%""><IMG src=""imagens/lineleft.gif""';
  txt(size(txt,1)+1)='      border=0></TD>';
  txt(size(txt,1)+1)='    <TD align=left><IMG src=""imagens/line.gif"" width=""100%""></TD>';
  txt(size(txt,1)+1)='    </TR></TBODY></TABLE>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<BR>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='<BR>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<tr>';
  txt(size(txt,1)+1)='<td width=""50%"">';
  txt(size(txt,1)+1)='<font size=3><center>';
  txt(size(txt,1)+1)='<FONT size=6><B><A NAME=""ancora0"">'+nomeRelat+'</A></B></FONT></center>';
  txt(size(txt,1)+1)='</td>';
  txt(size(txt,1)+1)='</tr>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='<BR>';
  
endfunction

function txt = parteFinal(nomeRelat)
  txt = [];
  txt(size(txt,1)+1)='  <TABLE><TR>';
  txt(size(txt,1)+1)='<TD WIDTH=90?><DIV ALIGN=RIGHT><A href="+nomeRelat+".htm?comheader=2"" target=""_blank""><img src=""imagens/printer.gif"" border=""0""></A></DIV></TD>';
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='<BR><BR>'
  txt(size(txt,1)+1)='</BODY>';
  txt(size(txt,1)+1)='</HTML>';
  
endfunction

function txt = figura0(nomeRelat)
  
  txt = [];
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='<tr>';
  txt(size(txt,1)+1)='<td width=""50%""  id=""figura0"">';
  txt(size(txt,1)+1)='<font size=3><center>';
  txt(size(txt,1)+1)='<FONT size=4><B>Digrafo da Rede</B></FONT></center></font>';
  txt(size(txt,1)+1)='</td>';
  txt(size(txt,1)+1)='</tr>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<TABLE>';  
  txt(size(txt,1)+1)='<TBODY>';
  txt(size(txt,1)+1)='<TR>';
  txt(size(txt,1)+1)='<TD WIDTH=10% ALIGN=middle>'
  txt(size(txt,1)+1)='<A HREF=""imagens/'+nomeRelat+'_rede.gif"">'
  txt(size(txt,1)+1)='<IMG src=""imagens/'+nomeRelat+'_rede.gif"" width=700></A></TD>';
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='</TBODY>';
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR><BR>';
  
endfunction

function geraDiagrama(dados,nomeRelat)
  
  S_PU = size(dados.REDE_ARESTA_BOMBA.tag,1);
  S_PI = size(dados.REDE_ARESTA_LINHA.tag,1);
  S_HE = size(dados.REDE_ARESTA_TROC.tag,1);
  S = S_PU+S_PI+S_HE;
  N_E = length(dados.REDE_VERTICE.ind_vertice);
  N = length(unique([dados.REDE.ind_noh_montante;dados.REDE.ind_noh_jusante]));
  K = zeros(N,S);
  QSI_PI = zeros(S_PI,S);
  QSI_PU = zeros(S_PU,S);
  QSI_HE = zeros(S_HE,S);
  for i=1:S
    ix = find(dados.REDE.ind_aresta==i);
    i_Noh1=dados.REDE.ind_noh_montante(ix);
    i_Noh2=dados.REDE.ind_noh_jusante(ix);
    K(i_Noh1,ix) = -1;
    K(i_Noh2,ix) =  1;
  end
  for i=1:S_PI
    ix = dados.REDE_ARESTA_LINHA.ind(i);
    QSI_PI(i,ix)=1;
  end
  for i=1:S_PU
    ix = dados.REDE_ARESTA_BOMBA.ind(i);
    QSI_PU(i,ix)=1;
  end
  for i=1:S_HE
    ix = dados.REDE_ARESTA_TROC.ind(i);
    QSI_HE(i,ix)=1;
  end
  
  K_PI = K*QSI_PI';
  K_PU = K*QSI_PU';
  K_HE = K*QSI_HE';
  S_PI = size(QSI_PI,1);
  S_PU = size(QSI_PU,1);
  S_HE = size(QSI_HE,1);
    
  ix1 = [];  ix2 = [];
  
  txt = [];  
  txt(size(txt,1)+1) = 'digraph REDE {';
  txt(size(txt,1)+1) = 'ranksep=.75; rankdir=LR;';
  txt(size(txt,1)+1) = 'node [width=.1,height=.1,shape=circle,style=filled];';
  txt(size(txt,1)+1) = 'edge [color=blue,style=bold];';
  
  for i = 1:length(ix1)
    txt(size(txt,1)+1) = string(ix1(i))+' [width=.5,height=.3,shape=box,style=filled,color=skyblue,label=""Suprimento""];';
  end
  for i = 1:length(ix2)
    txt(size(txt,1)+1) = string(ix2(i))+' [width=.5,height=.3,shape=box,style=filled,color=skyblue,label=""Retorno""];';
  end
  
  for i = 1:S_PI
    no1 = find(K_PI(:,i)==-1);
    no2 = find(K_PI(:,i)==+1);
    if (dados.REDE_ARESTA_LINHA.tipo(i)=='existente_fixo' | dados.REDE_ARESTA_LINHA.tipo(i)=='existente_otimo')
        txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+dados.REDE_ARESTA_LINHA.tag(i)+'"",penwidth=3, style=dashed];';
    else
        txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+dados.REDE_ARESTA_LINHA.tag(i)+'"",penwidth=3, style=bold];';
    end
        
  end
  
  txt(size(txt,1)+1) = '  subgraph cluster1 {';
  txt(size(txt,1)+1) = 'node [width=.1,height=.1,shape=circle,style=filled];';
  txt(size(txt,1)+1) = 'edge [color=blue,style=bold];';
  for i = 1:S_PU
    no1 = find(K_PU(:,i)==-1);
    no2 = find(K_PU(:,i)==+1);
    if (dados.REDE_ARESTA_BOMBA.tipo(i)=='existente')
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+string(dados.REDE_ARESTA_BOMBA.ind(i))+' ('+dados.REDE_ARESTA_BOMBA.tag(i)+')"",len=2, style=dashed, color=green];';
    else
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+string(dados.REDE_ARESTA_BOMBA.ind(i))+' ('+dados.REDE_ARESTA_BOMBA.tag(i)+')"",len=2, style=bold, color=green];';
    end
  end
  txt(size(txt,1)+1) = 'label = ""Pumps"";';
  txt(size(txt,1)+1) = '}';
  
  txt(size(txt,1)+1) = '  subgraph cluster2 {';
  txt(size(txt,1)+1) = 'node [width=.1,height=.1,shape=circle,style=filled];';
  txt(size(txt,1)+1) = 'edge [color=blue,style=bold];';
  for i = 1:S_HE
    no1 = find(K_HE(:,i)==-1);
    no2 = find(K_HE(:,i)==+1);
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+string(dados.REDE_ARESTA_TROC.ind(i))+' ('+dados.REDE_ARESTA_TROC.tag(i)+')"",len=2, style=bold, color=red];';
  end
  txt(size(txt,1)+1) = 'label = ""Heat Exchangers"";';
  txt(size(txt,1)+1) = '}';
  txt(size(txt,1)+1) = '}';
    
  deletefile(pwd()+'/Relatorios/imagens/'+nomeRelat+'_rede.dot');
  deletefile(pwd()+'/Relatorios/imagens/'+nomeRelat+'_rede.gif');
  write(pwd()+'/Relatorios/imagens/'+nomeRelat+'_rede.dot',txt);
  dos('""C:\Program Files\Graphviz 2.28\bin\dot"" -Tgif ""'+pwd()+'\Relatorios\imagens\'+nomeRelat+'_rede.dot"" -o ""'+pwd()+'\Relatorios\imagens\'+nomeRelat+'_rede.gif""')  
  //"C:\Program Files\Graphviz 2.28\bin\dot" -Tgif "Relatorios\imagens\caso1_rede.dot" -o "Relatorios\imagens\caso1_rede.gif"
  
  aux = dir(pwd());
  
endfunction


function txt = tabelaValores_com_link(nomeTabela,variavel,nomeCampo,descCampo,unidCampo,linking,isMat)
  
  if ~exists('isMat'), isMat = zeros(size(descCampo,1),1); end
  
  nomeCampoTotal = fieldnames(variavel);
  nCampi = size(nomeCampoTotal,1);
  execstr('nvar = size(variavel.'+nomeCampoTotal(1)+',1);')    
  txt = [];
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='<tr>';
  txt(size(txt,1)+1)='<td width=""50%"" id=""tabela1"">';
  txt(size(txt,1)+1)='<font size=3><center>';
  txt(size(txt,1)+1)='<FONT size=4><B>'+nomeTabela+'</B></FONT></center></font>';
  txt(size(txt,1)+1)='</td>';
  txt(size(txt,1)+1)='</tr>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='<CENTER><TABLE border=2 bgcolor=#e4e4e4>';
  txt(size(txt,1)+1)='<TR>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      tipoCampoi = descCampo(find(nomeCampoTotal(i)==nomeCampo));
      if ~isempty(tipoCampoi),txt(size(txt,1)+1)=' <TD ALIGN=middle><b>'+string(tipoCampoi(1))+'</b></TD>'; end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='<TR>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      unidCampoi = unidCampo(find(nomeCampoTotal(i)==nomeCampo));
      if ~isempty(unidCampoi),txt(size(txt,1)+1)=' <TD bgcolor=""#BFBFBF"" ALIGN=middle><b>'+...
        string(unidCampoi(1))+'</b></TD>';end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  for j = 1:nvar
    txt(size(txt,1)+1)='<TR>';
    for i = 1:nCampi
      if ~isempty(tipoCampoi)
        if i==1
            if isMat(find(nomeCampoTotal(i)==nomeCampo))==0
              execstr('valor = variavel.'+nomeCampoTotal(i)+'('+string(j)+')'+';')
              txt(size(txt,1)+1)='<TD bgcolor=""#ffffcc"" ALIGN=middle><a href=""#ancora'+string(j)+'"">'+string(valor)+'</A></TD>';
            else
              txt(size(txt,1)+1)='<TD align=center> <table>';
              execstr('valor = variavel.'+nomeCampoTotal(i)+'(j,:);')
              for k=1:length(valor)
                txt(size(txt,1)+1)='<TD bgcolor=""#ffffcc"" ALIGN=middle><a href=""#ancora'+string(j)+'"">'+string(valor(k))+'</A></TD>';
              end
              txt(size(txt,1)+1)='</table></TD>';
            end
        else
            if isMat(find(nomeCampoTotal(i)==nomeCampo))==0
              execstr('valor = variavel.'+nomeCampoTotal(i)+'('+string(j)+')'+';')
              txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle><a href=""#ancora'+string(j)+'"">'+string(valor)+'</A></TD>';
            else
              txt(size(txt,1)+1)='<TD align=center> <table>';
              execstr('valor = variavel.'+nomeCampoTotal(i)+'(j,:);')
              for k=1:length(valor)
                txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle><a href=""#ancora'+string(j)+'"">'+string(valor(k))+'</A></TD>';
              end
              txt(size(txt,1)+1)='</table></TD>';
            end
        end
      end
    end
    txt(size(txt,1)+1)='</a>';
    txt(size(txt,1)+1)='</TR>';
  end
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR>';

endfunction

function txt = tabelaValoresVert(nomeTabela,variavel,nomeCampo,descCampo,unidCampo)
  
  nomeCampoTotal = fieldnames(variavel);
  nCampi = size(nomeCampoTotal,1);
  execstr('nvar = size(variavel.'+nomeCampoTotal(1)+',1);')    
  txt = [];
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='<tr>';
  txt(size(txt,1)+1)='<td width=""50%"" id=""tabela1"">';
  txt(size(txt,1)+1)='<font size=3><center>';
  txt(size(txt,1)+1)='<FONT size=4><B>'+nomeTabela+'</B></FONT></center></font>';
  txt(size(txt,1)+1)='</td>';
  txt(size(txt,1)+1)='</tr>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='<CENTER><TABLE border=2 bgcolor=#e4e4e4>';
  txt(size(txt,1)+1)='<TR>';
  txt(size(txt,1)+1)='<TD><table>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      tipoCampoi = descCampo(find(nomeCampoTotal(i)==nomeCampo));
      txt(size(txt,1)+1)=' <TR><TD ALIGN=right><b>'+string(tipoCampoi(1))+'</b></TD>';
      txt(size(txt,1)+1)='</TD></TR>';
    end
  end
  txt(size(txt,1)+1)='</table></TD>';
  txt(size(txt,1)+1)='<TD><table>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      tipoCampoi = descCampo(find(nomeCampoTotal(i)==nomeCampo));
      execstr('valor = variavel.'+nomeCampoTotal(i)+'(:);')
      if isempty(valor)
        txt(size(txt,1)+1)='<TD bgcolor=""#FFFFcc"" ALIGN=middle>-</TD>';
      else
        for j=1:size(valor,1)
          txt(size(txt,1)+1)='<TD bgcolor=""#FFFFcc"" ALIGN=middle>'+string(valor(j))+'</TD>';
        end
      end
      
      txt(size(txt,1)+1)='</TD></TR>';
    end
  end
  txt(size(txt,1)+1)='</table></TD>';
  txt(size(txt,1)+1)='<TD><table>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      valor = unidCampo(find(nomeCampoTotal(i)==nomeCampo));
      if isempty(valor)
        txt(size(txt,1)+1)='<TR><TD ALIGN=left bgcolor=""#BFBFBF"" ALIGN=middle>-</TD></TR>';
      else
        txt(size(txt,1)+1)='<TR><TD ALIGN=left bgcolor=""#BFBFBF"" ALIGN=middle>'+...
        valor+'</TD></TR>';
      end
      txt(size(txt,1)+1)='</TD></TR>';
    end
  end
  txt(size(txt,1)+1)='</table></TD>';
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR>';

endfunction


function txt = tabelaValores(nomeTabela,variavel,nomeCampo,descCampo,unidCampo,isMat)
    
  if ~exists('isMat'), isMat = zeros(size(descCampo,1),1); end
  
  nomeCampoTotal = fieldnames(variavel);
  nCampi = size(nomeCampoTotal,1);
  execstr('nvar = size(variavel.'+nomeCampoTotal(1)+',1);')    
  txt = [];
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='<tr>';
  txt(size(txt,1)+1)='<td width=""50%"" id=""tabela1"">';
  txt(size(txt,1)+1)='<font size=3><center>';
  txt(size(txt,1)+1)='<FONT size=4><B>'+nomeTabela+'</B></FONT></center></font>';
  txt(size(txt,1)+1)='</td>';
  txt(size(txt,1)+1)='</tr>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='<CENTER><TABLE border=2 bgcolor=#e4e4e4>';
  txt(size(txt,1)+1)='<TR>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      tipoCampoi = descCampo(find(nomeCampoTotal(i)==nomeCampo));
      if ~isempty(tipoCampoi),txt(size(txt,1)+1)=' <TD ALIGN=middle><b>'+string(tipoCampoi(1))+'</b></TD>'; end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='<TR>';
  for i = 1:nCampi
    if or(nomeCampoTotal(i)==nomeCampo)
      unidCampoi = unidCampo(find(nomeCampoTotal(i)==nomeCampo));
      if ~isempty(unidCampoi),txt(size(txt,1)+1)=' <TD bgcolor=""#BFBFBF"" ALIGN=middle><b>'+...
        string(unidCampoi(1))+'</b></TD>';end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='<TR>';
  
  for j = 1:nvar
    for i = 1:nCampi
      if ~isempty(tipoCampoi)
        if isMat(find(nomeCampoTotal(i)==nomeCampo))==0
          execstr('valor = variavel.'+nomeCampoTotal(i)+'('+string(j)+')'+';')
          txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>'+string(valor)+'</TD>';
        else
          txt(size(txt,1)+1)='<TD align=center> <table>';
          execstr('valor = variavel.'+nomeCampoTotal(i)+'(j,:);')
          for k=1:length(valor)
            txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>'+string(valor(k))+'</TD>';
          end
          txt(size(txt,1)+1)='</table></TD>';
        end
      end
    end
    txt(size(txt,1)+1)='</TR>';
  end
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR>';

endfunction
