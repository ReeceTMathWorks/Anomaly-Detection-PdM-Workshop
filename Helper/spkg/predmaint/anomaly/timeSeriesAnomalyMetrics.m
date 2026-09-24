function metricTable = timeSeriesAnomalyMetrics(predictions, labels, scores, options)
%   Run "doc timeSeriesAnomalyMetrics" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    predictions (1,:) {mustBeVector, mustBeA(predictions, ["cell", "numeric", "logical"]), mustBeNonempty, iMustBeLogical(predictions)}
    labels (1,:) {mustBeVector(labels,'allow-all-empties'), mustBeA(labels, ["cell", "numeric", "string", "categorical", "logical"]), anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(labels, predictions)} = []
    scores (1,:) {mustBeVector(scores,'allow-all-empties'), mustBeA(scores, ["cell","numeric"]),anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(scores, predictions)} = []
    options.NormalClassLabel (1,:) {mustBeVector, mustBeA(options.NormalClassLabel, ["cell", "numeric", "string", "categorical", "logical"])} = 0
    options.Method (1,1) string {mustBeMember(options.Method, ["standard", "point-adjusted"])} = "standard"
    options.Aggregation (1,1) logical = false
    options.DetectionDelay (1,1) double {mustBeReal, mustBeNonnegative} = inf
    options.MinAnomalyFraction (1,1) double {mustBeReal, mustBeBetween(options.MinAnomalyFraction,0,1)} = 0
end

% Check whether the warning messages are turned off externally
% List of warning IDs to check
warningIDs = {'predmaint_anomaly:anomaly:warnUnsupervisedAllZero',...
    'predmaint_anomaly:anomaly:warnUnsupervisedAllOne',...
    'predmaint_anomaly:anomaly:warnUnsupervisedOneSample',...
    'predmaint_anomaly:anomaly:warnPrecisionSetToOne',...
    'predmaint_anomaly:anomaly:warnPrecisionSetToZero',...
    'predmaint_anomaly:anomaly:warnRecallSetToZero',...
    'predmaint_anomaly:anomaly:warnF1SetToOne',...
    'predmaint_anomaly:anomaly:warnFprSetToZero'};

% Check and store the state of each warning
warningStates = struct();
for i = 1:length(warningIDs)
    id = warningIDs{i};
    warnState = warning('query', id);
    warningStates.(matlab.lang.makeValidName(id)) = warnState.state;
end

% Ensure the data length of inputs cells are the same
if iscell(predictions)
    iCheckMemberLength(predictions, labels, scores);
end

% Check NaN in scores and ignore the corresponding labels and predictions g3966034
if ~isempty(scores)
    [predictions, labels, scores] = iCheckNaNValue(predictions, labels, scores);
end

% Convert multi-class labels into binary labels
if ~isempty(labels)
    [normalClassLabel, classLabels] = iConvertLabelSet(labels,options.NormalClassLabel);
    logicalLabels = iConvertLabel2Logical(labels, normalClassLabel);
else
    classLabels = [];
    logicalLabels = [];
    normalClassLabel = options.NormalClassLabel;
end

% Compute metrics
if iscell(predictions)
    if options.Aggregation
        metricStruct = allMembersMetrics(predictions, logicalLabels, scores, labels, ...
            ClassLabels = classLabels,...
            NormalClassLabel = normalClassLabel,...
            Method = options.Method, ...
            DetectionDelay = options.DetectionDelay, ...
            MinAnomalyFraction = options.MinAnomalyFraction);
    else
        numMembers = numel(predictions);
        metricStruct = struct();
        for i = 1:numMembers
            pred = predictions{i};
            logicalLabel = [];
            label = [];
            score = [];

            if ~isempty(logicalLabels)
                logicalLabel = logicalLabels{i};
            end
            if ~isempty(labels)
                label = labels{i};
            end
            if ~isempty(scores)
                score = scores{i};
            end

            memberMetric = tsAnomalyDetectionMetrics(pred, logicalLabel, score, label, ...
                ClassLabels = classLabels,...
                NormalClassLabel = normalClassLabel,...
                Method = options.Method, ...
                DetectionDelay = options.DetectionDelay, ...
                MinAnomalyFraction = options.MinAnomalyFraction);
            if isempty(fieldnames(metricStruct))
                metricStruct = memberMetric;
            else
                metricStruct = [metricStruct, memberMetric];
            end
        end
    end
