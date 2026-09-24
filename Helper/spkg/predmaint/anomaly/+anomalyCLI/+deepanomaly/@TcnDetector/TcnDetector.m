classdef TcnDetector < anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
    % Run "doc anomalyCLI.deepanomaly.TcnDetector" for more information.

    %   Copyright 2024-2026 The MathWorks, Inc.

    % TcnDetector is a reconstruction-based deep learning class that implements a
    % Temporal Convolutional Network (TCN) architecture for the purpose of
    % training and detecting anomalies in time-series data. By comparing
    % the reconstructed values with the observed data within a detection
    % window, the detector identifies anomalies as significant deviations
    % from expected patterns.
    %
    % General properties for abstract class:
    %            IsTrained               - Logical indicator indicating
    %                                      whether the network is trained
    %            DetectionStride         - Stride length for creating windows
    %                                      for detecting anomalies
    %            NumChannels             - Number of channels of input data
    %            Layers                  - Deep network layer structure
    %            Dlnet                   - TCN based deep network
    %            Normalization           - Normalization technique for
    %                                      training and testing data
    %            Threshold               - Threshold value calculated by
    %                                      the threshold method or manual
    %                                      threshold value
    %            ThresholdMethod         - Methods to calculate the threshold
    %            ThresholdParameter      - Scaling parameter used in scaling
    %                                      the computed threshold value
    %            ThresholdFunction       - When threshold method is set as manual,
    %                                      the threshold function is used to
    %                                      calculate the threshold
    %
    % Model specific properties:
    %            DetectionWindowLength   - Length of the detection window.
    %            FilterSize              - Filter size of convolutional layers
    %            DropoutProbability      - Dropout probability of dropoutLayers
    %                                      to avoid over-fitting
    %            NumFilters              - Number of filters of each
    %                                      convolutional layer
    %
    % Methods:
    %            train                   - Train detector and obtain threshold
    %            detect                  - Detect anomalies using trained network and obtained threshold
    %            updateDetector          - Update detector properties and the anomaly detection result could be updated. Network will not be retrained.
    %            plot                    - Plot anomalies or/and plot anomaly scores of input data
    %            plotHistogram           - Plot histogram of anomaly scores

    properties(SetAccess = protected)
        % set the properties will reset the IsTrain property as False

        % FilterSize - Filter size of each convolutional layer
        FilterSize (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 7

        % DropoutProbability - Dropout probability of dropoutLayers to avoid over-fitting
        DropoutProbability (1, 1) double {mustBeReal,mustBeNonnegative, mustBeLessThan(DropoutProbability,1)} = 0.25

        % DetectionWindowLength - Detection window length in training
        DetectionWindowLength (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 10

        % NumFilters - Number of filters of each convolutional layer
        NumFilters (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 32
    end

    % Protected properties
    properties (Hidden, Access = protected)
        % pTrainingOptions - network training options for trainnet
        pTrainingOptions

        % pTrainingInfo - network training
        pTrainingInfo

        % pWindowScoresAggregationMethod - method to aggregate the
        % point-wise anomaly scores into window-wise anomaly scores
        pWindowScoresAggregationMethod = "max"

    end

    %% Public Methods
    methods (Access=public)
        function obj = TcnDetector(numChannels, options, baseProps)
            %Constructor for TcnDetector: Creates an object for TCN Anomaly Detector
            %object and sets the properties from the NV pairs
            arguments
                numChannels (1, 1) {mustBeInteger, mustBePositive, mustBeFinite} = 1
                options struct = struct()
                baseProps struct = struct()
            end

            % Set properties in the AbstractDeepAnomalyDetector
            basePropsCell = namedargs2cell(baseProps);
            obj@anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector(basePropsCell{:});

            obj.NumChannels = numChannels;

            % set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = options.(field{i});
                end
            end

            % set private properties to ensure in the detection, the
            % detection window is non-overlapped by default
            if ~isfield(options, 'DetectionStride')
                obj.DetectionStride = obj.DetectionWindowLength;
            end

            try
                % build model
                obj = iBuildModel(obj);
            catch E
                throwAsCaller(E)
            end
        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.TcnDetector/train" for more information.


            % TRAIN function trains the built TCN network using a training
            % dataset. The threshold is calculated based on training
            % dataset if the thresholdMethod is not set as 'manual'.
            %
            % train(obj, trainData) trains the detector object on the
            % training data set. trainData is a data source containing M
            % set of signals, each with numChannels channels, where numChannels
            % is the value defined in the NumChannels property of detector.
            % The trainData should consist solely of normal data, meaning
            % it must not contain any known anomalies or anomalous data. It
            % is expected to be in one of the following formats:
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
            %     trainData consists of a single multichannel signal
            %     observation. The NC channels can be distributed either in
            %     the columns of a matrix contained in a single table
            %     variable, or in NC table variables, each containing a
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
            % amplitude. Train the network with normal data
            % sineWaveNormal.
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
            % train(D, sineWaveNormal, TrainingOpts=trainingOpts)

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.TcnDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.TrainingOpts (1, 1) {mustBeA(options.TrainingOpts, ["nnet.cnn.TrainingOptionsADAM", "nnet.cnn.TrainingOptionsSGDM", "nnet.cnn.TrainingOptionsRMSProp"])} = trainingOptions('adam', LearnRateSchedule="piecewise")
                options.Monitor = []
            end

            % Record trainingOptions in order to keep SequenceLength same
            % for detection
            obj.pTrainingOptions = options.TrainingOpts;

            try
                % preprocess the data to convert the input data into cells
                [trainInput, ~, ~, obj] = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = obj.pTrainingOptions.ExecutionEnvironment, trainFlag = true);

                % Train network
                [trainedNet, trainInfo] = iModelTrain(obj, trainInput, obj.pTrainingOptions, options.Monitor);
                obj.Dlnet = trainedNet;
                obj.pTrainingInfo= trainInfo;

                % Compute threshold
                if ~strcmp(obj.ThresholdMethod, "manual")
                    if obj.pTrainingOptions.Verbose
                        disp(getString(message('predmaint_anomaly:anomaly:msgComputingThreshold')))
                    end
                    % minibatchpredict does not support parallel/multi-gpu Geck: g3723144
                    trainInputArray = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = obj.pTrainingOptions.ExecutionEnvironment);
                    trainEE = iConvertEEForDetection(obj, obj.pTrainingOptions.ExecutionEnvironment);
                    trainWinScores = iGetWinScores(obj, trainInputArray, ExecutionEnvironment = trainEE, MiniBatchSize = obj.pTrainingOptions.MiniBatchSize);
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

        function obj = updateDetector(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.TcnDetector/updateDetector" for more information.
            arguments
                obj (1, 1) anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
                data {mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])} =[]
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean","median","max","contaminationFraction","manual","customFunction", "kSigma"])}
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.DetectionWindowLength {mustBeInteger,mustBePositive} = []
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
                options.ExecutionEnvironment (1,1) string {mustBeMember(options.ExecutionEnvironment,["auto","gpu","cpu"])} = "auto"
                options.MiniBatchSize (1, 1) {mustBeInteger,mustBePositive} = 128
            end

            try
                if ~isempty(options.DetectionWindowLength)
                    obj.DetectionWindowLength = gather(options.DetectionWindowLength);
                end

                options = rmfield(options,{'DetectionWindowLength'});
                
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
                    winScores = iGetWinScores(obj, data, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);

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
        % Build specific underlying deep-net architecture
        function obj = iBuildModel(obj)
            obj.Dlnet = dlnetwork;
            obj.Layers = [
                sequenceInputLayer(obj.NumChannels)

                convolution1dLayer(obj.FilterSize, obj.NumFilters, Padding="causal", DilationFactor=1, Stride=1, Name="conv1")
                layerNormalizationLayer
                reluLayer(Name="relu1")
                dropoutLayer(obj.DropoutProbability)

                convolution1dLayer(obj.FilterSize, obj.NumFilters, Padding="causal", DilationFactor=2, Stride=1, Name="conv2")
                layerNormalizationLayer
                reluLayer(Name="relu2")
                dropoutLayer(obj.DropoutProbability)

                convolution1dLayer(obj.FilterSize, obj.NumFilters, Padding="causal", DilationFactor=4, Stride=1, Name="conv3")
                layerNormalizationLayer
                reluLayer(Name="relu3")
                dropoutLayer(obj.DropoutProbability)

                convolution1dLayer(obj.FilterSize, obj.NumFilters, Padding="causal", DilationFactor=8, Stride=1, Name="conv4")
                layerNormalizationLayer
                reluLayer(Name="relu4")
                dropoutLayer(obj.DropoutProbability)

                convolution1dLayer(obj.FilterSize, obj.NumFilters, Padding="causal", DilationFactor=16, Stride=1, Name="conv5")
                layerNormalizationLayer
                reluLayer(Name="relu5")
                dropoutLayer(obj.DropoutProbability)

                concatenationLayer(1, 3, 'Name', 'concat')

                convolution1dLayer(1, obj.NumChannels, Padding="causal", Name="conv1x1")
                ];

            obj.Dlnet = addLayers(obj.Dlnet, obj.Layers);

            % Connect the outputs of the last three convolutional layers to the concatenation layer
            obj.Dlnet = connectLayers(obj.Dlnet, 'relu3', 'concat/in2');
            obj.Dlnet = connectLayers(obj.Dlnet, 'relu4', 'concat/in3');
        end

        % Train the network with training data and targets
        function [trainedNet,trainHistory] = iModelTrain(obj, trainInput, trainingOpts, monitor)
            arguments
                obj
                trainInput
                trainingOpts
                monitor
            end

            lossFcn = "mse";
            network = obj.Dlnet;
            if isempty(monitor)
                [trainedNet,trainHistory] = trainnet(trainInput,trainInput,network,lossFcn,trainingOpts);
            else
                [trainedNet,trainHistory] = deep.internal.sdk.trainnet.trainnet(trainInput, trainInput, network, lossFcn, trainingOpts, Monitor=monitor);
            end

        end

        % Compute the scores for the windows
        function winScores = iGetWinScores(obj, data, options)
            arguments
                obj
                data
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 128
            end
            network = obj.Dlnet;
            reconstructedTarget = minibatchpredict(network, data, ...
                ExecutionEnvironment = options.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize);
            pointScores = iComputeAnomalyScore(obj, data, reconstructedTarget);
            winScores = double(gather(iAggregatePointScoresArray(obj, pointScores)));
        end

        % prepare the data for training or detection
        function [dataInputCells, segmentInfo, dataCell, obj] = iPreProcessData(obj, data, stride, options)
            arguments
                obj
                data
                stride
                options.trainFlag = false
                options.ExecutionEnvironment
            end
            segmentInfo = [];

            % convert data to cell data
            if options.trainFlag
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, 1, 1)
            else
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.DetectionWindowLength, obj.DetectionStride)
            end
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            % Normalization (in double precision before single conversion)
            [dataCell, obj] = iNormalization(obj, dataCell, options.trainFlag);

            dataCell = iSetupEnvironmentAndPrepareData(obj, dataCell, options.ExecutionEnvironment);

            if ~options.trainFlag
                %Segment the test data based on detectionWindowLength for
                %detection — build 3D array directly
                [dataInputCells, segmentInfo] = prepareDetectionWindows3D(dataCell, obj.DetectionWindowLength, stride);

            else
                %Sort the sequences in the dataCell  based on their
                %lengths to minimize the zero-padding for training

                % Calculate the length of the sequence in each cell
                sequenceLengths = cellfun(@(c) size(c, 1), dataCell);

                % Sort the cell array based on sequence lengths
                [~, sortOrder] = sort(sequenceLengths, 'ascend');
                dataInputCells = dataCell(sortOrder);
            end
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

        % Compute anomaly scores based on network's scores and actual values
        function pointScores = iComputeAnomalyScore(~, data, reconstructedTarget)
            % Vectorized: single operation on full 3D arrays
            % Result: detectionWindowLength x numObservations
            scores3D = sqrt(sum((data - reconstructedTarget).^2, 2));
            pointScores = reshape(scores3D, size(scores3D, 1), size(scores3D, 3));
        end
    end
    
    methods(Hidden,Static)       
        function n = matlabCodegenRedirect(~)
            % Inform coder that TcnDetector has a separate code generation
            % implementation.
            n = 'anomalyCLI.coder.deepanomaly.TcnDetector';
        end
    end

    methods(Hidden)
        function method = getWindowScoresMethod(obj)
            method = obj.pWindowScoresAggregationMethod;
        end
    end
