function plotF1Comparison(metricsTable)
%PLOTF1COMPARISON Show shared and tuned F1 scores by detector.

figure(Color="w")
detectorNames = unique(metricsTable.Detector,"stable");
assetNames = unique(metricsTable.Asset,"stable");
nDetectors = numel(detectorNames);

tiledlayout(1,nDetectors,TileSpacing="compact",Padding="compact")
for d = 1:nDetectors
    sharedF1 = localMetricVector(metricsTable,assetNames,detectorNames(d),"Shared");
    tunedF1 = localMetricVector(metricsTable,assetNames,detectorNames(d),"Tuned");

    nexttile
    barSeries = bar([sharedF1, tunedF1]);
    barSeries(1).FaceColor = [0.6 0.6 0.6];
    barSeries(2).FaceColor = [0.2 0.7 0.3];
    grid on
    ylim([0 1])
    set(gca,XTick=1:numel(assetNames),XTickLabel=assetNames,XTickLabelRotation=30)
    ylabel("Point-adjusted F1")
    title(detectorNames(d),Interpreter="none")
    if d == 1
        legend("Shared threshold","Tuned threshold",Location="northwest")
    end
end
sgtitle("Shared detector adapted with per-pump thresholds")
end

function metricValues = localMetricVector(metricsTable, assetNames, detectorName, strategy)

metricValues = NaN(numel(assetNames),1);
for k = 1:numel(assetNames)
    row = metricsTable.Asset == assetNames(k) ...
        & metricsTable.Detector == detectorName ...
        & metricsTable.Strategy == strategy;
    if any(row)
        metricValues(k) = metricsTable.F1Score(find(row,1,"first"));
    end
end
end
