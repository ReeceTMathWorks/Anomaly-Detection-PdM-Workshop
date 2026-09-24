classdef Compare < anomalyAPP.internal.app.AppComponent
    % Compare document.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strCompare')
        Tag (1,1) string = "compare_document"
    end

    properties (Access = public)
        Widgets
        Workspace = struct('SelectedMember', 1)
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener

        DataStore anomalyAPP.internal.utils.DataStore
        DataStoreListener event.listener
    end

    methods
        function obj = Compare(stateStore, modelStore, dataStore)
            key = anomalyAPP.internal.app.document.Compare.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            weakObj = matlab.lang.WeakReference(obj);

            obj.ModelStore = modelStore;
            obj.ModelStoreListener = listener(modelStore, 'ModelChanged', @(~,ed) cbModelChanged(weakObj.Handle,ed));

            obj.DataStore = dataStore;
            obj.DataStoreListener = listener(dataStore, 'DataChanged', @(~,ed) cbDataChanged(weakObj.Handle,ed));

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function panel = getFigureDocument(obj)
            panel = obj.Widgets.FigureDocument;
        end

        function setModel(obj, key)
            state = obj.getState();
            % state.SelectedModel = key; % NOTE: From the document, not the browser.
            state = obj.updateDirtyStates(state);
            obj.setState(state);
        end

        function setData(obj, key)
            state = obj.getState();
            state.SelectedData = key;
            state = obj.updateDirtyStates(state);
            obj.setState(state);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'Models', string.empty(0,2), ...
                'SelectedData', string.empty, ...
                'SelectedModel', string.empty, ...
                'AllModelsDetected', false, ... % Logical flag indicating whether all trained models have detection results using the current data.
                'DirtyModel', false, ... % Logical flag indicating whether any model has been re-trained since the last detection with the current data.
                'DirtyFromLKGConfig', false, ... % Logical flag indicating whether the selected model's detection config differs from its last known good config.
                'Detected', false); % Logical flag indicating whether the selected model has detection results for the selected data.
        end

        function reset(obj)
            state = obj.getDefaultState();
            dataKey = string.empty;

            % Initialize state from model store.
            info = obj.ModelStore.findTrainedModels();
            state.Models = [info.keys(:) info.names(:)];
            modelKey = selectModel(obj, info.keys);  % Can be empty.

            % Initialize state from data store.
            info = obj.DataStore.findLabeledData();
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize state from data browser, if there is one.
            if obj.hasState("data_panel")
                otherState = obj.getState("data_panel");
                strUnlabeled = m('predmaint_anomaly:anomaly_app:strUnlabeled');
                I = otherState.DataTable.isSelected & (otherState.DataTable.LabelVariable ~= strUnlabeled);
                if any(I)
                    candidateKeys = otherState.DataTable.Key(I);
                    dataKey = candidateKeys(1);
                end
            end

            % Initialize state based on the selected model and data.
            state.SelectedModel = modelKey;
            state.SelectedData = dataKey;
            state = obj.updateDirtyStates(state);
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "compare_tab")
                otherState = obj.getState(ed.Name);
                state = obj.getState();

                if ~isempty(otherState.SelectedData) && ~isequal(state.SelectedData, otherState.SelectedData)
                    obj.Workspace.SelectedMember = 1; % Only if new data is selected.
                end

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                    state.SelectedData = dataKey;
                end

                state = obj.updateDirtyStates(state);
                obj.setState(state);
            end
        end

        function render_(obj, ~)
            arguments
                obj
                ~
            end
            import anomalyAPP.internal.utils.setAlertBoxMessage;

            state = obj.getState();

            obj.Widgets.FigureDocument.Title = obj.Title;

            % Update the info/alert box based on the state of the detectors.
            fig = obj.Widgets.FigureDocument.Figure;
            if isempty(state.SelectedData)
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgNoLabeledDataForCompare'));
            elseif isempty(state.Models)
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgNoModelsToCompare'));
            elseif ~state.AllModelsDetected
                setAlertBoxMessage(fig, "info", m('predmaint_anomaly:anomaly_app:msgPressCompare'));
            elseif state.DirtyModel
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgCompareResultsDirty'));
            else
                setAlertBoxMessage(fig);
            end

            % Update the metrics displays.
            updateComparisonMetrics(obj);
            updateDetectorDetails(obj);
        end
    end

    % Event management
    methods (Access = private)
        function cbDataChanged(obj, ed)
            state = obj.getState();

            info = obj.DataStore.findLabeledData(); % Only the labeled datasets.

            if isempty(state.SelectedData) || ~any(state.SelectedData == info.keys)
                % No dataset is selected or the selected dataset is no longer available.
                if ~isempty(info.keys)
                    % There is a dataset to select.
                    state.SelectedData = info.keys(1);
                else
                    % No dataset available.
                    state.SelectedData = string.empty;
                end
                obj.Workspace.SelectedMember = 1; % Only if new data selected.
                state = obj.updateDirtyStates(state);
            elseif (ed.Data.Status == "Changed") && any(state.SelectedData == ed.Name)
                % Selected data was modified in place — detection results are stale.
                state = obj.updateDirtyStates(state, true);
            end

            obj.setState(state);
        end

        function cbModelChanged(obj, ~)
            state = obj.getState();

            info = obj.ModelStore.findTrainedModels(); % Only the trained models.
            state.Models = [info.keys(:), info.names(:)];

            if isempty(state.SelectedModel) || ~any(state.SelectedModel == info.keys)
                % No model is selected or the selected model is no longer available.
                state.SelectedModel = selectModel(obj, info.keys);
            end

            state = obj.updateDirtyStates(state);
            obj.setState(state);

            % Close document when there is no detector in the app.
            if ~obj.ModelStore.hasModels()
                obj.getFigureDocument.close();
            end
        end

        function DetectorMetricsTableSelectionChangedFcn(obj, ~, ed)
            if ~isempty(ed.Selection)
                state = obj.getState();
                idx = min(ed.Selection, size(state.Models, 1));
                state.SelectedModel = state.Models(idx, 1);
                state = obj.updateDirtyStates(state);
                obj.setState(state);
            end
        end

        function MemberMetricsTableSelectionChangedFcn(obj, ~, ed)
            if ~isempty(ed.Selection)
                obj.Workspace.SelectedMember = ed.Selection;
                updateDetectorDetails(obj);
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Figure Document
            compareOptions.Tag = obj.Tag;
            compareOptions.Closable = false;
            fd = matlab.ui.internal.FigureDocument(compareOptions);

            mainContainer = uigridlayout(fd.Figure);
            mainContainer.RowHeight = {'fit', '1x'};
            mainContainer.ColumnWidth = {'1x'};

            alertBox = anomalyAPP.internal.utils.makeAlertBox(mainContainer, "message");
            alertBox.Layout.Row = 1;
            alertBox.Layout.Column = 1;

            scrollContainer = uigridlayout(mainContainer);
            scrollContainer.Layout.Row = 2;
            scrollContainer.Layout.Column = 1;
            scrollContainer.RowHeight = {'fit'};
            scrollContainer.ColumnWidth = {'1x'};
            scrollContainer.Scrollable = 'on';

            % Accordion panels
            accordion = matlab.ui.container.internal.Accordion('Parent', scrollContainer);
            accordion.Layout.Row = 1;
            accordion.Layout.Column = [1 3];

            % Supervised training metrics
            metricsAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            metricsAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strDetectionMetricsTitle');

            metricsGridLayout = uigridlayout(metricsAccordionPanel);
            metricsGridLayout.RowHeight = {0, 200};
            metricsGridLayout.ColumnWidth = {'fit', '1x'};

            metricsAlertIcon = uiimage(metricsGridLayout);
            metricsAlertIcon.Layout.Row = 1;
            metricsAlertIcon.Layout.Column = 1;
            matlab.ui.control.internal.specifyIconID(metricsAlertIcon, 'warning', 16);

            metricsAlertLabel = uilabel(metricsGridLayout);
            metricsAlertLabel.Layout.Row = 1;
            metricsAlertLabel.Layout.Column = 2;
            metricsAlertLabel.WordWrap = 'on';
            metricsAlertLabel.FontAngle = 'italic';
            metricsAlertLabel.Text = m('predmaint_anomaly:anomaly_app:strTrainMetricsFail');
            matlab.graphics.internal.themes.specifyThemePropertyMappings(...
                metricsAlertLabel, 'FontColor', '--mw-color-warning');

            detectorMetricsTable = uitable(metricsGridLayout, SelectionType="row", ...
                Multiselect="off", ColumnSortable=true, ColumnWidth='1x');
            detectorMetricsTable.Tooltip = m('predmaint_anomaly:anomaly_app:strSummaryTableTip');
            detectorMetricsTable.SelectionChangedFcn = @(es,ed) DetectorMetricsTableSelectionChangedFcn(weak_obj.Handle,es,ed);
            detectorMetricsTable.Layout.Row = 2;
            detectorMetricsTable.Layout.Column = [1 2];

            % Selected detector details.
            detailsAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            detailsAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strDetectorDetailsTitle');

            detailsGridLayout = uigridlayout(detailsAccordionPanel);
            detailsGridLayout.RowHeight = {'fit', 200, 200};
            detailsGridLayout.ColumnWidth = {'1x'};

            detailsLabel = uilabel(detailsGridLayout);
            detailsLabel.Layout.Row = 1;
            detailsLabel.Layout.Column = 1;
            detailsLabel.FontWeight = "bold";

            memberMetricsTable = uitable(detailsGridLayout, SelectionType="row", ...
                Multiselect="off", ColumnSortable=true, ColumnWidth='1x');
            memberMetricsTable.SelectionChangedFcn = @(es,ed) MemberMetricsTableSelectionChangedFcn(weak_obj.Handle,es,ed);
            memberMetricsTable.Layout.Row = 2;
            memberMetricsTable.Layout.Column = 1;

            confusionPanel = uipanel(detailsGridLayout, Scrollable="off", BorderType="none");
            confusionPanel.Layout.Row = 3;
            confusionPanel.Layout.Column = 1;

            obj.Widgets = struct(...
                'ConfusionPanel', confusionPanel, ...
                'DetailsAccordionPanel', detailsAccordionPanel, ...
                'DetailsLabel', detailsLabel, ...
                'DetectorMetricsTable', detectorMetricsTable, ...
                'FigureDocument', fd, ...
                'MemberMetricsTable', memberMetricsTable, ...
                'MetricsAccordionPanel', metricsAccordionPanel, ...
                'MetricsAlertLabel', metricsAlertLabel);
        end

        function updateComparisonMetrics(obj)
            % Populate supervised training metrics
            state = obj.getState();

            % Save current warning state
            currentWarningState = warning;

            % Turn off a specific warning by its ID
            warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnF1SetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnF1SetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnFprSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnNoNormalLabel');

            T = cell2table(cell(0,6), ...
                'VariableNames', [ ...
                m('predmaint_anomaly:anomaly_app:strDetector'), ...
                m('predmaint_anomaly:anomaly_app:strF1Score'), ...
                m('predmaint_anomaly:anomaly_app:strFPRate'), ...
                m('predmaint_anomaly:anomaly_app:strPrecision'), ...
                m('predmaint_anomaly:anomaly_app:strRecall'), ...
                m('predmaint_anomaly:anomaly_app:strAccuracy')]);

            modelKeys = state.Models(:,1);
            for i = 1:numel(modelKeys)
                model = obj.ModelStore.getModel(modelKeys(i));

                if ~isempty(state.SelectedData) && isKey(model.DetectResults, state.SelectedData)
                    res = model.DetectResults{state.SelectedData};

                    predictions = cellfun(@(c) c.Labels, res, 'UniformOutput', false);

                    % Fetch the cross model common window definitions for the sample to window label converter function
                    [windowLength, detectionStride, obsWinLen] = model.Handler.getCommonWindowDefinitions(model.Model);

                    [~, ~, labels] = obj.DataStore.getData(state.SelectedData);
                    winLabels = anomalyCLI.internal.utils.sampleLabelsToWindowLabels(...
                        labels, windowLength, detectionStride, obsWinLen, model.Type);

                    M = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=true);
                else
                    M = struct('F1Score', NaN, 'FalsePositiveRate', NaN, ...
                        'Precision', NaN, 'Recall', NaN, 'Accuracy', NaN);
                end

                T = [T; {model.Name, M.F1Score, M.FalsePositiveRate, M.Precision, M.Recall, M.Accuracy}];
            end

            % Restore previous warning state
            warning(currentWarningState);

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.DetectorMetricsTable.Data, T)
                obj.Widgets.DetectorMetricsTable.Data = T;
            end
            idx = find(state.SelectedModel == modelKeys);
            obj.Widgets.DetectorMetricsTable.Selection = idx;

            removeStyle(obj.Widgets.DetectorMetricsTable);
            s = uistyle('FontColor', 'red');
            I = ismissing(T{:,:});
            [row,col] = find(I);
            addStyle(obj.Widgets.DetectorMetricsTable, s, "cell", [row(:),col(:)]);

            labelRow = obj.Widgets.MetricsAlertLabel.Layout.Row;
            if ~any(I, 'all')
                % No missing data. Hide the alert message.
                obj.Widgets.MetricsAlertLabel.Parent.RowHeight{labelRow} = 0;
            else
                % Show the alert message.
                obj.Widgets.MetricsAlertLabel.Parent.RowHeight{labelRow} = 'fit';
            end
        end

        function updateDetectorDetails(obj)
            % Show per-member detection metrics and confusion matrix for the
            % selected detector.
            state = obj.getState();

            if isempty(state.Models)
                obj.Widgets.DetailsLabel.Text = "";
                obj.Widgets.MemberMetricsTable.Data = [];
                delete(obj.Widgets.ConfusionPanel.Children);
                return;
            end

            idx = find(state.SelectedModel == state.Models(:,1));
            modelKey = state.Models(idx, 1);
            modelName = state.Models(idx, 2);
            model = obj.ModelStore.getModel(modelKey);

            obj.Widgets.DetailsLabel.Text = modelName;

            if isempty(state.SelectedData) || ~isKey(model.DetectResults, state.SelectedData)
                obj.Widgets.MemberMetricsTable.Data = [];
                delete(obj.Widgets.ConfusionPanel.Children);
                return;
            end

            res = model.DetectResults{state.SelectedData};
            predictions = cellfun(@(c) c.Labels, res, 'UniformOutput', false);

            [windowLength, detectionStride, obsWinLen] = model.Handler.getCommonWindowDefinitions(model.Model);
            [~, ~, labels] = obj.DataStore.getData(state.SelectedData);
            winLabels = anomalyCLI.internal.utils.sampleLabelsToWindowLabels(...
                labels, windowLength, detectionStride, obsWinLen, model.Type);

            % Suppress metric computation warnings.
            currentWarningState = warning;
            warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnPrecisionSetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnRecallSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnF1SetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnF1SetToOne');
            warning('off', 'predmaint_anomaly:anomaly:warnFprSetToZero');
            warning('off', 'predmaint_anomaly:anomaly:warnNoNormalLabel');

            M = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=false);
            % M_agg = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=true);

            warning(currentWarningState);

            % Per-member metrics table.
            numMembers = numel(predictions);
            members = arrayfun(@(i) m('predmaint_anomaly:anomaly_app:strMemberXOfY', i, numMembers), (1:numMembers)');

            T = table(members, M.F1Score, M.FalsePositiveRate, M.Precision, M.Recall, M.Accuracy, ...
                'VariableNames', [...
                m('predmaint_anomaly:anomaly_app:strDetectionData'), ...
                m('predmaint_anomaly:anomaly_app:strF1Score'), ...
                m('predmaint_anomaly:anomaly_app:strFPRate'), ...
                m('predmaint_anomaly:anomaly_app:strPrecision'), ...
                m('predmaint_anomaly:anomaly_app:strRecall'), ...
                m('predmaint_anomaly:anomaly_app:strAccuracy')]);

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.MemberMetricsTable.Data, T)
                obj.Widgets.MemberMetricsTable.Data = T;
            end
            obj.Widgets.MemberMetricsTable.Selection = obj.Workspace.SelectedMember;

            % Highlight missing values in red.
            removeStyle(obj.Widgets.MemberMetricsTable);
            s = uistyle('FontColor', 'red');
            I = ismissing(T{:,:});
            [row, col] = find(I);
            addStyle(obj.Widgets.MemberMetricsTable, s, "cell", [row(:), col(:)]);

            % Confusion matrix for the selected detector.
            delete(obj.Widgets.ConfusionPanel.Children);
            confusionchart(obj.Widgets.ConfusionPanel, ...
                M.ConfusionMatrix{obj.Workspace.SelectedMember}.Variables, ["Normal", "Anomaly"]);
        end

        function state = updateDirtyStates(obj, state, dataChanged)
            arguments
                obj
                state
                dataChanged (1,1) logical = false
            end

            if isempty(state.Models)
                state.AllModelsDetected = false;
                state.Detected = false;
                state.DirtyModel = false;
                state.DirtyFromLKGConfig = false;
            elseif isempty(state.SelectedData)
                state.AllModelsDetected = false;
                state.Detected = false;
                state.DirtyModel = false;
                state.DirtyFromLKGConfig = false;
            elseif dataChanged
                % Selected data was modified in place. Detection results are stale.
                % DirtyFromLKGConfig depends on model config, not data, so it is
                % computed normally.
                state.AllModelsDetected = false;
                state.DirtyModel = false;
                state.Detected = false;

                if ~isempty(state.SelectedModel)
                    selectedModel = obj.ModelStore.getModel(state.SelectedModel);
                    state.DirtyFromLKGConfig = ~isequaln(selectedModel.TipDetectConfig, selectedModel.LKGDetectConfig);
                else
                    state.DirtyFromLKGConfig = false;
                end
            else
                % There is at least one trained model, and there is a selected data
                % set. Check if all the models have detection results for the
                % selected data.
                allModelsDetected = true;
                dirtyModel = false;
                for iModel = 1:height(state.Models)
                    model = obj.ModelStore.getModel(state.Models(iModel,1));
                    % Detection results exist for the model if there is a
                    % key in the map for the selected data.
                    allModelsDetected = allModelsDetected && isKey(model.DetectionTimestamp, state.SelectedData);
                    if allModelsDetected
                        % If detection results exist, the model is dirty if
                        % training is more recent than detection.
                        dirtyModel = dirtyModel || (model.DetectionTimestamp(state.SelectedData) < model.TrainingTimestamp);
                    end
                end
                state.AllModelsDetected = allModelsDetected;
                state.DirtyModel = dirtyModel;

                % Track config dirty and detected state for the selected model.
                if ~isempty(state.SelectedModel)
                    selectedModel = obj.ModelStore.getModel(state.SelectedModel);
                    state.DirtyFromLKGConfig = ~isequaln(selectedModel.TipDetectConfig, selectedModel.LKGDetectConfig);
                    state.Detected = ~isempty(state.SelectedData) && isKey(selectedModel.DetectionTimestamp, state.SelectedData);
                else
                    state.DirtyFromLKGConfig = false;
                    state.Detected = false;
                end
            end
        end

        function selectedKey = selectModel(~, modelKeys)
            selectedKey = string.empty;
            if ~isempty(modelKeys)
                % There is a model to select.
                selectedKey = modelKeys(1);
            end
        end
    end
end

%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
