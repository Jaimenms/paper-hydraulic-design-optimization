Sets
     p   pipes    / pipe01, pipe02 /
     n   subsections    / sub01, sub02, sub03 /
     h   heat-exchanger   / he01 /;

Scalar dz  head difference betweeen demand and source  /5/ ;

Table khi(h,p)  hydraulic circuit incidence
            pipe1    pipe2    pipe3
      he01    1    1     1   ;

Parameter fpi(p,n) head loss in pipe section per length ;

          fpi(p,n) = dz ;

Parameter l(p) pipe length
     / pipe01 10
       pipe02 20/  ;

Parameter fpu pump head ;

          fpi= 1111 ;


Parameter picost(p) pipe cost;

Parameter pucost pump cost;

Parameter opcost operation cost;


Variable x(p,n)  mass flow rate at edges  ;

x.up(p,n) = 1 ;
x.lo(p,n) = 0 ;

Variable totalcost  totalcost  ;


Positive Variable x ;

Equations
     pipeunity(p)   pipe unity
     hydraulics(h)  hydraulic constraints
     cost   total cost

pipeunity(p) ..  1 =e= sum(n, x(p,n)) ;
hydraulics(h) .. sum( (p,n), khi(h,p)*fpi(p,n)*x(p,n)*l(p) ) + fpe(h) - fpu - dz =e= 0 ;
cost .. totalcost =e= sum(p,pipecost(p)) + pucost + opcost ;

Model cooling /all/ ;

Solve cooling using lp minimizing totalcost ;

Display x.l, x.m, totalcost.l;