classdef VaelstmDetector < anomalyCLI.coder.deepanomaly.AbstractDeepAnomalyDetector 
    
    %#codegen

    %   Copyright 2026 The MathWorks, Inc.

    properties (SetAccess=private)
        ObservationWindowLength
        DetectionWindowLength
        pDlnetVaeEncoder
        pDlnetVaeDecoder
        pDlnetLstm
    end

    methods

        function this = VaelstmDetector(myProps,baseProps)
            coder.internal.prefer_const(myProps,baseProps);

            % construct base class first.
            this@anomalyCLI.coder.deepanomaly.AbstractDeepAnomalyDetector(baseProps);

            pnames = fieldnames(myProps);
            coder.unroll();
            for i = 1:numel(pnames)
                this.(pnames{i}) = myProps.(pnames{i});
            end
        end

        function [lstmSeqCells, vaeWinArray, lstmSegmentInfo, dataCell] = iPreProcessData(this, data, stride)
            coder.internal.prefer_const(stride);
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateInputData(data,...
                this.NumChannels, this.ObservationWindowLength, this.DetectionStride);

            dataCell1 = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
            dataCell = cellfun(@single,dataCell1, 'UniformOutput',false);
            if ~coder.const(strcmp(this.Normalization,'off'))
                dataCell = cellfun(@(X)normalize(X,"center",this.DataCenter,"scale",this.DataScale),...
                    dataCell,'UniformOutput',false);
            end

            vaeWinArray = [];
            vaeWindowLength = this.DetectionWindowLength;
            lstmWindowLength = floor(this.ObservationWindowLength/vaeWindowLength);
            [lstmSeqCells, lstmSegmentInfo] = prepareLstmCells(dataCell, iscell(data),...
                this.NumChannels, vaeWindowLength, lstmWindowLength, stride);

        end

        function winScores = iGetWinScores(this,lstmSeqCells,~,options)
            arguments
                this
                lstmSeqCells
                ~
                options.MiniBatchSize
            end
            coder.internal.prefer_const(options);
            miniBatchSize = coder.internal.indexInt(options.MiniBatchSize);
            XEmb = iGenerateVaeEmbeddings(this, lstmSeqCells, miniBatchSize);
            lstmSeqPred = iModelLstmPredictDecode(this, XEmb, miniBatchSize);

            target = cellfun(@(x)x(:,:,end),lstmSeqCells,'UniformOutput',false);
            winScores = iComputeAnomalyScores(this,target,lstmSeqPred);
        end

        function XEmb = iGenerateVaeEmbeddings(this,lstmSeqCells,miniBatchSize)
            coder.internal.prefer_const(miniBatchSize);
            numLstmSeq = coder.internal.indexInt(numel(lstmSeqCells));
            seqLength = coder.internal.indexInt(size(lstmSeqCells{1},3));

            m = coder.internal.indexInt(size(lstmSeqCells{1},1));
            n = coder.internal.indexInt(size(lstmSeqCells{1},2));

            totalBatches = numLstmSeq*seqLength;
            allSeq = coder.nullcopy(dlarray(zeros(m,n,totalBatches,'single'),'SCB'));
            k = coder.internal.indexInt(0);
            % Cannot use allSeq = cat(3,lstmSeqCells{:}) because the input
            % lstmSeqCells can be variable-sized during codegen
            for i = 1:numLstmSeq
                for j = 1:seqLength
                    k = k + 1;
                    allSeq(:,:,k) = dlarray(lstmSeqCells{i}(:,:,j),'SCB');
                end
            end

            ZBatch = anomalyCLI.coder.utils.miniBatchPredictSCB(this.pDlnetVaeEncoder,...
                allSeq,miniBatchSize);

            Z = reshape(extractdata(ZBatch),size(ZBatch,1),seqLength,[]);
            embeddingArray = permute(Z,[2 1 3]);
            XEmb = coder.nullcopy(repmat({embeddingArray(1:end-1,:,1)},numLstmSeq,1));
            for i = 1:numLstmSeq
                XEmb{i} = embeddingArray(1:end-1,:,i);
            end
        end

        function lstmSeqPred = iModelLstmPredictDecode(this, XEmb,miniBatchSize)
            coder.internal.prefer_const(miniBatchSize);

            XEmbPred = anomalyCLI.coder.utils.miniBatchPredictTCB(this.pDlnetLstm,...
                XEmb,miniBatchSize);

            nb = coder.internal.indexInt(numel(XEmbPred));

            allEmbBatch = coder.nullcopy(dlarray(zeros(size(XEmbPred{1},2),nb,'single'),'CB'));
            for i = 1:nb
                allEmbBatch(:,i) = XEmbPred{i}(end,:)';
            end

            predDecoded = extractdata(anomalyCLI.coder.utils.miniBatchPredictSCB(this.pDlnetVaeDecoder,...
                allEmbBatch, miniBatchSize));
            lstmSeqPred = coder.nullcopy(repmat({predDecoded(:,:,1)},nb,1));
            for i = 1:nb
                lstmSeqPred{i} = predDecoded(:,:,i);
            end

        end

        function winScores = iComputeAnomalyScores(~,targetSeq,targetPred)
            [m,n] = size(targetSeq{1});
            scale = cast(m*n,'single');
            op = @(x,y) double(sum((x-y).^2,"all")/scale);
            winScores = cellfun(op,targetSeq,targetPred,'UniformOutput',true);
        end
    end

    methods(Static,Hidden)

        function props = matlabCodegenNontunableProperties(~)
            props = [{'ObservationWindowLength','DetectionWindowLength'},...
                anomalyCLI.coder.deepanomaly.AbstractDeepAnomalyDetector.matlabCodegenNontunableProperties];
        end

        function name = matlabCodegenUserReadableName()
            % The below name will appear in the report generated by coder.
            name = 'VaelstmDetector';
        end

        function cgObj = matlabCodegenToRedirected(mlObj)
           
            anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTrained(...
                mlObj.IsTrained);

            myProps.ObservationWindowLength = mlObj.ObservationWindowLength;
            myProps.DetectionWindowLength = mlObj.DetectionWindowLength;
            [myProps.pDlnetVaeEncoder, myProps.pDlnetVaeDecoder, myProps.pDlnetLstm] = ...
                deal(mlObj.Dlnet{:});
            % Base class properties.
            baseProps.NumChannels = mlObj.NumChannels;
            baseProps.Threshold = mlObj.Threshold;
            baseProps.Normalization = mlObj.Normalization;
            baseProps.DetectionStride = mlObj.DetectionStride;
            [baseProps.DataCenter, baseProps.DataScale] = mlObj.getNormalizationParameters();
            cgObj = anomalyCLI.coder.deepanomaly.VaelstmDetector(myProps,baseProps);
        end

    end
