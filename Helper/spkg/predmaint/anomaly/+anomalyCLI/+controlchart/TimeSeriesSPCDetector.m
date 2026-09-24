classdef (Sealed = true) TimeSeriesSPCDetector
    % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector" for more information.

    % Copyright 2025-2026 The MathWorks, Inc.

    % References
    %
    % George C. Runger & Thomas R. Willemain (1996) Batch-means control charts
    % for autocorrelated data, IIE Transactions, 28:6, 483-487,
    % DOI: 10.1080/07408179608966295
    %
    % J. Stuart Hunter (1986) The Exponentially Weighted Moving Average,
    % Journal of Quality Technology, 18:4, 203-210,
    % DOI: 10.1080/00224065.1986.11979014

    properties (Constant, Hidden)
        d2 (1,1) double = 1.128 % Gives std = MR/d2
    end

    properties (GetAccess = public, SetAccess = protected)
        % Specified, in general.
        NumChannels (1,1) {mustBeUnderlyingType(NumChannels, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1

        WindowLength (1,1) {mustBeUnderlyingType(WindowLength, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1
        Stride (1,1) {mustBeUnderlyingType(Stride, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1

        Method (1,1) string {mustBeMember(Method, ["individual","ewma"])} = "individual"
        Lambda (1,1) {mustBeUnderlyingType(Lambda, ["single","double"]), mustBeNumeric, mustBeReal, mustBePositive, mustBeLessThanOrEqual(Lambda,1.0)} = 0.4

        DetectionRules (1,:) string {mustBeMember(DetectionRules, ["n","n1","n2","n3","n4","n5","n6","n7","n8","we","we1","we2","we3","we4","we5","we6","we7","we8","we9","we10"])} = "n1"
        Level (1,1) {mustBeUnderlyingType(Level, ["single","double"]), mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 3.0

        % Computed, in general.
        CenterLine (1,:) {mustBeUnderlyingType(CenterLine, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite}
        StandardError (1,:) {mustBeUnderlyingType(StandardError, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite, mustBeNonnegative}

        Mean (1,:) {mustBeUnderlyingType(Mean, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite}
        Sigma (1,:) {mustBeUnderlyingType(Sigma, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite, mustBeNonnegative}
        MeanRange (1,:) {mustBeUnderlyingType(MeanRange, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite, mustBeNonnegative}

        IsTrained (1,1) logical = false
    end

    methods (Access = public)
        function obj = TimeSeriesSPCDetector(numChannels, options)
            arguments
                numChannels (1,1) {mustBeUnderlyingType(numChannels, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1
                options.WindowLength (1,1) {mustBeUnderlyingType(options.WindowLength, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1
                options.Method (1,1) string {mustBeMember(options.Method, ["individual","ewma"])} = "individual"
                options.Lambda (1,1) {mustBeUnderlyingType(options.Lambda, ["single","double"]), mustBeNumeric, mustBeReal, mustBePositive, mustBeLessThanOrEqual(options.Lambda,1.0)} = 0.4
                options.DetectionRules (1,:) string {mustBeMember(options.DetectionRules, ["n","n1","n2","n3","n4","n5","n6","n7","n8","we","we1","we2","we3","we4","we5","we6","we7","we8","we9","we10"])} = "n1"
                options.Level (1,1) {mustBeUnderlyingType(options.Level, ["single","double"]), mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 3.0
            end

            obj.NumChannels = gather(numChannels);

            obj.WindowLength = gather(options.WindowLength);
            obj.Stride = gather(options.WindowLength); % No overlapping windows.
            obj.Method = options.Method;
            obj.Lambda = gather(options.Lambda);
            obj.DetectionRules = options.DetectionRules;
            obj.Level = gather(options.Level);

            % Default statistics before training.
            obj.Mean = zeros(1, obj.NumChannels, 'like', obj.NumChannels);
            obj.Sigma = ones(1, obj.NumChannels, 'like', obj.NumChannels);
            obj.MeanRange = obj.d2 * obj.Sigma;
            [obj.CenterLine, obj.StandardError] = computeChartParameters(obj.Method, obj.Mean, obj.Sigma, obj.Lambda);
        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector/train" for more information.
            arguments
                obj
                data
                options.WindowLength (1,1) {mustBeUnderlyingType(options.WindowLength, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = obj.WindowLength
                options.Method (1,1) string {mustBeMember(options.Method, ["individual","ewma"])} = obj.Method
                options.Lambda (1,1) {mustBeUnderlyingType(options.Lambda, ["single","double"]), mustBeNumeric, mustBeReal, mustBePositive, mustBeLessThanOrEqual(options.Lambda,1.0)} = obj.Lambda
            end

            % Assign before data validation.
            obj.WindowLength = gather(options.WindowLength);
            obj.Stride = gather(options.WindowLength); % No overlapping windows.
            obj.Method = options.Method;
            obj.Lambda = gather(options.Lambda);

            % Validate here since data size vs WindowLength compatibility might have changed.
            validateInputData(obj, data);
            data = convertDataToCellArray(data);

            % Train and update properties.
            Y = cellfun(@(Xj) computeBatchMeans(Xj, obj.WindowLength, obj.Stride), data, UniformOutput=false);
            [obj.Mean, obj.Sigma, obj.MeanRange] = computeStatistics(Y);
            [obj.CenterLine, obj.StandardError] = computeChartParameters(obj.Method, obj.Mean, obj.Sigma, obj.Lambda);

            obj.IsTrained = true;
        end

        function results = detect(obj, data, options)
            % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector/detect" for more information.
            arguments
                obj
                data {validateInputData(obj, data)}
                options.Resolution(1,1) string {mustBeMember(options.Resolution,["sample","window","member"])} = "window"
                options.LabelConversionMethod (1,1) string {mustBeMember(options.LabelConversionMethod, ["majorityVoting","normalPriority","anomalyPriority"])}
                options.AnomalousWindowPercentage (1,1) double {mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
            end

            % Check if AnomalousWindowPercentage is explicitly set but won't be
            % used.
            if options.Resolution ~= "member" && isfield(options, 'AnomalousWindowPercentage')
                warning(message("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage"));
            end

            % Check if LabelConversionMethod is explicitly set but won't be
            % used.
            if (options.Resolution ~= "sample") && isfield(options, 'LabelConversionMethod')
                warning(message("predmaint_anomaly:anomaly:warnUnusedLabelConversionMethod"));
            end

            % Set default AnomalousWindowPercentage if Resolution is "member"
            % but AnomalousWindowPercentage is not supplied.
            if options.Resolution == "member" && ~isfield(options, 'AnomalousWindowPercentage')
                options.AnomalousWindowPercentage = 10;
            end

            % Set default LabelConversionMethod if Resolution is "sample"
            % but LabelConversionMethod is empty.
            if (options.Resolution == "sample") && ~isfield(options, 'LabelConversionMethod')
                options.LabelConversionMethod = "anomalyPriority";
            end

            % Algorithm has to be trained first.
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

            data = convertDataToCellArray(data);

            % Detect anomalies.
            Y = cellfun(@(Xj) computeBatchMeans(Xj, obj.WindowLength, obj.Stride), data, UniformOutput=false);
            if (obj.Method == "individual")
                Z = Y;
            else
                Z = cellfun(@(Yj) obj.computeEWMA(Yj, obj.Lambda, obj.CenterLine), Y, UniformOutput=false);
            end

            n = numel(Z);
            results = findAnomalies(obj, Z);

            switch options.Resolution
                case "window"
                    % Already in the right form.
                case "sample"
                    for i = 1:n
                        [sampleLabels, sampleScores, sampleIndices] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            results{i}.Labels, obj.WindowLength, results{i}.StartIndices, ...
                            'Method', options.LabelConversionMethod, ...
                            'DataLength', size(data{i},1), ...
                            'WinScores', results{i}.AnomalyScores);

                        results{i} = table(sampleLabels, sampleScores, sampleIndices, ...
                            VariableNames=["Labels","AnomalyScores","StartIndices"]);
                    end
                case "member"
                    numWindows = cellfun(@(r) height(r), results);
                    winScores = vertcat(results{:}).AnomalyScores;
                    [memberLabels, memberScores, memberIndex] = ...
                        anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        winScores, numWindows, options.AnomalousWindowPercentage, 0);
                    results = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        VariableNames=["Labels","AnomalyScores","MemberIndices"]);
            end

            % Special case for single member data set (window/sample only).
            if options.Resolution ~= "member" && (n == 1)
                results = results{1};
            end
        end

        function obj = updateDetector(obj, data, options)
            % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector/updateDetector" for more information.
            arguments
                obj
                data = []
                options.DetectionRules (1,:) string {mustBeMember(options.DetectionRules, ["n","n1","n2","n3","n4","n5","n6","n7","n8","we","we1","we2","we3","we4","we5","we6","we7","we8","we9","we10"])} = obj.DetectionRules
                options.Level (1,1) {mustBeUnderlyingType(options.Level, ["single","double"]), mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = obj.Level
                options.CenterLine (1,:) {mustBeUnderlyingType(options.CenterLine, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite}
                options.StandardError (1,:) {mustBeUnderlyingType(options.StandardError, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite, mustBeNonnegative}
                options.Mean (1,:) {mustBeUnderlyingType(options.Mean, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite}
                options.Sigma (1,:) {mustBeUnderlyingType(options.Sigma, ["single","double"]), mustBeFloat, mustBeReal, mustBeFinite, mustBeNonnegative}
            end

            % To be able to overwrite some properties after train().
            hasCenterLine = isfield(options, 'CenterLine');
            hasStandardError = isfield(options, 'StandardError');
            hasMean = isfield(options, 'Mean');
            hasSigma = isfield(options, 'Sigma');

            % Train and update properties.
            if ~isempty(data)
                obj = train(obj, data); % Validates non-empty data in train().
            end

            % Algorithm has to be trained first.
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

            % Mean or Sigma was set.
            if hasMean
                obj.Mean(:) = gather(options.Mean); % Implicit expansion.
                obj.Mean = cast(obj.Mean, like=gather(options.Mean));
            end
            if hasSigma
                obj.Sigma(:) = gather(options.Sigma); % Implicit expansion.
                obj.Sigma = cast(obj.Sigma, like=gather(options.Sigma));
            end
            if hasMean || hasSigma
                [obj.CenterLine, obj.StandardError] = computeChartParameters(obj.Method, obj.Mean, obj.Sigma, obj.Lambda);
            end

            % CenterLine or StandardError was set.
            if hasCenterLine
                obj.CenterLine(:) = gather(options.CenterLine); % Implicit expansion.
                obj.CenterLine = cast(obj.CenterLine, like=gather(options.CenterLine));
            end
            if hasStandardError
                obj.StandardError(:) = gather(options.StandardError); % Implicit expansion.
                obj.StandardError = cast(obj.StandardError, like=gather(options.StandardError));
            end

            % Assign remaining properties.
            obj.DetectionRules = options.DetectionRules;
            obj.Level = gather(options.Level);
        end

        function plot(obj, data, options)
            % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector/plot" for more information.
            arguments
                obj
                data {validateInputData(obj, data)}
                options.PlotType {mustBeTextScalar, mustBeMember(options.PlotType, ["anomaly", "anomalyScores", "all"])} = "all"
            end

            % Detect
            [data, names] = convertDataToCellArray(data);
            if numel(data) > 1
                error(message("predmaint_anomaly:anomaly:errInvalidBatchInput"));
            end
            windowResults = detect(obj, data);

            % Plots
            ax = newplot;
            ax.NextPlot = 'replace';

            fig = ancestor(ax, 'figure');
            matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
            t = tiledlayout(fig, 'vertical');

            if any(options.PlotType == ["anomaly", "all"])
                % Raw data plot
                ax1 = nexttile(t);
                anomalyCLI.internal.utils.AnomalyDetection.plotAnomalies(ax1, data{1}, names, ...
                    windowResults, obj.WindowLength);

                % Batch-mean data plot.
                Y = cellfun(@(Xj) computeBatchMeans(Xj, obj.WindowLength, obj.Stride), data, UniformOutput=false);
                if (obj.Method == "individual")
                    Z = Y;
                else
                    Z = cellfun(@(Yj) obj.computeEWMA(Yj, obj.Lambda, obj.CenterLine), Y, UniformOutput=false);
                end
                [UCL,LCL] = computeChartLimits(obj.CenterLine, obj.StandardError, obj.Level);
                CL = obj.CenterLine;

                ax2 = nexttile(t);
                anomalyCLI.internal.utils.AnomalyDetection.plotControlChart(ax2, Z, names, ...
                    windowResults, obj.WindowLength, obj.Method, CL, LCL, UCL);
            end

            if any(options.PlotType == ["anomalyScores", "all"])
                % Anomaly scores plot.
                ax3 = nexttile(t);
                threshold = NaN; % Do not show threshold.
                anomalyCLI.internal.utils.AnomalyDetection.plotScores(ax3, windowResults, threshold);
            end

            allAxes = findobj(t, Type='Axes');
            linkaxes(allAxes, 'x');

            % Setup to manage plot interactivity.
            set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.
        end

        function plotHistogram(obj, data)
            % Run "doc anomalyCLI.controlchart.TimeSeriesSPCDetector/plotHistogram" for more information.
            arguments
                obj
            end
            arguments (Repeating)
                data {validateInputData(obj, data)}
            end

            % Detect
            function scores = localDetect(data)
                data = convertDataToCellArray(data);
                if numel(data) > 1
                    error(message("predmaint_anomaly:anomaly:errInvalidBatchInput"));
                end
                windowResults = detect(obj, data);
                scores = windowResults.AnomalyScores;
            end
            scores = cellfun(@(c) localDetect(c), data, UniformOutput=false);

            % Plots
            ax = newplot;
            ax.NextPlot = 'replace';

            fig = ancestor(ax, 'figure');
            matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
            t = tiledlayout(fig, 'vertical');

            % Histogram plot
            ax = nexttile(t);
            threshold = NaN; % Do not show threshold.
            anomalyCLI.internal.utils.AnomalyDetection.plotHistogram(ax, scores, threshold);

            % Setup to manage plot interactivity.
            set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.
        end
    end

    methods (Static, Access = public)
        function Z = computeEWMA(X, lambda, target)
            % Columnwise EWMA of matrix X.
            [nr,nc] = size(X);

            Z = zeros(nr, nc, "like", X);
            Zk = target;
            for k = 1:nr
                Z(k,:) = lambda*X(k,:) + (1-lambda)*Zk;
                Zk = Z(k,:);
            end
        end
    end

    methods (Access = private)
        function validateInputData(obj, data)
            import anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing;
            TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.WindowLength, obj.Stride);
        end

        function windowResults = findAnomalies(obj, Z)
            n = numel(Z);
            windowResults = cell(n,1);

            % Detect anomalies in all members.
            for k = 1:n
                [nr,nc] = size(Z{k});
                windowLabels = false(nr, 1);
                windowScores = zeros(nr, 1, 'like', Z{k});
                windowIndices = 1 + cast(obj.Stride, underlyingType(Z{k})) * (0:nr-1)';
                windowRules = cell(nr,1);

                % Detect anomalies in each column of data.
                for j = 1:nc
                    [J1,rules1] = controlrules(obj.DetectionRules, Z{k}(:,j), obj.CenterLine(j), obj.StandardError(j));
                    [rules1,I1] = unique(rules1(:)'); % rules1 is not always a row.
                    J1 = J1(:,I1);

                    [J2,rules2] = computeDefaultRules(Z{k}(:,j), obj.CenterLine(j), obj.StandardError(j), obj.Level);
                    J = [J1, J2];
                    rules = string([rules1, rules2]);

                    % Combine anomaly information across columns.
                    windowLabels = windowLabels | any(J,2);
                    windowScores = windowScores + sum(J,2);

                    % Find which rules were applied for each row of current data column.
                    for r = 1:nr
                        windowRules{r} = unique([windowRules{r}, rules(J(r,:))]);
                    end
                end

                % Normalize scores by max number of detected anomalies.
                if any(windowLabels)
                    windowScores = windowScores / max(windowScores); % No divide by zero here.
                end

                windowResults{k} = table(gather(windowLabels), gather(windowScores), ...
                    gather(windowIndices), windowRules, ...
                    VariableNames=["Labels","AnomalyScores","StartIndices","ActiveRules"]);
            end
        end
    end

    methods (Static,Hidden)
        function n = matlabCodegenRedirect(~)
            n = 'anomalyCLI.coder.controlchart.TimeSeriesSPCDetector';
        end
    end
end


%% Helper functions
function Y = computeBatchMeans(X, b, s)
    % Columnwise batch means of matrix X with batch size b and stride s.
    [nr,nc] = size(X);
    nb = floor((nr+s-b)/s); % Number of batches.

    Y = zeros(nb, nc, "like", X);
    for i = 1:nb
        I = (i-1)*s + (1:b); % Rows of kth batch.
        Y(i,:) = mean(X(I,:), 1, "omitmissing"); % Mean of each column for rows I.
    end
end

function [mu,sigma,mr] = computeStatistics(C)
    % Columnwise statistics across all elements of cell array C.
    n = numel(C);
    nc = size(C{1}, 2); % All cell elements have the same number of columns.

    mu = zeros(1, nc, "like", C{1});
    sigma = zeros(1, nc, "like", C{1});
    mr = zeros(1, nc, "like", C{1}); % Moving range average.

    % Processing columnwise across all members.
    % TODO: Needs optimization for GPU and/or multi-core processing.
    for j = 1:nc
        v = [];
        d = [];
        for k = 1:n
            % Append column j across all members.
            Xj = C{k}(:,j);
            v = [v; Xj];
            d = [d; abs(diff(Xj))]; % Does not diff across member boundaries.
        end
        mu(j) = mean(v, "omitmissing");
        sigma(j) = std(v, "omitmissing");
        mr(j) = mean(d, "omitmissing");
    end

    % Use CPU types after computation loop.
    mu = gather(mu);
    sigma = gather(sigma);
    mr = gather(mr);
end

function [CL,SE] = computeChartParameters(method, target, sigma, lambda)
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

function [J,rules] = computeDefaultRules(x, CL, SE, level)
    % Check if data is beyond level*SE from CL.
    [UCL,LCL] = computeChartLimits(CL, SE, level);
    J = (x < LCL) | (x > UCL);
    rules = {'default'};
end

function [UCL,LCL] = computeChartLimits(CL, SE, level)
    % Computes the control chart limits of each channel from the control chart
    % parameters.
    UCL = CL + level*SE;
    LCL = CL - level*SE;
end

function [data, varnames] = convertDataToCellArray(data)
    import anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing;
    [data, varnames] = TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
end

function s = msg(id,varargin)
    % Read string with the given ID from a resource bundle
    s = string(message(id, varargin{:}));
end
