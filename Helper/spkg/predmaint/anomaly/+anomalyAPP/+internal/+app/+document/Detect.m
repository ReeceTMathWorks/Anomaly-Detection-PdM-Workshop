classdef Detect < anomalyAPP.internal.app.AppComponent
    % Detect document.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strDetect')
        Tag (1,1) string = "detect_document"
    end

    properties (Access = public)
        Widgets
        Workspace = struct('Location', 1, 'SelectedMember', 1)
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener

        DataStore anomalyAPP.internal.utils.DataStore
        DataStoreListener event.listener
    end

    methods
        function obj = Detect(stateStore, modelStore, dataStore)
            key = anomalyAPP.internal.app.document.Detect.Tag;
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
            state.SelectedModel = key;
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
                'SelectedModel', string.empty, ...
                'SelectedData', string.empty, ...
                'Trained', false, ... % Logical flag indicating whether the current model is trained
                'Detected', false, ... % Logical flag indicating whether the current model has been used for detection with the current data
                'DetectionTimestamp', [], ... % Datetime timestamp in UTC indicating when the current model was last detected on the current data
                'DirtyFromExecutionConfig', false, ... % Logical flag indicating whether the current model has a dirty detection configuration compared to what was used when computing the current results
                'DirtyFromLKGConfig', false, ... % Logical flag indicating whether the current detector config is different than the LKG config stored in the actual detector object
                'DirtyModel', false, ... % Logical flag indicating whether the current model has been re-trained since the last detection with the current data
                'DirtyResults', true); % Logical flag indicating whether the detection results plots are dirty for the current model/data combination. Value is also true if no detection results exist yet for the model/data.
        end

        function reset(obj)
            state = obj.getDefaultState();
            dataKey = string.empty;

            % Initialize state from model store.
            info = obj.ModelStore.getModelNames();
            modelKey = selectModel(obj, info.keys); % Can be empty.

            % Initialize state from data store.
            info = obj.DataStore.getDataNames();
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize state from data browser, if there is one.
            if obj.hasState("data_panel")
                otherState = obj.getState("data_panel");
                I = otherState.DataTable.isSelected;
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
            if (ed.Name == "detect_tab")
                otherState = obj.getState(ed.Name);
                state = obj.getState();

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                    state.SelectedModel = modelKey;
                end

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

        function render_(obj, force)
            arguments
                obj
                force (1,1) logical = false
            end
            import anomalyAPP.internal.utils.setAlertBoxMessage;

            state = obj.getState();
            model = obj.ModelStore.getModel(state.SelectedModel);

            if isempty(model)
                return;
            end

            % Update the document properties
            str = sprintf("%s: %s", obj.Title, model.Name);
            if ~state.Detected || state.DirtyFromExecutionConfig || state.DirtyFromLKGConfig || state.DirtyModel
                str = str + "*";
            end
            description = m('predmaint_anomaly:anomaly_app:descDetection', model.Name);
            obj.Widgets.FigureDocument.Title = str;
            obj.Widgets.FigureDocument.Description = description;
            obj.Widgets.ModelName.Text = model.Name;

            % Update the info/alert box based on the state of the detector
            fig = obj.Widgets.FigureDocument.Figure;
            if isempty(state.SelectedData)
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgImportToGetStarted'));
            elseif ~state.Trained
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgMustTrainBeforeDetect'));
            elseif ~state.Detected
                setAlertBoxMessage(fig, "info", m('predmaint_anomaly:anomaly_app:msgPressDetect'));
            elseif state.DirtyModel
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgDetectorRetrained'));
            elseif state.DirtyFromExecutionConfig
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgDetectorDirtySinceExecution'));
            else
                setAlertBoxMessage(fig);
            end

            % If the results are dirty, redraw them on the document
            if state.Detected && (state.DirtyResults || force)
                updateDetectionMetrics(obj, model);
                updateAnomalyPlot(obj);
            end

            % Show/hide panels
            obj.Widgets.HistogramAccordionPanel.Visible = state.Detected;
            obj.Widgets.MetricsAccordionPanel.Visible = state.Detected;
            obj.Widgets.TimeSeriesAccordionPanel.Visible = state.Detected;
            obj.Widgets.ScoresAccordionPanel.Visible = state.Detected;
        end
    end

    % Event management
    methods (Access = private)
        function cbDataChanged(obj, ed)
            state = obj.getState();

            info = obj.DataStore.getDataNames(); % All datasets.

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
                % Selected data was modified in place — detection is stale.
                state = obj.updateDirtyStates(state, true);
            end

            obj.setState(state);
        end

        function cbModelChanged(obj, ~)
            state = obj.getState();

            info = obj.ModelStore.getModelNames(); % All models.

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

        function MemberMetricsTableSelectionChangedFcn(obj, ~, ed)
            if ~isempty(ed.Selection)
                obj.Workspace.SelectedMember = ed.Selection;
                updateAnomalyPlot(obj);
            end
        end

        function AnomalyTableSelectionChangedFcn(obj, es, ed)
            if ~isempty(ed.Selection)
                obj.Workspace.Location = es.Data{ed.Selection,1}; % Anomaly location.
                updateAnomalyPlot(obj);
            end
        end

        function SelectFcn(obj, fig, ed)
            hoverObj = ed.HitObject;
            hoverAxes = ancestor(hoverObj, 'axes');

            % Return if the axis is already in an interactive mode.
            axesInMode = matlab.graphics.interaction.internal.containsAxesInMode(hoverAxes);
            if axesInMode
                return;
            end

            % Clickable and draggable objects.
            targetAxes = findobj(fig, 'Type', 'axes', {'Tag', 'signal_anomalies_axes'});
            dragTarget = findobj(targetAxes, {'Tag', 'zoom_location'});
            clickLines = findobj(targetAxes, 'Type', 'line', ...
                {'Tag', 'raw_signal', '-or', 'Tag', 'detected_anomalies'});
            clickTargets = [clickLines; targetAxes];

            if ~isempty(dragTarget) && any(hoverObj == dragTarget)
                % Make selection lines more prominent.
                set(dragTarget, 'LineWidth', 2.5, 'Selected', 'on');

                %disableDefaultInteractivity(hoverAxes);

                fig.UserData.Document.ActiveObject = hoverObj;

                fig.UserData.HoverFcn.Enabled = false; % Stored by AnomalyDetector.
                fig.UserData.Document.SelectFcn.Enabled = false;

                fig.UserData.Document.DragFcn.Enabled = true;
                fig.UserData.Document.RestoreFcn.Enabled = true;
            elseif ~isempty(clickTargets) && any(hoverObj == clickTargets)
                loc = num2ruler(ed.IntersectionPoint(1), targetAxes.XAxis);
                obj.Workspace.Location = loc;
                updateAnomalyPlot(obj);
            end
        end

        function DragFcn(obj, fig, ed)
            hoverObj = ed.HitObject;
            activeObj = fig.UserData.Document.ActiveObject;

            % IntersectionPoint works only when hoverObj is an axes or a direct sibling.
            if (hoverObj == activeObj.Parent) || (hoverObj.Parent == activeObj.Parent)
                activeAxes = ancestor(activeObj, 'axes');
                XLim = activeAxes.XLim;

                loc = num2ruler(ed.IntersectionPoint(1), activeAxes.XAxis);
                loc = max(XLim(1), min(loc, XLim(2)));
                obj.Workspace.Location = loc;
                updateAnomalyPlot(obj);
            end
        end

        function RestoreFcn(~, fig, ~)
            activeObj = fig.UserData.Document.ActiveObject;
            activeAxes = ancestor(activeObj, 'axes');

            %enableDefaultInteractivity(activeAxes);

            fig.UserData.Document.ActiveObject = [];

            fig.UserData.HoverFcn.Enabled = true; % Stored by AnomalyDetector.
            fig.UserData.Document.SelectFcn.Enabled = true;

            fig.UserData.Document.DragFcn.Enabled = false;
            fig.UserData.Document.RestoreFcn.Enabled = false;

            % Restore non-selection line widths.
            h = findobj(activeAxes, {'Tag', 'zoom_location'});
            set(h, 'LineWidth', 1.5, 'Selected', 'off');
        end
    end

    methods (Access = private)
        function createComponents(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Figure Document
            detectOptions.Tag = obj.Tag;
            detectOptions.Closable = false;
            fd = matlab.ui.internal.FigureDocument(detectOptions);

            mainContainer = uigridlayout(fd.Figure);
            mainContainer.RowHeight = {'fit', '1x'};
            mainContainer.ColumnWidth = {'1x'};

            alertBox = anomalyAPP.internal.utils.makeAlertBox(mainContainer, "message");
            alertBox.Layout.Row = 1;
            alertBox.Layout.Column = 1;

            scrollContainer = uigridlayout(mainContainer);
            scrollContainer.Layout.Row = 2;
            scrollContainer.Layout.Column = 1;
            scrollContainer.RowHeight = {'fit', 'fit'};
            scrollContainer.ColumnWidth = {'fit', 'fit', '1x'};
            scrollContainer.Scrollable = 'on';

            modelNameLabel = uilabel(scrollContainer);
            modelNameLabel.Layout.Row = 1;
            modelNameLabel.Layout.Column = 1;
            modelNameLabel.Text = "Model: ";

            modelName = uilabel(scrollContainer);
            modelName.Layout.Row = 1;
            modelName.Layout.Column = 2;

            % Accordion panels
            accordion = matlab.ui.container.internal.Accordion('Parent', scrollContainer);
            accordion.Layout.Row = 2;
            accordion.Layout.Column = [1 3];

            % Histogram panel
            histogramAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            histogramAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strScoreDistributionTitle');

            datasetMetricsLayout = uigridlayout(histogramAccordionPanel);
            datasetMetricsLayout.RowHeight = {'1x', 'fit'};
            datasetMetricsLayout.ColumnWidth = {'1x', '1x'};

            histogramPlotAxes = uiaxes(datasetMetricsLayout, 'Box', 'on');
            histogramPlotAxes.Layout.Row = 1;
            histogramPlotAxes.Layout.Column = [1 2];

            datasetMetricsTable = uitable(datasetMetricsLayout, ColumnSortable=true, ColumnWidth='1x');
            datasetMetricsTable.Layout.Row = 2;
            datasetMetricsTable.Layout.Column = 1;

            confusionMatrixPanel = uipanel(datasetMetricsLayout, 'BorderType', 'none');
            confusionMatrixPanel.Layout.Row = 2;
            confusionMatrixPanel.Layout.Column = 2;

            % Per member metrics
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

            memberMetricsTable = uitable(metricsGridLayout, SelectionType="row", ...
                Multiselect="off", ColumnSortable=true, ColumnWidth='1x');
            memberMetricsTable.Tooltip = m('predmaint_anomaly:anomaly_app:strSummaryTableTip');
            memberMetricsTable.SelectionChangedFcn = @(es,ed) MemberMetricsTableSelectionChangedFcn(weak_obj.Handle,es,ed);
            memberMetricsTable.Layout.Row = 2;
            memberMetricsTable.Layout.Column = [1 2];

            % Time series plot with highlighted anomalies
            timeSeriesAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            timeSeriesAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strTimeSeriesAnomaliesTitle');

            tsAnomaliesGridLayout = uigridlayout(timeSeriesAccordionPanel);
            tsAnomaliesGridLayout.RowHeight = {600, 200};
            tsAnomaliesGridLayout.ColumnWidth = {'1x', '1x'};
            tsAnomaliesGridLayout.RowSpacing = 0;

            plotAxes = uiaxes(tsAnomaliesGridLayout, Box='on', ClippingStyle='rectangle');
            disableDefaultInteractivity(plotAxes); % Require explicit use of axis toolbar.
            plotAxes.Layout.Row = 1;
            plotAxes.Layout.Column = [1 2];

            anomalyTable = uitable(tsAnomaliesGridLayout, SelectionType="row", ...
                Multiselect="off", RowName='numbered', ColumnSortable=true, ColumnWidth='1x');
            anomalyTable.Layout.Row = 2;
            anomalyTable.Layout.Column = 1;
            anomalyTable.SelectionChangedFcn = @(es,ed) AnomalyTableSelectionChangedFcn(weak_obj.Handle,es,ed);

            zoomAxes = uiaxes(tsAnomaliesGridLayout, Box='on', ClippingStyle='rectangle', ...
                Tag='zoom_anomalies_axes');
            disableDefaultInteractivity(zoomAxes); % Require explicit use of axis toolbar.
            zoomAxes.Layout.Row = 2;
            zoomAxes.Layout.Column = 2;
            title(zoomAxes, m("predmaint_anomaly:anomaly_app:strZoomView"));

            % Anomaly scores plot
            scoresAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            scoresAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strAnomalyScoresTitle');

            anomalyScoresGridLayout = uigridlayout(scoresAccordionPanel);
            anomalyScoresGridLayout.RowHeight = {'1x'};
            anomalyScoresGridLayout.ColumnWidth = {'1x'};

            scoreAxes = uiaxes(anomalyScoresGridLayout, 'Box', 'on');
            scoreAxes.Layout.Row = 1;
            scoreAxes.Layout.Column = 1;

            % Store all widgets on Detect document.
            obj.Widgets = struct(...
                'AnomalyTable', anomalyTable, ...
                'FigureDocument', fd, ...
                'HistogramAccordionPanel', histogramAccordionPanel, ...
                'HistogramPlotAxes', histogramPlotAxes, ...
                'MemberMetricsTable', memberMetricsTable, ...
                'MetricsAccordionPanel', metricsAccordionPanel, ...
                'MetricsAlertLabel', metricsAlertLabel, ...
                'ModelName', modelName, ...
                'ConfusionMatrixPanel', confusionMatrixPanel, ...
                'DatasetMetricsTable', datasetMetricsTable, ...
                'PlotAxes', plotAxes, ...
                'ScoreAxes', scoreAxes, ...
                'ScoresAccordionPanel', scoresAccordionPanel, ...
                'TimeSeriesAccordionPanel', timeSeriesAccordionPanel, ...
                'ZoomAxes', zoomAxes);
        end

        function updateDetectionMetrics(obj, model)
            % Populate supervised training metrics
            state = obj.getState();
            mtest = obj.DataStore.getData(state.SelectedData);    % Get the testing data

            res = model.DetectResults{state.SelectedData};
            numMembers = mtest.Members;
            members = arrayfun(@(i) m('predmaint_anomaly:anomaly_app:strMemberXOfY', i, numMembers), (1:numMembers)');

            predictions = cellfun(@(c) c.Labels, res, 'UniformOutput', false);
            scores = cellfun(@(c) c.AnomalyScores, res, 'UniformOutput', false);

            if mtest.LabelIndex == 0
                % Warning management
                % Save current warning state
                currentWarningState = warning;

                % Turn off a specific warning by its ID
                warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedAllZero');
                warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedAllOne');
                warning('off', 'predmaint:plot:warnRanking_EntropyAlmostZeroVar');
                warning('off', 'predmaint_anomaly:anomaly:warnF1SetToZero');
                warning('off', 'predmaint_anomaly:anomaly:warnUnsupervisedOneSample');

                M = timeSeriesAnomalyMetrics(predictions, [], scores, Aggregation=false);
                M_aggregateTable = timeSeriesAnomalyMetrics(predictions, [], scores, Aggregation=true);
                M_aggregate = table2struct(M_aggregateTable);

                % Restore previous warning state
                warning(currentWarningState);

                T = table(members, M.AvgAnomalySeparation, M.FractionOfAnomalies, M.KLdivergence, M.NormalScoresRange, ...
                    'VariableNames', [ ...
                    m('predmaint_anomaly:anomaly_app:strDetectionData'), ...
                    m('predmaint_anomaly:anomaly_app:strAvgAnomalySeparation'), ...
                    m('predmaint_anomaly:anomaly_app:strFracOfAnomaly'), ...
                    m('predmaint_anomaly:anomaly_app:strKLDivergence'), ...
                    m('predmaint_anomaly:anomaly_app:strNormalScoreRng')]);

                % Dataset-level metrics table (unsupervised)
                datasetMetrics = [m('predmaint_anomaly:anomaly_app:strAvgAnomalySeparation'); ...
                    m('predmaint_anomaly:anomaly_app:strFracOfAnomaly'); ...
                    m('predmaint_anomaly:anomaly_app:strKLDivergence'); ...
                    m('predmaint_anomaly:anomaly_app:strNormalScoreRng')];
                datasetScores = [M_aggregate.AvgAnomalySeparation; ...
                    M_aggregate.FractionOfAnomalies; ...
                    M_aggregate.KLdivergence; ...
                    M_aggregate.NormalScoresRange];
                T_aggregate = table(datasetMetrics, datasetScores, 'VariableNames', ["Metrics", "Scores"]);

                % Confusion matrix not available for unlabeled data
                delete(obj.Widgets.ConfusionMatrixPanel.Children);
                g = uigridlayout(obj.Widgets.ConfusionMatrixPanel);
                g.RowHeight = {'1x'};
                g.ColumnWidth = {'1x'};
                lbl = uilabel(g, ...
                    'Text', m('predmaint_anomaly:anomaly_app:strConfusionMatrixUnavailable'), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'center', ...
                    'FontAngle', 'italic', ...
                    'WordWrap', 'on');
                lbl.Layout.Row = 1;
                lbl.Layout.Column = 1;
            else
                % Fetch the cross model common window definitions for the sample to window label converter function
                [windowLength, detectionStride, obsWinLen] = model.Handler.getCommonWindowDefinitions(model.Model);

                [~, ~, labels] = obj.DataStore.getData(state.SelectedData);
                winLabels = anomalyCLI.internal.utils.sampleLabelsToWindowLabels(...
                    labels, windowLength, detectionStride, obsWinLen, model.Type);

                % Warning management
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

                M = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=false);
                M_aggregateTable = timeSeriesAnomalyMetrics(predictions, winLabels, Aggregation=true);
                M_aggregate = table2struct(M_aggregateTable);

                % Restore previous warning state
                warning(currentWarningState);

                T = table(members, M.F1Score, M.FalsePositiveRate, M.Precision, M.Recall, M.Accuracy, ...
                    'VariableNames', [ ...
                    m('predmaint_anomaly:anomaly_app:strDetectionData'), ...
                    m('predmaint_anomaly:anomaly_app:strF1Score'), ...
                    m('predmaint_anomaly:anomaly_app:strFPRate'), ...
                    m('predmaint_anomaly:anomaly_app:strPrecision'), ...
                    m('predmaint_anomaly:anomaly_app:strRecall'), ...
                    m('predmaint_anomaly:anomaly_app:strAccuracy')]);

                % Dataset-level metrics table (supervised)
                datasetMetrics = [m('predmaint_anomaly:anomaly_app:strF1Score'); ...
                    m('predmaint_anomaly:anomaly_app:strFPRate'); ...
                    m('predmaint_anomaly:anomaly_app:strPrecision'); ...
                    m('predmaint_anomaly:anomaly_app:strRecall'); ...
                    m('predmaint_anomaly:anomaly_app:strAccuracy')];
                datasetScores = [M_aggregate.F1Score; ...
                    M_aggregate.FalsePositiveRate; ...
                    M_aggregate.Precision; ...
                    M_aggregate.Recall; ...
                    M_aggregate.Accuracy];
                T_aggregate = table(datasetMetrics, datasetScores, 'VariableNames', ["Metrics", "Scores"]);

                % Confusion matrix
                delete(obj.Widgets.ConfusionMatrixPanel.Children);
                confusionchart(obj.Widgets.ConfusionMatrixPanel, M_aggregate.ConfusionMatrix.Variables, ["Normal", "Anomaly"]);
            end

            % Update dataset-level metrics table (only for multi-member data).
            if numMembers > 1
                obj.Widgets.DatasetMetricsTable.Visible = "on";
                if ~isequaln(obj.Widgets.DatasetMetricsTable.Data, T_aggregate)
                    obj.Widgets.DatasetMetricsTable.Data = T_aggregate;
                end
            else
                obj.Widgets.DatasetMetricsTable.Visible = "off";
            end

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.MemberMetricsTable.Data, T)
                obj.Widgets.MemberMetricsTable.Data = T;
            end
            obj.Widgets.MemberMetricsTable.Selection = obj.Workspace.SelectedMember;

            removeStyle(obj.Widgets.MemberMetricsTable);
            s = uistyle('FontColor', 'red');
            I = ismissing(T{:,:});
            [row,col] = find(I);
            addStyle(obj.Widgets.MemberMetricsTable, s, "cell", [row(:),col(:)]);

            labelRow = obj.Widgets.MetricsAlertLabel.Layout.Row;
            if ~any(I, 'all')
                % No missing data. Hide the alert message.
                obj.Widgets.MetricsAlertLabel.Parent.RowHeight{labelRow} = 0;
            else
                % Show the alert message.
                obj.Widgets.MetricsAlertLabel.Parent.RowHeight{labelRow} = 'fit';
            end

            % Anomaly threshold.
            try
                threshold = model.Model.Threshold;
            catch E
                % Some algorithms do not have a Threshold property.
                threshold = NaN;
            end
            allScores = cat(1, scores{:});
            anomalyCLI.internal.utils.AnomalyDetection.plotHistogram( ...
                obj.Widgets.HistogramPlotAxes, {allScores}, threshold);
        end

        function updateAnomalyPlot(obj)
            state = obj.getState();
            member = obj.Workspace.SelectedMember;
            [metadata,time,labels,data] = obj.DataStore.getData(state.SelectedData, Member=member);

            % Only one member.
            time = time{1};
            labels = labels{1};
            data = data{1};

            model = obj.ModelStore.getModel(state.SelectedModel);
            res = model.DetectResults{state.SelectedData};

            if ~iscell(res)
                res = {res};
            end
            res = res{member};

            windowLength = model.Handler.getCommonWindowDefinitions(model.Model);

            % Time series anomalies plot.
            % Initialize or update when data types change.
            if isempty(obj.Widgets.PlotAxes.Children) || ...
                    ~strcmp(class(time(1)), class(obj.Workspace.Location))
                fig = ancestor(obj.Widgets.PlotAxes, 'figure');
                set(fig, 'NextPlot', 'replace'); % Will clear listeners if figure's content gets updated.

                anomalyCLI.internal.utils.AnomalyDetection.plotAnomalies(...
                    obj.Widgets.PlotAxes, data, metadata.ChannelNames, res, ...
                    windowLength, TrueLabels=labels, Time=time);

                obj.Workspace.Location = mean(time);

                % Zoom location drag line.
                h = xline(obj.Widgets.PlotAxes, time(1), ...
                    Tag='zoom_location', SeriesIndex=4, LineWidth=1.5, ...
                    Label=m("predmaint_anomaly:anomaly_app:strZoomLocation"), ...
                    LabelHorizontalAlignment='left', ...
                    DisplayName=m("predmaint_anomaly:anomaly_app:strZoomLocation"));
                h.Annotation.LegendInformation.IconDisplayStyle = 'off';

                % Zoom view.
                ndim = length(metadata.ChannelNames);
                cla(obj.Widgets.ZoomAxes);
                hold(obj.Widgets.ZoomAxes, 'on');

                h = plot(obj.Widgets.ZoomAxes, time(1), NaN(1,ndim), LineStyle='-', Tag='zoom_data');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                    'Color', '--mw-graphics-colorOrder-1-tertiary');

                h = plot(obj.Widgets.ZoomAxes, time(1), NaN(1,ndim), LineStyle='-', Tag='zoom_detected_anomalies');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                    'Color', '--mw-graphics-colorOrder-2-tertiary');
                hold(obj.Widgets.ZoomAxes, 'off');

                h = xline(obj.Widgets.ZoomAxes, time(1), ...
                    Tag='zoom_location', SeriesIndex=4, LineWidth=1.5, ...
                    DisplayName=m("predmaint_anomaly:anomaly_app:strZoomLocation"));
                h.Annotation.LegendInformation.IconDisplayStyle = 'off';

                weak_obj = matlab.lang.WeakReference(obj);
                fig.UserData.Document.SelectFcn = event.listener(fig, 'WindowMousePress', @(es,ed) SelectFcn(weak_obj.Handle,es,ed));
                fig.UserData.Document.DragFcn = event.listener(fig, 'WindowMouseMotion', @(es,ed) DragFcn(weak_obj.Handle,es,ed));
                fig.UserData.Document.RestoreFcn = event.listener(fig, 'WindowMouseRelease', @(es,ed) RestoreFcn(weak_obj.Handle,es,ed));

                fig.UserData.Document.SelectFcn.Enabled = true;
                fig.UserData.Document.DragFcn.Enabled = false;
                fig.UserData.Document.RestoreFcn.Enabled = false;
            end

            % Signals.
            anomalyCLI.internal.utils.AnomalyDetection.updateAnomalies(...
                obj.Widgets.PlotAxes, data, time, metadata.ChannelNames, res, ...
                windowLength, labels);
            str = m('predmaint_anomaly:anomaly_app:strMemberXOfY', member, metadata.Members);
            subtitle(obj.Widgets.PlotAxes, str);

            % Location line on signal plot.
            h = findobj(obj.Widgets.PlotAxes, 'Tag', 'zoom_location');
            h.Value = obj.Workspace.Location;

            % Zoom view. +/-3 x window size around zoom location.
            N = size(data,1);
            [~,idx] = min(abs(time-obj.Workspace.Location));
            I = max(1,idx-3*windowLength):min(idx+3*windowLength,N);
            I = I(:);

            h = findobj(obj.Widgets.ZoomAxes, 'Tag', 'zoom_data');
            for k = 1:numel(h)
                set(h(k), Xdata=time(I), YData=data(I,k));
            end
            %set(obj.Widgets.ZoomAxes, 'XLim', [min(time(I)), max(time(I))]);
            axis(obj.Widgets.ZoomAxes, 'padded');

            % Anomalies in zoom view.
            Istart = res.StartIndices(res.Labels);
            Iend = min((Istart + windowLength - 1), N);

            h = findobj(obj.Widgets.ZoomAxes, 'Tag', 'zoom_detected_anomalies');
            if ~isempty(h)
                for i = 1:size(data,2)
                    y = NaN(1,height(time));
                    % Locate anomalous windows.
                    for j = 1:numel(Istart)
                        J = max(Istart(j),idx-3*windowLength):min(idx+3*windowLength,Iend(j));
                        y(J) = data(J,i);
                    end
                    set(h(i), XData=time, YData=y);
                end
            end

            % Location line on zoom plot.
            h = findobj(obj.Widgets.ZoomAxes, 'Tag', 'zoom_location');
            h.Value = obj.Workspace.Location;

            % Anomaly table
            I = (res.Labels == true);
            location = time(res.StartIndices(I));
            score = res.AnomalyScores(I);
            T = table(location, score, 'VariableNames', [ ...
                m("predmaint_anomaly:anomaly_app:strAnomalyLocation"), ...
                m("predmaint_anomaly:anomaly_app:strAnomalyScore")]);

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.AnomalyTable.Data, T)
                prevSelection = obj.Widgets.AnomalyTable.Selection;
                obj.Widgets.AnomalyTable.Data = T;
                if (prevSelection < numel(score))
                    obj.Widgets.AnomalyTable.Selection = prevSelection;
                end
            end

            % Score plot
            % Anomaly threshold.
            try
                threshold = model.Model.Threshold;
            catch E
                % Some algorithms do not have a Threshold property.
                threshold = NaN;
            end

            if isempty(obj.Widgets.ScoreAxes.Children)
                anomalyCLI.internal.utils.AnomalyDetection.plotScores(...
                    obj.Widgets.ScoreAxes, res, threshold);
            end

            % Scores
            anomalyCLI.internal.utils.AnomalyDetection.updateScores(...
                obj.Widgets.ScoreAxes, res, threshold);
        end

        function state = updateDirtyStates(obj, state, dataChanged)
            arguments
                obj
                state
                dataChanged (1,1) logical = false
            end

            if isempty(state.SelectedModel)
                state.Trained = false;
                state.Detected = false;
                state.DetectionTimestamp = [];
                state.DirtyFromExecutionConfig = false;
                state.DirtyFromLKGConfig = false;
                state.DirtyModel = false;
                state.DirtyResults = true;
            elseif dataChanged
                % Selected data was modified in place. Only reset data-dependent
                % states. Trained and DirtyFromLKGConfig depend on model state, not
                % detection data, so they are computed normally.
                model = obj.ModelStore.getModel(state.SelectedModel);

                state.Trained = ~isempty(model.TrainingTimestamp);
                state.Detected = false;
                state.DetectionTimestamp = [];

                state.DirtyFromExecutionConfig = false;
                state.DirtyFromLKGConfig = ~isequaln(model.TipDetectConfig, model.LKGDetectConfig);

                state.DirtyModel = false;
                state.DirtyResults = true;
            else
                model = obj.ModelStore.getModel(state.SelectedModel);

                % Check if the model is trained
                state.Trained = ~isempty(model.TrainingTimestamp);

                % Check if the model has completed detection for the selected data
                state.Detected = ~isempty(state.SelectedData) && isKey(model.DetectionTimestamp, state.SelectedData);

                % Check if the model's LKG detection configuration is different than
                % when detection occurred for the selected data
                state.DirtyFromExecutionConfig = state.Detected && ...
                    ~isequaln(model.LKGDetectConfig, model.ExecutedDetectConfig(state.SelectedData)); % Dirty if detection has been computed and the config has changed since

                % Check if the model's current detection configuration is different
                % than the LKG stored in the model itself
                state.DirtyFromLKGConfig = ~isequaln(model.TipDetectConfig, model.LKGDetectConfig);

                % Check if the model has been retrained since its last detection on
                % the selected data
                state.DirtyModel = state.Detected && (model.DetectionTimestamp(state.SelectedData) < model.TrainingTimestamp);

                % Check if the results plots need to be updated based on when
                % detection occurred for the selected data
                state.DirtyResults = state.Detected && ...
                    (isempty(state.DetectionTimestamp) || model.DetectionTimestamp(state.SelectedData) ~= state.DetectionTimestamp); % Redraw if the model is detected on the current data and the results were from a different detection

                % Update the detection timestamp with the value from the selected
                % model/data
                if state.Detected
                    state.DetectionTimestamp = model.DetectionTimestamp(state.SelectedData);
                else
                    state.DetectionTimestamp = []; % No detection results yet for the selected data
                end
            end
        end

        function selectedKey = selectModel(obj, modelKeys)
            % If the model browser exists and has the same models (it is synced up),
            % then use the selection in the browser rather than the first model.
            selectedKey = string.empty;
            if ~isempty(modelKeys)
                % There is a model to select.
                selectedKey = modelKeys(1);

                if obj.hasState("model_panel")
                    otherState = obj.getState("model_panel");
                    browserKeys = otherState.ModelTable.Key;
                    if numel(modelKeys) == numel(browserKeys) && isempty(setdiff(modelKeys, browserKeys))
                        selectedKey = browserKeys(otherState.ModelTable.isSelected);
                    end
                end
            end
        end
    end
end

%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end

