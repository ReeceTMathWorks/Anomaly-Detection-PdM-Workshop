classdef (ConstructOnLoad) EventData < event.EventData
    % Manages event data associated with event notifications.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties
        Name (1,:) string
        Data (1,1) struct
    end

    methods
        function obj = EventData(name, data)
            arguments
                name (1,:) string
                data (1,1) struct = struct
            end
            obj.Name = name;
            obj.Data = data;
        end
    end
end
