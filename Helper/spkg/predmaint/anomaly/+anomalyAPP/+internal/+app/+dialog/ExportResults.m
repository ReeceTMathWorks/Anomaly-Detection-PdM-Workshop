classdef ExportResults < anomalyAPP.internal.app.AppComponent
    % Export results dialog.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = getString(message('predmaint_anomaly:anomaly_app:strExportResults'))
        Tag (1,1) string = "export_results_dialog"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        DataStore anomalyAPP.internal.utils.DataStore
    end

    properties (Access = private, Constant)
        DetectorsTableTemplate = table('Size', [0 3], ...
            'VariableNames', {'DetectorName', 'Key', 'isSelected'}, ...
            'VariableTypes', {'string', 'string', 'logical'})
    end

    events
        ExportResultsRequest
    end

    methods
        function obj = ExportResults(stateStore, modelStore, dataStore, dataKey, modelKey)
            key = anomalyAPP.internal.app.dialog.ExportResults.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.ModelStore = modelStore;
            obj.DataStore = dataStore;

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
            obj.setDataAndModel(dataKey, modelKey);
        end

        function delete(obj)
            delete(obj.Widgets.Figure);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(obj)
            state = struct('SelectedData', string.empty, ...
                'SelectedModel', string.empty, ...
                'DetectorsTable', obj.DetectorsTableTemplate, ...
                'LabelResolution', "sample", ...
                'IncludeGroundTruth', true);
        end

        function reset(obj)
            state = obj.getDefaultState();
            obj.setState(state);
        end

        function update_(obj, ed)
        end

        function render_(obj, ~)
            state = obj.getState();

            % Update the data set label
            if ~isempty(state.SelectedData)
                metadata = obj.DataStore.getData(state.SelectedData);
                obj.Widgets.DataValue.Text = metadata.Name;
            end

            % Update the detectors table
            obj.Widgets.DetectorsTable.Data = state.DetectorsTable(:, ...
                ["isSelected","DetectorName"]);

            % Update the label resolution
            if strcmp(state.LabelResolution, "sample")
                btn = obj.Widgets.SampleButton;
            else
                btn = obj.Widgets.WindowButton;
            end
            obj.Widgets.ResolutionButtonGroup.SelectedObject = btn;

            % Update the checkbox for including ground truth labels. If
            % there is not a selected data set or the data set is not
            % labeled, disable the checkbox.
            obj.Widgets.IncludeGroundTruthCheckbox.Value = state.IncludeGroundTruth;
            obj.Widgets.IncludeGroundTruthCheckbox.Enable = ~isempty(state.SelectedData) && metadata.LabelIndex ~= 0;

            % Update the figure size depending on whether the detector
            % selection table is required. If there is a selected model,
            % then the table should be hidden.
            if isempty(state.SelectedModel)
                obj.Widgets.Figure.Position(4) = 410;
                obj.Widgets.ContentLayout.RowHeight(2:4) = {'fit', 60, '1x'};
            else
                obj.Widgets.Figure.Position(4) = 230;
                obj.Widgets.ContentLayout.RowHeight(2:4) = {0, 0, 0};
            end

            % Enable the export button only if at least one detector is
            % selected.
            obj.Widgets.ButtonPanel.ExportButton.Enable = ~isempty(state.SelectedModel) || ...
                any(state.DetectorsTable.isSelected);
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
            fig.Position(4) = 410;
            fig.CloseRequestFcn = @(~,~) delete(weak_obj.Handle);

            % Main grid layout for the dialog
            mainLayout = uigridlayout(fig, ...
                'RowHeight', {'1x', 'fit'}, ...
                'ColumnWidth', {'1x'});

            % 2nd grid layout to contain the scrollable contents of the
            % dialog other than the button panel
            contentLayout = uigridlayout(mainLayout, ...
                'RowHeight', {'fit', 'fit', 60, '1x', 'fit', 'fit', 44, 'fit'}, ...
                'ColumnWidth', {'fit', '1x'});
            contentLayout.Layout.Row = 1;
            contentLayout.Layout.Column = 1;
            contentLayout.Scrollable = 'on';

            % Detection data label and value
            dataLabel = uilabel(contentLayout);
            dataLabel.Text = m('predmaint_anomaly:anomaly_app:strDetectionData') + ":";
            dataLabel.Layout.Row = 1;
            dataLabel.Layout.Column = 1;

            dataValue = uilabel(contentLayout);
            dataValue.Text = "";
            dataValue.Layout.Row = 1;
            dataValue.Layout.Column = 2;

            % Select results to export message
            messageLayout = uigridlayout(contentLayout, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', 'fit', '1x'});
            messageLayout.Layout.Row = 2;
            messageLayout.Layout.Column = [1 2];
            messageLayout.Padding = 0;

            messageLabel = uilabel(messageLayout);
            messageLabel.Text = m('predmaint_anomaly:anomaly_app:strSelectResultsToExport');
            messageLabel.FontWeight = 'bold';
            messageLabel.Layout.Row = 1;
            messageLabel.Layout.Column = 1;

            messageIcon = uiimage(messageLayout);
            matlab.ui.control.internal.specifyIconID(messageIcon, 'help', 16);
            messageIcon.Tooltip = m('predmaint_anomaly:anomaly_app:tipSelectResultsToExport');
            messageIcon.Layout.Row = 1;
            messageIcon.Layout.Column = 2;

            % Detector selection table
            detectorsTable = uitable(contentLayout, ...
                'RowStriping', 'off', ...
                'ColumnName', cell.empty, ...
                'RowName', cell.empty, ...
                'SelectionType', 'row', ...
                'ColumnEditable', [true false], ...
                'ColumnWidth', {'fit', '1x'});
            detectorsTable.Layout.Row = [3 4];
            detectorsTable.Layout.Column = [1 2];
            detectorsTable.CellEditCallback = @(~,ed) cbDetectorSelection(weak_obj.Handle, ed);

            % Options label
            optionsLabel = uilabel(contentLayout);
            optionsLabel.Text = m('predmaint_anomaly:anomaly_app:strLabelOptions');
            optionsLabel.FontWeight = 'bold';
            optionsLabel.Layout.Row = 5;
            optionsLabel.Layout.Column = [1 2];

            % Exported label resolution
            resolutionLabel = uilabel(contentLayout);
            resolutionLabel.Text = m('predmaint_anomaly:anomaly_app:strLabelResolution') + ":";
            resolutionLabel.Layout.Row = 6;
            resolutionLabel.Layout.Column = [1 2];

            resolutionButtonGroup = uibuttongroup(contentLayout);
            resolutionButtonGroup.BorderType = 'none';
            resolutionButtonGroup.Layout.Row = 7;
            resolutionButtonGroup.Layout.Column = [1 2];
            resolutionButtonGroup.SelectionChangedFcn = @(~,ed) cbLabelResolution(weak_obj.Handle, ed);

            sampleButton = uiradiobutton(resolutionButtonGroup);
            sampleButton.Text = m('predmaint_anomaly:anomaly_app:strSample');
            sampleButton.Position(1) = 20;
            sampleButton.Position(2) = 22;

            windowButton = uiradiobutton(resolutionButtonGroup);
            windowButton.Text = m('predmaint_anomaly:anomaly_app:strWindow');
            windowButton.Position(1) = 20;
            windowButton.Position(2) = 0;

            % Include ground truth labels
            includeCheckbox = uicheckbox(contentLayout);
            includeCheckbox.Text = m('predmaint_anomaly:anomaly_app:strIncludeGroundTruth');
            includeCheckbox.Value = true;
            includeCheckbox.Layout.Row = 8;
            includeCheckbox.Layout.Column = [1 2];
            includeCheckbox.ValueChangedFcn = @(~,ed) cbIncludeGroundTruth(weak_obj.Handle, ed);

            % Button panel
            ButtonPanel = controllib.widget.internal.buttonpanel.ButtonPanel(mainLayout, ...
                ["Export" "Cancel"]);
            ButtonPanel.ButtonWidth = 'fit';
            ButtonContainer = getWidget(ButtonPanel);
            ButtonContainer.Layout.Row = 2;
            ButtonContainer.Layout.Column = 1;
            ButtonPanel.ExportButton.ButtonPushedFcn = @(~,~) cbExport(weak_obj.Handle);
            ButtonPanel.ExportButton.Tag = 'export_detectors_dialog_export';
            ButtonPanel.CancelButton.ButtonPushedFcn = @(~,~) cbCancel(weak_obj.Handle);
            ButtonPanel.CancelButton.Tag = 'export_detectors_dialog_cancel';

            obj.Widgets = struct(...
                'Figure', fig, ...
                'MainLayout', mainLayout, ...
                'ContentLayout', contentLayout, ...
                'DataLabel', dataLabel, ...
                'DataValue', dataValue, ...
                'MessageLayout', messageLayout, ...
                'MessageLabel', messageLabel, ...
                'MessageIcon', messageIcon, ...
                'DetectorsTable', detectorsTable, ...
                'OptionsLabel', optionsLabel, ...
                'ResolutionLabel', resolutionLabel, ...
                'ResolutionButtonGroup', resolutionButtonGroup, ...
                'SampleButton', sampleButton, ...
                'WindowButton', windowButton, ...
                'IncludeGroundTruthCheckbox', includeCheckbox, ...
                'ButtonPanel', ButtonPanel);
        end

        function setDataAndModel(obj, dataKey, modelKey)
            state = obj.getState();

            state.SelectedData = dataKey;
            state.SelectedModel = modelKey;

            if isempty(modelKey)
                % There is no designated model for this dialog instance.
                % Get all the detectors that have results for the selected
                % data and update the state.DetectorsTable.
                trainedModels = obj.ModelStore.findTrainedModels();
                mask = true(size(trainedModels.keys));
                for iM = 1:numel(trainedModels.keys)
                    model = obj.ModelStore.getModel(trainedModels.keys(iM));
                    mask(iM) = isKey(model.DetectResults, dataKey);
                end
                state.DetectorsTable = table(trainedModels.names(mask), ...
                    trainedModels.keys(mask), true(nnz(mask),1), ...
                    'VariableNames', obj.DetectorsTableTemplate.Properties.VariableNames);
            else
                state.DetectorsTable = obj.DetectorsTableTemplate;
            end

            % When setting the data, we should make sure that the checkbox
            % to include ground truth labels is only true if the data has
            % labels.
            state.IncludeGroundTruth = state.IncludeGroundTruth && ...
                obj.DataStore.getData(dataKey).LabelIndex ~= 0;

            obj.setState(state);
        end

        function cbDetectorSelection(obj, ed)
            % Update the state when the detector selection changes
            state = obj.getState();
            state.DetectorsTable.isSelected(ed.Indices(1)) = ed.NewData;

            obj.setState(state);
        end

        function cbLabelResolution(obj, ed)
            % Update the state when the selected label resolution changes
            state = obj.getState();
            if ed.NewValue == obj.Widgets.SampleButton
                state.LabelResolution = "sample";
            else
                state.LabelResolution = "window";
            end

            obj.setState(state);
        end

        function cbIncludeGroundTruth(obj, ed)
            % Update the state when the checkbox selection changes
            state = obj.getState();
            state.IncludeGroundTruth = ed.Value;

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

        function cbExport(obj)
            % Make the figure not visible while exporting
            obj.Widgets.Figure.Visible = 'off';

            % Send a request to export the selected results
            state = obj.getState();
            if isempty(state.SelectedModel)
                % Use the detectors table to get the models to export
                modelKeys = state.DetectorsTable.Key(state.DetectorsTable.isSelected);
            else
                modelKeys = state.SelectedModel;
            end
            S = struct('Data', state.SelectedData, ...
                'Model', modelKeys, ...
                'LabelResolution', state.LabelResolution, ...
                'IncludeGroundTruth', state.IncludeGroundTruth);
            edata = anomalyAPP.internal.utils.EventData('ExportResultsRequest', S);
            obj.notify('ExportResultsRequest', edata); % Defer to higher authority.

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
    end
end

% Helper functions
function s = m(id, varargin)
% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end