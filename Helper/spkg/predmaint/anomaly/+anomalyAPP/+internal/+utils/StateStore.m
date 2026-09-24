classdef StateStore < handle
    % Manages the storage of state data for the app and its view components.
    %
    % State changes are relayed to observers with event data containing:
    %   Name: Label (key) of the state.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties
        State (1,1) dictionary = configureDictionary("string", "struct")
    end

    events
        StateChanged
    end

    % Lifecycle management
    methods
        function obj = StateStore()
        end

        function delete(~)
            %disp('StateStore is being deleted.');
        end

        function s = serialize(obj)
            s = struct('State', obj.State);
        end

        function deserialize(obj, s)
            % Preserve states registered by active components that are not present
            % in the saved session (forward-compatibility).
            currentKeys = keys(obj.State);
            savedKeys = keys(s.State);
            missingKeys = setdiff(currentKeys, savedKeys);

            currentState = obj.State;
            obj.State = s.State;

            for i = 1:numel(missingKeys)
                obj.State(missingKeys(i)) = currentState(missingKeys(i));
            end
        end
    end

    methods(Static)
        function tf = validateSerializedState(s)
            % The serialized state must be a struct containing a State
            % field. The State field should be a dictionary of
            % string->struct.
            tf = false;
            if isstruct(s) && isfield(s, 'State') && isa(s.State, "dictionary")
                [kType, vType] = types(s.State);
                tf = kType == "string" && vType == "struct";
            end
        end
    end

    % State management
    methods
        function registerState(obj, key)
            if ~isKey(obj.State, key)
                obj.State(key) = struct;
            else
                error("The state '%s' is already registered.\n", key);
            end
        end

        function dirty = setState(obj, key, state)
            if ~isKey(obj.State, key)
                error("The state '%s' does not exist. Register it first.\n", key);
            end

            dirty = ~isequaln(obj.State(key), state);
            if dirty
                %fprintf('Setting state: %s\n', key);
                obj.State(key) = state;
            end
        end

        function state = getState(obj, key)
            state = obj.State(key); % Errors out if key does not exist.
        end

        function removeState(obj, key)
            %fprintf('Removing state: %s\n', key);
            obj.State(key) = []; % Remove state from dictionary, if it exists.
        end

        function flag = hasState(obj, key)
            flag = isKey(obj.State, key); % Check if a state has been registered.
        end
    end
end
