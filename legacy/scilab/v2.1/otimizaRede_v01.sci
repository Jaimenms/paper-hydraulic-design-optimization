function otimizaRede_v01(arquivoIN,dados)
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
  //   Desenvolvido por Jaime Souza em 12 de outubro de 2011

  // (1) Iniciando variaveis
  executa_classico=1;
  executa_QP=0;
  parametros = geraParametros_opt(dados);
  xi=[];
  
  // (3) Determina diametros da rede a partir das velocidade de projeto
  if (dados.CASO.executa_towler=='sim')
      mprintf('- Projeto tradicional-Towler:\n')
      [dadosi,opti] = determinaTowler(dados,parametros);
      if (executa_classico==1)
          // (4) Simulando para projeto classico
          mprintf('- Simulação projeto tradicional-Towler:\n')
          [simi,xi]  = simulaRede(dadosi,xi);
          simi.cenario=1;
          heati = heatcheck (simi.k_HE,parametros);
          opti  = calculaFob(simi,dadosi,opti,parametros);
          save(part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'01_TOWLER.dat',dadosi,simi,heati,opti);
      end
  end

  // (5) Determina diametros da rede a partir das velocidade de projeto
  if (dados.CASO.executa_himmelblau=='sim')
      mprintf('- Projeto tradicional-Himmelblau:\n')
      [dadosi,opti] = determinaHimmelblau(dados,parametros);
      
      if (executa_classico==1)
          // (6) Simulando para projeto classico
          mprintf('- Simulação projeto tradicional-Himmelblau:\n')
          [simi,xi]  = simulaRede(dadosi,xi);
          simi.cenario=1;
          heati = heatcheck (simi.k_HE,parametros);
          opti  = calculaFob(simi,dadosi,opti,parametros);
          save(part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'02_HIMMELBLAU.dat',dadosi,simi,heati,opti);
      end
  end

  // (7) Otimizando para cada curva de bomba
  for i_bomba = 1:size(parametros.HOPT,2)
      
      // Iniciando
      mprintf('- Otimização para bomba '+string(i_bomba)+'...\n')      
            
      mprintf('- Calculando da estimativa inicial\n')
      parametros = geraParametros_opt(dados);
      [x1,u1,eh_inviavel] = geraEstimativaInicial(i_bomba,parametros);      
      if eh_inviavel
          mprintf('- Problema inviável. Conjunto de diametros ou bomba inadequados.\n')
      else
          
          mprintf('- Projeto LP bomba '+string(i_bomba)+':\n')
          dadosk=[];
          [x2,u2,dadosk,opti] = resolveLP(i_bomba,x1,u1,dados,parametros);
          
          for j = 1:parametros.N_CEN
              mprintf('- Simulação projeto LP bomba '+string(i_bomba)+' para cenário '+string(j)+':\n')
              dadosi=dadosk;
              dadosi.REDE_ARESTA_TROC.Fac=dadosk.REDE_ARESTA_TROC.Fac(:,j);
              [simi,xi]  = simulaRede(dadosi,xi);
              simi.cenario=j;
              heati = heatcheck (simi.k_HE,parametros);
              opti  = calculaFob(simi,dadosi,opti,parametros);
              save(part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'LP'+string(i_bomba)+'CEN'+string(j)+'.dat',dadosi,simi,heati,opti);
          end
          
          if (executa_QP==1)
              mprintf('- Projeto QP bomba '+string(i_bomba)+':\n')
              dadosk=[];
              [x3,u3,dadosk,opti] = resolveQP(i_bomba,x2,u2,dados,parametros);
              
              for j = 1:parametros.N_CEN
                  mprintf('- Simulação projeto QP bomba '+string(i_bomba)+' para cenário '+string(j)+':\n')
                  dadosi=dadosk;
                  dadosi.REDE_ARESTA_TROC.Fac=dadosk.REDE_ARESTA_TROC.Fac(:,j);
                  [simi,xi]  = simulaRede(dadosi,xi);
                  simi.cenario=j;
                  heati = heatcheck (simi.k_HE,parametros);
                  opti  = calculaFob(simi,dadosi,opti,parametros);
                  save(part(arquivoIN,1:regexp(arquivoIN,'/.txt/'))+'QP'+string(i_bomba)+'CEN'+string(j)+'.dat',dadosi,simi,heati,opti);
              end
          end
      end
  end  

endfunction