else
    metricStruct = tsAnomalyDetectionMetrics(predictions, logicalLabels, scores, labels, ...
        ClassLabels = classLabels,...
        NormalClassLabel = normalClassLabel,...
        Method = options.Method, ...
        DetectionDelay = options.DetectionDelay, ...
        MinAnomalyFraction = options.MinAnomalyFraction);
end

metricTable = struct2table(metricStruct, "AsArray", true);

% Reorder the table columns alphabetically
[~, idx] = sort(metricTable.Properties.VariableNames);
metricTable = metricTable(:, idx);

% Restore any warnings that were 'on'
for i = 1:length(warningIDs)
    id = warningIDs{i};
    currentState = warning('query', id);
    fieldName = matlab.lang.makeValidName(id);
    % If the warning was 'on' initially and "off" now, make sure it's 'on' now
    if  strcmp(warningStates.(fieldName), 'on') && ...
            strcmp(currentState.state, 'off')
        warning('on', id);
    end
end
end

function metricStruct = allMembersMetrics(predictionCell, logicalLabelCell, scoreCell, labelCell, options)
%ALLMEMBERSMETRICS Compute metrics by aggregating all time series members
%   This function computes anomaly detection metrics by concatenating all time
%   series members and treating them as a single dataset.
%
%   Inputs:
%       predictionCell     - Cell array of logical vectors containing anomaly predictions
%       logicalLabelCell   - Cell array of logical vectors containing binary ground truth
%       scoreCell          - Cell array of numeric vectors containing anomaly scores
%       labelCell          - Cell array containing original class labels
%       options            - Struct with the following fields:
%           ClassLabels        - Vector of all possible class labels
%           NormalClassLabel   - Vector of labels considered as normal
%           Method             - String specifying evaluation method ("standard" or "point-adjusted")
%           DetectionDelay     - Maximum allowed delay for anomaly detection
%           MinAnomalyFraction - Minimum fraction of anomalies required in a segment
%
%   Output:
%       metricStruct      - Structure containing computed metrics
arguments
    predictionCell (1,:) cell {mustBeVector, mustBeNonempty}
    logicalLabelCell (1,:) cell  {mustBeVector(logicalLabelCell,'allow-all-empties')} = []
    scoreCell (1,:) cell {mustBeVector(scoreCell,'allow-all-empties')} = []
    labelCell (1,:) cell  {mustBeVector(labelCell,'allow-all-empties')} = []
    options.ClassLabels (1,:) {mustBeVector(options.ClassLabels,'allow-all-empties')} = []
    options.NormalClassLabel (1,:) {mustBeNonempty, mustBeVector, mustBeNonempty} = false
    options.Method (1,1) string {mustBeNonempty, mustBeMember(options.Method, ["standard", "point-adjusted"])} = "standard"
    options.DetectionDelay (1,1) double {mustBeReal, mustBeNonnegative} = inf
    options.MinAnomalyFraction (1,1) double {mustBeReal, mustBeGreaterThanOrEqual(options.MinAnomalyFraction, 0), mustBeLessThanOrEqual(options.MinAnomalyFraction, 1)} = 0
end

% Concatenate all cell members into column vectors
allLogicalLabels = iConcatenateCells(logicalLabelCell);
allScores = iConcatenateCells(scoreCell);
allPredictions = iConcatenateCells(predictionCell);
allLabels = iConcatenateCells(labelCell);

if isempty(logicalLabelCell)
    % Unsupervised metrics if no labels provided
    metricStruct = unsupervisedMetrics(allPredictions, allScores);
