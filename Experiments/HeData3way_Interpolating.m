% Import 3-way arrays 
%FS Middleton 27 June 2022

%% Import data of 3-way arrays 
clc
clear
Temps = 298.15;%[243.15; 253.15; 263.15; 273.15; 283.15; 288.15; 290.15; 293.15; 296.15; 298.15; 303.15; 308.15; 313.15; 318.15; 323.15; 333.15; 343.15; 348.15; 353.15; 363.15];

for t = 1:length(Temps)
    T = Temps(t); 
    filename = strcat('HEMatrixPoly16June',num2str(T),'.xlsx');
    table = table2array(readtable(filename, 'Sheet', '0.1'));
    conc_interval = 0.1:0.1:0.9;
    dim1(t) = size(table,1);
    dim2 = size(table,2);
    dim3 = length(conc_interval);
    X = nan(dim1(t), dim2, dim3);

    for i = 1:length(conc_interval)
        table = table2array(readtable(filename, 'Sheet',num2str(conc_interval(i))));
        X(:,:,i) = table;
    end 
    table = table2array(readtable(filename, 'Sheet', 'mixtures1'));
    table2 = table2array(readtable(filename, 'Sheet', 'error'));
    table3 = table2array(readtable(filename, 'Sheet', 'orderPolynomial'));
end 

%% Import all collected data 
% Import the data of composition, component, temperature, and excess enthalpy
clc
clear
data = readtable('HEData18July.xlsx','Sheet', 'All','ReadVariableNames',true); % change sheet to include certain functional groups as the main site of data collection 

comp = table2array(data(:,7));
temp = table2array(data(:,6));
HE  = table2array(data(:,9));
rHE = table2array(data(:,11)); %reduced excess enthalpy rHE = HE/(x1*(1-x1))
% Unique temperatures 
[B,it,ib]=unique(temp);
count_t = zeros(length(B),2);
B = sort(B, 'descend');
count_t(:,1)=B;
for i = 1:length(B)
    count_t(i,2) = sum(ib(:)==i); 
end 


f1 = table2cell(data(:,1));
f2 = table2cell(data(:,2));
ch1 = table2array(data(:,3));
ch2 = table2array(data(:,4));

func_groups.one = {'Alkane', 'Primaryalcohol', 'Secondaryalcohol','Isoalkanol', 'Tertiaryalcohol','Benzene', 'Toluene', 'Ketone', 'Ketone3','Alkene','Cycloalkane', 'Ester1', 'Ester2','Ester3','Ester4','Ester5','Estercyc', 'Amine', 'Aniline', 'Benzylamine', 'Acid', 'Aldehyde'};
func_groups.two = {'Alkane', 'Primaryalcohol', 'Secondaryalcohol','Isoalkanol', 'Tertiaryalcohol','Benzene', 'Toluene', 'Ketone', 'Ketone3','Alkene','Cycloalkane', 'Ester1', 'Ester2','Ester3','Ester4','Ester5','Estercyc', 'Amine', 'Aniline', 'Benzylamine', 'Acid', 'Aldehyde'};
max_chain_length = 12; 
f1_num= zeros(length(HE),1);
f2_num= zeros(length(HE),1);
f = 0;
for func = func_groups.one
    f=f+1;
    indices1 = find(strcmp(func,f1));
    indices2 = find(strcmp(func,f2));
    f1_num(indices1) = f;
    f2_num(indices2) = f;
end 
%specification of mixtures 
mixture = zeros(4,length(HE));
mixture(1,:)=f1_num;
mixture(3,:)=f2_num;
mixture(2,:)=ch1;
mixture(4,:)=ch2;
mixtureT = mixture';
%the unique components in the array
[allcomps1,~,~]=unique(mixtureT(:,[1,2]), 'rows');
[allcomps2,~,~]=unique(mixtureT(:,[3,4]), 'rows');
[l,Locb] = ismember(allcomps2,allcomps1,'rows');
include2 = find(Locb==0);
% all possible components in this matrix 
allcomps = [allcomps1; allcomps2(include2,:)];
%% Interpolate data 
% at one temp (ignore pressure) for each mixture to find values at certain concentrations 
% Find all data points with the same temp, FuncGroup1, FuncGroup2,
% ChainLength1 and ChainLength2 and populate comp_temp with compositions
% and HE_temp with HE data 
poly = 1; %1 for interpolation using polynomials, 2 for the RK equation, done with reduced HE data 
interp_index = zeros(length(data.FunctionalGroup1),1);%variable to save the indexes that have been interpolated

