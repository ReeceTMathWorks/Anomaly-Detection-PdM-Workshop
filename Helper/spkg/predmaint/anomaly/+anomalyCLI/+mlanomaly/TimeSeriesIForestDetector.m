classdef TimeSeriesIForestDetector < anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
    % Run "doc anomalyCLI.mlanomaly.TimeSeriesIForestDetector" for more information.
    
    %   Copyright 2025-2026 The MathWorks, Inc.

    properties(SetAccess = private)
        % set the properties will reset the IsTrain property as False
        NumLearners (1, 1) double {mustBeReal, mustBeInteger, mustBePositive} = 100
        NumObservationsPerLearner double {mustBeReal, mustBeInteger, mustBePositive} = []
    end


    %% Public Methods
    methods (Access=public)
        function obj = TimeSeriesIForestDetector(numChannels, options, baseProps)
            arguments
                numChannels (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
                options struct = struct()
                baseProps struct = struct()
            end
            % Set properties in the AbstractDeepAnomalyDetector
            basePropsCell = namedargs2cell(baseProps);
            obj@anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector(basePropsCell{:})
            obj.NumChannels = numChannels;

            % set model specific properties
            if ~isempty(options)
                field = fieldnames(options);
                for i = 1:length(field)
                    obj.(field{i}) = options.(field{i});
                end
            end

        end

        function obj = train(obj, data, options)
            % Run "doc anomalyCLI.mlanomaly.TimeSeriesIForestDetector/train" for more information.

            
                %train Train the detector on input time series data
                %   Train the TimeSeriesIForestDetector on input time series data using
                %   isolation forest algorithm.
                %
                %   Inputs:
                %       obj             - TimeSeriesIForestDetector object
                %       data           - Input time series data as numeric array, cell array,
                %                       timetable, or gpuArray
                %       options.WindowLength    - Length of sliding window (default: obj.WindowLength)
                %       options.TrainingStride  - Stride between training windows (default: obj.TrainingStride)
                %
                %   The method segments the input data into windows, trains an isolation forest
                %   model, and computes the anomaly threshold based on the training scores.
            arguments
                obj (1, 1) anomalyCLI.mlanomaly.TimeSeriesIForestDetector
                data (:, :) {mustBeNonempty, mustBeA(data, ["cell", "numeric", "timetable"])}
                options.WindowLength = obj.WindowLength
                options.TrainingStride = obj.TrainingStride
            end
            
            % g3957048 error out when input is cell of gru array 
            if iscell(data) && any(cellfun(@isgpuarray, data(:)))
                    error(message("predmaint_anomaly:anomaly:errInvalidCellMemberType"))
            end

            obj.WindowLength = options.WindowLength;
            obj.TrainingStride = options.TrainingStride;

            try
                % check data
                anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.WindowLength, obj.DetectionStride)
                dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);

                % preprocess the data to convert the input data into cells and
                % segment signals into windows for training input and targets
                [trainInput, ~, obj] = iSegmentFeaturizeCell(obj, dataCell, obj.WindowLength, obj.TrainingStride, ...
                    NormalizationMethod = obj.Normalization,...
                    TrainFlag = true);

                % Train the model
                if isempty(obj.NumObservationsPerLearner)
                [trainedModel, ~, winScores] = iforest(trainInput, ...
                    NumLearners=obj.NumLearners);
                obj.NumObservationsPerLearner = trainedModel.NumObservationsPerLearner;
                else
                    [trainedModel, ~, winScores] = iforest(trainInput, ...
                        NumLearners=obj.NumLearners, ...
                        NumObservationsPerLearner=obj.NumObservationsPerLearner);
                end
                obj.pModel = trainedModel;

                % calculate threshold
                 obj.Threshold = anomalyCLI.internal.utils.anomalyThresholding(winScores, ...
                     obj.ThresholdMethod, obj.ThresholdParameter, obj.ThresholdFunction);
                
                obj.IsTrained = true;
            catch E
                throwAsCaller(E)
            end
        end
    end

    methods(Hidden,Static)
        function n = matlabCodegenRedirect(~)
            n = 'anomalyCLI.coder.mlanomaly.TimeSeriesIForestDetector';
        end
    end

end
