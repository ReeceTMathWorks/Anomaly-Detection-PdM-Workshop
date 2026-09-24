function detector = usAD(NumChannels, options, baseProps)
%   Run "doc usAD" for more information.

%   Copyright 2024-2026 The MathWorks, Inc.

arguments
    NumChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.DetectionStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.ObservationWindowLength (1,1) double {mustBeInteger,mustBePositive} = 24
    options.Alpha (1,1) {double, mustBeGreaterThanOrEqual(options.Alpha,0), mustBeLessThanOrEqual(options.Alpha,1)} = 0.7
    options.Beta (1,1) {double, mustBeGreaterThanOrEqual(options.Beta,0), mustBeLessThanOrEqual(options.Beta,1)} = 0.3
    options.TrainingStride (1,1) double {mustBeInteger, mustBePositive} 
    options.LatentSpaceDim (1,1) double { mustBeInteger, mustBePositive} = 32
    baseProps.?anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector;
    baseProps.ThresholdMethod string {mustBeMember(baseProps.ThresholdMethod, ["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}  = "kSigma"
    baseProps.Normalization string {mustBeMember(baseProps.Normalization, ["off", "zscore", "range"])}  = "zscore"
    baseProps.Threshold (1,1) double
    baseProps.ThresholdParameter (1, 1) double
    baseProps.ThresholdFunction
end
try
    detector = anomalyCLI.deepanomaly.UsadDetector.UsadDetector(NumChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end