else
    % Supervised metrics
    if options.Method == "point-adjusted"
        % Adjust predictions member by member
        adjustedCells = cell(numel(predictionCell), 1);
        for ii = 1:numel(predictionCell)
            prediction = predictionCell{ii};
            label = [];
            if ~isempty(logicalLabelCell)
                label = logicalLabelCell{ii};
            end
            detectionDelay = options.DetectionDelay;
            if isinf(detectionDelay)
                detectionDelay = length(prediction);
            end
            adjustedCells{ii} = adjustPoints(prediction, label, detectionDelay, options.MinAnomalyFraction);
        end
        flattened = cellfun(@(v) v(:), adjustedCells, 'UniformOutput', false);
        predictionsToUse = vertcat(flattened{:});
    else
        % Standard method - use original predictions
        predictionsToUse = allPredictions;
    end
    % Calculate metrics using the appropriate predictions
    metricStruct = standardMetrics(predictionsToUse, allLogicalLabels);
    metricStruct.AccuracyPerSubClass = iPerClassAnomalyAccuracy(predictionsToUse, allLabels, options.ClassLabels, options.NormalClassLabel);
end
end

function metricStruct = tsAnomalyDetectionMetrics(predictions, logicalLabels, scores, labels, options)
%TSANOMALYDETECTIONMETRICS Compute metrics for a single time series
%   This function computes anomaly detection metrics for a single time series
%   based on the provided predictions, labels, and scores.
%
%   Inputs:
%       predictions    - Logical vector containing anomaly predictions
%       logicalLabels  - Logical vector containing binary ground truth
%       scores         - Numeric vector containing anomaly scores
%       labels         - Vector containing original class labels
%       options        - Struct with the following fields:
%           ClassLabels        - Vector of all possible class labels
%           NormalClassLabel   - Vector of labels considered as normal
%           Method             - String specifying evaluation method ("standard" or "point-adjusted")
%           DetectionDelay     - Maximum allowed delay for anomaly detection
%           MinAnomalyFraction - Minimum fraction of anomalies required in a segment
%
%   Output:
%       metricStruct   - Structure containing computed metrics
arguments
    predictions (1,:) logical {mustBeNonempty, mustBeNonNan, mustBeFinite}
    logicalLabels (1,:) logical {mustBeNonNan, mustBeFinite, mustBeVector(logicalLabels,'allow-all-empties'), anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(logicalLabels, predictions)} = []
    scores (1,:) double {mustBeReal,mustBeNonNan, mustBeFinite, mustBeVector(scores,'allow-all-empties'), anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(scores, predictions)} = []
    labels (1,:) {mustBeVector(labels,'allow-all-empties'), mustBeA(labels, ["numeric", "string", "categorical", "logical"])} = []
    options.ClassLabels (1,:) {mustBeVector(options.ClassLabels,'allow-all-empties')} = []
    options.NormalClassLabel (1,:) {mustBeVector} = false
    options.Method (1,1) string {mustBeMember(options.Method, ["standard", "point-adjusted"])} = "standard"
    options.DetectionDelay (1,1) double {mustBeReal, mustBeNonnegative} = inf
    options.MinAnomalyFraction (1,1) double {mustBeReal, mustBeGreaterThanOrEqual(options.MinAnomalyFraction, 0), mustBeLessThanOrEqual(options.MinAnomalyFraction, 1)} = 0
end

if isempty(logicalLabels)
    % Unsupervised case
    metricStruct = unsupervisedMetrics(predictions, scores);
else
    % Supervised case
    if options.Method == "point-adjusted"
        detectionDelay = options.DetectionDelay;
        if isinf(detectionDelay)
            detectionDelay = length(predictions);
        end
        predictionsToUse = adjustPoints(predictions, logicalLabels, detectionDelay, options.MinAnomalyFraction);
    else
        % Standard method - use original predictions
        predictionsToUse = predictions;
    end
    % Calculate metrics using the appropriate predictions
    metricStruct = standardMetrics(predictionsToUse, logicalLabels);
    metricStruct.AccuracyPerSubClass = iPerClassAnomalyAccuracy(predictionsToUse, labels, options.ClassLabels, options.NormalClassLabel);
