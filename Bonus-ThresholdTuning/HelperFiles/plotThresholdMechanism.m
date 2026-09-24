function plotThresholdMechanism(sharedDetector, normalAssetData, testAssetData, testLabels, assetName, detectorName)
%PLOTTHRESHOLDMECHANISM Show how per-pump threshold tuning changes detections.

figure(Color="w")
tunedDetector = updateDetector(sharedDetector,normalAssetData);

sharedResult = detect(sharedDetector,testAssetData,Resolution="sample");
tunedResult = detect(tunedDetector,testAssetData,Resolution="sample");

tiledlayout(2,1,TileSpacing="compact",Padding="compact")
localPlotScores(sharedResult,tunedResult,logical(testLabels), ...
    localDetectorThreshold(sharedDetector),localDetectorThreshold(tunedDetector))
localPlotPredictionBands(sharedResult,tunedResult,logical(testLabels))
sgtitle(assetName + " score threshold adaptation: " + detectorName,Interpreter="none")
end

function localPlotScores(sharedResult, tunedResult, testLabels, sharedThreshold, tunedThreshold)

sampleIndex = localSampleIndex(sharedResult);
scores = sharedResult.AnomalyScores;
sharedLabels = logical(sharedResult.Labels);
tunedLabels = logical(tunedResult.Labels);
newlyPredicted = tunedLabels & ~sharedLabels;
clearedPredictions = sharedLabels & ~tunedLabels;
actualLabels = testLabels(sampleIndex);

ax = nexttile;
plot(ax,sampleIndex,scores,Color=[0.12 0.28 0.52],LineWidth=0.9,HandleVisibility="off")
hold(ax,"on")
grid(ax,"on")
yLimits = ylim(ax);
localDrawRegions(ax,localFindRegions(actualLabels,sampleIndex),yLimits)
plot(ax,sampleIndex,scores,Color=[0.12 0.28 0.52],LineWidth=0.9,DisplayName="Anomaly score")

if any(newlyPredicted)
    scatter(ax,sampleIndex(newlyPredicted),scores(newlyPredicted),18,[0.85 0.05 0.05], ...
        "filled",DisplayName="Newly flagged after tuning")
end

if any(clearedPredictions)
    scatter(ax,sampleIndex(clearedPredictions),scores(clearedPredictions),18,[0.2 0.45 0.85], ...
        "filled",DisplayName="Cleared after tuning")
end

if isfinite(sharedThreshold)
    yline(ax,sharedThreshold,"--",Color=[0.15 0.15 0.15],LineWidth=1.1,DisplayName="Shared threshold")
end

if isfinite(tunedThreshold)
    yline(ax,tunedThreshold,"-",Color=[0.1 0.55 0.2],LineWidth=1.1,DisplayName="Tuned threshold")
end

ylabel(ax,"Score")
title(ax,"Score changes near the tuned threshold",Interpreter="none")
legend(ax,Location="northwest")
end

function localPlotPredictionBands(sharedResult, tunedResult, testLabels)

sampleIndex = localSampleIndex(sharedResult);
actualLabels = testLabels(sampleIndex);
sharedLabels = logical(sharedResult.Labels);
tunedLabels = logical(tunedResult.Labels);
newlyPredicted = tunedLabels & ~sharedLabels;

ax = nexttile;
hold(ax,"on")
grid(ax,"on")
localDrawBand(ax,localFindRegions(actualLabels,sampleIndex),3,[0.95 0.55 0.18],"Actual anomaly")
localDrawBand(ax,localFindRegions(sharedLabels,sampleIndex),2,[0.55 0.55 0.55],"Shared prediction")
localDrawBand(ax,localFindRegions(tunedLabels,sampleIndex),1,[0.2 0.7 0.3],"Tuned prediction")
localDrawBand(ax,localFindRegions(newlyPredicted,sampleIndex),0,[0.85 0.05 0.05],"Newly flagged")
xlim(ax,[sampleIndex(1), sampleIndex(end)])
ylim(ax,[-0.5 3.5])
yticks(ax,0:3)
yticklabels(ax,["Newly flagged","Tuned","Shared","Actual"])
xlabel(ax,"Sample index")
title(ax,"Prediction regions before and after threshold tuning",Interpreter="none")
legend(ax,Location="eastoutside")
end

function sampleIndex = localSampleIndex(result)

if ismember("StartIndices",string(result.Properties.VariableNames))
    sampleIndex = result.StartIndices;
else
    sampleIndex = (1:height(result))';
end
end

function regions = localFindRegions(labels, sampleIndex)

labels = labels(:);
sampleIndex = sampleIndex(:);
edge = diff([false; labels; false]);
startPosition = find(edge == 1);
endPosition = find(edge == -1) - 1;
regions = [sampleIndex(startPosition), sampleIndex(endPosition)];
end

function localDrawRegions(ax, regions, yLimits)

for k = 1:size(regions,1)
    xRegion = [regions(k,1), regions(k,2), regions(k,2), regions(k,1)];
    yRegion = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
    visibility = "off";
    if k == 1
        visibility = "on";
    end
    patch(ax,xRegion,yRegion,[0.95 0.55 0.18],FaceAlpha=0.18,EdgeColor="none", ...
        DisplayName="Actual anomaly",HandleVisibility=visibility)
end
end

function localDrawBand(ax, regions, yCenter, color, displayName)

for k = 1:size(regions,1)
    xRegion = [regions(k,1), regions(k,2), regions(k,2), regions(k,1)];
    yRegion = [yCenter - 0.28, yCenter - 0.28, yCenter + 0.28, yCenter + 0.28];
    visibility = "off";
    if k == 1
        visibility = "on";
    end
    patch(ax,xRegion,yRegion,color,FaceAlpha=0.72,EdgeColor="none", ...
        DisplayName=displayName,HandleVisibility=visibility)
end
end

function threshold = localDetectorThreshold(detector)

if isprop(detector,"Threshold")
    threshold = detector.Threshold;
else
    threshold = NaN;
end
end
