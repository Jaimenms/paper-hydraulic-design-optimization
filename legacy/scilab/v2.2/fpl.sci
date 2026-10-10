function [xsolucao,viab]=fpl(c,A1,b1,A2,b2,A3,b3)
// Método Simplex Revisado de Programação Linear
// Fase 1/Fase 2
//
// Problema: max c'x
//           sa:
//		A1x >= b1
//		A2x <= b2		b1,b2,b3 quaisquer
//		A3x =  b3
//		x>=0		
// Não existindo o bloco de restrições correspondente inserir o argumento []



// Preparação

// Inicalização da semente randômica
rand('seed',getdate('s'));

// Dimensões do problema
no=length(c); , m=length([b1;b2;b3]); , md=length([b1;b2]); , n=no+md;

// Preparação I - b1 , b2 , b3 >= 0
A1_=A1;  , b1_=b1;
if mtlb_any(b1<0) | mtlb_any(b2<0)
   // Preparação A1/b1
   i=find(b1>=0); , A1=A1(i,:); , b1=b1(i);
   i=find(b2<0); , A1=[ A1 ; -A2(i,:) ]; , b1=[ b1 ; -b2(i) ];
   // Preparação A2/b2
   i=find(b2>=0); , A2=A2(i,:); , b2=b2(i);
   i=find(b1_<0); , A2=[ A2 ; -A1_(i,:) ]; , b2=[ b2 ; -b1_(i) ];
end
if mtlb_any(b3<0)
   // Preparação A3/b3
   i=find(b3<0); , A3(i,:)=-A3(i,:); , b3(i)=-b3(i);
end

// Preparação II - A/b/c
nb1=length(b1); , nb2=length(b2); , nb3=length(b3);
if nb1==0 , A11=[]; , else , A11=-eye(nb1,nb1); , end
if nb2==0 , A22=[]; , else , A22=eye(nb2,nb2);  , end
if nb1*nb2==0
   A12=[]; , A21=[];
else
   A12=zeros(nb1,nb2); , A21=zeros(nb2,nb1);
end
if nb1*nb3==0 , A31=[]; , else , A31=zeros(nb3,nb1); , end
if nb2*nb3==0 , A32=[]; , else , A32=zeros(nb3,nb2); , end
A=[ A1, A11 , A12 ; A2 , A21 , A22 ; A3 , A31 , A32 ];
b=[ b1 ; b2 ; b3 ];
c=[ c ; zeros(md,1) ];


// Problema de Viabilidade

// Definição do PV
cb=ones(m,1); , cn=zeros(n,1);
B=eye(m,m); , N=A;
Bi=B;

// Pivotamento
// Observação: As macro-posições quando pivotadas ganham o índice "p"
cnp=cb'*A; , dp=cb'*b;
Np=N; , bp=b;

// Ordenação das variáveis
ordb=(n+1:n+m)'; , ordn=(1:n)';

