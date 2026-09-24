function plotPumpAutocorrelation(trainData, assetIdx, assetNames, maxLag)
%PLOTPUMPAUTOCORRELATION Plot short-range autocorrelation for selected assets.
nPlots = numel(assetIdx);
tiledlayout(1,nPlots,TileSpacing="compact",Padding="compact")
for i = 1:nPlots
    nexttile
    sig = trainData{assetIdx(i)}{:,1};
    sig = sig - mean(sig,"omitmissing");
    [acf,lags] = xcorr(sig,maxLag,"normalized");
    lags = lags(maxLag+1:end);
    acf = acf(maxLag+1:end);
    stem(lags,acf,"filled",MarkerSize=2,LineWidth=0.5)
    grid on
    xlabel("Lag (minutes)")
    ylabel("ACF")
    title(assetNames{i})
    ylim([-0.6 1])
end
sgtitle("Autocorrelation of normal pump training data")
end
