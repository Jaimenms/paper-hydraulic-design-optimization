function [saidas,x]=simulaRede(dados_sim,x0)
  // SIMULAREDE    Simula uma rede de escoamento de fluido incompressível com
  //               qualquer topologia (redes cíclicas ou acíclicas) dotadas ou
  //               não de equipamentos ou elementos geradores ou consumidores de
  //               momento como bombas, válvulas ou acidentes. Esses equipamentos
  //               ou elementos são modelados por um polinômio que relaciona a vazão
  //               através do mesmo e a variação do head entre o nó a montante e 
  //               o nó a jusante do elemento.
  //               As variáveis da rede são a pressão em bar e a vazão externa de
  //               cada nó em kg/s e a vazão das arestas (linhas ou equipamentos),
  //               que são organizadas na forma de um vetor x.
  //
  //   Sintaxe: [saidas,x,saidas0,x0] = SIMULAREDE(dados_sim,x0,cenario)
  //
  //
  //   Os argumentos de entrada são:
  //
  //     dados_sim: struct com os dados_sim da simulacao
  //     x0: vetor com as estimativas iniciais da simulacao (opcional)
  //     cenario: indice do cenario
  //
  //   Os argumentos de saída são:
  //
  //     saidas: struct com as saidas da simulacao
  //     x:      vetor com as variaveis da simulacao
  //
  //
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011

  // (1) Tratamentos iniciais  
  warning('off')

  // (2) Gerando struct com parametros_sim a partir dos dados_sim
  parametros_sim = geraParametros_sim(dados_sim);

  if ~exists('x0'), x0=modelolaminar(parametros_sim);  end
  if isempty(x0), x0=modelolaminar(parametros_sim);  end
  
  // (5) Resolvendo sistema algébrico não-linear
  x=solver_sea('modelorigoroso',parametros_sim,x0);
  
  // (6) Calculando saídas
  [F,saidas]=modelorigoroso(parametros_sim,x);
  
endfunction

