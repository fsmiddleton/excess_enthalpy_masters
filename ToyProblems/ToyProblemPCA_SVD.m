%% Toy problem to create code for SVD used for matrix completion 
% Francesca Middleton, 2022-03-02

%% Import or create data matrix for testing 
clc
clear

import = 0;% import =1 to import a full test matrix, import = 0 to create a low rank matrix
if import ==0
    % correlated matrix of spectral data, manuscript available (highly correlated data):
    % https://www.kaggle.com/sergioalejandrod/raman-spectroscopy
    T1 = readtable('raman_mix1_spectrum.xlsx', 'Sheet', 'mix_1');
    T2 = readtable('raman_mix2_spectrum.xlsx', 'Sheet', 'mix_2');
    T3 = readtable('raman_mix3_spectrum.xlsx', 'Sheet', 'mix_3');
    T4 = readtable('raman_mix4_spectrum.xlsx', 'Sheet', 'mix_4');

    T = cat(1, T1, T2, T3, T4); % concatenate arrays vertically 
    X = table2array(T1);%only use T1, small enough to manage
    n = size(X,2);
    m = size(X,1);
        
else 
    %create array
    %specify size and rank of array, choosing random mu and sigma to create
    %singular values from 
    n=50;
    m=50;
    rank = 10;
    mu = 0;
    sigma = 1;
    noise=1; %noise =1 to add noise
    [X,Xnoise, rankU, rankV]=create_matrix(n,m,rank, mu, sigma);
    Xdiff=X-Xnoise;
    disp(rank)
    if noise ==1
        X=Xnoise;
    end 
end 
%% Plot the matrix generated
clf
%[Xs,missing_ind,filled_linear_ind]=fill_matrix(X,0.5);%missing data 
hm = HeatMap(X);
addXLabel(hm,'Component 1','FontSize',12);
addYLabel(hm,'Component 2','FontSize',12);
view(hm)
histogram(X)
xlabel('Value in the matrix X')
ylabel('Frequency')
%%
% remove data or fill a matrix 
remove = 0;
remove_ind = 1:(n*m);
 
%Time to choose how to find the best rank
Gavish =0;
 % Choose sparsities used for finding the rank 
sparsities = [0.1,0.2,0.3,0.4,0.5,0.6];

%intialise the metrics to analyse each sparsity and its final rank found 
minmse = zeros(size(sparsities,2),1);
minwmse = zeros(size(sparsities,2),1);
min_fn = zeros(size(sparsities,2),1);
X_pred_best = zeros(n,m,size(sparsities,2)); % and the X predictions

