function [f,G,H] = objfungrad ( x )
  
  f = 0.5.*x(:)'*OPT.Q*x(:);
  G = OPT.Q*x(:);
  H = OPT.Q;
  
  Ceq=[OPT.C];
  beq=[OPT.b];

  C=[OPT.p(:)'];
  b=[1.0*OPT.p(:)'*OPT.x2];

  c=C*x(:)-b;
  ceq=Ceq*x(:)-beq;
  
  mprintf('-> fob: '+string(f)+' / xmin: '+string(min(x))+' / xmax: '+string(max(x))+' / res: '+string(norm(ceq))+' / delta custo: '+string(c)+'\n')
endfunction
