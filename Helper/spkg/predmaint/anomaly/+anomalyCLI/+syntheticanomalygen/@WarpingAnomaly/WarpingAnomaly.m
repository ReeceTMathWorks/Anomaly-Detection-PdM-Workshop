classdef WarpingAnomaly < anomalyCLI.syntheticanomalygen.AbstractAnomaly
% WarpingAnomaly class defines the Warp anomaly type and
% handles the injection of the anomaly into the specified time series.

%   Copyright 2025-2026 The MathWorks, Inc.

    properties (SetAccess=private)
        Type (1,1) string {mustBeMember(Type, "Magnitude")} = "Magnitude"
    end

    properties
        Algorithm (1,1) string {mustBeMember(Algorithm, ["GPR", "Spline"])} = "GPR"
        Scale (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 1
    end

    methods
        function obj = WarpingAnomaly(NameValueArgs)
            arguments
                NameValueArgs.Algorithm (1,1) string {mustBeMember(NameValueArgs.Algorithm, ["GPR", "Spline"])} = "GPR"
                NameValueArgs.Scale (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 1
            end

            obj.Algorithm = NameValueArgs.Algorithm;
            obj.Scale = NameValueArgs.Scale;
        end
    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, inTS, windowStart, windowEnd, windowLength, labels)

            % Compute the random curve for warping using the selected
            % algorithm
            if obj.Algorithm == "GPR"
                magCurve = anomalyCLI.syntheticanomalygen.utils.gprCurve(windowLength, obj.Scale);
            else
                magCurve = anomalyCLI.syntheticanomalygen.utils.cubicSplineCurve(windowLength, obj.Scale);
            end
            % Inject magnitude warp
            outTS(windowStart:windowEnd) = inTS(windowStart:windowEnd).*magCurve;
            
            % Create labels vector
            labels(windowStart:windowEnd) = true;
        end
    end
end
