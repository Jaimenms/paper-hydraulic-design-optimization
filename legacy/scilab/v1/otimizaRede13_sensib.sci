function [saidas_sensib]=otimizaRede13_sensib(dados)
  // OTIMIZAREDE    Otimiza uma rede de escoamento de fluido incompressível com
  //                qualquer topologia (redes cíclicas ou acíclicas) dotadas ou
  //                não de equipamentos ou elementos geradores ou consumidores de
  //                momento como bombas, válvulas ou acidentes. Esses equipamentos
  //                ou elementos são modelados por um polinômio que relaciona a vazão
  //                através do mesmo e a variação do head entre o nó a montante e 
  //                o nó a jusante do elemento.
  //
  //   Sintaxe: [saidas] = OTIMIZAREDE(dados)
  //
  //
  //   Os argumentos de entrada são:
  //
  //     dados: struct com os dados da otimização
  //
  //   Os argumentos de saída são:
  //
  //     saidas: struct com as saidas da otimização
  //
  //
  //   Desenvolvido por Jaime Souza em 11 de outubro de 2010

  // (1) Iniciando variaveis
  saidas.CLASSIC = [];
  saidas.SPLIT = list();

  // (2) Criando struct de parametros
  parametros = geraParametros(dados);

//  f_sensib = 0.25:0.25:2.00;
  f_sensib = 0.025:0.025:2.0;

  saidas_sensib = [];
  xQP=[];
  xTRA=[];
  xTo=[];
  for iii = 1:length(f_sensib)
      clear saidas;
      clear OPT;
      f_sensib_i = f_sensib(iii);
      
      // (3) Determinando balancos de massa
      saidas.INITIAL = determinaInicial(parametros);
      k_PU_rated = saidas.INITIAL.k_PU;
      
      // (4) Determina Parametros do Otimizador    
      OPT = determinaParametrosPre(saidas.INITIAL,parametros);
    

      // (5) Determina diametros da rede a partir das velocidade de projeto
      mprintf('Otimização projeto tradicional-Himmelblau:\n')
      parametros.v_PI_max=3.7;//3.7;
      saidas.INITIAL = determinaTradicional(saidas.INITIAL,parametros,f_sensib_i);
      //disp(saidas.INITIAL.D1)
      // (6) Inclui a bomba para o projeto classico
    //  [dadosB,parametrosB] = incluiBombaMinima(saidas.INITIAL.x0,saidas.INITIAL.k_PU,OPT,dados,parametros);
    //  [dados2,parametros2]=ativaCurvaBomba(1,dadosB,parametrosB);
      [indice] = incluiBombaAdequada(saidas.INITIAL.x0,saidas.INITIAL.k_PU,OPT,dados,parametros);
      if (~isempty(indice))
          //disp(indice)
          //pause
          [dados2,parametros2] =ativaCurvaBomba(indice,dados,parametros);
        
          // Simulando para projeto classico
          mprintf('Simulação projeto tradicional-Himmelblau:\n')
          saidas_aux=[];
          [Diametro,xi,DiametroNominal] = x2D(saidas.INITIAL.x0,parametros2.D,parametros2.DN);
          dados2.LINHA.di = Diametro.*1000;
          dados2.LINHA.xsplit=zeros(Diametro);
          dados2.LINHA.Dsplit=Diametro.*1000;
          [saidas_aux.SIMULATION,xTRA]= simulaRede(dados2,xTRA);
          saidas_aux.FOB   = determinaRedePos(xi,xi,OPT.F_PI,parametros2,saidas_aux.SIMULATION,OPT,xi,k_PU_rated,f_sensib_i);
          saidas_aux.HESIM = heatcheck (saidas_aux.SIMULATION.k_HE,parametros2);
          saidas.CLASSIC = saidas_aux;
      else
          saidas.CLASSIC=[];
      end
    
      mprintf('Otimização projeto tradicional-Towler:\n')
      parametros.v_PI_max = 3.7;
      saidas.INITIAL = determinaTowler(saidas.INITIAL,parametros);
      // (6) Inclui a bomba para o projeto classico
      [dadosB,parametrosB] = incluiBombaMinima(saidas.INITIAL.x0,saidas.INITIAL.k_PU,OPT,dados,parametros);
      [dados2,parametros2] =ativaCurvaBomba(1,dadosB,parametrosB);
      [indice] = incluiBombaAdequada(saidas.INITIAL.x0,saidas.INITIAL.k_PU,OPT,dados,parametros);
      
      if (~isempty(indice))
          [dados2,parametros2] =ativaCurvaBomba(indice,dados,parametros);
          // Simulando para projeto classico
          mprintf('Simulação projeto tradicional-Towler:\n')
          saidas_aux=[];
          [Diametro,xi,DiametroNominal] = x2D(saidas.INITIAL.x0,parametros2.D,parametros2.DN);
          dados2.LINHA.di = Diametro.*1000;
          dados2.LINHA.xsplit=zeros(Diametro);
          dados2.LINHA.Dsplit=Diametro.*1000;
          [saidas_aux.SIMULATION,xTo]= simulaRede(dados2,xTo);
          sim_Tow=saidas_aux.SIMULATION;
          opt_Tow=OPT;
          saidas_aux.FOB   = determinaRedePos(xi,xi,OPT.F_PI,parametros2,saidas_aux.SIMULATION,OPT,xi,k_PU_rated,f_sensib_i);
          saidas_aux.HESIM = heatcheck (saidas_aux.SIMULATION.k_HE,parametros2);
          saidas.CLASSIC2 = saidas_aux;
      else
          saidas.CLASSIC2=[];
      end
      
      // (7) Otimizando para cada curva de bomba
      mprintf('Pré-tratamento projeto proposto:\n')
      for i = 1:size(parametros.HOPT,2)
          
          // Iniciando
          mprintf('Otimização para bomba '+string(i)+'...\n')      
          // Atualizando a bomba para curva i
          [dados2,parametros2]=ativaCurvaBomba(i,dados,parametros);
          
          // Determinando parametros do otimizador
          OPT = determinaParametrosPos(OPT,saidas.INITIAL,parametros2,k_PU_rated,f_sensib_i);
    
          // Gerando arquivos de dados
          S_PI = parametros.S_PI;
          N_D = parametros.N_D;
          Sx=S_PI*N_D;
          
          // Determinando subseções válidas pelos critérios de máx. velocidade e máx. perda de carga
          aux=0;
          for k=1:S_PI
              for j=1:N_D
                  aux = aux+1;
                  dPdL100(aux)=OPT.dPdL100(k,j);
                  v_PI(aux)=OPT.v_PI(k,j);
              end
          end
          dPdL100_max=%inf;//0.5;
          v_PI_max=3.7;//3.7;
          checkVal1=v_PI<v_PI_max  & dPdL100<dPdL100_max
                
          ix  =find(checkVal1(:));
          inx =find(~checkVal1(:));
          Six =length(ix);
          Sinx=length(inx);
          Sz1=S_PI;
          Sz2=length(OPT.b2);
          Mix=zeros(Six,Sx);
          for k=1:Six
              Mix(k,ix(k))=1;
          end
          
          mprintf('Otimização projeto proposto:\n')
          disp('Executando KARMARKAR para determinar estimativa inicial...')
          S_CIR = size(parametros.QSI_CIR,1);
          x0 = zeros(Sx,1);
          x0(ix) = ones(Six,1);
          x0m=x0(ix);x0m=x0m(:);
          z10 = -(ones(S_PI,1)-OPT.C1*Mix'*x0m);
          z20 = -(OPT.b2-OPT.C2*Mix'*x0m);
          
          y0 = [x0m;z10;z20];
          C1 = OPT.C1;
          C2 = OPT.C2;
          C1z1=-eye(S_PI,S_PI);
          C1z2=zeros(S_PI,S_CIR);
          C2z1=zeros(S_CIR,S_PI);
          C2z2=-eye(S_CIR,S_CIR);
          Ckar =[[C1*Mix' C1z1 C1z2];[C2*Mix' C2z1 C2z2]];
          a = Ckar;
          b = OPT.b;
          c = [zeros(Six,1);ones(z10);ones(z20)];
          
          eh_inviavel=~isempty(find(z20<0));
          if eh_inviavel
              y1=y0;
          else
              y1=karmarkar2(a,b,c,y0,1.d-6,1/4);
         end
          
          x1m = y1(1:Six);x1m=x1m(:);
          x1=zeros(Sx,1);x1(ix)=x1m;
          z1 = y1((Six+1):(Six+S_PI));z1=z1(:);
          z2 = y1((Six+S_PI+1):(Six+S_PI+S_CIR));z2=z2(:);
          disp('... estimativa inicial determinada.')
          
          eh_inviavel=~isempty(find(abs(z2)>1e-3));
          if eh_inviavel
              disp('Problema inviável. Conjunto de diametros ou bomba inadequados.')
              x1 = zeros(Sx,1);
              x1(N_D:N_D:Sx)=1;
              x3=x1;
          else
              disp('Executando KARMARKAR para resolver LP...')
              a = OPT.C*Mix';
              b = OPT.b;
              c = Mix*OPT.p;
              try 
                  [x2m]=karmarkar2(a,b,c,x1(ix),1e-6,1/4);x2=zeros(Sx,1);x2(ix)=x2m;
                  disp('...LP resolvido.')
              catch
                  x2m = xi;
                  disp('...LP não resolvido.')
              end
    
              disp('Executando QUAPRO para resolver QP para todos os diametros...')
              custoOpt=OPT.p(:)'*x2;
              Qix=Mix*OPT.Q*(Mix');
              pix=OPT.p(ix);
              Cix=[OPT.C;[OPT.p(:)]']*(Mix');
              ciix=OPT.ci(ix);
              csix=OPT.cs(ix);
              b=[OPT.b;1.0*custoOpt];
              me=size(OPT.C,1);
              x3m=quapro(Qix,pix,Cix,b,ciix,csix,me,x2(ix));x3=zeros(Sx,1);x3(ix)=x3m;
    
              disp('.. QP inicial resolvido.')
              
          end
    
          [x2] = x2Dsplit(x2,parametros2.D,parametros2.DN);
          [x3,Dmin,xmin,Dmax,xmax,DNmin,DNmax] = x2Dsplit(x3,parametros2.D,parametros2.DN);
          
          xopti=x2;
          xopt=x3;
    
          mprintf('Simulação da QP do cenário '+string(i)+':\n')
          saidas_aux=[];
          [xopt,Dmin,xmin,Dmax,xmax,DNmin,DNmax] = x2Dsplit(xopt,parametros2.D,parametros2.DN);
          dados2.LINHA.di = Dmin.*1000;
          dados2.LINHA.xsplit=xmax;dados2.LINHA.Dsplit=Dmax.*1000;
          [saidas_aux.SIMULATION,xQP] = simulaRede(dados2,xQP);
          saidas_aux.FOB   = determinaRedePos(xopt,xopt,OPT.F_PI,parametros2,saidas_aux.SIMULATION,OPT,xopt,k_PU_rated,f_sensib_i);
          saidas_aux.HESIM = heatcheck (saidas_aux.SIMULATION.k_HE,parametros2);
          saidas_aux.OPT   = OPT;
          saidas.SPLIT_QP(i) = saidas_aux;
    
      end
      
      saidas_sensib.f_sensib(iii)=f_sensib_i;
      saidas_sensib.pc(iii)      =f_sensib_i.*parametros.pc;


      if isempty(saidas.CLASSIC)
          saidas_sensib.fob_classic(iii)=0;
          saidas_sensib.C_PU_classic(iii)=0;
          saidas_sensib.C_PI_classic(iii)=0;
          saidas_sensib.Cop_PU_classic(iii)=0;
          saidas_sensib.Tho_classic(:,iii)=zeros(parametros.S_HE,1);
      else
          saidas_sensib.fob_classic(iii)=saidas.CLASSIC.FOB.fob;
          saidas_sensib.C_PU_classic(iii)=saidas.CLASSIC.FOB.C_PU;
          saidas_sensib.C_PI_classic(iii)=saidas.CLASSIC.FOB.C_PI;
          saidas_sensib.Cop_PU_classic(iii)=saidas.CLASSIC.FOB.Cop_PU;
          saidas_sensib.Tho_classic(:,iii)=saidas.CLASSIC.HESIM.Tho(:);
      end
          
      if isempty(saidas.CLASSIC2)
          saidas_sensib.fob_classic2(iii)=0;
          saidas_sensib.C_PU_classic2(iii)=0;
          saidas_sensib.Cop_PU_classic2(iii)=0;
          saidas_sensib.C_PI_classic2(iii)=0;
          saidas_sensib.Tho_classic2(:,iii)=zeros(parametros.S_HE,1);        
      else
          saidas_sensib.fob_classic2(iii)=saidas.CLASSIC2.FOB.fob;
          saidas_sensib.C_PU_classic2(iii)=saidas.CLASSIC2.FOB.C_PU;
          saidas_sensib.Cop_PU_classic2(iii)=saidas.CLASSIC2.FOB.Cop_PU;
          saidas_sensib.C_PI_classic2(iii)=saidas.CLASSIC2.FOB.C_PI;
          saidas_sensib.Tho_classic2(:,iii)=saidas.CLASSIC2.HESIM.Tho;        
      end
          
      saidas_sensib.fob_QP1(iii)=saidas.SPLIT_QP.FOB(1).fob;
      saidas_sensib.fob_QP2(iii)=saidas.SPLIT_QP.FOB(2).fob;
      saidas_sensib.fob_QP3(iii)=saidas.SPLIT_QP.FOB(3).fob;
      saidas_sensib.fob_QP4(iii)=saidas.SPLIT_QP.FOB(4).fob;    

      
      saidas_sensib.C_PU_QP1(iii)=saidas.SPLIT_QP.FOB(1).C_PU;
      saidas_sensib.C_PU_QP2(iii)=saidas.SPLIT_QP.FOB(2).C_PU;
      saidas_sensib.C_PU_QP3(iii)=saidas.SPLIT_QP.FOB(3).C_PU;
      saidas_sensib.C_PU_QP4(iii)=saidas.SPLIT_QP.FOB(4).C_PU;    

      
      saidas_sensib.Cop_PU_QP1(iii)=saidas.SPLIT_QP.FOB(1).Cop_PU;
      saidas_sensib.Cop_PU_QP2(iii)=saidas.SPLIT_QP.FOB(2).Cop_PU;
      saidas_sensib.Cop_PU_QP3(iii)=saidas.SPLIT_QP.FOB(3).Cop_PU;
      saidas_sensib.Cop_PU_QP4(iii)=saidas.SPLIT_QP.FOB(4).Cop_PU;    

      
      saidas_sensib.C_PI_QP1(iii)=saidas.SPLIT_QP.FOB(1).C_PI;
      saidas_sensib.C_PI_QP2(iii)=saidas.SPLIT_QP.FOB(2).C_PI;
      saidas_sensib.C_PI_QP3(iii)=saidas.SPLIT_QP.FOB(3).C_PI;
      saidas_sensib.C_PI_QP4(iii)=saidas.SPLIT_QP.FOB(4).C_PI;    

      
      saidas_sensib.Tho_QP1(:,iii)=saidas.SPLIT_QP.HESIM(1).Tho;
      saidas_sensib.Tho_QP2(:,iii)=saidas.SPLIT_QP.HESIM(2).Tho;
      saidas_sensib.Tho_QP3(:,iii)=saidas.SPLIT_QP.HESIM(3).Tho;
      saidas_sensib.Tho_QP4(:,iii)=saidas.SPLIT_QP.HESIM(4).Tho;    
  end
 

endfunction


function [Diametro,xmax,DiametroNominal] = x2D(x,D,DN)
  // Função que determina diametros tendo como regra utilizar os maiores
  // diametros quando houver um mais de um diametro em um trecho.
  
  // Determinando numero de diametros
  N_D = length(D);
  // Determinando numero de tubulações
  S_PI = length(x)/N_D;
  // Iniciando matrizes X e Xmax
  X = zeros(S_PI,N_D);
  Xmax=X;
  // Montando matriz X
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; X(i,j)=x(aux); end, end
  // Montando vetores de diametros
  for i = 1:S_PI
      ix=find(X(i,:)>1e-2);
      Xmax(i,max(ix))=1;
      Diametro(i,1)=D(max(ix));
      DiametroNominal(i,1)=DN(max(ix));
  end
  // Desmontando a matriz Xmax
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; xmax(aux)=Xmax(i,j); end, end  
  
endfunction

function [Diametro,xmax,DiametroNominal] = x3D(x,D,DN)
  // Função que determina diametros tendo como regra utilizar os
  // diametros com maior fração
  
  // Determinando numero de diametros
  N_D = length(D);
  // Determinando numero de tubulações
  S_PI = length(x)/N_D;
  // Iniciando matrizes X e Xmax
  X = zeros(S_PI,N_D);
  Xmax=X;
  // Montando matriz X
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; X(i,j)=x(aux); end, end
  // Montando vetores de diametros
  for i = 1:S_PI
      [aux,ix]=max(X(i,:))
      ix = max([1;ix(:)]);
      Xmax(i,ix)=1;
      Diametro(i,1)=D(ix);
      DiametroNominal(i,1)=DN(ix);
  end
  // Desmontando a matriz Xmax
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; xmax(aux)=Xmax(i,j); end, end  
endfunction


function [x2,Dmin,xmin,Dmax,xmax,DNmin,DNmax] = x2Dsplit(x,D,DN)
  // Função que determina diametros e frações de trecho de tubulação

  // Determinando numero de diametros
  N_D = length(D);
  // Determinando numero de tubulações
  S_PI = length(x)/N_D;
  // Iniciando matrizes X, Xmax e Xmin
  X = zeros(S_PI,N_D);
  Xmax=X;
  Xmin=X;
  // Montando matriz X
  x(x>(1-1e-6))=1;
  x(x<1e-6)=0;
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; X(i,j)=x(aux); end, end
  x2=zeros(x);
  // Montando vetores de diametros
  for i = 1:S_PI
      [aux,ix]=gsort(X(i,:));
      Dmax(i,1)=D(ix(1));
      Dmin(i,1)=D(ix(2));
      xs=X(i,ix(1))+X(i,ix(2))
      xmax(i,1)=X(i,ix(1))./xs;
      xmin(i,1)=X(i,ix(2))./xs;
      DNmax(i,1)=DN(ix(1));
      DNmin(i,1)=DN(ix(2));
      x2((i-1)*N_D+ix(1))=X(i,ix(1))./xs;
      x2((i-1)*N_D+ix(2))=X(i,ix(2))./xs;
  end  
endfunction

function [saidas] = determinaInicial(parametros)
  //Calcula o balanço de massa da rede
  
  // Resgatando parametros
  uPS = parametros.uPS;
  uPD = parametros.uPD;
  K = parametros.K;
  NE = parametros.NE;
  N = parametros.N;
  E = parametros.E;
  S = parametros.S;
  e = parametros.e;
  QSI_PI = parametros.QSI_PI;
  QSI_HE = parametros.QSI_HE;
  QSI_PU = parametros.QSI_PU;
  // Calculando balanço de massa
  A = [K uPS uPD;E zeros(NE,2)];
  b = [zeros(N,1);e];
  x = A\b;
  // Determinando vazoes massicas dos elementos
  k = x(1:S,1);
  k_PI = QSI_PI*k;
  k_HE = QSI_HE*k;
  k_PU = QSI_PU*k;
  //Montando saídas
  saidas.k_PI=k_PI;
  saidas.k_PU=k_PU;
  saidas.k_HE=k_HE;  
endfunction

function [saidas] = determinaTradicional(saidas,parametros,f_sensib_i)
  
  // Acessando parametros  
  k_PI=saidas.k_PI;
  d = parametros.d;
  S_PI = parametros.S_PI;
  N_D = parametros.N_D;
  D = parametros.D;
  DN = parametros.DN;
  v_PI_max=parametros.v_PI_max;
    
  Dvmax = ((4.*k_PI.*((%pi.*v_PI_max.*d).^-1)).^0.5);
  
  
  coef=1.269;
  // Calculando os diametros estimados
  D0 = ((f_sensib_i).^0.164).*(coef.*(k_PI.^0.459)).*0.0254;
//  D0 = (39.37.*(k_PI.^0.5).*(d.^-0.5)).*0.0254;
  // Iniciando vetores e matrizes
  x0=zeros(S_PI*N_D,1);
  X0=zeros(S_PI,N_D);
  // Criando vetores de fracoes de comprimento
  for i=1:S_PI
    // Bucando diametros imediatamente maiores
    ix=find(D>D0(i)&D>Dvmax(i));
    // Determinado diametros imediatamente maiores
    if ~isempty(ix)
      D1(i)=D(ix(1));
      DN1(i)=DN(ix(1));
    else
      D1(i)=max(D);
      DN1(i)=max(DN);
      ix = N_D;
    end
    // Criando frações
    x0((i-1)*N_D+ix(1))=1;
    X0(i,ix(1))=1;
  end
  
  vPI = 4.*k_PI.*((d*%pi*D1.^2).^-1);
    

  saidas.D0=D0;
  saidas.D1=D1;
  saidas.x0=x0;
  saidas.X0=X0;
  
endfunction

function [saidas] = determinaTowler(saidas,parametros)
  
  // Acessando parametros  
  k_PI=saidas.k_PI;
  d = parametros.d;
  S_PI = parametros.S_PI;
  N_D = parametros.N_D;
  D = parametros.D;
  v_PI_max=parametros.v_PI_max;
    
  Dvmax = ((4.*k_PI.*((%pi.*v_PI_max.*d).^-1)).^0.5).*0.0254;

  coef=0.718;
  // Calculando os diametros estimados
  D0 = (39.37.*(k_PI.^0.5).*(d.^-0.5)).*0.0254;
  // Iniciando vetores e matrizes
  x0=zeros(S_PI*N_D,1);
  X0=zeros(S_PI,N_D);
  // Criando vetores de fracoes de comprimento
  for i=1:S_PI
    // Bucando diametros imediatamente maiores
    ix=find(D>D0(i)&D>Dvmax(i));
    // Determinado diametros imediatamente maiores
    if ~isempty(ix)
      D1(i)=D(ix(1));
    else
      D1(i)=max(D);
      ix = N_D;
    end
    // Criando frações
    x0((i-1)*N_D+ix(1))=1;
    X0(i,ix(1))=1;
  end
  
  //Montando saídas
  saidas.D0=D0;
  saidas.D1=D1;
  saidas.x0=x0;
  saidas.X0=X0;
  
endfunction


function [dadosB,parametrosB] = incluiBombaMinima(x0,k_PU,OPT,dados,parametros)
  //Inclui Bomba para Projeto Classico
  
  S_PI = parametros.S_PI;
  N_D=parametros.N_D;
  d = parametros.d;   
  // Acessando parametros  
  C2= OPT.C2;
  b2minimo = OPT.b2minimo;
  
  F_PU=max(C2*x0 - b2minimo);
  
  //Colocando curva da bomba
  dadosB=dados;
  parametrosB=parametros;
  dadosB.PUMPCURVE.coef3=[0;dados.PUMPCURVE.coef3];
  dadosB.PUMPCURVE.coef2=[0;dados.PUMPCURVE.coef2];
  dadosB.PUMPCURVE.coef1=[0;dados.PUMPCURVE.coef1];
  dadosB.PUMPCURVE.coef0=[F_PU;dados.PUMPCURVE.coef0];
  dadosB.PUMPCURVE.qrated=[k_PU./d;dados.PUMPCURVE.qrated];
  parametrosB.HOPT=[[0;0;0;F_PU] parametros.HOPT];
  parametrosB.q_PU_rated=[k_PU./d;parametros.q_PU_rated];  
  
endfunction

function [indice] = incluiBombaAdequada(x0,k_PU,OPT,dados,parametros)
  //Inclui Bomba para Projeto Classico
  
  // Acessando parametros
  g = 9.81;
  S_PI = parametros.S_PI;
  N_D=parametros.N_D;
  d = parametros.d;   

  // Acessando parametros  
  C2= OPT.C2;
  b2minimo = OPT.b2minimo;
  
  F_PU=max(C2*x0 - b2minimo);

  
  q_PU = k_PU./d; // in m³/s
  F_PU_aux=[];
  for i=1:length(dados.PUMPCURVE.coef3)
      F_PU_aux(i) = dados.PUMPCURVE.coef3(i)*(q_PU.^3)+...
             dados.PUMPCURVE.coef2(i)*(q_PU.^2)+...
             dados.PUMPCURVE.coef1(i)*(q_PU.^1)+...
             dados.PUMPCURVE.coef0(i)*(q_PU.^0);
  end
  [F_PU_s,k] = gsort(F_PU_aux,'c','i');
  ix = find(F_PU_s>=F_PU);
  F_PU_c = F_PU_s(ix(1));
  indice = find(F_PU_c==F_PU_aux)  
  
endfunction



function [dados2,parametros2]=ativaCurvaBomba(i,dados,parametros)
  //Ativa os parametros da bomba i
  
  // Iniciando parametros
  dados2=dados;
  parametros2 = parametros;
  //Colocando curva da bomba
  dados2.BOMBA.coef3=dados.PUMPCURVE.coef3(i);
  dados2.BOMBA.coef2=dados.PUMPCURVE.coef2(i);
  dados2.BOMBA.coef1=dados.PUMPCURVE.coef1(i);
  dados2.BOMBA.coef0=dados.PUMPCURVE.coef0(i);
  dados2.BOMBA.qrated=dados.PUMPCURVE.qrated(i);
  //Atualizando parametros
  parametros2.H = parametros.HOPT(:,i);
  parametros2.q_PU_rated = dados.PUMPCURVE.qrated(i);
endfunction


function saidas = determinaParametrosPre(massa,parametros)
  // Calcula os coeficientes e argumentos da otimização linear
  
  // Acessando parametros  
  k_PI=massa.k_PI;
  k_HE=massa.k_HE;
  N_D = parametros.N_D;  
  QSI_CIR = parametros.QSI_CIR;
  QSI_PI = parametros.QSI_PI;  
  QSI_HE = parametros.QSI_HE;
  dz = parametros.dz;
  S_PI = parametros.S_PI;
  N_D=parametros.N_D;
  S_PI=parametros.S_PI;
  S_HE=parametros.S_HE;
  ixHEPI=parametros.ixHEPI;
  ixHEPI2=parametros.ixHEPI2;
  D  = parametros.D;
  L  = parametros.L;
  d=parametros.d;
  
  S_CIR=size(QSI_CIR,1);
  
  // Determina heads
  [F_PI,F_PI_ac] = determinaHeadsLinhas(k_PI,parametros);
  [F_HE] = determinaHeadsTrocadores(k_HE,parametros);
  
  // Matriz de coeficientes das restri�oes de igualdade (me) x n
  C1=[];
  for i=1:S_PI
    C1(i,(1:N_D)+(i-1)*N_D) = ones(1,N_D);
  end
  
  // Vetor das restri�oes de igualdade (me) x 1    
  b1 = ones(S_PI,1);
    
  // Matriz de coeficientes das restricoes de desigualdade (md) x n
  F_PI2=[];
  Q=[];
  for i=1:S_PI
    F_PI2(i,(1:N_D)+(i-1)*N_D) = F_PI(i,:);
  end
  C2 = QSI_CIR*QSI_PI'*F_PI2;
      
  //Vetor das restri�oes de desigualdade (md) x n
  b2minimo = dz - QSI_CIR*QSI_HE'*F_HE - QSI_CIR*QSI_PI'*F_PI_ac;

  // Vetor de coeficientes da FOB 
  [Cop_PI,C_PI] = calcula_PI(parametros);
  r = calcula_r(parametros);
  C_PIa = C_PI';
  p = C_PIa(:) + Cop_PI(:);
    
  // Determina Matriz Q
  Q=zeros(S_PI*N_D,S_PI*N_D);
  aux = length(ixHEPI);
  for i=1:S_PI
    for k=1:N_D
      Q(k+(i-1)*N_D,k+(i-1)*N_D) = -1./S_PI;
//      if sum(ixHEPI==i)==0
//        Q(k+(i-1)*N_D,k+(i-1)*N_D) = -1./(0.001*aux+(S_PI-aux));
//      else
//        Q(k+(i-1)*N_D,k+(i-1)*N_D) = -0.001./(0.001*aux+(S_PI-aux));
//      end
    end
  end
    
  // Demais coeficientes e argumentos
  me = size([C1],1);
  md = size([C2],1);
  np =length(p);
  ci = zeros(np,1);
  cs = ones(np,1);
  x0max=zeros(np,1);
  for i=1:S_PI
    x0max(i*N_D)=1;
  end
  x0min=zeros(np,1);
  for i=1:S_PI
    x0min((i-1)*N_D+1)=1;
  end

  // Novas matrizes para variaveis de folga
  C1z1=eye(S_PI,S_PI);
  C1z2=zeros(S_PI,S_CIR);
  C2z1=zeros(S_CIR,S_PI);
  C2z2=eye(S_CIR,S_CIR);


  for i=1:S_PI
      for j=1:N_D
          v_PI(i,j)=4*(k_PI(i)/d)/(%pi*D(j)^2)
      end
  end
  
  dPdL100=100*(diag(L)^-1)*F_PI*9.8066*d./98066.5; //kgf/cm²/100m
  
  saidas.dPdL100=dPdL100;
  saidas.v_PI=v_PI;
  saidas.F_PI=F_PI;
  saidas.F_HE=F_HE;
  saidas.F_PI_ac=F_PI_ac;
  saidas.C_PI=C_PI;
  saidas.Cop_PI=Cop_PI;
  saidas.r=r;
  saidas.Q=Q;
  saidas.p=p;
  saidas.C1=C1;
  saidas.C2=C2;
  saidas.C =[C1;C2];
  saidas.Ckar =[[C1 C1z1 C1z2];[C2 C2z1 C2z2]];  
  saidas.C1z1 =C1z1;
  saidas.C1z2 =C1z2;
  saidas.C2z1 =C2z1;
  saidas.C2z2 =C2z2;
  saidas.b1=b1;
  saidas.b2minimo=b2minimo;
  saidas.ci=ci;
  saidas.cs=cs;
  saidas.me=me;
  saidas.p=p;
  saidas.x0min=x0min;
  saidas.x0max=x0max;
  
  
endfunction

function saidas = determinaParametrosPos(saidas,massa,parametros,k_PU_rated,f_sensib_i)
  // Calcula os coeficientes e argumentos da otimização linear
  
  // Acessando parametros  
  k_PI=massa.k_PI;
  k_PU=massa.k_PU;
  k_HE=massa.k_HE;
  N_D = parametros.N_D;  
  S_PI = parametros.S_PI;
  QSI_CIR = parametros.QSI_CIR;
  QSI_PI = parametros.QSI_PI;  
  QSI_HE = parametros.QSI_HE;
  dz = parametros.dz;
  N_D=parametros.N_D;
  S_PI=parametros.S_PI;
  S_HE=parametros.S_HE;
  ixHEPI=parametros.ixHEPI;
  ixHEPI2=parametros.ixHEPI2;
  F_HE=saidas.F_HE;
  F_PI=saidas.F_PI;
  F_PI_ac=saidas.F_PI_ac;
  r = saidas.r;
  d = parametros.d;
  
  // Determina heads
  [F_PU] = determinaHeadsBombas(k_PU,parametros);
  [F_PU_rated] = determinaHeadsBombas(k_PU_rated,parametros);
  
  //Vetor das restri�oes de desigualdade (md) x n
  b2 = F_PU + dz - QSI_CIR*QSI_HE'*F_HE - QSI_CIR*QSI_PI'*F_PI_ac;
    
  // Vetor de coeficientes da FOB
  [Cop_PU,I_PU] = calcula_PU(F_PU_rated,k_PU_rated,parametros,f_sensib_i);
  C_PU = r.*I_PU;
    
  saidas.F_PU=F_PU;
  saidas.I_PU=I_PU;
  saidas.C_PU=C_PU;
  saidas.Cop_PU=Cop_PU;
  saidas.b2=b2;
  saidas.b = [saidas.b1;saidas.b2];  
  
endfunction

function saidas = determinaRedePos(xopt,x,F_PIopt,parametros,massa,OPT,xopti,k_PU_rated,f_sensib_i)
  // Funcao que permite determinar as saidas do otimizador
  
  // Acessando parametros  
  k_PI=massa.k_PI;
  k_PU=massa.k_PU;
  k_HE=massa.k_HE;
  QSI_CIR=parametros.QSI_CIR;
  QSI_HE=parametros.QSI_HE;
  QSI_PI=parametros.QSI_PI;
  S_PI = parametros.S_PI;
  N_D = parametros.N_D;
  D = parametros.D;  
  DN = parametros.DN;  
  F_HE_ref=parametros.F_HE_ref;
  d = parametros.d;
  
  // Iniciando matriz X
  X = zeros(S_PI,N_D)
  Xopt = zeros(S_PI,N_D)
  
  [x,Dmin,xmin,Dmax,xmax,DNmin,DNmax] = x2Dsplit(x,D,DN);

  // Montando matriz X
  aux=0;
  for i=1:S_PI
      for j=1:N_D
          aux = aux+1;
          X(i,j)=x(aux);
          Xopt(i,j)=xopt(aux);
      end
  end

  //   Perda de carga faltante
  F_PIOR = zeros(S_PI,1);
  for i=1:S_PI
    for j=1:N_D
      F_PIOR(i,1)=F_PIOR(i,1)+F_PIopt(i,j).*(Xopt(i,j)-X(i,j));
    end
  end
  
  [F_PI,F_PI_ac] = determinaHeadsLinhas(k_PI,parametros);
  [F_PU] = determinaHeadsBombas(k_PU,parametros);
  [F_PU_rated] = determinaHeadsBombas(k_PU_rated,parametros);
  [F_HE] = determinaHeadsTrocadores(k_HE,parametros);

  // Vetor de coeficientes da FOB
  [Cop_PU_aux,I_PU,q_PU,q_PU_rated,F_PU_rated] = calcula_PU(F_PU_rated,k_PU_rated,parametros,f_sensib_i);
  [Cop_PU] = calcula_PU(F_PU,k_PU,parametros,f_sensib_i);
  
  [Cop_PI,C_PI] = calcula_PI(parametros);
  r = calcula_r(parametros);
  C_PIa = C_PI';
  C_PU = r.*I_PU;
  p = C_PIa(:) + Cop_PI(:);
  
  // Criando struct de variaveis de sa�da
  saidas.x = x;
  saidas.Xopt = Xopt;
  saidas.DNmax = DNmax;
  saidas.DNmin = DNmin;
  saidas.Dmax = Dmax;
  saidas.Dmin = Dmin;
  saidas.xmax = xmax;
  saidas.xmin = xmin;
  saidas.F_PI = F_PI;
  saidas.F_PU = F_PU;
  saidas.F_HE = F_HE;
  saidas.F_PIOR = F_PIOR;
  saidas.fob= p(:)'*x(:)+C_PU+Cop_PU;
  saidas.fobPEN= 0.5.*x(:)'*OPT.Q*x(:);
  saidas.C_PU= C_PU;
  saidas.Cop_PU= Cop_PU;
  saidas.C_PI= C_PIa(:)'*x(:);
  saidas.Cop_PI= Cop_PI(:)'*x(:);
  saidas.q_PU=k_PU./d;
  saidas.q_PU_rated=q_PU_rated;
  saidas.F_PU_rated=F_PU_rated;  
  
endfunction


function [F_HE] = determinaHeadsTrocadores(k_HE,parametros)
  // Função que calcula os heads dos elementos
  
  // Acessando parametros
  F_HE_ref = parametros.F_HE_ref;
  k_HE_ref = parametros.k_HE_ref;
  
  F_HE = F_HE_ref.*(k_HE./k_HE_ref).^1.8;
             
endfunction

function [F_PU] = determinaHeadsBombas(k_PU,parametros);
  // Função que calcula os heads dos elementos
  
  // Acessando parametros
  g = 9.81;
  L = parametros.L;
  d = parametros.d;
  H = parametros.H;
  
  q_PU = k_PU./d; // in m³/s
  F_PU = diag(H(1,:))*(q_PU.^3)+...
         diag(H(2,:))*(q_PU.^2)+...
         diag(H(3,:))*(q_PU.^1)+...
         diag(H(4,:))*(q_PU.^0);
         
endfunction

function [F_PI,F_PI_ac] = determinaHeadsLinhas(k_PI,parametros);
  // Função que calcula os heads dos elementos
  
  // Acessando parametros
  g = 9.81;
  L = parametros.L;
  d = parametros.d;
  ni = parametros.ni;
  ep = parametros.ep;
  LDac = parametros.LDac;
  N_D = parametros.N_D;  
  DIN = parametros.D;
  F_PI_ac = parametros.Fac;
  
  F_PI = [];           
  for j = 1:N_D
           
    D = DIN(j);
    
    A=Area(D);
    v=Velocidade(d,k_PI,A);
    Re=Reynolds(d,ni,D,v);
    LD = L.*(D.^-1);
    epD = ep.*(D.^-1);
    
    f=fatorDarcy(Re,epD);
    fT=fatorDarcy(1e8,epD);
    
    F_PIj = 0.5.*(f.*LD+fT.*LDac).*v.^2./g;
    F_PI = [F_PI F_PIj(:)];
  end
             
endfunction

function [r] = calcula_r(parametros)
  //Determina o fator de anualização
  
  //Constantes
  in = parametros.in;
  ny = parametros.ny;
  //Calculos
  f=(1+in)^ny;
  r = (in*f)/(f-1);

endfunction

function [Cop,C] = calcula_PI(F_PI,k_PI,parametros)
  // Determina custos tubos
  
  //Constantes
  alfah=parametros.alfa;
  betah=parametros.beta;
  //Calculos
  Cop=0;
  L = parametros.L;
  D = parametros.D;
  DN = parametros.DN;
  for i=1:length(L)
    for j=1:length(D)
      C(i,j) = 3.281^(betah+1)*L(i)*alfah*((DN(j)*0.0254)^betah);
    end
  end
endfunction
function Re=Reynolds(d,ni,D,v)
  //Determina o número de Reynolds
  Re = D.*abs(v).*d./ni;
endfunction
function A=Area(D)
  // Determina a área da seção interna do tubo
  A = (%pi.*D.^2)./4;
endfunction
function v=Velocidade(d,k,A)
  //Determina as velocidades médias
  v = k./A./d;
endfunction
function fD=fatorDarcy(Re,epD)
  // Determina o fator de atrito de Darcy
  A=(2.457.*log((0.27.*(epD)+(7.*(Re.^(-1))).^0.9).^(-1))).^16;
  B=(37530.*(Re.^(-1))).^16;  
  fD=8.*((8.*(Re.^(-1))).^12+(A+B).^(-1.5)).^(1./12);
endfunction

function [Cop,I,q_PU,q_PU_rated,F_PU_rated,Power] = calcula_PU(F_PU,k_PU,parametros,f_sensib_i)
  // Determina custos de bombas
  
  //Constantes
  g = 9.81;
  eta = parametros.eta;
  Nop = parametros.Nop;
  pc = parametros.pc;
  H = parametros.H;
  d = parametros.d;
  
  //Calculos
  q_PU=k_PU./d;
  [I,q_gpm,H_ft,Pot_HP] =price(k_PU,F_PU,d,eta);
  Power = k_PU*g*F_PU/(eta*1e3); //kW
  Cop = Power*Nop*pc*f_sensib_i;//USD/y
  q_PU_rated=q_PU;
  F_PU_rated=F_PU;
  
endfunction


function [parametros] = geraParametros(dados)
  // GERAPARAMETROS   Monta um struct com todos os parametros usados pelo
  //                  OTIMIZAREDE a partir de um struct de dados.
  //
  //   Sintaxe: [parametros] = GERAPARAMETROS(dados)
  //
  //   Os argumentos de entrada são:
  //
  //     dados: struct com os dados da simulacao
  //
  //   Os argumentos de saída são:
  //
  //     parametros: struct com os parametros
  //
  //   Desenvolvido por Jaime Souza em 11 de outubro de 2010
  
  
  D = dados.PIPE.DIN./1000; //diametros possiveis
  DN = dados.PIPE.DN; //diametros possiveis
  
  S_PU = size(dados.BOMBA.tag,1);
  S_PI = size(dados.LINHA.tag,1);
  S_HE = size(dados.EQUIP.tag,1);
  S = S_PU+S_PI+S_HE;
  N = length(unique([dados.REDE.ind_noh_montante;dados.REDE.ind_noh_jusante]));
  N_D = size(dados.PIPE.DIN,1);  
  N_E = length(dados.VERTICE.ind_vertice);
  
  K = zeros(N,S);
  for i=1:S
    ix = find(dados.REDE.ind_aresta==i);
    i_Noh1=dados.REDE.ind_noh_montante(ix);
    i_Noh2=dados.REDE.ind_noh_jusante(ix);
    K(i_Noh1,ix) = -1;
    K(i_Noh2,ix) =  1;
  end
  
  QSI_PI = zeros(S_PI,S);
  for i=1:S_PI
    ix = dados.LINHA.ind(i);
    QSI_PI(i,ix)=1;
  end
  
  QSI_PU = zeros(S_PU,S);
  for i=1:S_PU
    ix = dados.BOMBA.ind(i);
    QSI_PU(i,ix)=1;
  end
    
  QSI_HE = zeros(S_HE,S);
  for i=1:S_HE
    ix = dados.EQUIP.ind(i);
    QSI_HE(i,ix)=1;
    ix = find(K(:,ix)==1);
    ix = find(K(ix,:)==-1);
    ixHE(i)=ix;
  end
  
  NE = S_HE;
  E = QSI_HE;
  
  uPS = ones(N,1)-sign((abs(K)+K)*ones(S,1));
  uPD = ones(N,1)-sign((abs(K)-K)*ones(S,1));
  zPS = dados.VERTICE.z(1);
  zPD = dados.VERTICE.z(2);
  pPS = dados.VERTICE.esp(1);
  pPD = dados.VERTICE.esp(2);
  
  I_SS = eye(S,S);
  I_NENE = eye(NE,NE);
  Z_S2 = zeros(S,2);
  Z_NE2 = zeros(NE,2);
  Z_SS = zeros(S,S);
  Z_NE = zeros(S,NE);

  Z_NNE = zeros(N,NE);
  A = [I_SS Z_S2];  
  B = inv([K uPS uPD ; E Z_NE2]);
  C = [Z_NNE;I_NENE];
            
  QSI_CIR=[A*sign(B)*C]';

  
  H = zeros(4,0);
  for i=1:length(dados.BOMBA.ind)
    H(1,i)=dados.BOMBA.coef3(i);
    H(2,i)=dados.BOMBA.coef2(i);
    H(3,i)=dados.BOMBA.coef1(i);
    H(4,i)=dados.BOMBA.coef0(i);
  end
  
  HOPT = zeros(4,0);
  for i=1:length(dados.PUMPCURVE.ind)
    HOPT(1,i)=dados.PUMPCURVE.coef3(i);
    HOPT(2,i)=dados.PUMPCURVE.coef2(i);
    HOPT(3,i)=dados.PUMPCURVE.coef1(i);
    HOPT(4,i)=dados.PUMPCURVE.coef0(i);
  end

  parametros.ixHE = ixHE;
  parametros.NE = NE;
  parametros.zPS = zPS;
  parametros.zPD = zPD;
  parametros.pPS = pPS;
  parametros.pPD = pPD;
    
  parametros.HOPT = HOPT;
  parametros.QSI_CIR = QSI_CIR;
  parametros.uPS = uPS;
  parametros.uPD = uPD;
  
  parametros.pipeTag=dados.PIPE.tag;
  parametros.D = D;
  parametros.DN = DN;
  parametros.N_D = N_D;  
  parametros.N = N;
  parametros.S = S;
  parametros.K = K;  
  parametros.H = H;  
  parametros.E = E;  
  parametros.e = dados.EQUIP.k;  
  parametros.F_HE_ref=dados.EQUIP.F;
  parametros.k_HE_ref=dados.EQUIP.k;
  parametros.S_PI = S_PI;
  parametros.S_PU = S_PU;
  parametros.S_HE = S_HE;
  parametros.N_HY = size(QSI_CIR,1);
  parametros.QSI_PI = QSI_PI;
  parametros.QSI_PU = QSI_PU;
  parametros.QSI_HE = QSI_HE;
  parametros.ep = dados.LINHA.e./1e6;
  parametros.ni = dados.FLUIDO.visc./1000;
  parametros.d = dados.FLUIDO.dens;
  parametros.L = dados.LINHA.L;
  parametros.D = dados.PIPE.DIN./1000;
  parametros.LDac = dados.LINHA.LDac;
  parametros.Fac = dados.LINHA.Fac;
  parametros.dz = (parametros.zPS+1e5.*parametros.pPS./(parametros.d*9.81))-(parametros.zPD+1e5.*parametros.pPD./(parametros.d*9.81));
     
  
  for i=1:size(dados.EQUIP.tag,1)
    ix = find(dados.HE_TASK.tag==dados.EQUIP.tag(i));
    parametros.mh(i,1)=dados.HE_TASK.mh(ix);
    parametros.Cph(i,1)=dados.HE_TASK.Cph(ix);
    parametros.Thi(i,1)=dados.HE_TASK.Thi(ix);
    parametros.Tho_sp(i,1)=dados.HE_TASK.Tho_sp(ix);
    parametros.Tco_sp(i,1)=dados.HE_TASK.Tco_sp(ix);
    parametros.mc_sp(i,1)=dados.HE_TASK.mc_sp(ix);
    ix = find(dados.HE_DESIGN.tag==dados.EQUIP.tag(i));
    parametros.A(i,1) =dados.HE_DESIGN.A(ix);
    parametros.hi_sp(i,1) =dados.HE_DESIGN.hi_sp(ix);
    parametros.he_sp(i,1) =dados.HE_DESIGN.he_sp(ix);
    parametros.Rfi(i,1) =dados.HE_DESIGN.Rfi(ix);
    parametros.Rfe(i,1) =dados.HE_DESIGN.Rfe(ix);
    parametros.kt(i,1) =dados.HE_DESIGN.kt(ix);
    parametros.Dti(i,1) =dados.HE_DESIGN.Dti(ix);
    parametros.Dte(i,1) =dados.HE_DESIGN.Dte(ix);
    parametros.ic(i,1) =dados.HE_DESIGN.ic(ix);
    parametros.it(i,1) =dados.HE_DESIGN.it(ix);
  end
  parametros.Cpc = dados.FLUIDO.cp;
  parametros.Tci = dados.FLUIDO.temp;
  parametros.q_PU_rated = dados.BOMBA.qrated;
  parametros.q_PU_OPT_rated = dados.PUMPCURVE.qrated;
  
  
  ixHEPI=zeros(S_HE,1);
  ixHEPI2=zeros(S_HE,1);
  MauxHE=K*QSI_HE';
  MauxPI=K*QSI_PI';
  for i=1:S_HE
    aux2=find(MauxHE(:,i)==1);
    ixHEPI(i,1)=find(MauxPI(aux2,:)==-1);
    ixHEPI2(i,1)=find(K(aux2,:)==-1);
  end
  parametros.ixHEPI = ixHEPI;
  parametros.ixHEPI2 = ixHEPI2;
  
  parametros.alfa=dados.PIPECOST.alfa;
  parametros.beta=dados.PIPECOST.beta;
  
  parametros.eta=dados.PUMPCOST.eta
  parametros.Nop=dados.PUMPCOST.Nop;
  parametros.pc=dados.PUMPCOST.pc;
  parametros.in=dados.PUMPCOST.in;
  parametros.ny=dados.PUMPCOST.ny;  
  
 endfunction