function [parametros] = geraParametros_opt(dados)
  // GERAPARAMETROS   Monta um struct com todos os parametr''os usados pelo
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
  
  
  // Modificando rede para o casode haver splits nos pipes
  // TODO

  // Identificando Diametros Internos
  N_D   = length(dados.OPT_OPCOES_LINHA.DIN);
  S_PI   = length(dados.REDE_ARESTA_LINHA.ind);
  dados.REDE_ARESTA_LINHA.DIN = zeros(S_PI,1);
  tipo_PI= dados.REDE_ARESTA_LINHA.tipo;
  existente_X= zeros(S_PI,N_D);
  fixo_X= zeros(S_PI,N_D);
  otimo_X= zeros(S_PI,N_D);
  novo_X= zeros(S_PI,N_D);  
  existente_PI= zeros(S_PI,1);
  fixo_PI= zeros(S_PI,1);
  otimo_PI= zeros(S_PI,1);
  novo_PI= zeros(S_PI,1);  
  for i=1:S_PI
      for j=1:N_D
          if (dados.REDE_ARESTA_LINHA.DIA(i)==dados.OPT_OPCOES_LINHA.tag(j) | dados.REDE_ARESTA_LINHA.DIA(i)==dados.OPT_OPCOES_LINHA.DN(j))
              dados.REDE_ARESTA_LINHA.DIN(i) = dados.OPT_OPCOES_LINHA.DIN(j);
              if (tipo_PI(i)=="existente_fixo" | tipo_PI(i)=="existente_otimo" )
                  existente_X(i,j)=1;
                  existente_PI(i,1)=1;
              end
              if (tipo_PI(i)=="novo_fixo" | tipo_PI(i)=="novo_otimo" )
                  novo_X(i,j)=1;
                  novo_PI(i,1)=1;
              end
              if (tipo_PI(i)=="existente_fixo" | tipo_PI(i)=="novo_fixo" )
                  fixo_X(i,j)=1;
                  fixo_PI(i,1)=1;
              end
              if (tipo_PI(i)=="existente_otimo" | tipo_PI(i)=="novo_otimo" )
                  otimo_X(i,j)=1;
                  otimo_PI(i,1)=1;
              end
          end
      end
  end
  

  // Identificando Dados das Bombas
  N_Curvas   = length(dados.OPT_CURVA.ind);
  S_PU   = length(dados.REDE_ARESTA_BOMBA.ind);
  dados.REDE_ARESTA_BOMBA.coef3  = zeros(S_PU,1);
  dados.REDE_ARESTA_BOMBA.coef2  = zeros(S_PU,1);
  dados.REDE_ARESTA_BOMBA.coef1  = zeros(S_PU,1);
  dados.REDE_ARESTA_BOMBA.coef0  = zeros(S_PU,1);
  dados.REDE_ARESTA_BOMBA.qrated = zeros(S_PU,1);
  dados.REDE_ARESTA_BOMBA.eta    = zeros(S_PU,1);
  tipo_PU= dados.REDE_ARESTA_BOMBA.tipo;
  indice_PU = zeros(S_PU,1);
  for i=1:S_PU
      for j=1:N_Curvas
          if (dados.REDE_ARESTA_BOMBA.curve(i)==dados.OPT_CURVA.tag(j))
              dados.REDE_ARESTA_BOMBA.coef3(i)  = dados.OPT_CURVA.coef3(j);
              dados.REDE_ARESTA_BOMBA.coef2(i)  = dados.OPT_CURVA.coef2(j);
              dados.REDE_ARESTA_BOMBA.coef1(i)  = dados.OPT_CURVA.coef1(j);
              dados.REDE_ARESTA_BOMBA.coef0(i)  = dados.OPT_CURVA.coef0(j);
              dados.REDE_ARESTA_BOMBA.qrated(i) = dados.OPT_CURVA.qrated(j);
              dados.REDE_ARESTA_BOMBA.eta(i)    = dados.OPT_CURVA.eta(j);
              indice_PU(i)=j;
          end
      end
  end

  // Diametros e comprimentos
  L     = dados.REDE_ARESTA_LINHA.L;
  DIN  = dados.OPT_OPCOES_LINHA.DIN;
  DN   = dados.OPT_OPCOES_LINHA.DN ;
  D    = DIN./1000;  //diametros possiveis

  // Fluido
   v_PI_max = dados.REDE_FLUIDO.v_PI_max;
   d        = dados.REDE_FLUIDO.dens;
   ni       = dados.REDE_FLUIDO.visc./1000;

  // Numero de elementos
  N_OPT = size(dados.OPT_CURVA.tag,1); // quantidade de bombas a serem testadas
  S_PU  = size(dados.REDE_ARESTA_BOMBA.tag,1); // número de bombas da rede (nessa versao sempre 1)
  S_PI  = size(dados.REDE_ARESTA_LINHA.tag,1); // número de arestas de tubulação
  S_HE  = size(dados.REDE_ARESTA_TROC.tag,1); // número de arestas de trocadores de calor
  N     = length(unique([dados.REDE.ind_noh_montante;dados.REDE.ind_noh_jusante])); // Número de vértices
  N_D   = length(dados.OPT_OPCOES_LINHA.DIN);   // número de diâmetros a serem testados
  N_E   = length(dados.REDE_VERTICE.ind_vertice); // número de especificações nodais (apenas para simulação)
  N_CEN = length(unique(dados.OPT_CENARIO.i)); // número de cenários (normalmente 1)
  NE = S_HE; // número de especificações (apenas para rede tipo árvore)
  S     = S_PU + S_PI + S_HE; // número de arestas

  // Matriz de incidência que mostra a conecitividade entre vértices e arestas
  K = zeros(N,S);
  for i=1:S
    ix = find(dados.REDE.ind_aresta==i);
    i_Noh1=dados.REDE.ind_noh_montante(ix);
    i_Noh2=dados.REDE.ind_noh_jusante(ix);
    K(i_Noh1,ix) = -1;
    K(i_Noh2,ix) =  1;
  end
  
  // Vetores de vértices
  uPS = ones(N,1)-sign((abs(K)+K)*ones(S,1));
  uPD = ones(N,1)-sign((abs(K)-K)*ones(S,1));
  zPS = dados.REDE_VERTICE.z(1);
  zPD = dados.REDE_VERTICE.z(2);
  pPS = dados.REDE_VERTICE.esp(1);
  pPD = dados.REDE_VERTICE.esp(2);
  
  // Matriz seletora que mapeia ARESTAS -> LINHAS
  QSI_PI = zeros(S_PI,S);
  flag_PI = ones(S_PI,1);
  for i=1:S_PI
    ix = dados.REDE_ARESTA_LINHA.ind(i);
    QSI_PI(i,ix)=1;
  end
  
  // Matriz seletora que mapeia ARESTAS -> BOMBAS
  QSI_PU = zeros(S_PU,S);
  flag_PU = ones(S_PU,1);
  for i=1:S_PU
    ix = dados.REDE_ARESTA_BOMBA.ind(i);
    QSI_PU(i,ix)=1;
  end
    
  // Matriz seletora que mapeia ARESTAS -> TROCADORES
  QSI_HE = zeros(S_HE,S);
  flag_HE = ones(S_HE,1);
  for i=1:S_HE
    ix = dados.REDE_ARESTA_TROC.ind(i);
    QSI_HE(i,ix)=1;
  end
  
  // Matriz e vetor de especificações (para rede tipo árvore)
  E  = QSI_HE;
  e=[];
  for i=1:N_CEN
    e(:,i) = dados.OPT_CENARIO.k(dados.OPT_CENARIO.i==i);
  end
  fop=dados.OPT_CENARIO.fop;
  
  // Matrizes seletoras de circuitos
  A = [eye(S,S) zeros(S,2)];
  B = inv([K uPS uPD ; E zeros(NE,2)]);
  C = [zeros(N,NE);eye(NE,NE)];
  QSI_CIR= [A*sign(B)*C]';
  S_CIR  = size(QSI_CIR,1);
  
  // Diferença de head entre vértice de entrada e vértice de saída
  dz  = (zPS+1e5.*pPS./(d*9.81))-(zPD+1e5.*pPD./(d*9.81));
  
  // Determina matriz Q da parte quadrática
  Q=zeros(S_PI*N_D,S_PI*N_D);
  for i=1:S_PI
    for k=1:N_D
      Q(k+(i-1)*N_D,k+(i-1)*N_D) = -1./S_PI;
    end
  end
  
  // Matriz de coeficientes das bombas (normalmente apenas uma bomba)
  H = zeros(4,0);
  for i=1:S_PU
    H(1,i)=dados.REDE_ARESTA_BOMBA.coef3(i);
    H(2,i)=dados.REDE_ARESTA_BOMBA.coef2(i);
    H(3,i)=dados.REDE_ARESTA_BOMBA.coef1(i);
    H(4,i)=dados.REDE_ARESTA_BOMBA.coef0(i);
  end

  // Matriz de coeficientes do polinômio das bombas selecionáveis
  HOPT = zeros(4,0);
  for i=1:N_OPT
    HOPT(1,i)=dados.OPT_CURVA.coef3(i);
    HOPT(2,i)=dados.OPT_CURVA.coef2(i);
    HOPT(3,i)=dados.OPT_CURVA.coef1(i);
    HOPT(4,i)=dados.OPT_CURVA.coef0(i);
  end

  ep         = dados.REDE_ARESTA_LINHA.e./1e6;
  LDac       = dados.REDE_ARESTA_LINHA.LDac;
  F_HE_ref   = dados.REDE_ARESTA_TROC.F;
  k_HE_ref   = dados.REDE_ARESTA_TROC.k;
  Fac        = dados.REDE_ARESTA_LINHA.Fac;
  qrated     = dados.OPT_CURVA.qrated;
  k_PU_rated = d.*qrated;
  for j=1:N_OPT
      F_PU_rated(j,1) = determinaHeadsBombas(k_PU_rated(j),d,HOPT(:,j));
  end

  // Deterinando custos operacionais
  Nop = dados.OPT_CUSTO_OPERACIONAL.Nop;
  pc  = dados.OPT_CUSTO_OPERACIONAL.pc;
  eta = dados.OPT_CURVA.eta;
  // Determinando fator de anualização
  in = dados.OPT_CUSTO_OPERACIONAL.in;
  ny = dados.OPT_CUSTO_OPERACIONAL.ny;
  f=(1+in)^ny;
  r = (in*f)/(f-1);
    
  I_PU=[];
  Power=[];
  C_PU=[];
  for ind=1:N_OPT
      if (ind==indice_PU(1) & (tipo_PU=="existente"))
         fator_PU=0;
      else
         fator_PU=1;
      end
      I_PU(ind) = fator_PU.*price(k_PU_rated(ind),F_PU_rated(ind),d,eta(ind));
      C_PU(ind) = r.*I_PU(ind);
  end
      
  // Balanço de massa
  C2x=[];  
  C2u=[];  
  b2=[];
  
  KK_PI = zeros(S_PI,N_CEN);
  KK_PU = zeros(S_PU,N_CEN);
  KK_HE = zeros(S_HE,N_CEN);
  FF_PI = [];
  FF_PU = [];
  FF_HE = [];
  CCop_PI = [];
  Mix=zeros(S_PI*N_D,S_PI*N_D);
  for i_cen=1:N_CEN
      
      A = [K uPS uPD;E zeros(NE,2)];
      b = [zeros(N,1);e(:,i_cen)];
      x = A\b;
      k = x(1:S,1);
      k_PI = QSI_PI*k;
      k_PU = QSI_PU*k;
      k_HE = QSI_HE*k;
      
      KK_PI(1:S_PI,i_cen) = QSI_PI*k;
      KK_PU(1:S_PU,i_cen) = QSI_PU*k;
      KK_HE(1:S_HE,i_cen) = QSI_HE*k;
  
      // Determina heads
      [F_PI,v_PI]    = determinaHeadsLinhas(k_PI,L,d,ni,ep,LDac,D,Fac);
      [F_HE     ]    = determinaHeadsTrocadores(k_HE,F_HE_ref,k_HE_ref);
      for j=1:N_OPT
          F_PU(j,1)       = determinaHeadsBombas(k_PU,d,HOPT(:,j));
      end
    
      // Determinando queda de pressão por comprimento
      dPdL100=100*(diag(L)^-1)*F_PI*9.8066*d./98066.5; //kgf/cm²/100m
    
      // Deterinando custos das linhas
      alfah = dados.OPT_CUSTO_LINHA.alfa;
      betah = dados.OPT_CUSTO_LINHA.beta;
      [Cop_PI,C_PI_ast,C_PI] = calcula_PI(alfah,betah,L,DN,existente_X,fixo_X);
      C_PIa_ast = C_PI_ast';
      p_ast = C_PIa_ast(:) + Cop_PI(:);
      C_PIa = C_PI';
      p = C_PIa(:) + Cop_PI(:);
      
      // Matriz de coeficientes das restrições de somatórios de frações em relação às frações
      C1x=[];
      for i=1:S_PI
        C1x(i,(1:N_D)+(i-1)*N_D) = ones(1,N_D);
      end
    
      // Matriz de coeficientes das restrições de circuitos hidráulicos em relação às frações
      F_PI2=[];
      for i=1:S_PI
        F_PI2(i,(1:N_D)+(i-1)*N_D) = F_PI(i,:);
      end
      C2x_aux = QSI_CIR*QSI_PI'*F_PI2;
      C2x = [C2x;C2x_aux];
              
      //Vetor das restricoes de desigualdade (md) x n
      b2_aux=[];
      for i=1:N_OPT
          b2_aux(:,i) = F_PU(i) + dz - QSI_CIR*QSI_HE'*F_HE - QSI_CIR*QSI_PI'*Fac;
      end
      b2=[b2;b2_aux];
              
      // Determinando subseções válidas pelos critérios de máx. velocidade e máx. perda de carga
      aux=0;
      v_PI_aux=zeros(S_PI*N_D,1);
      for k=1:S_PI
          for j=1:N_D
              aux = aux+1;
              v_PI_aux(aux)=v_PI(k,j);
          end
      end
      checkVal1=v_PI_aux<v_PI_max;
      ix  =find(checkVal1(:)); // indice das subsecoes válidas
      inx =find(~checkVal1(:));
      Six =length(ix); // número de subseções válidas
      Sz1=S_PI;
      Sz2=length(b2(:,1));
      for k=1:Six
          Mix(ix(k),ix(k))=Mix(ix(k),ix(k))+1;
      end
      
      FF_PI=[FF_PI F_PI];
      FF_PU=[FF_PU F_PU];
      FF_HE=[FF_HE F_HE];
      
      
  end
  ix = Mix(:)==N_CEN;
  ix2 = Mix==N_CEN;
  inx2 = Mix~=N_CEN;
  Mix(ix2)=1;
  Mix(inx2)=0;
  Mix2=[];
  for i=1:size(Mix,1)
     if sum(Mix(i,:))~=0
         Mix2=[Mix2;Mix(i,:)];
      end
  end
  Mix=Mix2;
  
  // Valores de constraints (inferior e superior)
  ci = [zeros(S_PI*N_D+N_CEN*S_HE,1)];
  cs = [ones(S_PI*N_D,1);100*ones(N_CEN*S_HE,1)];
  
  // Matriz de coeficientes das restrições de somatórios de frações em relação às válvulas
  C1u = zeros(S_PI,N_CEN*S_HE)

  // Matriz de coeficientes das restrições de circuitos hidráulicos em relação às válvulas
  C2u = eye(N_CEN*S_HE,N_CEN*S_HE)

  // Vetor das restrições de igualdade (me) x 1    
  b1 = ones(S_PI,1);
  
  parametros.flag_PI    = flag_PI;
  parametros.flag_PU    = flag_PU;
  parametros.flag_HE    = flag_HE;
  parametros.Mix        = Mix;
  parametros.C_PI       = C_PI;
  parametros.C_PI_ast   = C_PI_ast;
  parametros.Cop_PI     = Cop_PI;
  parametros.k_PI       = KK_PI;
  parametros.k_PU       = KK_PU;
  parametros.k_HE       = KK_HE;
  parametros.k_PU_rated = k_PU_rated;
  parametros.F_PI       = FF_PI;
  parametros.F_PU       = FF_PU;
  parametros.F_HE       = FF_HE;
  parametros.F_PI_ac    = Fac;
  parametros.F_PU_rated = F_PU_rated;
  parametros.C_PU       = C_PU;
  parametros.D          = D;
  parametros.NE         = NE;
  parametros.zPS        = zPS;
  parametros.zPD        = zPD;
  parametros.pPS        = pPS;
  parametros.pPD        = pPD;
  parametros.HOPT       = HOPT;
  parametros.uPS        = uPS;
  parametros.uPD        = uPD;
  parametros.D          = D;
  parametros.DN         = DN;
  parametros.N_D        = N_D;  
  parametros.N_CEN      = N_CEN;  
  parametros.N          = N;
  parametros.Nop        = Nop;
  parametros.fop        = fop;
  parametros.S          = S;
  parametros.K          = K;  
  parametros.H          = H;  
  parametros.E          = E;  
  parametros.S_PI       = S_PI;
  parametros.S_PU       = S_PU;
  parametros.S_HE       = S_HE;
  parametros.S_CIR      = S_CIR;
  parametros.QSI_CIR    = QSI_CIR;
  parametros.QSI_PI     = QSI_PI;
  parametros.QSI_PU     = QSI_PU;
  parametros.QSI_HE     = QSI_HE;
  parametros.dz         = dz;
  parametros.ep         = ep;
  parametros.L          = L;
  parametros.LDac       = LDac;
  parametros.ni         = ni;
  parametros.d          = d;
  parametros.dPdL100    = dPdL100;
  parametros.v_PI       = v_PI;
  parametros.r          = r;
  parametros.Q          = Q;
  parametros.C1x        = C1x;
  parametros.C2x        = C2x;
  parametros.C1u        = C1u;
  parametros.C2u        = C2u;
  parametros.b1         = b1;
  parametros.b2         = b2;
  parametros.ci         = ci;
  parametros.cs         = cs;
  parametros.p          = p;
  parametros.p_ast      = p_ast;
  parametros.tipo_PU    = tipo_PU;
  parametros.tipo_PI    = tipo_PI;
  parametros.existente_X= existente_X;
  parametros.fixo_X     = fixo_X;
  parametros.otimo_X    = otimo_X;
  parametros.novo_X     = novo_X;
  parametros.existente_PI= existente_PI;
  parametros.fixo_PI     = fixo_PI;
  parametros.otimo_PI    = otimo_PI;
  parametros.novo_PI     = novo_PI;
  parametros.DIN        = dados.REDE_ARESTA_LINHA.DIN;
  parametros.Cpc        = dados.REDE_FLUIDO.cp;
  parametros.Tci        = dados.REDE_FLUIDO.temp;
  parametros.v_PI_max   = dados.REDE_FLUIDO.v_PI_max;
  parametros.q_PU_rated = dados.REDE_ARESTA_BOMBA.qrated;
  parametros.mh         = dados.REDE_ARESTA_TROC.mh;
  parametros.Cph        = dados.REDE_ARESTA_TROC.Cph;
  parametros.Thi        = dados.REDE_ARESTA_TROC.Thi;
  parametros.Tho_sp     = dados.REDE_ARESTA_TROC.Tho_sp;
  parametros.Tco_sp     = dados.REDE_ARESTA_TROC.Tco_sp;
  parametros.mc_sp      = dados.REDE_ARESTA_TROC.mc_sp;
  parametros.A          = dados.REDE_ARESTA_TROC.A;
  parametros.hi_sp      = dados.REDE_ARESTA_TROC.hi_sp;
  parametros.he_sp      = dados.REDE_ARESTA_TROC.he_sp;
  parametros.Rfi        = dados.REDE_ARESTA_TROC.Rfi;
  parametros.Rfe        = dados.REDE_ARESTA_TROC.Rfe;
  parametros.kt         = dados.REDE_ARESTA_TROC.kt;
  parametros.Dti        = dados.REDE_ARESTA_TROC.Dti;
  parametros.Dte        = dados.REDE_ARESTA_TROC.Dte;
  parametros.ic         = dados.REDE_ARESTA_TROC.ic;
  parametros.it         = dados.REDE_ARESTA_TROC.it;
  parametros.F_HE_ref   = dados.REDE_ARESTA_TROC.F;
  parametros.k_HE_ref   = dados.REDE_ARESTA_TROC.k;
  parametros.eta        = dados.OPT_CURVA.eta
  parametros.pc         = dados.OPT_CUSTO_OPERACIONAL.pc;
  parametros.in         = dados.OPT_CUSTO_OPERACIONAL.in;
  parametros.ny         = dados.OPT_CUSTO_OPERACIONAL.ny;  
  parametros.alfa       = dados.OPT_CUSTO_LINHA.alfa;
  parametros.beta       = dados.OPT_CUSTO_LINHA.beta;  
   