j=0;
for sparsity = sparsities
    j=j+1;
    % Create the sparse matrix 
    if remove == 1
        [Xs,missing_ind, filled_linear_ind] = remove_matrix(X,sparsity);
    else 
        [Xs,missing_ind,filled_linear_ind]=fill_matrix(X,sparsity);
    end 
    
    % Find the optimal rank for this matrix
    if Gavish==1
        %Hard thresholding 
        if n/m ==1
            omega = 2.858; % omega(beta)=2.858 for n*n
        elseif n/m < 1
            omega = optimal_SVHT_coef_sigma_unknown(n/m);
        else
            beta = m/n;
            %omega = optimal_SVHT_coef_sigma_unknown(m/n); 
            omega = 0.56*beta^3 - 0.95*beta^2 + 1.82*beta + 1.43;
        end 
        [U,D,V,X_pred]=missing_svd(Xs,m,1,1e-4,200); % PCA done once, the matrix needs to be filled to do this
        
        y_med = median(diag(D)); %ymed = median singular value of the noisy matrix  
        cutoff = omega*y_med; %cutoff= tau= omega(beta)*ymed; matrix
         % Keep modes w/ sig > cutoff; rank chosen as hard cutoff
        d = diag(D);
        disp(cutoff)
        d(d<(cutoff))=0;
        fn = length(find(diag(D)>cutoff));
        disp(fn)
        X_pred = U*diag(d)*V';
        SRSS = sqrt((sum((X_pred(missing_ind)-X(missing_ind)).^2)));
        minmse(j) = (sum((X_pred(missing_ind)-X(missing_ind)).^2))/length(remove_ind);
        minwmse(j)= find_wmse(X(missing_ind), X_pred(missing_ind), length(missing_ind));
        min_fn(j) = fn;
        X_pred_best(:,:,j) = X_pred;
    else
        % Iterative PCA with wMSE or MSE used to find rank 
        fns = [1,2,3,4,5,6,7,8,9,10];

        %choose which error measure to use for choosing the best PC
        winsorized_mse =1; %1=use wmse 

        % initialise error vars 
        mse = zeros(size(fns,2),1);
        smse = zeros(size(fns,2),1);
        wmse = zeros(size(fns,2),1);
        
        %Find rank by minimising the mse or wmse 
        i=0;
        for fn=fns
            [U,D,V,X_pred]=missing_svd(Xs,fn,1,1e-3,1000);
            i=i+1;
            SRSS = sqrt((sum((X_pred(missing_ind)-X(missing_ind)).^2)));
            mse(i) = (sum((X_pred(missing_ind)-X(missing_ind)).^2))/length(remove_ind);
            wmse(i)= find_wmse(X(missing_ind), X_pred(missing_ind), length(missing_ind));
            smse(i) = sqrt(mse(i));
            %error bars
            
        end
        minmse(j) = min(mse);
        minwmse(j)=min(wmse);
        if winsorized_mse ==1
            min_index = find(wmse==minwmse(j));
        else
            min_index = find(mse==minmse(j));
        end 
        min_fn(j) = fns(min_index);
        [U,D,V,X_pred_best(:,:,j)]=missing_svd(Xs,min_fn(j),1,1e-3,1000);
    end
    
    %error bars
    X_pred_boot = zeros(n,m,size(filled_linear_ind,1));
    boot_removed_col = zeros(size(filled_linear_ind,1),1);
    boot_removed_row = zeros(size(filled_linear_ind,1),1);
    j=0;
    for filled_ind = filled_linear_ind' %filled_linear_ind must be a row vector for a for loop
        %Find error bars of the predictions 
        % remove a point from Xs 
        X_b = Xs;
        col = mod(filled_ind,m);
        if col ==0
            col=m;% mod(any integer*m,m)=0, but the column should be column m
        end 
        row = ceil(filled_ind/m);
        X_b(filled_ind) = nan;
        if find(X_b(:,col)) & find(X_b(row,:)) %ensure at least one value in each column and row
            j=j+1;
            boot_removed_col(j) = col;
            boot_removed_row(j) = row;
            %if there are other entries in the rows and columns,
            %perform iterative PCA on the slightly more empty matrix 
            [U,D,V,X_pred_boot(:,:,j)]=missing_svd(X_b,min(fn),1,1e-3,1000);%iterative PCA using the known rank 
        end 
    end 
    % remove the predictions that were not made from the averaging and
    % finding variance 
    
    for l=1:j
        X_pred_best_boot(boot_removed_row(l), boot_removed_col(l)) = mean(X_pred_boot(boot_removed_row(l), boot_removed_col(l), :));
        X_var_best_boot(boot_removed_row(l), boot_removed_col(l)) = var(X_pred_boot(boot_removed_row(l), boot_removed_col(l), :));
    end 
    
end 


%% Plots of the singular values 
subplot(2,1,1)
y = diag(D);
semilogy(1:m, diag(D))
hold on 
semilogy(rank, y(rank), 'ro')
hold off
subplot(2,1,2)
plot(1:m,cumsum(diag(D))/sum(diag(D)))
hold on
y2 = y(1:rank);
realranky = cumsum(y(1:rank));
plot(rank, realranky(rank)/sum(diag(D)), 'ro')
hold off

%% Reorder data to test the change of the order of the data (in rows and columns) and how this affects the final predictions 


