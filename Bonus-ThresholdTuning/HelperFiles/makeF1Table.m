function summaryTable = makeF1Table(metricsTable)
%MAKEF1TABLE Convert shared and tuned metrics into a readable comparison table.

sharedMetrics = metricsTable(metricsTable.Strategy == "Shared",:);
tunedMetrics = metricsTable(metricsTable.Strategy == "Tuned",:);

sharedMetrics = sharedMetrics(:,["Asset","Detector","F1Score","Precision","Recall","FalsePositiveRate","Threshold"]);
tunedMetrics = tunedMetrics(:,["Asset","Detector","F1Score","Precision","Recall","FalsePositiveRate","Threshold"]);

sharedMetrics = renamevars(sharedMetrics, ...
    ["F1Score","Precision","Recall","FalsePositiveRate","Threshold"], ...
    ["SharedF1","SharedPrecision","SharedRecall","SharedFalsePositiveRate","SharedThreshold"]);
tunedMetrics = renamevars(tunedMetrics, ...
    ["F1Score","Precision","Recall","FalsePositiveRate","Threshold"], ...
    ["TunedF1","TunedPrecision","TunedRecall","TunedFalsePositiveRate","TunedThreshold"]);

summaryTable = join(sharedMetrics,tunedMetrics,Keys=["Asset","Detector"]);
summaryTable.F1Improvement = summaryTable.TunedF1 - summaryTable.SharedF1;
summaryTable.FalsePositiveRateChange = ...
    summaryTable.TunedFalsePositiveRate - summaryTable.SharedFalsePositiveRate;

summaryTable = movevars(summaryTable, ...
    ["F1Improvement","FalsePositiveRateChange"],After="TunedF1");
summaryTable = sortrows(summaryTable,["Detector","Asset"]);
end
