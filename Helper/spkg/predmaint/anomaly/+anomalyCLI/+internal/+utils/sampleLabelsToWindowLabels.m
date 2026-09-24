function winLabels = sampleLabelsToWindowLabels(labels, windowLength, stride, observationWinLength, modelType)
% localConvertSamples2Win Convert sample-level labels to window-level labels
%   winLabels = localConvertSamples2Win(labels, windowLength, stride)
%   takes a cell array of logical column vectors (labels), a window length,
%   and a stride, and returns a cell array of window-level labels where each
%   window is labeled as 1 if any sample in that window is labeled as 1.

% Copyright 2025 The MathWorks, Inc.

numMembers = numel(labels);
winLabels = cell(size(labels));

for i = 1:numMembers
    sampleLabels = labels{i};
    if ismember(modelType, ["cnnae", "lstmae", "lstmf"])
        numWindows = ceil(size(sampleLabels, 1) / stride);

        % Preallocate cell array
        windowInputData = cell(numWindows, 1);

        for iWin = 1:numWindows
            startIdx = (iWin - 1) * stride + 1;
            endIdx = min((startIdx + windowLength - 1), size(sampleLabels,1));
            windowInputData{iWin, 1} = sampleLabels(startIdx:endIdx);
        end
    elseif modelType=="vaelstm"
        vaeWindowLength = windowLength;
        lstmWindowLength = floor(observationWinLength/vaeWindowLength);
        windowLength  = vaeWindowLength*lstmWindowLength;
        numWindows=floor((size(sampleLabels,1) - windowLength)/stride) + 1;
        windowInputData = anomalyCLI.internal.utils.createRollingWindows(sampleLabels, windowLength, stride, NumWindows = numWindows);
    else
        numWindows = floor((size(sampleLabels, 1) - observationWinLength - windowLength)/stride) + 1;
        % get training window input
        windowInputData = anomalyCLI.internal.utils.createRollingWindows(sampleLabels, windowLength, stride, "NumWindows", numWindows);
    end

    winLabels{i} = cellfun(@any, windowInputData);
end

end