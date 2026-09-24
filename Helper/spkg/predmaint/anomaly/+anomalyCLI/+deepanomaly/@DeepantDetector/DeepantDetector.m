classdef DeepantDetector < anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
    % Run "doc anomalyCLI.deepanomaly.DeepantDetector" for more information.

    %   Copyright 2024-2026 The MathWorks, Inc.

    % DeepantDetector is a forecasting-based deep learning class designed for
    % anomaly detection in time-series data. It leverages historical data
    % of a specified window length to predict future data points and
    % identify anomalies based on the deviation between detected and
    % actual observations. By comparing the predicted values with the
    % observed data within a detection window, the detector identifies
    % anomalies as significant deviations from expected patterns.
    %
    % Key Features:
    %   - Forecasting-based anomaly detection using deep learning. -
    %     Utilizes historical data of length `w` to predict a future window
    %     of length `p_w`.
    %   - Detects anomalies by analyzing prediction deviations. - Flexible
    %     and adaptable for various time-series datasets.
    %
    % General properties:
    %            IsTrained          - Logical indicator indicating whether
    %                                 the network is trained or not
    %            DetectionStride    - Stride length for creating windows
    %                                      for detecting anomalies
    %            NumChannels        - Number of channels of input data
    %            Layers             - Deep network layer structure
    %            Dlnet              - DeepAnT based deep network
    %            Normalization      - Normalization technique for
    %                                 training and testing data
    %            Threshold          - Threshold value calculated by the
    %                                 threshold method or manual threshold
    %                                 value
    %            ThresholdMethod    - Methods to calculate the threshold
    %            ThresholdParameter - Scaling parameter used in scaling the
    %                                 computed threshold value
    %            ThresholdFunction  - When threshold method is set as manual,
    %                                 the threshold function is used to
    %                                 calculate the threshold
    %
    % Model specific properties:
    %            ObservationWindowLength  - Window length for historical data
    %            DetectionWindowLength   - Window length for detecting
    %                                      anomalies
    %            FilterSize              - Filter size of convolutional layers
    %            DropoutProbability      - Dropout probability of dropoutLayers to avoid over-fitting
    %            NumFilters              - Number of filters in convolution layers
    %            TrainingStride          - Stride length used to create
    %                                      overlapping windows in training
    %                                      data
    %
    % Methods:
    %            train                   - train detector and obtain threshold
    %            detect                  - detect anomalies using trained network and obtained threshold
    %            updateDetector          - update detector properties and the anomaly detection result could be updated. Network will not be retrained.
    %            plot                    - plot anomalies or/and plot anomaly scores of input data
    %            plotHistogram           - plot histogram of anomaly scores
    % References:
    %   M. Munir, S. A. Siddiqui, A. Dengel and S. Ahmed, "DeepAnT: A Deep Learning Approach for Unsupervised Anomaly Detection in Time Series,"
    %       in IEEE Access, vol. 7, pp. 1991-2005, 2019, doi: 10.1109/ACCESS.2018.2886457.

    properties(SetAccess = protected)
        % Set the properties will reset the IsTrain property as False

        % ObservationWindowLength - Historic window length
        ObservationWindowLength (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 10

        % DetectionWindowLength - Prediction window length
        DetectionWindowLength (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 5

        % Network-related parameters
        % FilterSize - Filter size of each convolutional layer
        FilterSize (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = [2,3]

        % DropoutProbability - Dropout probability of dropoutLayers to avoid over-fitting
        DropoutProbability (1, :) double {mustBeReal, mustBeNonnegative, mustBeLessThan(DropoutProbability,1)} = 0.25

        % NumFilters - Number of filters of each convolutional layer
        NumFilters (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 32

        % TrainingStride - stride size of sliding window in training stage
        TrainingStride (1, 1) double = 1
    end


    % Protected properties
    properties (Hidden, Access = protected)
        % Model architecture related
        % NumConvLayers - Number of convolutional layers
        NumConvLayers (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 2

        % pTrainingOptions - network training options for trainnet
        pTrainingOptions

        % pTrainingInfo - network training history
        pTrainingInfo

        % ConvLayerStride - Downsample factor for convolutional layer in each downsample layer
        ConvLayerStride (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 1

        % PoolLayerStride - Downsample factor for max pooling layer in each downsample layer
        PoolLayerStride (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 2

        % FullyConnectedSize - fully connected layer size
        FullyConnectedSize (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 100

        % PoolSize - pool size for max pooling layer in each downsample layer
        PoolSize (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 2

        % pWindowScoresAggregationMethod - method to aggregate the
        % point-wise anomaly scores into window-wise anomaly scores
        pWindowScoresAggregationMethod = "max"

    end

    %% Public Methods
    methods (Access=public)
        function obj = DeepantDetector(numChannels, options, baseProps)
            % DeepantDetector is designed to set the properties from the NV pairs
            % and build the deepAnT network based on specified network
            % architecture.
            arguments
                numChannels (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
                options struct = struct()
                baseProps struct = struct()
            end
            % Set properties in the AbstractDeepAnomalyDetector
            basePropsCell = namedargs2cell(baseProps);
            obj@anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector(basePropsCell{:})

            obj.NumChannels = numChannels;

            % Set private properties to ensure in the detection window is
            % non-overlapping
            if ~isfield(options, 'DetectionStride')
                obj.DetectionStride = options.DetectionWindowLength;
            end

            % Set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = options.(field{i});
                end
            end

            try
                % Build model
                obj = iBuildModel(obj);
            catch E
                throwAsCaller(E)
            end
        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.DeepantDetector/train" for more information.

            % TRAIN is designed to train built network using a training
            % dataset. The threshold is calculated based on training
            % dataset if the thresholdMethod is not 'manual'.
            %
            % train(obj, trainData) trains the detector object on the
            % training data set. trainData is a data source containing M
            % signals, each with numChannels channels, where numChannels is
            % the value defined in the NumChannels property of detector.
            % The trainData should consist solely of normal data, meaning
            % it must not contain any known anomalies or anomalous data. It
            % is expected to be in one of the following formats:
            %
            %   - An N-column matrix.
            %     data consists of a single multichannel(numChannels = N)  signal observation
            %     (M = 1). A sufficiently long single observation can be as
            %     effective for training as multiple shorter observations.
            %
            %   - An M-element cell array containing numChannels-column matrices
            %     or numChannels-column timetable.
            %
            %   - A timetable.
            %     trainData consists of a single multichannel signal
            %     observation. The N channels can be distributed either in
            %     the columns of a matrix contained in a single table
            %     variable, or in N table variables, each containing a
            %     vector. In either case, the timetable must contain
            %     finite, increasing, and uniformly sampled time values.
            %
            %   train(obj, trainData, Name=Value) specifies training options as TrainingOpts.
            %   TrainingOpts can be a TrainingOptionsSGDM, TrainingOptionsRMSProp, or
            %   TrainingOptionsADAM object returned by the trainingOptions
            %   function.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data sineWaveNormal.
            %
            % load sineWaveAnomalyData.mat
            % D = deepantAD(3);
            % trainingOpts = trainingOptions("adam", ...
            %     InitialLearnRate=1e-3, ...
            %     LearnRateSchedule="piecewise", ...
            %     LearnRateDropFactor=0.02, ...
            %     LearnRateDropPeriod=10, ...
            %     MaxEpochs=5, ...
            %     Plots="training-progress");
            % D = train(D, sineWaveNormal, TrainingOpts=trainingOpts)
            %
            arguments
                obj (1, 1) anomalyCLI.deepanomaly.DeepantDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.TrainingOpts (1, 1) {mustBeA(options.TrainingOpts, ["nnet.cnn.TrainingOptionsADAM", "nnet.cnn.TrainingOptionsSGDM", "nnet.cnn.TrainingOptionsRMSProp"])}  = trainingOptions('adam', LearnRateSchedule="piecewise")
                options.Monitor = []
            end

            % Record trainingOptions in order to keep SequenceLength same
            % for detection
            obj.pTrainingOptions = options.TrainingOpts;

            % Set the input and output format for training
            obj.pTrainingOptions.InputDataFormats = "SCB";
            obj.pTrainingOptions.TargetDataFormats = "SCB";

            try
                % Preprocess the data to convert the input data into cells and
                % segment signals into windows for training input and targets
                [trainInput, trainTarget, ~, ~, obj] = iPreProcessData(obj, data, obj.TrainingStride, ...
                    ExecutionEnvironment = obj.pTrainingOptions.ExecutionEnvironment, trainFlag = true);

                % Train network
                [trainedNet,trainInfo] = iModelTrain(obj, trainInput, trainTarget, obj.pTrainingOptions, options.Monitor);
                obj.Dlnet = trainedNet;
                obj.pTrainingInfo= trainInfo;

                % Compute threshold
                if ~strcmp(obj.ThresholdMethod, "manual")
                    if obj.pTrainingOptions.Verbose
                        disp(getString(message('predmaint_anomaly:anomaly:msgComputingThreshold')))
                    end
                    % minibatchpredict does not support parallel/multi-gpu Geck: g3723144
                    trainEE = iConvertEEForDetection(obj, obj.pTrainingOptions.ExecutionEnvironment);

                    trainWinScores = iGetWinScores(obj, trainInput, trainTarget, ExecutionEnvironment = trainEE, MiniBatchSize = obj.pTrainingOptions.MiniBatchSize);
                    thres = anomalyCLI.internal.utils.anomalyThresholding(trainWinScores, ...
                        obj.ThresholdMethod, obj.ThresholdParameter, obj.ThresholdFunction);
                    obj.Threshold = gather(thres);
                    
                    if obj.pTrainingOptions.Verbose
                        disp(getString(message("predmaint_anomaly:anomaly:msgFinishThreshold")))
                    end
                end
                obj.IsTrained = true;
            catch E
                throwAsCaller(E)
            end
        end

        function result = detect(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.DeepantDetector/detect" for more information.


            % DETECT is designed to detect subsequence anomalies in data using
            % trained network. The length of subsequence is detection window length.
            % The subsequences are non-overlapped. The window anomaly
            % scores are calculated and the window labels are determined
            % by the threshold value. Data can be one of these:
            %
            %   - An N-column matrix.
            %     data consists of a single multichannel (numChannels = N) signal observation
            %     (M = 1). A sufficiently long single observation can be as
            %     effective for training as multiple shorter observations.
            %
            %   - An M-element cell array containing numChannels-column matrices
            %     or numChannels-column timetable.
            %
            %   - A timetable.
            %     trainData consists of a single multichannel signal
            %     observation. The N channels can be distributed either in
            %     the columns of a matrix contained in a single table
            %     variable, or in N table variables, each containing a
            %     vector. In either case, the timetable must contain
            %     finite, increasing, and uniformly sampled time values.
            %
            %   resultsTable = detect(D, data) returns window labels (0/1)
            %   and numeric window anomaly scores for each window. The
            %   window start index of the data is identified by winStartIdx.
            %
            %   resultsTable = detect(..., MiniBatchSize=MBS) specifies the
            %   mini-batch size MBS for network detection.
            %   Set MBS to a positive integer scalar. The default is 128.
            %
            %   resultsTable = detect(..., ExecutionEnvironment=EE) specifies
            %   the execution environment for the network. The execution
            %   environment determines what hardware resources are used to
            %   run the network. Specify EE as one of these:
            %
            %   "auto" - Use the GPU if it is available, otherwise use the CPU
            %   "gpu"  - Use the GPU
            %   "cpu"  - Use the CPU
            %   The default EE is "auto".
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
            % D = deepantAD(3);
            % trainingOpts = trainingOptions("adam", ...
            %     InitialLearnRate=1e-3, ...
            %     LearnRateSchedule="piecewise", ...
            %     LearnRateDropFactor=0.02, ...
            %     LearnRateDropPeriod=10, ...
            %     MaxEpochs = 5, ...
            %     Plots="training-progress");
            % D = train(D, sineWaveNormal, TrainingOpts=trainingOpts);
            % resultsTable = detect(D, sineWaveAbnormal);

            arguments
                obj (1,1) anomalyCLI.deepanomaly.DeepantDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.MiniBatchSize (1, 1) double {mustBeInteger,mustBePositive} = 128
                options.PlotHistogram (1, 1) logical = false
                options.ExecutionEnvironment (1, 1) string {mustBeTextScalar,mustBeMember(options.ExecutionEnvironment,{'cpu','auto','gpu'})} = "auto"
                options.Resolution (1,1) {mustBeMember(options.Resolution,["sample","window","member"])} = "window"
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

                % preprocess the data by reformatting, normalizing and
                % segmenting into windows
                [data, target, segmentInfo, dataCell] = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                % detect anomaly
                winScores = iGetWinScores(obj, data, target, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);
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

        function obj = updateDetector(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.DeepantDetector/updateDetector" for more information.

            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data {mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])} = []
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean","median","max","contaminationFraction","manual","customFunction", "kSigma"])}
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 128
            end

            try
                optionsCells = namedargs2cell(options);
                obj = iUpdateBasic(obj, data, optionsCells{:});
                % Recompute the threshold
                if ~strcmp(obj.ThresholdMethod,'manual')

                    % Check the detector is trained
                    anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                    % preprocess the data by reformatting, normalizing and
                    % segmenting into windows
                    [data, target1] = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                    % detect anomaly
                    winScores = iGetWinScores(obj, data, target1, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);

                    obj.Threshold = anomalyCLI.internal.utils.anomalyThresholding(winScores, ...
                        obj.ThresholdMethod, ...
                        obj.ThresholdParameter, obj.ThresholdFunction);
                end
            catch E
                throwAsCaller(E)
            end
        end

        function plotHistogram(obj, data1, data2, options)
            % Run "doc anomalyCLI.deepanomaly.DeepantDetector/plotHistogram" for more information.


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
                data2 {mustBeA(data2, ["cell", "numeric", "timetable", "gpuArray"])} = []
                options.MiniBatchSize (1, 1) {mustBeInteger,mustBePositive} = 128
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
            end

            try
                % Check the detector is trained
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                % preprocess the data by reformatting, normalizing and
                % segmenting into windows
                [data1, target1] = iPreProcessData(obj, data1, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                % detect anomaly
                scores{1} = iGetWinScores(obj, data1, target1, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);

                if ~isempty(data2)
                    % check data and get the window scores for data 2
                    [data2, target2] = iPreProcessData(obj, data2, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);
                    scores{2} = iGetWinScores(obj, data2, target2, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);
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
    methods  (Access = protected)
        % Build specific underlying model network
        function obj = iBuildModel(obj)
            % prepare the parameters for layers
            [obj.FilterSize, obj.NumFilters, obj.ConvLayerStride, obj.PoolLayerStride, obj.PoolSize] = ...
                anomalyCLI.internal.deepanomaly.utils.prepareLayerParamVec(obj.NumConvLayers, "NumConvLayers", ...
                ["FilterSize", "NumFilters", "ConvLayerStride","PoolLayerStride", "PoolSize"],  ...
                obj.FilterSize, obj.NumFilters, obj.ConvLayerStride, obj.PoolLayerStride, obj.PoolSize);

            %Validate the network based on the above layer params prior to
            %building the network
            validateNetwork(obj.ObservationWindowLength, obj.FilterSize, obj.NumConvLayers, obj.ConvLayerStride, obj.PoolSize, obj.PoolLayerStride)

            obj.Layers = inputLayer([obj.ObservationWindowLength, obj.NumChannels, NaN], "SCB",Name="Input") ;

            for i = 1: obj.NumConvLayers
                obj.Layers = [obj.Layers
                    convolution1dLayer(obj.FilterSize(i), ...
                    obj.NumFilters(i), ...
                    Padding = 0, ...
                    Stride = obj.ConvLayerStride(i))
                    layerNormalizationLayer
                    reluLayer
                    maxPooling1dLayer(obj.PoolSize(i), ...
                    Stride = obj.PoolLayerStride(i))
                    ];
            end
            obj.Layers = [obj.Layers
                fullyConnectedLayer(obj.FullyConnectedSize, Name="fc_1")
                dropoutLayer(obj.DropoutProbability)
                fullyConnectedLayer(obj.DetectionWindowLength*obj.NumChannels, Name="fc_2")
                functionLayer(@(x)dlarray(reshape(x, obj.DetectionWindowLength, obj.NumChannels, []),'SCB'), ...
                Formattable=true, Acceleratable=true, Name="reshape")];

            obj.Dlnet = dlnetwork(obj.Layers);
        end

        % Train the network with training data and targets
        function [trainedNet,trainHistory] = iModelTrain(obj, trainInput, trainTarget, trainingOpts, monitor)
            arguments
                obj
                trainInput
                trainTarget
                trainingOpts
                monitor
            end

            lossFcn = "mse";
            network = obj.Dlnet;
            if isempty(monitor)
                [trainedNet,trainHistory] = trainnet(trainInput,trainTarget,network,lossFcn,trainingOpts);
            else
                [trainedNet,trainHistory] = deep.internal.sdk.trainnet.trainnet(trainInput,trainTarget,network,lossFcn,trainingOpts,Monitor=monitor);
            end
        end

        % Predict targets with preprocessed data
        function targetPred = iModelPredict(obj, windowData, options)
            arguments
                obj
                windowData
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 128
            end
            network = obj.Dlnet;
            targetPred = minibatchpredict(network, windowData, ...
                ExecutionEnvironment = options.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize);
        end

        % Compute anomaly scores based on network's scores and actual values
        function pointScores = iComputeAnomalyScore(~, target, targetPred)
            % Vectorized: single operation on full 3D arrays
            % Result: detectionWindowLength x numObservations
            scores3D = sqrt(sum((target - targetPred).^2, 2));
            pointScores = reshape(scores3D, size(scores3D, 1), size(scores3D, 3));
        end

        function winScores = iGetWinScores(obj, data, target, options)
            arguments
                obj
                data
                target
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 128
            end
            targetPred = iModelPredict(obj, data, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);
            pointScores = iComputeAnomalyScore(obj, target, targetPred);
            winScores = double(gather(iAggregatePointScoresArray(obj, pointScores)));
        end

        % prepare the data for training or detection
        function [dataArray, targetArray, segmentInfo, dataCell, obj] = iPreProcessData(obj, data, stride, options)
            arguments
                obj
                data
                stride
                options.trainFlag = false
                options.ExecutionEnvironment
            end

            % convert data to cell data
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.ObservationWindowLength + obj.DetectionWindowLength, obj.DetectionStride)
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            % Normalization (in double precision before single conversion)
            [dataCell, obj] = iNormalization(obj, dataCell, options.trainFlag);

            dataCell = iSetupEnvironmentAndPrepareData(obj, dataCell, options.ExecutionEnvironment);

            % prepare input and target as 3D arrays directly
            [dataArray, targetArray, segmentInfo] = prepareInputTargetArrays(dataCell, obj.ObservationWindowLength, obj.DetectionWindowLength, stride);
        end

        % Aggregate point losses to get window loss for one signal (model specific)
        function winScores = iAggregatePointScores(obj, pointScores)
            method = obj.pWindowScoresAggregationMethod;
            switch method
                case "mean"
                    winScores = cellfun(@(x) mean(x),pointScores, 'UniformOutput', false);
                case "median"
                    winScores = cellfun(@(x) median(x),pointScores, 'UniformOutput', false);
                case "min"
                    winScores = cellfun(@(x) min(x),pointScores, 'UniformOutput', false);
                case "max"
                    winScores = cellfun(@(x) max(x),pointScores, 'UniformOutput', false);
            end
            winScores = vertcat(winScores{:});
        end

        function winScores = iAggregatePointScoresArray(obj, pointScores)
            % Vectorized aggregation on a matrix (columns = observations)
            method = obj.pWindowScoresAggregationMethod;
            switch method
                case "mean"
                    winScores = mean(pointScores, 1)';
                case "median"
                    winScores = median(pointScores, 1)';
                case "min"
                    winScores = min(pointScores, [], 1)';
                case "max"
                    winScores = max(pointScores, [], 1)';
            end
        end
    end

    methods(Hidden, Static)
        function n = matlabCodegenRedirect(~)
            n = 'anomalyCLI.coder.deepanomaly.DeepantDetector';
        end
    end

    methods (Hidden)
        function method = getWindowScoresMethod(obj)
            method = obj.pWindowScoresAggregationMethod;
        end
    end
end

%% Local function
% prepare the input and target for training process
function [dataInputCells, dataTargetsCells, segmentInfo] = prepareInputTargetCells(cellData, windowLength, detectionWindowLength, stride)
    arguments
        cellData
        windowLength
        detectionWindowLength
        stride
    end
    [dataInput, dataTarget, numWindows, winStartIdx] = cellfun(@(x)preparInputOutputRolling(x, windowLength, detectionWindowLength, stride), cellData, 'UniformOutput', false);

    % Concatenate the results to obtain the final training cells and target cells
    dataInputCells = vertcat(dataInput{:});
    dataTargetsCells = vertcat(dataTarget{:});

    segmentInfo.numWindows = vertcat(numWindows{:});
    segmentInfo.winStartIdx = vertcat(winStartIdx{:});
end

function [dataArray, targetArray, segmentInfo] = prepareInputTargetArrays(cellData, windowLength, detectionWindowLength, stride)
    numChannels = size(cellData{1}, 2);
    numCells = numel(cellData);

    % Compute total windows
    winCounts = zeros(numCells, 1);
    for i = 1:numCells
        winCounts(i) = floor((size(cellData{i}, 1) - windowLength - detectionWindowLength)/stride) + 1;
    end
    totalWindows = sum(winCounts);

    % Pre-allocate 3D arrays
    dataArray = zeros(windowLength, numChannels, totalWindows, 'like', cellData{1});
    targetArray = zeros(detectionWindowLength, numChannels, totalWindows, 'like', cellData{1});
    allStartIdx = zeros(totalWindows, 1);
    offset = 0;

    for i = 1:numCells
        d = cellData{i};
        nWin = winCounts(i);
        startIndices = (0:nWin-1)' * stride + 1;

        % Input windows
        winIdx = startIndices + (0:windowLength-1);
        chunk = reshape(d(winIdx', :), windowLength, nWin, numChannels);
        dataArray(:, :, offset+1:offset+nWin) = permute(chunk, [1, 3, 2]);

        % Target windows (start after the input window)
        targetStart = startIndices + windowLength;
        targetIdx = targetStart + (0:detectionWindowLength-1);
        targetChunk = reshape(d(targetIdx', :), detectionWindowLength, nWin, numChannels);
        targetArray(:, :, offset+1:offset+nWin) = permute(targetChunk, [1, 3, 2]);

        allStartIdx(offset+1:offset+nWin) = startIndices + windowLength;
        offset = offset + nWin;
    end

    segmentInfo.numWindows = winCounts;
    segmentInfo.winStartIdx = allStartIdx;
end

% For each signal cell, prepare the input and target
function [windowInputData, windowTarget, numWindows, winStartIdx] = preparInputOutputRolling(data, windowLength, detectionWindowLength, stride)
arguments
    data
    windowLength
    detectionWindowLength
    stride
end

numWindows = floor((size(data, 1) - windowLength - detectionWindowLength)/stride) + 1;
% get training window input
windowInputData = anomalyCLI.internal.utils.createRollingWindows(data, windowLength, stride, "NumWindows", numWindows);

% get training window target
target = data(1 + windowLength:end, :);
[windowTarget, numWindows, winStartIdx] = anomalyCLI.internal.utils.createRollingWindows(target, detectionWindowLength, stride, "NumWindows", numWindows);
winStartIdx = winStartIdx + windowLength;
end

function validateNetwork(windowLength, filterSizes, numRounds, convStrides, poolSizes, poolStrides)
% VALIDATENETWORK checks if the window length is sufficient for a given
% number of rounds of processing through specified layers.
%
% Inputs:
%   windowLength - The length of the input sequence (window length).
%   filterSizes  - A vector containing filter sizes for each round.
%   numRounds    - The number of rounds to process the sequence.
%   convStrides  - A vector containing strides for the conv1dLayer for each round.
%   poolSizes    - A vector containing pool sizes for the maxPooling1dLayer for each round.
%   poolStrides  - A vector containing strides for the maxPooling1dLayer for each round.

% Initialize current length
currentLength = windowLength;    %For clarity as the length will change

% Process each round
for round = 1:numRounds
    % Extract parameters for the current round
    filterSize = filterSizes(round);
    convStride = convStrides(round);
    poolSize = poolSizes(round);
    poolStride = poolStrides(round);

    % Calculate length after convolution
    newLength = floor((currentLength - filterSize) / convStride) + 1;

    % Check if the length is valid after convolution
    if newLength < 1
        error(message("predmaint_anomaly:anomaly:errInvalidNetworkConv", num2str(round)))
    end
    currentLength = newLength;

    % Calculate length after max pooling
    newLength = floor((currentLength - poolSize) / poolStride) + 1;

    % Check if the length is valid after max pooling
    if newLength < 1
        error(message("predmaint_anomaly:anomaly:errInvalidNetworkMaxP", num2str(round)))
    end
    currentLength = newLength;
end
end