end

%% Helper function
function [segmentedData, numCompleteWindows, winStartIdx] = prepareDetectionWindows(data, detectionWindowLength, stride)
%When the stride is same as WindowLength the segmentedData will have
%non-overlapping windows
arguments
    data
    detectionWindowLength
    stride
end

% Calculate the number of complete windows
numCompleteWindows = floor((size(data, 1) - detectionWindowLength) / stride) + 1;

segmentedData = zeros(detectionWindowLength, size(data,2), numCompleteWindows);
winStartIdx = zeros(numCompleteWindows, 1);

% Segment the complete windows
for i = 1:numCompleteWindows
    startIdx = (i - 1) * stride + 1;
    endIdx = startIdx + detectionWindowLength - 1;
    segmentedData(:, :, i) = data(startIdx:endIdx, :);
    winStartIdx(i) = startIdx;
end
end

function [dataArray, segmentInfo] = prepareDetectionWindows3D(dataCell, detectionWindowLength, stride)
%Build a 3D detection window array directly from multiple observations.
numCells = numel(dataCell);
numChannels = size(dataCell{1}, 2);

% Compute window counts per observation
winCounts = zeros(numCells, 1);
for i = 1:numCells
    winCounts(i) = floor((size(dataCell{i}, 1) - detectionWindowLength) / stride) + 1;
end
totalWindows = sum(winCounts);

% Pre-allocate 3D array
dataArray = zeros(detectionWindowLength, numChannels, totalWindows, 'like', dataCell{1});
allStartIdx = zeros(totalWindows, 1);
offset = 0;

for i = 1:numCells
    d = dataCell{i};
    nWin = winCounts(i);
    startIndices = (0:nWin-1)' * stride + 1;

    % Vectorized indexing: build index matrix for all windows at once
    winIdx = startIndices + (0:detectionWindowLength-1);
    chunk = reshape(d(winIdx', :), detectionWindowLength, nWin, numChannels);
    dataArray(:, :, offset+1:offset+nWin) = permute(chunk, [1, 3, 2]);

    allStartIdx(offset+1:offset+nWin) = startIndices;
    offset = offset + nWin;
end

segmentInfo.numWindows = winCounts;
segmentInfo.winStartIdx = allStartIdx;
end
