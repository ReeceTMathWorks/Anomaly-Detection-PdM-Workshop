function detector = timeSeriesIforestAD(numChannels, options, baseProps)
%   Run "doc timeSeriesIforestAD" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    numChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.NumLearners (1,1) double {mustBeReal, mustBeInteger, mustBePositive} = 100
    options.NumObservationsPerLearner double {mustBeReal, mustBeInteger, mustBePositive, mustBeGreaterThanOrEqual(options.NumObservationsPerLearner, 3)} = []
    baseProps.?anomalyCLI.internal.mlanomaly.AbstractMachineLearningAnomalyDetector;
    baseProps.WindowLength (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 10
    baseProps.TrainingStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
    baseProps.DetectionStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    baseProps.FeatureExtraction (1,1) logical = true
    baseProps.Threshold = [];
    baseProps.ThresholdMethod (1,1) string {mustBeMember(baseProps.ThresholdMethod,["contaminationFraction","manual","customFunction","mean","median","max", "kSigma"])} = "kSigma"
    baseProps.ThresholdParameter (1,1) double = 3;
    baseProps.ThresholdFunction = [];
    baseProps.Normalization (1,1) string {mustBeMember(baseProps.Normalization,["off","zscore","range"])} ="zscore";
end
try
    detector = anomalyCLI.mlanomaly.TimeSeriesIForestDetector(numChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end