end
end

function unlabeled = unsupervisedMetrics(predictions, scores)
arguments
    predictions (1,:) logical {mustBeNonempty, mustBeFinite}
    scores (:,1) double {mustBeReal, mustBeFinite, mustBeNonNan, mustBeVector(scores,'allow-all-empties'), ...
        anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(scores, predictions)} = []
end

unlabeled = struct();
unlabeled.KLdivergence = NaN;
unlabeled.AvgAnomalySeparation = NaN;
unlabeled.NormalScoresRange = NaN;
% Fraction of predictions marked as anomalies
unlabeled.FractionOfAnomalies = sum(predictions) / numel(predictions);

% Check if all predictions are 0 or all are 1 or only one sample in the
% class

count_zeros = sum(predictions == 0);
count_ones = sum(predictions == 1);

if ~isempty(scores)
    if count_zeros == numel(predictions)
        % When all predictions are 0 (no anomalies)
        unlabeled.NormalScoresRange = max(scores) - min(scores);
        warning(message('predmaint_anomaly:anomaly:warnUnsupervisedAllZero'));
        warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedAllZero');
    elseif count_ones == numel(predictions)
        % When all predictions are 1 (all anomalies)
        warning(message('predmaint_anomaly:anomaly:warnUnsupervisedAllOne'));
        warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedAllOne');
    else
        if count_zeros == 1 || count_ones == 1 %geck: g3908396
            % KL divergence is undefined when one class has only one sample
            warning(message('predmaint_anomaly:anomaly:warnUnsupervisedOneSample'));
            warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedOneSample');
        else
            % KL divergence between normal and abnormal data score distributions
            unlabeled.KLdivergence = relativeEntropy(scores, predictions);
        end
        % Extract anomaly and normal scores
        anomalies = scores(predictions == 1);
        normals   = scores(predictions == 0);

        % Average distance of anomaly scores from the median of normal scores
        unlabeled.AvgAnomalySeparation = median(abs(anomalies - median(normals)));

        % Range of scores for normal data
        unlabeled.NormalScoresRange = max(normals) - min(normals);
    end
end
end


function basics = standardMetrics(predictions, labels)
%standardMetrics Computes basic classification metrics for binary predictions with special handling for edge cases.
%
%   basics = standardMetrics(predictions, labels)
%
%   Inputs:
%       predictions - logical vector, predicted labels
%       labels      - logical vector, ground truth labels

arguments
    predictions (1,:) logical {mustBeNonempty, mustBeFinite}
    labels (1,:) logical {mustBeFinite, mustBeVector(labels,'allow-all-empties'), ...
        anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(labels, predictions)}
end

eps = 1e-5;

% Initialize struct with NaNs
basics = struct( ...
    'Precision', NaN, ...
    'Recall', NaN, ...
    'F1Score', NaN, ...
    'FalsePositiveRate', NaN, ...
    'Accuracy', NaN, ...
    'ConfusionMatrix', NaN);

% Find unique classes present in ground truth and predictions
uniqueLabels = unique(labels);
uniquePreds = unique(predictions);
classes = unique([labels, predictions]);

% Calculate confusion matrix
C = confusionmat(labels, predictions, 'Order', [0 1]);

% Initialize confusion matrix entries
tn = 0; fp = 0; fn = 0; tp = 0;

if isequal(classes, 0) % Only class 0 present
    tn = C(1,1);
    % fp, fn, tp remain 0
elseif isequal(classes, 1) % Only class 1 present
    tp = C(2,2);
    % tn, fp, fn remain 0
else
    tn = C(1,1);
    fp = C(1,2);
    fn = C(2,1);
    tp = C(2,2);
end

