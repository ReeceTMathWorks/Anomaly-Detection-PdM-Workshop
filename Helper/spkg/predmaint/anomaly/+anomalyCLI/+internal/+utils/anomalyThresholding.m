function thres = anomalyThresholding(scores, thresholdMethod, thresholdParameter, thresholdFunction)
switch thresholdMethod
    case 'max'
        thres = thresholdParameter*max(scores);
    case 'mean'
        thres = thresholdParameter*mean(scores);
    case 'median'
        thres = thresholdParameter*median(scores);
    case 'contaminationFraction'
        thres = quantile(scores, 1-thresholdParameter);
    case 'kSigma'
        thres = thresholdParameter * std(scores)  + mean(scores);
    case 'customFunction'
        thres = thresholdFunction(scores);
end
end
