classdef (Abstract) AbstractMachineLearningAnomalyDetector
    %#codegen

    %   Copyright 2026 The MathWorks, Inc.

    properties(SetAccess=protected)
        NumChannels
        WindowLength
        DetectionStride
        Normalization
        FeatureExtraction
        Threshold
    end
    properties (Hidden,Access=protected)
        pModel
        pDataCenter
        pDataScale
        pValidFeatureColumns
    end

    methods

        function obj =AbstractMachineLearningAnomalyDetector(opts)
            fn = fieldnames(opts);
            coder.unroll();
            for i = 1:numel(fn)
                obj.(fn{i}) = opts.(fn{i});
            end
        end

        function tbl = detect(obj, data, options)
            arguments
                obj (1,1)
                data {mustBeNonempty, mustBeA(data, {'cell', 'numeric', 'timetable'})}
                options.Resolution(1,1) string {coder.mustBeConst(options.Resolution,...
                    "predmaint_anomaly:anomaly:optionMustBeConst","Resolution"),mustBeMember(options.Resolution,{'sample','window','member'})} = "window"
                options.AnomalousWindowPercentage (1,1) double {mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
                options.LabelConversionMethod (1,1) string {coder.mustBeConst(options.LabelConversionMethod,...
                    "predmaint_anomaly:anomaly:optionMustBeConst","LabelConversionMethod"),mustBeMember(options.LabelConversionMethod,...
                    {'majorityVoting','normalPriority','anomalyPriority'})}
            end
            coder.internal.prefer_const(options);
            if iscell(data)
                coder.internal.assert(coder.internal.isConst(size(data)),"predmaint_anomaly:anomaly:cellInputToDetectMustBeFixedSize");
            end

            if options.Resolution ~= "member" && isfield(options, 'AnomalousWindowPercentage')
                coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage");
            end

            if options.Resolution ~= "sample" && isfield(options, 'LabelConversionMethod')
                coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedLabelConversionMethod");
            end

            if isfield(options, 'AnomalousWindowPercentage')
                anomalousWindowPercentage = options.AnomalousWindowPercentage;
            else
                anomalousWindowPercentage = 10;
            end

            if isfield(options, 'LabelConversionMethod')
                labelConversionMethod = options.LabelConversionMethod;
            else
                labelConversionMethod = "anomalyPriority";
            end

            [winScores, dataCell, segmentInfo] = iGetWinScores(obj, data);
            winLabels = winScores > obj.Threshold;

            offset = coder.internal.indexInt(0);
            numCells = coder.internal.indexInt(numel(segmentInfo.numWindows));

            switch options.Resolution
                case "member"
                    [memberLabels, memberScores, memberIndex] = anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        winScores, segmentInfo.numWindows, anomalousWindowPercentage, obj.Threshold);
                    tbl = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        'VariableNames', {'Labels', 'AnomalyScores', 'MemberIndices'});
                case "window"
                    dounroll = ~coder.internal.isHomogeneousCell(dataCell) && ...
                        coder.internal.isConst(segmentInfo.numWindows) && ...
                        coder.const(any(diff(segmentInfo.numWindows) ~= 0));
                    result = cell(numCells, 1);
                    coder.unroll(dounroll);
                    for i = 1:numCells
                        winLabelsCell = coder.nullcopy(false(segmentInfo.numWindows(i),1));
                        winStartIdxCell = coder.nullcopy(zeros(segmentInfo.numWindows(i),1));
                        winAnomalyScoresCell = coder.nullcopy(zeros(segmentInfo.numWindows(i),1,"like",winScores));
                        for k = 1:segmentInfo.numWindows(i)
                            winLabelsCell(k) = winLabels(offset+k);
                            winStartIdxCell(k) = segmentInfo.winStartIdx(offset + k);
                            winAnomalyScoresCell(k) = winScores(offset+k);
                        end
                        result{i} = table(winLabelsCell, winAnomalyScoresCell, winStartIdxCell, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                        offset = offset + segmentInfo.numWindows(i);
                    end
                    if numCells == 1
                        tbl = result{1};
                    else
                        tbl = result;
                    end
                case "sample"
                    dounroll = ~coder.internal.isHomogeneousCell(dataCell);
                    result = cell(numCells, 1);
                    coder.unroll(dounroll);
                    for i = 1:numCells
                        winLabelsCell = coder.nullcopy(false(segmentInfo.numWindows(i),1));
                        winStartIdxCell = coder.nullcopy(zeros(segmentInfo.numWindows(i),1));
                        winAnomalyScoresCell = coder.nullcopy(zeros(segmentInfo.numWindows(i),1,"like",winScores));
                        for k = 1:segmentInfo.numWindows(i)
                            winLabelsCell(k) = winLabels(offset+k);
                            winStartIdxCell(k) = segmentInfo.winStartIdx(offset + k);
                            winAnomalyScoresCell(k) = winScores(offset+k);
                        end
                        [sampleLabel, sampleScore, sampleIdx] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            winLabelsCell, obj.WindowLength, winStartIdxCell, ...
                            'Method', labelConversionMethod, ...
                            'DataLength', size(dataCell{i},1),...
                            'WinScores', winAnomalyScoresCell);
                        result{i} = table(sampleLabel, sampleScore, sampleIdx, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                        offset = offset + segmentInfo.numWindows(i);
                    end
                    if numCells == 1
                        tbl = result{1};
                    else
                        tbl = result;
                    end
            end
        end

        function obj = updateDetector(obj,data, options)
            % For code generation we only support updating Threshold to a
            % numeric value.
            arguments
                obj
                data = []
                options.ThresholdMethod
                options.Threshold
            end

            isValid = isfield(options,'ThresholdMethod') && ...
                coder.internal.isConstTrue(strcmp(options.ThresholdMethod,'manual')) && ...
                isfield(options,'Threshold');
            coder.internal.assert(isValid,"predmaint_anomaly:anomaly:InvalidInputToUpdateDetectorCG")

            if ~isempty(data)
                coder.internal.compileWarning("predmaint_anomaly:anomaly:warnNoNeedData");
            end
            validateattributes(options.Threshold,{'numeric'},{'real','scalar'},'', 'Threshold');
            obj.Threshold(1) = options.Threshold(1);
        end

    end

    methods(Access = protected, Hidden)
        function [winScores, dataCell, segmentInfo] = iGetWinScores(obj, data)
            % check data
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data, obj.NumChannels, obj.WindowLength, obj.DetectionStride)
            dataCell =  anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);

            % preprocess the data by reformatting, normalizing and
            % segmenting into windows
            [dataArray, segmentInfo] = iSegmentFeaturizeCell(obj, dataCell, obj.WindowLength, obj.DetectionStride);

            % detect anomaly
            [~, winScores] = isanomaly(obj.pModel,dataArray);
        end

        function [featureArray, segmentInfo, obj] = iSegmentFeaturizeCell(obj, dataCell, windowLength, stride)
            arguments
                obj
                dataCell (:,1) cell
                windowLength (1,1)
                stride
            end
            coder.internal.prefer_const(windowLength,stride);
            windowFun = @(x)anomalyCLI.coder.utils.segmentData(x,windowLength,stride);
            % Create window data as 3D arrays
            if ~isscalar(dataCell)
                [dataInput, numWindows, winStartIdx] = cellfun(windowFun, dataCell, 'UniformOutput', false);
                windowArray3D = cat(3,dataInput{:});
                segmentInfo.numWindows = vertcat(numWindows{:});
                segmentInfo.winStartIdx = vertcat(winStartIdx{:});
            else
                % Do not call cellfun when original input was cell, cellfun
                % outputs are not constants and can lead to unnecessary
                % variable-sizing.
                [windowArray3D,segmentInfo.numWindows, segmentInfo.winStartIdx] = windowFun(dataCell{1});
            end

            % Process features.
            if windowLength == 1 && obj.FeatureExtraction
                % When window length is 1, feature extraction doesn't make sense
                coder.internal.compileWarning("predmaint_anomaly:anomaly:warnNoFeatureExtraction");
                featureArray = reshapeArray3D(windowArray3D);
            elseif obj.FeatureExtraction
                % Extract statistical features from 3D array
                featureArrayTemp = extractStatisticsFeaturesArray3D(windowArray3D);
                if ~isempty(obj.pValidFeatureColumns)
                    featureArray = featureArrayTemp(:, obj.pValidFeatureColumns);
                else
                    featureArray = featureArrayTemp;
                end
            else
                % No feature extraction, reshape 3D to 2D
                featureArray = reshapeArray3D(windowArray3D);
            end
            if obj.Normalization ~= "off"
                featureArray = normalize(featureArray,1, "center",  obj.pDataCenter, "scale", obj.pDataScale);
            end
        end
    end

    methods(Static,Hidden)
        function n = matlabCodegenNontunableProperties(~)
            n = {'NumChannels','WindowLength','DetectionStride',...
                'Normalization','FeatureExtraction','pValidFeatureColumns'};
        end
    end
