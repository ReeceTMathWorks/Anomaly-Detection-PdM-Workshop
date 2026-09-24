classdef Plot < anomalyAPP.internal.app.AppComponent
    % Plot document.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = string(message('predmaint_anomaly:anomaly_app:strPlot'))
        Tag (1,1) string = "plot_document"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataSetKey = string.empty % Since each plot document only ever shows one data set, store the key as a property of the document
        DataStore anomalyAPP.internal.utils.DataStore
        DataStoreListener event.listener
    end

    methods
        function obj = Plot(stateStore, dataStore, key)
            tag = anomalyAPP.internal.app.document.Plot.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(tag + "-" + key, stateStore);

            weakObj = matlab.lang.WeakReference(obj);
            obj.DataSetKey = key;
            obj.DataStore = dataStore;
            obj.DataStoreListener = listener(dataStore, 'DataChanged', @(~,ed) cbDataChanged(weakObj.Handle,ed));

            % Initialize view components after construction.
            createComponents(obj, key);
            reset(obj);
        end

        function panel = getFigureDocument(obj)
            panel = obj.Widgets.FigureDocument;
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(obj)
            template = table('Size', [0 2], ...
                'VariableNames', {'IsSelected', 'Channel'}, ...
                'VariableTypes', {'logical', 'string'});

            state = struct(...
                'DataSetKey', obj.DataSetKey, ...
                'DataSetName', string.empty, ...
                'CurrentMember', 1, ...
                'NormalizationMethod', 'off', ...
                'ChannelsTable', template, ...
                'HasLabels', true, ...
                'ShowLabeledAnomalies', true);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Update the state for the data set key
            dataKeys = obj.DataStore.getDataNames().keys;
            if ~isempty(state.DataSetKey) && ismember(state.DataSetKey, dataKeys)
                metadata = obj.DataStore.getData(state.DataSetKey);
                channelsTbl = table(true(size(metadata.ChannelNames)), metadata.ChannelNames, ...
                    'VariableNames', state.ChannelsTable.Properties.VariableNames);
                state.ChannelsTable = channelsTbl;
                state.DataSetName = metadata.Name;
                state.HasLabels = metadata.LabelIndex ~= 0;
                state.ShowLabeledAnomalies = state.HasLabels;
            end

            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "plot_options_panel")
                otherState = obj.getState(ed.Name);

                state = obj.getState();
                if obj.DataSetKey == otherState.DataSetKey
                    state.ChannelsTable = otherState.ChannelsTable;
                    state.ShowLabeledAnomalies = otherState.ShowLabeledAnomalies;
                    obj.setState(state);
                end
            end

            if (ed.Name == "plot_tab")
                otherState = obj.getState(ed.Name);

                state = obj.getState();
                if obj.DataSetKey == otherState.DataSetKey
                    state.CurrentMember = otherState.CurrentMember;
                    state.NormalizationMethod = otherState.NormalizationMethod;
                    obj.setState(state);
                end
            end
        end

        function render_(obj, ~)
            state = obj.getState();

            if isempty(obj.DataSetKey) || ~ismember(obj.DataSetKey, obj.DataStore.getDataNames().keys)
                % Nothing to render
                return
            end

            member = state.CurrentMember;
            [metadata, time, labels, data] = obj.DataStore.getData(obj.DataSetKey, Member=member);

            % Only one member.
            time = time{1};
            labels = labels{1};
            data = data{1};

            if isempty(data) || (~any(state.ChannelsTable.IsSelected) && ~state.ShowLabeledAnomalies)
                cla(obj.Widgets.UIAxes);
                legend(obj.Widgets.UIAxes, 'off');
            else
                if ~strcmp(state.NormalizationMethod, 'off')
                    nData = normalize(data, state.NormalizationMethod);
                else
                    nData = data;
                end
                nData = nData(:, state.ChannelsTable.IsSelected);
                channelNames = metadata.ChannelNames(state.ChannelsTable.IsSelected);

                if ~state.ShowLabeledAnomalies
                    labels = [];
                end

                anomalyCLI.internal.utils.AnomalyDetection.plotAnomalies(...
                    obj.Widgets.UIAxes, nData, channelNames, ...
                    TrueLabels=labels, Time=time);
            end

            % Replace title and add subtitle.
            name = metadata.Name;
            title(obj.Widgets.UIAxes, name, 'Interpreter', 'none');
            subtitleStr = string(message('predmaint_anomaly:anomaly_app:strMemberXOfY', ...
                member, metadata.Members));
            subtitle(obj.Widgets.UIAxes, subtitleStr);

            % Update document tab.
            str = sprintf("%s: %s", anomalyAPP.internal.app.document.Plot.Title, name);
            description = string(message('predmaint_anomaly:anomaly_app:strPlotDocumentDescription', name));
            obj.Widgets.FigureDocument.Title = str;
            obj.Widgets.FigureDocument.Description = description;
        end
    end

    % Event management
    methods (Access = private)
        function cbDataChanged(obj, ed)
            key = ed.Name;

            if ed.Data.Status == "Changed"
                % Needs to update only if the selected data has changed.
                if (key == obj.DataSetKey)
                    reset(obj);
                end
            end
        end
    end

    methods (Access = private)
        function createComponents(obj, name)
            weak_obj = matlab.lang.WeakReference(obj);

            % Figure Document
            plotOptions.Tag = sprintf("%s-%s", obj.Tag, name);
            plotOptions.Closable = true;
            fd = matlab.ui.internal.FigureDocument(plotOptions);
            addlistener(fd, 'ObjectBeingDestroyed', @(~,~) delete(weak_obj.Handle));

            % Layout
            layout = uigridlayout(fd.Figure);
            layout.RowHeight = {'1x'};
            layout.ColumnWidth = {'1x'};
            ax1 = uiaxes(layout, Box='on', ClippingStyle='rectangle');
            %disableDefaultInteractivity(ax1); % Require explicit use of axis toolbar.

            obj.Widgets = struct( ...
                'FigureDocument', fd, ...
                'UIAxes', ax1);
        end
    end
end
