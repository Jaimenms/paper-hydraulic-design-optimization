function [saidas,x]=simulaRede(dados,x0)
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
  //   Sintaxe: [saidas,x,saidas0,x0] = SIMULAREDE(dados,x0,D)
  //
  //
  //   Os argumentos de entrada são:
  //
  //     dados: struct com os dados da simulacao
  //     x0: vetor com as estimativas iniciais da simulacao (opcional)
  //     D: vetor com os diametros internos do dutos em m (opcional)
  //
  //   Os argumentos de saída são:
  //
  //     saidas: struct com as saidas da simulacao
  //     x:      vetor com as variaveis da simulacao
  //
  //
  //   Desenvolvido por Jaime Souza em 11 de outubro de 2010

  // (1) Tratamentos iniciais  
  warning('off')
  if ~exists('x0'),x0=[]; end
  if isempty(x0),flagLaminar=1;else;flagLaminar=0;end
  
  // (2) Gerando struct com parametros a partir dos dados
  parametros = geraParametros(dados);
  
  // (4) Gerando estimativa inicial
  if flagLaminar
    x0=modelolaminar(parametros);
  end
  
  // (5) Resolvendo sistema algébrico não-linear
  x=solver_sea('modelorigoroso',parametros,x0);
  
  // (6) Calculando saídas
  [F,saidas]=modelorigoroso(parametros,x);
  
endfunction