// Resolução do PV
warning off
delta=1e-10;
while mtlb_any(cnp>delta) | (dp==0 & mtlb_any(ordb>n))
      
      // Identificação do pivot (j,k)
      if mtlb_all(cnp<=delta) & dp==0 & mtlb_any(ordb>n)
         j=find(ordb>n); , j=j(1);
         k=find(Np(j,:)~=0 & ordn'<=n); , k=k(1);
      else
         [lixo,ordcoef]=gsort(cnp);
         ncoefp=sum(cnp>delta);
         idpivot=0; , cont=0; , deg=0;
         while idpivot==0
               cont=cont+1;
               if deg==0
                  k=ordcoef(cont);
               else
                  k=ordcoef(ceil(rand(1,1)*ncoefp)); , idpivot=1;
               end
               razao=bp./(Np(:,k)+1e-10);
               i=find(razao>=0 & Np(:,k)>0);
               [lixo,ii]=min(razao(i));
               j=i(ii);
               if deg==0
                  if bp(j)~=0
                  idpivot=1;
               else
                  if ncoefp==cont , deg=1; , end
               end
         end
      end
      end

      // Armazenamento do Tableau atual
      cb_=cb; , cn_=cn; , B_=B; , N_=N; , ordb_=ordb; , ordn_=ordn;

      // Atualização dos coeficientes da função objetivo
      cb(j)=cn_(k); , cn(k)=cb_(j);

      // Atualização das matrizes das restrições
      B(:,j)=N_(:,k); , N(:,k)=B_(:,j);

      // Atualização da inversa de B
      Bi=inv(B);

      // Atualização do ordenamento
      ordb(j)=ordn_(k); , ordn(k)=ordb_(j);

      // Pivotamento
      cnp=-cn'+cb'*Bi*N; , dp=cb'*Bi*b;
      Np=Bi*N; , bp=Bi*b;

      // Correção
      bp(find(bp<0))=0;
      if abs(dp)<1e-10 , dp=0; , end
      Np(find(abs(Np)<1e-10))=0;

end

// Finalização
resultado=[ bp ; zeros(n,1) ];
[lixo,ordenacao]=gsort([ -ordb ; -ordn ]); , resultado=resultado(ordenacao);
zv=resultado(n+1:n+m);


// Verificação da existência de região viável
if mtlb_all(zv==0)


// Problema Original

// Definição do PO
clear cb cn B N b
cb=c(ordb); , i=find(ordn<n+1); , cn=c(ordn(i));
B=eye(m,m); , N=Np(:,i); , b=bp;
Bi=B;

// Pivotamento
// Observação: As macro-posições quando pivotadas ganham o índice "p"
clear cnp dp Np bp dparm
cnp=-cn'+cb'*N; , dp=cb'*b;
Np=N; , bp=b;

// Ordenação das variáveis
ordn=ordn(i);

// Resolução do PO
nlim=[]; , delta=1e-10;
while mtlb_any(cnp<-delta)

      // Identificação de ótimo não limitado;
      nlim=find(sum(Np>0)==0 & cnp<0);
      if ~isempty(nlim) , break , end

      // Identificação do pivot (j,k)
      [lixo,ordcoef]=gsort(-cnp);
      ncoefn=sum(cnp<-delta);
      idpivot=0; , cont=0; , deg=0;
      while idpivot==0
            cont=cont+1;
            if deg==0
               k=ordcoef(cont);
            else
               k=ordcoef(ceil(rand(1,1)*ncoefp)); , idpivot=1;
            end
            razao=bp./(Np(:,k)+1e-10);
            i=find(razao>=0 & Np(:,k)>0);
            [lixo,ii]=min(razao(i));
            j=i(ii);
            if deg==0
               if bp(j)~=0
                  idpivot=1;
               else
                  if ncoefn==cont , deg=1; , end
               end
            end
      end

      // Armazenamento do Tableau atual
      cb_=cb; , cn_=cn; , B_=B; , N_=N; , ordb_=ordb; , ordn_=ordn;

      // Atualização dos coeficientes da função objetivo
      cb(j)=cn_(k); , cn(k)=cb_(j);

      // Atualização das matrizes das restrições
      B(:,j)=N_(:,k); , N(:,k)=B_(:,j);

      // Atualização da inversa de B
      Bi=inv(B);

      // Atualização do ordenamento
      ordb(j)=ordn_(k); , ordn(k)=ordb_(j);

      // Pivotamento
      cnp=-cn'+cb'*Bi*N; , dp=cb'*Bi*b;
      Np=Bi*N; , bp=Bi*b;

      // Correção
      bp(find(bp<0))=0;
      Np(find(abs(Np)<1e-10))=0;

end

// Finalização
if ~isempty(nlim)
   xsolucao=[]; , viab=[];
   disp('Ótimo não limitado')
else
   clear resultado ordenacao
   resultado=[ bp ; zeros(no,1) ];
   [lixo,ordenacao]=gsort([ -ordb ; -ordn ]); , resultado=resultado(ordenacao);
   xsolucao=resultado(1:no); , viab=1;
   // Identificação de infinitas soluções
   if mtlb_any(cnp==0) , disp('Infinitas soluções') , end   
end

// Sem região viável
else , xsolucao=[]; , viab=0; , disp('Não há região viável') , end

warning on

// Finalização da função
endfunction