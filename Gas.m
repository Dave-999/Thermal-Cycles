%function [] = GasTurbine(power, fuel, eta_piC, eta_piT, k_mec, T3, k_cc, lambda)
function [] = Gas()
%A faire varier:

P_e=230*10^6;
fuel = 'methane';
eta_piC=0.9;
eta_piT=0.9;
k_mec=0.015;
T3=1050+273.15; %valeur max
k_cc=0.95;
%lambda=1.04; %Exces d'air

if strcmp(fuel,'methane')
    methane=true;
else
    diesel=true;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%

%Propri�t�s invariantes
R=8.314472;
R_a=287.1;
x_O2_molar=0.21;
x_O2_massic=x_O2_molar*32/(x_O2_molar*32+(1-x_O2_molar)*28) %Fraction massique d'O2 dans l'air =cst
gamma=1.4;
r=10;
T1=50+273.15;
p1=10^5; %[Pa]
p2=p1*r;
p3=p2*k_cc;
p4=p3/k_cc/r;
h1=(x_O2_massic*janaf('h','O2',T1)+(1-x_O2_massic)*janaf('h','N2',T1))*1000 %[J/kg]
%s1=x_O2_massic*janaf('s','O2',T1)+(1-x_O2_massic)*janaf('s','N2',T1) %[]
s1=0
%Trouver T2 et T4
T2=T1*r^((gamma-1)/gamma/eta_piC)
T4=T3*(p3/p4)^(-eta_piT*(gamma-1)/gamma)

m_12=(1-((gamma-1)/gamma/eta_piC))^-1; %Polytropic coefficients
m_34=(1-((gamma-1)/gamma*eta_piT))^-1;

%h2=(x_O2_massic*janaf('h','O2',T2)+(1-x_O2_massic)*janaf('h','N2',T2))*1000 %[J/kg]
h2=h1+integral(@(t) x_O2_massic*janaf('c','O2',t)+(1-x_O2_massic)*janaf('c','N2',t),T1,T2)*1000 %(other way to get the same result)
s2=s1+integral(@(t) (x_O2_massic*janaf('c','O2',t)+(1-x_O2_massic)*janaf('c','N2',t))./t,T1,T2)*(1-eta_piC)

if methane
    LHV_massic=5*10^7; %[J/kg] http://www.engineeringtoolbox.com/fuels-higher-calorific-values-d_169.html
    LHV_molar=LHV_massic*16/1000 %[J/mol]
    %x_H2O=2*(18/48)/(1+(2*18/48))
    m_a1=2*2/x_O2_massic %CH4 + 2 O2 = CO2 + 2 H2O
    lambda=1/2 * (LHV_molar-(janaf('h','CO2',T3)-janaf('h','CO2',T2))*44+2*(janaf('h','H2O',T3)-janaf('h','H2O',T2))*18+2*(janaf('h','O2',T3)-janaf('h','O2',T2))*32) / ((janaf('h','O2',T3)-janaf('h','O2',T2))*32+3.762*(janaf('h','N2',T3)-janaf('h','N2',T2))*28)
    flue_gas_molar_mass=(16+lambda*m_a1*16)/(1+2+lambda*m_a1*(1-x_O2_massic)*16/28+lambda*m_a1*x_O2_massic*16/32-2)/1000 %[kg/mol]
    R_g=R/flue_gas_molar_mass
    h3=h2+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))/(1+lambda*m_a1),T2,T3)*1000
    s3=s2+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T2,T3)-R_g*log(p3/p2)/1000
    h4=h3+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))/(1+lambda*m_a1),T3,T4)*1000    
    s4=s3-(1-eta_piT)/eta_piT*integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T3,T4)

    syms ma mc
    [m_a, m_c] = vpasolve([lambda*m_a1 == ma/mc,...
        P_e == (ma+mc)*(h3-h4)*(1-k_mec)...
        -  ma*(h2-h1)*(1+k_mec)... %Eq 3.1
        %mc*LHV== (ma+mc)*h3-ma*h2... %autre �quation possible � la place
        %de celle de P_e
        ],[ma, mc])
    
    m_g=m_a+m_c;
    
else
    LHV_massic=43.4*10^6; %Diesel(gazole) [J/kg]
    LHV_molar=LHV_massic*167/1000
    m_a1=(71/4)*(32/167)/x_O2_massic; %4 C12H23 + 71 O2 = 48 CO2 + 46 H2O
end

W_mT=h3-h4;
P_mT=m_g*W_mT

W_mC=h2-h1;
P_mC=m_a*W_mC