%% Functions 
function [X,Xnoise, rankU, rankV]=create_matrix(n,m,r, mu, sigma)
    % create a matrix of size nxm with rank =r using SVD 
    
    sing_vals = normrnd(mu, sigma, r,1); % generate r singular values that are normally distributed 
    sing_vals = sort(sing_vals, 'descend'); % sorted from highest to lowest
    D = zeros(n,m);%initialise D 
    for i = 1:r
        D(i,i) = sing_vals(i); %populate array with values 
    end 
    % fill the matrices U,V with random entries
    U = rand(n,n);
    V = rand(m,m);
    % find orthonormal bases of U and V 
    rankU = rank(U);
    rankV = rank(V);
    U = orth(U);
    V = orth(V);
    %fill the final matrix 
    X = U*D*V'; %create the matrix of rank r
    Xnoise = X+randn(size(X))/sqrt(n*m);
end 

function [X_sparse,remove_ind, fill_ind]=fill_matrix(X, perc_remove)
    % fill data into a matrix until you have reached 1-perc_remove, save all
    % indices not filled 
    [n,m]=size(X);
    num_removed = floor(m*n*perc_remove);
    %create NaN matrix 
    X_sparse = NaN(n,m);
    X_filled_indices = zeros(n,m);
    % fill in one entry in every row and column, randomly 
    filled_rows = zeros(n,1);
    cols=randperm(m); % sort the columns in a random order 
    for j =cols
        i = randi([1,n],1);
        while ismember(i,filled_rows)
            i = randi([1,n],1);
        end
        filled_rows(j)=i;
        X_sparse(i, j)=X(i,j);
        X_filled_indices(i,j)=1;
    end 
  
    
    for k= 1:(m*n-num_removed-m) % remove this many values from array X, 
                                  % having filled at least one entry into every row and column 
        i = randi(n,1); %matrix inidices start at 1 in MATLAB
        j = randi(m,1);
        while X_filled_indices(i,j)==1
            %repeat the finding of indices to fill if this index is already filled 
            i = randi(n,1); %row
            j = randi(m,1);%col
        end 
        X_sparse(i,j)= X(i,j); %reassign value as original X value 
    end 
    remove_ind = find(isnan(X_sparse));
    fill_ind = find(~isnan(X_sparse));
end 

function [X_sparse,remove_ind,fill_ind]=remove_matrix(X,perc_remove)
% Remove data from the X matrix until the percentage is removed, must
% remove entire rows or columns for the matrix to make sense
    [m,n]=size(X);
    num_removed = floor(m*n*perc_remove);
    
    X_sparse = X;
    for k= 1:(num_removed) % remove this many values from array X 
        i = randi(m,1); %matrix inidices start at 1 in MATLAB
        j = randi(n,1);
        while isnan(X_sparse(i,j))
            i = randi(m,1); %repeat the removal if necessary  
            j = randi(n,1);
        end 
        X_sparse(i,j)= nan; %reassign value as NaN value 
    end 
    remove_ind = find(isnan(X_sparse));
    fill_ind = find(~isnan(X_sparse));
end 

function [X_filled]=fill_data(X)
    [m,n]=size(X);
    missing_ind = (isnan(X));
    
    X_filled=X;
    X_filled(missing_ind)=0; %fill NaN values with 0 
    
    [i, j]=find(isnan(X));% returns rows and columns with nonzero elements 
    
    mean_col = sum(X_filled,1)./(ones(1,n)*m-sum(missing_ind,1)); %columns are dimension 1
    mean_row= sum(X_filled,2)./(ones(1,m)*n-sum(missing_ind,2)); % rows are dimension 2 
    for k =1:length(i) % for all NaN elements that exist, loop through them to replace with means 
        X_filled(i(k),j(k))=(mean_row(i(k))+mean_col(j(k)))/2;
    end 
end 

