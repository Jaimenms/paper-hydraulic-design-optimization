
load rede13_sensib.dat;

saidas.fob_QPMIN=[];
saidas.Cop_PU_QPMIN=[];
saidas.C_PU_QPMIN=[];
saidas.Cop_PI_QPMIN=[];
for i=1:length(saidas.pc)
    [aux,k] = min([saidas.fob_QP1(i);saidas.fob_QP2(i);saidas.fob_QP3(i);saidas.fob_QP4(i)]);
    if k==1, saidas.fob_QPMIN(i)=saidas.fob_QP1(i); saidas.Cop_PU_QPMIN(i)=saidas.Cop_PU_QP1(i); saidas.C_PU_QPMIN(i)=saidas.C_PU_QP1(i); saidas.C_PI_QPMIN(i)=saidas.C_PI_QP1(i);saidas.Tho_QPMIN(:,i)=saidas.Tho_QP1(:,i);end
    if k==2, saidas.fob_QPMIN(i)=saidas.fob_QP2(i); saidas.Cop_PU_QPMIN(i)=saidas.Cop_PU_QP2(i); saidas.C_PU_QPMIN(i)=saidas.C_PU_QP2(i); saidas.C_PI_QPMIN(i)=saidas.C_PI_QP2(i);saidas.Tho_QPMIN(:,i)=saidas.Tho_QP2(:,i);end
    if k==3, saidas.fob_QPMIN(i)=saidas.fob_QP3(i); saidas.Cop_PU_QPMIN(i)=saidas.Cop_PU_QP3(i); saidas.C_PU_QPMIN(i)=saidas.C_PU_QP3(i); saidas.C_PI_QPMIN(i)=saidas.C_PI_QP3(i);saidas.Tho_QPMIN(:,i)=saidas.Tho_QP3(:,i);end
    if k==4, saidas.fob_QPMIN(i)=saidas.fob_QP4(i); saidas.Cop_PU_QPMIN(i)=saidas.Cop_PU_QP4(i); saidas.C_PU_QPMIN(i)=saidas.C_PU_QP4(i); saidas.C_PI_QPMIN(i)=saidas.C_PI_QP4(i);saidas.Tho_QPMIN(:,i)=saidas.Tho_QP4(:,i);end
    saidas.indice_QPMIN(i)=k;
    
end

figure('BackGroundColor',[1 1 1]);

ix = saidas.fob_classic==0;
saidas.fob_classic(ix)=%nan;
saidas.Cop_PU_classic(ix)=%nan;
saidas.C_PU_classic(ix)=%nan;
saidas.C_PI_classic(ix)=%nan;
saidas.Tho_classic(1,ix)=%nan;
saidas.Tho_classic(2,ix)=%nan;
saidas.Tho_classic(3,ix)=%nan;
saidas.Tho_classic(4,ix)=%nan;
saidas.Tho_classic(5,ix)=%nan;
ix = saidas.fob_classic2==0;
saidas.fob_classic2(ix)=%nan;
saidas.Cop_PU_classic2(ix)=%nan;
saidas.C_PI_classic2(ix)=%nan;
saidas.C_PU_classic2(ix)=%nan;
saidas.Tho_classic2(1,ix)=%nan;
saidas.Tho_classic2(2,ix)=%nan;
saidas.Tho_classic2(3,ix)=%nan;
saidas.Tho_classic2(5,ix)=%nan;

ix= saidas.pc>0.03 & saidas.pc<=0.15;

saidas.fob_classic2(saidas.fob_classic2==0)=%nan;
plot(saidas.pc(ix),saidas.fob_QP1(ix),'kx-',...
     saidas.pc(ix),saidas.fob_QP2(ix),'k:',...
     saidas.pc(ix),saidas.fob_QP3(ix),'k-.',...
     saidas.pc(ix),saidas.fob_QP4(ix),'k.-','thickness',2,'markersize',3)
legenda(1) = 'Curve 1';
legenda(2) = 'Curve 2';
legenda(3) = 'Curve 3';
legenda(4) = 'Curve 4';
a=get("current_axes");
a.title.text='Objective Function: Proposed Method';
a.y_label.text='USD/Year';
a.x_label.text='Energy Cost (USD/kWh)';
b=legend(legenda,2); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;

drawnow

figure('BackGroundColor',[1 1 1]);
ix= saidas.pc>0.03 & saidas.pc<=0.15;
saidas.fob_classic(saidas.fob_classic==0)=%nan;
saidas.fob_classic2(saidas.fob_classic2==0)=%nan;
plot(saidas.pc(ix),saidas.fob_classic(ix),'k.-',...
     saidas.pc(ix),saidas.fob_classic2(ix),'k:',...
     saidas.pc(ix),saidas.fob_QPMIN(ix),'k-','thickness',2,'markersize',3)
