function winLabels = sampleLabelsToWindowLabels(labels, windowLength, stride, observationWinLength, modelType)
% localConvertSamples2Win Convert sample-level labels to window-level labels
%   winLabels = localConvertSamples2Win(labels, windowLength, stride)
%   takes a cell array of logical column vectors (labels), a window length,
%   and a stride, and returns a cell array of window-level labels where each
%   window is labeled as 1 if any sample in that window is labeled as 1.

% Copyright 2025 The MathWorks, Inc.

numMembers = numel(labels);
winLabels = cell(size(labels));
handler = anomalyAPP.internal.app.modelmanager.utils.mapDetectorToHandler(modelType);
for i = 1:numMembers
    sampleLabels = labels{i};
    numWindows = handler.getNumWindows(windowLength, stride, observationWinLength, size(sampleLabels,1));
    if ismember(modelType, ["cnnae", "lstmae", "lstmf"])
        % Preallocate cell array
        windowInputData = cell(numWindows, 1);

        for iWin = 1:numWindows
            startIdx = (iWin - 1) * stride + 1;
            endIdx = min((startIdx + windowLength - 1), size(sampleLabels,1));
            windowInputData{iWin, 1} = sampleLabels(startIdx:endIdx);
        end
    elseif modelType=="vaelstm"
        % For VAELSTM models, the windowLength is the VAE window length. We
        % need to compute the actual window length used to get the windows
        vaeWindowLength = windowLength;
        lstmWindowLength = floor(observationWinLength/vaeWindowLength);
        windowLength  = vaeWindowLength*lstmWindowLength;
        windowInputData = anomalyCLI.internal.utils.createRollingWindows(sampleLabels, windowLength, stride, NumWindows=numWindows);
    else
        windowInputData = anomalyCLI.internal.utils.createRollingWindows(sampleLabels(observationWinLength+1:end), windowLength, stride, NumWindows=numWindows);
    end

    winLabels{i} = cellfun(@any, windowInputData);
end

end