endfunction
 
 
function [dados2,opt] = determinaHimmelblau(dados,parametros)
  
  // Acessando parametros  
  g = 9.81;
  k_PI     = parametros.k_PI;
  k_PU     = parametros.k_PU;
  d        = parametros.d;
  S_PI     = parametros.S_PI;
  N_D      = parametros.N_D;
  N_CEN    = parametros.N_CEN;

  D        = parametros.D;
  DN       = parametros.DN;
  v_PI_max = parametros.v_PI_max;
  C2x      = parametros.C2x;
  F_PU     = parametros.F_PU;
  
  dz       = parametros.dz;
  S_HE     = parametros.S_HE;
  S_CIR    = parametros.S_CIR;
  QSI_CIR  = parametros.QSI_CIR;
  QSI_HE   = parametros.QSI_HE;
  F_HE     = parametros.F_HE;
  QSI_CIR  = parametros.QSI_CIR;
  QSI_PI   = parametros.QSI_PI;
  Fac      = parametros.F_PI_ac;
  C_PI_ast     = parametros.C_PI_ast;

  Dvmax = 1e10*ones(S_PI,1);
  D0   = 0*ones(S_PI,1);
  for i = 1:N_CEN
      // Diametro calculado para velocidade máxima
      Dvmaxi = ((4.*k_PI(:,i).*((%pi.*v_PI_max.*d).^-1)).^0.5).*0.0254;
      Dvmax = min(Dvmax,Dvmaxi);

      // Calculando os diametros estimados
      coef=1.269;
      // Calculando os diametros estimados
      D0i = (coef.*(k_PI(:,i).^0.459)).*0.0254;
      D0 = max(D0,D0i);
  end

  //D0(find(parametros.existente_PI==1)) = parametros.DIN(find(parametros.existente_PI==1))./1000;

  // Iniciando vetores e matrizes
  x0=zeros(S_PI*N_D,1);
  X0=zeros(S_PI,N_D);
  // Criando vetores de fracoes de comprimento
  for i=1:S_PI
    // Bucando diametros imediatamente maiores
    ix=find(D>=D0(i)&D>=Dvmax(i));
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

  b2minimo = [];
  // Vetor de head adicional mínimo por circuito hidráulico
  for i = 1:N_CEN
      b2minimoi = dz - QSI_CIR*QSI_HE'*F_HE(:,i) - QSI_CIR*QSI_PI'*Fac;
      b2minimo = [b2minimo;b2minimoi];
  end

  // Head minimo da bomba
  [F_PU_minimo,kmax]=max(C2x*x0 - b2minimo);
  
  // Determinando Cenário Limitante
  ind_cen_lim = ceil(kmax/S_CIR); 

  [F_PU_s] = gsort(F_PU(:,ind_cen_lim),'c','i');
  
  ix = find(F_PU_s>=F_PU_minimo);
  
  F_PU_c = F_PU_s(ix(1));

  indice = find(F_PU_c==F_PU(:,ind_cen_lim));
  
  [calc_D,xopt,calc_DN,custo] = x2D_via_MaiorDiametro(x0,D,DN,C_PI_ast);
  
  dados2=dados;
  dados2.REDE_ARESTA_BOMBA.curve=dados.OPT_CURVA.tag(indice);
  dados2.REDE_ARESTA_LINHA.DIA = calc_DN;
  dados2.REDE_ARESTA_LINHA.xsplit=zeros(calc_DN);
  dados2.REDE_ARESTA_LINHA.DIAsplit=calc_DN;
  dados2.REDE_ARESTA_LINHA.Fac=zeros(calc_DN);
  
  opt.indice  = indice;
  opt.xopt    = xopt;
  opt.x0      = x0;
  opt.X0      = X0;
  opt.u       = zeros(S_HE);
  opt.xmin    = xopt;
  opt.xmax    = zeros(xopt);
  opt.Dmin    = calc_D;
  opt.Dmax    = calc_D;
  opt.DNmin   = calc_DN;
  opt.DNmax   = calc_D;
  opt.custo_PI= custo;
  