function [S,V,D,X_pred]=missing_svd(X,fn,center,conv,max_iter)
    [m,n]=size(X);
    miss_ind = find(isnan(X));
    if any(isnan(X)) % there is missing data 
        Xf = fill_data(X); 
        mx = mean(Xf);
        SS = sum(sum(Xf(miss_ind).^2));
        
        f=2*conv;
        iter = 1;
        while iter<max_iter && f>conv
            SSold = SS;
            if center ==1
                mx = mean(Xf);
                %Xc = normalize(Xf); %normalizing 
                Xc = Xf-ones(m,1)*mx; %centering of the data done -> for PCA 
            else 
                Xc=Xf;
            end 
            [S,V,D]=svd(Xc);
            S=S*V;
            V=V(:,1:fn);
            S=S(:,1:fn);
            D=D(:,1:fn);
            if center ==1
                X_pred = S*D'+ones(m,1)*mx;
            else 
                X_pred = S*D';
            end 
            Xf(miss_ind)=X_pred(miss_ind);
            SS = sum(sum(Xf(miss_ind).^2));
            f = abs(SS-SSold)/(SSold);
            iter = iter+1;
        end 
    else 
        Xf=X;
        if center ==1
            mx = mean(Xf);
            %Xc = normalize(Xf); %normalizing 
            Xc = Xf-ones(m,1)*mx; %centering
        else 
            Xc=X;
        end 
        [S,V,D]=svd(Xc);
        S=S*V;
        S=S(:,1:fn);
        D=D(:,1:fn);
        if center ==1
            X_pred = S*D'+ones(m,1)*mx;
        else 
            X_pred = S*D';
        end 
    end %end if  else 
end % end function 

function [wmse]=find_wmse(X,X_pred,no_missing)
% find the winsorized mse for the matrices 
    % turn 
    % find outliers
    perc5 = prctile(X_pred,5, 'all');
    perc95 = prctile(X_pred, 95, 'all');
    %reassign
    X_pred(X_pred<perc5)=perc5;
    X_pred(X_pred> perc95)=perc95;
    wmse = (sum((X_pred-X).^2))/no_missing;
end 

function omega = optimal_SVHT_coef_sigma_unknown(beta)
%Gavish and Donaho; finding coeff for optimal cutoff for a non-square
%matrix
% Beta = n/m = aspect ratio 
    warning('off','MATLAB:quadl:MinStepSize')
    assert(all(beta>0));
    assert(all(beta<=1));
    assert(prod(size(beta)) == length(beta)); % beta must be a vector
    
    coef = optimal_SVHT_coef_sigma_known(beta);

    MPmedian = zeros(size(beta));
    for i=1:length(beta)
        MPmedian(i) = MedianMarcenkoPastur(beta(i));
    end

    omega = coef ./ sqrt(MPmedian);
end

function lambda_star = optimal_SVHT_coef_sigma_known(beta)
    assert(all(beta>0));
    assert(all(beta<=1));
    assert(prod(size(beta)) == length(beta)); % beta must be a vector
    
    w = (8 * beta) ./ (beta + 1 + sqrt(beta.^2 + 14 * beta +1)); 
    lambda_star = sqrt(2 * (beta + 1) + w);
end
function med = MedianMarcenkoPastur(beta)
    MarPas = @(x) 1-incMarPas(x,beta,0);
    lobnd = (1 - sqrt(beta))^2;
    hibnd = (1 + sqrt(beta))^2;
    change = 1;
    while change & (hibnd - lobnd > .001),
      change = 0;
      x = linspace(lobnd,hibnd,5);
      for i=1:length(x),
          y(i) = MarPas(x(i));
      end
      if any(y < 0.5),
         lobnd = max(x(y < 0.5));
         change = 1;
      end
      if any(y > 0.5),
         hibnd = min(x(y > 0.5));
         change = 1;
      end
    end
    med = (hibnd+lobnd)./2;
end

function I = incMarPas(x0,beta,gamma)
    if beta > 1,
        error('betaBeyond');
    end
    topSpec = (1 + sqrt(beta))^2;
    botSpec = (1 - sqrt(beta))^2;
    MarPas = @(x) IfElse((topSpec-x).*(x-botSpec) >0, ...
                         sqrt((topSpec-x).*(x-botSpec))./(beta.* x)./(2 .* pi), ...
                         0);
    if gamma ~= 0,
       fun = @(x) (x.^gamma .* MarPas(x));
    else
       fun = @(x) MarPas(x);
    end
    I = quadl(fun,x0,topSpec);
    
    function y=IfElse(Q,point,counterPoint)
        y = point;
        if any(~Q),
            if length(counterPoint) == 1,
                counterPoint = ones(size(Q)).*counterPoint;
            end
            y(~Q) = counterPoint(~Q);
        end
        
    end
end

