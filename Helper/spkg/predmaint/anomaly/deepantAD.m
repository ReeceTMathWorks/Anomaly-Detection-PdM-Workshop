function detector = deepantAD(NumChannels, options, baseProps)
%   Run "doc deepantAD" for more information.

%   Copyright 2024-2026 The MathWorks, Inc.

% References:
%   M. Munir, S. A. Siddiqui, A. Dengel and S. Ahmed, "DeepAnT: A Deep
%   Learning Approach for Unsupervised Anomaly Detection in Time Series,"
%       in IEEE Access, vol. 7, pp. 1991-2005, 2019, doi:
%       10.1109/ACCESS.2018.2886457.
%
arguments
    NumChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.DetectionStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.ObservationWindowLength (1,1) double {mustBeInteger, mustBePositive} = 10
    options.DetectionWindowLength (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 5
    options.FilterSize (1,2) {mustBeInteger, mustBePositive, mustBeVector, mustBeFinite} = [2, 3]
    options.DropoutProbability (1,1) double {mustBeReal, mustBeNonnegative, mustBeLessThan(options.DropoutProbability,1)} = 0.25
    options.TrainingStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1
    options.NumFilters (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 32
    baseProps.?anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector;
    baseProps.ThresholdMethod string {mustBeMember(baseProps.ThresholdMethod, ["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}  = "kSigma"
    baseProps.Normalization string {mustBeMember(baseProps.Normalization, ["off", "zscore", "range"])}  = "zscore"
    baseProps.Threshold (1,1) double
    baseProps.ThresholdParameter (1, 1) double
    baseProps.ThresholdFunction
end
try
    detector = anomalyCLI.deepanomaly.DeepantDetector(NumChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end
