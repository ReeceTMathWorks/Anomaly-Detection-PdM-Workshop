classdef (Abstract) AbstractDeepAnomalyDetector
   
%#codegen

%   Copyright 2025-2026 The MathWorks, Inc.

    properties (SetAccess = protected)    
        NumChannels
        Threshold
        Normalization
        DetectionStride        
        DataCenter
        DataScale
    end

    methods (Abstract)
        iPreProcessData;
        iGetWinScores;
    end

    methods
        function this = AbstractDeepAnomalyDetector(opts)
            coder.internal.prefer_const(opts);
            % Use prefer_const on variables that are expected to be constant,
            % This will  aid coder in constant folding.
            pnames = fieldnames(opts);
            coder.unroll(true);
            for i = 1:numel(pnames)
                this.(pnames{i}) = opts.(pnames{i});
            end
        end

        
        function result = detect(this,data,options)
            arguments
                this
                data {mustBeNonempty, mustBeA(data, {'cell', 'numeric', 'timetable'})}
                options.Resolution (1,1) string {coder.mustBeConst(options.Resolution,...
                "predmaint_anomaly:anomaly:optionMustBeConst","Resolution"),mustBeMember(options.Resolution, {'window','sample','member'})} = "window"
                options.AnomalousWindowPercentage (1,1) double {mustBeGreaterThanOrEqual(options.AnomalousWindowPercentage,0), mustBeLessThanOrEqual(options.AnomalousWindowPercentage,100)}
                options.LabelConversionMethod (1,1) string {coder.mustBeConst(options.LabelConversionMethod,...
                "predmaint_anomaly:anomaly:optionMustBeConst","LabelConversionMethod"),mustBeMember(options.LabelConversionMethod,...
                    {'majorityVoting','normalPriority','anomalyPriority'})}
                options.MiniBatchSize (1,1){ coder.mustBeConst(options.MiniBatchSize,....
                    "predmaint_anomaly:anomaly:optionMustBeConst","MiniBatchSize"),mustBeInteger,mustBePositive} = 128
            end
            if iscell(data)
                coder.internal.assert(coder.internal.isConst(size(data)),"predmaint_anomaly:anomaly:cellInputToDetectMustBeFixedSize");
            end

            if options.Resolution ~= "member" && isfield(options,'AnomalousWindowPercentage')
                coder.internal.compileWarning("predmaint_anomaly:anomaly:warnUnusedAnomalousWindowPercentage");
            end

            if options.Resolution ~= "sample" && isfield(options,'LabelConversionMethod')
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

            [dataArray,targetArray,segmentInfo,dataCell]  = iPreProcessData(this,data,this.DetectionStride);

            winScores = iGetWinScores(this,dataArray,targetArray,MiniBatchSize=options.MiniBatchSize);
            winLabels = winScores > this.Threshold;
            result = iPrepareResult(this,winLabels,segmentInfo.winStartIdx,segmentInfo.numWindows,options.Resolution, ...
                       WinScores=winScores,DataCell=dataCell,LabelConversionMethod=labelConversionMethod, ...
                       AnomalousWindowPercentage=anomalousWindowPercentage);

        end

        function res = iPrepareResult(this,winLabels,winStartIdx,numWindows,resolution,options)
            arguments
                this
                winLabels
                winStartIdx
                numWindows
                resolution
                options.WinScores
                options.DataCell
                options.LabelConversionMethod = "anomalyPriority"
                options.AnomalousWindowPercentage (1,1) double = 10
            end
            coder.internal.prefer_const(numWindows,resolution)
            numCells = coder.internal.indexInt(numel(numWindows));
            offset = coder.internal.indexInt(0);

            switch resolution
                case "member"
                    [memberLabels, memberScores, memberIndex] = anomalyCLI.internal.utils.windowLabelsToMemberLabels( ...
                        options.WinScores, numWindows, options.AnomalousWindowPercentage, this.Threshold);
                    res = table(memberLabels(:), memberScores(:), memberIndex(:), ...
                        'VariableNames', {'Labels', 'AnomalyScores', 'MemberIndices'});
                case "window"
                    doUnroll = ~coder.internal.isHomogeneousCell(options.DataCell)...
                        && coder.internal.isConst(numWindows) && coder.const(any(diff(numWindows) ~= 0));
                    result = cell(numCells,1);
                    coder.unroll(doUnroll)
                    for i = 1:numCells
                        bwinlabels = coder.nullcopy(zeros(numWindows(i),1,"like",winLabels));
                        bwinAnomalyScores = coder.nullcopy(zeros(numWindows(i),1,"like",options.WinScores));
                        bwinStartIdx = coder.nullcopy(zeros(numWindows(i),1));
                        for k = 1:numWindows(i)
                            bwinlabels(k) = winLabels(offset + k);
                            bwinAnomalyScores(k) = options.WinScores(offset+k);
                            bwinStartIdx(k) = winStartIdx(offset+k);
                        end
                        result{i} = table(bwinlabels,bwinAnomalyScores,bwinStartIdx,...
                            'VariableNames',{'Labels', 'AnomalyScores', 'StartIndices'});
                        offset = offset + numWindows(i);
                    end
                    if numCells == 1
                        res = result{1};
                    else
                        res = result;
                    end
                case "sample"
                    doUnroll = ~coder.internal.isHomogeneousCell(options.DataCell);
                    result = cell(numCells,1);
                    coder.unroll(doUnroll)
                    for i = 1:numCells
                        bwinlabels = coder.nullcopy(zeros(numWindows(i),1,"like",winLabels));
                        bwinAnomalyScores = coder.nullcopy(zeros(numWindows(i),1,"like",options.WinScores));
                        bwinStartIdx = coder.nullcopy(zeros(numWindows(i),1));
                        for k = 1:numWindows(i)
                            bwinlabels(k) = winLabels(offset + k);
                            bwinAnomalyScores(k) = options.WinScores(offset+k);
                            bwinStartIdx(k) = winStartIdx(offset+k);
                        end
                        [sampleLabel, sampleScore, sampleIdx] = ...
                            anomalyCLI.internal.utils.windowLabelsToSampleLabels( ...
                            bwinlabels, this.DetectionWindowLength, bwinStartIdx, ...
                            'Method', options.LabelConversionMethod, ...
                            'DataLength', size(options.DataCell{i},1),...
                            'WinScores', bwinAnomalyScores);
                        result{i} = table(sampleLabel, sampleScore, sampleIdx, ...
                            'VariableNames', {'Labels', 'AnomalyScores', 'StartIndices'});
                        offset = offset + numWindows(i);
                    end
                    if numCells == 1
                        res = result{1};
                    else
                        res = result;
                    end
            end
        end

        function this = updateDetector(this,data,options)
           % For code generation we only support updating Threshold to a
           % numeric value.
            arguments
                this
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
            this.Threshold(1) = options.Threshold(1);
        end       
    end

    methods(Static)
        function props = matlabCodegenNontunableProperties(~)
            props = {'NumChannels','Normalization', 'DetectionStride'};
        end
    end

end
