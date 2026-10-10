function geraRelatorioOtimizador(dados,saidas,nomeRelat)
  
  y11=saidas.CLASSIC.FOB.C_PI.*1e-3;
  y21=saidas.CLASSIC.FOB.C_PU.*1e-3;
  y31=saidas.CLASSIC.FOB.Cop_PU.*1e-3;
  y41=saidas.CLASSIC.FOB.fob.*1e-3;
  y51=saidas.CLASSIC.FOB.F_PU;
  z1=(saidas.CLASSIC.HESIM.mc-saidas.CLASSIC.HESIM.mc_sp)./saidas.CLASSIC.HESIM.mc_sp.*100;
  w1 = -saidas.CLASSIC.SIMULATION.F_PU;
  d1=sum(abs(saidas.CLASSIC.HESIM.mc-dados.EQUIP.k));
  m1=sum(saidas.CLASSIC.HESIM.mc);
  res1='-';
  y12=saidas.CLASSIC2.FOB.C_PI.*1e-3;
  y22=saidas.CLASSIC2.FOB.C_PU.*1e-3;
  y32=saidas.CLASSIC2.FOB.Cop_PU.*1e-3;
  y42=saidas.CLASSIC2.FOB.fob.*1e-3;
  y52=saidas.CLASSIC2.FOB.F_PU;
  z2=(saidas.CLASSIC2.HESIM.mc-saidas.CLASSIC2.HESIM.mc_sp)./saidas.CLASSIC2.HESIM.mc_sp.*100;
  w2 = -saidas.CLASSIC2.SIMULATION.F_PU;
  d2=sum(abs(saidas.CLASSIC2.HESIM.mc-dados.EQUIP.k));
  m2=sum(saidas.CLASSIC2.HESIM.mc);
  res2='-';


  for i = 1:size(saidas.SPLIT_LP,1)
    x(i)=i;
    y13(i)=saidas.SPLIT_LP(i).FOB.C_PI.*1e-3;
    y23(i)=saidas.SPLIT_LP(i).FOB.C_PU.*1e-3;
    y33(i)=saidas.SPLIT_LP(i).FOB.Cop_PU.*1e-3;
    y43(i)=saidas.SPLIT_LP(i).FOB.fob.*1e-3;
    y53(i)=saidas.SPLIT_LP(i).FOB.F_PU;
    z3(:,i)=(saidas.SPLIT_LP(i).HESIM.mc-  saidas.SPLIT_LP(i).HESIM.mc_sp)./saidas.SPLIT_LP(i).HESIM.mc_sp.*100;
    w3(i) = -saidas.SPLIT_LP(i).SIMULATION.F_PU;
    d3(i)=sum(abs(saidas.SPLIT_LP(i).HESIM.mc-dados.EQUIP.k));
    m0(i)=sum(dados.EQUIP.k);
    m3(i)=sum(saidas.SPLIT_LP(i).HESIM.mc);
    teste=1
    res3(i)='-';
    if m0(i)>1.01*m3(i), res3(i)='Not viable'; teste=0;else, res3(i)='Viable'; end
  end

  for i = 1:size(saidas.SPLIT_QP,1)
    x(i)=i;
    y14(i)=saidas.SPLIT_QP(i).FOB.C_PI.*1e-3;
    y24(i)=saidas.SPLIT_QP(i).FOB.C_PU.*1e-3;
    y34(i)=saidas.SPLIT_QP(i).FOB.Cop_PU.*1e-3;
    y44(i)=saidas.SPLIT_QP(i).FOB.fob.*1e-3;
    y54(i)=saidas.SPLIT_QP(i).FOB.F_PU;
    z4(:,i)=(saidas.SPLIT_QP(i).HESIM.mc-  saidas.SPLIT_QP(i).HESIM.mc_sp)./saidas.SPLIT_QP(i).HESIM.mc_sp.*100;
    w4(i) = -saidas.SPLIT_QP(i).SIMULATION.F_PU;
    d4(i)=sum(abs(saidas.SPLIT_QP(i).HESIM.mc-dados.EQUIP.k));
    m0(i)=sum(dados.EQUIP.k);
    m4(i)=sum(saidas.SPLIT_QP(i).HESIM.mc);
    teste=1
    res4(i)='-';
    if m0(i)>1.01*m4(i), res4(i)='Not viable'; teste=0;else, res4(i)='Viable'; end
  end

  figure;a=gcf();a.background=8;
  bar(x,[y14(:) y24(:) y34(:)],'stacked')
  a=get("current_axes");a.margins = [0.125,0.25,0.125,0.125];
  a.x_label.text='Case';a.x_label.font_size=3;
  a.y_label.text='Annualized Cost (kUSD/y)';a.y_label.font_size=3;
  a.title.text='Costs';a.title.font_size=5;
  a=legend('Pipes','Pump','Operational',-1);a.background=8;a.font_size=3;
  a = gcf();  xs2gif(a,pwd()+'\Relatorios\graficos\'+nomeRelat+'_fig_01.gif');  close
  
  figure;a=gcf();a.background=8;
  bar(x,z4','grouped')
  a=get("current_axes");a.margins = [0.125,0.25,0.125,0.125];
  a.x_label.text='Case';a.x_label.font_size=3;
  a.y_label.text='Cooling Water Excess (%)';a.y_label.font_size=3;
  a.title.text='Water Flow Rate';a.title.font_size=5;
  hetext=[];
  for i=1:size(z4,1)
    hetext(i)='HE-'+string(i);
  end
  a=legend(hetext,-1);a.background=8;a.font_size=3;
  a = gcf();  xs2gif(a,pwd()+'\Relatorios\graficos\'+nomeRelat+'_fig_02.gif');close

  txt1=parteInicial('Optimization Results');
  
  nopt = size(saidas.SPLIT_LP,1);
  j=0;
  for i = 1:1
    j=j+1;
    ind(j)=j;
    caso(j)=0;
    tipo(j)='TD';
    fob(j)=round(1e4*saidas.CLASSIC.FOB.fob.*1e-3)/1e4;
    fobPEN(j)=round(1e4*saidas.CLASSIC.FOB.fobPEN)/1e4;
    Cop_PU(j)=round(1e4*saidas.CLASSIC.FOB.Cop_PU.*1e-3)/1e4;
    C_PI(j)=round(1e4*saidas.CLASSIC.FOB.C_PI.*1e-3)/1e4;
    C_PU(j)=round(1e4*saidas.CLASSIC.FOB.C_PU.*1e-3)/1e4;
    D(j) = d1(i);
    res(j)=res1(i);
    linking(j)='<A HREF=""'+nomeRelat+'_TRAD_'+string(i)+'.htm"">'
  end
  for i = 1:1
    j=j+1;
    ind(j)=j;
    caso(j)=0;
    tipo(j)='TD2';
    fob(j)=round(1e4*saidas.CLASSIC2.FOB.fob.*1e-3)/1e4;
    fobPEN(j)=round(1e4*saidas.CLASSIC2.FOB.fobPEN)/1e4;
    Cop_PU(j)=round(1e4*saidas.CLASSIC2.FOB.Cop_PU.*1e-3)/1e4;
    C_PI(j)=round(1e4*saidas.CLASSIC2.FOB.C_PI.*1e-3)/1e4;
    C_PU(j)=round(1e4*saidas.CLASSIC2.FOB.C_PU.*1e-3)/1e4;
    D(j) = d2(i);
    res(j)=res2(i);
    linking(j)='<A HREF=""'+nomeRelat+'_TRAD2_'+string(i)+'.htm"">'
  end
  for i = 1:nopt
    j=j+1;
    ind(j)=j;
    caso(j)=i;
    tipo(j)='SP-LP';
    fob(j)=round(1e4*saidas.SPLIT_LP(i).FOB.fob.*1e-3)/1e4;
    fobPEN(j)=round(1e4*saidas.SPLIT_LP(i).FOB.fobPEN)/1e4;
    Cop_PU(j)=round(1e4*saidas.SPLIT_LP(i).FOB.Cop_PU.*1e-3)/1e4;
    C_PI(j)=round(1e4*saidas.SPLIT_LP(i).FOB.C_PI.*1e-3)/1e4;
    C_PU(j)=round(1e4*saidas.SPLIT_LP(i).FOB.C_PU.*1e-3)/1e4;
    D(j) = d3(i);
    res(j)=res3(i);
    linking(j)='<A HREF=""'+nomeRelat+'_PROP_LP_'+string(i)+'.htm"">'
  end
  for i = 1:nopt
    j=j+1;
    ind(j)=j;
    caso(j)=i;
    tipo(j)='SP-QP';
    fob(j)=round(1e4*saidas.SPLIT_QP(i).FOB.fob.*1e-3)/1e4;
    fobPEN(j)=round(1e4*saidas.SPLIT_QP(i).FOB.fobPEN)/1e4;
    Cop_PU(j)=round(1e4*saidas.SPLIT_QP(i).FOB.Cop_PU.*1e-3)/1e4;
    C_PI(j)=round(1e4*saidas.SPLIT_QP(i).FOB.C_PI.*1e-3)/1e4;
    C_PU(j)=round(1e4*saidas.SPLIT_QP(i).FOB.C_PU.*1e-3)/1e4;
    D(j) = d4(i);
    res(j)=res4(i);
    linking(j)='<A HREF=""'+nomeRelat+'_PROP_QP_'+string(i)+'.htm"">'
  end
  
  calc=[];
  calc.ind = ind;
  calc.caso=caso;
  calc.tipo = tipo;
  calc.fob=fob;
  calc.Cop_PU=Cop_PU;
  calc.C_PU=C_PU;
  calc.C_PI=C_PI;
  calc.D=D;
  calc.res=res;
  calc.fobPEN=fobPEN;
  
  nomeCampo=['ind';'tipo';'caso';'fob';'Cop_PU';'C_PU';'C_PI';'D';'res';'fobPEN'];
  descCampo=['Index';'Desc.';'Case';'FOB';'Pump Op. Cost';'Pump Cost';'Pipe Cost';'Flow Rate Deviation';'Optimization';'Penalty'];
  unidCampo=['-';'-';'-';'(kUSD/y)';'(kUSD/y)';'(kUSD/y)';'(kUSD/y)';'kg/s';'-';'-'];  
  txt2 = tabelaValores_com_link("Optimization Results",calc,nomeCampo,descCampo,unidCampo,linking);

  txt2 = [txt2;figura1(nomeRelat+'_fig_01')];
  txt2 = [txt2;figura1(nomeRelat+'_fig_02')];
  
  geraDiagrama(dados)
          
  copyfile(pwd()+'/rede.gif',pwd()+'/Relatorios/graficos/'+nomeRelat+'_rede.gif');
  
  txtt1=parteInicial('Pipe Network Description');
  
  nomeCampo=['projeto';'usuario';'data';'documento';'nome_rede';'desc_rede'];
  descCampo=['Project Name';'User Name';'Date';'Document';'Network Name';'Network Description'];
  unidCampo=['';'';'';'';'';''];
  txtt2 = tabelaValoresVert('Data Details',dados.CASO,nomeCampo,descCampo,unidCampo);

  nomeCampo=['tag';'dens';'visc';'cp';'temp'];
  descCampo=['Fluid Name';'Density';'Viscosity';'Thermal Capacity';'Inlet Temperature'];
  unidCampo=['-';'kg/m3';'cP';'J/(kgoC)';'oC'];
  txtt3 = tabelaValoresVert("Fluid",dados.FLUIDO,nomeCampo,descCampo,unidCampo);
  
  nomeCampo=['ind';'tag';'L';'e';'di';'LDac';'Fac'];
  descCampo=['Id.';'Tag';'Length';'Roughness';'Preliminar Internal Diameter';'Pipe Fittings L/D';'Fixed Head Loss'];
  unidCampo=['-';'-';'m';'10-6 m';'mm';'-';'m'];
  txtt4 = tabelaValores("Pipes",dados.LINHA,nomeCampo,descCampo,unidCampo);
  
  nomeCampo=['ind';'tag';'k';'F'];
  descCampo=['Id.';'Tag';'Rated flow rate';'Rated head loss'];
  unidCampo=['-';'-';'kg/s';'m'];
  txtt5 = tabelaValores("Heat Exchangers",dados.EQUIP,nomeCampo,descCampo,unidCampo);
  
  nomeCampo=['ind_vertice';'tag_vertice';'tipo';'esp';'z'];
  descCampo=['Id.';'Tag';'Type (P or W)';'Specification';'Height'];
  unidCampo=['-';'-';'P or W';'bar or kg/s';'m'];
  txtt6 = tabelaValores("Specifications",dados.VERTICE,nomeCampo,descCampo,unidCampo);

  txtt7=parteInicial('Optimization Data');
  
  nomeCampo=['ind';'tag';'coef3';'coef2';'coef1';'coef0';'qrated'];
  descCampo=['Id.';'Tag';'Coeficient 3';'Coeficient 2';'Coeficient 1';'Coeficient 0';'Rated Flow Rate'];
  unidCampo=['-';'-';'m/(kg/s)^3';'m/(kg/s)^2';'m/(kg/s)^1';'m/(kg/s)^0';'m³/s'];
  txtt8 = tabelaValores("Pump Characteristic Curves",dados.PUMPCURVE,nomeCampo,descCampo,unidCampo);

  nomeCampo=['tag';'DIN';'DOUT';'DN';'C'];
  descCampo=['Tag';'Internal Diameter';'External Diameter';'Nominal Diameter';'Linear Cost'];
  unidCampo=['-';'mm';'mm';'in';'USD/m/year'];
  alfah=dados.PIPECOST.alfa;
  betah=dados.PIPECOST.beta;
  for j=1:length(dados.PIPE.DN)
    dados.PIPE.C(j) = 3.281^(betah+1)*alfah*((dados.PIPE.DN(j).*0.0254)^betah);
  end  
  txtt9 = tabelaValores("Possible Pipe Set",dados.PIPE,nomeCampo,descCampo,unidCampo);


  nomeCampo=['eta';'Nop';'pc';'gamah';'coef1';'coef2';'in';'ny'];
  descCampo=['Pump Efficiency';'Number of hours';'Energy cost';'Cost Coefficient 1';'Cost Coefficient 2';'Cost Coefficient 3';'Interest rate';'Number of Years'];
  unidCampo=['-';'hours/year';'USD/kWh';'USD';'-';'-';'-';'years'];
  txtt10 = tabelaValoresVert('Optimization Data',dados.PUMPCOST,nomeCampo,descCampo,unidCampo);

  txtt11=parteInicial('Pipe Network Topology');

  txtt12=figura0(nomeRelat);

  txtf=parteFinal(nomeRelat);
  
  txt = [txt1;txt2;txtt1;txtt2;txtt3;txtt4;txtt5;txtt6;txtt7;txtt8;txtt9;txtt10;txtt11;txtt12;txtf];

  deletefile(pwd()+'/Relatorios/'+nomeRelat+'.htm');
  write(pwd()+'/Relatorios/'+nomeRelat+'.htm',txt);
  dos('start '+pwd()+'/Relatorios/'+nomeRelat+'.htm');

endfunction


function txt=parteInicial(nomeRelat)
  
  txt = [];
  txt(size(txt,1)+1)='<HTML>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<BODY bgcolor=#fdf1e3 leftMargin=20 marginheight=0 marginwidth=0>';
  txt(size(txt,1)+1)=' ';
  txt(size(txt,1)+1)='<TABLE cellSpacing=0 cellPadding=0 width=""80%"" border=0>';
  txt(size(txt,1)+1)='<TR>';
//  txt(size(txt,1)+1)='  <TD WIDTH=70><IMG src=""imagens/pipelab.gif"" ALIGN=CENTER BORDER=0></TD>';
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
  txt(size(txt,1)+1)='<FONT size=6><B>'+nomeRelat+'</B></FONT></center></font>';
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
  txt(size(txt,1)+1)='<A HREF=""graficos/'+nomeRelat+'_rede.gif"">'
  txt(size(txt,1)+1)='<IMG src=""graficos/'+nomeRelat+'_rede.gif"" width=700></A></TD>';
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='</TBODY>';
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR><BR>';
  
endfunction

function txt = figura1(nomeFig)
  
  txt = [];
  txt(size(txt,1)+1)='<center><table>';
  txt(size(txt,1)+1)='</table></center>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<TABLE>';  
  txt(size(txt,1)+1)='<TBODY>';
  txt(size(txt,1)+1)='<TR>';
  txt(size(txt,1)+1)='<TD WIDTH=10% ALIGN=middle>'
  txt(size(txt,1)+1)='<A HREF=""graficos/'+nomeFig+'.gif"">'
  txt(size(txt,1)+1)='<IMG src=""graficos/'+nomeFig+'.gif"" width=700></A></TD>';
  txt(size(txt,1)+1)='</TR>';
  txt(size(txt,1)+1)='</TBODY>';
  txt(size(txt,1)+1)='</TABLE>';
  txt(size(txt,1)+1)='';
  txt(size(txt,1)+1)='<BR><BR>';
  
endfunction


function geraDiagrama(dados)
  
  S_PU = size(dados.BOMBA.tag,1);
  S_PI = size(dados.LINHA.tag,1);
  S_HE = size(dados.EQUIP.tag,1);
  S = S_PU+S_PI+S_HE;
  N_E = length(dados.VERTICE.ind_vertice);
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
    ix = dados.LINHA.ind(i);
    QSI_PI(i,ix)=1;
  end
  for i=1:S_PU
    ix = dados.BOMBA.ind(i);
    QSI_PU(i,ix)=1;
  end
  for i=1:S_HE
    ix = dados.EQUIP.ind(i);
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
  
  mind = min(dados.LINHA.di);
  maxd = max(dados.LINHA.di);
  ld = ceil((dados.LINHA.di-mind)./(maxd-0).*5)+2;  
  
  for i = 1:S_PI
    no1 = find(K_PI(:,i)==-1);
    no2 = find(K_PI(:,i)==+1);
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+dados.LINHA.tag(i)+'"",penwidth='+string(ld(i))+', style=bold];';
  end
  
  txt(size(txt,1)+1) = '  subgraph cluster1 {';
  txt(size(txt,1)+1) = 'node [width=.1,height=.1,shape=circle,style=filled];';
  txt(size(txt,1)+1) = 'edge [color=blue,style=bold];';
  for i = 1:S_PU
    no1 = find(K_PU(:,i)==-1);
    no2 = find(K_PU(:,i)==+1);
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+string(dados.BOMBA.ind(i))+' ('+dados.BOMBA.tag(i)+')"",len=2, style=bold, color=green];';
  end
  txt(size(txt,1)+1) = 'label = ""Pumps"";';
  txt(size(txt,1)+1) = '}';
  
  txt(size(txt,1)+1) = '  subgraph cluster2 {';
  txt(size(txt,1)+1) = 'node [width=.1,height=.1,shape=circle,style=filled];';
  txt(size(txt,1)+1) = 'edge [color=blue,style=bold];';
  for i = 1:S_HE
    no1 = find(K_HE(:,i)==-1);
    no2 = find(K_HE(:,i)==+1);
    txt(size(txt,1)+1) = string(no1)+' -> '+string(no2)+'  [label=""'+string(dados.EQUIP.ind(i))+' ('+dados.EQUIP.tag(i)+')"",len=2, style=bold, color=red];';
  end
  txt(size(txt,1)+1) = 'label = ""Heat Exchangers"";';
  txt(size(txt,1)+1) = '}';
  txt(size(txt,1)+1) = '}';
    
  write(pwd()+'/rede.dot',txt);
  dos('""C:\Program Files\Graphviz2.26.3\bin\dot"" -Tgif ""'+pwd()+'\rede.dot"" -o ""'+pwd()+'\rede.gif""')  
  aux = dir(pwd());
  if ~or(aux.name=='rede.gif');
    copyfile(pwd()+'/notavailable.gif',pwd()+'/rede.gif');
  end
  deletefile(pwd()+'/rede.dot');
  
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
  txt(size(txt,1)+1)='<TR>';
  for j = 1:nvar
    for i = 1:nCampi
      if ~isempty(tipoCampoi)
        if i==1
            if isMat(find(nomeCampoTotal(i)==nomeCampo))==0
              execstr('valor = variavel.'+nomeCampoTotal(i)+'('+string(j)+')'+';')
              txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>'+linking(j)+string(valor)+'</A></TD>';
            else
              txt(size(txt,1)+1)='<TD align=center> <table>';
              execstr('valor = variavel.'+nomeCampoTotal(i)+'(j,:);')
              for k=1:length(valor)
                txt(size(txt,1)+1)=' <TD bgcolor=""#ffffcc"" ALIGN=middle>'+linking(j)+string(valor(k))+'</A></TD>';
              end
              txt(size(txt,1)+1)='</table></TD>';
            end
        else
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