legenda(1) = 'Himmelblau Method';
legenda(2) = 'Towler Method';
legenda(3) = 'Proposed Method';
a=get("current_axes");
a.title.text='Objective Function: Comparison';
a.y_label.text='USD/Year';
a.x_label.text='Energy Cost (USD/kWh)';
b=legend(legenda,2); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;

drawnow


figure('BackGroundColor',[1 1 1]);
ix= saidas.pc>0.03 & saidas.pc<=0.15;
saidas.fob_classic(saidas.fob_classic==0)=%nan;
saidas.fob_classic2(saidas.fob_classic2==0)=%nan;
plot(saidas.pc(ix),-100.*(saidas.fob_QPMIN(ix)-saidas.fob_classic(ix))./saidas.fob_classic(ix),'k.-',...
     saidas.pc(ix),-100.*(saidas.fob_QPMIN(ix)-saidas.fob_classic2(ix))./saidas.fob_classic2(ix),'k:','thickness',2,'markersize',3)
legenda(1) = 'Compared to Himmelblau Method';
legenda(2) = 'Compared to Towler Method';
b=legend(legenda,1); b.background= 8;
set(b,'font_size',2)
a=get("current_axes");
a.title.text='Cost Reduction with Proposed Methodology';
a.y_label.text='%';
a.x_label.text='Energy Cost (USD/kWh)';
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;

drawnow



figure('BackGroundColor',[1 1 1]);
plot(saidas.pc(ix),saidas.Cop_PU_classic(ix),'k.-',...
    saidas.pc(ix),saidas.Cop_PU_classic2(ix),'k:',...
     saidas.pc(ix),saidas.Cop_PU_QPMIN(ix),'k-','thickness',2,'markersize',3)
xtitle('Pump Operational Cost', 'Energy Cost (USD/kWh)', 'USD/Year') ;
legenda(1) = 'Himmelblau Method';
legenda(2) = 'Towler Method';
legenda(3) = 'Proposed Method';
a=get("current_axes");
a.title.text='Pump Operational Cost';
a.y_label.text='USD/Year';
a.x_label.text='Energy Cost (USD/kWh)';
b=legend(legenda,2); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;
drawnow

figure('BackGroundColor',[1 1 1]);
plot(saidas.pc(ix),saidas.C_PU_classic(ix),'k.-',...
saidas.pc(ix),saidas.C_PU_classic2(ix),'k:',...
     saidas.pc(ix),saidas.C_PU_QPMIN(ix),'k-','thickness',2,'markersize',3)
xtitle('Pump Cost', 'Energy Cost (USD/kWh)', 'USD/Year') ;
legenda(1) = 'Himmelblau Method';
legenda(2) = 'Towler Method';
legenda(3) = 'Proposed Method';
a=get("current_axes");
a.title.text='Pump Cost';
a.y_label.text='USD/Year';
a.x_label.text='Energy Cost (USD/kWh)';
b=legend(legenda,1); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;
drawnow

figure('BackGroundColor',[1 1 1]);
plot(saidas.pc(ix),saidas.C_PI_classic(ix),'k.-',...
     saidas.pc(ix),saidas.C_PI_classic2(ix),'k:',...
     saidas.pc(ix),saidas.C_PI_QPMIN(ix),'k-','thickness',2,'markersize',3)
xtitle('Pipe Cost', 'Energy Cost (USD/kWh)', 'USD/Year') ;
legenda(1) = 'Himmelblau Method';
legenda(2) = 'Towler Method';
legenda(3) = 'Proposed Method';
a=get("current_axes");
a.title.text='Pipe Cost';
a.y_label.text='USD/Year';
a.x_label.text='Energy Cost (USD/kWh)';
b=legend(legenda,4); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;
drawnow



figure('BackGroundColor',[1 1 1]);
plot(saidas.pc(ix),saidas.Tho_classic(4,ix),'k.-',...
saidas.pc(ix),saidas.Tho_classic2(4,ix),'k:',...
     saidas.pc(ix),saidas.Tho_QPMIN(4,ix),'k-',...
     saidas.pc(ix),41.*(ones(saidas.Tho_QPMIN(4,ix))),'r--','thickness',2,'markersize',3)
xtitle('Hot Stream Outlet Temperature (E-104)', 'Energy Cost (USD/kWh)', '°C') ;
legenda(1) = 'Himmelblau Method';
legenda(2) = 'Towler Method';
legenda(3) = 'Proposed Method';
legenda(4) = 'Design';
a=get("current_axes");
a.title.text='Hot Stream Outlet Temperature (E-104)';
a.y_label.text='USD/Year';
a.x_label.text='°C';
b=legend(legenda,2); b.background= 8;
set(b,'font_size',2)
a.font_size = 3;
a.title.font_size=4;
a.y_label.font_size= 4;
a.x_label.font_size= 4;
drawnow