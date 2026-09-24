classdef (Abstract) AbstractMachineLearningAnomalyDetector < matlab.mixin.CustomDisplay
    %

    % Copyright 2025-2026 The MathWorks, Inc.

    % Public Properties (read-only)
    properties (GetAccess = public, SetAccess = protected)
        % IsTrained - Logical indicator indicating whether the network is trained or not
        NumChannels (1, 1) double

        IsTrained (1, 1) logical = false

        WindowLength (1, 1) double

        TrainingStride (1, 1) double
        DetectionStride (1, 1) double

        % Threshold-related properties.

        %Threshold - threshold used to detect anomalies
        Threshold double

        %ThresholdMethod - Method for threshold computation
        ThresholdMethod (1,1) string

        %ThresholdParameter - Parameter for threshold computation
        ThresholdParameter double

        %ThresholdFunction - Custom function for threshold computation.
        %Applies only when ThresholdMethod is "customFunction"
        ThresholdFunction

        %Normalization method
        Normalization (1, 1)

        % Flag
        FeatureExtraction (1,1) logical
    end


    % Protected properties
    properties (Hidden,Access=protected)
        % pModel - internal model
        pModel

        % Normalization parameters
        % pDataCenter - data center obtained from training data
        pDataCenter

        % pDataScale - data scale obtained from training data
        pDataScale

        % pValidFeatureColumns - logical vector to indicate the valid (not
        % all NaN) columns in the feature array.
        pValidFeatureColumns = []
    end

    %% Public Methods
    methods (Access=public)
        % Constructor function
        function obj = AbstractMachineLearningAnomalyDetector(options)
            % Construct a base AnomalyDetector object
            arguments
                options.WindowLength (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 10
                options.TrainingStride (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
                options.DetectionStride (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite}
                options.FeatureExtraction (1,1) logical = true
                options.Threshold = [];
                options.ThresholdMethod (1, 1) string {mustBeMember(options.ThresholdMethod,["contaminationFraction","manual","customFunction","mean","median","max", "kSigma"])}
                options.ThresholdParameter =[];
                options.ThresholdFunction = [];
                options.Normalization (1, 1) {mustBeMember(options.Normalization,["off","zscore","range"])} ="zscore";
            end

            % Validate properties
            options = iValidateThresholdProperties(obj, options);

            if ~isfield(options, 'DetectionStride')
                options.DetectionStride = options.WindowLength;
            end

            % set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = gather(options.(field{i}));
                end
            end
        end

        function result = detect(obj, data, options)
            % Run "doc anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector/detect" for more information.
            arguments
                obj (1,1) anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
                data (:,:) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable"])}
                options.Resolution(1,1) string {mustBeMember(options.Resolution,["sample","window","member"])} = "window"
                options.AnomalousWindowPercentage (1,1) double {mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
                options.LabelConversionMethod (1,1) string {mustBeMember(options.LabelConversionMethod, ["majorityVoting","normalPriority","anomalyPriority"])}
            end

            if iscell(data) && any(cellfun(@(x) isa(x, 'gpuArray'), data(:)))
                error(message("predmaint_anomaly:anomaly:errInvalidCellMemberType"))
            end

            if options.Resolution ~= "member" && isfield(options, 'AnomalousWindowPercentage')
                warning(message("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage"));
            end

            if options.Resolution ~= "sample" && isfield(options, 'LabelConversionMethod')
                warning(message("predmaint_anomaly:anomaly:warnUnusedLabelConversionMethod"));
            end

            if options.Resolution == "member" && ~isfield(options, 'AnomalousWindowPercentage')
                options.AnomalousWindowPercentage = 10;
            end

            if options.Resolution == "sample" && ~isfield(options, 'LabelConversionMethod')
                options.LabelConversionMethod = "anomalyPriority";
            end

            [winScores, dataCell, segmentInfo] = iGetWinScores(obj, data);
            winLabels = winScores > obj.Threshold;

            numCells = numel(segmentInfo.numWindows);
            endIdx = cumsum(segmentInfo.numWindows);
            startIdx = [1; endIdx(1:end-1) + 1];

            switch options.Resolution
                case "member"
                    [memberLabels, memberScores, memberIndex] = anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        winScores, segmentInfo.numWindows, options.AnomalousWindowPercentage, obj.Threshold);
                    result = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        'VariableNames', {'Labels', 'AnomalyScores', 'MemberIndices'});
                case "window"
                    result = cell(numCells, 1);
                    for i = 1:numCells
                        labelsList = winLabels(startIdx(i):endIdx(i));
                        startIdxList = segmentInfo.winStartIdx(startIdx(i):endIdx(i));
                        scoresList = winScores(startIdx(i):endIdx(i));
                        result{i} = table(labelsList, scoresList, startIdxList, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                    end
                    if numCells == 1
                        result = result{1};
                    end
                case "sample"
                    result = cell(numCells, 1);
                    for i = 1:numCells
                        labelsList = winLabels(startIdx(i):endIdx(i));
                        startIdxList = segmentInfo.winStartIdx(startIdx(i):endIdx(i));
                        scoresList = winScores(startIdx(i):endIdx(i));
                        [labelsList, scoresList, startIdxList] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            labelsList, obj.WindowLength, startIdxList, ...
                            'Method', options.LabelConversionMethod, ...
                            'DataLength', size(dataCell{i},1), ...
                            'WinScores',scoresList);
                        result{i} = table(labelsList, scoresList, startIdxList, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                    end
                    if numCells == 1
                        result = result{1};
                    end
            end
        end

        function obj = updateDetector(obj, data, options)
            % Run "doc anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector/updateDetector" for more information.
            arguments
                obj (1, 1) anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
                data (:,:) {mustBeA(data, ["cell", "numeric", "timetable"])} = []
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean","median","max","contaminationFraction","manual","customFunction", "kSigma"])} 
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
            end

            try
                if ~isempty(options.DetectionStride)
                    obj.DetectionStride = options.DetectionStride;
                end

                % Validate threshold related properties
                options = obj.iValidateThresholdProperties(options);

                % Verify if data is(not) empty when ThresholdMethod is(not) 'manual'
                if ~strcmp(options.ThresholdMethod,'manual')
                    if isempty(data)
                        error(message("predmaint_anomaly:anomaly:errNoDataProvided"))
                    end
                else
                    if ~isempty(data)
                        warning(message("predmaint_anomaly:anomaly:warnNoNeedData"))
                    end
                end

                obj.ThresholdFunction = options.ThresholdFunction;
                obj.ThresholdMethod = options.ThresholdMethod;
                obj.Threshold = options.Threshold;
                obj.ThresholdParameter = options.ThresholdParameter;
                obj.ThresholdFunction = options.ThresholdFunction;

                % Recompute the threshold
                if ~strcmp(obj.ThresholdMethod,'manual')
                    % Do not allow GPU array as input in cell array 
                    if iscell(data) && any(cellfun(@(x) isa(x, 'gpuArray'), data(:)))
                        error(message("predmaint_anomaly:anomaly:errInvalidCellMemberType"))
                    end
                    winScores = iGetWinScores(obj, data);
                    obj.Threshold = anomalyCLI.internal.utils.anomalyThresholding(winScores, ...
                        obj.ThresholdMethod, ...
                        obj.ThresholdParameter, obj.ThresholdFunction);
                end
            catch E
                throwAsCaller(E)
            end
        end

        function plot(obj, data, options)
            % Run "doc anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector/plot" for more information.

            % PLOT is designed to highlight anomalies with signals or plot
            % window anomaly scores along the time. The input data is a single
            % multichannel signal observation.
            %
            %   plot(obj, data) returns two figures. One figure is for
            %   anomalies plot and the other one is for anomaly score plot.
            %
            %   plot(obj, ..., PlotType=PT) specifies which figures to
            %   plot.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data
            % sineWaveNormal. sineWaveAbnormal contains three signals with
            % various anomalies, like frequency changes, amplitude changes,
            % and  spikes. After training the detector use the plot method
            % for better visualization of detected anomalies.
            %
            % load sineWaveAnomalyData.mat
            % D = usAD(3);
            % train(D, sineWaveNormal);
            % plot(D, sineWaveAbnormal{1});

            arguments
                obj (1, 1) anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
                data (:, :) {mustBeA(data, ["numeric", "timetable"])}
                options.PlotType (1,1) string {mustBeMember(options.PlotType,["anomaly", "anomalyScores", "all"])}  = "all"
            end

            try
                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                % check data
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.WindowLength, obj.DetectionStride)
                [dataCell, varnames] =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);

                if iscell(dataCell) && (numel(dataCell) > 1)
                    error(message("predmaint_anomaly:anomaly:errInvalidBatchInput"));
                end

                % Detect anomaly and get the labels and scores.
                windowResults = detect(obj, dataCell);

                % Plots
                ax = newplot;
                ax.NextPlot = 'replace';

                fig = ancestor(ax, 'figure');
                matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
                t = tiledlayout(fig, "vertical");

                if any(options.PlotType == ["anomaly", "all"])
                    ax1 = nexttile(t);
                    anomalyCLI.internal.utils.AnomalyDetection.plotAnomalies(ax1, dataCell{1}, varnames, ...
                        windowResults, obj.WindowLength);
                end

                if any(options.PlotType == ["anomalyScores", "all"])
                    ax2 = nexttile(t);
                    anomalyCLI.internal.utils.AnomalyDetection.plotScores(ax2, windowResults, obj.Threshold);
                end

                allAxes = findobj(t, Type='Axes');
                linkaxes(allAxes, 'x');

                % Setup to manage plot interactivity.
                set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.
            catch E
                throwAsCaller(E)
            end
        end

        function plotHistogram(obj, data1, data2)
            % Run "doc anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector/plotHistogram" for more information.

            % PLOTHISTOGRAM is designed to plot anomaly score histogram.
            % data can be matrix, cell array, timetable, datastore.
            % If there are two datasets, two histograms are plotted in the
            % same figure for comparison. When only one dataset is
            % provided, one histogram will be plotted.
            %
            %   plotHistogram(obj, data1) plot anomaly scores histogram of
            %   data1.
            %
            %   plotHistogram(obj, data1, data2) plot two anomaly scores histograms in the
            %   same figure for comparison.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data sineWaveNormal.
            % The sineWaveAbnormal contains three signals with various
            % anomalies, like frequency changes, amplitude changes, and
            % spikes. Use plotHistogram method to visualize how
            % distributed the anomaly scores are in training and testing
            % datasets.
            %
            % load sineWaveAnomalyData.mat
            % D = usAD(3);
            % train(D, sineWaveNormal);
            % plotHistogram(D, sineWaveNormal, sineWaveAbnormal);

            arguments
                obj (1, 1) anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
                data1 (:, :) {mustBeNonempty, mustBeA(data1, ["cell", "numeric", "timetable"])}
                data2 (:, :) {mustBeA(data2, ["cell", "numeric", "timetable"])}= []
            end

            try
                % Do not allow GPU array as input in cell array
                if iscell(data1) && any(cellfun(@(x) isa(x, 'gpuArray'), data1(:)))
                    error(message("predmaint_anomaly:anomaly:errInvalidCellMemberType"))
                end

                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                % check data and get the window scores for data 1
                scores{1} = iGetWinScores(obj, data1);

                if ~isempty(data2)
                    % Do not allow GPU array as input in cell array
                    if iscell(data2) && any(cellfun(@(x) isa(x, 'gpuArray'), data2(:)))
                        error(message("predmaint_anomaly:anomaly:errInvalidCellMemberType"))
                    end

                    % check data and get the window scores for data 2
                    scores{2} = iGetWinScores(obj, data2);
                end

                % Plots
                ax = newplot;
                ax.NextPlot = 'replace';

                fig = ancestor(ax, 'figure');
                matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
                t = tiledlayout(fig, "vertical");

                ax = nexttile(t);
                anomalyCLI.internal.utils.AnomalyDetection.plotHistogram(ax, scores, obj.Threshold);

                % Setup to manage plot interactivity.
                set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.
            catch E
                throwAsCaller(E)
            end
        end
    end

    %% Internal Methods
    methods (Access=protected)
        % Prepare the data for training or detection
        function [featureArray, segmentInfo, obj] = iSegmentFeaturizeCell(obj, dataCell, windowLength, stride, options)
            arguments
                obj
                dataCell (:,1) cell
                windowLength (1,1)
                stride
                options.NormalizationMethod
                options.TrainFlag = false
            end

            numChannels = size(dataCell{1}, 2);
            numCells = numel(dataCell);

            % Compute window counts per cell
            winCounts = zeros(numCells, 1);
            for i = 1:numCells
                winCounts(i) = floor((size(dataCell{i},1) - windowLength)/stride) + 1;
            end
            totalWindows = sum(winCounts);

            segmentInfo.numWindows = winCounts;

            % Build start indices and 3D window array via vectorized indexing
            allStartIdx = zeros(totalWindows, 1);
            windowArray3D = zeros(windowLength, numChannels, totalWindows);
            offset = 0;
            for i = 1:numCells
                nWin = winCounts(i);
                d = dataCell{i};
                startIndices = (0:nWin-1)' * stride + 1;
                winIdx = startIndices + (0:windowLength-1); % nWin x windowLength
                chunk = reshape(d(winIdx', :), windowLength, nWin, numChannels);
                windowArray3D(:, :, offset+1:offset+nWin) = permute(chunk, [1, 3, 2]);
                allStartIdx(offset+1:offset+nWin) = startIndices;
                offset = offset + nWin;
            end
            segmentInfo.winStartIdx = allStartIdx;

            % Process features
            if windowLength == 1 && obj.FeatureExtraction
                warning(message("predmaint_anomaly:anomaly:warnNoFeatureExtraction"));
                featureArray = squeeze(windowArray3D)';
                if totalWindows == 1
                    featureArray = featureArray(:)';
                end
            elseif obj.FeatureExtraction
                % Vectorized feature extraction on 3D array
                featureArray = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.extractStatisticsFeaturesArray3D(windowArray3D);

                % Handle columns that are entirely NaN
                if options.TrainFlag
                    nanPercentage = sum(isnan(featureArray), 1) / size(featureArray, 1);
                    nanColumns = nanPercentage > 0.5;
                    obj.pValidFeatureColumns = ~nanColumns;
                    featureArray = featureArray(:, obj.pValidFeatureColumns);
                else
                    if ~isempty(obj.pValidFeatureColumns)
                        featureArray = featureArray(:, obj.pValidFeatureColumns);
                    end
                end
            else
                % No feature extraction: reshape 3D to 2D (totalWindows*windowLength x numChannels)
                featureArray = reshape(permute(windowArray3D, [1, 3, 2]), [], numChannels);
            end

            % Normalization
            if obj.Normalization ~= "off"
                if options.TrainFlag
                    [featureArray, dataCenter, dataScale] = normalize(featureArray, 1, options.NormalizationMethod);

                    % Handle constant features (zero variance)
                    constantFeatures = dataScale == 0;
                    if any(constantFeatures)
                        featureArray(:, constantFeatures) = 0;
                        dataScale(constantFeatures) = 1;
                    end

                    obj.pDataCenter = dataCenter;
                    obj.pDataScale = dataScale;
                else
                    featureArray = normalize(featureArray, "center",  obj.pDataCenter, "scale", obj.pDataScale);
                end
            end
        end

        function [winScores, dataCell, segmentInfo] = iGetWinScores(obj, data)
            % Check the detector is trained
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

            % check data
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.WindowLength, obj.DetectionStride)
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);

            % preprocess the data by reformatting, normalizing and
            % segmenting into windows
            [dataArray, segmentInfo] = iSegmentFeaturizeCell(obj, dataCell, obj.WindowLength, obj.DetectionStride);

            % detect anomaly
            [~, winScores] = isanomaly(obj.pModel,dataArray);
        end

        % Validate detector settings (threshold)
        function options = iValidateThresholdProperties(obj,options)
            %   Validates the threshold-related settings in the input 'options' struct
            %   for an anomaly detector object. Ensures the combination of threshold
            %   method, parameter, function, and value are consistent and valid.
            %   Sets default values where necessary and throws errors for invalid
            %   combinations or values.

            %Setup previously set values if they were assigned in
            %updateDetector
            % --ThresholdMethod
            %if strlength(options.ThresholdMethod) == 0
            if ~isfield(options, "ThresholdMethod")
                options.ThresholdMethod = obj.ThresholdMethod;
                if strcmp(options.ThresholdMethod, 'customFunction') && isempty(options.ThresholdFunction)
                    options.ThresholdFunction = obj.ThresholdFunction;
                elseif strcmp(options.ThresholdMethod, 'manual') && isempty(options.Threshold)
                    options.Threshold = obj.Threshold;
                elseif ismember(options.ThresholdMethod,{'max', 'mean', 'median','kSigma','contaminationFraction'}) && isempty(options.ThresholdParameter)
                    options.ThresholdParameter = obj.ThresholdParameter;
                end
            end

            % "Threshold" value must not be empty when "ThresholdMethod" is set to "manual"
            if strcmp(options.ThresholdMethod, 'manual')
                if isempty(options.Threshold)
                    error(message("predmaint_anomaly:anomaly:errEmptyThres"));
                end
            end

            % "ThresholdMethod" must be set to "manual" when "Threshold" value is not empty.
            if ~isempty(options.Threshold)
                if ~strcmp(options.ThresholdMethod, 'manual')
                    error(message("predmaint_anomaly:anomaly:errInvalidCombThreshold"));
                end
            end

            % When ThresholdMethod is 'customFunction',
            % ThresholdFunction need to be defined
            if strcmp(options.ThresholdMethod, 'customFunction')
                if isempty(options.ThresholdFunction)
                    error(message("predmaint_anomaly:anomaly:errEmptyThresFunc"));
                end
            end

            % When ThresholdFunction is defined, ThresholdMethod has to be
            % 'customFunction'
            if ~isempty(options.ThresholdFunction)
                if ~strcmp(options.ThresholdMethod, 'customFunction')
                    error(message("predmaint_anomaly:anomaly:errInvalidCombThresholdFunction"));
                end
            end

            % For untrained model, ThresholdParameter is set for different
            % ThresholdMethod. For trained model,ThresholdParameter is set
            % as obj ThresholdParameter value.
            if isempty(options.ThresholdParameter)
                if ~obj.IsTrained
                    if strcmp(options.ThresholdMethod, 'contaminationFraction')
                        options.ThresholdParameter = 0.01;
                    elseif ismember(options.ThresholdMethod,{'max', 'mean', 'median'})
                        options.ThresholdParameter = 1;
                    elseif strcmp(options.ThresholdMethod,'kSigma')
                        options.ThresholdParameter = 3;
                    end
                else
                    if ~strcmp(options.ThresholdMethod, 'manual') && ~strcmp(options.ThresholdMethod, 'customFunction')
                        options.ThresholdParameter = obj.ThresholdParameter;
                    end
                end
            end

            % Validate the threshold settings for each method
            switch options.ThresholdMethod
                % --Threshold
                case 'manual'
                    % Validate Threshold
                    validateattributes(options.Threshold, {'numeric'}, {'real', 'scalar'}, '', 'Threshold');
                    % --ThresholdFunction
                case 'customFunction'
                    if isempty(options.ThresholdFunction) || ~isa(options.ThresholdFunction, 'function_handle')
                        error(message("predmaint_anomaly:anomaly:errInvalidThresFun"))
                    end
                    % --ThresholdParameter
                case 'contaminationFraction'
                    if isempty(options.ThresholdParameter)
                        error(message("predmaint_anomaly:anomaly:errEmptyThresPara", options.ThresholdMethod))
                    end
                    % Validate ThresholdParameter (CF)
                    if ~(isnumeric(options.ThresholdParameter)...
                            && isreal(options.ThresholdParameter) ...
                            && isscalar(options.ThresholdParameter) ...
                            && options.ThresholdParameter>=0 ...
                            && options.ThresholdParameter<0.5)
                        error(message("predmaint_anomaly:anomaly:errInvalidThresParaCF"))
                    end
                otherwise % {'max', 'mean', 'median', 'kSigma'}
                    if isempty(options.ThresholdParameter)
                        error(message("predmaint_anomaly:anomaly:errEmptyThresPara", options.ThresholdMethod))
                    end
                    % Validate ThresholdParameter (Others)
                    if ~(isnumeric(options.ThresholdParameter) ...
                            && isreal(options.ThresholdParameter) ...
                            && isscalar(options.ThresholdParameter) ...
                            && options.ThresholdParameter>0)
                        error(message("predmaint_anomaly:anomaly:errInvalidThresPara", options.ThresholdMethod))
                    end
            end
        end
    end

    %% Function implemented in concrete subclasses with specific model
    methods (Abstract)
        % train detector and obtain threshold
        train
    end

    methods(Hidden)
        function mdl = getUnderlyingModel(obj)
            mdl = obj.pModel;
        end

        function [center,scale] = getNormalizationParameters(obj)
            center = obj.pDataCenter;
            scale = obj.pDataScale;
        end

        function validCols = getValidFeatureColumns(obj)
            validCols = obj.pValidFeatureColumns;
        end


    end
end
