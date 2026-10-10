function [f,G] = objfun ( x )
  
  f = 0.5.*x(:)'*OPT.Q*x(:);
  G = OPT.Q*x(:);
  
  Ceq=[OPT.C];
  beq=[OPT.b];

  C=[OPT.p(:)'];
  b=[OPT.p(:)'*OPT.x2];

  c=C*x(:)-b;
  ceq=Ceq*x(:)-beq;
  
  mprintf('---> fob: '+string(f)+'   /   residuo: '+string(norm(ceq))+'   /   variacao custo: '+string(c))
  
endfunction
