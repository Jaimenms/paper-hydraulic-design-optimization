function geraRelatorio(arquivo)
    
  dir_arquivos = dir(arquivo+'*.dat');
  arquivos=dir_arquivos.name;
  
  n = size(arquivos);
  for i=1:n(1)
      
      load(arquivos(i));
      
       // Casos
       D.nome(i)=arquivos(i);
       D.ind(i)=i;
       D.pump(i)=opti.indice;
       D.cenario(i)=simi.cenario;
       D.Cop_PU(i)=round(1000*opti.Cop_PU*1e-3)/1000;
       D.C_PU(i)=round(1000*opti.C_PU*1e-3)/1000;
       D.C_PI(i)=round(1000*opti.C_PI*1e-3)/1000;
       D.tipo(i)=opti.tipo;
       
  end
  fob_cen=[];
  for i=1:n(1)
      fob_cen(i)=D.C_PU(i)+D.C_PI(i);
      for j=1:n(1)
          if (D.pump(i)==D.pump(j) & D.tipo(i)==D.tipo(j)) then
              fob_cen(i)=fob_cen(i)+D.Cop_PU(j);
          end
      end
  end
  
  D.fob=fob_cen;
  txt = [];
  txt=[txt;parteInicial('Optimization Results <font color=red>'+dadosi.CASO.projeto+'</font>')];
  nomeCampo=['ind'  ;'pump';'tipo'       ;'cenario';'fob'     ;'Cop_PU'       ;'C_PU'     ;'C_PI'];
  descCampo=['Index';'Pump';'Description';'Case'   ;'FOB'     ;'Pump Op. Cost';'Pump Cost';'Pipe Cost'];
  unidCampo=['-'    ;'-'   ;'-'          ;'-'      ;'(kUSD/y)';'(kUSD/y)'     ;'(kUSD/y)' ;'(kUSD/y)'];  
  txt=[txt;tabelaValores("Optimization Results",D,nomeCampo,descCampo,unidCampo,1)];
  
  geraDiagrama(dadosi,arquivo)
  txt=[txt;figura0(arquivo)];
  
   // Fluido
   G=dadosi.REDE_FLUIDO;
  nomeCampo=['tag';'dens';'visc';'cp';'temp';'v_PI_max'];
  descCampo=['Fluid Name';'Density';'Viscosity';'Thermal Capacity';'Inlet Temperature';'Vel. Maxima'];
  unidCampo=['-';'kg/m3';'cP';'J/(kgoC)';'oC';'m/s'];
  txt=[txt;tabelaValoresVert("Fluid",G,nomeCampo,descCampo,unidCampo)];
  
   // Vertices
   E=[];
   E=dadosi.REDE_VERTICE;
  nomeCampo=['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
  descCampo=['Node Index';'Node Tag';'Type';'Specification Value';'Node Elevation'];
  unidCampo=['-';'-';'-';'bar or kg/s';'m'];
  txt=[txt;tabelaValoresVert("Nodal Especifications",E,nomeCampo,descCampo,unidCampo)];
   
   // Rede
   F=dadosi.REDE;
   nomeCampo=['ind_aresta';'ind_noh_montante';'ind_noh_jusante'];
   descCampo=['Edge Index';'UpStream node';'DownStream node'];
   unidCampo=['-';'-';'-'];
   txt=[txt;tabelaValoresVert('Network',F,nomeCampo,descCampo,unidCampo)];

   // Curvas
   H=dadosi.OPT_CURVA;
   nomeCampo=['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated';'eta'];
   descCampo=['Index';'Curve Tag';'Coefficient 3';'Coefficient 2';'Coefficient 1';'Coefficient 1';'Rated Flow Rate';'Efficiency'];
   unidCampo=['-';'tag';'coef3';'coef2';'coef1';'coef0';'m³/s';'-'];
   txt=[txt;tabelaValoresVert('Pump Options',H,nomeCampo,descCampo,unidCampo)];
    
   // Custo
   I=dadosi.OPT_CUSTO_OPERACIONAL;
   I.alfa=dadosi.OPT_CUSTO_LINHA.alfa;
   I.beta=dadosi.OPT_CUSTO_LINHA.beta;
   
   nomeCampo=['alfa';'beta';'pc';'in';'ny';'Nop'];
   descCampo=['Pipe Cost Coeficient 1';'Pipe Cost Coeficient 2';'Electrical energy Cost';'Annualization Tax';'Number of years';'Annual operation time'];
   unidCampo=['-';'-';'USD/kW';'-';'years';'h/year'];
   txt=[txt;tabelaValoresVert('Optimization Data',I,nomeCampo,descCampo,unidCampo)];

   // Opcoes Linhas
   J=dadosi.OPT_OPCOES_LINHA;
   nomeCampo=['';'DOUT';'DIN';'DN'];
   descCampo=['Diameter';'Outter Diameter';'Inner Diameter';'Nominal Diameter'];
   unidCampo=['""';'mm';'mm';'inches'];
   txt=[txt;tabelaValoresVert('Pipe Diameter Options',J,nomeCampo,descCampo,unidCampo)];

   // Opcoes Cenarios
   H=dadosi.OPT_CENARIO;       
   nomeCampo=['i';'ind';'tag';'k';'fop'];
   descCampo=['Index';'Specified Edge';'Edge Tag';'Specified Mass Flow Rate';'Time fraction during scenario'];
   unidCampo=['-';'ind';'tag';'k';'fop'];
   txt=[txt;tabelaValoresVert('Scenarios',H,nomeCampo,descCampo,unidCampo)];
  
   // Arestas Trocadores
   B = dadosi.REDE_ARESTA_TROC;
   B.k_HE=round(1000*simi.k_HE)/1000;
   B.F_HE=round(1000*simi.F_HE)/1000;
   B.p_HE_1=round(1000*simi.p_HE_1)/1000;
   B.p_HE_2=round(1000*simi.p_HE_2)/1000;
   B.Tco=round(1000*heati.Tco)/1000;
   B.Tho=round(1000*heati.Tho)/1000;
   B.DeltaTho=round(1000*heati.DeltaTho)/1000;
   B.Ratiomc=round(1000*heati.Ratiomc)/1000;
   B.U=round(1000*heati.U)/1000;
   B.Q=round(10*heati.Q.*1e-3)/10;
   
  nomeCampo=['ind';'tag';'k';'F';'Cph';'mh';'mc_sp';'Thi';'Tho_sp';'Tco_sp';'hi_sp';'he_sp';'Rfi';'Rfe';'kt';'Dti';'Dte';'ic';'it'];
  descCampo=['Index';'Tag';'Rated Mass Rate (cold)';'Rated Head Loss (cold)';'Heat Capacity (cold)';'Designed Mass Rate (hot)';'Designed Mass Rate (cold)';'Designed Inlet Temperature (hot)';'Designed Outlet Temperature (hot)';'Designed Outlet Temperature (cold)';'Film Coefficient (Tube)';'Film Coefficient (Shell)';'Fouling Factor (Tube)';'Fouling Factor (Shell)';'Conductivity';'Internal tube diameter';'External tube diameter';'Configuration';'Tube Fluid'];
  unidCampo=['-';'-';'kg/s';'m';'kg/s';'kg/s';'J/kg.K';'oC';'oC';'oC';'W/m2K';'W/m2K';'m2K/W';'m2K/W';'W/m.K';'m';'m';'-';'-'];
  txt=[txt;tabelaValoresVert("Heat Exchangers",B,nomeCampo,descCampo,unidCampo)];
  
  
  // Aresta Linhas
   A = dadosi.REDE_ARESTA_LINHA;
  nomeCampo=['ind';'tag';'L';'e';'LDac';'Fac';'tipo'];
  descCampo=['Index';'Tag';'Length';'Roughness';'Pipe Accidents (L/D)';'Pipe Accidents (fixed head Loss)';'Type'];
  unidCampo=['-';'-';'m';'micrometer';'-';'m';'-'];
  txt=[txt;tabelaValores("Pipes",A,nomeCampo,descCampo,unidCampo,0)];

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
       descCampo=['Indice';'Tag';'Head Loss'];
       unidCampo=['-';'-';'m'];
       txt=[txt;tabelaValoresVert("Calculated Heat Exchanger Valve",R1,nomeCampo,descCampo,unidCampo)];
      
       R2=[];
       R2.ind=dadosi.REDE_ARESTA_LINHA.ind;

       R2.custo_PI=round(100*opti.custo_PI)/100;
       R2.tag=dadosi.REDE_ARESTA_LINHA.tag;
       R2.tipo=dadosi.REDE_ARESTA_LINHA.tipo;
       R2.xmin=round(1000*opti.xmin)./1000;
       R2.xmax=round(1000*opti.xmax)./1000;
       R2.DNmin=opti.DNmin;
       R2.DNmax=opti.DNmax;
       R2.k_PI=round(1000*simi.k_PI)./1000;
       R2.v1=round(1000*simi.v1)./1000;
       R2.v2=round(1000*simi.v2)./1000;
       R2.dPdL100=round(simi.dPdL100);
       R2.F_PI=round(1000*simi.F_PI)./1000;
       R2.p_PI_1=round(1000*simi.p_PI_1)./1000;
       R2.p_PI_2=round(1000*simi.p_PI_2)./1000;
       nomeCampo=['ind';'custo_PI';'tag';'tipo';'xmin';'xmax';'DNmin';'DNmax';'k_PI';'v1';'v2';'dPdL100_2';'F_PI';'p_PI_1';'p_PI_2'];
       descCampo=['Index';'Pipe Cost';'Edge Tag';'Type';'Length Fraction 1';'Length Fraction 2';'Diameter 1';'Diameter 2';'Mass rate';'Velocity (Lower Dia.)';'Velocity (Higher Dia.)';'Head Loss/Length';'Total Head Loss';'UpStream Pressure';'DownStream Pressure'];
       unidCampo=['-';'USD/y';'-';'-';'-';'-';'in';'in';'kg/s';'m/s';'m/s';'kPa/100m';'m';'bar';'bar'];
       txt=[txt;tabelaValores("Calculated Line Diameter",R2,nomeCampo,descCampo,unidCampo)];


       // Arestas Trocadores
       B = dadosi.REDE_ARESTA_TROC;
       B.k_HE=round(1000*simi.k_HE)/1000;
       B.F_HE=round(1000*simi.F_HE)/1000;
       B.p_HE_1=round(1000*simi.p_HE_1)/1000;
       B.p_HE_2=round(1000*simi.p_HE_2)/1000;
       B.Tco=round(1000*heati.Tco)/1000;
       B.Tho=round(1000*heati.Tho)/1000;
       B.DeltaTho=round(1000*heati.DeltaTho)/1000;
       B.Ratiomc=round(1000*heati.Ratiomc)/1000;
       B.U=round(1000*heati.U)/1000;
       B.Q=round(10*heati.Q.*1e-3)/10;
       
      nomeCampo=['ind';'tag';'Fac';'k_HE';'F_HE';'p_HE_1';'p_HE_2';'Tco';'Tho';'DeltaTho';'Ratiomc';'U';'Q';'A'];
      descCampo=['Index';'Tag';'Valve head loss';'Simulated Mass Rate';'Simulated Head Loss';'Simulated UpStream Pressure';'Simulated DownStream Pressure';'Simulated Oulet Temperature (cold)';'Simulated Outlet Temperature (cold)';'Temp. Difference (Simulated - Designed)';'Mass Difference (cold)';'Heat Transfer Coef.';'Power';'Area'];
      unidCampo=['-';'-';'m';'kg/s';'m';'bar-g';'bar-g';'oC';'oC';'oC';'kg/s';'W/m2K';'kW';'m2'];
      txt=[txt;tabelaValoresVert("Heat Exchangers",B,nomeCampo,descCampo,unidCampo)];
       
       // Arestas Bombas
       C = dadosi.REDE_ARESTA_BOMBA;
       C.k_PU=round(1000*simi.k_PU)/1000;
       C.F_PU=-round(1000*simi.F_PU)/1000;
       C.p_PU_1=round(1000*simi.p_PU_1)/1000;
       C.p_PU_2=round(1000*simi.p_PU_2)/1000;
      nomeCampo=['ind';'tag';'curve';'tipo';'k_PU';'F_PU';'p_PU_1';'p_PU_2'];
      descCampo=['Index';'Tag';'Curve';'Type';'Mass Flow Rate';'Pump head';'UpStream Pressure';'DownStream Pressure'];
      unidCampo=['-';'-';'-';'-';'kg/s';'m';'bar';'bar'];
      txt=[txt;tabelaValores("Pump",C,nomeCampo,descCampo,unidCampo,0)];
   
       E=[];
       E.ind=1:length(simi.w);
       E.w=round(1000*simi.w)/1000;
       E.p=round(1000*simi.p)/1000;
      nomeCampo=['ind';'w';'p'];
      descCampo=['Edge Index';'Nodal Mass Flow Rate';'Nodal Pressure'];
      unidCampo=['-';'kg/s';'bar'];
      txt=[txt;tabelaValoresVert("Nodal Values",E,nomeCampo,descCampo,unidCampo)];
      
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
  txt(size(txt,1)+1) = 'ranksep=.75; rankdir=LR; splines=""true"";';
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


function txt = tabelaValores(nomeTabela,variavel,nomeCampo,descCampo,unidCampo,com_link,isMat)
  
  if ~exists('isMat'), isMat = zeros(size(descCampo,1),1); end
  if ~exists('com_link'), com_link = 0; end
  
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
  
  n_nomeCampo = size(nomeCampo);
  n_nomeCampo=n_nomeCampo(1);
  for i=1:n_nomeCampo
    if or(nomeCampoTotal==nomeCampo(i))
      tipoCampoi = descCampo(i);
      if ~isempty(tipoCampoi)
          txt(size(txt,1)+1)=' <TD ALIGN=middle>';
          txt(size(txt,1)+1)=' <b>'+string(tipoCampoi(1))+'</b>';
          txt(size(txt,1)+1)=' </TD>';
      end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='<TR>';
  for i=1:n_nomeCampo
    if or(nomeCampoTotal==nomeCampo(i))
      unidCampoi = unidCampo(i);
      if ~isempty(unidCampoi)
          txt(size(txt,1)+1)=' <TD bgcolor=""#BFBFBF"" ALIGN=middle>';
          txt(size(txt,1)+1)=' <b>'+string(unidCampoi(1))+'</b>';
          txt(size(txt,1)+1)=' </TD>';
      end
    end
  end
  txt(size(txt,1)+1)='</TR>';
  
  
  for j = 1:nvar
    txt(size(txt,1)+1)='<TR>';
    for i=1:n_nomeCampo
      if or(nomeCampoTotal==nomeCampo(i))
          execstr('valor = variavel.'+nomeCampo(i)+'('+string(j)+')'+';')
          if (com_link) then
              txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>';
              txt(size(txt,1)+1)='<A href=""#ancora'+string(j)+'"">';
              txt(size(txt,1)+1)=string(valor);
              txt(size(txt,1)+1)='</A></TD>';
          else
              txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>';
              txt(size(txt,1)+1)=string(valor);
              txt(size(txt,1)+1)=' </TD>';
          end 
      end
    end
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
  n_nomeCampo = size(nomeCampo);
  n_nomeCampo=n_nomeCampo(1);
  for i=1:n_nomeCampo
    if or(nomeCampoTotal==nomeCampo(i))
      tipoCampoi = descCampo(i);
      txt(size(txt,1)+1)=' <TR><TD ALIGN=right nowrap><b>'+string(tipoCampoi)+'</b></TD>';
      txt(size(txt,1)+1)='</TD></TR>';
    end
  end
  txt(size(txt,1)+1)='</table></TD>';
  txt(size(txt,1)+1)='<TD><table>';
  for i = 1:n_nomeCampo
    if or(nomeCampoTotal==nomeCampo(i))
      tipoCampoi = descCampo(i);
      execstr('valor = variavel.'+nomeCampo(i)+'(:);')
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
  for i = 1:n_nomeCampo
    if or(nomeCampoTotal==nomeCampo(i))
      valor = unidCampo(i);
      if isempty(valor)
        txt(size(txt,1)+1)='<TR><TD ALIGN=left bgcolor=""#BFBFBF"" ALIGN=middle nowrap>-</TD></TR>';
      else
        txt(size(txt,1)+1)='<TR><TD ALIGN=left bgcolor=""#BFBFBF"" ALIGN=middle nowrap>'+...
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