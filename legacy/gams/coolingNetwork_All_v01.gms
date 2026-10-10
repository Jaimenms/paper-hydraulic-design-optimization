Sets
     p   pipes    / pipe01, pipe02 /
     n   subsections    / 1.50, 0.75, 1.00, 1.25, 1.50, 2.00, 2.50, 3.00,
                          3.50, 4.00, 5.00, 6.00, 8.00, 10.0, 12.0, 14.0,
                          16.0, 18.0, 20.0, 24.0 /
     h   heat-exchanger   / E-101, E-102, E-103, E-104, E-105 /
     i   pump curve polynomial index  / 0, 1, 2 /
     j   pump cost index  / 1, 2, 3 /
     s   pump option / 1, 2, 3, 4 /
;

* general parameters
Scalar g gravity acceleration /9.8/;

* network
Scalar dz  head difference betweeen source and demand  /-5/ ;
Table khi(h,p)  hydraulic circuit incidence
            pipe1    pipe2
      E-101  1        1    ;

* design
Scalar vmax maximum flow velocity /3.7/;
Scalar nop number of operating hours /8760/;
Scalar pc energy cost /0.1/;
Scalar irate interest rate /0.12/;
Scalar ny project horizon /20/;
Parameter rfactor annualizing factor ;
         rfactor = irate*((1+irate)^ny+0)/((1+irate)^ny-1)
* fluid
Scalar rho water density  /995/ ;
Scalar ni water viscosity /0.00072/ ;
Scalar cp cooling water heat capacity /4187/;
Scalar tin cooling water inlet temperature /32/;

* pumps
Scalar eta pump efficiency /0.60/ ;
Scalar fi pump capital cost factor fi /2.8/;
Scalar fms pump capital cost factor fms /1.3/;
Scalar fm pump capital cost factor fm /1.35/;
Table a(i,s) pump curve coeficient
                1      2      3      4
           0   31.5   37.8   42.0   46.2
           1 -135   -162   -180   -198
           2 -415.6 -498.7 -554.1 -609.5 ;
Parameter b(j) pump capital cost factor
      /  1  5.1029
         2 -1.2217
         3  0.0771 /;
Parameter ft(s) pump capital cost factor ft;
     ft(s) = exp(sum(j,b(j)*(ln(28710*kpud/rho*fpud(s)^0.5)^(j-1)) ;
Parameter zpu(s) pump capital cost factor zpu;
      zpu(s) = 28710*kpud/rho*fpud(s)^0.5 ;
Parameter cpu(s) pump cost ;
       cpu(s) = rfactor*fi*fms*fm*ft(s)*(1.39*exp(8.833-0.6019*ln(zpu(s))+0.0519*(ln(zpu))^2))
Parameter cop(s) operational cost ;
       cop(s) = kpu*g*fpu(s)/eta*(nop*pc/1000)

* heat exchanger
Scalar alfa heat exchanger head loss parameter /1.8/ ;
Parameter khed(h) mass flow rate in heat exchanger for design conditions
         / E-101 11.8
           E-102 28.7
           E-103 35.6
           E-104 15.6
           E-105 3.1 /;

Parameter fhed(h) head loss in heat exchanger for design conditions
         / E-101 5.4
           E-102 6.2
           E-103 4.7
           E-104 2.8
           E-105 1.2 /;

* pipes
Scalar ep pipe rougthness /0.000046/;
Scalar c1 pipe capital cost factor c1 /7.0386/;
Scalar m pipe capital cost factor m /1.4393/;
Parameter l(p) pipe length
       / 1 100
         2 100 /;
Parameter din(n)  internal diameter
       /  1.50 15.8
          0.75 21.0
          1.00 26.6
          1.25 35.1
          1.50 40.9
          2.00 52.5
          2.50 62.7
          3.00 77.9
          3.50 90.1
          4.00 102.3
          5.00 128.2
          6.00 154.1
          8.00 202.7
          10.0 254.5
          12.0 303.3
          14.0 333.3
          16.0 381.0
          18.0 428.7
          20.0 477.8
          24.0 574.6 /;
Parameter dnom(n)  nominal diameter
       /  1.50 1.50
          0.75 0.75
          1.00 1.00
          1.25 1.25
          1.50 1.50
          2.00 2.00
          2.50 2.50
          3.00 3.00
          3.50 3.50
          4.00 4.00
          5.00 5.00
          6.00 6.00
          8.00 8.00
          10.0 10.0
          12.0 12.0
          14.0 14.0
          16.0 16.0
          18.0 18.0
          20.0 20.0
          24.0 24.0 /;

* hydraulics

Parameter vpi(p,n) velocity ;
          vpi(p,n) = kpi(p) / rho * (4/(pi*din(n)^2)

Parameter Redarcy(p,n) Reynolds number ;
         Redarcy(p,n) = din(n).*abs(vpi(n,p)).*rho./ni;

Parameter Adarcy(p,n) A Darcy ;
         Adarcy(p,n)=(2.457.*log((0.27.*(ep/din(p,n))+(7.*(Redarcy(p,n).^(-1))).^0.9).^(-1))).^16;

Parameter Bdarcy(p,n) A Darcy ;
         Bdarcy(p,n)=(37530.*(Redarcy(p,n).^(-1))).^16;

Parameter fdarcy(p,n) Darcy factor ;
          fdarcy(p,n) = 8.*((8.*(Redarcy(p,n).^(-1))).^12+(Adarcy(p,n)+Bdarcy(p,n)).^(-1.5)).^(1./12) ;

Parameter fpi(p,n) head loss in pipe section per length ;
          fpi(p,n) = fdarcy * (1/din(n)) * vpi(p,n) / (2*g) ;

Parameter fhe(h) head loss in heat exchanger ;
          fhe(h) = fhed(h) * (khe(h)/khed(h))^alfa  ;

Parameter fpu(s) pump head ;
          fpu(s)= sum(i,a(i,s)*(kpu/rho)^i) ;

Parameter cpi(n) pipe section nominal cost ;
          cpi(n) = (C1/0.3048)*(dnom(n)/12)^m

Variable x(p,n)  mass flow rate at edges  ;
         x.up(p,n) = 1 ;
         x.lo(p,n) = 0 ;


loop (s,
         Variable totalcost(s) totalcost  ;

         Positive Variable x ;

         Equations
              pipeunity(p)   pipe unity
              hydraulics(h)  hydraulic constraints
              cost           total cost

         pipeunity(p) ..  1 =e= sum(n, x(p,n)) ;
         hydraulics(h) .. sum( (p,n), khi(h,p)*fpi(p,n)*x(p,n)*l(p) ) + fpe(h) - fpu(s) - dz =e= 0 ;
         cost .. totalcost =e= sum((p,n),cpi(n)*x(p,n)*l(p)) + cpu(s) + cop(s) ;

         Model cooling /all/ ;

         Solve cooling using lp minimizing totalcost ;

         Display x.l, x.m, totalcost.l;
);