end

function  [lstmSeqCells, segmentInfo] = prepareLstmCells(cellData, inputDataWasCell,numChannels, windowLength, sequenceLength, stride)
coder.internal.prefer_const(inputDataWasCell,numChannels, windowLength, sequenceLength, stride);
iWinLen = coder.internal.indexInt(windowLength);
iSeqLen = coder.internal.indexInt(sequenceLength);
istride = coder.internal.indexInt(stride);

iWinLenEffective = iWinLen*iSeqLen;
if coder.const(inputDataWasCell)
    [vaeInput, numWindows, lstmWinStartIdx] = cellfun(@(x)anomalyCLI.coder.utils.segmentData(...
        x,iWinLenEffective,istride,[],'cell'),cellData,'UniformOutput',false);
    vaeInputCells = vertcat(vaeInput{:});


    segmentInfo.numWindows = vertcat(numWindows{:});
    % Input data start index for LSTM network. Entire length of the LSTM
    % network is windowLength*sequenceLength
    lstmWinStartIdx = vertcat(lstmWinStartIdx{:});

else
    [vaeInputCells,segmentInfo.numWindows,lstmWinStartIdx] = ...
        anomalyCLI.coder.utils.segmentData(cellData{1},iWinLenEffective,istride,[],'cell');
end
reshape2LstmFunc = @(x) permute(reshape(x, [windowLength, sequenceLength, numChannels]), [1, 3, 2]);
lstmSeqCells = cellfun(reshape2LstmFunc, vaeInputCells, 'UniformOutput', false);

% Prediction data start index. The last windowLength points of the entire
% LSTM network input
segmentInfo.winStartIdx = lstmWinStartIdx + iWinLen*(iSeqLen-1);
end
