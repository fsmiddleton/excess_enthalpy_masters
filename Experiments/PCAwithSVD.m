%% PCA done using SVD 
% Francesca Middleton 2022-04-25 

%% Import data 
clc
clear

filename = 'ToyProblemData3DFull.xlsx'; % created using parafac code 
% find sheet names in the file 
sheets = sheetnames(filename);
% iterate for the number of sheets

for s=1:length(sheets)
    [sNum,tf]=str2num(s);
    % if the name of the sheet was a number, it can be converted and
    % contains data for the problem 
    if tf == 1
        T = readtable(filename, 'Sheet', num2str(sNum));
        % fill X matrix, changes upon each iteration 
        X(:, :, sNum)=table2array(T); 
    end 
end 
dim = size(X);
%% remove NaN rows or columns
% saves the columns and rows with Nan values 
% this does not work correctly
% row_nan = find(all(isnan(X),2));
% col_nan = find(all(isnan(X),1));
% if row_nan
%     X(row_nan,:)=[];
% end 
% if col_nan 
%     X(:,col_nan)=[];
% end 
% dim = size(X);
% dim1 = dim(1);
% dim2 = dim(2);
% missing_ind = find(isnan(X));
% filled_linear_ind = find(~isnan(X));
 
%% Matrix completion step 
 

%intialise the metrics to analyse each sparsity and its final rank found 
% vectors, one for each matrix that is sliced 
minmse = zeros(size(intervals,2),1); 
minwmse = zeros(size(intervals,2),1);
min_fn = zeros(size(intervals,2),1);
X_pred_best = zeros(dim1,dim2,size(intervals,2)); % and the X predictions
R2 = zeros(size(intervals,2),1);
% initialise error vars 
% column for each matrix (fn vs sparsity)
mse = zeros(size(fns,2),size(intervals,2));

smse = zeros(size(fns,2),size(intervals,2));
wmse = zeros(size(fns,2),size(intervals,2));
R = zeros(size(fns,2),size(intervals,2));


if size(dim,2)>2
    if size(dim,2)==3
        dim3 = dim(3);
        j=0; % counter for matrices
        for dim = 1:dim3 
            j = j+1;
            Xs = X(:,:,j);
            Xs = reshape(Xs,[dim(1),dim(2)]); %matrix
            % complete matrix
            % Iterative PCA with wMSE or MSE used to find rank 
        
            %choose which error measure to use for choosing the best PC
            winsorized_mse =1; %1=use wmse 

            
            %Find rank by minimising the mse or wmse  
            i=0; %counter for ranks 
            for fn=fns
                % rank = fn 
                i=i+1;
                % var filled for each rank 
                error = zeros(size(filled_linear_ind,1),1);
                
                %LOOCV
                k=0;% counter for LOOCV 
                for filled_ind = filled_linear_ind' %filled_linear_ind must be a row vector  
                    % temporary X
                    X_b = Xs;
                    col = mod(filled_ind,dim2);
                    if col ==0
                        col=dim2;% mod(integer*m,m)=0, therefore the column should be column m
                    end 
                    row = ceil(filled_ind/dim2);
                    X_b(filled_ind) = nan;% remove a point from Xs
                    if find(X_b(:,col)) &&  find(X_b(row,:)) %ensure at least one value in each column and row
                        k=k+1;% allowed, therefore the counter is increased 
                        boot_removed_col(k) = col;
                        boot_removed_row(k) = row;
                        %perform iterative PCA on the matrix with one entry missing
                        [U,D,V,X_pred_boot(:,:)]=missing_svd(X_b,min_fn,1,1,1e-3,1000);
                        %save error for this value left out 
                        error(k) = X_pred_boot(filled_ind)- Xs(filled_ind);
                    end 
                end %end LOOCV 
                % find error for matrix (i) and rank (j)
                mse(i,j) = sum(error.^2)/k;
                % find the winsorized mse for the matrices 
                % find outliers
                perc5 = prctile(error,5, 'all');
                perc95 = prctile(error, 95, 'all');
                %reassign
                error(error<perc5)=perc5;
                error(error> perc95)=perc95;
                wmse(i,j) = (sum(error.^2))/k;
            end %end ranks loop
            minmse(j) = min(mse(:,j));
            minwmse(j)=min(wmse(:,j));

            if winsorized_mse ==1
                min_index = find(wmse(:,j)==minwmse(j));
            else
                min_index = find(mse(:,j)==minmse(j));
            end 
            min_fn(j) = fns(min_index);
            [U,D,V,X_pred_best(:,:,j)]=missing_svd(Xs,min_fn(j),1,1,1e-3,1000);
        end %end matrices loop 
        
    end 
end 

%% Relate matrices to each other by RK 

% initialise regression constants - will find matrix of each 
A=ones(dim1,dim2);
B=ones(dim1,dim2);
C=ones(dim1,dim2);
% function created 
He = @(x1) x1*(1-x1)*(A+B*(2*x1-1)+C*(2*x1-1)^2);
% call the function 
He(x);
% regress each system 


