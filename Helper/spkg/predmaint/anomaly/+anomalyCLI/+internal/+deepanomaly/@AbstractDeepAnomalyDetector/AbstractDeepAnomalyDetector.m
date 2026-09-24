classdef (Abstract) AbstractDeepAnomalyDetector < matlab.mixin.CustomDisplay
    % TODO: validation data options and what is their usage: training,
    % threshold finding?

    % TODO: downsampling for training dataset to speed up the training
    % phase.

    %AbstractDeepAnomalyDetector is the abstract class for deep time-series
    %anomaly detector. It aims to define abstract properties and functions
    %for deep anomaly detection
    %
    % AbstractDeepAnomalyDetector properties that common for all
    % subclasses:
    %            IsTrained          - Logical indicator indicating whether the network is trained or not
    %            NumChannels        - Number of channels of input data
    %            Layers             - Deep network layer structure
    %            Dlnet              - Deep network
    %            Normalization      - Method for normalizing the training
    %                                 data and reusing params for
    %                                 normalizing the testing data
    %            Threshold          - Manual threshold value that is set by
    %                                 user
    %            ThresholdMethod    - Methods to calculate the threshold
    %            ThresholdParameter - Parameters utilized in calculating
    %                                 the threshold with threshold method
    %            ThresholdFunction  - When threshold method is set as
    %                                 manual, the threshold function is
    %                                 used to calculate the threshold
    %
    % Abstract methods:
    %            train              - train detector and obtain threshold
    %            detect             - detect anomalies using trained network and obtained threshold
    %            updateDetector     - update detector properties and the anomaly detection result could be updated. Network will not be retrained.
    %            plot               - plot anomalies or anomaly scores
    %            plotHistogram      - plot anomaly scores histogram

    % Copyright 2024-2026 The MathWorks, Inc.

    % Public Properties (read-only)
    properties (GetAccess = public, SetAccess = protected)
        % IsTrained - Logical indicator indicating whether the network is trained or not
        IsTrained (1, 1) logical = false

        % NumChannel - Number of channels of expected input data
        NumChannels (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 1

        % Layers - Deep network layer structure
        Layers

        % Dlnet - Deep network
        Dlnet

        % Threshold-related properties.
        %Threshold - threshold used to detect anomalies
        Threshold

        %ThresholdMethod - Method for threshold computation
        ThresholdMethod

        %ThresholdParameter - Parameter for threshold computation
        ThresholdParameter

        %ThresholdFunction - Custom function for threshold computation.
        %Applies only when ThresholdMethod is "customFunction"
        ThresholdFunction

        %Normalization method
        Normalization (1, 1) string

        % DetectionStride - stride size of sliding window in detection stage
        DetectionStride (1, 1) double
    end

    % Protected properties
    properties (Hidden, Access = protected)
        % Normalization parameters
        % pDataCenter - data center obtained from training data
        pDataCenter
        % pDataScale - data scale obtained from training data
        pDataScale
    end

    %% Public Methods
    methods (Access=public)
        % Constructor function
        function obj = AbstractDeepAnomalyDetector(options)
            % Construct a base AnomalyDetector object
            arguments
                options.Threshold = [];
                options.ThresholdMethod string {mustBeMember(options.ThresholdMethod, ["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}  = "kSigma"
                options.ThresholdParameter =[];
                options.ThresholdFunction = [];
                options.Normalization string {mustBeMember(options.Normalization, ["off", "zscore", "range"])}  = "zscore"
            end

            % check whether DL toolbox is installed
            anomalyCLI.internal.deepanomaly.utils.isDLTavailable()

            % Validate properties
            options = obj.iValidateThresholdProperties(options);

            % set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = gather(options.(field{i}));
                end
            end
        end

        function result = detect(obj, data, options)
            % Run "doc anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector/detect" for more information.

            % DETECT is designed to detect subsequence anomalies in data using
            % trained network. The length of subsequence is detection window length.
            % The subsequences are non-overlapped by default. The window anomaly
            % scores are calculated and the window labels are determined
            % by the threshold value. The input data can be one of these:
            %
            %   - An N-column matrix.
            %     data consists of a single multichannel signal observation
            %     (M = 1). A sufficiently long single observation can be as
            %     effective for training as multiple shorter observations.
            %
            %   - An M-element cell array containing numChannels-column matrices
            %     or numChannels-column timetable.
            %
            %   - A timetable.
            %     The input data consists of a single multichannel signal
            %     observation. The NC channels can be distributed either in
            %     the columns of a matrix contained in a single table
            %     variable, or in NC table variables, each containing a
            %     vector. In either case, the timetable must contain
            %     finite, increasing, and uniformly sampled time values.
            %
            %   resultsTable = detect(D, data) returns window labels (0/1)
            %   and numeric window anomaly scores for each window. The
            %   window start index of corresponding to the input data in a table.
            %
            %   resultsTable  = detect(..., MiniBatchSize=MBS) specifies the
            %   mini-batch size MBS for network detection results.
            %   Set MBS to a positive integer scalar. The default is 128.
            %
            %   resultsTable  = detect(..., ExecutionEnvironment=EE) specifies
            %   the execution environment for the network. The execution
            %   environment determines what hardware resources are used to
            %   run the network. Specify EE as one of these:
            %
            %
            %   resultsTable = detect(..., PlotHistogram=PH) specifies the
            %   flag indictor for plot. If PH is true, the figure that plot
            %   the anomaly score histogram is presented.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data
            % sineWaveNormal. sineWaveAbnormal contains three signals with
            % various anomalies, like frequency changes, amplitude changes,
            % and  spikes. Use the detect method to detect anomalies in
            % the abnormal signals.
            %
            % load sineWaveAnomalyData.mat
            % D = tcnAD(3);
            % trainingOpts = trainingOptions("adam", ...
            %                 InitialLearnRate=1e-3, ...
            %                 LearnRateSchedule="piecewise", ...
            %                 LearnRateDropFactor=0.002, ...
            %                 LearnRateDropPeriod=10, ...
            %                 MaxEpochs=50, ...
            %                 Plots="training-progress");
            % train(D, sineWaveNormal, TrainingOpts=trainingOpts);
            % resultsTable = detect(D, sineWaveAbnormal);

            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.MiniBatchSize (1, 1) double {mustBeInteger,mustBePositive} = 128
                options.PlotHistogram (1, 1) logical = false
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
                options.Resolution (1,1) string {mustBeMember(options.Resolution, ["sample","window","member"])} = "window"
                options.AnomalousWindowPercentage (1,1) double {mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
                options.LabelConversionMethod (1,1) string {mustBeMember(options.LabelConversionMethod, ["majorityVoting","normalPriority","anomalyPriority"])}
            end

            try
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

                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                [dataArray, segmentInfo, dataCell]  = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                % Detect anomaly and get the labels and scores
                winScores = iGetWinScores(obj, dataArray, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize= options.MiniBatchSize);
                winLabels = winScores > obj.Threshold;

                if options.PlotHistogram
                    % Plots
                    ax = newplot;
                    ax.NextPlot = 'replace';

                    fig = ancestor(ax, 'figure');
                    matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
                    t = tiledlayout(fig, "vertical");

                    ax = nexttile(t);
                    anomalyCLI.internal.utils.AnomalyDetection.plotHistogram(ax, {winScores}, obj.Threshold);

                    % Setup to manage plot interactivity.
                    set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.
                end
                nvArgs = {'WinScores', winScores, 'DataCell', dataCell};
                if isfield(options, 'LabelConversionMethod')
                    nvArgs = [nvArgs, {'LabelConversionMethod', options.LabelConversionMethod}];
                end
                if isfield(options, 'AnomalousWindowPercentage')
                    nvArgs = [nvArgs, {'AnomalousWindowPercentage', options.AnomalousWindowPercentage}];
                end
                result = iPrepareResult(obj, winLabels, segmentInfo.winStartIdx, segmentInfo.numWindows, options.Resolution, ...
                    nvArgs{:});
            catch E
                throwAsCaller(E)
            end
        end

        function plot(obj, data, options)
            % Run "doc anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector/plot" for more information.

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
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data (:, :) {mustBeA(data, ["numeric", "timetable", "gpuArray"])}
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
                options.MiniBatchSize (1, 1) double {mustBeInteger,mustBePositive} = 128
                options.PlotType (1,1) string {mustBeMember(options.PlotType,["anomaly", "anomalyScores", "all"])}  = "all"
            end

            try
                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                % preprocess the data by reformatting, normalizing and
                % segmenting into windows
                [dataCell, varnames] = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);

                if iscell(dataCell) && (numel(dataCell) > 1)
                    error(message("predmaint_anomaly:anomaly:errInvalidBatchInput"));
                end

                windowResults = detect(obj, data, MiniBatchSize = options.MiniBatchSize, ExecutionEnvironment = options.ExecutionEnvironment);

                % Plots
                ax = newplot;
                ax.NextPlot = 'replace';

                fig = ancestor(ax, 'figure');
                matlab.graphics.internal.themes.figureUseDesktopTheme(fig);
                t = tiledlayout(fig, "vertical");

                if any(options.PlotType == ["anomaly", "all"])
                    ax1 = nexttile(t);
                    anomalyCLI.internal.utils.AnomalyDetection.plotAnomalies(ax1, dataCell{1}, varnames, ...
                        windowResults, obj.DetectionWindowLength);
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

        function plotHistogram(obj, data1, data2, options)
            % Run "doc anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector/plotHistogram" for more information.

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
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data1 (:, :)  {mustBeNonempty, mustBeA(data1, ["cell", "numeric", "timetable", "gpuArray"])}
                data2  {mustBeA(data2, ["cell", "numeric", "timetable", "gpuArray"])} = []
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
                options.MiniBatchSize (1, 1) {mustBeInteger,mustBePositive} = 128
            end

            try
                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                % preprocess the data by reformatting, normalizing and
                % segmenting into windows
                data1 = iPreProcessData(obj, data1, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);
                scores{1} = iGetWinScores(obj, data1,  ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);

                if ~isempty(data2)
                    % check data and get the window scores for data 2
                    data2 = iPreProcessData(obj, data2, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);
                    scores{2} = iGetWinScores(obj, data2,  ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);
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
        function [dataCell, obj] = iNormalization(obj, dataCell, trainFlag)
            % Skip normalization if it's turned off
            if strcmp(obj.Normalization, 'off')
                return;
            end
            if trainFlag
                % Compute normalization parameters incrementally
                [center, scaling] = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.getNormalizationParameters(dataCell, obj.Normalization);
                % Handle constant features (zero variance)
                constantFeatures = scaling == 0;
                if any(constantFeatures)
                    scaling(constantFeatures) = 1;
                end
                obj.pDataCenter = gather(center);
                obj.pDataScale = gather(scaling);
            end
            % normalize data using normalization parameters obtained from training data
            dataCell = cellfun(@(cellData) normalize(cellData, "center",  obj.pDataCenter, "scale", obj.pDataScale), dataCell, 'UniformOutput', false);
        end

        function [dataCellProcessed, executionSettings] = iSetupEnvironmentAndPrepareData(~, dataCell, ExecutionEnvironment)
            % Setup execution environment
            executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment(...
                "ExecutionEnvironment", ExecutionEnvironment, ...
                "DispatchInBackground", 0);

            % Determine if raw data is on GPU
            OnGPU = isa(dataCell{1}, 'gpuArray');

            % Error out when having gpuArray data and EE=cpu
            if OnGPU && strcmp(executionSettings.ExecutionEnvironment, 'cpu')
                error(message("predmaint_anomaly:anomaly:errInvalidCPUEnvironment"));
            end

            % % Check if GPU can be used
            % canUseGPU = exist('gpuDevice', 'file') == 2 && ~isempty(gpuDeviceCount) && gpuDeviceCount > 0;
            %
            % % Error out when having EE=gpu without valid GPU support
            % if strcmp(executionSettings.ExecutionEnvironment, 'gpu') && ~canUseGPU
            %     error(message("predmaint_anomaly:anomaly:errInvalidGPUEnvironment"));
            % end

            % Process data based on environment
            if ~OnGPU && strcmp(executionSettings.ExecutionEnvironment, 'gpu')
                % Move data to GPU and convert to single
                dataCellProcessed = cellfun(@(x)single(gpuArray(x)), dataCell, 'UniformOutput', false);
            elseif isa(dataCell{1}, 'single')
                % Already single — no conversion needed
                dataCellProcessed = dataCell;
            else
                % Convert to single via loop (avoids cellfun anonymous function overhead)
                dataCellProcessed = dataCell;
                for iCell = 1:numel(dataCellProcessed)
                    dataCellProcessed{iCell} = single(dataCellProcessed{iCell});
                end
            end
        end

        function obj = iUpdateBasic(obj, data, options)
            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data = []
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean","median","max","contaminationFraction","manual","customFunction", "kSigma"])}
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 128
            end

            if ~isempty(options.DetectionStride)
                obj.DetectionStride = gather(options.DetectionStride);
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

            obj.ThresholdMethod = gather(options.ThresholdMethod);
            obj.Threshold = gather(options.Threshold);
            obj.ThresholdParameter = gather(options.ThresholdParameter);
            obj.ThresholdFunction = gather(options.ThresholdFunction);

        end
    end

    %% Function implemented in concrete subclasses with specific model
    methods (Abstract, Access = protected, Hidden=true)
        % Build specific underlying model network
        iBuildModel;
        % Train the network with training data and targets
        iModelTrain;

        % Preprocess the data for training
        iPreProcessData

        iGetWinScores
    end

    methods (Abstract)
        % train detector and obtain threshold
        train

        % update detector related parameters
        updateDetector
    end

    %% Internal Methods
    methods (Access=protected)
        function EE = iConvertEEForDetection(~, executionEnvironment)
            switch executionEnvironment
                case {"cpu", "parallel-cpu"}
                    EE = "cpu";
                case {"gpu", "multi-gpu", "parallel-gpu"}
                    EE = "gpu";
                case {"auto", "parallel-auto", "parallel"}
                    EE = "auto";
            end
        end

        % Validate detector settings
        function options = iValidateThresholdProperties(obj,options)
            %   Validates the threshold-related settings in the input 'options' struct
            %   for an anomaly detector object. Ensures the combination of threshold
            %   method, parameter, function, and value are consistent and valid.
            %   Sets default values where necessary and throws errors for invalid
            %   combinations or values.

            %Setup previously set values if they were assigned in
            %updateDetector
            % --ThresholdMethod
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

        function result = iPrepareResult(obj, winLabels, winStartIdx, numWindows, resolution, options)
            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                winLabels
                winStartIdx
                numWindows
                resolution
                options.WinScores
                options.DataCell
                options.LabelConversionMethod = "anomalyPriority"
                options.AnomalousWindowPercentage (1,1) double = 10
            end
            numCells = numel(numWindows);
            endIdx = cumsum(numWindows);
            startIdx = [1; endIdx(1:end-1) + 1];

            switch resolution
                case "member"
                    [memberLabels, memberScores, memberIndex] = anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        options.WinScores, numWindows, options.AnomalousWindowPercentage, obj.Threshold);
                    result = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        'VariableNames', {'Labels', 'AnomalyScores', 'MemberIndices'});
                case "window"
                    result = cell(numCells, 1);
                    for i = 1:numCells
                        labelsList = winLabels(startIdx(i):endIdx(i));
                        startIdxList = winStartIdx(startIdx(i):endIdx(i));
                        scoresList = options.WinScores(startIdx(i):endIdx(i));
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
                        startIdxList = winStartIdx(startIdx(i):endIdx(i));
                        scoresList = options.WinScores(startIdx(i):endIdx(i));
                        [labelsList, scoresList, startIdxList] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            labelsList, obj.DetectionWindowLength, startIdxList, ...
                            'Method', options.LabelConversionMethod, ...
                            'DataLength', size(options.DataCell{i},1), ...
                            'WinScores',scoresList);
                        result{i} = table(labelsList, scoresList, startIdxList, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                    end
                    if numCells == 1
                        result = result{1};
                    end
            end
        end
    end
    
    methods(Hidden)
        function [center,scale] = getNormalizationParameters(obj)
            center = obj.pDataCenter;
            scale =  obj.pDataScale;
        end
    end

end
