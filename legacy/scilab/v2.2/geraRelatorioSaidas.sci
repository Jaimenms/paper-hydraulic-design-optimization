function geraRelatorioSaidas(titulo,dados,saidas,inicial,nomeRelat)
  
  if ~isstruct(saidas)
      auxS=1;  
  else
      auxS =size(saidas,1);
  end
  
  auxS
  for ind = 1:auxS
      txtt=[];
      txtt=parteInicial(titulo+' - Case '+string(ind));
    
      AUX=[];
      AUX.ind = dados.BOMBA.ind;
      AUX.tag = dados.BOMBA.tag;
      AUX.F_PU  =round(1e4*saidas(ind).FOB.F_PU)/1e4;
      AUX.q_PU  =round(1e4*saidas(ind).FOB.q_PU)/1e4;
      AUX.F_PU_rated  =round(1e4*saidas(ind).FOB.F_PU_rated)/1e4;
      AUX.q_PU_rated  =round(1e4*saidas(ind).FOB.q_PU_rated)/1e4;
      nomeCampo=['ind';'tag';'q_PU_rated';'F_PU_rated';'q_PU';'F_PU'];
      descCampo=['Edge index';'Tag';'Nominal flow rate';'Nominal head';'Simulated flow rate';'Simulated head'];
      unidCampo=['-';'-';'m3/s';'m';'m3/s';'m'];
      txtt = [txtt;tabelaValoresVert("Pumps",AUX,nomeCampo,descCampo,unidCampo)];

      AUX=[];
      AUX.ind_line=dados.LINHA.ind;
      AUX.Dmin  = saidas(ind).FOB.DNmin;
      AUX.Dmax  = saidas(ind).FOB.DNmax;
      AUX.xmin  = round(1e4*saidas(ind).FOB.xmin)/1e4;
      AUX.xmax  = round(1e4*saidas(ind).FOB.xmax)/1e4;
      AUX.h = round(1e4*saidas(ind).FOB.F_PIOR)/1e4;
      AUX.k1 = round(1e4*inicial.k_PI)/1e4;
      AUX.k2 = round(1e4*saidas(ind).SIMULATION.k_PI)/1e4;
      AUX.F1  = round(1e4*saidas(ind).SIMULATION.F_PI1)/1e4;
      AUX.F2  = round(1e4*saidas(ind).SIMULATION.F_PI2)/1e4;
      AUX.v1  = round(1e4*saidas(ind).SIMULATION.v1)/1e4;
      AUX.v2  = round(1e4*saidas(ind).SIMULATION.v2)/1e4;
      nomeCampo=['ind_line';'xmin';'Dmin';'xmax';'Dmax';'h';'k1';'k2';'F1';'F2';'v1';'v2'];
      descCampo=['Id.';'Length Fraction 1';'Nominal Diameter 1';'Length Fraction 2';'Nominal Diameter 2';'Forced head loss';'Desired Mass Flow';'Simulated Mass Flow';'Head Loss 1';'Head Loss 2';'Velocity 1';'Velocity 2'];
      unidCampo=['-';'-';'in';'-';'in';'m';'kg/s';'kg/s';'m/100m';'m/100m';'m/s';'m/s'];
      txtt=[txtt;tabelaValores("Pipes",AUX,nomeCampo,descCampo,unidCampo)];

      
      AUX=[];
      AUX.ind_line=dados.EQUIP.tag;
      AUX.Tco_sp = round(1e4*saidas(ind).HESIM.Tco_sp)/1e4;
      AUX.Tco = round(1e4*saidas(ind).HESIM.Tco)/1e4;
      AUX.mc_sp = round(1e4*saidas(ind).HESIM.mc_sp)/1e4;
      AUX.mc = round(1e4*saidas(ind).HESIM.mc)/1e4;
      nomeCampo=['ind_line';'Tco_sp';'Tco';'mc_sp';'mc'];
      descCampo=['Identification';'Rated Outlet Temp. (cold side)';...
                 'Simulated Outlet Temp. (cold side)';...
                 'Rated Flow Rate (cold side)';...
                 'Simulated Flow Rate (cold side)'];
      unidCampo=['-';'oC';'oC';'kg/s';'kg/s'];
      txtt=[txtt;tabelaValores("Heat Exchangers - Cold Side",AUX,nomeCampo,descCampo,unidCampo)];


      AUX=[];
      AUX.ind_line=dados.EQUIP.tag;
      AUX.Tho_sp = round(1e4*saidas(ind).HESIM.Tho_sp)/1e4;
      AUX.Tho = round(1e4*saidas(ind).HESIM.Tho)/1e4;
      AUX.mh_sp = round(1e4*saidas(ind).HESIM.mh_sp)/1e4;
      AUX.mh = round(1e4*saidas(ind).HESIM.mh)/1e4;
      nomeCampo=['ind_line';'Tho_sp';'Tho';'mh_sp';'mh'];
      descCampo=['Identification';'Rated Outlet Temp. (hot side)';...
                 'Simulated Outlet Temp. (hot side)';...
                 'Rated Flow Rate (hot side)';...
                 'Simulated Flow Rate (hot side)'];
      unidCampo=['-';'oC';'oC';'oC';'kg/s';'kg/s'];
      txtt=[txtt;tabelaValores("Heat Exchangers - Hot Side",AUX,nomeCampo,descCampo,unidCampo)];


      AUX=[];
      AUX.fob   =round(1e4*saidas(ind).FOB.fob)/1e4;
      AUX.C_PI  =round(1e4*saidas(ind).FOB.C_PI)/1e4;
      AUX.C_PU  =round(1e4*saidas(ind).FOB.C_PU)/1e4;
      AUX.Cop_PU=round(1e4*saidas(ind).FOB.Cop_PU)/1e4;
      nomeCampo=['fob';'C_PI';'C_PU';'Cop_PU'];
      descCampo=['FOB';'Annualized Cost Pipes';'Annualized Cost Pumps (Fixed)';'Annualized Cost Pumps (Variable)'];
      unidCampo=['USD/yr';'USD/yr';'USD/yr';'USD/yr'];
      txtt = [txtt;tabelaValoresVert("Objetive Function",AUX,nomeCampo,descCampo,unidCampo)];

      AUX=[];
      AUX.ind_line=dados.EQUIP.tag;
      AUX.F_HE=saidas(ind).FOB.F_HE;
      nomeCampo=['ind_line';'F_HE'];
      descCampo=['Identification';'Actual Head Loss'];
      unidCampo=['-';'m';'m'];
      txtt=[txtt; tabelaValores("Heat Exchangers",AUX,nomeCampo,descCampo,unidCampo)];
        
      txtf=parteFinal(nomeRelat);
      txt = [txtt;txtf];
      
      deletefile(pwd()+'/Relatorios/'+nomeRelat+'_'+string(ind)+'.htm');
      write(pwd()+'/Relatorios/'+nomeRelat+'_'+string(ind)+'.htm',txt);
      //dos('start '+pwd()+'/Relatorios/'+nomeRelat+'.htm');
  end
  

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