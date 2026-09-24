classdef StuckAtConstantAnomaly < anomalyCLI.syntheticanomalygen.AbstractAnomaly
% StuckAtConstantAnomaly class defines the StuckAtAnomaly type and
% handles the injection of the anomaly into the specified time series.

%   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Type can Random, Min, Max, Custom
        Type(1,1) string {mustBeMember(Type, ["Random", "Max", "Min", "Custom"])} = "Random"
        % Value to be used for Type=Custom
        Value (1,1) {mustBeNumeric}
    end

    methods
        function obj = StuckAtConstantAnomaly(NameValueArgs)
            % Example MATLAB code to introduce bias into a portion of a time series
            arguments
                NameValueArgs.Type (1,1) string {mustBeMember(NameValueArgs.Type, ["Random", "Max", "Min", "Custom"])} = "Random"
                NameValueArgs.Value (1,1) {mustBeNumeric} = NaN;                
            end

            validateTypeValue(NameValueArgs)

            obj.Type = NameValueArgs.Type;
            obj.Value = NameValueArgs.Value;            
        end
    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, ~, windowStart, windowEnd, ~, labels)

            % Inject the "stuck at constant" anomaly
            if obj.Type == "Custom"                    
                outTS(windowStart:windowEnd) = obj.Value;
            elseif obj.Type == "Max"
                outTS(windowStart:windowEnd) = max(outTS(windowStart:windowEnd));
            elseif obj.Type == "Min"
                outTS(windowStart:windowEnd) = min(outTS(windowStart:windowEnd));
            elseif obj.Type == "Random"
                idx = randi([windowStart, windowEnd]);
                outTS(windowStart:windowEnd) = outTS(idx);
            end
            % Create label vector
            labels(windowStart:windowEnd) = true;
        end
    end
end


% Helper function
function validateTypeValue(NameValueArgs)
% Validate that Value is not specified when Type is not Custom
if NameValueArgs.Type == "Custom" && isnan(NameValueArgs.Value)
    error(message("predmaint_anomaly:anomaly:errStuckAtNVCombo"))
elseif ~isnan(NameValueArgs.Value) && ~(NameValueArgs.Type == "Custom")    
    error(message("predmaint_anomaly:anomaly:errStuckAtNVCombo"))
end
end
