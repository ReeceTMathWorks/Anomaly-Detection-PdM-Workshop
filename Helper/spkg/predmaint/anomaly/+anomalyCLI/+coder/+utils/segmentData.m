function [segmentedData, nCompleteWindows, winStartIdx] = segmentData(data, detectionWindowLength, stride,numCompleteWindows,windowOutputType)

%#codegen

%   Copyright 2026 The MathWorks, Inc.
coder.internal.prefer_const(detectionWindowLength,stride);
% Use indexInt to generate integer operations in generated code.
ndata = coder.internal.indexInt(size(data,1));
winLen = coder.internal.indexInt(detectionWindowLength);
strideLen = coder.internal.indexInt(stride);
if nargin < 5
    matrixOutput = true;
else
    coder.internal.prefer_const(windowOutputType)
    matrixOutput = strcmp(validatestring(windowOutputType,{'matrix','cell'},mfilename),'matrix');
end
%When the stride is same as WindowLength the segmentedData will have
%non-overlapping windows
if nargin < 4 || isempty(numCompleteWindows)
    nCompleteWindows = coder.internal.indexDivide(ndata - winLen,strideLen) + 1;
else
    coder.internal.prefer_const(numCompleteWindows)
    nCompleteWindows = coder.internal.indexInt(numCompleteWindows);
end
if matrixOutput
    segmentedData = coder.nullcopy(zeros(winLen,size(data,2),nCompleteWindows,"like",data));
else
    segmentedData = coder.nullcopy(repmat({zeros(winLen,size(data,2),"like",data)},nCompleteWindows,1));
end
winStartIdx = coder.nullcopy(zeros(nCompleteWindows, 1,coder.internal.indexIntClass));

% Segment the complete windows
for i = 1:nCompleteWindows
    startIdx = (i - 1) * strideLen + 1;
    if matrixOutput
        segmentedData(:, :, i) = data(startIdx + (0:winLen-1), :);
    else
        segmentedData{i} = data(startIdx + (0:winLen-1), :);
    end
    winStartIdx(i) = startIdx;
end
end
