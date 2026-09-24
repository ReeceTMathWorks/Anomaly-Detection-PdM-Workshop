classdef BiasAnomaly < anomalyCLI.syntheticanomalygen.AbstractAnomaly
% BiasAnomaly class defines the Bias anomaly type and handles the
% injection of the anomaly into the specified time series.

%   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Type is Constant or Proportional
        Type (1,1) string {mustBeMember(Type, ["Constant", "Proportional"])} = "Constant"
        % Value to use for defining the bias being introduced
        Offset (1,1)
    end

    methods
        function obj = BiasAnomaly(NameValueArgs)
            arguments
                NameValueArgs.Type (1,1) string {mustBeMember(NameValueArgs.Type, ["Constant", "Proportional"])} = "Constant";
                NameValueArgs.Offset (1,1) {validateOffset(NameValueArgs.Offset)} = "Default";                
            end

            obj.Type = NameValueArgs.Type;
            obj.Offset = NameValueArgs.Offset;            
        end
    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, inTS, windowStart, windowEnd, windowLength, labels) %#ok<INUSD>

            winSegment = inTS(windowStart:windowEnd);
            if obj.Type == "Constant"
                if isstring(obj.Offset)
                    obj.Offset = 2*std(winSegment);
                end
                % Add constant offset
                outTS(windowStart:windowEnd) = winSegment + obj.Offset;
            elseif obj.Type == "Proportional"    
                if isstring(obj.Offset)
                    obj.Offset = 0.2;
                end
                % Inject proportional offset into the specified portion of the signal
                outTS(windowStart:windowEnd) = winSegment * (1 + obj.Offset);
            end
            % Create labels vector
            labels(windowStart:windowEnd) = true;
        end
    end
end

function validateOffset(Offset)
if isstring(Offset)
    if Offset ~= "Default"
        error('Only string value allowed is "Default".')
    end
elseif isnumeric(Offset)
    validateattributes(Offset, {'numeric'}, {'finite', 'nonnan'});
end
end