endfunction
 
 
function [dados2,opt] = determinaTowler(dados,parametros)

  // Acessando parametros  
  g = 9.81;
  k_PI     = parametros.k_PI;
  k_PU     = parametros.k_PU;
  d        = parametros.d;
  S_HE     = parametros.S_HE;
  S_PI     = parametros.S_PI;
  N_D      = parametros.N_D;
  D        = parametros.D;
  DN       = parametros.DN;
  v_PI_max = parametros.v_PI_max;
  C2x      = parametros.C2x;
  F_PU     = parametros.F_PU;
  N_CEN    = parametros.N_CEN;  
  dz       = parametros.dz;
  QSI_CIR  = parametros.QSI_CIR;
  S_CIR    = parametros.S_CIR;
  QSI_HE   = parametros.QSI_HE;
  F_HE     = parametros.F_HE;
  QSI_PI   = parametros.QSI_PI;
  Fac      = parametros.F_PI_ac;
  C_PI_ast = parametros.C_PI_ast;

  Dvmax = 1e10*ones(S_PI,1);
  D0   = 0*ones(S_PI,1);
  for i = 1:N_CEN
      // Diametro calculado para velocidade máxima
      Dvmaxi = ((4.*k_PI(:,i).*((%pi.*v_PI_max.*d).^-1)).^0.5).*0.0254;
      Dvmax = min(Dvmax,Dvmaxi);

      // Calculando os diametros estimados
      D0i = (39.37.*(k_PI(:,i).^0.5).*(d.^-0.5)).*0.0254;
      D0 = max(D0,D0i);
      
   end

  //D0(find(parametros.existente_PI==1)) = parametros.DIN(find(parametros.existente_PI==1))./1000;
  
  
  // Iniciando vetores e matrizes
  x0=zeros(S_PI*N_D,1);
  X0=zeros(S_PI,N_D);
  // Criando vetores de fracoes de comprimento
  for i=1:S_PI
    // Bucando diametros imediatamente maiores
    ix=find(D>=D0(i)&D>=Dvmax(i));
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


  b2minimo = [];
  // Vetor de head adicional mínimo por circuito hidráulico
  for i = 1:N_CEN
      b2minimoi = dz - QSI_CIR*QSI_HE'*F_HE(:,i) - QSI_CIR*QSI_PI'*Fac;
      b2minimo = [b2minimo;b2minimoi];
  end

  // Head minimo da bomba
  [F_PU_minimo,kmax]=max(C2x*x0 - b2minimo);
  
  // Determinando Cenário Limitante
  ind_cen_lim = ceil(kmax/S_CIR); 

  [F_PU_s] = gsort(F_PU(:,ind_cen_lim),'c','i');
  
  ix = find(F_PU_s>=F_PU_minimo);
  
  F_PU_c = F_PU_s(ix(1));

  indice = find(F_PU_c==F_PU(:,ind_cen_lim));

  [calc_D,xopt,calc_DN,custo] = x2D_via_MaiorDiametro(x0,D,DN,C_PI_ast);

  if (isempty(indice))
    [aux,indice] = max(F_PU(:,1));
  end
  
  dados2=dados;
  dados2.REDE_ARESTA_BOMBA.curve=dados.OPT_CURVA.tag(indice);
  dados2.REDE_ARESTA_LINHA.DIA = calc_DN;
  dados2.REDE_ARESTA_LINHA.xsplit=zeros(calc_DN);
  dados2.REDE_ARESTA_LINHA.DIAsplit=calc_DN;
  dados2.REDE_ARESTA_LINHA.Fac=zeros(calc_DN);
  
  opt.indice  = indice;
  opt.xopt    = xopt;
  opt.x0      = x0;
  opt.X0      = X0;
  opt.u       = zeros(S_HE);
  opt.xmin    = xopt;
  opt.xmax    = zeros(xopt);
  opt.Dmin    = calc_D;
  opt.Dmax    = calc_D;
  opt.DNmin   = calc_DN;
  opt.DNmax   = calc_D;
  opt.custo_PI= custo;

  
