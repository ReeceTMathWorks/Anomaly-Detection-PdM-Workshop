function plotPumpTestOverview(testDataM, testLabelsM, assetName, channelIdx)
%PLOTPUMPTESTOVERVIEW Plot selected channels with ground-truth anomaly shading.
channelNames = string(testDataM.Properties.VariableNames(channelIdx));
regions = localFindRegions(logical(testLabelsM));
tVec = (1:height(testDataM))';
tiledlayout(numel(channelIdx),1,TileSpacing="compact",Padding="compact")
for k = 1:numel(channelIdx)
    ax = nexttile;
    plot(tVec,testDataM{:,channelIdx(k)},Color=[0.2 0.4 0.7],LineWidth=0.8)
    hold on
    yLimits = ylim;
    for r = 1:size(regions,1)
        xPatch = [regions(r,1) regions(r,2) regions(r,2) regions(r,1)];
        yPatch = [yLimits(1) yLimits(1) yLimits(2) yLimits(2)];
        patch(xPatch,yPatch,[0.9 0.3 0.2],FaceAlpha=0.22,EdgeColor="none")
    end
    ylabel(channelNames(k))
    grid on
    if k < numel(channelIdx)
        ax.XTickLabel = [];
    end
end
xlabel("Sample index (minutes)")
sgtitle(assetName + " test telemetry with labeled anomaly regions")
end
function regions = localFindRegions(binaryLabel)
d = diff([false; binaryLabel(:); false]);
starts = find(d == 1);
ends = find(d == -1) - 1;
regions = [starts, ends];
end
