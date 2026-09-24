function metricsTable = evaluateDetectorSet(detectors, trainData, assetIdx, testData, testLabels, tuneThresholds, options)
%EVALUATEDETECTORSET Compute point-adjusted metrics for detectors and assets.

arguments
    detectors
    trainData
    assetIdx
    testData
    testLabels
    tuneThresholds (1,1) logical
    options.AssetNames string = strings(0,1)
    options.DetectorNames string = strings(0,1)
end

nAssets = numel(testData);
nDetectors = numel(detectors);
nRows = nAssets*nDetectors;

assetNames = string(options.AssetNames(:));
if numel(assetNames) ~= nAssets
    assetNames = "Asset " + string((1:nAssets)');
end

detectorNames = string(options.DetectorNames(:));
if numel(detectorNames) ~= nDetectors
    detectorNames = "Detector " + string((1:nDetectors)');
end

strategy = "Shared";
if tuneThresholds
    strategy = "Tuned";
end

asset = strings(nRows,1);
detectorName = strings(nRows,1);
strategyName = strings(nRows,1);
f1Score = zeros(nRows,1);
precision = zeros(nRows,1);
recall = zeros(nRows,1);
falsePositiveRate = zeros(nRows,1);
threshold = zeros(nRows,1);

precisionWarningState = warning("off","predmaint_anomaly:anomaly:warnPrecisionSetToZero");
cleanupWarning = onCleanup(@() warning(precisionWarningState));

row = 0;
for d = 1:nDetectors
    for k = 1:nAssets
        row = row + 1;
        evaluatedDetector = detectors{d};
        if tuneThresholds
            evaluatedDetector = updateDetector(evaluatedDetector,trainData{assetIdx(k)});
        end

        result = detect(evaluatedDetector,testData{k},Resolution="sample");
        metrics = timeSeriesAnomalyMetrics(result.Labels,logical(testLabels{k}),Method="point-adjusted");

        asset(row) = assetNames(k);
        detectorName(row) = detectorNames(d);
        strategyName(row) = strategy;
        f1Score(row) = metrics.F1Score;
        precision(row) = metrics.Precision;
        recall(row) = metrics.Recall;
        falsePositiveRate(row) = metrics.FalsePositiveRate;
        threshold(row) = localDetectorThreshold(evaluatedDetector);
    end
end

metricsTable = table(asset,detectorName,strategyName,f1Score,precision,recall,falsePositiveRate,threshold, ...
    VariableNames=["Asset","Detector","Strategy","F1Score","Precision","Recall","FalsePositiveRate","Threshold"]);
end

function threshold = localDetectorThreshold(detector)

if isprop(detector,"Threshold")
    threshold = detector.Threshold;
else
    threshold = NaN;
end
end
