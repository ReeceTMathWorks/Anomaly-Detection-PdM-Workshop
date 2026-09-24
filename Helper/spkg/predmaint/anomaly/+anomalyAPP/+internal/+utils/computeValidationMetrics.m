function model = computeValidationMetrics(model, validationData, trainData, selectedDataKey, labelIndex, cv, labels)
oc = model.LKGDetectConfig;   % Get configurations to use
cc = model.TipDetectConfig;
% The call to detect updates the model based on settings in the
% Detect tab which can change the Detection Window Size and
% Stride which impacts the logic below. Therefore,we need to
% use the returned model from the call to detect.

% Copyright 2026 The MathWorks, Inc.

% ConfigUpdate is needed only if Tip (cc) is different than LKG (oc)
needsConfigUpdate = ~isequal(cc, oc);
config = cc;

[res, model] = model.Handler.detect(model, trainData, validationData, config, needsConfigUpdate);

predictions = cellfun(@(c) c.Labels, res, 'UniformOutput', false);
scores = cellfun(@(c) c.AnomalyScores, res, 'UniformOutput', false);

if (labelIndex ~= 0)
    gndTruth = subset(cv,labels, false);

    % Fetch the cross model common window definitions for the sample to window label converter function
    [windowLength, detectionStride, obsWinLen] = model.Handler.getCommonWindowDefinitions(model.Model);
    winLabels = anomalyCLI.internal.utils.sampleLabelsToWindowLabels(...
        gndTruth, windowLength, detectionStride, obsWinLen, model.Type);
else
    % Else generate labels for training data assuming that all training data is normal
    %For each cell, create a label vector
    for iC = 1:numel(predictions)
        winLabels{iC,1} = zeros(size(predictions{iC},1),1);
    end
end
% Warning management
% Save current warning state
currentWarningState = warning;

% Turn off a specific warnings by ID
warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToOne');
warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToZero');
warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToOne');
warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToZero');
warning('off', 'predmaint_anomaly:anomaly:warnF1SetToZero');
warning('off', 'predmaint_anomaly:anomaly:warnF1SetToOne');
warning('off', 'predmaint_anomaly:anomaly:warnFprSetToZero');
warning('off', 'predmaint_anomaly:anomaly:warnNoNormalLabel');

% Turn off warning for specific boundary conditions
% Compute metrics with Aggregation=True for dataset level metrics
T_dataset = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=true);

% Compute metrics with Aggregation=false for member level metrics
T_member = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=false);

% Restore warning conditions to previous saved state

% Restore previous warning state
warning(currentWarningState);

% Assign results to ValidationResults
numValidationMembers = numel(predictions); % Using predictions instead of validationData cause predictions is a lot smaller in size
totalNumMembers = cv.NumSeries; % This is the total number of members in the imported data

if totalNumMembers == 1
    numValidationSamples = numel(validationData{1});
else
    numValidationSamples = [];
end

model.ValidationResults(selectedDataKey) = struct("DatasetMetrics", T_dataset, ...
    "MemberMetrics", T_member, ...
    "AnomalyScores", {scores}, ...
    "NumValidationMembers", numValidationMembers, ...
    "TotalNumDatasetMembers", totalNumMembers, ...
    "NumValidationSamples", numValidationSamples,...
    "ValidationHoldout", cv.HoldoutRatio);
end