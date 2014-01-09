function output = inerfcm(R, c, options)
%% 
%   Improved Relational Fuzzy c-Means (iRFCM) is an extension on top of the
%   Relational Fuzzy c-Means (RFCM) proposed in [1]. Since RFCM is the
%   relational dual of Fuzzy c-Means (FCM), it expects the input
%   relational matrix R to be Euclidean. Otherwise, RFCM can fail to
%   execute due encountering negative relational distances. iRFCM attempts
%   to solve this problem by Euclideanizing R first before clustering.
%
% Usage: output = irfcm(R,c,options)
%   options is a struct with the following default values:
%
%       fuzzifier        = 2;
%       epsilon          = 0.001;   
%       maxIter          = 100;     
%       initType         = 2;       
%       gamma            = 0;       
%       delta            = [];
%
%   Explanation of those fields is provided below
%
% output    - structure containing:
%               U: fuzzy partition
%               V: cluster centers/coefficients
%               terminationIter: the number of iterations at termination
%               maxIter: maximum number iterations allowed
%
%             If you decide to Euclideniate R before running iRFCM, then the
%             following information will be returned as well
%               kruskalStress: the stress value measured the tranformed R
%               eps: the value that minimized the different between R and D
%               lambda: the smallest constant to add to R to make it Euclidean
%               D: The Euclideaniated matrix
%
% R         - the relational (dissimilarity) data matrix of size n x n
% c         - number of clusters
% fuzzifier - fuzzifier, default 2
% epsilon   - convergence criteria, default 0.0001
% initType  - initialize relational cluster centers V
%               1 = random initialization
%               2 = randomly choose c rows from D
% maxIter   - the maximum number fo iterations, default 100
% delta     - delta is the matrix that is used to tranform R to Euclidean
%               (See ref. [2-3])
%             delta is of size n x n and can be for instance
%                  delta = 1-eye(n)  this is the default delta
%                  delta = subdominant ultrametric matrix
%                  delta = R
%                  delta = power of R
%                  delta = log2(1+D), see [3], page 485
%                  delta = parametric function
%              delta is expected to have an Euclidean representation,
%              otherwise an error will be thrown (see [2])
% gamma     - use it only if you know in advance that this the value that
%             will Euclideanize R
% 
% Refs:
%   [1] R. J. Hathaway and J. C. Bezdek, “Nerf c-means: Non-Euclidean 
%       relational fuzzy clustering,” Pattern Recognition, vol. 27, no. 3, pp. 429–437, Mar. 1994.
%   [2] J. Benasseni, M. B. Dosse, and S. Joly, “On a General Transformation Making a Dissimilarity 
%       Matrix Euclidean,” Journal of Classification, vol. 24, no. 1, pp. 33–51, Jun. 2007.
%   [3] J. Dattorro, Convex optimization and Euclidean distance geometry. 2005.

    %% iRFCM default values
    m = 2; epsilon = 0.0001;maxIter = 100;transformType='NE';
    
    %% Overwrite iRFCM options by the user defined options
    if nargin == 3 && isstruct(options)
        fields = fieldnames(options);
        for i=1:length(fields)
           switch fields{i}
               case 'fuzzifier', m = options.fuzzifier;
               case 'epsilon', epsilon = options.epsilon; 
               case 'initType', initType = options.initType; 
               case 'maxIter', maxIter = options.maxIter;
               case 'transform', transformType = options.transform;
           end
        end
    end
    
    %% Initialize variables
    D = R;n=size(D,1);d = zeros(c,n);bcount = 0;
    numIter=0;stepSize=epsilon;U=Inf(c,n);beta=0.0001;
    
    %some data checking and validation
    if min(min(D)) < 0 || any(any(abs(D - D') > 0)) || max(diag(D)) > 0
		error('R is not properly initialized.')
	elseif size(D) ~= [n,n]
		error('Dimensions R are inconsistent.')
    end
    
    %initialize relational cluster centers
    V = init_centers(initType, n, c, D);
    
    %% Begin the main loop:
    while  numIter < maxIter && stepSize >= epsilon
        U0 = U;
        
        %Get new (quasi-squared-distance values) d:
        % First, get new initial values for d:
        for i=1:c
            d(i,:)=D*V(i,:)'-V(i,:)*D*V(i,:)'/2;
        end
       
        %if D is not Euclideanized RFCM might fail
        %check if any of the relational distances has negative distance
        j = find(d(:) < 0);
        if ~isempty(j)
           %tranform the distance matrices here
           [D d beta] = transform(transformType,D,d,V,U,beta,j);
           bcount = bcount + 1;
        end
        
        %Get new partition matrix U:
        d=d.^(1/(m-1));
		work = 1 ./ d;
		work = sum(work);
        U=1./d;
        U = U./(ones(c,1)*work);
		
        %Get new V prototypes assuming we initialized V first
        V=U.^m;  
        V = V./(sum(V,2) * ones(1,n));
    
        %Calculate step_size and return to top of loop:
		stepSize=max(max(abs(U-U0)));
        
        numIter = numIter + 1;
    end
    
    %prepare output structure
    output = struct('U',U,...
                    'V',V,...
                    'terminationIter',numIter,...
                    'blockerCount',bcount);
                
    if nargin == 3,output.options = options;end
end