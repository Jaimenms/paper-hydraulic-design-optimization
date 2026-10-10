function [C,q_gpm,H_ft,Pot_HP] =price(m,H,ro,efic)

// Propriedades e constantes físicas
g = 9.81;
//ro = 1e3;

// Passagem para vazão volumétrica (m^3/s para kg/s)
q = m / ro;

// Conversão de unidades
q_gpm = q * 3600 / 2.271247e-1;
H_ft = H / .3048;

// Cálculo da potência
//efic=0.7
Pot = q * H * ro * g / efic;
Pot_HP = Pot / 745.6;

// Cálculo do custo base
alfa = log( q_gpm .* sqrt(H_ft) );
Cb = 1.39 * exp( 8.833 - 0.6019 * alfa + 0.0519 * alfa .^2);

// Fator de correção do material
// 1 = Ferro fundido , 1.35 = Aço fundido , 2 = Aço inox
Fm = 1.35;

// Fator de correção do tipo de bomba (vide quadro no final do arquivo)
ptype = 2;
b = [ 0          0          0
      5.1029    -1.2217    0.0771 
      0.0632     0.2744    -0.0253
      2.0290    -0.2371    0.0102
      13.7321   -2.8304    0.1542
      9.8849    -1.6164    0.0834 ];
Ft = exp( b(ptype,1) + b(ptype,2) * alfa + b(ptype,3) * alfa.^2 ) ;

// Fator de correção do custo de instalação
Fi = 2.8;

// Fator Marshall & Swift
MS = 1457.4 / 1123.6; // (2009 / 2003)

// Preço do equipamento
p = MS * Fm * Ft .* Cb;

// Custo instalado
C = Fi * p;

// Tipos de bomba
//
// 1 = 1 Estágio     / 3550 rpm / VSC / q(gpm) = 50-900   / H(ft) = 50-400   / Potmax(HP) = 75
// 2 = 1 Estágio     / 1750 rpm / VSC / q(gpm) = 50-3500  / H(ft) = 50-200   / Potmax(HP) = 200
// 3 = 1 Estágio     / 3550 rpm / HSC / q(gpm) = 100-1500 / H(ft) = 100-450  / Potmax(HP) = 150
// 4 = 1 Estágio     / 1750 rpm / HSC / q(gpm) = 250-5000 / H(ft) = 50-500   / Potmax(HP) = 250
// 5 = 2 Estágios    / 3550 rpm / HSC / q(gpm) = 50-1100  / H(ft) = 300-1100 / Potmax(HP) = 250
// 6 = Multiestágios / 3550 rpm / HSC / q(gpm) = 100-1500 / H(ft) = 650-3200 / Potmax(HP) = 1450
// HSC = Horizontal Split Casing , VSC = Vertical Split Casing

endfunction