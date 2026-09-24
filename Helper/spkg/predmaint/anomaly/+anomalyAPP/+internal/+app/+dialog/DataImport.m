classdef DataImport < anomalyAPP.internal.app.AppComponent
    % Data import dialog.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = getString(message('predmaint_anomaly:anomaly_app:strImportDataTitle'))
        Tag (1,1) string = "data_import_dialog"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataStore anomalyAPP.internal.utils.DataStore
    end

    methods
        function obj = DataImport(stateStore, dataStore)
            key = anomalyAPP.internal.app.dialog.DataImport.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.DataStore = dataStore;

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function delete(obj)
            delete(obj.Widgets.Figure);
        end

        function initialize(obj)
            reset(obj);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            SelectedChannelsTemplate = table('Size', [0 2], ...
                'VariableNames', {'ChannelName', 'isSelected'}, ...
                'VariableTypes', {'string', 'logical'});
            AllDatasetsTemplate = table('Size', [0 4], ...
                'VariableNames', {'DatasetName', 'isSelected', 'ChannelNames', 'SelectedLabelVariable'}, ...
                'VariableTypes', {'string', 'logical', 'cell', 'string'});
            state = struct(...
                'BaseDatasetName', string.empty, ...
                'BaseDatasetLocked', false, ...
                'SelectedChannels', SelectedChannelsTemplate, ...
                'ValidationHoldoutPercentage', 20, ...
                'AllDatasets', AllDatasetsTemplate, ...
                'NormalClassLabel', "0", ...
                'NormalClassLabelLocked', false, ...
                'LabelDataType', string.empty);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % If there is data in the app, then use the first training
            % data set as the base data set
            otherState = obj.StateStore.State('data_panel');
            if height(otherState.DataTable) > 0
                % Get the training data set and update the state
                I = find(otherState.DataTable.isTrainingData, 1);
                dataKey = otherState.DataTable.Key(I);
                metadata = obj.DataStore.getData(dataKey);

                state.BaseDatasetName = string(metadata.Name);
                state.ValidationHoldoutPercentage = metadata.ValidationHoldoutPercentage;

                if strcmp(metadata.DataType, "matrix")
                    selectedChannelIndex = metadata.ChannelIndex;
                    if metadata.LabelIndex ~= 0
                        selectedChannelIndex = sort([selectedChannelIndex; metadata.LabelIndex]);
                    end
                    channelNames = getString(message('predmaint_anomaly:anomaly_app:strColumn')) + string(selectedChannelIndex);
                    selectedChannelsTable = table(channelNames, true(size(channelNames)), ...
                        'VariableNames', state.SelectedChannels.Properties.VariableNames);
                    state.SelectedChannels = selectedChannelsTable;
                elseif strcmp(metadata.DataType, "timetable")
                    channelNames = metadata.ChannelNames;
                    if metadata.LabelIndex ~= 0
                        channelNames = [channelNames; metadata.LabelVariable];
                    end
                    selectedChannelsTable = table(channelNames(:), true(size(channelNames(:))), ...
                        'VariableNames', state.SelectedChannels.Properties.VariableNames);
                    state.SelectedChannels = selectedChannelsTable;
                end
                
                if ~iscell(channelNames)
                    % Force cell
                    channelNames = {channelNames(:)};
                end
                baseDataset = table(state.BaseDatasetName, true, channelNames, metadata.LabelVariable, ...
                    'VariableNames', state.AllDatasets.Properties.VariableNames);
                datasets = obj.refreshAvailableDatasets(state.BaseDatasetName, state.SelectedChannels, metadata.LabelVariable);
                if isempty(datasets)
                    state.AllDatasets = baseDataset;
                else
                    state.AllDatasets = [baseDataset; cell2table(datasets, 'VariableNames', state.AllDatasets.Properties.VariableNames)];
                end

                state.BaseDatasetLocked = true;

                % Check for label definitions in the app and update the
                % state
                strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
                isLabeled = ~strcmp(otherState.DataTable.LabelVariable, strUnlabeled);
                state.NormalClassLabelLocked = any(isLabeled);
                if state.NormalClassLabelLocked
                    I = find(isLabeled, 1);
                    dataKey = otherState.DataTable.Key(I);
                    metadata = obj.DataStore.getData(dataKey);
                    state.NormalClassLabel = metadata.OriginalNormalClassLabel;
                    state.LabelDataType = metadata.OriginalLabelDataType;
                end
            end

            obj.setState(state);
        end

        function update_(obj, ed)
        end

        function render_(obj, ~)
            weak_obj = matlab.lang.WeakReference(obj);
            state = obj.getState();

            hasBaseDataset = ~isempty(state.BaseDatasetName);
            hasChannelSelection = any(state.SelectedChannels.isSelected);

            % Get widgets
            wdgtsL = obj.Widgets.LeftWidgets;
            wdgtsR = obj.Widgets.RightWidgets;
            wdgtsB = obj.Widgets.BottomWidgets;
            
            % Set visibility of widgets on the left panel
            wdgtsL.SelectDatasetLabel.Visible = ~state.BaseDatasetLocked;
            wdgtsL.TrainingDataMessage.Visible = ~state.BaseDatasetLocked;
            wdgtsL.SelectDatasetDropdown.Visible = ~state.BaseDatasetLocked;
            wdgtsL.DataFormatLabel.Visible = state.BaseDatasetLocked;
            wdgtsL.ArchetypeDatasetLabel.Visible = state.BaseDatasetLocked;
            wdgtsL.SelectChannelsLabel.Visible = ~state.BaseDatasetLocked && hasBaseDataset;
            wdgtsL.ChannelsTable.Visible = hasBaseDataset;
            wdgtsL.LabelVariableLabel.Visible = hasBaseDataset;
            wdgtsL.LabelVariableDropdown.Visible = hasBaseDataset;
            wdgtsL.DataHoldoutLabel.Visible = hasBaseDataset;
            wdgtsL.DataHoldoutSpinner.Visible = hasBaseDataset;
            wdgtsL.WarnMessage.Visible = hasBaseDataset && ~hasChannelSelection;

            % For some widgets which are not visible, update their rows in
            % the layout to avoid blank space
            w = {wdgtsL.TrainingDataMessage, wdgtsL.SelectChannelsLabel, wdgtsL.WarnMessage};
            for iW = 1:numel(w)
                row = w{iW}.Layout.Row;
                if w{iW}.Visible
                    valueToSet = 'fit';
                else
                    valueToSet = 0;
                end
                w{iW}.Parent.RowHeight{row} = valueToSet;
            end

            % Set visibility of widgets on the right panel
            wdgtsR.MessageLabel.Visible = ~hasBaseDataset;
            wdgtsR.AddMoreDatasetsLayout.Visible = hasBaseDataset && ~state.BaseDatasetLocked;
            wdgtsR.SelectAdditionalDatasetsLabel.Visible = state.BaseDatasetLocked;
            wdgtsR.CompatibilityMessage.Visible = state.BaseDatasetLocked;
            wdgtsR.CompatibilityHelpIcon.Visible = state.BaseDatasetLocked;
            wdgtsR.RefreshButton.Visible = state.BaseDatasetLocked;
            wdgtsR.DatasetsLayout.Visible = state.BaseDatasetLocked;

            % Update the row height for the bottom panel in the main layout
            % to hide it or show it depending on if a base data set is
            % chosen
            row = wdgtsB.BottomPanel.Layout.Row;
            if hasBaseDataset
                valueToSet = 'fit';
            else
                valueToSet = 0;
            end
            wdgtsB.BottomPanel.Parent.RowHeight{row} = valueToSet;

            % Set enabled status of widgets
            wdgtsR.AddMoreDatasetsButton.Enable = hasChannelSelection;
            wdgtsL.ChannelsTable.Enable = char(matlab.lang.OnOffSwitchState(~state.BaseDatasetLocked));
            wdgtsL.LabelVariableDropdown.Enable = ~state.BaseDatasetLocked && hasChannelSelection;
            wdgtsL.DataHoldoutSpinner.Enable = ~state.BaseDatasetLocked && hasChannelSelection;

            if ~hasBaseDataset
                % If there is no base data set, then we don't need to update
                % the channels or additional datasets since they will be
                % hidden.
                wdgtsL.SelectDatasetDropdown.Value = wdgtsL.SelectDatasetDropdown.ItemsData{1};
                wdgtsB.DefineLabelsMessage.Text = getString(message('predmaint_anomaly:anomaly_app:strDefineNormalClassLabel'));
            else
                obj.renderDataSetWidgets();
            end

            % Import should only be enabled if there is a new data set to
            % import. This means a base data set if the base data set is not
            % locked (and at least one channel selected) or at least one
            % additional data set if the base data set is locked.
            if state.BaseDatasetLocked
                % If the base data set is locked, we may still need to
                % enable the import button if the base data set has not yet
                % been brought into the app. Check if the DataStore is
                % empty
                hasDataToImport = ~obj.DataStore.hasData() || any(state.AllDatasets.isSelected(2:end));
            else
                hasDataToImport = hasBaseDataset && hasChannelSelection;
            end
            obj.Widgets.ButtonPanel.ImportButton.Enable = hasDataToImport;
        end
    end

    methods (Access = private)
        function createComponents(obj)
            % Construct the components which will always exist in the
            % dialog.
            weak_obj = matlab.lang.WeakReference(obj);

            fig = uifigure;
            fig.WindowStyle = 'alwaysontop';
            fig.Position(3) = 700;
            fig.Position(4) = 530;
            fig.Visible = 'off'; % Initialize while not visible
            fig.CloseRequestFcn = @(~,~) cbClose(weak_obj.Handle);

            % There should be a main grid on the figure that puts two
            % panels side by side.
            mainLayout = uigridlayout(fig, ...
                'RowHeight', {'1x', 'fit', 10, 'fit'}, ...
                'ColumnWidth', {250, '1x'}, ...
                'ColumnSpacing', 0, ...
                'RowSpacing', 0);

            % Create the left, right, and bottom panels
            leftPanel = uipanel(mainLayout);
            leftPanel.Layout.Row = 1;
            leftPanel.Layout.Column = 1;

            rightPanel = uipanel(mainLayout);
            rightPanel.Layout.Row = 1;
            rightPanel.Layout.Column = 2;

            bottomPanel = uipanel(mainLayout);
            bottomPanel.Layout.Row = 2;
            bottomPanel.Layout.Column = [1 2];

            % Build the permanent widgets for the left panel
            leftLayout = uigridlayout(leftPanel, ...
                'RowHeight', {'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit', 'fit'}, ...
                'ColumnWidth', {180, '1x'});

            % Select a data set label
            str = getString(message('predmaint_anomaly:anomaly_app:strSelectInitialDataset'));
            selectDatasetLabel = uilabel(leftLayout, ...
                'Text', str, ...
                'WordWrap', 'on', ...
                'FontWeight', 'bold');
            selectDatasetLabel.Layout.Row = 1;
            selectDatasetLabel.Layout.Column = [1 2];

            % Current data format label (for when the left panel is locked
            % with a specific data format from the app session)
            str = getString(message('predmaint_anomaly:anomaly_app:strCurrentDataFormat'));
            dataFormatLabel = uilabel(leftLayout, ...
                'Text', str, ...
                'WordWrap', 'on', ...
                'FontWeight', 'bold');
            dataFormatLabel.Layout.Row = 1;
            dataFormatLabel.Layout.Column = [1 2];

            % Message explaining that the base data set will be used for
            % model training
            str = getString(message('predmaint_anomaly:anomaly_app:tipTrainingDataset'));
            trainingDataMessage = uilabel(leftLayout, ...
                'Text', str, ...
                'WordWrap', 'on', ...
                'FontAngle', 'italic');
            trainingDataMessage.Layout.Row = 2;
            trainingDataMessage.Layout.Column = [1 2];

            % Select a data set dropdown
            selectDatasetDropdown = uidropdown(leftLayout);
            selectDatasetDropdown.Layout.Row = 3;
            selectDatasetDropdown.Layout.Column = 1;
            selectDatasetDropdown.ValueChangedFcn = @(~,ed)cbDatasetSelected(weak_obj.Handle, ed);
            defaultItem = getString(message('predmaint_anomaly:anomaly_app:strSelectDatasetDefault'));
            selectDatasetDropdown.Items = {defaultItem}; % For the default, populate with just the "Select" item
            selectDatasetDropdown.ItemsData = {string.empty};
            selectDatasetDropdown.DropDownOpeningFcn = @(~,~) populateDatasets(weak_obj.Handle);

            % Label for the archetype data set (when the left panel is
            % locked with a sepcific data format from the app session)
            archetypeDatasetLabel = uilabel(leftLayout, ...
                'Text', '', ... % Will be updated during rendering
                'WordWrap', 'on');
            archetypeDatasetLabel.Layout.Row = 3;
            archetypeDatasetLabel.Layout.Column = [1 2];

            % Select channels label
            selectChannelsLabel = uilabel(leftLayout, ...
                'Text', '', ... % Will be updated during rendering
                'WordWrap', 'on');
            selectChannelsLabel.Layout.Row = 4;
            selectChannelsLabel.Layout.Column = [1 2];

            % Channel selection table
            channelsTable = uitable(leftLayout, ...
                'RowStriping', 'off', ...
                'ColumnName', cell.empty, ...
                'RowName', cell.empty, ...
                'SelectionType', 'row', ...
                'ColumnEditable', [true false], ...
                'ColumnWidth', {'fit', '1x'});
            channelsTable.Layout.Row = 5;
            channelsTable.Layout.Column = [1 2];
            channelsTable.CellEditCallback = @(~,ed) cbChannelSelection(weak_obj.Handle, ed);

            % Anomaly label variable selection. Includes a layout so that we can
            % put a dropdown next to the label.
            labelVariableLayout = uigridlayout(leftLayout, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', 120, '1x'}, ...
                'Padding', 0); % No padding on inner layout
            labelVariableLayout.Layout.Row = 6;
            labelVariableLayout.Layout.Column = [1 2];

            str = getString(message('predmaint_anomaly:anomaly_app:strSelectLabelVariable'));
            labelVariableLabel = uilabel(labelVariableLayout, ...
                'Text', str);
            labelVariableLabel.Layout.Column = 1;

            labelVariableDropdown = uidropdown(labelVariableLayout, ...
                'Items', {});
            labelVariableDropdown.Layout.Column = 2;
            labelVariableDropdown.ValueChangedFcn = @(~,ed)cbBaseDatasetLabelVariableSelected(weak_obj.Handle, ed);

            % Data validation holdout percentage. Includes a layout so that
            % we can put a spinner next to the label.
            dataHoldoutLayout = uigridlayout(leftLayout, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', 60, '1x'}, ...
                'Padding', 0); % No padding on inner layout
            dataHoldoutLayout.Layout.Row = 7;
            dataHoldoutLayout.Layout.Column = [1 2];

            str = getString(message('predmaint_anomaly:anomaly_app:strValidationDataPercentage'));
            dataHoldoutLabel = uilabel(dataHoldoutLayout, ...
                'Text', str);
            dataHoldoutLabel.Layout.Column = 1;

            dataHoldoutSpinner = uispinner(dataHoldoutLayout);
            dataHoldoutSpinner.Value = 10;
            dataHoldoutSpinner.RoundFractionalValues = 'on';
            dataHoldoutSpinner.Limits = [5 50];
            dataHoldoutSpinner.Layout.Column = 2;
            dataHoldoutSpinner.ValueChangedFcn = @(~,ed)cbDataHoldoutPercentage(weak_obj.Handle, ed);

            % Warning mesage
            str = getString(message('predmaint_anomaly:anomaly_app:warnNoChannelSelected'));
            warnMessage = uilabel(leftLayout, ...
                'Text', str, ...
                'WordWrap', 'on');
            warnMessage.Layout.Row = 8;
            warnMessage.Layout.Column = [1 2];
            controllib.plot.internal.utils.setColorProperty(warnMessage, 'FontColor', '--mw-color-error');

            % Store the widgets
            leftWidgets = struct(...
                'SelectDatasetLabel', selectDatasetLabel, ...
                'TrainingDataMessage', trainingDataMessage, ...
                'SelectDatasetDropdown', selectDatasetDropdown, ...
                'DataFormatLabel', dataFormatLabel, ...
                'ArchetypeDatasetLabel', archetypeDatasetLabel, ...
                'SelectChannelsLabel', selectChannelsLabel, ...
                'ChannelsTable', channelsTable, ...
                'LabelVariableLabel', labelVariableLabel, ...
                'LabelVariableDropdown', labelVariableDropdown, ...
                'DataHoldoutLabel', dataHoldoutLabel, ...
                'DataHoldoutSpinner', dataHoldoutSpinner, ...
                'WarnMessage', warnMessage);

            % Build the permanent widgets for the right panel
            rightLayout = uigridlayout(rightPanel, ...
                'RowHeight', {'fit', 'fit', 'fit', '1x'}, ...
                'ColumnWidth', {'1x', 'fit', '1x'});

            % If no data set has been selected as the base data set on the
            % left panel, there should be a message shown on the right
            % panel
            str = getString(message('predmaint_anomaly:anomaly_app:msgSelectDatasetToLeft'));
            messageLabel = uilabel(rightLayout, ...
                'Text', str, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'on');
            messageLabel.Layout.Row = [1 4];
            messageLabel.Layout.Column = [1 3];

            % If a data set has been selected on the left panel but the user
            % is still configuring it, there should be a button on the
            % right panel to add additional datasets. Put it in a layout so
            % it can be centered
            addMoreDatasetsLayout = uigridlayout(rightLayout, ...
                'RowHeight', {'1x', 'fit', '1x'}, ...
                'ColumnWidth', {'1x', 'fit', '1x'}, ...
                'Padding', 0); % no padding for inner layout
            addMoreDatasetsLayout.Layout.Row = [1 4];
            addMoreDatasetsLayout.Layout.Column = [1 3];

            str = getString(message('predmaint_anomaly:anomaly_app:strAddMoreDatasetsButton'));
            addMoreDatasetsButton = uibutton(addMoreDatasetsLayout, ...
                'Text', str);
            addMoreDatasetsButton.Layout.Row = 2;
            addMoreDatasetsButton.Layout.Column = 2;
            matlab.ui.control.internal.specifyIconID(addMoreDatasetsButton, 'add', 16);
            addMoreDatasetsButton.ButtonPushedFcn = @(~,~)cbAddMoreDatasets(weak_obj.Handle);

            % Select additional datasets label
            str = getString(message('predmaint_anomaly:anomaly_app:strSelectAdditionalDatasets'));
            selectAdditionalDatasetsLabel = uilabel(rightLayout, ...
                'Text', str, ...
                'WordWrap', 'on', ...
                'FontWeight', 'bold');
            selectAdditionalDatasetsLabel.Layout.Row = 1;
            selectAdditionalDatasetsLabel.Layout.Column = [1 3];
            
            % Compatibility message. Includes layout so that we can put a
            % help icon next to the message
            compatibilityLayout = uigridlayout(rightLayout, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', 'fit', '1x'}, ...
                'Padding', 0); % no padding for inner layout
            compatibilityLayout.Layout.Row = 2;
            compatibilityLayout.Layout.Column = [1 3];

            str = getString(message('predmaint_anomaly:anomaly_app:warnDatasetCompatibility'));
            compatibilityMessage = uilabel(compatibilityLayout, ...
                'Text', str, ...
                'FontAngle', 'italic');
            compatibilityMessage.Layout.Column = 1;

            compatibilityHelpIcon = uiimage(compatibilityLayout);
            compatibilityHelpIcon.Layout.Column = 2;
            matlab.ui.control.internal.specifyIconID(compatibilityHelpIcon, 'help', 16);
            compatibilityHelpIcon.Tooltip = getString(message('predmaint_anomaly:anomaly_app:tipDatasetCompatibility'));

            % Refresh button
            str = getString(message('predmaint_anomaly:anomaly_app:strRefresh'));
            refreshButton = uibutton(rightLayout, ...
                'Text', str);
            refreshButton.Layout.Row = 3;
            refreshButton.Layout.Column = 2;
            matlab.ui.control.internal.specifyIconID(refreshButton, 'refresh', 16);
            refreshButton.ButtonPushedFcn = @(~,~)cbRefreshDatasets(weak_obj.Handle);

            % Layout for additional datasets and column headers
            datasetsLayout = uigridlayout(rightLayout, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {150, 120, '1x'}, ...
                'Scrollable', true, ...
                'Padding', 0); % No padding for inner layout
            datasetsLayout.Layout.Row = 4;
            datasetsLayout.Layout.Column = [1 3];
            datasetsLayout.Padding(1) = 20; % Add a little left padding

            str = getString(message('predmaint_anomaly:anomaly_app:strNameTitle'));
            datasetColumnLabel = uilabel(datasetsLayout, ...
                'Text', str, ...
                'FontWeight', 'bold');
            datasetColumnLabel.Layout.Column = 1;

            str = getString(message('predmaint_anomaly:anomaly_app:strLabelVarTitle'));
            anomalyVarColumnLabel = uilabel(datasetsLayout, ...
                'Text', str, ...
                'FontWeight', 'bold');
            anomalyVarColumnLabel.Layout.Column = [2 3];

            % Store the widgets
            rightWidgets = struct(...
                'MessageLabel', messageLabel, ...
                'AddMoreDatasetsLayout', addMoreDatasetsLayout, ...
                'AddMoreDatasetsButton', addMoreDatasetsButton, ...
                'SelectAdditionalDatasetsLabel', selectAdditionalDatasetsLabel, ...
                'CompatibilityMessage', compatibilityMessage, ...
                'CompatibilityHelpIcon', compatibilityHelpIcon, ...
                'RefreshButton', refreshButton, ...
                'DatasetsLayout', datasetsLayout);
            % Initialize the data set checkboxes and anomaly label variable
            % dropdowns as empty. Must be done after the struct
            % exists.
            rightWidgets.DatasetCheckboxes = cell.empty;
            rightWidgets.DatasetAnomalyVarDropdowns = cell.empty;

            % Build the permanent widgets for the bottom panel
            bottomLayout = uigridlayout(bottomPanel, ...
                'RowHeight', {'fit', 'fit'}, ...
                'ColumnWidth', {'fit', 'fit', '1x'});

            % Define normal class label message
            str = getString(message('predmaint_anomaly:anomaly_app:strDefineNormalClassLabel'));
            defineLabelsMessage = uilabel(bottomLayout, ...
                'Text', str, ...
                'WordWrap', 'on', ...
                'FontWeight', 'bold');
            defineLabelsMessage.Layout.Row = 1;
            defineLabelsMessage.Layout.Column = [1 3];

            % Edit field label
            str = getString(message('predmaint_anomaly:anomaly_app:strNormalClassLabel'));
            normalClassLabel = uilabel(bottomLayout, 'Text', str);
            normalClassLabel.Layout.Row = 2;
            normalClassLabel.Layout.Column = 1;

            % Normal class label edit field
            normalClassLabelEditField = uieditfield(bottomLayout, 'Value', "0");
            normalClassLabelEditField.Layout.Row = 2;
            normalClassLabelEditField.Layout.Column = 2;
            normalClassLabelEditField.ValueChangedFcn = @(~,ed)cbNormalClassLabelChanged(weak_obj.Handle, ed);

            % Store the widgets
            bottomWidgets = struct(...
                'DefineLabelsMessage', defineLabelsMessage, ...
                'NormalClassLabelEditField', normalClassLabelEditField, ...
                'BottomPanel', bottomPanel);

            % Button panel
            ButtonPanel = controllib.widget.internal.buttonpanel.ButtonPanel(mainLayout, ...
                ["Help" "Import" "Cancel"]);
            ButtonPanel.ButtonWidth = 'fit';
            ButtonContainer = getWidget(ButtonPanel);
            ButtonContainer.Layout.Row = 4;
            ButtonContainer.Layout.Column = [1 2];
            ButtonPanel.HelpButton.ButtonPushedFcn = @(~,~) cbHelp(weak_obj.Handle);
            ButtonPanel.HelpButton.Tag = 'import_dialog_help';
            ButtonPanel.ImportButton.ButtonPushedFcn = @(~,~) cbImport(weak_obj.Handle);
            ButtonPanel.ImportButton.Tag = 'import_dialog_import';
            ButtonPanel.CancelButton.ButtonPushedFcn = @(~,~) cbCancel(weak_obj.Handle);
            ButtonPanel.CancelButton.Tag = 'import_dialog_cancel';

            obj.Widgets = struct(...
                'Figure', fig, ...
                'ButtonPanel', ButtonPanel, ...
                'LeftWidgets', leftWidgets, ...
                'RightWidgets', rightWidgets, ...
                'BottomWidgets', bottomWidgets, ...
                'ProgressDialog', []);
        end

        function renderDataSetWidgets(obj)
            weak_obj = matlab.lang.WeakReference(obj);
            state = obj.getState();

            % Get widgets
            wdgtsL = obj.Widgets.LeftWidgets;
            wdgtsR = obj.Widgets.RightWidgets;
            wdgtsB = obj.Widgets.BottomWidgets;

            % If the base data set is not locked, then set the value of the
            % dropdown. Otherwise, update widgets to show the archetype
            % data set in the left panel.
            if ~state.BaseDatasetLocked
                wdgtsL.SelectDatasetDropdown.Value = state.BaseDatasetName;
            else
                str = getString(message('predmaint_anomaly:anomaly_app:strDatasetValue', state.BaseDatasetName));
                wdgtsL.ArchetypeDatasetLabel.Text = str;
            end

            % Update the text of the select channels label
            wdgtsL.SelectChannelsLabel.Text = getString(message('predmaint_anomaly:anomaly_app:strSelectFromDataset', state.BaseDatasetName));

            % Update the selected channels table data
            wdgtsL.ChannelsTable.Data = [state.SelectedChannels(:,"isSelected") state.SelectedChannels(:,"ChannelName")];

            % Update the label variable dropdown for the base data set
            strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            baseDatasetInfo = state.AllDatasets(1,:);
            possibleLabelVariables = strUnlabeled;
            if nnz(state.SelectedChannels.isSelected) > 1
                possibleLabelVariables = [possibleLabelVariables; state.SelectedChannels.ChannelName(state.SelectedChannels.isSelected)];
            end
            wdgtsL.LabelVariableDropdown.Items = cellstr(possibleLabelVariables);
            wdgtsL.LabelVariableDropdown.Value = baseDatasetInfo.SelectedLabelVariable(1);

            % Update the validation data holdout spinner for the base data
            % set
            wdgtsL.DataHoldoutSpinner.Value = state.ValidationHoldoutPercentage;

            % If the base data set is locked, then the user is free to play
            % with the right panel. Update all the widgets on the right
            % panel.
            labelVariable = state.AllDatasets.SelectedLabelVariable(1); % base data set labels
            if state.BaseDatasetLocked
                % If the data set names are not the same as the existing
                % data set names, then redraw the widgets.
                existingNames = cellfun(@(x)x.Text, wdgtsR.DatasetCheckboxes, 'UniformOutput', false);
                datasetsToShow = state.AllDatasets(2:end, :);
                if isempty(existingNames) || ~isequal(existingNames(:), cellstr(datasetsToShow.DatasetName))
                    % We need to redraw the widgets
                    if ~isempty(wdgtsR.DatasetCheckboxes)
                        delete([wdgtsR.DatasetCheckboxes{:}]);
                        delete([wdgtsR.DatasetAnomalyVarDropdowns{:}]);
                    end
                    n = height(datasetsToShow);
                    wdgtsR.DatasetsLayout.RowHeight = repmat({'fit'}, 1, n+1);
                    cboxList = cell(1, n);
                    ddList = cell(1, n);
                    for i = 1:n
                        cbox = uicheckbox(wdgtsR.DatasetsLayout, 'Text', datasetsToShow.DatasetName(i));
                        cbox.Layout.Row = i+1;
                        cbox.Layout.Column = 1;
                        cbox.ValueChangedFcn = @(es,ed) cbAdditionalDatasetSelected(weak_obj.Handle, es, ed);
                        cboxList{i} = cbox;
    
                        dd = uidropdown(wdgtsR.DatasetsLayout);
                        dd.Layout.Row = i+1;
                        dd.Layout.Column = 2;
                        dd.ValueChangedFcn = @(es,ed) cbLabelVariableSelected(weak_obj.Handle, es, ed);
                        ddList{i} = dd;
                    end
                    wdgtsR.DatasetCheckboxes = cboxList;
                    wdgtsR.DatasetAnomalyVarDropdowns = ddList;
                end

                % Determine what the label variable is allowed to be. If
                % the base data set is labeled, then that variable must be
                % used for all datasets (or unlabeled). Otherwise, only one
                % label variable is allowed across all datasets. There is
                % no way for the AllDatasets.SelectedLabelVariable column
                % to have more than one unique value (other than
                % "Unlabeled") since each dropdown selection triggers a
                % render.
                if strcmp(labelVariable, strUnlabeled)
                    labelVariable = unique(state.AllDatasets.SelectedLabelVariable, 'stable');
                    labelVariable(strcmp(labelVariable, strUnlabeled)) = [];
                end

                % Set the selected state of the data set checkboxes and the
                % correct items and value of the anomaly label variable
                % dropdowns
                selectedChannelNames = state.SelectedChannels.ChannelName(state.SelectedChannels.isSelected);
                requiredChannelNames = selectedChannelNames(~strcmp(selectedChannelNames, state.AllDatasets.SelectedLabelVariable(1)));
                for i = 1:numel(wdgtsR.DatasetCheckboxes)
                    % Update the selected state of the checkbox
                    wdgtsR.DatasetCheckboxes{i}.Value = datasetsToShow.isSelected(i);

                    % Update the items and selected value for the dropdown
                    if isempty(labelVariable)
                        % Case1: All datasets are unlabeled at the moment.
                        % Allow any variables other than the required training
                        % variables as labels.
                        names = setdiff(datasetsToShow.ChannelNames{i}, requiredChannelNames, 'stable');
                    else
                        % Case2: At least one datasets has a selected label
                        % variable. Only "Unlabeled" or the same variable may
                        % be used.
                        if ismember(labelVariable, datasetsToShow.ChannelNames{i})
                            names = labelVariable;
                        else
                            names = string.empty;
                        end
                    end
                    items = [strUnlabeled; names];
                    wdgtsR.DatasetAnomalyVarDropdowns{i}.Items = items;
                    wdgtsR.DatasetAnomalyVarDropdowns{i}.Value = datasetsToShow.SelectedLabelVariable(i);

                    % Only enable the label variable selection if the
                    % data set is selected
                    wdgtsR.DatasetAnomalyVarDropdowns{i}.Enable = datasetsToShow.isSelected(i);
                end
            end

            % Update the label for normal class value and the enable state
            % of the edit field based on the base data set's label variable
            validLabel = ~isempty(labelVariable) && ~strcmp(labelVariable, strUnlabeled);
            if validLabel
                wdgtsB.DefineLabelsMessage.Text = getString(message('predmaint_anomaly:anomaly_app:strDefineNormalClassLabelForVar', labelVariable));
            elseif ~state.NormalClassLabelLocked
                wdgtsB.DefineLabelsMessage.Text = getString(message('predmaint_anomaly:anomaly_app:strDefineNormalClassLabel'));
            end
            wdgtsB.NormalClassLabelEditField.Enable = validLabel && ~state.NormalClassLabelLocked;
            wdgtsB.NormalClassLabelEditField.Value = string(state.NormalClassLabel);

            % In case any widgets changed during rendering, restore the
            % obj.Widgets property
            obj.Widgets.LeftWidgets = wdgtsL;
            obj.Widgets.RightWidgets = wdgtsR;
        end

        function datasets = refreshAvailableDatasets(obj, baseDatasetName, channelSelection, selectedLabelVar)
            % Build a table of the datasets which are compatible with the
            % base data set. If the data set exists in the DataStore, get the
            % metadata. Otherwise, we will have to look in the workspace
            % for the data set.
            dataInApp = obj.DataStore.getDataNames();
            I = strcmp(dataInApp.names, baseDatasetName);
            baseDatasetExistsInApp = ~isempty(I) && any(I);

            if baseDatasetExistsInApp
                % The base data set exists in the app (and not necessarily
                % in the base workspace). Use the metadata to find
                % compatible datasets.
                I = I(1); % There may be multiple datasets with the base data set name. The first one will be the actual base data set.
                dataKey = dataInApp.keys(I);
                metadata = obj.DataStore.getData(dataKey);

                if strcmp(metadata.DataType, "matrix")
                    selectedChannelIndex = metadata.ChannelIndex(:);
                    labelI = metadata.LabelIndex;
                    datasets = findCompatibleMatrices(metadata.Name, selectedChannelIndex, labelI, true);
                elseif strcmp(metadata.DataType, "timetable")
                    datasets = findCompatibleTimetables(metadata.Name, metadata.ChannelNames, metadata.LabelVariable, true);
                end
            else
                % The base data set does not yet exist in the app. Validate
                % that it still exists in the workspace and then find
                % datasets compatible with it.
                wksp = evalin('base', 'whos');
                varNamesInWksp = arrayfun(@(x)x.name,wksp,'UniformOutput',false);
                validVar = ismember(baseDatasetName, varNamesInWksp);
                if ~validVar
                    error(message('predmaint_anomaly:anomaly_app:errDatasetNotFound', baseDatasetName))
                end

                data = evalin('base', baseDatasetName);
                if isnumeric(data)
                    selectedChannelIndex = find(channelSelection.isSelected);
                    labelIndex = find(strcmp(selectedLabelVar, channelSelection.ChannelName), 1);
                    if isempty(labelIndex)
                        labelIndex = 0;
                    end
                    datasets = findCompatibleMatrices(baseDatasetName, selectedChannelIndex, labelIndex, false);
                elseif istimetable(data)
                    channelNames = channelSelection.ChannelName(channelSelection.isSelected);
                    labelName = selectedLabelVar;
                    if ~ismember(labelName, channelNames)
                        labelName = "";
                    end
                    datasets = findCompatibleTimetables(baseDatasetName, channelNames, labelName, false);
                elseif iscell(data)
                    if isnumeric(data{1})
                        selectedChannelIndex = find(channelSelection.isSelected);
                        labelIndex = find(strcmp(selectedLabelVar, channelSelection.ChannelName), 1);
                        if isempty(labelIndex)
                            labelIndex = 0;
                        end
                        datasets = findCompatibleMatrices(baseDatasetName, selectedChannelIndex, labelIndex, false);
                    elseif istimetable(data{1})
                        channelNames = channelSelection.ChannelName(channelSelection.isSelected);
                        labelName = selectedLabelVar;
                        if ~ismember(labelName, channelNames)
                            labelName = "";
                        end
                        datasets = findCompatibleTimetables(baseDatasetName, channelNames, labelName, false);
                    end
                end
            end
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

            % Close the dialog
            cbClose(obj);
        end
        
        function cbClose(obj)
            % Rather than destroying the dialog, just make it not visible.
            % The dialog will be destroyed when the app is destructed.
            obj.Widgets.Figure.Visible = 'off';
        end

        function cbHelp(~)
            helpview('predmaint','TSADAppImportHelp');
        end

        function cbImport(obj)
            state = obj.getState();

            % Initialize the progress dialog before doing anything so that
            % user action is blocked
            msg = getString(message('predmaint_anomaly:anomaly_app:strImportingData'));
            obj.Widgets.ProgressDialog = uiprogressdlg(obj.Widgets.Figure, 'Indeterminate', 'on', 'Message', msg);
            weak_obj = matlab.lang.WeakReference(obj);
            
            % Loop through the datasets and import them. Skip the base
            % data set if it already exists in the app.
            datasetsToImport = state.AllDatasets(state.AllDatasets.isSelected, :);
            dataInApp = obj.DataStore.getDataNames();
            baseDatasetName = state.BaseDatasetName;
            I = strcmp(dataInApp.names, baseDatasetName);
            baseDatasetExistsInApp = ~isempty(I) && any(I);
            if baseDatasetExistsInApp
                datasetsToImport = datasetsToImport(2:end, :);
            end

            % Verify that the datasets to import still exist in the base
            % workspace
            wksp = evalin('base', 'whos');
            varNamesInWksp = arrayfun(@(x)x.name,wksp,'UniformOutput',false);
            validVar = ismember(datasetsToImport.DatasetName, varNamesInWksp);
            if any(~validVar)
                msg = getString(message('predmaint_anomaly:anomaly_app:msgSkipMissingDatasets', ...
                    strjoin(datasetsToImport.DatasetName(~validVar), newline)));
                title = getString(message('predmaint_anomaly:anomaly_app:strDatasetNotFound'));
                skipOpt = getString(message('predmaint_anomaly:anomaly_app:strSkipOpt'));
                cancelOpt = getString(message('predmaint_anomaly:anomaly_app:strCancelOpt'));
                opt = {skipOpt, cancelOpt};
                selection = uiconfirm(obj.Widgets.Figure, msg, title, Options=opt, DefaultOption=1, CancelOption=2);
                if strcmp(selection, skipOpt)
                    datasetsToImport = datasetsToImport(validVar, :);
                    baseDatasetName = datasetsToImport.DatasetName(1);
                else
                    if ~validVar(1)
                        % If the base data set is not found, then reset the
                        % dialog
                        reset(obj);
                    else
                        % The base data set is found, but some other data
                        % set was not found. Refresh the available data
                        % sets
                        cbRefreshDatasets(obj); % Refresh before returning
                    end
                    delete(obj.Widgets.ProgressDialog);
                    obj.Widgets.ProgressDialog = [];
                    return
                end
            end

            % Create index vectors for the selected columns and the label
            % column within the base data set
            labelI = strcmp(state.AllDatasets.SelectedLabelVariable(1), state.SelectedChannels.ChannelName); % Logical index of label variable among all channel names (not just selected channels) in the base data set
            selectedColumns = state.SelectedChannels.isSelected & ~labelI; % Logical index of columns to include from the base data set (selected channels but not the label channel)

            info = obj.DataStore.getDataNames();
            obj.Widgets.ProgressDialog.Indeterminate = 'off';
            for iDS = 1:height(datasetsToImport)
                origName = datasetsToImport.DatasetName(iDS);
                L = event.listener(obj.DataStore, 'DataMemberAdded', @(~,ed) cbProgressUpdated(weak_obj.Handle, ed, origName));
                % Update the message of the progress dialog
                obj.Widgets.ProgressDialog.Message = getString(message('predmaint_anomaly:anomaly_app:strImportingDataSet', ...
                    origName));
                obj.Widgets.ProgressDialog.Value = 0;
                
                % Construct the metadata for the data set
                % The index of the label variable may be different than
                % what it was in the base data set, so re-compute the
                % index.
                channelNames = state.SelectedChannels.ChannelName(selectedColumns);
                [~, dataI] = ismember(channelNames, datasetsToImport.ChannelNames{iDS});
                [~, labelI] = ismember(datasetsToImport.SelectedLabelVariable(iDS), datasetsToImport.ChannelNames{iDS});
                uniqueName = matlab.lang.makeUniqueStrings(origName, info.names);
                metadata = struct('Name', uniqueName, ...
                    'DataType', string.empty, ...
                    'isTrainingData', strcmp(origName, baseDatasetName) && ~baseDatasetExistsInApp, ...
                    'ValidationHoldoutPercentage', NaN, ...
                    'ChannelNames', state.SelectedChannels.ChannelName(selectedColumns), ...
                    'ChannelIndex', dataI, ...
                    'LabelVariable', datasetsToImport.SelectedLabelVariable(iDS), ...
                    'LabelIndex', labelI, ...
                    'OriginalNormalClassLabel', string.empty, ...
                    'OriginalLabelDataType', string.empty, ...
                    'Members', 0);
                if metadata.isTrainingData
                    metadata.ValidationHoldoutPercentage = state.ValidationHoldoutPercentage;
                end
                if metadata.LabelIndex ~= 0
                    metadata.OriginalNormalClassLabel = state.NormalClassLabel;
                    metadata.OriginalLabelDataType = state.LabelDataType;
                end

                % Fetch the data from the base workspace
                data = evalin('base', origName);

                % If the data is not already a cell array, wrap it in a cell.
                % Then we can loop through and cell arrays will be treated the
                % same as a matrix/timetable (which will be a scalar cell)
                if ~iscell(data)
                    data = {data};
                end
                metadata.Members = numel(data);

                labels = cell(size(data));
                for iC = 1:numel(data)
                    if isnumeric(data{iC})
                        % Pull out the label variable if needed
                        if labelI ~= 0 % If labelI==0, then "Unlabeled" is selected
                            labels{iC} = data{iC}(:, labelI);
                        end

                        % Use only the selected columns of data
                        data{iC} = data{iC}(:, dataI);

                        % If we are looking at the first cell, update the
                        % data type in the metadata
                        if iC == 1
                            metadata.DataType = "matrix";
                        end
                    elseif istimetable(data{iC})
                        % Pull out the label variable if needed
                        if labelI ~= 0 % If labelI==0, then "Unlabeled" is selected
                            labels{iC} = data{iC}.(datasetsToImport.ChannelNames{iDS}(labelI));
                        end

                        % Use only the selected variables of data
                        data{iC} = data{iC}(:, state.SelectedChannels.ChannelName(selectedColumns));

                        % If we are looking at the first cell, update the
                        % data type in the metadata
                        if iC == 1
                            metadata.DataType = "timetable";
                        end
                    end
                end

                % Add the data set to the DataStore
                if isempty(labels{1})
                    % No label variable
                    labels = [];
                else
                    % Check if the labels are valid
                    [validLabels, labels] = cellfun(@(x)isValidLabel(x, state.NormalClassLabel, state.LabelDataType), labels, 'UniformOutput', false);
                    if ~all([validLabels{:}])
                        msg = getString(message('predmaint_anomaly:anomaly_app:msgSkipInvalidLabels', origName));
                        title = getString(message('predmaint_anomaly:anomaly_app:strInvalidLabelVariable'));
                        skipOpt = getString(message('predmaint_anomaly:anomaly_app:strSkipOpt'));
                        continueOpt = getString(message('predmaint_anomaly:anomaly_app:strContinueOpt'));
                        opt = {skipOpt, continueOpt};
                        selection = uiconfirm(obj.Widgets.Figure, msg, title, Options=opt, DefaultOption=1, CancelOption=1);
                        if strcmp(selection, skipOpt)
                            if strcmp(origName, baseDatasetName) && height(datasetsToImport) > iDS
                                % Update the base name
                                baseDatasetName = datasetsToImport.DatasetName(iDS+1);
                            end
                            % The user has chosen to skip the data set.
                            % Continue the for-loop to go to the next data
                            % set.
                            continue
                        else
                            labels = [];
                            metadata.LabelVariable = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
                            metadata.LabelIndex = 0;
                            metadata.OriginalNormalClassLabel = string.empty;
                        end
                    end
                end

                % Up to now, only the first cell of data has been
                % validated. Validate the full cell array for variable
                % types and sizes before validating the numeric or
                % timetable data
                varData = evalin('base', ['whos(''' char(origName) ''')']);
                validCellArray = ~strcmp(varData.class, 'cell') || ...
                    isValidCellArray(varData, metadata.DataType, "all");
                if strcmp(metadata.DataType, "matrix")
                    validData = validCellArray & validateNumericData(data);
                else
                    validData = validCellArray & validateTimetableData(data);
                end

                if all(validData)
                    % All cells are valid. Import the full data set
                    key = matlab.lang.internal.uuid;
                    try
                        obj.DataStore.addData(key, metadata, data, labels);
                    catch E
                        title = getString(message('predmaint_anomaly:anomaly_app:strImportError'));
                        if strcmp(E.identifier, 'predmaint:backend:errImportingWorkspaceDataToBackend') && ...
                                ~isempty(E.cause)
                            % This is a pretty generic message. Add more
                            % detail from the first cause
                            msg = sprintf("%s: %s", E.message, E.cause{1}.message);
                        else
                            msg = E.message;
                        end
                        uialert(obj.Widgets.Figure, msg, title);
                        delete(obj.Widgets.ProgressDialog);
                        obj.Widgets.ProgressDialog = [];
                        return
                    end
                elseif any(validData)
                    % At least one cell is valid, but at least one is not
                    % valid. Ask the user if they want to skip invalid
                    % members.
                    msg = getString(message('predmaint_anomaly:anomaly_app:msgSkipInvalidMembers', origName));
                    title = getString(message('predmaint_anomaly:anomaly_app:strInvalidData'));
                    continueOpt = getString(message('predmaint_anomaly:anomaly_app:strContinueOpt'));
                    skipOpt = getString(message('predmaint_anomaly:anomaly_app:strSkipOpt'));
                    opt = {continueOpt, skipOpt};
                    selection = uiconfirm(obj.Widgets.Figure, msg, title, Options=opt, DefaultOption=1, CancelOption=2);
                    if strcmp(selection, continueOpt)
                        data = data(validData);
                        metadata.Members = numel(data);
                        key = matlab.lang.internal.uuid;
                        obj.DataStore.addData(key, metadata, data, labels);
                    else
                        if strcmp(origName, baseDatasetName) && height(datasetsToImport) > iDS
                            % Update the base name
                            baseDatasetName = datasetsToImport.DatasetName(iDS+1);
                        end
                        % The user has chosen to skip the data set.
                        % Continue the for-loop to go to the next data set.
                        continue
                    end
                else
                    % None of the cells in the data set are valid. Ask the
                    % user if they want to skip the data set or cancel.
                    msg = getString(message('predmaint_anomaly:anomaly_app:msgSkipInvalidDataSet', origName));
                    title = getString(message('predmaint_anomaly:anomaly_app:strInvalidData'));
                    skipOpt = getString(message('predmaint_anomaly:anomaly_app:strSkipOpt'));
                    cancelOpt = getString(message('predmaint_anomaly:anomaly_app:strCancelOpt'));
                    opt = {skipOpt, cancelOpt};
                    selection = uiconfirm(obj.Widgets.Figure, msg, title, Options=opt, DefaultOption=1, CancelOption=2);
                    if strcmp(selection, skipOpt)
                        if strcmp(origName, baseDatasetName) && height(datasetsToImport) > iDS
                            % Update the base name
                            baseDatasetName = datasetsToImport.DatasetName(iDS+1);
                        end
                        % The user has chosen to skip the data set.
                        % Continue the for-loop to go to the next data set.
                        continue
                    else
                        if strcmp(metadata.Name, state.BaseDatasetName) % Compare against the actual base dataset name, not the baseDatasetName variable, which tracks what will become the base upon import
                            % If the base data set is not valid, then go
                            % back to the base dataset selection
                            state = obj.getState();
                            state.BaseDatasetLocked = false;
                            obj.setState(state);
                        else
                            % The base data set is valid, but some other data
                            % set was not valid. Refresh the available data
                            % sets
                            cbRefreshDatasets(obj); % Refresh before returning
                        end
                        delete(obj.Widgets.ProgressDialog);
                        obj.Widgets.ProgressDialog = [];
                        return
                    end
                end
                delete(L);
            end
            delete(obj.Widgets.ProgressDialog);
            obj.Widgets.ProgressDialog = [];

            % Log a DDUX event for the button click
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.ButtonPanel.ImportButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);

            % Close the dialog
            cbClose(obj);
        end

        function cbDatasetSelected(obj, ed)
            state = obj.getState();

            % If the selection is reverted back to the "Select a
            % data set..." option, then just use the default state.
            if isempty(ed.Value)
                state = obj.getDefaultState();
                obj.setState(state);
                return
            end

            % Update the base data set name in the state
            state.BaseDatasetName = string(ed.Value);

            % Based on the base data set, update the channel selection and
            % the AllDatasets table. The AllDatasets table for now will
            % just have one row representing the base data set
            strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            strColumn = string(message('predmaint_anomaly:anomaly_app:strColumn')); % Make sure it is a string and not char
            data = evalin('base', ed.Value);
            if isnumeric(data)
                % The data is a matrix. Channel names will just be ColumnX.
                selectedChannelIndex = (1:size(data,2))';
                channelNames = strColumn + string(selectedChannelIndex);
                selectedChannelsTable = table(channelNames, true(size(channelNames)), ...
                    'VariableNames', state.SelectedChannels.Properties.VariableNames);
                state.SelectedChannels = selectedChannelsTable;

                if ~iscell(channelNames)
                    % Force cell
                    channelNames = {channelNames(:)};
                end
                state.AllDatasets = table(string(ed.Value), true, channelNames, strUnlabeled, ...
                    'VariableNames', state.AllDatasets.Properties.VariableNames);
            elseif istimetable(data)
                % The data is a timetable. Channel names are the variable
                % names.
                channelNames = string(data.Properties.VariableNames);
                selectedChannelsTable = table(channelNames(:), true(size(channelNames(:))), ...
                    'VariableNames', state.SelectedChannels.Properties.VariableNames);
                state.SelectedChannels = selectedChannelsTable;

                if ~iscell(channelNames)
                    % Force cell
                    channelNames = {channelNames(:)};
                end
                state.AllDatasets = table(string(ed.Value), true, channelNames, strUnlabeled, ...
                    'VariableNames', state.AllDatasets.Properties.VariableNames);
            elseif iscell(data)
                if ~isscalar(unique(cellfun(@class, data, 'UniformOutput', false)))
                    % The data types of cells are not consistent. Revert to
                    % the default state
                    state = obj.getDefaultState();
                    obj.setState(state);

                    % Show an error on the dialog using uiconfirm
                    msg = getString(message('predmaint_anomaly:anomaly_app:errInconsistentCellFormats', ed.Value));
                    title = getString(message('predmaint_anomaly:anomaly_app:strImportError'));
                    opt = {getString(message('predmaint_anomaly:anomaly_app:strContinueOpt'));};
                    sel = uiconfirm(obj.Widgets.Figure, msg, title, Options=opt, Icon="warning"); % Wait for the user to acknowledge before continuing
                    
                    % Make sure the widget is reverted. Render may not be
                    % called if the initial state was the default state,
                    % since nothing in the state was dirtied.
                    ed.Source.Value = ed.PreviousValue;

                    return
                elseif isnumeric(data{1})
                    % For a cell array of matrices, find the columns that
                    % exist in all cells
                    nCol = min(cellfun(@(x)size(x,2), data));
                    selectedChannelIndex = (1:nCol)';
                    channelNames = strColumn + string(selectedChannelIndex);
                    selectedChannelsTable = table(channelNames, true(size(channelNames)), ...
                        'VariableNames', state.SelectedChannels.Properties.VariableNames);
                    state.SelectedChannels = selectedChannelsTable;

                    if ~iscell(channelNames)
                        % Force cell
                        channelNames = {channelNames(:)};
                    end
                    state.AllDatasets = table(string(ed.Value), true, channelNames, strUnlabeled, ...
                        'VariableNames', state.AllDatasets.Properties.VariableNames);
                elseif istimetable(data{1})
                    % For a cell array of timetables, find the variables
                    % that exist in all cells
                    channelNames = data{1}.Properties.VariableNames;
                    isValidChannel = cellfun(@(x)all(cellfun(@(y)any(ismember(y.Properties.VariableNames,x)), data)), channelNames); % Channel name must exist in each cell of data
                    channelNames = string(channelNames(isValidChannel));
                    selectedChannelsTable = table(channelNames(:), true(size(channelNames(:))), ...
                        'VariableNames', state.SelectedChannels.Properties.VariableNames);
                    state.SelectedChannels = selectedChannelsTable;

                    if ~iscell(channelNames)
                        % Force cell
                        channelNames = {channelNames(:)};
                    end
                    state.AllDatasets = table(string(ed.Value), true, channelNames, strUnlabeled, ...
                    'VariableNames', state.AllDatasets.Properties.VariableNames);
                end
            end

            % Set the state
            obj.setState(state);
        end

        function cbRefreshDatasets(obj)
            state = obj.getState();

            originalDatasetsTable = state.AllDatasets(2:end, :); % Don't include the base data set

            baseDataset = state.AllDatasets(1,:);
            try
                datasets = obj.refreshAvailableDatasets(state.BaseDatasetName, state.SelectedChannels, baseDataset.SelectedLabelVariable(1));
            catch E
                title = getString(message('predmaint_anomaly:anomaly_app:strDatasetNotFound'));
                uialert(obj.Widgets.Figure, E.message, title);
                reset(obj);
                return
            end

            if isempty(datasets)
                state.AllDatasets = baseDataset;
            else
                state.AllDatasets = [baseDataset; cell2table(datasets, 'VariableNames', state.AllDatasets.Properties.VariableNames)];
            end

            % Maintain selection where possible
            for i = 1:height(state.AllDatasets)
                % If the data set existed before, try to keep its selected
                % state and chosen label variable
                J = strcmp(state.AllDatasets.DatasetName(i), originalDatasetsTable.DatasetName);
                if any(J)
                    state.AllDatasets.isSelected(i) = originalDatasetsTable.isSelected(J);
                    labelVariableValue = originalDatasetsTable.SelectedLabelVariable(J);
                    if ismember(labelVariableValue, state.AllDatasets.ChannelNames{i})
                        state.AllDatasets.SelectedLabelVariable(i) = labelVariableValue;
                    end
                end
            end

            obj.setState(state);
        end

        function cbAddMoreDatasets(obj)
            state = obj.getState();

            % Lock the base data set
            state.BaseDatasetLocked = true;

            % Update the available datasets based on the base data set
            baseDataset = state.AllDatasets(1,:);
            try
                datasets = obj.refreshAvailableDatasets(state.BaseDatasetName, state.SelectedChannels, baseDataset.SelectedLabelVariable(1));
            catch E
                if strcmp(E.identifier, 'predmaint_anomaly:anomaly_app:errDatasetNotFound')
                    title = getString(message('predmaint_anomaly:anomaly_app:strDatasetNotFound'));
                    uialert(obj.Widgets.Figure, E.message, title);
                    reset(obj);
                    return
                else
                    rethrow(E)
                end
            end

            if isempty(datasets)
                state.AllDatasets = baseDataset;
            else
                state.AllDatasets = [baseDataset; cell2table(datasets, 'VariableNames', state.AllDatasets.Properties.VariableNames)];
            end

            obj.setState(state);
        end

        function cbChannelSelection(obj, ed)
            state = obj.getState();

            % Update the SelectedChannels table in the state
            I = ed.Indices(1);
            state.SelectedChannels.isSelected(I) = ed.NewData;

            % If the label variable was unselected, then update the
            % SelectedLabelVariable
            if ~ed.NewData && strcmp(state.AllDatasets.SelectedLabelVariable(1), state.SelectedChannels.ChannelName(I))
                state.AllDatasets.SelectedLabelVariable(1) = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            elseif nnz(state.SelectedChannels.isSelected) <= 1
                % If 0 or 1 channel is selected, then only Unlabeled is
                % valid
                state.AllDatasets.SelectedLabelVariable(1) = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            end

            obj.setState(state);
        end

        function cbAdditionalDatasetSelected(obj, es, ed)
            state = obj.getState();

            % Update the selection in the AllDatasets table in the state
            I = [false; strcmp(es.Text, state.AllDatasets.DatasetName(2:end))]; % Make sure not to include the first row when updating selection. This row is the base data set and should always be true
            state.AllDatasets.isSelected(I) = ed.Value;

            obj.setState(state);
        end

        function cbBaseDatasetLabelVariableSelected(obj, ed)
            state = obj.getState();

            % Update the selected label variable in the first row of the
            % AllDatasets table
            state.AllDatasets.SelectedLabelVariable(1) = string(ed.Value);

            % If the base data set is labeled, then it is the first data
            % set to be labeled. Update the label data type in the state.
            if ed.ValueIndex == 1 % Unlabeled is the first option
                state.LabelDataType = string.empty;
            else
                % Get the data set from the base workspace to check for the
                % data type of the label variable
                DS = evalin('base', state.BaseDatasetName);
                if iscell(DS)
                    DS = DS{1}; % Just use the first member to check the label data type
                end
                if istimetable(DS)
                    % If the data set is a timetable, just get the labels
                    % using the label variable name. Look at the first
                    % sample to check the data type.
                    labelSample = DS.(ed.Value)(1);
                    if iscell(labelSample)
                        labelSample = labelSample{1};
                    end
                elseif isnumeric(DS)
                    % If the data set is numeric, find which column is the
                    % label variable and look at the first row of that
                    % column to check the data type.
                    I = strcmp(ed.Value, state.SelectedChannels.ChannelName);
                    labelSample = DS(1,I);
                end
                % Set the state.LabelDataType and state.NormalClassLabel
                % based on the first value of the label variable. The
                % LabelDataType will keep track of what type of data is
                % used for labels
                % (string/char/categorical/logical/numeric), and the
                % NormalClassLabel will be the default string we will use
                % in the edit field for normal class label definition.
                if isnumeric(labelSample)
                    state.LabelDataType = 'numeric'; % Treat all numeric classes as the same
                    state.NormalClassLabel = "0";
                else
                    state.LabelDataType = class(labelSample);
                    if strcmp(state.LabelDataType, 'logical')
                        state.NormalClassLabel = "false";
                    else
                        state.NormalClassLabel = "normal";
                    end
                end
            end

            obj.setState(state);
        end

        function cbDataHoldoutPercentage(obj, ed)
            state = obj.getState();

            % Update the data holdout percentage in the state
            state.ValidationHoldoutPercentage = ed.Value;

            obj.setState(state);
        end

        function cbLabelVariableSelected(obj, es, ed)
            state = obj.getState();

            % Update the anomaly label variable in the AllDatasets table in
            % the state
            I = es.Layout.Row; % Subtract one because of the column titles. Add 1 because the base data set will be the first row in state.AllDatasets
            state.AllDatasets.SelectedLabelVariable(I) = string(ed.Value);

            % If the label data type has not yet been defined, update it in
            % the state
            if ed.ValueIndex == 1 % Unlabeled
                % If setting back to unlabeled, check if other label
                % definitions exist for selected datasets. If not, reset
                % the label data type.
                strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
                isLabeled = ~strcmp(state.AllDatasets.SelectedLabelVariable(state.AllDatasets.isSelected), strUnlabeled);
                if ~any(isLabeled)
                    state.LabelDataType = string.empty;
                end
            elseif isempty(state.LabelDataType)
                % The label data type has not yet been defined, so use the
                % selected data set to define it.
                DS = evalin('base', state.AllDatasets.DatasetName(I));
                if iscell(DS)
                    DS = DS{1}; % Just use the first member to check the label data type
                end
                if istimetable(DS)
                    % If the data set is a timetable, just get the labels
                    % using the label variable name. Look at the first
                    % sample to check the data type.
                    labelSample = DS.(ed.Value)(1);
                    if iscell(labelSample)
                        labelSample = labelSample{1};
                    end
                elseif isnumeric(DS)
                    % If the data set is numeric, find which column is the
                    % label variable and look at the first row of that
                    % column to check the data type.
                    I = strcmp(ed.Value, state.SelectedChannels.ChannelName);
                    labelSample = DS(1,I);
                end
                % Set the state.LabelDataType and state.NormalClassLabel
                % based on the first value of the label variable. The
                % LabelDataType will keep track of what type of data is
                % used for labels
                % (string/char/categorical/logical/numeric), and the
                % NormalClassLabel will be the default string we will use
                % in the edit field for normal class label definition.
                if isnumeric(labelSample)
                    state.LabelDataType = 'numeric'; % Treat all numeric classes as the same
                    state.NormalClassLabel = "0";
                else
                    state.LabelDataType = class(labelSample);
                    if strcmp(state.LabelDataType, 'logical')
                        state.NormalClassLabel = "false";
                    else
                        state.NormalClassLabel = "normal";
                    end
                end
            end
            
            obj.setState(state);
        end

        function cbNormalClassLabelChanged(obj, ed)
            state = obj.getState();

            % Update the normal class label in the state. Clean up the
            % formatting of the string in the edit field also.
            if state.LabelDataType == "numeric"
                normal = str2double(string(ed.Value));
                if isnan(normal) || isempty(normal)
                    normal = ed.PreviousValue;
                end
            elseif state.LabelDataType == "logical"
                normal = str2double(string(ed.Value));
                if isnan(normal)
                    if any(strcmpi(ed.Value, {'true', 'false'}))
                        normal = lower(ed.Value);
                    else
                        normal = ed.PreviousValue;
                    end
                else
                    normal = logical(normal);
                end
            else % string, char, or categorical can keep the text
                normal = ed.Value;
            end
            ed.Source.Value = string(normal);
            state.NormalClassLabel = string(normal);

            obj.setState(state);
        end

        function populateDatasets(obj)
            wksp = evalin('base', 'whos');
            valid = arrayfun(@(x)isValidDataset(x), wksp);
            wkspTable = struct2table(wksp(valid));
            vals = wkspTable.name;
            defaultItem = getString(message('predmaint_anomaly:anomaly_app:strSelectDatasetDefault'));
            obj.Widgets.LeftWidgets.SelectDatasetDropdown.Items = vertcat({defaultItem}, vals);
            obj.Widgets.LeftWidgets.SelectDatasetDropdown.ItemsData = vertcat({string.empty}, vals);
        end

        function cbProgressUpdated(obj, ed, dsName)
            obj.Widgets.ProgressDialog.Value = ed.Progress;
            obj.Widgets.ProgressDialog.Message = getString(message(...
                'predmaint_anomaly:anomaly_app:strImportingDataSetXOfY', dsName, ed.NumCompleted, ed.TotalNum));
        end
    end

    % QE methods
    methods (Hidden)
        function qeOpenSelectDatasetDropdown(obj)
            obj.Widgets.LeftWidgets.SelectDatasetDropdown.DropDownOpeningFcn();
        end

        function qeSelectDatasetFromDropdown(obj, dsName)
            obj.Widgets.LeftWidgets.SelectDatasetDropdown.DropDownOpeningFcn();
            prevValue = obj.Widgets.LeftWidgets.SelectDatasetDropdown.Value;
            I = find(strcmp(obj.Widgets.LeftWidgets.SelectDatasetDropdown.ItemsData, dsName));
            if I ~= 0
                obj.Widgets.LeftWidgets.SelectDatasetDropdown.Value =  obj.Widgets.LeftWidgets.SelectDatasetDropdown.ItemsData{I};
            end
            ed = struct('Value', dsName, 'PreviousValue', prevValue);
            obj.cbDatasetSelected(ed);
        end
    end
end

function valid = isValidDataset(var)
valid = isValidMatrix(var) || isValidTimetable(var);
end

function valid = isValidMatrix(var)
if strcmp(var.class, 'cell')
    valid = isValidCellArray(var, 'matrix', "first");
else
    % A valid matrix is a numeric class variable that has more than one row
    validClasses = {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'};
    valid = any(strcmp(var.class, validClasses)) && var.size(1) > 1;
end
end

function valid = isValidTimetable(var)
if strcmp(var.class, 'cell')
    valid = isValidCellArray(var, 'timetable', "first");
else
    valid = strcmp(var.class, 'timetable') && var.size(1) > 1;
end
end

function valid = isValidCellArray(var, type, method)
arguments
    var
    type
    method (1,1) string {mustBeMember(method, ["first" "all"])} = "first" % "first" validation will just validate the first cell
end
valid = true;
% Cell arrays must be 1xn or nx1
if ~any(var.size == 1) || any(var.size == 0)
    valid = false;
    return
else
    name = var.name;
    if method == "first"
        nCells = 1; % Just validate the first cell
    else
        nCells = max(var.size);
    end
    for i = 1:nCells
        % For each cell, verify that the cell data is the correct type and
        % has more than one row
        if strcmp(type, 'matrix')
            strToEval = sprintf("isnumeric(%1$s{%2$d}) && (size(%1$s{%2$d},1)>1)", name, i);
            valid = valid && evalin('base', strToEval);
        elseif strcmp(type, 'timetable')
            strToEval = sprintf("istimetable(%1$s{%2$d}) && (size(%1$s{%2$d},1)>1)", name, i);
            valid = valid && evalin('base', strToEval);
        else
            valid = false;
            return
        end
    end
end
end

function C = findCompatibleMatrices(baseVarName, selectedChannelIndex, labelVarIndex, allowBaseDataset)
strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
strColumn = string(message('predmaint_anomaly:anomaly_app:strColumn')); % Make sure it is a string and not char
C = cell.empty;
wksp = evalin('base', 'whos');
isMatrix = arrayfun(@(x)isValidMatrix(x), wksp);
matrices = wksp(isMatrix);
requiredChannelIndex = selectedChannelIndex(selectedChannelIndex ~= labelVarIndex);
for i = 1:numel(matrices)
    if strcmp(matrices(i).class, 'cell')
        if evalin('base', ['~all(cellfun(@isnumeric,' matrices(i).name '))'])
            % Not all cells are matrices, so skip
            continue
        end
        nCol = evalin('base', ['min(cellfun(@(x)size(x,2), ' matrices(i).name '))']);
    else
        nCol = matrices(i).size(2);
    end
    if ~isempty(requiredChannelIndex) && nCol < max(requiredChannelIndex)
        % Only look at matrices with at least the minimum
        % number of columns
        continue
    else
        if strcmp(matrices(i).name, baseVarName) && ~allowBaseDataset
            % Don't include the base data set
            continue
        end
        name = string(matrices(i).name);
        channelNames = strColumn + string((1:nCol)');
        C = [C; {name, false, channelNames, strUnlabeled}]; %#ok<AGROW>
    end
end
end

function C = findCompatibleTimetables(baseVarName, selectedVariables, labelVariable, allowBaseDataset)
strUnlabeled = string(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
C = cell.empty;
wksp = evalin('base', 'whos');
isTT = arrayfun(@(x)isValidTimetable(x), wksp);
timetables = wksp(isTT);
requiredVariables = selectedVariables(~strcmp(selectedVariables, labelVariable));
for i = 1:numel(timetables)
    if strcmp(timetables(i).class, 'cell')
        if evalin('base', ['~all(cellfun(@istimetable,' timetables(i).name '))'])
            % Not all cells are timetables, so skip
            continue
        end
        varNames = evalin('base', [timetables(i).name '{1}.Properties.VariableNames']);
        isValidChannel = evalin('base', ['cellfun(@(x)all(cellfun(@(y)any(ismember(y.Properties.VariableNames,x)), ' timetables(i).name ')), ' timetables(i).name '{1}.Properties.VariableNames)']);
        varNames = string(varNames(isValidChannel));
    else
        varNames = string(evalin('base',[timetables(i).name '.Properties.VariableNames']));
    end
    if ~isempty(requiredVariables) && ~all(ismember(requiredVariables, varNames))
        % Only look at matrices with at least the minimum
        % number of columns
        continue
    else
        if strcmp(timetables(i).name, baseVarName) && ~allowBaseDataset
            % Don't include the base data set
            continue
        end
        name = string(timetables(i).name);
        C = [C; {name, false, varNames(:), strUnlabeled}]; %#ok<AGROW>
    end
end
end

function [valid, logicalL] = isValidLabel(L, normalClassValue, expDataType)
% Check the label vector L against the expected data type. If it matches,
% then convert into logical labels using the normalClassValue as the normal
% data. All other values will be considered anomalous.
logicalL = logical.empty;

% If L is chars, convert to string
if ischar(L)
    L = string(L);
end

% If expecting char, we actually expect strings since everything is
% converted to string for comparison
if strcmp(expDataType, 'char')
    expDataType = 'string';
end

% Check for missing or infinite labels
if any(ismissing(L)) || (isnumeric(L) && ~all(isfinite(L)))
    valid = false;
    return
end

% Check the data type of L
if isnumeric(L)
    normal = str2double(normalClassValue);
    valid = ~isnan(normal); % If the normal class value cannot be converted to double, then it is not valid
    actDataType = 'numeric'; % All numeric types can be compared, so treat them as one class
else
    actDataType = class(L);
    valid = ~islogical(L) || any(strcmpi(normalClassValue, {'true', 'false'})); % All strings are a valid normalClassValue for string/char/categorical case, so just check logical case. Only check true/false since the edit field format is simplified when the value changes
end
valid = valid && strcmp(actDataType, expDataType);
if ~valid
    return
end

% Convert the labels to logical if the normal class value is valid
switch actDataType
    case 'numeric'
        normal = str2double(normalClassValue);
        normal = cast(normal, class(L));
    case 'logical'
        normal = strcmpi(normalClassValue,'true');
    case 'string'
        normal = normalClassValue; % Since it comes from a text edit field, it is string already
    case 'categorical'
        normal = categorical(normalClassValue);
    otherwise
        valid = false;
        return
end
logicalL = L ~= normal;
end

function valid = validateNumericData(data)
% For a matrix to be considered valid, it must be all finite and have no
% missing values
valid = cellfun(@allfinite, data);
end

function valid = validateTimetableData(data)
% For a timetable to be considered valid, its data must be all finite
% numerics and have no missing values
valid = cellfun(@(x) all(varfun(@isnumeric, x, 'OutputFormat', 'uniform')) && allfinite(x{:,:}), data);
end