% Store confusion matrix as 2x2 for consistency
confMat = [tn, fp; fn, tp];
basics.('ConfusionMatrix') = array2table( ...
    confMat, ...
    'VariableNames', ["Normal","Anomaly"], ...
    'RowNames', ["Normal","Anomaly"]);

% Handle Precision calculation
if abs(tp + fp) < eps % Predictions are all 0. tp + fp = 0
    % No positive predictions
    if isequal(uniqueLabels, 0)
        % All labels are 0 and predicted all 0
        prec = 1;
        warning(message('predmaint_anomaly:anomaly:warnPrecisionSetToOne'));
        warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToOne');

    else
        % Mixed labels but predicted all 0 and All labels are 1 but predicted all 0
        prec = 0;
        warning(message('predmaint_anomaly:anomaly:warnPrecisionSetToZero'));
        warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToZero');
    end
else
    prec = tp / (tp + fp);
end

% Handle Recall calculation
if abs(tp + fn) < eps % Ground truth are all 0, tp + fn == 0
    % No positive ground truth
    if isequal(uniquePreds, 0)
        % All predictions are 0
        rec = 1;
        warning(message('predmaint_anomaly:anomaly:warnRecallSetToOne'));

    else
        rec = 0;
        warning(message('predmaint_anomaly:anomaly:warnRecallSetToZero'));
        warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToZero');
    end
else
    rec = tp / (tp + fn);
end

% Handle F1 Score calculation
if abs(2*tp + fp + fn) < eps % 2*tp + fp + fn == 0
    f1 = 1;
    warning(message('predmaint_anomaly:anomaly:warnF1SetToOne'));
    warning('off', 'predmaint_anomaly:anomaly:warnF1SetToOne');
else
    f1 = 2*tp /(2*tp+fp+fn);
end

% Handle False Positive Rate calculation
if  abs(fp + tn) < eps % Ground truth are all 1, fp + tn == 0
    fpr = 0;
    warning(message('predmaint_anomaly:anomaly:warnFprSetToZero'));
    warning('off', 'predmaint_anomaly:anomaly:warnFprSetToZero');
else
    fpr = fp / (fp + tn);
end

% Calculate accuracy
if isempty(labels)
    acc = NaN;
else
    acc = (tp + tn) / numel(labels);
end

basics.('Precision') = prec;
basics.('Recall') = rec;
basics.('FalsePositiveRate') = fpr;
basics.('F1Score') = f1;
basics.('Accuracy') = acc;
end


function adjustedPrediction = adjustPoints(predictions, labels, delay, minAnomalyFraction)
%ADJUSTPOINTS Adjusts anomaly predictions based on segment rules and delay.
%
%   This function post-processes a logical anomaly prediction vector by enforcing
%   segment-level rules. For each contiguous segment where 'labels' is true,
%   the function checks for anomaly predictions within the segment according to
%   the following logic:
%
%   - If at least one anomaly is predicted within 'delay' points from the start
%     of the segment, and the total number of predicted anomalies in the segment
%     is at least max(minAnomalyFraction * segmentLength, 1), the entire segment
%     is labeled as abnormal (all points in the segment set to 1).
%   - Otherwise, the segment is labeled as normal (all points in the segment set to 0).
%
%   INPUTS:
%       predictions         - Logical vector indicating predicted anomalies.
%       labels              - Logical vector indicating ground truth segments of interest.
%       delay               - Non-negative integer specifying how many points from the
%                             start of each segment to allow for detection (default: length(predictions)).
%       minAnomalyFraction  - Scalar in [0, 1] specifying the minimum fraction of points
%                             in a segment that must be predicted as anomalies for the segment
%                             to be considered abnormal (default: 0).
%
%   OUTPUT:
%       adjustedPrediction  - Logical vector of the same size as 'predictions', with segments
%                             relabeled according to the above rules.
%
%   NOTES:
%       - If minAnomalyFraction is 0, at least one prediction within the delay window is required.
%       - If minAnomalyFraction * segmentLength <= 1, at least one prediction within the delay is required.
%       - Otherwise, both criteria must be met.
%
%   Example:
%       predictions = [0 0 1 1 0 1 0 0];
%       labels =      [0 1 1 1 0 0 1 1];
%       adjusted = adjustPoints(predictions, labels, 2, 0.5);

