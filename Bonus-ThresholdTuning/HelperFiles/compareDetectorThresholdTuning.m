function [metricsTable, comparisonTable, summaryTable, bestAbsoluteDetector, mostImprovedByTuning] = ...
    compareDetectorThresholdTuning(detectors, trainData, assetIdx, testData, testLabels, assetNames, detectorNames)
%COMPAREDETECTORTHRESHOLDTUNING Summarize optional multi-detector tuning results.

sharedMetrics = evaluateDetectorSet(detectors,trainData,assetIdx,testData,testLabels,false, ...
    AssetNames=assetNames,DetectorNames=detectorNames);
tunedMetrics = evaluateDetectorSet(detectors,trainData,assetIdx,testData,testLabels,true, ...
    AssetNames=assetNames,DetectorNames=detectorNames);

metricsTable = [sharedMetrics; tunedMetrics];
comparisonTable = makeF1Table(metricsTable);

detectorsInTable = unique(comparisonTable.Detector,"stable");
nDetectors = numel(detectorsInTable);
meanSharedF1 = zeros(nDetectors,1);
meanTunedF1 = zeros(nDetectors,1);
meanF1Improvement = zeros(nDetectors,1);
meanTunedFalsePositiveRate = zeros(nDetectors,1);

for d = 1:nDetectors
    detectorRows = comparisonTable.Detector == detectorsInTable(d);
    meanSharedF1(d) = mean(comparisonTable.SharedF1(detectorRows),"omitnan");
    meanTunedF1(d) = mean(comparisonTable.TunedF1(detectorRows),"omitnan");
    meanF1Improvement(d) = mean(comparisonTable.F1Improvement(detectorRows),"omitnan");
    meanTunedFalsePositiveRate(d) = mean(comparisonTable.TunedFalsePositiveRate(detectorRows),"omitnan");
end

summaryTable = table(detectorsInTable,meanSharedF1,meanTunedF1, ...
    meanF1Improvement,meanTunedFalsePositiveRate, ...
    VariableNames=["Detector","MeanSharedF1","MeanTunedF1", ...
    "MeanF1Improvement","MeanTunedFalsePositiveRate"]);

[~,bestAbsoluteIdx] = max(summaryTable.MeanTunedF1);
[~,mostImprovedIdx] = max(summaryTable.MeanF1Improvement);
bestAbsoluteDetector = summaryTable.Detector(bestAbsoluteIdx);
mostImprovedByTuning = summaryTable.Detector(mostImprovedIdx);
end
