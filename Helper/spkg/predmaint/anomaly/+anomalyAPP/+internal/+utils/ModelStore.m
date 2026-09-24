classdef ModelStore < handle
    % Manages the storage of DL and ML models and their metadata.
    %
    % Model changes are relayed to observers with event data containing:
    %   Name: Label (key) of the model,
    %   Data.Status: One of 'Added', 'Removed', or 'Changed'.

    % Copyright 2025 The MathWorks, Inc.

    properties (Access = private)
        Model (1,1) dictionary = configureDictionary("string", "struct")
    end

    events
        ModelChanged
    end

    % Lifecycle management
    methods
        function obj = ModelStore()
        end

        function delete(~)
            %disp('ModelStore is being deleted.');
        end

        function s = serialize(obj)
            s = struct('Model', obj.Model);
        end

        function deserialize(obj, s)
            obj.Model = s.Model;
        end
    end

    methods(Static)
        function tf = validateSerializedState(s)
            % The serialized state must be a struct containing a Model
            % field. The Model field should be a dictionary of
            % string->struct.
            tf = false;
            if isstruct(s) && isfield(s, 'Model') && isa(s.Model, "dictionary")
                [kType, vType] = types(s.Model);
                tf = kType == "string" && vType == "struct";
            end
        end
    end

    % Model management
    methods
        function addModel(obj, keys, models)
            arguments
                obj
                keys (1,:) string
                models (1,:) struct
            end
            for k = 1:numel(keys)
                if ~isKey(obj.Model, keys(k))
                    obj.Model(keys(k)) = models(k);
                else
                    error("The model '%s' already exists.\n", keys(k));
                end
            end

            ed = anomalyAPP.internal.utils.EventData(keys, struct('Status', 'Added'));
            obj.notify('ModelChanged', ed);
        end

        function setModel(obj, key, model)
            if ~isKey(obj.Model, key)
                error("The model '%s' does not exist. Add the model first.\n", key);
            end

            dirty = ~isequaln(obj.Model(key), model);
            if dirty
                %fprintf('Setting model: %s\n', model.Name);
                obj.Model(key) = model;

                ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Changed'));
                obj.notify('ModelChanged', ed);
            end
        end

        function model = getModel(obj, key)
            model = obj.Model(key); % Errors out if key does not exist.
        end

        function removeModel(obj, keys)
            arguments
                obj
                keys (1,:) string % Supports multiple model removal
            end
            for iK = 1:numel(keys)
                if ~isempty(obj.Model(keys(iK)))
                    %fprintf('Removing model: %s\n', obj.Model(key).Name);
                end
                obj.Model(keys(iK)) = []; % Remove model from dictionary, if it exists.
            end

            ed = anomalyAPP.internal.utils.EventData(keys, struct('Status', 'Removed'));
            obj.notify('ModelChanged', ed);
        end

        function newKey = duplicateModel(obj, key)
            assert(~ischar(key));
            newKey = matlab.lang.internal.uuid(size(key));
            for i = 1:numel(key)
                model = obj.getModel(key(i));
                model.Name = obj.makeUniqueModelName(model.Name);
                obj.Model(newKey(i)) = model;
            end

            ed = anomalyAPP.internal.utils.EventData(newKey, struct('Status', 'Added'));
            obj.notify('ModelChanged', ed);
        end
    end

    % Convenience methods
    methods
        function names = getModelNames(obj)
            % Returns a struct with fields 'keys' and 'names', assuming all DL/ML models have a 'Name' property.
            keys = obj.Model.keys;
            names = struct( ...
                'keys', keys, ...
                'names', arrayfun(@(key) string(obj.Model(key).Name), keys));
            if isempty(names.names)
                names.names = string.empty(); % Make sure it is a string array that is returned
            end
        end

        function flag = hasModels(obj)
            flag = ~isempty(obj.Model.keys);
        end

        function names = findTrainedModels(obj)
            % Returns a struct with fields 'keys' and 'names' for all trained model.
            info = obj.getModelNames();
            I = arrayfun(@(key) ~isempty(obj.Model(key).TrainingTimestamp), info.keys);
            names = struct('keys', info.keys(I), 'names', info.names(I));
        end

        function uniqueName = makeUniqueModelName(obj, origName)
            info = obj.getModelNames();
            namesNoSpaces = replace(info.names, " ", "_"); % If we don't remove spaces, then makeUniqueStrings will always append "_1". Change all spaces to underscores to compare.
            origNameNoSpaces = replace(origName, " ", "_");
            uniqueNameNoSpaces = matlab.lang.makeUniqueStrings(origNameNoSpaces, namesNoSpaces);
            uniqueName = replace(uniqueNameNoSpaces, "_", " ");
            % In case the original name had underscores to begin with,
            % replace the first n chars with the original name, where n is
            % the length of the original name
            uniqueName = replaceBetween(uniqueName, 1, strlength(origName), origName);
        end
    end
end
