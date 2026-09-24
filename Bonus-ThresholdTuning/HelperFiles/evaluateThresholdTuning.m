function resultsTable = evaluateThresholdTuning(sharedDetector, trainData, assetIdx, testData, testLabels, assetNames)
%EVALUATETHRESHOLDTUNING Compare shared and per-asset tuned thresholds.

nAssets = numel(assetNames);
sharedThreshold = zeros(nAssets,1);
tunedThreshold = zeros(nAssets,1);
sharedF1 = zeros(nAssets,1);
tunedF1 = zeros(nAssets,1);
sharedFalsePositiveRate = zeros(nAssets,1);
tunedFalsePositiveRate = zeros(nAssets,1);

for k = 1:nAssets
    tunedDetector = updateDetector(sharedDetector,trainData{assetIdx(k)});

    sharedResult = detect(sharedDetector,testData{k},Resolution="sample");
    tunedResult = detect(tunedDetector,testData{k},Resolution="sample");
    labels = logical(testLabels{k});

    sharedMetrics = timeSeriesAnomalyMetrics(sharedResult.Labels,labels, ...
        Method="point-adjusted");
    tunedMetrics = timeSeriesAnomalyMetrics(tunedResult.Labels,labels, ...
        Method="point-adjusted");

    sharedThreshold(k) = sharedDetector.Threshold;
    tunedThreshold(k) = tunedDetector.Threshold;
    sharedF1(k) = sharedMetrics.F1Score;
    tunedF1(k) = tunedMetrics.F1Score;
    sharedFalsePositiveRate(k) = sharedMetrics.FalsePositiveRate;
    tunedFalsePositiveRate(k) = tunedMetrics.FalsePositiveRate;
end

resultsTable = table(assetNames(:),sharedThreshold,tunedThreshold,sharedF1,tunedF1, ...
    tunedF1 - sharedF1,sharedFalsePositiveRate,tunedFalsePositiveRate, ...
    VariableNames=["Asset","SharedThreshold","TunedThreshold","SharedF1","TunedF1", ...
    "F1Improvement","SharedFalsePositiveRate","TunedFalsePositiveRate"]);
end
