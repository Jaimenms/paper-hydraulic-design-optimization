function [f,G,H] = objfungrad2 ( x )
  
  custo=OPT.p(:)'*x(:);
  f = 0.5.*x(:)'*OPT.Q*x(:)+custo;
  G = OPT.Q*x(:)+OPT.p(:);
  H = OPT.Q;
  
  Ceq=[OPT.C];
  beq=[OPT.b];

  c=[];
  ceq=Ceq*x(:)-beq;
  
  mprintf('-> fob: '+string(f)+' / xmin: '+string(min(x))+' / xmax: '+string(max(x))+' / res: '+string(norm(ceq))+' / delta custo: '+string(custo)+'\n')
endfunction
