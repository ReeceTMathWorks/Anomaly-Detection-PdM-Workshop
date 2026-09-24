classdef TimeSeriesSPCDetector
    %#codegen

    %   Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = protected)
        NumChannels
        WindowLength
        Stride
        Method
        Lambda      
        Level
        CenterLine
        StandardError
        Mean
        Sigma
        MeanRange
        IsTrained = true;
    end

    properties (Access = private)
        pDetectionRulesIdx
        pNumRules
        pAllRules
    end

    properties(Dependent)
       DetectionRules
    end

    methods
        function obj = TimeSeriesSPCDetector(opts)
            fn = fieldnames(opts);
            coder.unroll();
            for i = 1:numel(fn)
                obj.(fn{i}) = opts.(fn{i});
            end
        end

        function tbl = detect(obj,data,options)
            arguments
                obj
                data {validateInputData(obj, data)}
                options.Resolution(1,1) string {coder.mustBeConst(options.Resolution,...
                    "predmaint_anomaly:anomaly:optionMustBeConst","Resolution"),mustBeMember(options.Resolution,{'sample','window','member'})} = "window"
                options.LabelConversionMethod (1,1) string {coder.mustBeConst(options.LabelConversionMethod,...
                    "predmaint_anomaly:anomaly:optionMustBeConst","LabelConversionMethod"),mustBeMember(options.LabelConversionMethod,...
                    {'majorityVoting','normalPriority','anomalyPriority'})}
                options.AnomalousWindowPercentage (1,1) double {coder.mustBeConst(options.AnomalousWindowPercentage,...
                    "predmaint_anomaly:anomaly:optionMustBeConst","AnomalousWindowPercentage"),...
                    mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
            end
            coder.internal.prefer_const(options);
            if iscell(data)
                coder.internal.assert(coder.internal.isConst(size(data)),"predmaint_anomaly:anomaly:cellInputToDetectMustBeFixedSize");
            end
            hasLabelConversion = isfield(options, 'LabelConversionMethod');
            hasAnomalousWindowPercentage = isfield(options, 'AnomalousWindowPercentage');
            switch options.Resolution
                case "window"
                    if hasLabelConversion
                        coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedLabelConversionMethod");
                    end
                    if hasAnomalousWindowPercentage
                        coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage");
                    end
                    labelConversionMethod = "";
                    anomalousWindowPercentage = 10;
                case "sample"
                    if hasLabelConversion
                        labelConversionMethod = options.LabelConversionMethod;
                    else
                        labelConversionMethod = "anomalyPriority";
                    end
                    if hasAnomalousWindowPercentage
                        coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage");
                    end
                    anomalousWindowPercentage = 10;
                case "member"
                    if hasLabelConversion
                        coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedLabelConversionMethod");
                    end
                    if hasAnomalousWindowPercentage
                        anomalousWindowPercentage = options.AnomalousWindowPercentage;
                    else
                        anomalousWindowPercentage = 10;
                    end
                    labelConversionMethod = "";
            end
            dataCell = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            Y = cellfun(@(Xj)computeBatchMeans(Xj,obj.WindowLength,obj.Stride),dataCell,UniformOutput=false);
            if (obj.Method == "individual")
                Z = Y;
            else
                Z = cellfun(@(Yj) obj.computeEWMA(Yj, obj.Lambda, obj.CenterLine), Y, UniformOutput=false);
            end

            n = numel(Z);
            results = findAnomalies(obj, Z, options.Resolution);
            switch options.Resolution
                case "window"
                    if n == 1
                        tbl = results{1};
                    else
                        tbl = results;
                    end
                case "sample"
                    out = cell(n,1);
                    coder.unroll(~coder.internal.isHomogeneousCell(results) || ~coder.internal.isHomogeneousCell(dataCell))
                    for i = 1:n
                        [sampleLabels, sampleScores, sampleIndices] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            results{i}.Labels, obj.WindowLength, results{i}.StartIndices, ...
                            'Method', labelConversionMethod, ...
                            'DataLength', size(dataCell{i},1), ...
                            'WinScores', results{i}.AnomalyScores);

                        out{i} = table(sampleLabels, sampleScores, sampleIndices, ...
                            VariableNames={'Labels','AnomalyScores','StartIndices'});
                    end
                    if n == 1
                        tbl = out{1};
                    else
                        tbl = out;
                    end
                case "member"
                    numWindows = zeros(n, 1);
                    totalWindows = coder.internal.indexInt(0);
                    coder.unroll(~coder.internal.isHomogeneousCell(results))
                    for i = 1:n
                        numWindows(i) = size(results{i}.AnomalyScores, 1);
                        totalWindows = totalWindows + numWindows(i);
                    end
                    winScores = coder.nullcopy(zeros(totalWindows, 1, "like", results{1}.AnomalyScores));
                    offset = coder.internal.indexInt(0);
                    coder.unroll(~coder.internal.isHomogeneousCell(results))
                    for i = 1:n
                        nw = coder.internal.indexInt(numWindows(i));
                        winScores(offset+1:offset+nw) = results{i}.AnomalyScores;
                        offset = offset + nw;
                    end
                    [memberLabels, memberScores, memberIndex] = ...
                        anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        winScores, numWindows, anomalousWindowPercentage, 0);
                    tbl = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        VariableNames={'Labels','AnomalyScores','MemberIndices'});
            end

        end

        function obj = updateDetector(obj,data,options)
            arguments
                obj
                data = []
                options.Level (1,1) {mustBeUnderlyingType(options.Level, {'single','double'}), mustBeReal, mustBeFinite, mustBePositive} = obj.Level
                options.CenterLine (1,:) {mustBeUnderlyingType(options.CenterLine, {'single','double'}), mustBeReal, mustBeFinite}
                options.StandardError (1,:) {mustBeUnderlyingType(options.StandardError, {'single','double'}), mustBeReal, mustBeFinite, mustBeNonnegative}
                options.Mean (1,:) {mustBeUnderlyingType(options.Mean, {'single','double'}), mustBeReal, mustBeFinite}
                options.Sigma (1,:) {mustBeUnderlyingType(options.Sigma, {'single','double'}), mustBeReal, mustBeFinite, mustBeNonnegative}
                options.DetectionRules {coder.mustBeConst,mustBeMember(options.DetectionRules,{'n','n1','n2','n3','n4','n5','n6','n7','n8','we','we1','we2','we3','we4','we5','we6','we7','we8','we9','we10'})}
            end
            hasCenterLine = isfield(options, 'CenterLine');
            hasStandardError = isfield(options, 'StandardError');
            hasMean = isfield(options, 'Mean');
            hasSigma = isfield(options, 'Sigma');

            if ~coder.internal.isConstTrue(isempty(data))
                coder.internal.compileWarning("predmaint_anomaly:anomaly:UpdateDetectorIgnoresData");
            end
            % Mean or Sigma was set.
            if hasMean
                obj.Mean(:) = options.Mean; % Implicit expansion.
            end
            if hasSigma
                obj.Sigma(:) = options.Sigma;
            end
            if hasMean || hasSigma
                [obj.CenterLine, obj.StandardError] = computeChartParameters(obj.Method, obj.Mean, obj.Sigma, obj.Lambda);
            end

            % CenterLine or StandardError was set.
            if hasCenterLine
                obj.CenterLine(:) = options.CenterLine;
            end
            if hasStandardError
                obj.StandardError(:) = options.StandardError;
            end
            obj.Level = options.Level;
            if isfield(options,'DetectionRules')
                [~,newRules] = coder.const(@feval,'controlrules',options.DetectionRules,zeros(5,1),1,1);
                newRulesRow =  reshape(coder.const(@feval,'sort',newRules),1,[]);
                [obj.pDetectionRulesIdx,obj.pNumRules] = coder.const(@feval,...
                    'anomalyCLI.coder.controlchart.TimeSeriesSPCDetector.rulesToIndex',newRulesRow,obj.pAllRules);
            end
        end

        
    end

    methods(Access = private)
        function validateInputData(obj, data)
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(...
                data, obj.NumChannels, obj.WindowLength, obj.Stride);
        end

        function windowResults = findAnomalies(obj,Z, resolution)
            coder.internal.prefer_const(resolution);
            isWindowResolution = resolution == "window";
            MaxNumRules = length(obj.pAllRules)+1; %(+1 for 'default')
            n = coder.internal.indexInt(numel(Z));
            windowResults = cell(n,1);
            numRules = obj.pNumRules + 1; %(+1 for 'default')
            assert(numRules <= MaxNumRules);
            
            activeRules_ = [{'default'}, obj.DetectionRules];
            activeRules = activeRules_;
            if ~coder.internal.isHomogeneousCell(activeRules_)
                % we will be indexing into the cell array, homogenize it so
                % that indexing can be done with non constant indexes.
                coder.internal.tryMakeHomogeneousCell(activeRules);
            end
            coder.unroll(~coder.internal.isHomogeneousCell(Z));
            for k = 1:n
                [nr,nc] = size(Z{k});
                windowScores = zeros(nr,1,"like",Z{k});
                windowIndices = 1 + obj.Stride*(0:nr-1)';
                if isWindowResolution
                    % possible rules are n1, n2..n8, we1, we2..we10 and
                    % default, together they can be represented by a
                    % variable-length character vector whose maximum length
                    % is seven.
                    coder.varsize('aRule',[1 7],[0 1]);
                    aRule = char(zeros(1,0));

                    %Number of rules violated by a given window can vary
                    %from 0 to numRules. So the collection of rules
                    %violated by a given window can be represented by a
                    %row cell array whose length varies from zero (no
                    %violation) to numRules (all rules violated). The
                    %elements of the cell array are character vectors as
                    %described above.
                    coder.varsize('aRuleCell',[1 MaxNumRules],[0 1]);
                    aRuleCell = {aRule};

                    % we have nr number of windows, for each window the
                    % rules violated are represented in a cell array as
                    % described above.
                    windowRules = coder.nullcopy(repmat({aRuleCell},nr,1));
                    Jwindow = false(nr, numRules);
                end
                for j = 1:nc
                    % J(i,j) = true => for the current channel, ith window
                    % violates jth rule.
                    J = controlrules(obj,activeRules,Z{k}(:,j), obj.CenterLine(j), obj.StandardError(j),obj.Level);
                    windowScores = windowScores + sum(J,2);
                    if isWindowResolution
                        % Accumulate the result for all channels.
                        Jwindow = Jwindow | J;
                    end
                end
                windowLabels = windowScores > 0;
                if any(windowLabels)
                    windowScores = windowScores/max(windowScores);
                end
                if isWindowResolution
                    for r = 1:nr
                        % idx = Jwindow(r,:);
                        % windowRules{r} = reshape({allRules{idx}},1,[]);
                        idx = Jwindow(r,:);
                        numViolations = coder.internal.indexInt(sum(idx));
                        % Clue coder about the maximum number of violation
                        % so as to give an upper bound for the length of
                        % array.
                        assert(numViolations <= numRules); %<HINT>
                        windowRules{r} = coder.nullcopy(repmat(aRuleCell,1,numViolations));
                        m = coder.internal.indexInt(0);
                        for i = coder.internal.indexInt(1):numel(idx)
                            if idx(i)
                                m = m + 1;
                                windowRules{r}{m} = activeRules{i};
                            end
                        end
                        assert(m==numViolations); % Sanity check.
                    end
                    windowResults{k} = table(windowLabels, windowScores, windowIndices, windowRules, ...
                        VariableNames={'Labels','AnomalyScores','StartIndices','ActiveRules'});
                else
                    windowResults{k} = table(windowLabels, windowScores, windowIndices,...
                        VariableNames={'Labels','AnomalyScores','StartIndices'});
                end
            end
        end

        function J = controlrules(~,activeRules,x,cl,se,level)
            numRules = coder.internal.indexInt(length(activeRules));
            assert(numRules <= 19);
            J = coder.nullcopy(false(length(x),numRules));
            coder.unroll(false)
            for i = 1:numRules
                switch activeRules{i}
                    case 'we1'
                        J(:,i) = x > (cl + 3*se);
                    case 'we2'
                        hi = cl + 2*se;
                        cnts = filter(ones(1,3,"like",x), ones("like",x), x > hi); % count from triple
                        J(:,i) = (cnts >= 2) & (x > hi);
                    case 'we3'
                        hi = cl + se;
                        cnts = filter(ones(1,5,"like",x), ones("like",x), x > hi);
                        J(:,i) = (cnts >= 4) & (x > hi);
                    case 'we4'
                        cnts = filter(ones(1,8,"like",x), ones("like",x), x > cl);
                        J(:,i) = (cnts >= 8);
                    case 'we5'
                        J(:,i) = x < (cl - 3*se);
                    case 'we6'
                        lo = cl - 2*se;
                        cnts = filter(ones(1,3,"like",x), ones("like",x), x < lo);
                        J(:,i) = (cnts >= 2) & (x < lo);
                    case 'we7'
                        lo = cl - se;
                        cnts = filter(ones(1,5,"like",x), ones("like",x), x < lo);
                        J(:,i) = (cnts >= 4) & (x < lo);
                    case 'we8'
                        cnts = filter(ones(1,8,"like",x), ones("like",x), x < cl);
                        J(:,i) = (cnts >= 8);
                    case 'we9'
                        cnts = filter(ones(1,15,"like",x), ones("like",x), (x > cl - se) & (x < cl + se));
                        J(:,i) = (cnts >= 15);
                    case 'we10'
                        cnts = filter(ones(1,8,"like",x), ones("like",x), (x < (cl-se)) | (x > cl + se));
                        J(:,i) = (cnts >= 8);
                        % Nelson rules
                    case 'n1'
                        J(:,i) = (x > cl + 3*se) | (x < cl - 3*se);
                    case 'n2'
                        cnts1 = filter(ones(1,9,"like",x), ones("like",x), x > cl);
                        cnts2 = filter(ones(1,9,"like",x), ones("like",x), x < cl);
                        J(:,i) = (cnts1 >= 9) | (cnts2 >= 9);
                    case 'n3'
                        diffx = [0; diff(x)];
                        cnts1 = filter(ones(1,5,"like",x), ones("like",x), diffx > 0);
                        cnts2 = filter(ones(1,5,"like",x), ones("like",x), diffx < 0);
                        J(:,i) = (cnts1 >= 5) | (cnts2 >= 5);
                    case 'n4'
                        signs = ones(size(x),"like",x);
                        signs(2:2:end) = -1;
                        diffx = [0; sign(diff(x))] .* signs;
                        cnts = filter(ones(1,13,"like",x), ones("like",x), diffx);
                        J(:,i) = (cnts <= -13) | (cnts >= 13);
                    case 'n5'
                        hi = cl + 2*se;
                        lo = cl - 2*se;
                        cnts1 = filter(ones(1,3,"like",x), ones("like",x), x > hi);
                        cnts2 = filter(ones(1,3,"like",x), ones("like",x), x < lo);
                        J(:,i) = (cnts1 >= 2  &  x > hi)  |  (cnts2 >= 2  &  x < lo);
                    case 'n6'
                        hi = cl + se;
                        lo = cl - se;
                        cnts1 = filter(ones(1,5,"like",x), ones("like",x), x > hi);
                        cnts2 = filter(ones(1,5,"like",x), ones("like",x), x < lo);
                        J(:,i) = (cnts1 >= 4  &  x > hi)  |  (cnts2 >= 4  &  x < lo);
                    case 'n7'
                        cnts = filter(ones(1,15,"like",x), ones("like",x), (x > cl - se) & (x < cl + se));
                        J(:,i) = (cnts >= 15);
                    case 'n8'
                        cnts = filter(ones(1,8,"like",x), ones("like",x), x< cl -se | x > cl + se);
                        J(:,i) = (cnts >= 8);
                    case 'default'
                        J(:,i) = computeDefaultRules(x,cl,se,level);
                end
            end
        end
    end

    methods
        function rules = get.DetectionRules(obj)
             
            allRules = obj.pAllRules;
            if ~coder.internal.isHomogeneousCell(allRules)
                p = coder.internal.tryMakeHomogeneousCell(allRules); %#ok
            end
            numRules = obj.pNumRules;
            assert(numRules <= length(allRules));
            coder.varsize('ch',[1 4],[0 1]);
            ch='n1';
            rules = coder.nullcopy(repmat({ch},1,numRules));
            for i = 1:numRules
                rules{i} = allRules{obj.pDetectionRulesIdx(i)};
            end           
        end
    end

    methods (Static, Access = public)
        function Z = computeEWMA(X, lambda, target)
            % Columnwise EWMA of matrix X.
            nr = coder.internal.indexInt(size(X,1));
            nc = coder.internal.indexInt(size(X,2));

            Z = coder.nullcopy(zeros(nr, nc, "like", X));
            Zk = cast(target,"like",X);
            oneMlambda = (1-lambda);
            for k = 1:nr
                Z(k,:) = lambda*X(k,:) + oneMlambda*Zk;
                Zk = Z(k,:);
            end
        end
    end

    methods(Static,Hidden)
        function props = matlabCodegenNontunableProperties(~)
            props = {'NumChannels', 'WindowLength', 'Stride', 'Method', 'IsTrained','pAllRules'};
        end

        function cgObj = matlabCodegenToRedirected(mlObj)
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(mlObj.IsTrained);
            props = properties('anomalyCLI.coder.controlchart.TimeSeriesSPCDetector');

            for i = 1:numel(props)
                opts.(props{i}) = mlObj.(props{i});
            end
            % No string array support in coder, use cell array of chars
            % instead.
            opts.DetectionRules = cellstr(opts.DetectionRules);
            % Make a dummy call to control rules, this will expand "we" to ...
            % "we1", "we2"..."we10" and "n" to "n1", "n2"..."n8" if
            % present.
            [~,aDetectionRules] = controlrules(opts.DetectionRules,zeros(10,1),opts.CenterLine(1),opts.StandardError(1));
            aDetectionRules = reshape(sort(aDetectionRules),1,[]);
            [~,opts.pAllRules] = controlrules(["we" "n"],zeros(10,1),1,1);
            opts.pAllRules = reshape(opts.pAllRules,1,[]);
            [opts.pDetectionRulesIdx, opts.pNumRules] = anomalyCLI.coder.controlchart.TimeSeriesSPCDetector.rulesToIndex(...
                aDetectionRules,opts.pAllRules);
            opts = rmfield(opts,'DetectionRules');
            cgObj = anomalyCLI.coder.controlchart.TimeSeriesSPCDetector(opts);           
        end

        function [idx,numRules] = rulesToIndex(activeRules,allRules)
            numRules = length(activeRules);
            idx = zeros(length(allRules),1,'uint8');
            for i = 1:numRules
                idx(i) = find(strcmp(activeRules{i},allRules));
            end
            numRules = uint8(numRules);
        end

    end
end

function Y = computeBatchMeans(X,windowLength,stride)
nr = coder.internal.indexInt(size(X,1));
nc = coder.internal.indexInt(size(X,2));

b = coder.internal.indexInt(windowLength);
s = coder.internal.indexInt(stride);
nb = coder.internal.indexDivide(nr+s-b,s);

Y = coder.nullcopy(zeros(nb,nc,"like",X));
for i = 1:nb
    Y(i,:) = mean(X((i-1)*s + (1:b),:), "omitmissing");
end
end

function J = computeDefaultRules(x, CL, SE, level)
% Check if data is beyond level*SE from CL.
UCL = CL + level*SE;
LCL = CL - level*SE;
J = (x < LCL) | (x > UCL);
end

function [CL,SE] = computeChartParameters(method, target, sigma, lambda)
coder.internal.prefer_const(method)
% Computes the center line and the standard error of each channel from the
% statistics of all members of batched training data.
switch method
    case "individual"
        CL = target;
        SE = sigma;
    case "ewma"
        CL = target;
        SE = sigma * sqrt(lambda/(2-lambda));
end
end



