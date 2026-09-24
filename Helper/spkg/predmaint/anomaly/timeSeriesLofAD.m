function detector = timeSeriesLofAD(numChannels, options, baseProps)
%   Run "doc timeSeriesLofAD" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    numChannels (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
    options.NumNeighbors (1,1) double {mustBeReal, mustBeInteger, mustBePositive} 
    options.Distance (1,1) string {mustBeMember(options.Distance, ["euclidean","fasteuclidean","cityblock","chebychev","minkowski","mahalanobis","cosine","correlation","spearman"])} = "euclidean"
    options.BucketSize (1,1) double {mustBePositive, mustBeInteger} = 50
    options.CacheSize {mustBeA(options.CacheSize, ["string", "double", "single", "char", "string"]), iValidateCacheSize(options.CacheSize)} = 1000
    options.Cov double
    options.Exponent (1,1)  double {mustBePositive}
    options.IncludeTies (1,1) logical = false
    options.SearchMethod (1,1) string {mustBeMember(options.SearchMethod, ["kdtree","exhaustive"])} 
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
    detector = anomalyCLI.mlanomaly.TimeSeriesLOFDetector(numChannels, options, baseProps);
catch E
    throwAsCaller(E)
end
end

function iValidateCacheSize(x)
%CACHESIZE is a numeric value specifying the size of cache in megabytes (MB) or a string of value "maximal",

if ischar(x) || isstring(x)
    if ~strcmpi(x, "maximal")
        error(message('predmaint_anomaly:anomaly:errInvalidCacheSize'));
    end
elseif ~isscalar(x) || ~isfloat(x) || x<=0 || isnan(x) || ~isreal(x)
    error(message('predmaint_anomaly:anomaly:errInvalidCacheSize'));
end
end