endfunction

function [Diametro,xmax,DiametroNominal,custo] = x2D_via_MaiorDiametro(x,D,DN,C_PI)
  // Função que determina diametros tendo como regra utilizar os maiores
  // diametros quando houver mais de um diametro em um trecho.
  
  
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
      custo(i)=C_PI(i,max(ix));
  end
  // Desmontando a matriz Xmax
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; xmax(aux)=Xmax(i,j); end, end  
  
endfunction

function [Diametro,xmax,DiametroNominal,custo] = x2D_via_MaiorFracao(x,D,DN,C_PI)
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
      custo(i)=C_PI(i,ix);      
  end
  // Desmontando a matriz Xmax
  aux=0;for i=1:S_PI, for j=1:N_D, aux = aux+1; xmax(aux)=Xmax(i,j); end, end  
endfunction


function [x2,Dmin,xmin,Dmax,xmax,DNmin,DNmax,custo] = x2D_via_SplitPipe(x,D,DN,C_PI)
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
      custo(i)=xmax(i).*C_PI(i,ix(1))+xmin(i).*C_PI(i,ix(2));
  end  

endfunction

function opt = calculaFob(sim,dados,opt,par)
  // Funcao que permite determinar as saidas do otimizador
  
  // Acessando parametros  
  indice     = opt.indice;
  xopt       = opt.xopt;
  k_PU       = sim.k_PU;
  F_PU       = sim.F_PU;
  S_PI       = par.S_PI;
  cenario    = sim.cenario;
  N_CEN      = par.N_CEN;
  N_D        = par.N_D;
  D          = par.D;  
  DN         = par.DN;  
  eta        = par.eta(indice);
  Nop        = par.Nop;
  fop        = par.fop(cenario);
  pc         = par.pc;
  C_PU       = par.C_PU(indice);
  p          = par.p;
  p_ast      = par.p_ast;
  Q          = par.Q;
  Cop_PI     = par.Cop_PI;
  C_PI       = par.C_PI;
      
  // Iniciando matriz X
  X    = zeros(S_PI,N_D)
  Xopt = zeros(S_PI,N_D)
  
  [x,Dmin,xmin,Dmax,xmax,DNmin,DNmax] = x2D_via_SplitPipe(xopt,D,DN,C_PI);

  // Montando matriz X
  aux=0;
  for i=1:S_PI
      for j=1:N_D
          aux = aux+1;
          X(i,j)=x(aux);
          Xopt(i,j)=xopt(aux);
      end
  end

  // Vetor de coeficientes da FOB
  [Cop_PU] = calcula_PU(-F_PU,k_PU,eta, Nop, pc);
    
  
  // Criando struct de variaveis de sa�da
  opt.x     = x;
  opt.Xopt  = Xopt;
  opt.DNmax = DNmax;
  opt.DNmin = DNmin;
  opt.Dmax  = Dmax;
  opt.Dmin  = Dmin;
  opt.xmax  = xmax;
  opt.p     = p;
  opt.xmin  = xmin;
