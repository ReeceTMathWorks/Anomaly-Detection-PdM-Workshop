classdef ExportDetectors < anomalyAPP.internal.app.AppComponent
    % Export detectors dialog.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = getString(message('predmaint_anomaly:anomaly_app:strExportDetectors'))
        Tag (1,1) string = "export_detectors_dialog"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
    end

    events
        ExportDetectorRequest
    end

    methods
        function obj = ExportDetectors(stateStore, modelStore)
            key = anomalyAPP.internal.app.dialog.ExportDetectors.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.ModelStore = modelStore;

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function delete(obj)
            delete(obj.Widgets.Figure);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            template = table('Size', [0 3], ...
                'VariableNames', {'DetectorName', 'Key', 'isSelected'}, ...
                'VariableTypes', {'string', 'string', 'logical'});
            state = struct('SelectedDetectors', template);
        end

        function reset(obj)
            state = obj.getDefaultState();
            
            % Initialize using the model store
            trainedModels = obj.ModelStore.findTrainedModels();
            sel = true(numel(trainedModels.keys),1);
            state.SelectedDetectors = table(trainedModels.names, trainedModels.keys, sel, 'VariableNames', state.SelectedDetectors.Properties.VariableNames);

            obj.setState(state);
        end

        function update_(obj, ed)
        end

        function render_(obj, ~)
            state = obj.getState();
            obj.Widgets.DetectorsTable.Data = state.SelectedDetectors(:, ...
                ["isSelected","DetectorName"]);

            % Only enable the export button if a detector is selected
            obj.Widgets.ButtonPanel.ExportButton.Enable = any(state.SelectedDetectors.isSelected);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            % Construct the components which will always exist in the
            % dialog.
            weak_obj = matlab.lang.WeakReference(obj);

            fig = uifigure(Visible="off");  % Initialize while not visible
            fig.Name = obj.Title;
            fig.WindowStyle = 'modal';
            fig.Position(3) = 350;
            fig.Position(4) = 350;
            fig.CloseRequestFcn = @(~,~) delete(weak_obj.Handle);

            % There should be a main grid on the figure
            mainLayout = uigridlayout(fig, ...
                'RowHeight', {'fit', 'fit', '1x', 'fit'}, ...
                'ColumnWidth', {'1x', '1x'});

            % Select detectors label
            str = getString(message('predmaint_anomaly:anomaly_app:tipExportSelectedDetectors'));
            selectDetectorsLabel = uilabel(mainLayout, ...
                'Text', str, ...
                'WordWrap', 'on');
            selectDetectorsLabel.Layout.Row = 1;
            selectDetectorsLabel.Layout.Column = [1 2];

            % Select all
            selectAllBtn = uibutton(mainLayout, ...
                Text=string(message('predmaint_anomaly:anomaly_app:strSelectAll')));
            selectAllBtn.Layout.Row = 2;
            selectAllBtn.Layout.Column = 1;
            selectAllBtn.ButtonPushedFcn = @(~,~) cbSelectAll(weak_obj.Handle);

            % Unselect all
            unselectAllBtn = uibutton(mainLayout, ...
                Text=string(message('predmaint_anomaly:anomaly_app:strUnselectAll')));
            unselectAllBtn.Layout.Row = 2;
            unselectAllBtn.Layout.Column = 2;
            unselectAllBtn.ButtonPushedFcn = @(~,~) cbUnselectAll(weak_obj.Handle);

            % Detectors table
            detectorsTable = uitable(mainLayout, ...
                'RowStriping', 'off', ...
                'ColumnName', cell.empty, ...
                'RowName', cell.empty, ...
                'SelectionType', 'row', ...
                'ColumnEditable', [true false], ...
                'ColumnWidth', {'fit', '1x'});
            detectorsTable.Layout.Row = 3;
            detectorsTable.Layout.Column = [1 2];
            detectorsTable.CellEditCallback = @(~,ed) cbDetectorsSelection(weak_obj.Handle, ed);

            % Button panel
            ButtonPanel = controllib.widget.internal.buttonpanel.ButtonPanel(mainLayout, ...
                ["Help" "Export" "Cancel"]);
            ButtonPanel.ButtonWidth = 'fit';
            ButtonContainer = getWidget(ButtonPanel);
            ButtonContainer.Layout.Row = 4;
            ButtonContainer.Layout.Column = [1 2];
            ButtonPanel.HelpButton.Visible = 'off'; % TODO: When help is implemented, enable the help button and update its callback
            ButtonPanel.HelpButton.ButtonPushedFcn = @(~,~) cbHelp(weak_obj.Handle);
            ButtonPanel.HelpButton.Tag = 'export_detectors_dialog_help';
            ButtonPanel.ExportButton.ButtonPushedFcn = @(~,~) cbExport(weak_obj.Handle);
            ButtonPanel.ExportButton.Tag = 'export_detectors_dialog_export';
            ButtonPanel.CancelButton.ButtonPushedFcn = @(~,~) cbCancel(weak_obj.Handle);
            ButtonPanel.CancelButton.Tag = 'export_detectors_dialog_cancel';

            obj.Widgets = struct(...
                'Figure', fig, ...
                'SelectAllButton', selectAllBtn, ...
                'UnselectAllButton', unselectAllBtn, ...
                'DetectorsTable', detectorsTable, ...
                'ButtonPanel', ButtonPanel);
        end

        function cbSelectAll(obj)
            state = obj.getState();
            state.SelectedDetectors.isSelected(:) = true;
            obj.setState(state);
        end

        function cbUnselectAll(obj)
            state = obj.getState();
            state.SelectedDetectors.isSelected(:) = false;
            obj.setState(state);
        end

        function cbCancel(obj)
            % Log a DDUX event for the button click
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.ButtonPanel.CancelButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);

            % Delete the dialog
            delete(obj);
        end

        function cbHelp(obj)
            uialert(obj.Widgets.Figure, 'Help is not implemented yet!', 'Help');
        end

        function cbExport(obj)
            % Make the figure not visible while exporting
            obj.Widgets.Figure.Visible = 'off';

            state = obj.getState();
            keys = state.SelectedDetectors.Key(state.SelectedDetectors.isSelected);
            edata = anomalyAPP.internal.utils.EventData(keys);
            obj.notify('ExportDetectorRequest', edata); % Defer to higher authority.

            % Log a DDUX event for the button click
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.ButtonPanel.ExportButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);

            % Delete the dialog
            delete(obj);
        end

        function cbDetectorsSelection(obj, ed)
            state = obj.getState();
            state.SelectedDetectors.isSelected(ed.Indices(1)) = ed.NewData;
            obj.setState(state);
        end
    end
end