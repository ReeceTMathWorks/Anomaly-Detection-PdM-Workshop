classdef DriftAnomaly < anomalyCLI.syntheticanomalygen.AbstractAnomaly
    % DriftAnomaly class defines the drift anomaly type and handles the
    % injection of the anomaly into the specified time series.

    %   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Drift can be either Linear, quadratic or exponential
        Type (1,1) string {mustBeMember(Type, ["Linear","Exponential","Quadratic"])}= "Linear"
        % Defines the rate of drift
        Scale (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 1;
    end

    methods
        function obj = DriftAnomaly(NameValueArgs)
            arguments
                NameValueArgs.Type (1,1) string {mustBeMember(NameValueArgs.Type, ["Linear","Exponential","Quadratic"])}= "Linear"
                NameValueArgs.Scale (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 1
            end

            obj.Type = NameValueArgs.Type;
            obj.Scale = NameValueArgs.Scale;
        end
    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, ~, windowStart, windowEnd, windowLength, labels)

            driftVector = linspace(0, 1, windowLength);
            % Inject the anomaly
            switch lower(obj.Type)
                case "linear"
                    drift = driftVector*obj.Scale;
                    outTS(windowStart:windowEnd) = outTS(windowStart:windowEnd)+drift(:);
                case "quadratic"
                    drift = (driftVector).^2 * obj.Scale;
                    outTS(windowStart:windowEnd) = outTS(windowStart:windowEnd)+drift(:);
                case "exponential"
                    drift = exp(driftVector* obj.Scale) ;
                    outTS(windowStart:windowEnd) = outTS(windowStart:windowEnd).*drift(:);
            end
            % Create the labels vector
            labels(windowStart:windowEnd) = true;
        end
    end
end