//  opt.fob   = p(:)'*x(:)+C_PU+Cop_PU;
  opt.fob   = p_ast(:)'*x(:)+C_PU+Cop_PU;
  opt.fobPEN= 0.5.*x(:)'*Q*x(:);
  opt.C_PU  = C_PU;
  opt.Cop_PU= Cop_PU.*fop;
//  opt.C_PI  = p(:)'*x(:);
  opt.C_PI  = p_ast(:)'*x(:);
  opt.Cop_PI= Cop_PI(:)'*x(:);
  
endfunction

function [Cop,C_ast,C] = calcula_PI(alfah,betah,L,DN,existente_X,fixo_X)
    
  //fixo=1  => recebe 1 outros recebem 1e6
  //fixo=0  => recebe 1 outros recebem 1
  
  corretor_X=ones(fixo_X);
  for i=1:length(L)
      if (sum(fixo_X(i,:))==1)
          corretor_X(i,:)=1e6;
          corretor_X(i,find(fixo_X(i,:)))=1;
      end
  end
  
  // Determina custos tubos
  Cop=0;
  for i=1:length(L)
    for j=1:length(DN)
      C_ast(i,j) = (1-existente_X(i,j)).*(3.281^(betah+1)*L(i)*alfah*((DN(j)*0.0254)^betah));
      C(i,j) = corretor_X(i,j).*C_ast(i,j);
    end
  end
  
