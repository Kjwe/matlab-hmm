function [p_start, A, Emis] = Chmm_gauss_mix_tied(Data, p_start, A, Emis, varargin)
iter_num = 10;          % the maximum of EM iteration
cov_type = 'diag';      % 'full' or 'diag'
cov_thresh = 1e-4;      % the thresh of cov
for i1 = 1:2:length(varargin)
    switch varargin{i1}
        case 'cov_type'
            cov_type = varargin{i1+1};
        case 'cov_thresh'
            cov_thresh = varargin{i1+1};
        case 'iter_num'
            iter_num = varargin{i1+1};
    end
end

data_num = length(Data);
Q = length(p_start);
sum_p_start = zeros(Q,1);
sum_ita = zeros(Q,Q);

% EM
for k = 1:iter_num
    Xtotal = []; gamma_total = []; w_total = [];
    for i1 = 1:data_num
        
        X = Data{i1};
        N = size(X,1);
        
        logOb = Gaussmix_tied_logp_xn_cond_zn(X, Emis);
        
        % E
        [gamma, ita, loglik] = ForwardBackward(p_start,A,[],logOb);
        
        
        % M
        
        sum_p_start = sum_p_start + gamma(1,:)';
        sum_ita = sum_ita + ita;
        
        Xtotal = [Xtotal; X];
        gamma_total = [gamma_total; gamma];
        
        w = Gaussmix_p_wm_cond_xn(X, Emis);     % p(wn=m|xn), size: N*M
        w_total = [w_total; w];
        
    end

    p_start = normalise(sum_p_start);
    A = mk_stochastic(sum_ita);
    Emis = UpdateGaussMixTiedPara(Xtotal,gamma_total, w_total,cov_type,cov_thresh);
end
end

function logOb = Gaussmix_tied_logp_xn_cond_zn(X, Emis)
[N,p] = size(X);
[M,Q] = size(Emis.pi);
logOb = zeros(N,Q);

for i1 = 1:Q
    tmpMat = zeros(N,M);
    for i2 = 1:M
        tmpMat(:,i2) = log(Emis.pi(i2,i1)) + Logmvnpdf(X, Emis.mu(:,i2), Emis.Sigma(:,:,i2));
    end
    logOb(:,i1) = max(tmpMat,[],2);
end
end

function w = Gaussmix_p_wm_cond_xn(X, Emis)
N = size(X,1);
[M,Q] = size(Emis.pi);
w = zeros(N,M,Q);
p_mat = zeros(N,M,Q);

for i1 = 1:Q
    tmp_mat = zeros(N,M);
    for i2 = 1:M
        tmp_mat(:,i2) = Logmvnpdf(X, Emis.mu(:,i2), Emis.Sigma(:,:,i2));
    end
    [~,loct] = max(tmp_mat,[],2);
    for j1 = 1:N
        w(j1,loct(j1),i1)=1;
    end
end
end

% M
function Emis = UpdateGaussMixTiedPara(X,gamma,w,cov_type,cov_thresh)

[N,Q] = size(gamma);
[N,M,Q] = size(w);
[N,p] = size(X);
Emis.pi = zeros(M,Q);
Emis.mu = zeros(p,M);
Emis.Sigma = zeros(p,p,M);
tmp = 0;
% for i1 = 1:Q
%     for i2 = 1:M
%         gamma_mul_w = gamma(:,i1) .* w(:,i2,i1);
%         Emis.pi(i2,i1) = sum(gamma_mul_w) / sum(gamma(:,i1));
%         Emis.mu(:,i2,i1) = (sum(bsxfun(@times, X, gamma_mul_w), 1) / sum(gamma_mul_w))';
%         x_minus_mu = bsxfun(@minus, X, Emis.mu(:,i2,i1)');
%         Emis.Sigma(:,:,i2,i1) = bsxfun(@times, x_minus_mu, gamma_mul_w)' * x_minus_mu / sum(gamma_mul_w);
%         tmp = tmp + gamma_mul_w;
% 
%         
%         if (cov_type=='diag')
%             Emis.Sigma(:,:,i2,i1) = diag(diag(Emis.Sigma(:,:,i2,i1)));
%         end
%         if max(max(Emis.Sigma(:,:,i2,i1))) < cov_thresh    % prevent cov from being too small
%             Emis.Sigma(:,:,i2,i1) = cov_thresh * eye(p);
%         end
%     end
% end

for i1 = 1:Q
    for i2 = 1:M
        gamma_mul_w = gamma(:,i1) .* w(:,i2,i1);
        Emis.pi(i2,i1) = sum(gamma_mul_w) / sum(w(:,i2,i1));
    end
end
for i1 = 1:M
    gamma_mul_w = gamma .* reshape(w(:,i1,:),N,Q);   % size: N*Q
    Emis.mu(:,i1) = sum(X' * gamma_mul_w, 2) / sum(gamma_mul_w(:));
    x_minus_mu = bsxfun(@minus, X, Emis.mu(:,i1)');
    Emis.Sigma(:,:,i1) = bsxfun(@times, x_minus_mu, sum(gamma_mul_w,2))' * x_minus_mu;
    
    if (cov_type=='diag')
        Emis.Sigma(:,:,i1) = diag(diag(Emis.Sigma(:,:,i1)));
    end
    if max(max(Emis.Sigma(:,:,i1))) < cov_thresh    % prevent cov from being too small
        Emis.Sigma(:,:,i1) = cov_thresh * eye(p);
    end
end
Emis.pi
Emis.mu
Emis.Sigma
pause

if M==1
    Emis.pi = ones(1,Q);
else
    Emis.pi = mk_stochastic(Emis.pi')';
end
end