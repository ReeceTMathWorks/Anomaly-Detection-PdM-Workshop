classdef VaelstmDetector < anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector
    % Run "doc anomalyCLI.deepanomaly.VaelstmDetector" for more information.
    
    %   Copyright 2024-2026 The MathWorks, Inc.

    %VaelstmDetector is a class for training and detecting time-series anomalies.
    %VAE-LSTM is a forecasting-based deep anomaly detection.The VaelstmDetector
    %class implements a deep anomaly detection algorithm that forecasts
    %future values using a sequence of historical data. At any given time
    %`t`, the model uses a test sequence `W_t` consisting of `k*p` past
    %signals. From this sequence, the first `(k-1)*p` signals are used to
    %predict the last `p` signals. Anomalies are detected when there is a
    %significant deviation between the predicted and actual signals.
    %
    % Properties
    % General for abstract class
    %            IsTrained          - Logical indicator indicating whether the network is trained or not
    %            DetectionStride    - Stride length for creating windows
    %                                      for detecting anomalies
    %            NumChannels        - Number of channels of input data
    %            Layers             - Deep network layer structure
    %            Dlnet              - Vae-LSTM based deep network
    %            Normalization      - Normalization technique for
    %                                 training and testing data
    %            Threshold          - Threshold value calculated by the threshold method
    %                                 or manual threshold value that is set
    %                                 by the user
    %            ThresholdMethod    - Methods to calculate the threshold
    %            ThresholdParameter - Parameters utilized in calculating
    %                                 the threshold with threshold method
    %            ThresholdFunction  - When threshold method is set as manual,
    %                                 the threshold function is used to
    %                                 calculate the threshold
    %
    % Model specific:
    %           ObservationWindowLength      - Length of historical window. It
    %                                         determine how far the network will
    %                                         look back for prediction. Must be a
    %                                         multiple of DetectionWindowLength
    %
    %           DetectionWindowLength       - Length of prediction window. It
    %                                         determines the length of subsequence
    %                                         in subsequence anomaly detection.
    %                                         Must be smaller than WindowLength
    %            NumDownsampleLayers        - Number of the convolutional
    %                                         layers in VAE model
    %            FilterSize                 - Filter size of convolutional layers in VAE model
    %            DropoutProbability         - Dropout probability of dropoutLayers to avoid over-fitting
    %            NumFilters                 - Number of filters of each convolutional layer
    %            LatentSpaceDim             - Dimension of latent space in the VAE model
    %            NumHiddenUnits             - Number of hidden units in LSTM model
    %            TrainingStride             - Stride length used to create
    %                                         overlapping windows in training
    %                                         data
    %
    % Methods:
    %            train                   - train detector and obtain threshold
    %            detect                  - detect anomalies using trained network and obtained threshold
    %            updateDetector          - update detector properties and the anomaly detection result could be updated. Network will not be retrained.
    %            plot                    - plot anomalies or/and plot anomaly scores of input data
    %            plotHistogram           - plot histogram of anomaly scores
    
    % References:
    %   S. Lin, R. Clark, R. Birke, S. Schönborn, N. Trigoni and S. Roberts,
    %   "Anomaly Detection for Time Series Using VAE-LSTM Hybrid Model," ICASSP
    %   2020 - 2020 IEEE International Conference on Acoustics, Speech and
    %   Signal Processing (ICASSP), Barcelona, Spain, 2020, pp. 4322-4326, doi:
    %   10.1109/ICASSP40776.2020.9053558.


    properties(SetAccess = protected)
        % WindowLength - Length of historical window. It determines how far the network will look back for prediction. Must be a multiple of DetectionWindowLeng
        ObservationWindowLength (1,1) double {mustBeInteger, mustBePositive} = 100

        % DetectionWindowLength - Length of prediction window. It determines the length of subsequence in subsequence anomaly detection. Must be smaller than WindowLength
        DetectionWindowLength (1,1) double {mustBeInteger, mustBePositive} = 10

        % NumDownsampleLayers - Number of downsample layers
        NumDownsampleLayers (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 2

        % FilterSize - Filter size of each convolutional layer
        FilterSize (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 5

        % DropoutProbability - Dropout probability of dropoutLayers to avoid to avoid over-fitting
        DropoutProbability  (1, :) double {mustBeReal, mustBeNonnegative, mustBeLessThan(DropoutProbability,1)} = 0.25

        % NumFilters - Number of filters of each convolutional layer
        NumFilters (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = 32

        % LatentSpaceDim Size of latent space
        LatentSpaceDim (1, 1) double {mustBeInteger, mustBePositive} = 5

        % LSTM-specific parameters
        % NumHiddenUnits - number of hidden units in the LSTM. The
        % length of the vector determines the number of LSTM layers in the
        % network.
        NumHiddenUnits (1, :) double {mustBeReal, mustBeInteger, mustBePositive} = [16, 16];

        % TrainingStride - stride size of sliding window in training stage
        TrainingStride (1, 1) double = 1
    end

    % Protected properties
    properties (Hidden, Access = protected)
        % VAE Model architecture related
        % window length for VAE. It equals to DetectionWindowLength
        VaeWindowLength (1, 1) double {mustBeInteger, mustBePositive} = 10

        % window length for LSTM. It equals to floor(ObservationWindowLength/DetectionWindowLength)
        LstmWindowLength (1, 1) double {mustBeInteger, mustBePositive} = 10

        % VaeDownsampleFactor Downsample factor for convolutional layer in
        % each downsample layer, Stride for convolutional layers
        VaeDownsampleFactor (1, :) double { mustBeReal, mustBeInteger, mustBePositive} = 1

        % Model building related
        % pLayersVaeEncoder - Deep network layer structure for VAE encoder
        pLayersVaeEncoder
        % pLayersVaeDeccoder - Deep network layer structure for VAE decoder
        pLayersVaeDecoder

        % pDlnetVaeEncoder - VAE decoder network
        pDlnetVaeEncoder
        % pDlnetVaeDecoder - VAE decoder network
        pDlnetVaeDecoder

        % pLayersLstm - Deep network layer structure for LSTM
        pLayersLstm
        % pDlnetLstm - LSTM network
        pDlnetLstm

        % VAE training related
        % pVaeTrainingOptions - Training options in training VAE
        pVaeTrainingOptions = struct()
        % pVaeTrainingOptions - Training history in training VAE
        pVaeTrainingInfo

        % LSTM training related
        % pLstmTrainingOptions - Training options in training LSTM
        pLstmTrainingOptions
        % pLstmTrainingInfo - Training history in training LSTM
        pLstmTrainingInfo
    end

    properties (Hidden)
        % Undocumented property to store user specified callback function
        % handle that will be called post vaetraining completion
        OnVaeTrainingDone
    end

    %% Public Methods
    methods (Access=public)
        function obj = VaelstmDetector(numChannels, options, baseProps)
            % VaelstmDetector is designed to set the properties from the NV pairs
            % and build the VAE-LSTM network based on specified network
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

            % Set private properties to ensure the detection window is
            % non-overlapping
            if ~isfield(options, 'DetectionStride')
                obj.DetectionStride = gather(options.DetectionWindowLength);
            end

            % Set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = options.(field{i});
                end
            end

            % Convert the ObservationWindowLength and DetectionWindowLength into VAE and LSTM model
            % window length. ObservationWindowLength = vaeWindowLength * lstmWindowLength.
            % DetectionWindowLength = vaeWindowLength. When the ObservationWindowLength is not
            % divisible by VaeWindowLength, the floor number will be utilized.

            obj.VaeWindowLength = gather(options.DetectionWindowLength);
            obj.LstmWindowLength = gather(floor(obj.ObservationWindowLength/obj.VaeWindowLength));

            % lstmWindowLength should be > 1 to ensure the sequence learning
            if obj.LstmWindowLength < 2
                error(message("predmaint_anomaly:anomaly:errWindowLength"));
            end

            % Warn the user if the ObservationWindowLength is not divisible by DetectionWindowLength.
            % The floor(options.ObservationWindowLength/options.VaeWindowLength) *
            % options.VaeWindowLength will be utilized
            if  (obj.ObservationWindowLength/obj.VaeWindowLength) ~= round(obj.ObservationWindowLength/obj.VaeWindowLength)
                warning(message("predmaint_anomaly:anomaly:warnWindowLength"))
            end
            try
                % build model
                obj = iBuildModel(obj);
            catch E
                throwAsCaller(E)
            end
        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.VaelstmDetector/train" for more information.


            % TRAIN is designed to train built network using a training
            % dataset. The threshold is calculated based on training
            % dataset if the thresholdMethod is not 'manual'.
            %
            % train(obj, trainData) trains the detector object on the
            % training data set. trainData is a data source containing M
            % signals, each with numChannels channels, where numChannels
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
            %   - An M-element cell array containing N-column matrices
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
            %   train(obj, trainData, VaeMaxEpochs=VME) specifies the
            %   maximum number of epochs in training VAE network
            %
            %   train(obj, trainData, VaeInitialLearnRate=VLR) specifies the
            %   learning rate in training VAE network
            %
            %   train(obj, trainData, TrainingOpts=LTO) specifies
            %   training options for training LSTM network. TrainingOpts can be a
            %   TrainingOptionsSGDM, TrainingOptionsRMSProp, or
            %   TrainingOptionsADAM object returned by the trainingOptions
            %   function.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data sineWaveNormal.
            %
            % load sineWaveAnomalyDat
            % D = anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector(3);
            % lstmTrainingOpts = trainingOptions("adam", ...
            %     MaxEpochs=10, ...
            %     SequencePaddingDirection="left", ...
            %     Shuffle="every-epoch", ...
            %     Plots="training-progress", ...
            %     Verbose=true, ...
            %     ExecutionEnvironment = "auto",...
            %     MiniBatchSize=64);
            % vaeMaxEpochs = 10;
            % vaeInitialLearnRate = 1e-3;
            % D = train(D, sineWaveNormal, TrainingOpts = lstmTrainingOpts, ...
            %        VaeMaxEpochs = vaeMaxEpochs, VaeInitialLearnRate = vaeInitialLearnRate )

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.TrainingOpts (1, 1) {mustBeA(options.TrainingOpts, ["nnet.cnn.TrainingOptionsADAM", "nnet.cnn.TrainingOptionsSGDM", "nnet.cnn.TrainingOptionsRMSProp"])} = trainingOptions('adam', ...
                    LearnRateSchedule="piecewise", ...
                    MaxEpochs=20, ...
                    SequencePaddingDirection="left", ...
                    ExecutionEnvironment = "auto", ...
                    MiniBatchSize=256)
                options.VaeMaxEpochs (1, 1) double {mustBeReal, mustBeInteger, mustBePositive}
                options.VaeInitialLearnRate (1, 1) double {mustBeReal, mustBePositive}
                options.VaeMonitor = []
                options.LstmMonitor = []
            end

            % Record training options for VAE training
            obj.pVaeTrainingOptions.MiniBatchSize = options.TrainingOpts.MiniBatchSize;
            obj.pVaeTrainingOptions.ExecutionEnvironment  = options.TrainingOpts.ExecutionEnvironment;
            obj.pVaeTrainingOptions.Verbose = options.TrainingOpts.Verbose;
            obj.pVaeTrainingOptions.Plots = options.TrainingOpts.Plots;
            obj.pVaeTrainingOptions.Shuffle = options.TrainingOpts.Shuffle;

            %Set Max Epochs for VAE same as LSTM trainingOptions MaxEpochs when
            %unset
            if ~isfield(options, 'VaeMaxEpochs')
                obj.pVaeTrainingOptions.NumEpochs = options.TrainingOpts.MaxEpochs;
            else
                obj.pVaeTrainingOptions.NumEpochs = options.VaeMaxEpochs;
            end

            %Set Learn Rate for VAE same as LSTM trainingOptions learn rate when
            %unset
            if ~isfield(options, 'VaeInitialLearnRate')
                obj.pVaeTrainingOptions.LearnRate = options.TrainingOpts.InitialLearnRate;
            else
                obj.pVaeTrainingOptions.LearnRate = options.VaeInitialLearnRate;
            end

            % Record training options for LSTM training
            obj.pLstmTrainingOptions = options.TrainingOpts;

            % set the input and output format for training
            obj.pLstmTrainingOptions.InputDataFormats = "TCB";
            obj.pLstmTrainingOptions.TargetDataFormats = "TCB";

            try
                % prepare training data for VAE and LSTM training data
                [lstmSeqTrainingCells, vaeWinArray, ~, ~, obj]   = iPreProcessData(obj, data, obj.TrainingStride, ...
                    ExecutionEnvironment = options.TrainingOpts.ExecutionEnvironment, trainFlag = true);

                % Train network
                [trainedEncoder, trainedDecoder,trainedLstmNet, vaeTrainHistory, lstmTrainHistory] = iModelTrain(obj, vaeWinArray, ...
                    lstmSeqTrainingCells, obj.pVaeTrainingOptions, obj.pLstmTrainingOptions, options.VaeMonitor,  options.LstmMonitor);

                obj.pDlnetVaeEncoder = trainedEncoder;
                obj.pDlnetVaeDecoder = trainedDecoder;
                obj.pDlnetLstm = trainedLstmNet;
                obj.pVaeTrainingInfo= vaeTrainHistory;
                obj.pLstmTrainingInfo= lstmTrainHistory;
                obj.Dlnet = {obj.pDlnetVaeEncoder, obj.pDlnetVaeDecoder, obj.pDlnetLstm};
                % Compute threshold
                if ~strcmp(obj.ThresholdMethod, "manual")
                    if obj.pLstmTrainingOptions.Verbose
                        disp(getString(message('predmaint_anomaly:anomaly:msgComputingThreshold')))
                    end
                    % minibatchpredict does not support parallel/multi-gpu Geck: g3723144
                    trainEE = iConvertEEForDetection(obj, obj.pLstmTrainingOptions.ExecutionEnvironment);

                    trainWinScores = iGetWinScores(obj, lstmSeqTrainingCells, ExecutionEnvironment = trainEE, MiniBatchSize = obj.pLstmTrainingOptions.MiniBatchSize);
                    thres = anomalyCLI.internal.utils.anomalyThresholding(trainWinScores, ...
                        obj.ThresholdMethod, obj.ThresholdParameter, obj.ThresholdFunction);
                    obj.Threshold = gather(thres);

                    if obj.pLstmTrainingOptions.Verbose
                        disp(getString(message("predmaint_anomaly:anomaly:msgFinishThreshold")))
                    end
                end
                obj.IsTrained = true;
            catch E
                throwAsCaller(E)
            end
        end

        function result = detect(obj, data, options)
            % Run "doc anomalyCLI.deepanomaly.VaelstmDetector/detect" for more information.


            % DETECT is designed to detect subsequence anomalies in data using
            % trained network. The length of subsequence is prediction window length.
            % The subsequences are non-overlapped. The window anomaly
            % scores are calculated and the window labels are determined
            % by the threshold value. data can be one of these:
            %
            %   - An N-column matrix.
            %     data consists of a single multichannel signal observation
            %     (M = 1). A sufficiently long single observation can be as
            %     effective for training as multiple shorter observations.
            %
            %   - An M-element cell array containing N-column matrices
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
            %   and numeric window anomaly scores for each window. The window
            %   start index of the data is identified by winStartIdx.
            %
            %   resultsTable  = detect(...,MiniBatchSize=MBS) specifies the
            %   mini-batch size MBS for network prediction.
            %   Set MBS to a positive integer scalar. The default is 128.
            %
            %   resultsTable  = detect(...,PlotHistogram=PH) specifies
            %   the flag indictor for plot. If PH is true, the figure that
            %   plot the anomaly score histogram is presented.
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
            % D = anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector(3);
            % D = train(D, sineWaveNormal);
            % resultsTable = detect(D, sineWaveAbnormal);

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])}
                options.MiniBatchSize (1, 1) double {mustBeInteger,mustBePositive} = 128
                options.PlotHistogram (1, 1) logical = false
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
                options.Resolution(1,1) {mustBeMember(options.Resolution,["sample","window","member"])} = "window"
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

                [lstmSeqCells, ~, segmentInfo, dataCell]  = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                % detect anomaly
                winScores = iGetWinScores(obj, lstmSeqCells, MiniBatchSize = options.MiniBatchSize, ExecutionEnvironment = options.ExecutionEnvironment);
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
            % Run "doc anomalyCLI.deepanomaly.VaelstmDetector/updateDetector" for more information.


            % UPDATEDETECTOR is designed to update the settings of a
            % trained detector and recompute the threshold based on the
            % updated parameters. The Data is used to calculate the
            % threshold if the thresholdMethod is not 'manual'. The Data
            % should consist solely of normal data, meaning it must not
            % contain any known anomalies or anomalous data. It is expected
            % to be in one of the following formats:
            %
            %   - An N-column matrix.
            %     data consists of a single multichannel signal observation
            %     (M = 1). A sufficiently long single observation can be as
            %     effective for training as multiple shorter observations.
            %
            %   - An M-element cell array containing N-column matrices
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
            %   updateDetector(obj, data) updates the threshold value using
            %   the new data.
            %
            %   updateDetector(obj,...,ThresholdMethod="manual",Threshold=TH)
            %   specifies a user-defined threshold that is independent of
            %   any training data. Threshold must be set to a real positive
            %   scalar. When ThresholdMethod is set to "manual" and
            %   Threshold is not specified, the function sets the value of
            %   TH to the current value of Threshold in detector D.
            %
            %   updateDetector(obj, data,...,ThresholdMethod=TM,ThresholdParameter=TP)
            %   specifies a method TM used to compute the anomaly detection
            %   threshold based on training data. You also specify a
            %   threshold parameter TP that varies depending on the
            %   selected method. The list enumerates the different
            %   threshold methods and corresponding threshold parameter:
            %
            %   "max"                   - The detection threshold is
            %                             computed as the maximum window
            %                             loss, measured over the entire
            %                             training data set and multiplied
            %                             by the threshold parameter TP. TP
            %                             must be a positive scalar.
            %
            %   "mean"                  - The detection threshold is
            %                             computed as the mean window loss,
            %                             measured over the entire training
            %                             data set and multiplied by the
            %                             threshold parameter TP. TP must
            %                             be a positive scalar.
            %
            %   "median"                - The detection threshold is
            %                             computed as the median window
            %                             loss, measured over the entire
            %                             training data set and multiplied
            %                             by the threshold parameter TP. TP
            %                             must be a positive scalar.
            %
            %   "contaminationFraction" - The detection threshold is
            %                             computed as the value that
            %                             results in the detection as
            %                             anomalies of a specified fraction
            %                             of windows, measured over the
            %                             entire training data set. The
            %                             fraction is specified by the
            %                             threshold parameter, TP, which
            %                             must be a nonnegative scalar and
            %                             less than 0.5.
            %   "kSigma"                - The detection threshold is
            %                             computed by normalizing the
            %                             anomaly scores. The threshold
            %                             parameter k indicator whether
            %                             anomaly scores is larger than
            %                             k-sigma of estimated anomaly
            %                             score distribution.
            %
            %   If ThresholdMethod or ThresholdParameter is not specified,
            %   the function sets the value of TM or TP equal to the
            %   current value of the corresponding parameter in detector D.
            %
            %   D = updateDetector(obj, data,...,ThresholdMethod=customFunction,ThresholdFunction=TF)
            %   specifies the threshold computation method by a custom
            %   function TF. The function T should take in two inputs. The
            %   first input is a cell array of aggregated window losses and
            %   the second input is a cell array of sample losses before
            %   aggregation. Each cell contains the loss vector for a
            %   signal observation. The function TF must return one single
            %   positive scalar to be set as a threshold. When
            %   ThresholdFunction is not specified, TF is set to the
            %   current ThresholdFunction value of detector.
            %
            % EXAMPLE:
            % Load a sine-wave data set sineWaveAnomalyData.mat, which
            % consists of 3-channel sine wave signals. sineWaveNormal
            % contains 10 normal signals with stable frequency and
            % amplitude. Train the network with normal data
            % sineWaveNormal. sineWaveAbnormal contains three signals with
            % various anomalies, like frequency changes, amplitude changes,
            % and  spikes. After training and plotting anomalies scores, use
            % updateThreshold method to update the threshold method used or
            % threshold value.
            %
            % load sineWaveAnomalyData.mat
            % D = vaelstmAD(3);
            % D = train(D, sineWaveNormal);
            % plot(D, sineWaveAbnormal{1});
            % D = updateDetector(D, ThresholdMethod="manual", Threshold=4);

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector
                data {mustBeA(data, ["cell", "numeric", "timetable", "gpuArray"])} = []
                options.ThresholdMethod (1,1) string {mustBeMember(options.ThresholdMethod,["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}
                options.ThresholdParameter = []
                options.ThresholdFunction = []
                options.Threshold = []
                options.MiniBatchSize (1, 1) double {mustBeInteger, mustBePositive} = 128;
                options.DetectionStride double {mustBeReal, mustBeInteger, mustBePositive} = []
                options.ExecutionEnvironment (1, 1) string {mustBeMember(options.ExecutionEnvironment,["cpu","auto","gpu"])} = "auto"
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
                    targetArray = iPreProcessData(obj, data, obj.DetectionStride, ExecutionEnvironment = options.ExecutionEnvironment);

                    % detect anomaly
                    winScores = iGetWinScores(obj, targetArray, ExecutionEnvironment = options.ExecutionEnvironment, MiniBatchSize = options.MiniBatchSize);

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
        % Build underlying model networks
        function obj = iBuildModel(obj)
            % Build VAE
            [obj.FilterSize, obj.NumFilters, obj.VaeDownsampleFactor] = ...
                anomalyCLI.internal.deepanomaly.utils.prepareLayerParamVec(obj.NumDownsampleLayers, "NumDownsampleLayers", ...
                ["FilterSize", "NumFilters", "VaeDownsampleFactor"], ...
                obj.FilterSize, obj.NumFilters, obj.VaeDownsampleFactor);

            obj.pLayersVaeEncoder = inputLayer([obj.VaeWindowLength, obj.NumChannels, NaN], "SCB", Name="Input") ;

            projectionSize = [obj.VaeWindowLength, obj.NumFilters(end)];


            for i = 1: obj.NumDownsampleLayers
                covLayer = convolution1dLayer(obj.FilterSize(i), ...
                    obj.NumFilters(i), ...
                    Padding="same", ...
                    Stride = obj.VaeDownsampleFactor(i));

                obj.pLayersVaeEncoder = [obj.pLayersVaeEncoder
                    covLayer
                    layerNormalizationLayer
                    reluLayer
                    ];
            end

            obj.pLayersVaeEncoder = [obj.pLayersVaeEncoder
                fullyConnectedLayer(2*obj.LatentSpaceDim, Name="fc_encoder")
                anomalyCLI.internal.deepanomaly.layer.samplingLayer];

            obj.pLayersVaeDecoder = [featureInputLayer(obj.LatentSpaceDim)
                anomalyCLI.internal.deepanomaly.layer.projectAndReshapeLayer(projectionSize)];

            for i = 1:obj.NumDownsampleLayers-1
                transposedLayer =  transposedConv1dLayer(obj.FilterSize(end-i), ...
                    obj.NumFilters(end-i), ...
                    Cropping ="same", ...
                    Stride = obj.VaeDownsampleFactor(end-i));

                obj.pLayersVaeDecoder = [obj.pLayersVaeDecoder
                    transposedLayer
                    layerNormalizationLayer
                    reluLayer
                    ];
            end

            obj.pLayersVaeDecoder = [obj.pLayersVaeDecoder
                transposedConv1dLayer(obj.FilterSize(1), obj.NumChannels, Cropping="same")];

            % build VAE net
            obj.pDlnetVaeEncoder = dlnetwork(obj.pLayersVaeEncoder);
            obj.pDlnetVaeDecoder = dlnetwork(obj.pLayersVaeDecoder);

            % build LSTM net
            obj.pLayersLstm = [sequenceInputLayer(obj.LatentSpaceDim, Name="Input")];
            for ii = 1:length(obj.NumHiddenUnits)
                obj.pLayersLstm = [obj.pLayersLstm
                    lstmLayer(obj.NumHiddenUnits(ii))];
            end

            obj.pLayersLstm = [obj.pLayersLstm
                fullyConnectedLayer(obj.LatentSpaceDim)];

            obj.pDlnetLstm = dlnetwork(obj.pLayersLstm);

            % save models
            obj.Layers = {obj.pLayersVaeEncoder, obj.pLayersVaeDecoder, obj.pLayersLstm};
            obj.Dlnet = {obj.pDlnetVaeEncoder, obj.pDlnetVaeDecoder, obj.pDlnetLstm};
        end

        % Train the network with training data and targets
        function [trainedEncoder, trainedDecoder,trainedLstmNet, vaeTrainHistory, lstmTrainHistory] = iModelTrain(obj, vaeTrainWin, lstmTrainSeq, ...
                vaeTrainningOpts, lstmTrainingOpts, vaeMonitor, lstmMonitor)
            arguments
                obj
                vaeTrainWin
                lstmTrainSeq
                vaeTrainningOpts
                lstmTrainingOpts
                vaeMonitor = []
                lstmMonitor = []
            end
            % train VAE network
            if vaeTrainningOpts.Verbose
            disp(getString(message("predmaint_anomaly:anomaly:msgVaeTrainingStarting")));
            end
            [trainedEncoder, trainedDecoder, vaeTrainHistory] = iModelVaeTrain(obj, vaeTrainWin, ...
                numEpochs = vaeTrainningOpts.NumEpochs, miniBatchSize = vaeTrainningOpts.MiniBatchSize, ...
                learnRate = vaeTrainningOpts.LearnRate, ExecutionEnvironment = vaeTrainningOpts.ExecutionEnvironment, ...
                Verbose = obj.pVaeTrainingOptions.Verbose, Plots = obj.pVaeTrainingOptions.Plots, Shuffle = obj.pVaeTrainingOptions.Shuffle, ...
                Monitor = vaeMonitor);
            if vaeTrainningOpts.Verbose
            disp(getString(message("predmaint_anomaly:anomaly:msgVaeTrainingFinished")));
            end

            % generate VAE embedding
            if obj.pLstmTrainingOptions.Verbose
            disp(getString(message("predmaint_anomaly:anomaly:msgLSTMDataPrep")));
            end
            executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment( ...
                "ExecutionEnvironment", vaeTrainningOpts.ExecutionEnvironment, ...
                "DispatchInBackground", 0);
            [~, XEmb, TargetEmb] = iGenerateVaeEmbedding(obj, lstmTrainSeq, ...
                ExecutionEnvironment = executionSettings.ExecutionEnvironment, ...
                MiniBatchSize=vaeTrainningOpts.MiniBatchSize);

            % Evaluate the post vae training callback if defined
            if ~isempty(obj.OnVaeTrainingDone)
                 obj.OnVaeTrainingDone();
            end

            % train LSTM network
            if lstmTrainingOpts.Verbose
            disp(getString(message("predmaint_anomaly:anomaly:msgLSTMTrainingStarting")));
            end
            [trainedLstmNet, lstmTrainHistory] = iModelLstmTrain(obj, XEmb, TargetEmb, lstmTrainingOpts, lstmMonitor);
            if lstmTrainingOpts.Verbose
            disp(getString(message("predmaint_anomaly:anomaly:msgLSTMTrainingFinished")));
            end
        end

        % Train the VAE network with training data and targets
        function  [netE, netD, monitor] = iModelVaeTrain(obj, trainInput, options)
            arguments
                obj
                trainInput
                options.NumEpochs = 150
                options.LearnRate = 1e-03
                options.MiniBatchSize = 128
                options.ExecutionEnvironment = "auto"
                options.Verbose = true
                options.Plots = "none"
                options.Shuffle = "once"
                options.Monitor = []
            end

            import anomalyCLI.deepanomaly.VaelstmDetector.*
            executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment( ...
                "ExecutionEnvironment", options.ExecutionEnvironment, ...
                "DispatchInBackground", 0);

            % convert data into minibatch
            dsTrain = arrayDatastore(trainInput,IterationDimension=3);

            trainQueue = minibatchqueue(dsTrain, 1, ...
                OutputAsDlarray=true,...
                MiniBatchSize = options.MiniBatchSize, ...
                MiniBatchFcn = @preprocessMiniBatch,...
                MiniBatchFormat="SCB", ...
                OutputEnvironment= executionSettings.ExecutionEnvironment, ...
                PartialMiniBatch = "discard");

            % setup monitor
            if isempty(options.Monitor)
                monitor = trainingProgressMonitor(Visible = false);
            else
                monitor = options.Monitor;
            end

            if strcmp(options.Plots, 'training-progress') || ~isempty(options.Monitor)
                % configure monitor and update constant information
                monitor.Visible = true;
                monitor.Progress = 0;
                monitor.XLabel = "Iteration" ;
                monitor.Status = "Running";               
                monitorMetricDisplayName  = "VAE Training Loss";
                monitor.Metrics = "TrainingLoss";
                yLims = {[0 Inf]};
                setYLimits(monitor, monitorMetricDisplayName, yLims);
                setLegendLocation(monitor, monitorMetricDisplayName, "northeast");
                setMetricDisplayNames(monitor, "TrainingLoss", monitorMetricDisplayName)
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
                numIterationsPerEpoch = max(floor(numObservationsTrain / options.MiniBatchSize), 1);
                options.NumIterations = options.NumEpochs * numIterationsPerEpoch;
            end

            % define the appropriate trainer based on serial vs. parallel training
            options.ExecutionEnvironment = executionSettings.ExecutionEnvironment;
            if executionSettings.UseParallel
                networkTrainer = VaeParallelTrainer(trainQueue, obj.pDlnetVaeEncoder, obj.pDlnetVaeDecoder, @vaeModelLoss, options);
            else
                networkTrainer = VaeSerialTrainer(trainQueue, obj.pDlnetVaeEncoder, obj.pDlnetVaeDecoder, @vaeModelLoss, options);            
            end
            [netE, netD] = fit(networkTrainer, monitor);
        end

        % Train the LSTM network with training data and targets
        function [trainedNet,trainHistory] = iModelLstmTrain(obj, XEmb, TargetEmb, trainingOpts,monitor)
            arguments
                obj
                XEmb
                TargetEmb
                trainingOpts
                monitor = []
            end
            lossFcn = "mse";
            network = obj.pDlnetLstm;

            if isempty(monitor)
                [trainedNet,trainHistory] = trainnet(XEmb, TargetEmb, network, lossFcn, trainingOpts);
            else
                [trainedNet,trainHistory] = deep.internal.sdk.trainnet.trainnet(XEmb, TargetEmb, network, lossFcn, trainingOpts, Monitor=monitor);
            end
        end

        % Generate VAE embedding
        function [embedding, XEmb, TargetEmb] = iGenerateVaeEmbedding(obj, sequenceCells, options)
            % iGenerateVaeEmbedding Generates VAE embeddings for LSTM training.
            %
            % This function processes a set of sequences to generate embeddings using
            % a trained VAE encoder. It prepares the input and target
            % embeddings for LSTM training by utilizing the encoder of the VAE model.
            %
            % Inputs:
            %   obj           - Object instance
            %   sequenceCells - Cell array of sequences, where each cell contains a
            %                   sequence to be processed.
            %   options.ExecutionEnvironment - Specifies the execution environment.
            %   options.MiniBatchSize - Size of mini-batches for prediction.
            %
            % Outputs:
            %   embedding - Cell array containing the VAE embeddings for each sequence.
            %   XEmb      - Cell array of input embeddings for LSTM training.
            %   TargetEmb - Cell array of target embeddings for LSTM training.

            arguments
                obj
                sequenceCells
                options.MiniBatchSize = 128
                options.ExecutionEnvironment = "auto"
            end
            numLstmSeq = length(sequenceCells);
            seqLength = size(sequenceCells{1}, 3);

            % Concatenate sequences into one batch along the time dimension
            allSequences = cat(3, sequenceCells{:});
            curSeqBatch = dlarray(allSequences, 'SCB');

            % Use the VAE encoder to predict the latent space representation for the batch
            ZBatch = minibatchpredict(obj.pDlnetVaeEncoder, curSeqBatch, ...
                MiniBatchSize = options.MiniBatchSize, ...
                ExecutionEnvironment = options.ExecutionEnvironment);
            ZBatch = extractdata(ZBatch);

            ZBatch = reshape(ZBatch, size(ZBatch, 1), seqLength, []);
            embeddingArray = permute(ZBatch, [2, 1, 3]); % 'TCB'

            % get input and target for LSTM training and convert them into
            % cell array
            XEmbArray = embeddingArray(1:end-1, :,:);
            TargetEmbArray = embeddingArray(2:end,:, :);

            embedding = mat2cell(embeddingArray, size(embeddingArray, 1), size(embeddingArray, 2), ones(numLstmSeq,1));
            embedding = reshape(embedding, [numLstmSeq, 1]);

            [a,b, ~] = size(XEmbArray);
            XEmb = mat2cell(XEmbArray, a, b, ones(numLstmSeq,1));
            XEmb = reshape(XEmb, [numLstmSeq, 1]);

            TargetEmb = mat2cell(TargetEmbArray, a, b, ones(numLstmSeq,1));
            TargetEmb = reshape(TargetEmb, [numLstmSeq, 1]);
        end

        % Predict LSTM sequence
        function [seqPred, XEmbPred] = iModelLstmPredictDecode(obj, XEmb, options)
            % iModelLstmPredictDecode Predicts LSTM sequences and decodes them using a VAE.
            %
            % This function takes LSTM embeddings, predicts the sequence using an LSTM
            % network, and then decodes the predicted embeddings using a VAE decoder.
            %
            % Inputs:
            %   obj     - Object instance
            %   XEmb    - Cell array of LSTM input embeddings.
            %   options.ExecutionEnvironment - Specifies the execution environment.
            %   options.MiniBatchSize - Size of mini-batches for prediction.
            %
            % Outputs:
            %   seqPred  - Cell array of predicted sequences after decoding.
            %   XEmbPred - Cell array of predicted LSTM embeddings.

            arguments
                obj
                XEmb
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize = 256
            end

            XEmbPred = minibatchpredict(obj.pDlnetLstm, XEmb, ...
                ExecutionEnvironment = options.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize, ...
                UniformOutput=false);

            % Extract the last time step from each predicted LSTM embedding
            XEmbPred = cellfun(@(x) x(end, :), XEmbPred, 'UniformOutput', false);
            % Concatenate sequences into one batch along the time dimension
            allEmb = cell2mat(XEmbPred);
            allEmbBatch = dlarray(allEmb, 'BC');

            % Decode the concatenated embeddings using the VAE decoder
            predDecoded = minibatchpredict(obj.pDlnetVaeDecoder, allEmbBatch, ...
                ExecutionEnvironment = options.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize);
            predDecoded = extractdata(predDecoded);

            % Convert the decoded predictions into a cell array, one cell per sequence
            seqPred = mat2cell(predDecoded, size(predDecoded,1), size(predDecoded,2), ones(size(predDecoded,3),1));
            seqPred = reshape(seqPred, [size(seqPred,3), 1]);
        end

        % Compute anomaly scores based on predictions and actual values
        function pointScores = iComputeAnomalyScore(~, TargetSeq, TargetPred)
            % iComputeAnomalyScore Computes anomaly scores based on mean square error.
            %
            % This function calculates the mean square error (MSE) between two sets of
            % sequences, TargetSeq and TargetPred, which are provided as cell arrays.
            % Each cell contains a 10x3 matrix. The function returns the MSE scores
            % for each sequence as a column vector.
            %
            % Inputs:
            %   ~          - Unused placeholder input.
            %   TargetSeq  - Cell array where each cell contains a matrix representing
            %                the target sequence.
            %   TargetPred - Cell array where each cell contains a matrix representing
            %                the predicted sequence.
            %
            % Outputs:
            %   pointScores - Column vector of size [N, 1], where N is the number of cells
            %                 in TargetSeq (and TargetPred). Each element is the MSE for
            %                 the corresponding pair of target and predicted sequences.
            %
            TargetSeqArray = cat(3, TargetSeq{:});
            TargetPredArray = cat(3, TargetPred{:});
            squaredDiff = (TargetSeqArray - TargetPredArray).^2;
            mse = sum(squaredDiff, [1, 2]) / (size(TargetSeqArray, 1) * size(TargetSeqArray, 2));
            pointScores = reshape(mse, [size(TargetSeqArray, 3), 1]);
        end

        %------------------------------------------------------------------
        % detect anomalies
        function  scores = iGetWinScores(obj, lstmSeq, options)
            % iDetect Detects anomalies in LSTM sequences using VAE-LSTM model.
            %
            % This function detects anomalies in sequences by predicting embeddings
            % with a VAE and LSTM model, then computing anomaly scores based on
            % prediction errors.
            %
            % Inputs:
            %   obj     - Instance of VaelstmDetector class used for anomaly detection.
            %   lstmSeq - Cell array of input LSTM sequences to be analyzed.
            %   options - Struct with optional parameters:
            %             - ExecutionEnvironment: Specifies the execution environment (default is "auto").
            %             - MiniBatchSize: Size of mini-batches for prediction (default is 128).
            %
            % Outputs:
            %   labels      - Binary array indicating whether each sequence is an anomaly.
            %   scores      - Array of anomaly scores for each sequence.
            %   lstmSeqPred - Cell array of predicted LSTM sequences.

            arguments
                obj (1, 1) anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector
                lstmSeq
                options.ExecutionEnvironment = "auto"
                options.MiniBatchSize (1, 1) = 128;
            end

            executionSettings = deep.internal.sdk.parallel.setupExecutionEnvironment( ...
                "ExecutionEnvironment", options.ExecutionEnvironment, ...
                "DispatchInBackground", 0);

            % predict and compute anomaly prediction
            [~, XEmb, ~] = iGenerateVaeEmbedding(obj, lstmSeq, ExecutionEnvironment = executionSettings.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize);

            lstmSeqPred = iModelLstmPredictDecode(obj, XEmb, ExecutionEnvironment = executionSettings.ExecutionEnvironment, ...
                MiniBatchSize=options.MiniBatchSize);

            % calculate the anomaly scores. Get the last VaeWindowLength
            % data, which is correlated to the last LSTM embedding
            % prediction.
            target = cellfun(@(x) x(:,:, end), lstmSeq, 'UniformOutput', false);
            scores = iComputeAnomalyScore(obj, target, lstmSeqPred);
            scores = double(gather(scores));
        end

        % prepare the data for training or detection
        function [lstmSeqCells, vaeWinArray, lstmSegmentInfo, dataCell, obj] = iPreProcessData(obj, data, stride, options)
            % iPreProcessData Prepares data for training or detection using VAE and LSTM.
            %
            % This function preprocesses the input data for training or detection tasks
            % using Variational Autoencoder (VAE) and Long Short-Term Memory (LSTM) models.
            % It handles data normalization, segmentation, and formatting for model input.
            %
            % Inputs:
            %   obj      - Object instance containing model parameters and methods.
            %   data     - Input cell array to be preprocessed.
            %   stride   - Stride length for data segmentation for LSTM input preparation.
            %   options.trainFlag: Boolean indicating if the data is for training.
            %   options.ExecutionEnvironment: Specifies the execution environment.
            %
            % Outputs:
            %   vaeWinArray     - Array containing VAE window data for training. Each
            %   row indicates a sample.
            %   lstmSeqCells    - Cell array containing LSTM sequence data. Each cell
            %   contains an array indicating a sequence.
            %   dataInfo        - Information about the data structure.
            %   lstmSegmentInfo - Information about LSTM data segmentation.
            %   dataCell        - Cell array representation of the normalized input data.
            %   obj             - Updated object instance with normalization parameters.

            arguments
                obj
                data
                stride = 1
                options.trainFlag = false
                options.ExecutionEnvironment = "auto"
            end

            vaeWinArray = [];

            % convert data to cell data
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.ObservationWindowLength, obj.DetectionStride)
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            % Normalization (in double precision before single conversion)
            [dataCell, obj] = iNormalization(obj, dataCell, options.trainFlag);

            dataCell = iSetupEnvironmentAndPrepareData(obj, dataCell, options.ExecutionEnvironment);


            % covert data to cell data
            if options.trainFlag
                % prepare input for VAE training as 3D array directly
                vaeWinArray = prepareVaeArray(dataCell, obj.VaeWindowLength);

                % prepare input for LSTM training
                [lstmSeqCells, lstmSegmentInfo] = prepareLstmCells(dataCell, obj.NumChannels, obj.VaeWindowLength, obj.LstmWindowLength, stride);

            else
                % prepare input for LSTM prediction
                [lstmSeqCells, lstmSegmentInfo] = prepareLstmCells(dataCell, obj.NumChannels, obj.VaeWindowLength, obj.LstmWindowLength, stride);
            end
        end
    end

    methods(Hidden, Static)
        function n = matlabCodegenRedirect(~)
            n = 'anomalyCLI.coder.deepanomaly.VaelstmDetector';
        end
    end
end

%% Local function
function [dataInputCells, segmentInfo] =  prepareVaeCells(cellData, windowLength, options)
arguments
    cellData
    windowLength
    options.Stride = 1
end

[dataInput, numWindows] = cellfun(@(x)anomalyCLI.internal.utils.createRollingWindows(x, windowLength, options.Stride), cellData, 'UniformOutput', false);
dataInputCells = vertcat(dataInput{:});
segmentInfo.numWindows = vertcat(numWindows{:});
end

function vaeWinArray = prepareVaeArray(cellData, windowLength)
    numChannels = size(cellData{1}, 2);
    stride = 1;
    numCells = numel(cellData);
    winCounts = zeros(numCells, 1);
    for i = 1:numCells
        winCounts(i) = floor((size(cellData{i},1) - windowLength)/stride) + 1;
    end
    totalWindows = sum(winCounts);

    vaeWinArray = zeros(windowLength, numChannels, totalWindows, 'like', cellData{1});
    offset = 0;
    for i = 1:numCells
        d = cellData{i};
        nWin = winCounts(i);
        startIndices = (0:nWin-1)' * stride + 1;
        winIdx = startIndices + (0:windowLength-1);
        chunk = reshape(d(winIdx', :), windowLength, nWin, numChannels);
        vaeWinArray(:, :, offset+1:offset+nWin) = permute(chunk, [1, 3, 2]);
        offset = offset + nWin;
    end
end

function  [lstmSeqCells, segmentInfo] = prepareLstmCells(cellData, numChannel, windowLength, sequenceLength, stride)
arguments
    cellData
    numChannel
    windowLength
    sequenceLength
    stride
end

[vaeInput, numWindows, lstmWinStartIdx] = cellfun(@(x)anomalyCLI.internal.utils.createRollingWindows(x, windowLength*sequenceLength, stride, NumWindows=floor((size(x,1) - windowLength*sequenceLength)/stride) + 1), cellData, 'UniformOutput', false);
vaeInputCells = vertcat(vaeInput{:});

% convert the array in each cell of vaeInputCells
% [windowLength*sequenceLength, numChannel] into [windowLength, numChannel,
% sequenceLength for LSTM input
reshape2LstmFunc = @(x) permute(reshape(x, [windowLength, sequenceLength, numChannel]), [1, 3, 2]);
lstmSeqCells = cellfun(reshape2LstmFunc, vaeInputCells, 'UniformOutput', false);

segmentInfo.numWindows = vertcat(numWindows{:});
% Input data start index for LSTM network. Entire length of the LSTM
% network is windowLength*sequenceLength
lstmWinStartIdx = vertcat(lstmWinStartIdx{:});
% Prediction data start index. The last windowLength points of the entire
% LSTM network input
segmentInfo.winStartIdx = lstmWinStartIdx + windowLength*(sequenceLength-1);
end

function X = preprocessMiniBatch(dataX)
% Concatenate.
X = cat(3,dataX{:});
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