% Specify the mixtures wanted in the matrix. The algorithm will find all
% combinations of functional group 1 and 2.  
func_groups.one = {'Alkane', 'Primaryalcohol', 'Secondaryalcohol','Isoalkanol', 'Tertiaryalcohol','Benzene', 'Toluene', 'Ketone', 'Ketone3','Alkene','Cycloalkane', 'Ester1', 'Ester2','Ester3','Ester4','Ester5','Estercyc', 'Amine', 'Aniline', 'Benzylamine', 'Acid', 'Aldehyde'};
func_groups.two = {'Alkane', 'Primaryalcohol' , 'Secondaryalcohol','Isoalkanol', 'Tertiaryalcohol','Benzene', 'Toluene', 'Ketone', 'Ketone3','Alkene','Cycloalkane', 'Ester1', 'Ester2','Ester3','Ester4','Ester5','Estercyc', 'Amine', 'Aniline', 'Benzylamine', 'Acid', 'Aldehyde'};
max_chain_length = 12; 
P = 15000; % pressure in kPa 
% pressure is ignored due to very small variation with pressure of HE and
% non-critical behaviour 

conc_interval = 0.1:0.1:0.9;
Temps = [283.15; 288.15; 303.15; 307.5; 309.5;313.15;318.15; 323.15]; % ;243.15; 253.15; 263.15; 273.15; 283.15; 288.15; 290.15; 293.15; 296.15; 298.15; 303.15; 308.15; 313.15; 318.15; 323.15; 328.15; 333.15; 343.15; 348.15; 353.15; 363.15];
for T = Temps'
    disp(T)
    data = readtable('HEData18July.xlsx','ReadVariableNames',true); % change sheet to include certain functional groups as the main site of data collection 

    comp = table2array(data(:,7));
    temp = table2array(data(:,6));
    HE  = table2array(data(:,9));
    rHE = table2array(data(:,11));
    
    % a moderate allowance for different experimental values 
    Tupper = T+1;
    Tlower = T-1;

    %First restrict data to relevant temperatures. Can add a for loop here
    %later 
    P_loc = find(data.Pressure_kPa_<P);
    temp_data=data(:,:); % all data, do not consider pressure
    T_loc = find(temp_data.Temperature<Tupper & temp_data.Temperature>Tlower);
    temp_data = temp_data(T_loc, :);

    % create matrices to populate with each mixture's data 
    HE_data = nan(length(conc_interval), (100*100));
    HEpred = nan(300, (100*100));
    errorpred = nan(300, (100*100));
    uncertainty = nan(length(conc_interval),100*100);
    dim1= 216; %assumed max 40 data points per set 
    conc_original = nan(dim1, 100*100);
    HE_original = nan(dim1, 100*100);
    mixture = nan(4, 100*100);
    mxture2 = nan(4,100*100);
    orderPolyfit = nan( 100*100,1);
    f1=0;
    ind=0;
    disp('Regressing')
    %run through functional group 1 possibilities 
    for func1= func_groups.one
        f1=f1+1;
        f2=0;
        % restrict to mixtures containing the wanted functional group in
        % position 1
        func1_loc= find(strcmp(temp_data.FunctionalGroup1, func1));
        temp1 = temp_data(func1_loc,:);
        % functional group 2 possibilities 
        for func2= func_groups.two
            f2=f2+1;
            % restrict to mixtures containing the wanted functional group in
            % position 2
            func2_loc = find(strcmp(temp1.FunctionalGroup2, func2));
            temp2 = temp1(func2_loc,:);
            % now loop through chain lengths
            for i =0:max_chain_length
                %only this chain length 
                chain1_loc = find(temp2.Chainlength1==i);
                temp3 = temp2(chain1_loc,:);
                for j =0:max_chain_length
                    % 2nd chain length considered
                    if i~=j || f1~=f2
                        %excess enthalpy of a mixture of the two different pure
                        %components
                        chain2_loc = find(temp3.Chainlength2==j);
                        temp4 = temp3(chain2_loc,:); % this is the data we interpolate 

                        if size(temp4,1)>2
                            ind =ind+1;% this index is correct now 

                            mixture(1,ind)= f1;
                            mixture(2,ind)= i;
                            mixture(3,ind)= f2;
                            mixture(4,ind)= j;
                            % interpolate data and populate matrix of all data
                            if poly == 1
                                [HE_data(:,ind), uncertainty(:,ind), orderPolyfit(ind),HEpred(:,ind), errorpred(:,ind)]=interp_data(temp4, conc_interval);
                                HE_original(1:size(temp4,1),ind) = temp4.Excessenthalpy;
                            else
                                %used for reduced HE data 
                                [HE_data(:,ind), uncertainty(:,ind), orderPolyfit(ind),HEpred(:,ind), errorpred(:,ind)]=RK_interp_data(temp4, conc_interval);
                                HE_original(1:size(temp4,1),ind) = temp4.ReducedHE;
                            end 
                            % save original data in the same order
                            conc_original(1:size(temp4,1),ind) = temp4.Compositioncomponent1;

                            % find if mixture is unique
                        end 
                    end 
                end  
            end 
        end 
    end
    % Exporting the data 
    disp('Exporting')
    prefixfilename = 'HEMatrixPolyAll';
    %remove nan columns or rows 
    mixture = mixture(:, 1:ind);
    HE_data = HE_data(:, 1:ind);
    conc_original = conc_original(:, 1:ind);
    uncertainty = uncertainty(:, 1:ind);
    orderPolyfit = orderPolyfit(1:ind, :)';
    RAD = abs(errorpred./HEpred);
    % number of unique components and their indices
    mixtureT = mixture';
    [comps1,~,~]=unique(mixtureT(:,[1,2]), 'rows');
    [comps2,~,~]=unique(mixtureT(:,[3,4]), 'rows');
    [l,Locb] = ismember(comps2,comps1,'rows');
    include2 = find(Locb==0);
    % all possible components in this matrix 
    comps = [comps1; comps2(include2,:)];

    % Populate matrices of interpolated data 
    % populate the square array 
    dim1 = size(comps,1); %number of component ones (rows)
    dim2 = size(comps,1);% number of component twos (columns)
    dim3 = length(conc_interval); % number of compositions

    %B1 and B2 already ordered - they become the indices on the sides of the
    %matrix 
    %order the data in HE_data 
    HE_data_sparse = nan(dim1,dim2,dim3);
    error = nan(dim1,dim2,dim3);
    for i = 1:dim1
        for j=1:dim2
            %consider all possibilities of mixtures 
            [lia,index]=ismember([comps(i,:) comps(j,:)], mixture', 'rows');
            if lia ==1
                HE_data_sparse(i,j,:)= reshape(HE_data(:,index),[1,dim3]);
                HE_data_sparse(j,i,:)=reshape(flip(HE_data(:,index)),[1,dim3]);
                error(i,j, :) = reshape(uncertainty(:,index),[1,dim3]);
                error(j,i,:) = reshape(uncertainty(:,index),[1,dim3]);
                if i==j
                disp('nah thats not right')
                disp(i)
                end 
            end 

        end 
    end 
    %place zeros on the diagonal 
    for i =1:dim1
        HE_data_sparse(i,i,:)=zeros(length(conc_interval),1);
    end 
    %find missing rows and columns 
    missing.ind = find(isnan(HE_data_sparse));
    % check for nan rows and column 
    [missing.i, missing.j] = find(isnan(HE_data_sparse));

    % Export 3-way array to excel spreadsheet 
    filename = strcat(prefixfilename,num2str(T),'.xlsx');
    %create table with all this information
    for i = 1:length(conc_interval)
        Table = array2table(HE_data_sparse(:,:,i));
        writetable(Table,filename,'Sheet',num2str(conc_interval(i)))
    end 
    TableHE = array2table(HE_data);
    Table2= array2table(mixture);
    Table4 = array2table(uncertainty);
    Table5 = array2table(orderPolyfit);
    TableRAD = array2table(RAD);
    TableConcO = array2table(conc_original);
    TableHEO = array2table(HE_original);
    writetable(Table2,filename,'Sheet','mixtures1')
    writetable(Table4, filename, 'Sheet', 'error')
    writetable(Table5, filename, 'Sheet', 'orderPolynomial')
    TableB1 = array2table(comps1); %unique component 1
    TableB2 = array2table(comps2);%unique component 2
    writetable(TableB1,filename, 'Sheet', 'B1')
    writetable(TableB2,filename, 'Sheet', 'B2')
    writetable(TableRAD, filename, 'Sheet', 'RAD')
    writetable(TableConcO, filename, 'Sheet', 'ConcOriginal')
    writetable(TableHEO, filename, 'Sheet', 'HEOriginal')
    writetable(TableHE, filename, 'Sheet', 'HEInterpolated')
    disp(filename)
    disp('Exported')
    save(strcat(prefixfilename,num2str(T),'.mat'))
end 
%% Check the interpolation worked nicely for select mixtures
clf
mix =12;
plot(conc_original(:,mix), HE_original(:,mix), 'bo')
hold on 
plot(conc_interval, HE_data(:,mix), 'LineWidth', 1) 

legend('Experimental', 'Interpolated', 'Location', 'northwest')

xlabel('Composition component 1 (mol/mol)')
ylabel('Excess enthalpy (kJ/mol)')
title(['Order of the fit ', num2str(orderPolyfit(mix))])
%% Plt the missing data structure 
% these must have the same sizes as x
v=HE_data_sparse;

xslice = 1:1:44;    % location of y-z planes
yslice = 1:2:80;     % location of x-z plane
zslice = 1:3:9;         % location of x-y planes
clf
slice(v,xslice,yslice,zslice)
xlabel('Component 1')
ylabel('Component 2')
zlabel('Composition')
% hm = HeatMap(HE_matrix);
% addXLabel(hm,'Component 1','FontSize',12);
% addYLabel(hm,'Component 2','FontSize',12);
% addZLabel(hm, 'Composition', 'FontSize',12);
% view(hm)
% histogram(X)
% xlabel('Value in the matrix X')
% ylabel('Frequency')
%% Plt the missing data structure 
% these must have the same sizes as x
v=HE_data_sparse;

xslice = 1:10:97;    % location of y-z planes
yslice = 1:10:97;     % location of x-z plane
zslice = 1:4:9;         % location of x-y planes
clf
slice(v,xslice,yslice,zslice)
xlabel('Component 1')
ylabel('Component 2')
zlabel('Composition')


%%
function [HE, uncertainty, orderPolyfit, HEpredout, errorpredout]=interp_data(data, conc_interval)
    % Interpolate data for use in the matrices
    % Inputs specify the mixture to be captured and the concentration
    % interval for which to create interpolate points
    
    % data = the whole table of data to be interpolated
    % conc_interval = list of concentrations for interpolation 
    
    % Ouputs is the data produced by the interpolation, ready for
    % matrix populating 
    % HE = excess enthalpy data at each concentration value for the mixture
    % uncertainty = uncertainty associated with each data point, to be
    % added
    HE_original = data.Excessenthalpy;
    comp = data.Compositioncomponent1;
    % remove the 0 and 1 data points 
    ind_keep = find(HE_original ~=0);
    
    HE_new= HE_original(ind_keep);
    comp_new = comp(ind_keep);
    % check for data that does not have many points outside a certain interval 
    maxdiff = max(comp)-min(comp);
    numberofpoints = length(comp_new);
    if ind_keep
        comp_new(numberofpoints+1)=0;
        comp_new(numberofpoints+2)=1;
        HE_new(numberofpoints+1)=0;
        HE_new(numberofpoints+2)=0;
    end 
    
    %interpolate the data 
    if maxdiff <0.3 || numberofpoints <2
        %just fit a parabola to the small amount of data 
        maxOrder = 2;
    else 
        maxOrder = 7;
    end 
    
    error = zeros(maxOrder-1,1);
    ind = 1;
    for i =2:maxOrder
        [p,S,mu] = polyfit(comp_new, HE_new,i);
        [~,uncertainty] = polyval(p,conc_interval, S,mu);
        error(ind) = sum(uncertainty)/length(uncertainty);
        ind = ind+1;
    end 
    %populate the data 
    orderPolyfit = find(error == min(error))+1;
    [p,S] = polyfit(comp_new, HE_new,orderPolyfit);
    [HE,uncertainty] = polyval(p,conc_interval, S);
    [HEpred, errorpred] = polyval(p, comp_new,S);
    HEpredout = zeros(300,1);
    HEpredout(1:length(HEpred),1)=HEpred;
    errorpredout = zeros(300,1);
    errorpredout(1:length(errorpred),1)=errorpred;
end 

function [HEr, uncertainty, orderPolyfit, HEpredout, errorpredout]=RK_interp_data(data, conc_interval)
    % Interpolate data for use in the matrices using the Redlich Kister
    % equation:
    % HE /(x1(1-x))=( A+B(2x-1)+C(2x-1)^2+D(2x-1)^3+E(2x-1)^4+F(2x-1)^5)
    % Inputs specify the mixture to be captured and the concentration
    % interval for which to create interpolate points
    
    % data = the whole table of data to be interpolated
    % conc_interval = list of concentrations for interpolation eg conc_interval = 0.1:0.1:0.9;
    
    % Ouputs is the data produced by the interpolation, ready for
    % matrix populating 
    % HE = reduced excess enthalpy data at each concentration value for the mixture
    % uncertainty = uncertainty associated with each data point, to be
    % added
    % order = the number of constants used in the RK equation
    HEr_original = data.ReducedHE;
    comp = data.Compositioncomponent1;
    % remove the 0 and 1 data points 
    ind_keep = find(HEr_original ~=0);
    HEr_new = HEr_original(ind_keep);
    comp_new = comp(ind_keep);
    maxdiff = max(comp)-min(comp);
    numberofpoints = length(comp_new);
    if ind_keep
        comp_new(numberofpoints+1)=0;
        comp_new(numberofpoints+2)=1;
        HEr_new(numberofpoints+1)=0;
        HEr_new(numberofpoints+2)=0;
    end 
    
     %interpolate the data 
    if maxdiff <0.4 || numberofpoints<4
        %just fit a parabola to the small amount of data 
        maxOrder = 3;
    else 
        maxOrder = 7;
    end 
    %interpolate the data 
    
    error = zeros(maxOrder-1,1);
    ind = 1;
    for i =2:maxOrder
        %Y=XB, B=X\Y, Y=HEr, X= (2x-1)^i, B=constants
        Y=HEr_new; % column n-by-1
        X = ones( length(comp_new),i); %
        for j = 1:i
            X(:,j)=(2*comp_new-1).^(j-1);
        end 
        
        mdl = fitlm(X,Y, 'Intercept',false);
        coeff = mdl.Coefficients.Estimate;
       
        error(ind) = mdl.MSE;
        ind = ind+1;
    end 
    %Find the best fit 
    orderPolyfit = find(error == min(error))+1;
    if length(orderPolyfit)>1
        orderPolyfit = orderPolyfit(1,1);
    end
    X = ones(length(comp_new), orderPolyfit); %
    for j = 1:i
        X(:,j)=(2*comp_new-1).^(j-1);
    end 
    mdl = fitlm(X,Y,'Intercept',false);
    coeff = mdl.Coefficients.Estimate;
    %predict the data 
    Xpred = ones(length(conc_interval), orderPolyfit); %
    for j = 1:i
        Xpred(:,j)=(2*conc_interval-1).^(j-1);
    end 
    HEpred = ones(length(conc_interval), orderPolyfit); %
    for j = 1:i
        HEpred(:,j)=(2*conc_interval-1).^(j-1);
    end  
    HEr = Xpred*coeff;
    HEpred = HEpred*coeff;
    errorpred = HEpred - HEr_new;
    uncertainty = mdl.MSE;
    HEpredout = zeros(300,1);
    HEpredout(1:length(HEpred),1)=HEpred;
    errorpredout = zeros(300,1);
    errorpredout(1:length(errorpred),1)=errorpred;
end 
