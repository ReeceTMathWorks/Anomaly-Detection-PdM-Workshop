function anomalyType =  syntheticAnomaly(AnomalyType, varargin)
%   Run "doc syntheticAnomaly" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    AnomalyType (1,1) string {mustBeMember(AnomalyType, ["Noise", "Bias", "Drift", "StuckAtConstant", "PointOutliers", "Warp"])} = "Noise"; 
end

arguments(Repeating)
    varargin
end

switch AnomalyType
    case "Noise"
        anomalyType = anomalyCLI.syntheticanomalygen.NoiseAnomaly(varargin{:});
    case "Bias"
        anomalyType = anomalyCLI.syntheticanomalygen.BiasAnomaly(varargin{:});
    case "Drift"
        anomalyType = anomalyCLI.syntheticanomalygen.DriftAnomaly(varargin{:});
    case "StuckAtConstant"
        anomalyType = anomalyCLI.syntheticanomalygen.StuckAtConstantAnomaly(varargin{:});
    case "PointOutliers"
        anomalyType = anomalyCLI.syntheticanomalygen.PointOutliersAnomaly(varargin{:});
    case "Warp"
        anomalyType = anomalyCLI.syntheticanomalygen.WarpingAnomaly(varargin{:});
    otherwise
        anomalyType = anomalyCLI.syntheticanomalygen.NoiseAnomaly(varargin{:});
end
end