function [parametros_sim] = geraParametros_sim(dados_sim)
  // GERAPARAMETROS   Monta um struct com todos os parametros_sim usados pelo
  //                  SIMULAREDE a partir de um struct de dados_sim.
  //
  //   Sintaxe: [parametros_sim] = GERAPARAMETROS(dados_sim)
  //
  //   Os argumentos de entrada são:
  //
  //     dados_sim: struct com os dados_sim da simulacao
  //
  //   Os argumentos de saída são:
  //
  //     parametros_sim: struct com os parametros_sim
  //
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011
  
  
  // Identificando Diametros Internos
  N_D   = length(dados_sim.OPT_OPCOES_LINHA.DIN);
  S_PI   = length(dados_sim.REDE_ARESTA_LINHA.ind);
  dados_sim.REDE_ARESTA_LINHA.DIN = zeros(S_PI,1);
  for i=1:S_PI
      for j=1:N_D
          if (dados_sim.REDE_ARESTA_LINHA.DIA(i)==dados_sim.OPT_OPCOES_LINHA.tag(j) | dados_sim.REDE_ARESTA_LINHA.DIA(i)==dados_sim.OPT_OPCOES_LINHA.DN(j))
              dados_sim.REDE_ARESTA_LINHA.DIN(i) = dados_sim.OPT_OPCOES_LINHA.DIN(j);
          end
          if (dados_sim.REDE_ARESTA_LINHA.DIAsplit(i)==dados_sim.OPT_OPCOES_LINHA.tag(j) | dados_sim.REDE_ARESTA_LINHA.DIAsplit(i)==dados_sim.OPT_OPCOES_LINHA.DN(j))
              dados_sim.REDE_ARESTA_LINHA.DINsplit(i) = dados_sim.OPT_OPCOES_LINHA.DIN(j);
          end
      end
  end
  

  // Identificando Dados das Bombas
  N_Curvas   = length(dados_sim.OPT_CURVA.ind);
  S_PU   = length(dados_sim.REDE_ARESTA_BOMBA.ind);
  dados_sim.REDE_ARESTA_BOMBA.coef3  = zeros(S_PU,1);
  dados_sim.REDE_ARESTA_BOMBA.coef2  = zeros(S_PU,1);
  dados_sim.REDE_ARESTA_BOMBA.coef1  = zeros(S_PU,1);
  dados_sim.REDE_ARESTA_BOMBA.coef0  = zeros(S_PU,1);
  dados_sim.REDE_ARESTA_BOMBA.qrated = zeros(S_PU,1);
  dados_sim.REDE_ARESTA_BOMBA.eta    = zeros(S_PU,1);
  for i=1:S_PU
      for j=1:N_Curvas
          if (dados_sim.REDE_ARESTA_BOMBA.curve(i)==dados_sim.OPT_CURVA.tag(j))
              dados_sim.REDE_ARESTA_BOMBA.coef3(i)  = dados_sim.OPT_CURVA.coef3(j);
              dados_sim.REDE_ARESTA_BOMBA.coef2(i)  = dados_sim.OPT_CURVA.coef2(j);
              dados_sim.REDE_ARESTA_BOMBA.coef1(i)  = dados_sim.OPT_CURVA.coef1(j);
              dados_sim.REDE_ARESTA_BOMBA.coef0(i)  = dados_sim.OPT_CURVA.coef0(j);
              dados_sim.REDE_ARESTA_BOMBA.qrated(i) = dados_sim.OPT_CURVA.qrated(j);
              dados_sim.REDE_ARESTA_BOMBA.eta(i)    = dados_sim.OPT_CURVA.eta(j);
          end
      end
  end

  // (1) Calculos Iniciais
  S_PU = size(dados_sim.REDE_ARESTA_BOMBA.tag,1); //numero de arestas de bombas
  S_PI = size(dados_sim.REDE_ARESTA_LINHA.tag,1); //numero de arestas de tubos
  S_HE = size(dados_sim.REDE_ARESTA_TROC.tag,1); //numero de arestas de trocadores
  S = S_PU+S_PI+S_HE; //numero total de arestas
  N_E = length(dados_sim.REDE_VERTICE.ind_vertice); //numero de especificações
  N = length(unique([dados_sim.REDE.ind_noh_montante;dados_sim.REDE.ind_noh_jusante])); //numero de nós
  
  // (2) Montando a matriz de incidência
  K = zeros(N,S);
  for i=1:S
    ix = find(dados_sim.REDE.ind_aresta==i);
    i_Noh1=dados_sim.REDE.ind_noh_montante(ix);
    i_Noh2=dados_sim.REDE.ind_noh_jusante(ix);
    K(i_Noh1,ix) = -1;
    K(i_Noh2,ix) =  1;
  end
  
  // (3) Montando as matrizes seletoras de arestas
  QSI_PI = zeros(S_PI,S);
  for i=1:S_PI
    ix = dados_sim.REDE_ARESTA_LINHA.ind(i);
    QSI_PI(i,ix)=1;
  end  
  QSI_PU = zeros(S_PU,S);
  for i=1:S_PU
    ix = dados_sim.REDE_ARESTA_BOMBA.ind(i);
    QSI_PU(i,ix)=1;
  end
  QSI_HE = zeros(S_HE,S);
  for i=1:S_HE
    ix = dados_sim.REDE_ARESTA_TROC.ind(i);
    QSI_HE(i,ix)=1;
  end
  
  // (4) Montando a matriz de coeficientes
  H = zeros(4,0);
  for i=1:length(dados_sim.REDE_ARESTA_BOMBA.ind)
    H(1,i)=dados_sim.REDE_ARESTA_BOMBA.coef3(i);
    H(2,i)=dados_sim.REDE_ARESTA_BOMBA.coef2(i);
    H(3,i)=dados_sim.REDE_ARESTA_BOMBA.coef1(i);
    H(4,i)=dados_sim.REDE_ARESTA_BOMBA.coef0(i);
  end
    
  // (5) Montando a matriz seletora de especificações
  E = zeros(N,2*N+S);  e = zeros(N,1);  z = zeros(N,1);
  for i = 1:N
    ix = find(dados_sim.REDE_VERTICE.ind_vertice==i);
    if ~isempty(ix)
      if dados_sim.REDE_VERTICE.tipo(ix) == 'P'
        E(i,S+i) = 1;
      elseif dados_sim.REDE_VERTICE.tipo(ix) == 'W'
        E(i,S+N+i) = 1;
      end
      e(i,1)=dados_sim.REDE_VERTICE.esp(ix);
      z(i,1)=dados_sim.REDE_VERTICE.z(ix);
    else
      E(i,S+N+i) = 1;
    end
  end
  
  // (6) Criando parametros_sim
  parametros_sim.N         = N;
  parametros_sim.S         = S;
  parametros_sim.K         = K;  
  parametros_sim.H         = H;  
  parametros_sim.E         = E;  
  parametros_sim.e         = e;
  parametros_sim.z         = z;
  parametros_sim.S_PI      = S_PI;
  parametros_sim.S_PU      = S_PU;
  parametros_sim.S_HE      = S_HE;
  parametros_sim.K_PI      = K*QSI_PI';
  parametros_sim.K_PU      = K*QSI_PU';
  parametros_sim.K_HE      = K*QSI_HE';
  parametros_sim.QSI_PI    = QSI_PI;
  parametros_sim.QSI_PU    = QSI_PU;
  parametros_sim.QSI_HE    = QSI_HE;
  parametros_sim.ni        = dados_sim.REDE_FLUIDO.visc./1000;
  parametros_sim.d         = dados_sim.REDE_FLUIDO.dens;
  parametros_sim.F_HE_ref  = dados_sim.REDE_ARESTA_TROC.F;
  parametros_sim.k_HE_ref  = dados_sim.REDE_ARESTA_TROC.k;
  parametros_sim.ep        = dados_sim.REDE_ARESTA_LINHA.e./1e6;
  parametros_sim.L         = dados_sim.REDE_ARESTA_LINHA.L;
  parametros_sim.D         = dados_sim.REDE_ARESTA_LINHA.DIN./1000;
  parametros_sim.LDac      = dados_sim.REDE_ARESTA_LINHA.LDac;
  parametros_sim.Fac       = dados_sim.REDE_ARESTA_LINHA.Fac;
  parametros_sim.FacHE     = dados_sim.REDE_ARESTA_TROC.Fac;
  
  if isfield(dados_sim.REDE_ARESTA_LINHA,'xsplit')
      parametros_sim.xsplit=dados_sim.REDE_ARESTA_LINHA.xsplit;
  else
      parametros_sim.xsplit=zeros(parametros_sim.D);
  end

  if isfield(dados_sim.REDE_ARESTA_LINHA,'DINsplit')
      parametros_sim.Dsplit=dados_sim.REDE_ARESTA_LINHA.DINsplit./1000;
  else
      parametros_sim.Dsplit=parametros_sim.D;
  end
  
