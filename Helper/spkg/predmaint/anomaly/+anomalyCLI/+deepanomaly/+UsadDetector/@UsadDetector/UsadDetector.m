classdef UsadDetector < anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
    % Run "doc anomalyCLI.deepanomaly.UsadDetector" for more information.

    % UsadDetector is a reconstruction-based deep learning class that implements
    % an Unsupervised Anomaly Detection (UsAD) deep learning network
    % architecture for detecting anomalies in time-series data. Utilizing
    % a dual auto-encoder architecture, this network learns to model normal
    % behavior patterns and identifies deviations as anomalies. The UsAD
    % deep-net is particularly effective for applications where labeled
    % anomaly data is scarce or unavailable.
    %
    % Key Features:
    % - Dual auto-encoder architecture for robust anomaly detection.
    % - Unsupervised learning approach, eliminating the need for labeled data.
    % - Methods for training the model and evaluating new data sequences.
    % - Configurable network parameters and detection algorithm parameters (Alpha & Beta).
    %
    % It utilizes the historical data where signal length w is
    % reconstructed to detect abnormalities.
    %
    % General properties for abstract class:
    %            IsTrained          - Logical indicator indicating whether the network is trained or not
    %            DetectionStride    - Stride length used to create
    %                                         detection windows of the test
    %                                         data
    %            NumChannels        - Number of channels of input data
    %            Layers             - Deep network layer structure
    %            Dlnet              - Deep network
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
    % Model specific:
    %            ObservationWindowLength     - Window length which will be used
    %                                         to create subsequences of the input
    %                                         signals for training and detection.
    %                                         For the usAD detector ObservationWindowLength
    %                                         is always equal to DetectionWindowLength
    %            LatentSpaceDim             - Dimension of latent space in the usAD model
    %            TrainingStride             - Stride length used to create
    %                                         windows for training
    %            Alpha                      - Sensitivity coefficient used in
    %                                         detection with the output of
    %                                         AE1
    %            Beta                       - Sensitivity coefficient used in
    %                                         detection with the output of
    %                                         AE2
    % Methods:
    %            train                      - train detector and obtain threshold
    %            detect                     - detect anomalies using trained network
    %                                         and obtained threshold
    %            updateDetector             - update detector properties and the
    %                                         anomaly detection result could be updated.
    %                                         Network will not be retrained.
    %            plot                       - Plot anomalies or/and plot anomaly
    %                                         scores of input data
    %            plotHistogram              - Plot histogram of anomaly scores

    %   Copyright 2024-2026 The MathWorks, Inc.

    properties(SetAccess = protected)
        % Window length
        ObservationWindowLength (1, 1) double {mustBeInteger,mustBePositive} = 24

        % Detection window length
        DetectionWindowLength (1, 1) double {mustBeInteger,mustBePositive} = 24

        %For detection and threshold computation
        Alpha (1, 1) {double, mustBeGreaterThanOrEqual(Alpha,0), mustBeLessThanOrEqual(Alpha,1)} = 0.5
        Beta (1, 1) {double, mustBeGreaterThanOrEqual(Beta,0), mustBeLessThanOrEqual(Beta,1)} = 0.5

        % TrainingStride - stride size of sliding window in training phase
        TrainingStride (1, 1) double

        % LatentSpaceDim Size of latent space
        LatentSpaceDim (1, 1) double {mustBeInteger, mustBePositive} = 5
    end

    % Protected properties
    properties (Hidden, Access = protected)
        % pOutputSize - Output size for the fully connected layers
        pOutputSize (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = [128, 64, 32]

        % Model building related
        % pLayersE - Deep network layer for encoder
        pLayersE
        % pLayersD1 - Deep network layer for decoder 1
        pLayersD1
        % pLayersD2 - Deep network layer for decoder 2
        pLayersD2

        % pDlnetE1 - Encoder dlnetwork
        pDlnetE
        % pDlnetD1 - Decoder 1 dlnetwork
        pDlnetD1
        % pDlnetD2 - Decoder 2 dlnetwork
        pDlnetD2

        % Training related
        % pTrainingOptions - Training options
        pTrainingOptions = struct()
        % pTrainingOptions - Training history
        pTrainingInfo
    end

    %% Public Methods
    methods (Access=public)
        function obj = UsadDetector(numChannels, options, baseProps)
            %Constructor for UsadDetector: Creates an object for UsAD anomaly detector
            %object and sets the properties from the NV pairs
            arguments
                numChannels (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
                options struct = struct()
                baseProps struct = struct()
            end

            % Set properties in the AbstractDeepAnomalyDetector
            basePropsCell = namedargs2cell(baseProps);
            obj@anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector(basePropsCell{:})

            obj.NumChannels = numChannels;

            % Set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = options.(field{i});
                end
            end

            % set private properties to ensure in the detection, the
            % window length is non-overlapped by default
            if ~isfield(options, 'TrainingStride')
                obj.TrainingStride = obj.ObservationWindowLength;
            end
            if ~isfield(options, 'DetectionStride')
                obj.DetectionStride = obj.ObservationWindowLength;
            end

            % DetectionWindowLength is always equal to ObservationWindowLength for UsAD
            obj.DetectionWindowLength = obj.ObservationWindowLength;

            % Model structure parameters based on LatentSpaceDim
            obj.pOutputSize = [4*obj.LatentSpaceDim, 2*obj.LatentSpaceDim, obj.LatentSpaceDim];

            try
                %Check for Alpha and Beta - sum must be 1
                mustSumToOne(obj.Alpha, obj.Beta)

                % build model
                obj = iBuildModel(obj);
            catch E
                throwAsCaller(E)
            end
        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.UsadDetector/train" for more information.


            % TRAIN function trains the built UsAD network using a training
            % dataset. The threshold is calculated based on training
            % dataset if the thresholdMethod is not set as 'manual'.
            %
            % train(obj, trainData) trains the detector object on the
            % training data set. The trainData is a data source containing M
            % set of signals, each with numChannels channels, where numChannels
            % is the value defined in the NumChannels property of detector.
            % The trainData should consist solely of normal data, meaning
            % it must not contain any known anomalies or anomalous data. It
            % is expected to be in one of the following formats:
            %
            %  - An N-column matrix.
            %    data consists of a single multichannel signal observation
            %    (M = 1). A sufficiently long single observation can be as
            %    effective for training as multiple shorter observations.
            %
            %  - An M-element cell array containing numChannels-column matrices
            %    or numChannels-column timetable.
            %
            %  - A timetable.
            %    trainData consists of a single multichannel signal
            %    observation. The NC channels can be distributed either in
            %    the columns of a matrix contained in a single table
            %    variable, or in NC table variables, each containing a
            %    vector. In either case, the timetable must contain
            %    finite, increasing, and uniformly sampled time values.
            %
            %   train(obj, trainData, Name=Value) specifies training options
            %   like number of MaxEpochs, MiniBatchSize, InitialLearnRate,
            %   Verbose, and Plots.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data sineWaveNormal.
            %
            % load sineWaveAnomalyData.mat
            % D = usAD(3);
            % train(D, sineWaveNormal, MaxEpochs=150, ...
            %        InitialLearnRate=1e-3, MiniBatchSize=128, Verbose=false);

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.UsadDetector.UsadDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.MaxEpochs (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 30
                options.InitialLearnRate (1, 1) double {mustBeReal, mustBePositive} = 1e-3
                options.MiniBatchSize (1, 1) double {mustBeInteger,mustBePositive} = 128;
                options.Verbose (1, 1) logical = true
                options.Plots (1, 1) string {mustBeMember(options.Plots,["none","training-progress"])} = 'none'
                options.ExecutionEnvironment (1, 1) string {mustBeTextScalar,mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu","parallel","multi-gpu", "parallel-auto", "parallel-cpu","parallel-gpu"])} = "auto"
                options.Monitor = []
            end

            % Record training options
            obj.pTrainingOptions.MiniBatchSize = options.MiniBatchSize;
            obj.pTrainingOptions.MaxEpochs = options.MaxEpochs;
            obj.pTrainingOptions.LearnRate = options.InitialLearnRate;
            obj.pTrainingOptions.Verbose = options.Verbose;
            obj.pTrainingOptions.Plots = options.Plots;
            obj.pTrainingOptions.ExecutionEnvironment = options.ExecutionEnvironment;
            try
                % prepare training data
                [trainInput, ~, ~, obj] = iPreProcessData(obj, data, obj.TrainingStride, trainFlag = true, ExecutionEnvironment = options.ExecutionEnvironment);

                % Train network
                [trainedEncoder, trainedDecoder1, trainedDecoder2, TrainHistory] = iModelTrain(obj, trainInput, obj.pTrainingOptions, options.Monitor);
                obj.pDlnetE = trainedEncoder;
                obj.pDlnetD1 = trainedDecoder1;
                obj.pDlnetD2 = trainedDecoder2;
                obj.pTrainingInfo = TrainHistory;

                % Compute threshold
                if ~strcmp(obj.ThresholdMethod, "manual")
                    if obj.pTrainingOptions.Verbose
                        disp(getString(message('predmaint_anomaly:anomaly:msgComputingThreshold')))
                    end

                    % minibatchpredict does not support parallel/multi-gpu Geck: g3723144
                    trainEE = iConvertEEForDetection(obj, obj.pTrainingOptions.ExecutionEnvironment);
                    trainWinScores = iGetWinScores(obj, trainInput, ExecutionEnvironment = trainEE, MiniBatchSize= obj.pTrainingOptions.MiniBatchSize);

                    thres = anomalyCLI.internal.utils.anomalyThresholding(trainWinScores, ...
                        obj.ThresholdMethod, obj.ThresholdParameter, obj.ThresholdFunction);
                    obj.Threshold = gather(thres);

                    if obj.pTrainingOptions.Verbose
                        disp(getString(message("predmaint_anomaly:anomaly:msgFinishThreshold")))
                    end
                end

                obj.Dlnet = {obj.pDlnetE, obj.pDlnetD1, obj.pDlnetD2};
                obj.IsTrained = true;
            catch E
                throwAsCaller(E)
            end
        end

        function obj = updateDetector(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.UsadDetector/updateDetector" for more information.

            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data { mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])} = []
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean","median","max","contaminationFraction","manual","customFunction", "kSigma"])}
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
                options.Alpha (1, 1) {double, mustBeGreaterThan(options.Alpha,0), mustBeLessThan(options.Alpha,1)} = obj.Alpha
                options.Beta (1, 1) {double, mustBeGreaterThan(options.Beta,0), mustBeLessThan(options.Beta,1)} = obj.Beta
                options.ExecutionEnvironment (1,1) string {mustBeMember(options.ExecutionEnvironment,["auto","gpu","cpu"])} = "auto"
                options.MiniBatchSize (1, 1) {mustBeInteger,mustBePositive} = 128
            end

            try
                mustSumToOne(options.Alpha, options.Beta);    %Check parameter validity
                obj.Alpha = gather(options.Alpha);
                obj.Beta = gather(options.Beta);

                options = rmfield(options,{'Alpha', 'Beta'});

                optionsCells = namedargs2cell(options);
                obj = iUpdateBasic(obj, data, optionsCells{:});

                % Recompute the threshold
                if ~strcmp(obj.ThresholdMethod,'manual')

                    % Check the detector is trained
                    anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(obj.IsTrained);

                    % preprocess the data by reformatting, normalizing and
                    % segmenting into windows
                    data = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                    % detect anomaly
                    winScores = iGetWinScores(obj, data, ExecutionEnvironment = options.ExecutionEnvironment, ...
                        MiniBatchSize = options.MiniBatchSize);

                    obj.Threshold = anomalyCLI.internal.utils.anomalyThresholding(winScores, ...
                        obj.ThresholdMethod, ...
                        obj.ThresholdParameter, obj.ThresholdFunction);
                end

            catch E
                throwAsCaller(E)
            end
        end
    end



    %% Internal Methods
    methods  (Access = protected)
        % Build underlying deep-net architecture
        function obj = iBuildModel(obj)
            obj.pLayersE = [
                inputLayer([obj.ObservationWindowLength, obj.NumChannels, NaN], "SCB",Name="Input")
                fullyConnectedLayer(obj.pOutputSize(1), Name="E_fc_1")
                reluLayer(Name="E_relu1")
                fullyConnectedLayer(obj.pOutputSize(2), Name="E_fc_2")
                reluLayer(Name="E_relu2")
                fullyConnectedLayer(obj.pOutputSize(3), Name="E_fc_3")
                reluLayer(Name="E_relu3")];

            obj.pLayersD1 = [
                featureInputLayer(obj.pOutputSize(3))
                fullyConnectedLayer(obj.pOutputSize(2), Name="D1_fc_1")
                reluLayer(Name="D1_relu1")
                fullyConnectedLayer(obj.pOutputSize(1), Name="D1_fc_2")
                reluLayer(Name="D1_relu2")
                fullyConnectedLayer(obj.ObservationWindowLength*obj.NumChannels, Name="D1_fc_3")
                sigmoidLayer];

            obj.pLayersD2 = [
                featureInputLayer(obj.pOutputSize(3))
                fullyConnectedLayer(obj.pOutputSize(2), Name="D2_fc_1")
                reluLayer(Name="D2_relu1")
                fullyConnectedLayer(obj.pOutputSize(1), Name="D2_fc_2")
                reluLayer(Name="D2_relu2")
                fullyConnectedLayer(obj.ObservationWindowLength*obj.NumChannels, Name="D2_fc_3")
                sigmoidLayer];

            % build dlnetwork
            obj.pDlnetE = dlnetwork(obj.pLayersE);
            obj.pDlnetD1 = dlnetwork(obj.pLayersD1);
            obj.pDlnetD2 = dlnetwork(obj.pLayersD2);

            % save models
            obj.Layers = {obj.pLayersE, obj.pLayersD1, obj.pLayersD2};
            obj.Dlnet = {obj.pDlnetE, obj.pDlnetD1, obj.pDlnetD2};
        end

        % Train the network with training data and targets
        function [trainedEncoder, trainedDecoder1, trainedDecoder2, trainHistory] = iModelTrain(obj, trainInput, trainingOptions, monitor)
            arguments
                obj
                trainInput
                trainingOptions
                monitor
            end

            import anomalyCLI.deepanomaly.UsadDetector.*
            executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment( ...
                "ExecutionEnvironment", trainingOptions.ExecutionEnvironment, ...
                "DispatchInBackground", 0);

            % convert data into minibatch
            dsTrain = arrayDatastore(trainInput,IterationDimension=3);

            trainQueue = minibatchqueue(dsTrain, 1, ...
                OutputAsDlarray=true,...
                MiniBatchSize = trainingOptions.MiniBatchSize, ...
                MiniBatchFcn = @preprocessMiniBatch,...
                MiniBatchFormat="SCB", ...
                PartialMiniBatch="discard",...
                OutputEnvironment= executionSettings.ExecutionEnvironment);

            % setup monitor
            hasExternalMonitor = ~isempty(monitor);
            if ~hasExternalMonitor
                monitor = trainingProgressMonitor(Visible = false);
            end

            if strcmp(trainingOptions.Plots, 'training-progress') || hasExternalMonitor
                % configure monitor and update constant information
                monitor.Visible = true;
                monitor.Progress = 0;
                monitor.XLabel = "Iteration" ;
                monitor.Status = "Running";
                monitorMetricName = ["AE1_TrainingLoss", "AE2_TrainingLoss"];
                monitorMetricDisplayName = ["AE1 Training Loss", "AE2 Training Loss"];
                monitor.Metrics = monitorMetricName;
                yLims = {[0 Inf]};
                setYLimits(monitor, monitorMetricDisplayName, yLims);
                setLegendLocation(monitor, monitorMetricDisplayName, "northeast");
                setMetricDisplayNames(monitor, monitorMetricName, monitorMetricDisplayName)
                hardwareResourceMessageStr = getExecutionEnvironmentString(executionSettings);

                monitor.Info = ["Epoch", "Iteration", "Solver", "LearningRateSchedule", "LearningRate", "OutputNetwork","HardwareResource"];
                setInfoDisplayNames(monitor, ["LearningRate", "LearningRateSchedule", "OutputNetwork","HardwareResource"],...
                    ["Learning rate", "Learning rate schedule", "Output network","Hardware resource"]);
                updateInfo(monitor, ...
                    Solver="Adam",...
                    OutputNetwork = "Last iteration", ...
                    LearningRateSchedule = "Constant", ...
                    HardwareResource = hardwareResourceMessageStr);

                % prepare for the progress visualization
                numObservationsTrain = size(trainInput,3);
                numIterationsPerEpoch = max(floor(numObservationsTrain / trainingOptions.MiniBatchSize), 1);
                trainingOptions.NumIterations = trainingOptions.MaxEpochs * numIterationsPerEpoch;
            end

            % define the appropriate trainer based on serial vs. parallel training
            trainingOptions.ExecutionEnvironment = executionSettings.ExecutionEnvironment;
            if executionSettings.UseParallel
                networkTrainer = UsadParallelTrainer(trainQueue, obj.pDlnetE, obj.pDlnetD1, obj.pDlnetD2, @usadModelLoss, trainingOptions);
            else
                networkTrainer = UsadSerialTrainer(trainQueue, obj.pDlnetE, obj.pDlnetD1, obj.pDlnetD2, @usadModelLoss, trainingOptions);
            end

            [trainedEncoder, trainedDecoder1, trainedDecoder2, trainHistory] = fit(networkTrainer, monitor, obj.ObservationWindowLength, obj.NumChannels);
        end

        function reconstructedTarget = iGetWinScores(obj, data, options)
            %Predict the error using UsAD detection algorithm
            arguments
                obj
                data
                options.MiniBatchSize = 128
                options.ExecutionEnvironment = "auto"
            end
            %
            % executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment( ...
            %     "ExecutionEnvironment", options.ExecutionEnvironment, ...
            %     "DispatchInBackground", 0);

            %Phase 1 for AE1
            data = dlarray(data, 'SCB');

            Z = minibatchpredict(obj.pDlnetE, data, ...
                MiniBatchSize = options.MiniBatchSize, ...
                ExecutionEnvironment = options.ExecutionEnvironment);

            Y1 = minibatchpredict(obj.pDlnetD1, Z, ...
                MiniBatchSize = options.MiniBatchSize, ...
                ExecutionEnvironment = options.ExecutionEnvironment);
            Y1_ = reshape(Y1, [obj.ObservationWindowLength, obj.NumChannels, size(Y1, 2)]);
            Y1_ = dlarray(Y1_, 'SCB');

            %Phase 2 for AE2
            Z_ = minibatchpredict(obj.pDlnetE, Y1_, ...
                MiniBatchSize = options.MiniBatchSize, ...
                ExecutionEnvironment = options.ExecutionEnvironment);
            Y2 = minibatchpredict(obj.pDlnetD2, Z_, ...
                MiniBatchSize = options.MiniBatchSize, ...
                ExecutionEnvironment = options.ExecutionEnvironment);
            Y2_ = reshape(Y2, [obj.ObservationWindowLength, obj.NumChannels, size(Y2, 2)]);
            Y2_ = dlarray(Y2_, 'SCB');

            winError = obj.Alpha*mean((data-Y1_).^2) + obj.Beta*mean((data-Y2_).^2);
            aggregatedChannelError = extractdata(squeeze(mean(winError, 2)));
            reconstructedTarget = double(gather(aggregatedChannelError));
        end

        % prepare the data for training or detection
        function [dataArray, segmentInfo, dataCell, obj] = iPreProcessData(obj, data, stride,  options)
            arguments
                obj
                data
                stride
                options.trainFlag = false
                options.ExecutionEnvironment
            end
            segmentInfo = [];

            % convert data to cell data
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.ObservationWindowLength, obj.DetectionStride)
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            % Normalization (in double precision before single conversion)
            [dataCell, obj] = iNormalization(obj, dataCell, options.trainFlag);

            dataCell = iSetupEnvironmentAndPrepareData(obj, dataCell, options.ExecutionEnvironment);

            numCells = numel(dataCell);
            numChannels = size(dataCell{1}, 2);
            winCounts = zeros(numCells, 1);
            for ci = 1:numCells
                winCounts(ci) = floor((size(dataCell{ci}, 1) - obj.ObservationWindowLength) / stride) + 1;
            end
            totalWindows = sum(winCounts);

            dataArray = zeros(obj.ObservationWindowLength, numChannels, totalWindows, 'like', dataCell{1});
            allStartIdx = zeros(totalWindows, 1);
            offset = 0;
            for ci = 1:numCells
                d = dataCell{ci};
                nWin = winCounts(ci);
                startIndices = (0:nWin-1)' * stride + 1;
                winIdx = startIndices + (0:obj.ObservationWindowLength-1);
                chunk = reshape(d(winIdx', :), obj.ObservationWindowLength, nWin, numChannels);
                dataArray(:, :, offset+1:offset+nWin) = permute(chunk, [1, 3, 2]);
                allStartIdx(offset+1:offset+nWin) = startIndices;
                offset = offset + nWin;
            end


            segmentInfo.numWindows = winCounts;
            segmentInfo.winStartIdx = allStartIdx;
        end
    end

    methods(Hidden, Static)
        function n = matlabCodegenRedirect(~)
            n = 'anomalyCLI.coder.deepanomaly.UsadDetector';
        end
    end

end


function X = preprocessMiniBatch(dataX)
% Concatenate.
X = cat(3,dataX{:});
end

function mustSumToOne(Alpha, Beta)
if abs((Alpha + Beta) - 1) > 1e-10  % Allowing for floating-point precision
    error(message("predmaint_anomaly:anomaly:errAlphaBetaSum"))
end
end


function messageStr = getExecutionEnvironmentString(executionSettings)
% Construct the message string from the settings
useGpu = executionSettings.ExecutionEnvironment == "gpu";
if executionSettings.UseParallel
    if useGpu
        messageStr = "Multiple GPUs";
    else
        messageStr = "Multiple CPUs";
    end
else
    if useGpu
        messageStr = "Single GPU";
    else
        messageStr = "Single CPU";
    end
end
end
