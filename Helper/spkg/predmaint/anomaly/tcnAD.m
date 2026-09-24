function detector = tcnAD(NumChannels, options, baseProps)
%   Run "doc tcnAD" for more information.

%   Copyright 2024-2026 The MathWorks, Inc.

arguments
    NumChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.DetectionStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.FilterSize (1,1) double {mustBeInteger, mustBePositive,mustBeVector} = 7
    options.DropoutProbability (1,1) double {mustBeReal, mustBeNonnegative, mustBeLessThan(options.DropoutProbability,1)} = 0.25
    options.DetectionWindowLength (1,1) double {mustBeInteger, mustBePositive} = 10
    options.NumFilters (1,1) double {mustBeReal, mustBeInteger, mustBePositive} = 32
    baseProps.?anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector;
    baseProps.ThresholdMethod string {mustBeMember(baseProps.ThresholdMethod, ["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}  = "kSigma"
    baseProps.Normalization string {mustBeMember(baseProps.Normalization, ["off", "zscore", "range"])}  = "zscore"
    baseProps.Threshold (1,1) double
    baseProps.ThresholdParameter (1, 1) double
    baseProps.ThresholdFunction
end
try
    detector = anomalyCLI.deepanomaly.TcnDetector(NumChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end
