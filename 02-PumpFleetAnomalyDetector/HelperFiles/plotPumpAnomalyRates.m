function plotPumpAnomalyRates(anomalyRates, assetNames)
%PLOTPUMPANOMALYRATES Bar chart of labeled anomaly rates by asset.
bar(anomalyRates, FaceColor=[0.2 0.5 0.8])
grid on
set(gca,XTick=1:numel(assetNames),XTickLabel=assetNames,XTickLabelRotation=45)
ylabel("Anomaly rate (%)")
title("Ground-truth anomaly rate by pump asset")
end