arguments
    predictions (1,:) logical {mustBeNonempty, mustBeFinite}
    labels (1,:) logical {mustBeFinite, mustBeVector(labels,'allow-all-empties'), ...
        anomalyCLI.internal.utils.mustBeEqualSizeIfNotEmpty(labels, predictions)}
    delay (1,1) double {mustBeInteger, mustBeNonnegative} = length(predictions)
    minAnomalyFraction  (1,1) double {mustBeReal, mustBeGreaterThanOrEqual(minAnomalyFraction, 0), mustBeLessThanOrEqual(minAnomalyFraction, 1)} = 0
end

adjustedPrediction = predictions;

% Find anomaly segment start and end indices
diffLabels = diff([0, labels, 0]); % Pad to detect edges
segmentStartIdx = find(diffLabels == 1);
segmentEndIdx   = find(diffLabels == -1) - 1;

numSegments = length(segmentStartIdx);
if numSegments == 0
    return;
end

% Vectorized: compute per-segment stats using cumulative sums
cumPreds = [0, cumsum(predictions)];
segLengths = segmentEndIdx - segmentStartIdx + 1;
segAnomalyCounts = cumPreds(segmentEndIdx + 1) - cumPreds(segmentStartIdx);
requiredCounts = max(ceil(minAnomalyFraction .* segLengths), 1);

% Check delay condition per segment
delayEndIdx = min(segmentStartIdx + delay, segmentEndIdx);
delayAnomalyCounts = cumPreds(delayEndIdx + 1) - cumPreds(segmentStartIdx);
hasDetectionWithinDelay = delayAnomalyCounts > 0;

% Determine which segments pass both criteria
segmentPass = hasDetectionWithinDelay & (segAnomalyCounts >= requiredCounts);

% Apply results
for i = 1:numSegments
    if segmentPass(i)
        adjustedPrediction(segmentStartIdx(i):segmentEndIdx(i)) = true;
    else
        adjustedPrediction(segmentStartIdx(i):segmentEndIdx(i)) = false;
    end
end
end


function allMemberVec = iConcatenateCells(vectorCell)
%ICONCATENATECELLS Concatenate all vectors in a cell array into a single column vector
%   This function takes a cell array of vectors and concatenates them into
%   a single column vector.
if isempty(vectorCell)
    allMemberVec = [];
else
    flattened = cellfun(@(v) v(:), vectorCell, 'UniformOutput', false);
    allMemberVec = vertcat(flattened{:});
end
end

function iCheckMemberLength(predictions, labels, scores)
%ICHECKMEMBERLENGTH Verify that corresponding cell array elements have matching sizes
%   This function checks that corresponding elements in the predictions,
%   labels, and scores cell arrays have the same dimensions.
%
%   Inputs:
%       predictions - Cell array of prediction vectors
%       labels      - Cell array of label vectors (can be empty)
%       scores      - Cell array of score vectors (can be empty)
%
%   Throws an error if size mismatch is detected.
hasLabels = ~isempty(labels);
hasScores = ~isempty(scores);

for i = 1:numel(predictions)
    predSize = size(predictions{i});
    if hasLabels && ~isequal(predSize, size(labels{i}))
        error(message('predmaint_anomaly:anomaly:errSizeMismatch', ...
            'predictedLabels', 'groundTruthLabels"'));
    end
    if hasScores && ~isequal(predSize, size(scores{i}))
        error(message('predmaint_anomaly:anomaly:errSizeMismatch', ...
            'predictedLabels', 'anomalyScores'));
    end
end
end

