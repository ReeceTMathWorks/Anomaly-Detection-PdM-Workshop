function detector = vaelstmAD(NumChannels, options, baseProps)
%   Run "doc vaelstmAD" for more information.

%   Copyright 2024-2026 The MathWorks, Inc.

% References:
%   S. Lin, R. Clark, R. Birke, S. Schönborn, N. Trigoni and S. Roberts,
%   "Anomaly Detection for Time Series Using VAE-LSTM Hybrid Model," ICASSP
%   2020 - 2020 IEEE International Conference on Acoustics, Speech and
%   Signal Processing (ICASSP), Barcelona, Spain, 2020, pp. 4322-4326, doi:
%   10.1109/ICASSP40776.2020.9053558.
arguments
    NumChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.DetectionStride (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.ObservationWindowLength (1,1) double {mustBeInteger, mustBePositive} = 100
    options.DetectionWindowLength (1,1) double {mustBeInteger, mustBePositive} = 10
    options.NumDownsampleLayers (1,1) double {mustBeInteger, mustBePositive} = 2;
    options.FilterSize (1,:) double {mustBeInteger,mustBePositive, mustBeVector} = 5;
    options.NumFilters (1,:) double {mustBeInteger,mustBePositive, mustBeVector} = 32;
    options.DropoutProbability(1,1) double {mustBeReal,mustBeNonnegative, mustBeLessThan(options.DropoutProbability,1)} = 0.25;
    options.LatentSpaceDim (1,1) double {mustBeInteger,mustBePositive} = 5;
    options.NumHiddenUnits double {mustBeInteger,mustBePositive,mustBeVector} = [16,16];
    options.TrainingStride (1, 1) double {mustBeInteger, mustBePositive, mustBeFinite} = 1;
    baseProps.?anomalyCLI.internal.deepanomaly.AbstractDeepAnomalyDetector;
    baseProps.ThresholdMethod string {mustBeMember(baseProps.ThresholdMethod, ["mean", "median", "max", "contaminationFraction", "manual", "customFunction", "kSigma"])}  = "kSigma"
    baseProps.Normalization string {mustBeMember(baseProps.Normalization, ["off", "zscore", "range"])}  = "zscore"
    baseProps.Threshold (1,1) double
    baseProps.ThresholdParameter (1, 1) double
    baseProps.ThresholdFunction
end
try
    detector = anomalyCLI.deepanomaly.VaelstmDetector.VaelstmDetector(NumChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end
