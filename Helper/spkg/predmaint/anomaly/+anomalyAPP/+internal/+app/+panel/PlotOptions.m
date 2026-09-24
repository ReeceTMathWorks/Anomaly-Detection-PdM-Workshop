classdef PlotOptions < anomalyAPP.internal.app.AppComponent
    % Plot options panel.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = string(message('predmaint_anomaly:anomaly_app:strPlotOptions'))
        Tag (1,1) string = "plot_options_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataStore anomalyAPP.internal.utils.DataStore
    end

    methods
        function obj = PlotOptions(stateStore, dataStore)
            key = anomalyAPP.internal.app.panel.PlotOptions.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.DataStore = dataStore;

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function panel = getFigurePanel(obj)
            panel = obj.Widgets.FigurePanel;
        end

        function syncWithDocument(obj, plotTag)
            state = obj.getState();
            otherState = obj.getState(plotTag);

            state.ChannelsTable = otherState.ChannelsTable;
            state.HasLabels = otherState.HasLabels;
            state.ShowLabeledAnomalies = otherState.ShowLabeledAnomalies;
            state.DataSetKey = otherState.DataSetKey;
            state.DataSetName = otherState.DataSetName;

            obj.setState(state)
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            template = table('Size', [0 2], 'VariableNames', {'IsSelected', 'Channel'}, 'VariableTypes', {'logical', 'string'});
            state = struct(...
                'ChannelsTable', template, ...
                'HasLabels', true, ...
                'ShowLabeledAnomalies', true, ...
                'DataSetKey', string.empty, ...
                'DataSetName', string.empty);
        end

        function reset(obj)
            state = obj.getDefaultState();
            obj.setState(state);
        end

        function update_(obj, ed)
        end

        function render_(obj, ~)
            state = obj.getState();
            if ~isempty(state.DataSetName)
                obj.Widgets.HeaderMessage.Text = string(message('predmaint_anomaly:anomaly_app:strSelectChannelsToView', state.DataSetName));
            end
            obj.Widgets.ChannelTable.Data = state.ChannelsTable;
            obj.Widgets.ShowLabelsCheckbox.Value = state.ShowLabeledAnomalies;
            obj.Widgets.ShowLabelsCheckbox.Enable = state.HasLabels;
        end
    end

    % Event management
    methods (Access = private)
        function cbCellEditFcn(obj, ed)
            state = obj.getState();
            state.ChannelsTable.IsSelected(ed.Indices(1)) = ed.NewData;
            obj.setState(state);

            % Log a DDUX event for the button
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CELL_EDIT, ... % event type
                matlab.ddux.internal.ElementType.TABLE, ... % element type
                obj.Widgets.ChannelTable.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);
        end

        function cbSelectAllBtn(obj)
            state = obj.getState();
            state.ChannelsTable.IsSelected(:) = true;
            obj.setState(state);

            % Log a DDUX event for the button
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.SelectAllButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);
        end

        function cbUnselectAllBtn(obj)
            state = obj.getState();
            state.ChannelsTable.IsSelected(:) = false;
            obj.setState(state);

            % Log a DDUX event for the button
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.UnselectAllButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);
        end

        function cbShowLabelsCbox(obj, ed)
            state = obj.getState();
            state.ShowLabeledAnomalies = ed.Value;
            obj.setState(state);

            % Log a DDUX event for the button
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.SELECTION_CHANGED, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.ShowLabelsCheckbox.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            weak_obj = matlab.lang.WeakReference(obj);

            % Construct the FigurePanel
            plotPanelOptions.Title = obj.Title;
            plotPanelOptions.Tag = obj.Tag;
            plotPanelOptions.Region = "right";
            fp = matlab.ui.internal.FigurePanel(plotPanelOptions);
            fp.Contextual = true;

            % Grid layout
            layout = uigridlayout(fp.Figure);
            layout.RowHeight = {'fit', 'fit', '1x', 'fit'};
            layout.ColumnWidth = {'1x', '1x'};

            % Context message
            msg = uilabel(layout, "Text", "");
            msg.WordWrap = 'on';
            msg.Layout.Row = 1;
            msg.Layout.Column = [1 2];

            % Select all
            str = string(message('predmaint_anomaly:anomaly_app:strSelectAll'));
            selectAllBtn = uibutton(layout, "Text", str);
            selectAllBtn.Tag = 'plot_panel_select_all';
            selectAllBtn.Layout.Row = 2;
            selectAllBtn.Layout.Column = 1;
            selectAllBtn.ButtonPushedFcn = @(~,~)cbSelectAllBtn(weak_obj.Handle);

            % Unselect all
            str = string(message('predmaint_anomaly:anomaly_app:strUnselectAll'));
            unselectAllBtn = uibutton(layout, "Text", str);
            unselectAllBtn.Tag = 'plot_panel_unselect_all';
            unselectAllBtn.Layout.Row = 2;
            unselectAllBtn.Layout.Column = 2;
            unselectAllBtn.ButtonPushedFcn = @(~,~)cbUnselectAllBtn(weak_obj.Handle);

            % Channel selection table
            channelTbl = uitable(layout);
            channelTbl.Tag = 'plot_panel_channels';
            channelTbl.Layout.Row = 3;
            channelTbl.Layout.Column = [1 2];
            channelTbl.Multiselect = 'off';
            channelTbl.ColumnEditable = [true, false];
            channelTbl.ColumnName = {[], getString(message('predmaint_anomaly:anomaly_app:strChannelHeader'))};
            channelTbl.ColumnWidth = {'fit', '1x'};
            channelTbl.CellEditCallback = @(~, ed)cbCellEditFcn(weak_obj.Handle, ed);

            % Show labels
            showLblCbox = uicheckbox(layout, ...
                "Text", string(message('predmaint_anomaly:anomaly_app:strShowLabeledAnomalies')));
            showLblCbox.Tag = 'plot_panel_show_labels';
            showLblCbox.Layout.Row = 4;
            showLblCbox.Layout.Column = [1 2];
            showLblCbox.ValueChangedFcn = @(~, ed)cbShowLabelsCbox(weak_obj.Handle, ed);

            obj.Widgets = struct(...
                'FigurePanel', fp, ...
                'HeaderMessage', msg, ...
                'SelectAllButton', selectAllBtn, ...
                'UnselectAllButton', unselectAllBtn, ...
                'ChannelTable', channelTbl, ...
                'ShowLabelsCheckbox', showLblCbox);
        end
    end
end
