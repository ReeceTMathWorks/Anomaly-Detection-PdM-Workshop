classdef TimeSeriesLOFDetector < anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector
    % Run "doc anomalyCLI.mlanomaly.TimeSeriesLOFDetector" for more information.

    %   Copyright 2025 The MathWorks, Inc.

    properties(SetAccess = private)
        NumNeighbors double {mustBeReal, mustBeInteger, mustBePositive} = []
        Distance (1, 1) string {mustBeMember(Distance, ["euclidean","fasteuclidean","cityblock","chebychev","minkowski","mahalanobis","cosine","correlation","spearman"])} = "euclidean"
        BucketSize (1,1) double {mustBePositive, mustBeInteger} = 50
        CacheSize
        Cov
        Exponent
        IncludeTies (1, 1) logical = false
        SearchMethod string {mustBeMember(SearchMethod, ["kdtree","exhaustive"])} = []
    end


    %% Public Methods
    methods (Access=public)
        function obj = TimeSeriesLOFDetector(numChannels, options, baseProps)
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
            % Run "doc anomalyCLI.mlanomaly.TimeSeriesLOFDetector/train" for more information.

            arguments
                obj (1, 1) anomalyCLI.mlanomaly.TimeSeriesLOFDetector
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

                % train model
                modelParameters = struct('NumNeighbors', obj.NumNeighbors, ...
                    'Distance', obj.Distance, ...
                    'BucketSize', obj.BucketSize, ...
                    'CacheSize', obj.CacheSize, ...
                    'Cov', obj.Cov, ...
                    'Exponent', obj.Exponent, ...
                    'IncludeTies', obj.IncludeTies, ...
                    'SearchMethod', obj.SearchMethod);

                opts = namedargs2cell(modelParameters);
                [trainedModel, ~, winScores] = lof(trainInput, opts{:});
                obj.NumNeighbors = trainedModel.NumNeighbors;
                obj.Distance = trainedModel.Distance; 
                obj.Cov = trainedModel.DistanceParameter;
                if isfield(trainedModel,"Exponent")
                    obj.Exponent = trainedModel.Exponent;
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

end