function x=modelolaminar(parametros)
  // MODELOLAMINAR     Calcula as variaveis da rede utilizando como premissa o
  //                   escoamento laminar. Desse modo o problema de simulação
  //                   da rede de escoamento é simplificado a apenas um siste-
  //                   algébrico linear.
  //
  //   Sintaxe: x = modelolaminar(parametros)
  //
  //   Os argumentos de entrada são:
  //   
  //      parametros: struct com todos os parametros necessarios
  //
  //   Os argumentos de saída são:
  //
  //     x:      vetor com as variaveis da simulacao
  //
  //
  //   Desenvolvido por Jaime Souza em 11 de outubro de 2010
  
  
  // (1) Acessando os parametros
  K = parametros.K; //matriz de incidencia da rede
  H = parametros.H; //matriz de coeficientes das bombas
  N = parametros.N; //numero de nós
  S = parametros.S; //numero de arestas
  E = parametros.E; //matriz de seleção de especificações
  e = parametros.e; //vetor de especificações
  z = parametros.z; //vetor de cotas dos vértices
  ni = parametros.ni; //viscosidade dinamica (Pa.s)
  d = parametros.d; //densidade (kg/m³)
  L = parametros.L; //comprimento (m)
  D = parametros.D; //diametro interno (m)
  QSI_PI = parametros.QSI_PI; //matriz de seleção de arestas de tubos
  QSI_PU = parametros.QSI_PU; //matriz de seleção de arestas de bombas
  QSI_HE = parametros.QSI_HE; //matriz de seleção de arestas de trocadores
  F_HE_ref = parametros.F_HE_ref; //vetor de perdas de carga dos trocadores na condição de projeto (m)
  k_HE_ref = parametros.k_HE_ref; //vetor de vazões mássica dos trocadores na condição de projeto (kg/s)
  S_PI = parametros.S_PI; //numero de arestas de tubos
  S_PU = parametros.S_PU; //numero de arestas de bombas
  S_HE = parametros.S_HE; //numero de arestas de trocadores
  K_PI = parametros.K_PI; //matriz de incidência de arestas de tubos
  K_HE = parametros.K_HE; //matriz de incidência de trocadores
  K_PU = parametros.K_PU; //matriz de incidência de bombas
  xsplit=parametros.xsplit;
  Dsplit=parametros.Dsplit;
  
  // (2) Definindo as constantes
  g = 9.80665; //aceleracao da gravidade (m/s²)
  fatorEsc = 1e-5; //fator de conversão de Pa para bar  
    
  // (3) Determinando as diferenças de pressão estática
  dPz_PI = K_PI'*(z.*d.*g); //vetor de diferenças de pressão estatica para tubos
  dPz_HE = K_HE'*(z.*d.*g); //vetor de diferenças de pressão estatica para trocadores  
  dPz_PU = K_PU'*(z.*d.*g); //vetor de diferenças de pressão estatica para bombas
  
  // (4) Determinando os coeficientes das equações de momento considerando laminar
  
  L1 = L.*(1-xsplit);  D1 = D;
  L2 = L.*(  xsplit);  D2 = Dsplit;

  F_PI1=diag(128.*ni.*L1.*(D1.^4.*%pi.*d).^-1); //para tubos
  F_PI2=diag(128.*ni.*L2.*(D2.^4.*%pi.*d).^-1); //para tubos
  F_PI=F_PI1+F_PI2;
  
  F_HE=diag(d.*g.*F_HE_ref.*(k_HE_ref.^-1)); //para trocadores
  F_PU=H($,:); //para bombas
  
  // (5) Montando as matrizes de coeficientes do modelo
  BM  =[K zeros(N,N) eye(N,N)]; // balanço de massa
  BEM1=[(fatorEsc.*F_PI)*QSI_PI K_PI' zeros(S_PI,N)]; // balanço de momento para tubos
  BEM2=[(fatorEsc.*F_HE)*QSI_HE K_HE' zeros(S_HE,N)]; // balanço de momento para trocadores
  BEM3=[zeros(S_PU,S_PU)*QSI_PU K_PU' zeros(S_PU,N)]; // balanço de momento para bombas
  BEM =[BEM1 ; BEM2; BEM3]; //balanço de momento
  A=[BM;BEM;E]; //matriz de coeficientes
      
  // (6) Montando vetor de coeficientes do sistema não-homogêneo
  C=[zeros(N,1); -fatorEsc.*dPz_PI;-fatorEsc.*dPz_HE;fatorEsc.*(-dPz_PU+d.*g.*F_PU); e];
  
  // (7) Resolvendo o sistema de equações
  x=A\C;
  
endfunction

function [F,saidas]=modelorigoroso(parametros,x)
  // MODELORIGOROSO     Calcula o vetor de residuos do modelo de escoamento
  //                    incompressível em uma rede de dutos descrita através
  //                    de um sistema algébrico não-linear.
  //
  //   Sintaxe: [F,saidas] = modelorigoroso(parametros,x)
  //
  //   Os argumentos de entrada são:
  //   
  //      parametros: struct com todos os parametros necessarios
  //      x:          vetor com as estimativas das variaveis da simulacao
  //
  //   Os argumentos de saída são:
  //
  //     saidas:      struct com as saidas da simulação
  //
  //
  //   Desenvolvido por Jaime Souza em 11 de outubro de 2010
  
  // (1) Acessando os parametros
  K = parametros.K; //matriz de incidencia da rede
  H = parametros.H; //matriz de coeficientes das bombas
  N = parametros.N; //numero de nós
  S = parametros.S; //numero de arestas
  E = parametros.E; //matriz de seleção de especificações
  e = parametros.e; //vetor de especificações
  z = parametros.z; //vetor de cotas dos vértices
  ni = parametros.ni; //viscosidade dinamica (Pa.s)
  d = parametros.d; //densidade (kg/m³)
  L = parametros.L; //comprimento (m)
  D = parametros.D; //diametro interno (m)
  QSI_PI = parametros.QSI_PI; //matriz de seleção de arestas de tubos
  QSI_PU = parametros.QSI_PU; //matriz de seleção de arestas de bombas
  QSI_HE = parametros.QSI_HE; //matriz de seleção de arestas de trocadores
  F_HE_ref = parametros.F_HE_ref; //vetor de perdas de carga dos trocadores na condição de projeto (m)
  k_HE_ref = parametros.k_HE_ref; //vetor de vazões mássica dos trocadores na condição de projeto (kg/s)  
  S_PI = parametros.S_PI; //numero de arestas de tubos
  S_PU = parametros.S_PU; //numero de arestas de bombas
  S_HE = parametros.S_HE; //numero de arestas de trocadores
  K_PI = parametros.K_PI; //matriz de incidência de arestas de tubos
  K_HE = parametros.K_HE; //matriz de incidência de trocadores
  K_PU = parametros.K_PU; //matriz de incidência de bombas
  ep = parametros.ep; //vetor de rugosidade dos tubos (m)
  Fac = parametros.Fac; //vetor de perdas de carga localizadas (m)
  LDac =parametros.LDac; //vetor de comprimentos equivalentes de acidentes (m)
  xsplit=parametros.xsplit;
  Dsplit=parametros.Dsplit;

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
  dP_HE = dg.*F_HE_ref.*(k_HE./k_HE_ref).^1.8; //trocadores

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
  saidas.F_PI = 100.*dP_PI.*((dg.*L).^-1);
  saidas.F_PI1 = F_PI1;
  saidas.F_PI2 = F_PI2;
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

// Funções para solução do sistema de equações
function [X1]=solver_sea(FUN,dados,X1)// Método de Newton-Raphson
  global F2 X2
  
  // (1) Determinando constantes
  Tol=1e-9;// Toler�ncia do método (norma do vetor de residuos)
  maxIter=30;// Numero máximo de iterações
  Delta=1e-6;// Parametro para calculo da Jacobiana numrica
  Delta2=1e-9;// Parametro para calculo da Jacobiana numrica
  
  // (2) Executa a função que gera o vetor de resíduos
  execstr('F1 = '+FUN+'(dados,X1);');
  
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
        execstr('F21 = '+FUN+'(dados,X21);');
        execstr('F22 = '+FUN+'(dados,X22);');
        dF=[dF (F22-F21)./(X22(j)-X21(j))];
    end

    X2=X1-real(dF\F1);// Atualização dos estados

    execstr('F2 = '+FUN+'(dados,X2);');// Cálculo do vetor de residuos

    // Atualização das variaveis
    X1 = X2;
    F1 = F2;
    Res =norm(F1);
    cont=cont+1;    

    // Atualização do painel
    mprintf(['it.:     '+string(cont)+'    norma :  '+string(norm(F1))+'\n'])
        
  end

  // Check final de convergência
  if sum(sum(isnan(X1)))
    mprintf('Não Convergiu/n')
    flag = 0;
  end
endfunction


function [parametros] = geraParametros(dados)
  // GERAPARAMETROS   Monta um struct com todos os parametros usados pelo
  //                  SIMULAREDE a partir de um struct de dados.
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
  
  
  // (1) Calculos Iniciais
  S_PU = size(dados.BOMBA.tag,1); //numero de arestas de bombas
  S_PI = size(dados.LINHA.tag,1); //numero de arestas de tubos
  S_HE = size(dados.EQUIP.tag,1); //numero de arestas de trocadores
  S = S_PU+S_PI+S_HE; //numero total de arestas
  N_E = length(dados.VERTICE.ind_vertice); //numero de especificações
  N = length(unique([dados.REDE.ind_noh_montante;dados.REDE.ind_noh_jusante])); //numero de nós
  
  // (2) Montando a matriz de incidência
  K = zeros(N,S);
  for i=1:S
    ix = find(dados.REDE.ind_aresta==i);
    i_Noh1=dados.REDE.ind_noh_montante(ix);
    i_Noh2=dados.REDE.ind_noh_jusante(ix);
    K(i_Noh1,ix) = -1;
    K(i_Noh2,ix) =  1;
  end
  
  // (3) Montando as matrizes seletoras de arestas
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
  end
  
  // (4) Montando a matriz de coeficientes
  H = zeros(4,0);
  for i=1:length(dados.BOMBA.ind)
    H(1,i)=dados.BOMBA.coef3(i);
    H(2,i)=dados.BOMBA.coef2(i);
    H(3,i)=dados.BOMBA.coef1(i);
    H(4,i)=dados.BOMBA.coef0(i);
  end
  
  // (5) Montando a matriz seletora de especificações
  E = zeros(N,2*N+S);  e = zeros(N,1);  z = zeros(N,1);
  for i = 1:N
    ix = find(dados.VERTICE.ind_vertice==i);
    if ~isempty(ix)
      if dados.VERTICE.tipo(ix) == 'P'
        E(i,S+i) = 1;
      elseif dados.VERTICE.tipo(ix) == 'W'
        E(i,S+N+i) = 1;
      end
      e(i,1)=dados.VERTICE.esp(ix);
      z(i,1)=dados.VERTICE.z(ix);
    else
      E(i,S+N+i) = 1;
    end
  end
  
  // (6) Criando parametros
  parametros.N = N;
  parametros.S = S;
  parametros.K = K;  
  parametros.H = H;  
  parametros.E = E;  
  parametros.e = e;
  parametros.z = z;
  parametros.S_PI = S_PI;
  parametros.S_PU = S_PU;
  parametros.S_HE = S_HE;
  parametros.K_PI = K*QSI_PI';
  parametros.K_PU = K*QSI_PU';
  parametros.K_HE = K*QSI_HE';
  parametros.QSI_PI = QSI_PI;
  parametros.QSI_PU = QSI_PU;
  parametros.QSI_HE = QSI_HE;
  parametros.ni = dados.FLUIDO.visc./1000;
  parametros.d = dados.FLUIDO.dens;
  parametros.F_HE_ref=dados.EQUIP.F;
  parametros.k_HE_ref=dados.EQUIP.k;
  parametros.ep = dados.LINHA.e./1e6;
  parametros.L = dados.LINHA.L;
  parametros.D = dados.LINHA.di./1000;
  parametros.LDac = dados.LINHA.LDac;
  parametros.Fac = dados.LINHA.Fac;
  
  if isfield(dados.LINHA,'xsplit')
      parametros.xsplit=dados.LINHA.xsplit;
      parametros.Dsplit=dados.LINHA.Dsplit./1000;
  else
      parametros.xsplit=zeros(parametros.D);
      parametros.Dsplit=parametros.D;
  end
  
  
endfunction