end

function d = reshapeArray3D(windowArray3D)
% Reshape 3D array (windowLength x numChannels x numWindows) to 2D
% (numWindows*windowLength x numChannels)
winLen = coder.internal.indexInt(size(windowArray3D,1));
numCh = coder.internal.indexInt(size(windowArray3D,2));
numWin = coder.internal.indexInt(size(windowArray3D,3));
d = zeros(winLen*numWin, numCh, "like", windowArray3D);
for i = 1:numWin
    offset = (i-1)*winLen;
    d(offset + (1:winLen),:) = windowArray3D(:,:,i);
end
end

function featureMatrix = extractStatisticsFeaturesArray3D(dataArray3D)
% Compute statistical features on a 3D array (windowLength x numChannels x numWindows)
% Output: (numWindows x numChannels*5)
numWindows = coder.internal.indexInt(size(dataArray3D, 3));
numChannels = coder.internal.indexInt(size(dataArray3D, 2));
numStats = coder.internal.indexInt(5);
featureMatrix = zeros(numWindows, numChannels*numStats, "like", dataArray3D);
for i = 1:numWindows
    win = dataArray3D(:,:,i);
    featureMatrix(i,:) = [mean(win,1), rms(win,1), std(win,0,1), max(abs(win),[],1), mad(win,1,1)];
end
end
