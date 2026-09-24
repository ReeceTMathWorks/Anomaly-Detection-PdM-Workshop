classdef DataStore < handle
    % Manages the storage of DL and ML data and their metadata.
    %
    % Data changes are relayed to observers with event data containing:
    %   Name: Label (key) of the data,
    %   Data.Status: One of 'Added', 'Removed', or 'Changed'.

    % Copyright 2025 The MathWorks, Inc.

    properties
        MetaData (1,1) dictionary = configureDictionary("string", "struct")
        DataBackend (1,1) predmaint.internal.backend.DataBackend
    end

    properties (Access = private, Constant = true)
        IndexVarName = "IndexVariable__"
    end

    events
        DataChanged
        DataMemberAdded
    end

    methods
        function obj = DataStore()
            obj.DataBackend = predmaint.internal.backend.DataBackend();
        end

        function delete(obj)
            %disp('DataStore is being deleted.');
        end

        function s = serialize(obj)
            % Only the MetaData gets serialized. The DataBackend is not
            % serialized, as it will be saved by exporting to .MLDATX and
            % restored by importing from the .MLDATX file.
            s = struct('MetaData', obj.MetaData);
        end

        function deserialize(obj, s)
            % Only the MetaData was serialized. The DataBackend should be
            % restored by importing from a .MLDATX file.
            obj.MetaData = s.MetaData;
        end
    end

    methods(Static)
        function tf = validateSerializedState(s)
            % The serialized state must be a struct containing a MetaData
            % field. The MetaData field should be a dictionary of
            % string->struct.
            tf = false;
            if isstruct(s) && isfield(s, 'MetaData') && isa(s.MetaData, "dictionary")
                [kType, vType] = types(s.MetaData);
                tf = kType == "string" && vType == "struct";
            end
        end
    end

    % Data management
    methods
        function addData(obj, key, metadata, data, labels)
            arguments
                obj
                key (1,1) string
                metadata struct
                data {mustBeValidData(data)}
                labels = []
            end

            if ~iscell(data)
                data = {data}; % Put it in a cell so the rest of the code can reliably assume a cell array
            end
            data = data(:); % Make sure it is a vertical cell array

            if ~isKey(obj.MetaData, key)
                weak_obj = matlab.lang.WeakReference(obj);
                L = event.listener(obj.DataBackend, 'MemberAppended', @(~,ed)notify(weak_obj.Handle, 'DataMemberAdded', ed));
                try
                    % Create the dataset
                    obj.MetaData(key) = metadata;

                    if isnumeric(data{1})
                        % For matrix, use the channel names provided by the metadata
                        varNames = metadata.ChannelNames;

                        % Define an index variable counting the data points in each member
                        I = cellfun(@(x)(1:height(x))',data,'UniformOutput',false);
                    else
                        varNames = data{1}.Properties.VariableNames;

                        % If the data has time, construct a timetable for each member
                        % with the time and index. Separate out the numeric data values.
                        [I, data] = cellfun(@splitTimeAndData, data, 'UniformOutput', false);
                    end

                    % We want to create a cell matrix to pass to the backend. Each
                    % row will be a member and there will be a column each  for
                    % data, index, labels
                    data = [I data];
                    varNames = vertcat(obj.IndexVarName, varNames(:));
                    if ~isempty(labels)
                        if ~iscell(labels)
                            if ~istabular(labels)
                                labels = labels(:); % Make sure it is a vertical array
                            end
                            labels = {labels};
                        end
                        data = [data labels(:)];
                        varNames = vertcat(varNames, string(metadata.LabelVariable));
                    end

                    % Add the data to the backend
                    obj.DataBackend.createDataset(key, data, TableRowMethod="point", VariableNames=varNames);
                catch E
                    % Adding the data set failed. Clean up and rethrow the error.
                    obj.removeData(key);
                    delete(L);
                    rethrow(E)
                end
                delete(L);
            else
                error(message('predmaint_anomaly:anomaly_app:errDataStoreKeyExists', key))
            end

            ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Added'));
            obj.notify('DataChanged', ed);
        end

        function removeData(obj, key)
            if isKey(obj.MetaData, key)
                obj.MetaData(key) = []; % Removes from dictionary
                obj.DataBackend.deleteDataset(key); % Delete the data from the backend
            else
                error(message('predmaint_anomaly:anomaly_app:errDataStoreKeyNotFound', key));
            end

            ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Removed'));
            obj.notify('DataChanged', ed);
        end

        function [metadata, time, labels, data] = getData(obj, key, options)
            arguments
                obj
                key
                options.Member int32 = int32.empty
            end

            if ~isKey(obj.MetaData, key)
                error(message('predmaint_anomaly:anomaly_app:errDataStoreKeyNotFound', key));
            end

            % If no member was specified, get all of them
            if isempty(options.Member)
                options.Member = 1:obj.DataBackend.getNumMembers(key);
            end

            % Get the metadata
            metadata = obj.MetaData(key);

            % Set default outputs for time, labels, data
            time = cell(numel(options.Member), 1);
            labels = cell(numel(options.Member), 1);
            data = cell(numel(options.Member), 1);

            % If more than one output, get the time
            if nargout > 1
                if ~isempty(metadata)
                    time = obj.DataBackend.readData(obj.IndexVarName, Dataset=key, MemberIndex=options.Member, OutputFormat="ensemble");
                    time = time{:,:}; % Extract the data from the table that is returned
                    if istimetable(time{1})
                        % If there was time, then the index var will be a
                        % timetable. Just extract the time dimension
                        time = cellfun(@(x)x.(x.Properties.DimensionNames{1}), time, 'UniformOutput', false);
                    end

                    % If more than two outputs, get the labels
                    if nargout > 2
                        if metadata.LabelIndex ~= 0
                            labels = obj.DataBackend.readData(metadata.LabelVariable, Dataset=key, MemberIndex=options.Member, OutputFormat="ensemble");
                            if ~isempty(labels)
                                labels = labels{:,:};
                                if istimetable(labels{1})
                                    labels = cellfun(@(x)x.(x.Properties.VariableNames{1}), labels, 'UniformOutput', false);
                                end
                            end
                        end

                        % If more than three outputs, get the data
                        if nargout > 3
                            data_table = obj.DataBackend.readData(metadata.ChannelNames, Dataset=key, MemberIndex=options.Member, OutputFormat="ensemble");
                            data_combined = rowfun(@convertDataTable, data_table, OutputVariableNames="Data_Combined");
                            data = data_combined{:,:};
                        end
                    end
                end
            end
        end

        function setData(obj, key, metadata, data, labels)
            arguments
                obj
                key
                metadata
                data = []
                labels = []
            end
            if ~isKey(obj.MetaData, key)
                error(message('predmaint_anomaly:anomaly_app:errDataStoreKeyNotFound', key));
            end

            if isempty(data) && isempty(labels)
                % The user has only provided metadata. Check the existing metadata
                % and update it
                existingMetaData = obj.getData(key);
                dirty = ~isequal(existingMetaData, metadata);
                if dirty
                    obj.MetaData(key) = metadata;
                    ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Changed'));
                    obj.notify('DataChanged', ed);
                end
            elseif isempty(metadata)
                % The user is trying to set data without passing metadata. Error
                error(message('predmaint_anomaly:anomaly_app:errSetDataWithoutMetadata'))
            elseif isempty(data)
                % The user is trying to set labels without passing data. Error
                error(message('predmaint_anomaly:anomaly_app:errSetLabelsWithoutData'))
            else
                % The user has provided metadata, data, and labels. We must
                % check all to see if they are dirty and update them.
                [existingMetaData, existingTime, existingLabels, existingData] = obj.getData(key);

                % If labels exist but were not provided, error
                if ~isempty(existingLabels{1}) && isempty(labels)
                    error(message('predmaint_anomaly:anomaly_app:errSetLabeledDataWithoutLabels'))
                end

                % If the number of members is different, than remove the data set
                % and add a new one.
                if existingMetaData.Members ~= metadata.Members
                    try
                        obj.removeData(key);
                        obj.addData(key, metadata, data, labels);
                    catch E
                        % If something fails, restore the previous data
                        if ~isKey(obj.MetaData, key)
                            if ~isnumeric(existingTime{1})
                                % Data has time. Update the data to be a timetable
                                % before adding it back
                                for i = 1:numel(existingTime)
                                    existingData{i} = array2timetable(existingData{i}, RowTimes=existingTime{i}, VariableNames=existingMetaData.ChannelNames);
                                end
                            end
                            if ~isempty(existingLabels{1})
                                obj.addData(key, existingMetaData, existingData, existingLabels);
                            else
                                obj.addData(key, existingMetaData, existingData);
                            end
                        end
                        if ~isempty(E.identifier)
                            error(message(E.identifier))
                        else
                            rethrow(E)
                        end
                    end
                    return
                end

                % Update the metadata
                dirtyMetaData = ~isequal(existingMetaData, metadata);
                if dirtyMetaData
                    obj.MetaData(key) = metadata;
                end

                % Update the data
                dirtyData = ~isempty(data);
                if dirtyData
                    if ~iscell(data)
                        data = {data}; % Put it in a cell so the rest of the code can reliably assume a cell array
                    end
                    data = data(:); % Make sure it is a vertical cell array
                    if ~isempty(data)
                        if ~isnumeric(data{1})
                            varNames = data{1}.Properties.VariableNames;

                            % If the data has time, construct a timetable for each member
                            % with the time and index. Separate out the numeric data values.
                            [I, data] = cellfun(@splitTimeAndData, data, 'UniformOutput', false);

                            dirtyTime = ~isequal(cellfun(@(x)x.(x.Properties.DimensionNames{1}), I, 'UniformOutput', false), existingTime);
                        else
                            varNames = metadata.ChannelNames;

                            % Define an index variable counting the data points in each member
                            I = cellfun(@(x)(1:height(x))',data,'UniformOutput',false);
                            dirtyTime = ~isequal(I, existingTime);
                        end
                        dirtyData = dirtyTime || ~isequal(data, existingData);
                        if dirtyData
                            % For the backend, delete the data without removing the dataset.
                            % Then add the new data to the dataset.
                            obj.DataBackend.deleteData(metadata.ChannelNames, Dataset=key);
                            obj.DataBackend.appendData(data, Dataset=key, VariableNames=varNames);

                            % Delete the time and add the new time
                            obj.DataBackend.deleteData(obj.IndexVarName, Dataset=key);
                            obj.DataBackend.appendData(I, Dataset=key, VariableNames=obj.IndexVarName);
                        end
                    end
                end

                % Update the labels
                dirtyLabels = ~isempty(labels);
                if dirtyLabels
                    if ~iscell(labels)
                        labels = {labels}; % Put it in a cell so the rest of the code can reliably assume a cell array
                    end
                    labels = labels(:); % Make sure it is a vertical cell array
                    if istimetable(labels{1})
                        labels = cellfun(@(x)x.(x.Properties.VariableNames{1}), labels, 'UniformOutput', false);
                    end
                    dirtyLabels = ~isequal(labels, existingLabels);
                    if dirtyLabels
                        % For the backend, delete the labels without removing the dataset.
                        % Then add the new labels to the dataset.
                        obj.DataBackend.deleteData(metadata.LabelVariable, Dataset=key);
                        obj.DataBackend.appendData(labels, Dataset=key, VariableNames=metadata.LabelVariable);
                    end
                end

                % Notify observers if there were real changes to either the
                % metadata, the data, or the labels
                if dirtyMetaData || dirtyData || dirtyLabels
                    ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Changed'));
                    obj.notify('DataChanged', ed);
                end
            end
        end
    end

    % Convenience methods
    methods
        function names = getDataNames(obj)
            % Returns a struct with fields 'keys' and 'names', assuming all DL/ML data have a 'Name' property.
            keys = obj.MetaData.keys;
            names = struct( ...
                'keys', keys, ...
                'names', arrayfun(@(key) string(obj.MetaData(key).Name), keys));
        end

        function flag = hasData(obj)
            flag = ~isempty(obj.MetaData.keys);
        end

        function names = findTrainingData(obj)
            info = obj.getDataNames();
            I = arrayfun(@(key) obj.MetaData(key).isTrainingData, info.keys);
            names = struct('keys', info.keys(I), 'names', info.names(I));
        end

        function names = findLabeledData(obj)
            info = obj.getDataNames();
            I = arrayfun(@(key) obj.MetaData(key).LabelIndex ~= 0, info.keys);
            names = struct('keys', info.keys(I), 'names', info.names(I));
        end
    end
end

%% Utility functions
function mustBeValidData(data)
    % Validate that data is a matrix, timetable, cell array of matrices, or
    % cell array of timetables
    if iscell(data)
        isvalidcell = cellfun(@isValidMemberData, data);
        if ~all(isvalidcell)
            error(message('predmaint_anomaly:anomaly_app:errInvalidDataCell'))
        end
    elseif isempty(data)
        error(message('predmaint_anomaly:anomaly_app:errEmptyData'))
    elseif ~isValidMemberData(data)
        error(message('predmaint_anomaly:anomaly_app:errInvalidData'))
    end
end

function valid = isValidMemberData(memData)
    valid = (isnumeric(memData) || istimetable(memData)) && ~isempty(memData);
end

function data = convertDataTable(varargin)
    data = horzcat(varargin{:}); % Extract the matrices out from varargin. Will yield a cell array where each cell directly holds the matrix.
    data = {horzcat(data{:})}; % Combine the channels into a single matrix
end

function [timeOut, dataOut] = splitTimeAndData(data)
    I = (1:height(data))';
    timeOut = timetable(data.(data.Properties.DimensionNames{1}), I, VariableNames="Index");
    dataOut = data{:,:};
end