function [predictions, labels, scores] = iCheckNaNValue(predictions, labels, scores)
%ICHECKNANVALUE Remove NaN values from predictions, labels, and scores
%   This function removes entries corresponding to NaN values in scores
%   from all three input arrays to ensure valid calculations.
%
%   Inputs:
%       predictions - Cell array or vector of predictions
%       labels      - Cell array or vector of labels (can be empty)
%       scores      - Cell array or vector of scores
%
%   Outputs:
%       predictions - Cleaned predictions with NaN entries removed
%       labels      - Cleaned labels with NaN entries removed
%       scores      - Cleaned scores with NaN entries removed
%
%   Throws an error if all scores are NaN.
hasLabels = ~isempty(labels);
if iscell(scores)
    for i = 1: numel(scores)
        score = scores{i};
        prediction = predictions{i};
        if hasLabels
            label = labels{i};
        end
        nanrows = isnan(score);
        if all(nanrows)
            error(message('predmaint_anomaly:anomaly:errNoValidPrediction', '"one of scores input cells"'))
        end
        if any(nanrows)
            warning(message('predmaint_anomaly:anomaly:warnHasNaNScore'));
            prediction(nanrows) = [];
            score(nanrows) = [];
            predictions{i} = prediction;
            scores{i} = score;
            if hasLabels
                label(nanrows) = [];
                labels{i} = label;
            end
        end
    end
else
    nanrows = isnan(scores);
    if all(nanrows)
        error(message('predmaint_anomaly:anomaly:errNoValidPrediction', '"scores input vector"'))
    end
    if any(nanrows)
        warning(message('predmaint_anomaly:anomaly:warnHasNaNScore'));
        if hasLabels
            labels(nanrows) = [];
        end
        predictions(nanrows) = [];
        scores(nanrows) = [];
    end
end
end

function logicalLabels = iConvertLabel2Logical(labels, normalClassLabel)
%ICONVERTLABEL2LOGICAL Convert multi-class labels to binary logical labels
%   This function converts multi-class labels to binary logical labels where
%   normal class labels are converted to false (0) and all other labels are
%   converted to true (1).
%
%   Inputs:
%       labels           - Cell array or vector of original class labels
%       normalClassLabel - Vector specifying which labels are considered normal
%
%   Output:
%       logicalLabels    - Cell array or vector of binary logical labels
if iscell(labels)
    logicalLabels = cell(size(labels));
    for i = 1:numel(labels)
        logicalLabels{i} = ~ismember(labels{i}, normalClassLabel);
    end
else
    logicalLabels = ~ismember(labels, normalClassLabel);
end
end

function [normalClassLabel, allLabels] = iConvertLabelSet(labels,normalClassLabel)
%ICONVERTLABELSET Process and validate label sets for anomaly detection
%   This function processes the input labels and normal class labels,
%   ensuring type compatibility and validating that normal class labels
%   are a subset of all labels.It will covert the normalClassLabel into
%   labels data type
%
%   Inputs:
%       labels           - Cell array or vector of original class labels
%       normalClassLabel - Vector specifying which labels are considered normal
%
%   Outputs:
%       normalClassLabel - Processed normal class labels with consistent type
%       allLabels        - Vector of all unique labels in the dataset
%
%   Throws an error if labels contain NaN values or if normalClassLabel
%   partially overlaps with the dataset labels.

% Get all unique labels from the dataset
if iscell(labels)
    labels = iConcatenateCells(labels);
end
allLabels = unique(labels);

% check NaN value in the ground truth
if anymissing(allLabels)
    error(message('predmaint_anomaly:anomaly:errLabelNonNan'))
end

normalClassLabel = unique(normalClassLabel);

% check the ground truth data type
if  ~(isnumeric(allLabels) || isstring(allLabels) || iscategorical(allLabels) || islogical(allLabels))
    error(message('predmaint_anomaly:anomaly:errLabelDataType'));
end

% Ensure the data types of normalClassLabel and allLabels are the same.
% When allLabels are logical or numeric and normalClassLabel is not logical or numeric, set normalClassLabel as NaN to avoid type conversion error 
if islogical(allLabels) || isnumeric(allLabels)
    if ~(isnumeric(normalClassLabel) || islogical(normalClassLabel))
        warning(message('predmaint_anomaly:anomaly:warnNoNormalLabel'));
        normalClassLabel = NaN;
        return
    end