%% Plots of the singular values 
clf
dim2=40;
composition = 0.5200;

    % import the relevant sparse matrix from the spreadsheet
    Ts = readtable(filename, 'Sheet', num2str(composition));
    Xs = table2array(Ts);
    missing_ind = find(isnan(Xs));
    filled_linear_ind = find(~isnan(Xs));
 
ind = find(intervals == composition);

[U,D,V,X_pred_plot]=missing_svd(Xs,dim2,1,1e-3,1000); 
mseplot = (sum((X_pred(missing_ind)-X(missing_ind)).^2))/length(remove_ind);
wmseplot= find_wmse(X(missing_ind), X_pred_plot(missing_ind), length(missing_ind));
smseplot = sqrt(mse);
Cyt = corrcoef(X_pred(missing_ind),Xs(missing_ind));
R=sqrt(Cyt(2,1));
%choose rank
subplot(2,1,1)
y = diag(D);
semilogy(1:dim2, diag(D))
xlabel('Rank')
ylabel('Singular values')

if (rank_mat)>0
    hold on 
    semilogy(rank_mat, y(rank_mat), 'ko','MarkerSize',5, 'LineWidth',5)
    legend('SVs', 'True rank')
    hold off
end 
subplot(2,1,2)
plot(1:dim2,cumsum(diag(D))/sum(diag(D)))
xlabel('Rank')
ylabel('Cumulative contribution to error')
if rank_mat>0
    hold on
    y2 = y(1:rank_mat);
    realranky = cumsum(y(1:dim2));
    plot(min_fn(ind), realranky(min_fn(ind)-fns(1)+1)/sum(diag(D)), 'r*', 'MarkerSize',15, 'LineWidth',1.5)
    legend('Cumulative error', 'Predicted rank')
    hold off
end 
sgtitle(strcat('Sparsity = ',num2str(composition)))
%% Plots of errors 
clf
plotno = length(intervals);
a = ceil(sqrt(plotno));
b = ceil(plotno/a);
i=0;
for composition = intervals
    i=i+1;
    ind = find(intervals == composition);
    subplot(a,b,i)
    titlestr = strcat('Sparsity = ',num2str(composition));
    plot(fns, wmse(:,ind))
    hold on
    plot(fns,mse(:,ind), 'm')
    plot(rank_mat,mse(rank_mat-fns(1)+1,ind), 'ko', 'MarkerSize',5, 'LineWidth',5)
    plot(min_fn(ind),wmse(min_fn(ind)-fns(1)+1,ind), 'r*', 'MarkerSize',15, 'LineWidth',1.5)
    hold off
    legend('Winsorized MSE', 'MSE', 'True rank', 'Predicted Rank')
    title(titlestr)
    xlabel('Rank')
    ylabel('Error')
end 

%% Functions 

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
    [dim1,dim2]=size(X);
    missing_ind = (isnan(X));
    [i, j]=find(isnan(X));% returns rows and columns with nonzero elements
    X_filled=X;
    X_filled(missing_ind)=0; %fill NaN values with 0
    %disp(X_filled)
    %disp(length(i))
    mean_col = sum(X_filled,1)./(ones(1,dim2)*dim1-sum(missing_ind,1)); %columns are dimension 1
    % = sum of filled values/(number of existing values)
    mean_row= sum(X_filled,2)./(ones(1,dim1)*dim2-sum(missing_ind,2)); % rows are dimension 2 
    
    for k =1:length(i) % for all NaN elements that exist, loop through them to replace with means 
        X_filled(i(k),j(k))=(mean_row(i(k))+mean_col(j(k)))/2;
         
    end 
end 

function [S,V,D,X_pred]=missing_svd(X,fn,center,scale,conv,max_iter)
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
            % preprocess = scale and then center 
            if scale ==1 
                sj = sqrt(sum(sum((Xf).^2)));
                Xf = Xf/sj;
            end 
            if center ==1
                mx = mean(Xf);
                Xc = Xf-ones(m,1)*mx; %centering of the data done -> for PCA 
            else 
                Xc=Xf;
            end 
            [S,V,D]=svd(Xc);
            S=S*V;
            V=V(:,1:fn);
            S=S(:,1:fn);
            D=D(:,1:fn);
            % post process = uncenter, unscale  
            if center ==1
                X_pred = S*D'+ones(m,1)*mx;
            else 
                X_pred = S*D';
            end 
            if scale ==1
                X_pred = X_pred*sj;
            end
            
            % fill misssing values 
            Xf(miss_ind)=X_pred(miss_ind);
            SS = sum(sum(Xf(miss_ind).^2));
            f = abs(SS-SSold)/(SSold);
            iter = iter+1;
        end 
    else 
        % no missing data 
        Xf=X;
        if scale ==1 
            sj = sqrt(sum(sum((Xf).^2)));
            Xf = Xf/sj;
        end
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
        if scale ==1
                X_pred = X_pred*sj;
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


