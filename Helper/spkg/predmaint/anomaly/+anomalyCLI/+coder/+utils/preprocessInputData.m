function [dataArray, segmentInfo, dataCell] = preprocessInputData(data,windowLength,...
            stride, doNormalization, dataCenter, dataScale)

%   Copyright 2025-2026 The MathWorks, Inc.
%#codegen

coder.internal.prefer_const(data,stride,doNormalization);

dataCell = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.convertDataToCellArray(data);
if coder.const(doNormalization)
    dataCell = cellfun(@(X)normalize(X,"center",dataCenter,"scale",dataScale),...
                dataCell,'UniformOutput',false);
end
dataCell = cellfun(@single,dataCell, 'UniformOutput',false);
prepareDetectionWindows = @(x)anomalyCLI.coder.utils.segmentData(...
    x,windowLength,stride);
if iscell(data)
    [dataInputCells, numWindows, winStartIdx] = cellfun(...
        prepareDetectionWindows,dataCell,'UniformOutput',false);
    dataArray = cat(3,dataInputCells{:});
    segmentInfo.numWindows = vertcat(numWindows{:});
    segmentInfo.winStartIdx = vertcat(winStartIdx{:});
else
    % Do not call cellfun when the input data is not a cell.
    % cellfun doesn't return constant outputs, we want to output
    % a fixed size table when input is fixed size, the number of
    % rows in the output is segmentInfo.numWindows, this 
    % variable is unlikely to be a constant if taken as an output of cellfun.                
    [dataArray, segmentInfo.numWindows, segmentInfo.winStartIdx ] = ...
        prepareDetectionWindows(dataCell{1});
end
end