P_fmec=k_mec*(P_mT+P_mC)%=P_e-P_m
P_m=P_e+P_fmec;



%%%%%%%
%Plots%
%%%%%%%

%T-s
length=10;
T_12=linspace(T1,T2,length);
T_23=linspace(T2,T3,length);
T_34=linspace(T3,T4,length);
T_41=linspace(T4,T1,length);

p_23=linspace(p2,p3,length);

s_12=zeros(1,length);
s_23=zeros(1,length);
s_34=zeros(1,length);
s_41=zeros(1,length);

h_12=zeros(1,length);
h_23=zeros(1,length);
h_34=zeros(1,length);
h_41=zeros(1,length);

%In the compressor:
for i= 1:length
    
    h_12(i)=h1+integral(@(t) x_O2_massic*janaf('c','O2',t)+(1-x_O2_massic)*janaf('c','N2',t),T1,T_12(i))*1000;
    
    s_12(i)=s1+(1-eta_piC)*integral(@(t) (x_O2_massic*janaf('c','O2',t)+(1-x_O2_massic)*janaf('c','N2',t))./t,T1,T_12(i));
    %s_12(i)=x_O2_massic*janaf('s','O2',T_12(i))+(1-x_O2_massic)*janaf('s','N2',T_12(i))-s1;
    
end

%In the combustion chamber:
for i= 1:length
    if methane
        h_23(i)=h2+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))/(1+lambda*m_a1),T2,T_23(i))*1000;   
        %h_23(i)=(janaf('h','CO2',T_23(i))*1000/16*44+janaf('h','H2O',T_23(i))*1000/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('h','N2',T_23(i))*1000+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('h','O2',T_23(i))*1000)/(1+lambda*m_a1);
        s_23(i)=s2+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T2,T_23(i))-R_g*log(p_23(i)/p2)/1000;

        %s_12(i)=s2+integral(@(t) (x_O2_massic*janaf('c','O2',t)+(1-x_O2_massic)*janaf('c','N2',t))./t*(1-eta_piC),T1,T_12(i));
        %s_23(i)=s2+(janaf('s','CO2',T_23(i))/16*44+janaf('s','H2O',T_23(i))/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('s','N2',T_23(i))+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('s','O2',T_23(i)))/(1+lambda*m_a1)-R_g*log(p_23(i)/p2);
    end
end

%In the turbine:
for i= 1:length
    if methane
        h_34(i)=h3+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))/(1+lambda*m_a1),T3,T_34(i))*1000;      
        s_34(i)=s3-(1-eta_piT)/eta_piT*integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T3,T_34(i));

        %s_34(i)=(janaf('s','CO2',T_34(i))/16*44+janaf('s','H2O',T_34(i))/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('s','N2',T_34(i))+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('s','O2',T_34(i)))/(1+lambda*m_a1)-R_g*log(p_34(i)/p3);
    end
end

%Virtual transformation 4->1
ds=(s4+(integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T4,T_41(i))))-s1;
for i= 1:length
    if methane
    h_41(i)=h4+integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))/(1+lambda*m_a1),T4,T_41(i))*1000;       
    s_41(i)=(s4+(integral(@(t) (janaf('c','CO2',t)/16*44+janaf('c','H2O',t)/8*18+lambda*m_a1*(1-x_O2_massic)*janaf('c','N2',t)+(lambda*m_a1*x_O2_massic-m_a1*x_O2_massic)*janaf('c','O2',t))./t/(1+lambda*m_a1),T4,T_41(i))))-ds*(i-1)/(length-1);

%s_41(i)=(m_a*(x_O2*(janaf('s','O2',T_41(i)+R/32*log(p_41/p4)))+(1-x_O2)*janaf('s','N2',T_41(i)+R/14*log(p_41/p4))) + m_c*get_methane('s',T_41(i),p_41))/m_g;
    else
    end
    
end
 figure
plot(s_12,h_12)
 hold on;
 plot(s_23,h_23)
 plot(s_34,h_34)
 plot(s_41,h_41)
 
 figure
 plot(s_12,T_12)
 hold on;
 plot(s_23,T_23)
 plot(s_34,T_34)
 plot(s_41,T_41)
 


%Energetic efficiency
%P_m/(m_c*LHV)
eta_cyclen=P_e/(m_c*LHV_massic)
%eta_cyclen=1-((1+1/(lambda*m_a1))*h4-h1)/((1+1/(lambda*m_a1))*h3-h2)
eta_mec=P_e/P_m
eta_toten=eta_cyclen*eta_mec
end