endfunction

function [Cop,Power] = calcula_PU(F_PU,k_PU,eta,Nop,pc)
  // Determina custos de bombas
  g = 9.81;
  Power = k_PU*g*F_PU/(eta*1e3); //kW
  Cop = Power*Nop*pc;//USD/y  
endfunction

function [F_HE] = determinaHeadsTrocadores(k_HE,F_HE_ref,k_HE_ref)
  // Função que calcula os heads dos elementos
  
  F_HE = F_HE_ref.*(k_HE./k_HE_ref).^1.8;
             
endfunction

function [F_PU] = determinaHeadsBombas(k_PU,d,H)
  // Função que calcula os heads dos elementos
  
  // Acessando parametros
  g = 9.81;
  q_PU = k_PU./d; // in m³/s
  F_PU = diag(H(1,:))*(q_PU.^3)+...
         diag(H(2,:))*(q_PU.^2)+...
         diag(H(3,:))*(q_PU.^1)+...
         diag(H(4,:))*(q_PU.^0);
         
endfunction

function [F_PI,v_PI] = determinaHeadsLinhas(k_PI,L,d,ni,ep,LDac,D,Fac)
  // Função que calcula os heads dos elementos

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

  g = 9.81;
  N_D = length(D);
  F_PI = [];
  v_PI = [];
  for j = 1:N_D
    Dj = D(j);
    
    A=Area(Dj);
    v=Velocidade(d,k_PI,A);
    Re=Reynolds(d,ni,Dj,v);
    LD = L.*(Dj.^-1);
    epD = ep.*(Dj.^-1);
    
    f=fatorDarcy(Re,epD);
    fT=fatorDarcy(1e8,epD);
    
    F_PIj = 0.5.*(f.*LD+fT.*LDac).*v.^2./g + Fac;
    F_PI = [F_PI F_PIj(:)];
    v_PI = [v_PI v(:)];
    
  end
             
endfunction

function [x1,u1,eh_inviavel] = geraEstimativaInicial(i,parametros)
    
    N_D   = parametros.N_D;
    S_PI  = parametros.S_PI;
    C2x   = parametros.C2x;
    b2    = parametros.b2(:,i);

    Sx = N_D*S_PI;
    
    // Forçando maiores diametros
    x1             = zeros(Sx,1);
    x1(N_D:N_D:Sx) = 1; 
    u1 = (b2-C2x*x1);

    eh_inviavel=~isempty(find(u1<0));
    
endfunction