endfunction

function x=modelolaminar(parametros_sim)
  // MODELOLAMINAR     Calcula as variaveis da rede utilizando como premissa o
  //                   escoamento laminar. Desse modo o problema de simulação
  //                   da rede de escoamento é simplificado a apenas um siste-
  //                   algébrico linear.
  //
  //   Sintaxe: x = modelolaminar(parametros_sim)
  //
  //   Os argumentos de entrada são:
  //   
  //      parametros_sim: struct com todos os parametros_sim necessarios
  //
  //   Os argumentos de saída são:
  //
  //     x:      vetor com as variaveis da simulacao
  //
  //
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011
  
  
  // (1) Acessando os parametros_sim
  K        = parametros_sim.K;        //matriz de incidencia da rede
  H        = parametros_sim.H;        //matriz de coeficientes das bombas
  N        = parametros_sim.N;        //numero de nós
  S        = parametros_sim.S;        //numero de arestas
  E        = parametros_sim.E;        //matriz de seleção de especificações
  e        = parametros_sim.e;        //vetor de especificações
  z        = parametros_sim.z;        //vetor de cotas dos vértices
  ni       = parametros_sim.ni;       //viscosidade dinamica (Pa.s)
  d        = parametros_sim.d;        //densidade (kg/m³)
  L        = parametros_sim.L;        //comprimento (m)
  D        = parametros_sim.D;        //diametro interno (m)
  QSI_PI   = parametros_sim.QSI_PI;   //matriz de seleção de arestas de tubos
  QSI_PU   = parametros_sim.QSI_PU;   //matriz de seleção de arestas de bombas
  QSI_HE   = parametros_sim.QSI_HE;   //matriz de seleção de arestas de trocadores
  F_HE_ref = parametros_sim.F_HE_ref; //vetor de perdas de carga dos trocadores na condição de projeto (m)
  k_HE_ref = parametros_sim.k_HE_ref; //vetor de vazões mássica dos trocadores na condição de projeto (kg/s)
  S_PI     = parametros_sim.S_PI;     //numero de arestas de tubos
  S_PU     = parametros_sim.S_PU;     //numero de arestas de bombas
  S_HE     = parametros_sim.S_HE;     //numero de arestas de trocadores
  K_PI     = parametros_sim.K_PI;     //matriz de incidência de arestas de tubos
  K_HE     = parametros_sim.K_HE;     //matriz de incidência de trocadores
  K_PU     = parametros_sim.K_PU;     //matriz de incidência de bombas
  xsplit   = parametros_sim.xsplit;   //fracao de tubo com diametro igual a Dsplit (-)
  Dsplit   = parametros_sim.Dsplit;   //diametro do split (m)
  
  // (2) Definindo as constantes
  g = 9.80665;                    //aceleracao da gravidade (m/s²)
  fatorEsc = 1e-5;                //fator de conversão de Pa para bar  
    
  // (3) Determinando as diferenças de pressão estática
  dPz_PI = K_PI'*(z.*d.*g);       //vetor de diferenças de pressão estatica para tubos (Pa)
  dPz_HE = K_HE'*(z.*d.*g);       //vetor de diferenças de pressão estatica para trocadores (Pa)  
  dPz_PU = K_PU'*(z.*d.*g);       //vetor de diferenças de pressão estatica para bombas (Pa)
  

  
  // (4) Determinando os coeficientes das equações de momento considerando laminar
  L1 = L.*(1-xsplit);                           // comprimento do trecho com diametro D1 (m)
  D1 = D;                                       // diametro D1 (m)
  L2 = L.*(  xsplit);                           // comprimento do trecho com D2 (m)
  D2 = Dsplit;                                  // diametro D2 (m)
  F_PI1=diag(128.*ni.*L1.*(D1.^4.*%pi.*d).^-1); // fator F para trecho com diametro D1
  F_PI2=diag(128.*ni.*L2.*(D2.^4.*%pi.*d).^-1); // fator F para trecho com diametro D2
  F_PI=F_PI1+F_PI2;                             // fator F para tubulação
  F_HE=diag(d.*g.*F_HE_ref.*(k_HE_ref.^-1));    // fator F para trocador
  F_PU=H($,:);                                  // fator F para bomba
  
  // (5) Montando as matrizes de coeficientes do modelo
  BM  =[K zeros(N,N) eye(N,N)];                       // balanço de massa
  BEM1=[(fatorEsc.*F_PI)*QSI_PI K_PI' zeros(S_PI,N)]; // balanço de momento para tubulação
  BEM2=[(fatorEsc.*F_HE)*QSI_HE K_HE' zeros(S_HE,N)]; // balanço de momento para trocador
  BEM3=[zeros(S_PU,S_PU)*QSI_PU K_PU' zeros(S_PU,N)]; // balanço de momento para bomba
  BEM =[BEM1 ; BEM2; BEM3];                           // balanços de momento
  A=[BM;BEM;E];                                       //matriz de coeficientes
      
  // (6) Montando vetor de coeficientes do sistema não-homogêneo
  C=[zeros(N,1);                      // coeficientes dos balanços de massa
   -fatorEsc.*dPz_PI;                 // coeficientes dos balanços de momento para tubulação
   -fatorEsc.*dPz_HE;                 // coeficientes dos balanços de momento para trocador
   fatorEsc.*(-dPz_PU+d.*g.*F_PU);    // coeficientes dos balanços de momento para bomba
    e];                               // especificações
  
  // (7) Resolvendo o sistema de equações
  x=A\C;    // sistema algébrico linear não-homogêneo
  
endfunction

function [F,saidas]=modelorigoroso(parametros_sim,x)
  // MODELORIGOROSO     Calcula o vetor de residuos do modelo de escoamento
  //                    incompressível em uma rede de dutos descrita através
  //                    de um sistema algébrico não-linear.
  //
  //   Sintaxe: [F,saidas] = modelorigoroso(parametros_sim,x)
  //
  //   Os argumentos de entrada são:
  //   
  //      parametros_sim: struct com todos os parametros_sim necessarios
  //      x:          vetor com as estimativas das variaveis da simulacao
  //
  //   Os argumentos de saída são:
  //
  //     saidas:      struct com as saidas da simulação
  //
  //
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011
  
    // Funções acessórias
    function Re=Reynolds(d,ni,D,v)//Determina o número de Reynolds
      Re = D.*abs(v).*d./ni;
    endfunction
    function A=Area(D)//Determina a área da seção interna do duto
        A = (%pi.*D.^2)./4;
    endfunction
    function v=Velocidade(d,k,A)//Determina a velocidade média do fluido
      v = k./A./d;
    endfunction
    function fD=fatorDarcy(Re,epD)//Determina o fator de atrito de Darcy
      A=(2.457.*log((0.27.*(epD)+(7.*(Re.^(-1))).^0.9).^(-1))).^16;
      B=(37530.*(Re.^(-1))).^16;  
      fD=8.*((8.*(Re.^(-1))).^12+(A+B).^(-1.5)).^(1./12);
    endfunction
    function f = cargaBombas(H,k,d)//Determina o head das bombas
      k = abs(k);
      q = k./d;
      f = diag(H(1,:))*(q.^3)+diag(H(2,:))*(q.^2)+diag(H(3,:))*(q.^1)+diag(H(4,:))*(q.^0);
    endfunction

  // (1) Acessando os parametros_sim
  K = parametros_sim.K; //matriz de incidencia da rede
  H = parametros_sim.H; //matriz de coeficientes das bombas
  N = parametros_sim.N; //numero de nós
  S = parametros_sim.S; //numero de arestas
  E = parametros_sim.E; //matriz de seleção de especificações
  e = parametros_sim.e; //vetor de especificações
  z = parametros_sim.z; //vetor de cotas dos vértices
  ni = parametros_sim.ni; //viscosidade dinamica (Pa.s)
  d = parametros_sim.d; //densidade (kg/m³)
  L = parametros_sim.L; //comprimento (m)
  D = parametros_sim.D; //diametro interno (m)
  QSI_PI = parametros_sim.QSI_PI; //matriz de seleção de arestas de tubos
  QSI_PU = parametros_sim.QSI_PU; //matriz de seleção de arestas de bombas
  QSI_HE = parametros_sim.QSI_HE; //matriz de seleção de arestas de trocadores
  F_HE_ref = parametros_sim.F_HE_ref; //vetor de perdas de carga dos trocadores na condição de projeto (m)
  k_HE_ref = parametros_sim.k_HE_ref; //vetor de vazões mássica dos trocadores na condição de projeto (kg/s)  
  S_PI = parametros_sim.S_PI; //numero de arestas de tubos
  S_PU = parametros_sim.S_PU; //numero de arestas de bombas
  S_HE = parametros_sim.S_HE; //numero de arestas de trocadores
  K_PI = parametros_sim.K_PI; //matriz de incidência de arestas de tubos
  K_HE = parametros_sim.K_HE; //matriz de incidência de trocadores
  K_PU = parametros_sim.K_PU; //matriz de incidência de bombas
  ep = parametros_sim.ep; //vetor de rugosidade dos tubos (m)
  FacHE = parametros_sim.FacHE; //vetor de perdas de carga localizadas no trocadores (m)
  Fac = parametros_sim.Fac; //vetor de perdas de carga localizadas (m)
  LDac =parametros_sim.LDac; //vetor de comprimentos equivalentes de acidentes (m)
  xsplit=parametros_sim.xsplit;
  Dsplit=parametros_sim.Dsplit;

  // (2) Definindo as constantes
  g = 9.80665; //aceleracao da gravidade (m/s²)
  fatorEsc = 1e-5; //fator de conversão de Pa para bar
  
  // (3) Separando variaveis de vazão, pressão e vazão externa
  k = x(1:S,:);
  p = x(S+(1:N),:);
  w = x(S+N+(1:N),:);

  // (4) Separando variaveis de vazãopor tipo de elemento
  k_PI = QSI_PI*k;
  k_PU = QSI_PU*k;
  k_HE = QSI_HE*k;

  // Separando para levar em conta 2 diametros diferentes em um mesmo trecho
  L1 = L.*(1-xsplit);  D1 = D;
  L2 = L.*(  xsplit);  D2 = Dsplit;

  // (5) Definindo modificações para comportar multiplas colunas de x
  n = size(x,2); //numero de colunas de x
  uns = ones(1,n); //vetor auxiliar usado para replicar colunas
  z = z(:)*uns; //ampliando vetor de cotas
  L1 = L1(:)*uns; //ampliando vetor de comprimentos
  D1 = D1(:)*uns; //ampliando vetor de diametros
  L2 = L2(:)*uns; //ampliando vetor de comprimentos
  D2 = D2(:)*uns; //ampliando vetor de diametros
  ep = ep(:)*uns; //ampliando vetor de rugosidades
  
  // (6) Determinando variaveis relevantes
  A1=Area(D1); //area (m²)
  A2=Area(D2); //area (m²)
  v1=Velocidade(d,k_PI,A1); //velocidade (m/s)
  v2=Velocidade(d,k_PI,A2); //velocidade (m/s)
  Re1=Reynolds(d,ni,D1,v1); //numero de Reynolds
  Re2=Reynolds(d,ni,D2,v2); //numero de Reynolds
  f1=fatorDarcy(Re1,ep.*(D1.^-1)); //fator de atrito
  f2=fatorDarcy(Re2,ep.*(D2.^-1)); //fator de atrito
  fT1=fatorDarcy(1e8,ep.*(D1.^-1)); //fator de atrito turbulento
  fT2=fatorDarcy(1e8,ep.*(D2.^-1)); //fator de atrito turbulento


  // (7) Determinando combinacões de variáveis
  dg = d.*g;
  zdg = z.*dg;
  LD1=L1.*(D1.^-1);
  LD2=L2.*(D2.^-1);
  
  // (8) Determinando diferenças de pressões estáticas
  dPz_PI = K_PI'*(zdg);  
  dPz_PU = K_PU'*(zdg);  
  dPz_HE = K_HE'*(zdg);
  
  // (9) Determinando quedas de pressão nos elementos
  dP_PU = -dg.*(cargaBombas(H,k_PU,d)); //bombas
  dP_PI1 = 0.5.*d.*(f1.*LD1+fT1.*LDac*uns).*abs(v1).*v1; //tubos
  dP_PI2 = 0.5.*d.*(f2.*LD2+fT2.*LDac*uns).*abs(v2).*v2; //tubos
  dP_PI =dP_PI1+dP_PI2+dg.*Fac(:)*uns;
  dP_HE = dg.*F_HE_ref.*(k_HE./k_HE_ref).^1.8+dg.*FacHE(:)*uns; //trocadores

  F_PI1 = 0.5.*(g.^-1).*f1.*(D1.^-1).*abs(v1).*v1.*100; //tubos
  F_PI2 = 0.5.*(g.^-1).*f2.*(D2.^-1).*abs(v2).*v2.*100; //tubos
  
  // (10) Determinando vetores de residuos
  F1 = (K*k)+w; //balanço de massa
  F2 = (K_PI'*p)+fatorEsc.*(dP_PI+dPz_PI); //balanço de momento tubos
  F3 = (K_HE'*p)+fatorEsc.*(dP_HE+dPz_HE); //balanço de momento de trocadores
  F4 = (K_PU'*p)+fatorEsc.*(dP_PU+dPz_PU); //balanço de momento de bombas
  F5 = (E*x)-e; //equações de especificações
  F=[F1;F2;F3;F4;F5];
  
  
  // (11) Determinando struct com saidas
  saidas.k   = k;
  saidas.w   = w;
  saidas.p   = p;
  saidas.k_PI = k_PI;
  saidas.k_PU = k_PU;
  saidas.k_HE = k_HE;
  saidas.dPdL100 = 100.*dP_PI.*((L).^-1);
  saidas.F_PI1 = F_PI1;
  saidas.F_PI2 = F_PI2;
  saidas.F_PI = F_PI1+F_PI2;
  saidas.F_PU = dP_PU./dg;
  saidas.F_HE = dP_HE./dg;
  saidas.p_PI_1=(K_PI==-1)'*p;
  saidas.p_PI_2=(K_PI==+1)'*p;
  saidas.p_PU_1=(K_PU==-1)'*p;
  saidas.p_PU_2=(K_PU==+1)'*p;
  saidas.p_HE_1=(K_HE==-1)'*p;
  saidas.p_HE_2=(K_HE==+1)'*p;  
  saidas.v1=v1;  
  saidas.v2=v2;  

endfunction

// 
function [X1OUT]=solver_sea(FUN,dados_sim,X1)
  // SOLVER_SEA     Método de Newton-Raphson para solução do sistema de equações não-lineares
  //
  //   Sintaxe: [X1OUT]=solver_sea(FUN,dados_sim,X1)
  //
  //   Os argumentos de entrada são:
  //   
  //      FUN:      string com o nome da função que retorna os resíduos
  //      dados_sim:    struct com os dados_sim de entrada de FUN
  //      X1:       vetor com as estimativas
  //
  //   Os argumentos de saída são:
  //
  //      X1OUT:    vetor com as soluções
  //
  //
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011
  
  global F2 X2
  
  // (1) Determinando constantes
  Tol=1e-9;// Toler�ncia do método (norma do vetor de residuos)
  maxIter=30;// Numero máximo de iterações
  Delta=1e-6;// Parametro para calculo da Jacobiana numrica
  Delta2=1e-9;// Parametro para calculo da Jacobiana numrica
  
  // (2) Executa a função que gera o vetor de resíduos
  execstr('F1 = '+FUN+'(dados_sim,X1);');
  
  // (3) Iniciando vari�veis
  cont=0; // contador
  Res=norm(F1); // Res�duo
  flag = 1; // Flag de converg�ncia
  status = 0;
  
  // (4) Iniciando painel
  mprintf(['it.:     '+string(cont)+'    norma :  '+string(norm(F1))+'\n'])

  // (5) Executando laço de convergência
  while Res>Tol&status==0

    if cont==maxIter
        mprintf('Parou por atingir número máximo de iterações.\n')
        flag = 0;
        break
    end
    
    dF=[];
    for j=1:length(X1)
        X21=X1;
        X22=X1;
        X21(j)=(1+Delta)*X1(j)+Delta2;
        X22(j)=(1-Delta)*X1(j)-Delta2;
        execstr('F21 = '+FUN+'(dados_sim,X21);');
        execstr('F22 = '+FUN+'(dados_sim,X22);');
        dF=[dF (F22-F21)./(X22(j)-X21(j))];
    end

    X2=X1-real(dF\F1);// Atualização dos estados

    execstr('F2 = '+FUN+'(dados_sim,X2);');// Cálculo do vetor de residuos

    // Atualização das variaveis
    X1 = X2;
    F1 = F2;
    Res =norm(F1);
    cont=cont+1;    

    // Atualização do painel
    mprintf(['it.:     '+string(cont)+'    norma :  '+string(norm(F1))+'\n'])
        
  end
   
  // Check final de convergência
   X1OUT = X1;
  if sum(sum(isnan(X1OUT)))
    mprintf('Não Convergiu/n')
    flag = 0;
  end
endfunction
