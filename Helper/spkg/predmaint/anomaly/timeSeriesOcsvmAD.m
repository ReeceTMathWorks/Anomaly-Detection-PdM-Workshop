function detector = timeSeriesOcsvmAD(numChannels, options, baseProps)
%   Run "doc timeSeriesOcsvmAD" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    numChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.BlockSize (1,1) double {mustBePositive} = 4e3
    options.KernelScale {mustBeA(options.KernelScale, ["string", "double", "single", "char"]), iValidateKernel(options.KernelScale)} = 1
    options.Lambda {mustBeA(options.Lambda, ["string", "double", "single", "char"]), iValidateLambda(options.Lambda)} = "auto"
    options.NumExpansionDimensions {mustBeA(options.NumExpansionDimensions, ["string", "double", "single", "char"]), iValidateDimensions(options.NumExpansionDimensions)} = "auto"
    options.BetaTolerance (1,1) double {mustBeNonnegative} = 1e-4
    options.GradientTolerance (1,1) double {mustBeNonnegative} = 1e-6
    options.IterationLimit double {mustBePositive, mustBeInteger} = []
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
    detector = anomalyCLI.mlanomaly.TimeSeriesOCSVMDetector(numChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end



%% Local functions
function iValidateLambda(x)
%Lambda is "auto" or a nonnegative scalar.
if ischar(x) || isstring(x)
    if ~strcmpi(x, "auto")
    error(message('predmaint_anomaly:anomaly:errInvalidLambda'));
    end
elseif ~isscalar(x) || ~isfloat(x) || x<0 || isnan(x) || ~isreal(x)
    error(message('predmaint_anomaly:anomaly:errInvalidLambda'));
end
end

function iValidateDimensions(x)
%NumExpansionDimensions is "auto" or a nonnegative integer scalar.
if ischar(x) || isstring(x)
    if ~strcmpi(x, "auto")
    error(message('predmaint_anomaly:anomaly:errInvalidDimension'));
    end
elseif ~isscalar(x) || ~(mod(x,1)==0) || x<=0 || isnan(x) || ~isreal(x)
    error(message('predmaint_anomaly:anomaly:errInvalidDimension'));
end
end


function iValidateKernel(x)
%KernelScale is "auto" or a positive scalar.
if ischar(x) || isstring(x)
    if ~strcmpi(x, "auto")
        error(message('predmaint_anomaly:anomaly:errInvalidKernel'));
    end
elseif ~isscalar(x) || ~(mod(x,1)==0) || x<=0 || isnan(x) || ~isreal(x)
    error(message('predmaint_anomaly:anomaly:errInvalidKernel'));
end
end
