function [saidas] = heatcheck(mc,parametros)  
  // Projeto de redes de distribui��o de �gua de resfriamento
  // Programa para as avalia��es dos desempenho dos trocadores presentes na rede
  // M�todo da efetividade
  
  // Dados de entrada da fun�ao
  // Notas explicativas:
  // (1) Para facilitar a manipula��o dos dados, as entradas est�o organizadas em listas
  // (2) Os elementos das listas correspondem a vetores de dimens�o (N�mero de trocadores x 1)
  //
  // Dados das correntes: data_str
  // mc       - Vaz�es m�ssicas das correntes frias (kg/s)
  // Cpc      - Capacidades calor�ficas das correntes frias (J/kgK)
  // Tci      - Temperaturas de entrada das correntes frias (C)
  // mh       - Vaz�es m�ssicas das correntes quentes (kg/s)
  // Cph      - Capacidades calor�ficas das correntes quentes (J/kgK)
  // Thi      - Temperaturas de entrada das correntes quentes (C)
  //
  // Dados dos trocadores: data_exch
  // A        - �reas dos trocadores
  // hi_sp    - Valores de projeto dos coeficientes de convec��o no interior dos tubos (W/m^2K)
  // he_sp    - Valores de projeto dos coeficientes de convec�ao no exterior dos tubos (W/m^2K)
  // Rfi      - Resist�ncias de dep�sito no interior dos tubos (m^2K/W)
  // Rfe      - Resist�ncias de dep�sito no exterior do casco (m^2K/W)
  // kt       - Condutividade t�rmica dos tubos (W/mK)
  // Dti      - Di�metro interno dos tubos (m)
  // Dte      - Di�metro externo dos tubos (m)
  // ic       - Identificadores da configura��o (1 = paralelo, 2 = contracorrente, 3 = 1:N)
  // it       - Identificadores do fluido que escoa no interior dos tubos (1 = frio, 0 = quente)
  // Tco_sp   - Valores de projeto das temperatura de sa�da das correntes frias (C)
  // Tho_sp   - Valores de projeto das temperaturas de sa�da das correntes quentes (C)
  // mc_sp    - Valores de projeto das vaz�es das correntes frias (kg/s)
  // mh_sp    - Valores de projeto das vaz�es das correntes quentes (kg/s)
  //
  //
  // Dados de sa�da da fun��o
  // Notas explicativas:
  // (1) As sa�das da fun��o s�o vetores com dimens�o (NHE x 1)
  //
  // Tco      - Temperaturas calculadas de sa�da das correntes frias (C)
  // Tho      - Temperaturas calculadas de sa�da das correntes quentes (C)
  // U        - Coeficientes globais de transfer�ncia de calor (W/m^2K)
  // DeltaTho - Diferen�as entre os valores de reais e de projeto das temperaturas de sa�da da correntes quentes (C)
  // Ratiomc  - Raz�o entre os valores reais e de projeto das vaz�es das correntes frias (kg/s)
  
  // Abertura das vari�veis
  Cpc=parametros.Cpc;
  Tci=parametros.Tci;
  Cph=parametros.Cph;
  Thi=parametros.Thi;
  Tho_sp=parametros.Tho_sp;
  Tco_sp=parametros.Tco_sp;
  
  A=parametros.A;
  hi_sp=parametros.hi_sp;
  he_sp=parametros.he_sp;
  Rfi=parametros.Rfi;
  Rfe=parametros.Rfe;
  kt=parametros.kt;
  Dti=parametros.Dti;
  Dte=parametros.Dte;
  ic=parametros.ic;
  it=parametros.it;
  
  mc_sp=parametros.mc_sp;
  mh=parametros.mh;
  mh_sp=mh;  
  Tho=Tho_sp;
  
  // Determina��o da raz�o entre as taxas de capacidade calor�fica
  
  // Taxas de capacidade calor�fica
  Ch = mh .* Cph;
  Cc = mc .* Cpc;
  Cmin = Cc .* (Cc<=Ch) + Ch .* (Cc>Ch);
  Cmax = Cc .* (Cc>Ch)  + Ch .* (Cc<=Ch);
  
  // Determina��o de Cr
  Cr = Cmin ./ Cmax;
  
  // Determina��o do n�mero de unidades de transfer�ncia
  
  // Determina��o dos coeficientes de convec��o
  hi = hi_sp .* ( (mc ./ mc_sp).*(it==1) + (mh ./ mh_sp).*(it==0) ).^0.8;
  he = he_sp .* ( (mc ./ mc_sp).*(it==0) + (mh ./ mh_sp).*(it==1) ).^0.6;
  
  // Determina��o dos coeficientes globais de transfer�ncia de calor
  U = 1 ./ ( (1 ./ hi) .* (Dte./Dti) + Rfi .* (Dte./Dti) + Dte .* log(Dte./Dti) ./ (2*kt) + Rfe + (1 ./ he) );
  
  // Determina��o de NUT
  NUT = U .* A ./ Cmin;
  
  // Determina��o da efetividade
  
  // Inicializa��o
  eff = zeros(NUT);
  
  // C�lculo da efetividade - Configura��o cocorrente
  i_c = find(ic==1);
  NUTi = NUT(i_c); , Cri = Cr(i_c);
  eff_co = ( 1 - exp( -NUTi .* (1 + Cri) ) ) ./ (1 + Cri);
  eff(i_c) = eff_co
  
  // C�lculo da efetividade - Configura��o contracorrente - Cr ~= 1
  i_c = find(ic==2 & Cr~=1);
  NUTi = NUT(i_c); , Cri = Cr(i_c);
  eff_cc = ( 1 - exp( -NUTi .* (1 - Cri) ) ) ./ (1 - Cri .* exp( -NUTi .* (1 - Cri) ));
  eff(i_c) = eff_cc;
  
  // C�lculo da efetividade - Configura��o contracorrente - Cr == 1
  i_c = find(ic==2 & Cr==1);
  NUTi = NUT(i_c); , Cri = Cr(i_c);
  eff_cc = NUTi ./ (1+NUTi);
  eff(i_c) = eff_cc;
  
  // C�lculo da efetividade - Configura��o 1-N
  i_c = find(ic==3);
  NUTi = NUT(i_c); , Cri = Cr(i_c);
  eff_1N = 2 ./ ( 1 + Cri + sqrt(1+Cri.^2) .* (1 + exp(-NUTi.*sqrt(1+Cri.^2))) ./ (1 - exp(-NUTi.*sqrt(1+Cri.^2))) );
  eff(i_c) = eff_1N;
  
  
  // Determina��o das temperaturas de sa�da
  
  // C�lculo da m�xima carga t�rmica
  Qmax = Cmin .* (Thi - Tci);
  
  // C�lculo da carga t�rmica
  Q = Qmax .* eff;
      
  // C�lculo de Tco e Tho
  Tco = Tci + Q ./ (mc .* Cpc);
  Tho = Thi - Q ./ (mh .* Cph);
  
  // Determina��o dos par�metros de desempenho  
  saidas.DeltaTho = Tho - Tho_sp;
  saidas.Ratiomc = mc ./ mc_sp;
  saidas.Tco = Tco;
  saidas.Tho = Tho;
  saidas.Tco_sp = Tco_sp;
  saidas.Tho_sp = Tho_sp;
  saidas.Tci = Tci;
  saidas.Thi = Thi;
  saidas.U = U;
  saidas.Q = Q;
  saidas.mc=mc;
  saidas.mh=mh;
  saidas.mc_sp=mc_sp;
  saidas.mh_sp=mh_sp;
  
endfunction