function [x2,u2,dados2,opt] = resolveLP(indice,x1,u1,dados,parametros)
    
  p   = parametros.p;
  C1x = parametros.C1x;
  C2x = parametros.C2x;
  C1u = parametros.C1u;
  C2u = parametros.C2u;
  b1  = parametros.b1;
  b2  = parametros.b2(:,indice);
  Mix = parametros.Mix;
  N_CEN = parametros.N_CEN;
  S_HE= parametros.S_HE;
  N_D = parametros.N_D;
  S_PI= parametros.S_PI;
  D   = parametros.D;
  DN  = parametros.DN;
  ind = dados.REDE_ARESTA_LINHA.ind;
  C_PI = parametros.C_PI;
  ci  = parametros.ci;
  cs  = parametros.cs;

  Sx = N_D*S_PI;
  Six = size(Mix,1);
  C1xix = C1x*Mix';
  C2xix = C2x*Mix';
  b = [b1;b2];

  metodo_linpro=0;
  
  if (metodo_linpro==1)
      pix = [Mix*p;zeros(N_CEN*S_HE,1)]
      Cix = [C1xix C1u;C2xix C2u];
      ciix=[Mix*ci(1:Sx);ci((Sx+1):(Sx+N_CEN*S_HE))];
      csix=[Mix*cs(1:Sx);cs((Sx+1):(Sx+N_CEN*S_HE))];
      me=length(b);
      zin = [Mix*x1;u1];
      zout=linpro(pix,Cix,b,ciix,csix,me,zin);
  else
      pix = Mix*p;
      a = [C1xix C1u;C2xix C2u];
      c = [pix(:);zeros(N_CEN*S_HE,1)];
      zout = fpl(-c,[],[],[],[],a,b);
  end
  
  x2    = zeros(S_PI*N_D,1);
  x2    = Mix'*zout(1:Six);
  u2    = zout((Six+1):(Six+N_CEN*S_HE));

  [xopt,Dmin,xmin,Dmax,xmax,DNmin,DNmax,custo] = x2D_via_SplitPipe(x2,D,DN,C_PI);
  
  dados2=dados;
  dados2.REDE_ARESTA_BOMBA.curve=dados.OPT_CURVA.tag(indice);
  dados2.REDE_ARESTA_LINHA.DIA      = DNmin;
  dados2.REDE_ARESTA_LINHA.xsplit   = xmax;
  dados2.REDE_ARESTA_LINHA.DIAsplit = DNmax;
  for i=1:N_CEN
      dados2.REDE_ARESTA_TROC.Fac(:,i)     = u2((i-1)*S_HE+(1:S_HE));
  end

  opt.indice  = indice;
  opt.x0      = x2;
  opt.u       = u2;
  opt.xopt    = xopt;
  opt.xmin    = xmin;
  opt.xmax    = xmax;
  opt.Dmin    = Dmin;
  opt.Dmax    = Dmax;
  opt.DNmin   = DNmin;
  opt.DNmax   = DNmax;
  opt.custo_PI= custo;
  
endfunction

function  [x3,u3,dados2,opt]=resolveQP(indice,x2,u2,dados,parametros)
    
  Q   = parametros.Q;
  p   = parametros.p;
  C1x = parametros.C1x;
  C2x = parametros.C2x;
  C1u = parametros.C1u;
  C2u = parametros.C2u;
  b1  = parametros.b1;
  b2  = parametros.b2(:,indice);
  N_CEN = parametros.N_CEN;
  Mix = parametros.Mix;
  S_HE= parametros.S_HE;
  N_D = parametros.N_D;
  S_PI= parametros.S_PI;
  C_PI= parametros.C_PI;
  ci  = parametros.ci;
  cs  = parametros.cs;
  ind = dados.REDE_ARESTA_LINHA.ind;
  D   = parametros.D;
  DN  = parametros.DN;
  C_PI = parametros.C_PI;

  Sx = N_D*S_PI;
  Six = size(Mix,1);
  
  C1xix = C1x*Mix';
  C2xix = C2x*Mix';
  Qix=[Mix*Q*Mix' zeros(Six,N_CEN*S_HE);zeros(N_CEN*S_HE,Six) zeros(N_CEN*S_HE,N_CEN*S_HE)];
  pix = [Mix*p;zeros(N_CEN*S_HE,1)]
  Cix = [C1xix C1u;C2xix C2u;[Mix*p]' zeros(1,N_CEN*S_HE)];
  b = [b1;b2;p'*x2];
  
  ciix=[Mix*ci(1:Sx);ci((Sx+1):(Sx+N_CEN*S_HE))];
  csix=[Mix*cs(1:Sx);cs((Sx+1):(Sx+N_CEN*S_HE))];
  me=length(b);
  
  zin = [Mix*x2;u2];
  
  try 
      zout=quapro(Qix,zeros(pix),Cix,b,ciix,csix,me,zin);
      disp('QP resolvido.')
  catch
      zout = zin;
      disp('QP falhou.')
  end

// disp([zout zin])
// pause

  
  //disp([Cix*zout b]);  
  
  // [x,lagr,f]=quapro(Q,p,C,b,ci,cs,me,x0 [,imp])
  //   min 0.5*x'*Q*x + p'*x
  //    s.a.
  //       C(j,:) x = b(j),  j=1,...,me
  //       C(j,:) x <= b(j), j=me+1,...,me+md
  //       ci <= x <= cs

  x3    = zeros(S_PI*N_D,1);
  x3    = Mix'*zout(1:Six);
  u3    = zout((Six+1):(Six+N_CEN*S_HE));
  
  [xopt,Dmin,xmin,Dmax,xmax,DNmin,DNmax,custo] = x2D_via_SplitPipe(x3,D,DN,C_PI);
  
  dados2=dados;
  dados2.REDE_ARESTA_BOMBA.curve=dados.OPT_CURVA.tag(indice);
  dados2.REDE_ARESTA_LINHA.DIA      = DNmin;
  dados2.REDE_ARESTA_LINHA.xsplit   = xmax;
  dados2.REDE_ARESTA_LINHA.DIAsplit = DNmax;
  for i=1:N_CEN
      dados2.REDE_ARESTA_TROC.Fac(:,i)     = u3((i-1)*S_HE+(1:S_HE));
  end

  opt.indice  = indice;
  opt.x0      = x3;
  opt.u       = u3;
  opt.xopt    = xopt;
  opt.xmin    = xmin;
  opt.xmax    = xmax;
  opt.Dmin    = Dmin;
  opt.Dmax    = Dmax;
  opt.DNmin   = DNmin;
  opt.DNmax   = DNmax;
  opt.custo_PI= custo;
  opt.C_PI    = C_PI;

endfunction