end

if ~isequal(class(normalClassLabel), class(allLabels))
    if isstring(allLabels)
        normalClassLabel = string(normalClassLabel);
    elseif isnumeric(allLabels)
        normalClassLabel = double(normalClassLabel);
    elseif iscategorical(allLabels)
        normalClassLabel = categorical(normalClassLabel);
    end
end

%  Error out if normalClassLabel is partial overlap with allLabels
if any(ismember(normalClassLabel, allLabels)) && any(~ismember(normalClassLabel, allLabels))
    error(message('predmaint_anomaly:anomaly:errLabelNotSubset'));
end

%  Warning if normalClassLabel is not a subset of allLabels
if all(~ismember(normalClassLabel, allLabels))
    warning(message('predmaint_anomaly:anomaly:warnNoNormalLabel'));
end
end


function iMustBeLogical(preds)
%IMUSTBELOGICAL Validate that prediction values are logical or numeric
%   This function validates that all prediction values are logical or
%   numeric vectors with finite, non-NaN values.
%
% g3966034
if ~iscell(preds)
    preds = {preds};
end
for i = 1: numel(preds)
        validateattributes(preds{i}, {'numeric','logical'}, {'vector', 'nonempty', 'real', 'nonsparse','nonnan','finite'}, 'timeSeriesAnomalyMetrics', 'values in PredictedLabel vector or cell');
end
end

function hitTable = iPerClassAnomalyAccuracy(predictions, groundTruthLabels, classLabel, normalClassLabel)
%IPERCLASSANOMALYACCURACY Compute per-class accuracy for anomaly detection
%   This function computes the accuracy of anomaly detection for each class
%   in the dataset, separating normal and anomaly classes.
%
%   Inputs:
%       predictions       - Logical vector of anomaly predictions
%       groundTruthLabels - Vector of original multi-class labels
%       classLabel        - Vector of all possible class labels
%       normalClassLabel  - Vector of labels considered as normal
%
%   Output:
%       hitTable          - Table containing per-class accuracy values
arguments
    predictions (:,1) logical {mustBeNonempty, mustBeFinite}
    groundTruthLabels (:,1) {mustBeNonempty}
    classLabel (:,1) {mustBeVector, mustBeNonempty}
    normalClassLabel (:,1)
end

% Check whether the normalClassLabel and classLabel are disjoint
isDisjoint = all(~ismember(normalClassLabel, classLabel));

if isDisjoint
    allLabels = classLabel;
    anomalyClassLabel = classLabel;
else
    anomalyClassLabel = setdiff(classLabel, normalClassLabel);
    allLabels = [anomalyClassLabel; normalClassLabel];
end

% Initialize tables. When class labels are logical, convert it into
% numerical to ensure
if islogical(allLabels)
    rowNames = string(double(allLabels));
else
    rowNames = string(allLabels);
end
hitTable = table('RowNames', rowNames);

% Compute per-class accuracy for anomaly classes
anomalyAcc = zeros(numel(anomalyClassLabel),1);
for i = 1:numel(anomalyClassLabel)
    cname = anomalyClassLabel(i);
    idx = ismember(groundTruthLabels, cname);
    anomalyAcc(i) = sum(predictions(idx))/ sum(idx); % hit/total
end

if ~isDisjoint
    % Compute per-class accuracy for normal classes
    normalAcc = zeros(numel(normalClassLabel),1);
    for i = 1:numel(normalClassLabel)
        cname = normalClassLabel(i);
        idx = ismember(groundTruthLabels, cname);
        normalAcc(i) = sum(~predictions(idx))/sum(idx); % hit/total
    end

    hitTable.AccuracyPerSubClass = [anomalyAcc;normalAcc];
else
    hitTable.AccuracyPerSubClass = anomalyAcc;

end
end
