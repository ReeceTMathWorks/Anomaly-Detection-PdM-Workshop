classdef Train < anomalyAPP.internal.app.AppComponent
    % Train document.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strTrain')
        Tag (1,1) string = "train_document"
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

        DetectorOverview (1,1) dictionary = configureDictionary("string", "cell")
    end

    methods
        function obj = Train(stateStore, modelStore, dataStore, detectorOverview)
            key = anomalyAPP.internal.app.document.Train.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            weakObj = matlab.lang.WeakReference(obj);

            obj.ModelStore = modelStore;
            obj.ModelStoreListener = listener(modelStore, 'ModelChanged', @(~,ed) cbModelChanged(weakObj.Handle,ed));

            obj.DataStore = dataStore;
            obj.DataStoreListener = listener(dataStore, 'DataChanged', @(~,ed) cbDataChanged(weakObj.Handle,ed));

            obj.DetectorOverview = detectorOverview;

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
                'TrainingTimestamp', [], ... % Datetime timestamp in UTC indicating when the current model was last trained
                'DirtyConfig', false, ... % Logical flag indicating whether the current model has a dirty training configuration
                'DirtyResults', true); % Logical flag indicating whether the training results plots are dirty for the current model
        end

        function reset(obj)
            state = obj.getDefaultState();
            dataKey = string.empty;

            % Initialize state from model store.
            info = obj.ModelStore.getModelNames();
            modelKey = selectModel(obj, info.keys); % Can be empty.

            % Initialize state from data store.
            info = obj.DataStore.findTrainingData(); % Only the training dataset(s).
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize state from data browser, if there is one.
            if obj.hasState("data_panel")
                otherState = obj.getState("data_panel");
                I = otherState.DataTable.isSelected & otherState.DataTable.isTrainingData;
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
            if (ed.Name == "train_tab")
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
            if ~state.Trained || state.DirtyConfig
                str = str + "*";
            end
            description = m('predmaint_anomaly:anomaly_app:descTraining', model.Name);
            obj.Widgets.FigureDocument.Title = str;
            obj.Widgets.FigureDocument.Description = description;

            % Update the model overview if the model has changed
            if ~strcmp(obj.Widgets.ModelName.Text, model.Name)
                delete(obj.Widgets.OverviewPanel.Children)
                obj.Widgets.ScoringDescription.Text = model.Handler.ScoringDescription;
                obj.Widgets.BestSuitedFor.Text = model.Handler.BestSuitedDescription;
                obj.Widgets.TuningRecommendation.Text = model.Handler.TuningRecommendationDescription;

                modelOverview = obj.DetectorOverview(model.Type);
                model.Handler.fillOverviewDiagram(obj.Widgets.OverviewPanel, modelOverview)
                obj.Widgets.ModelName.Text = model.Name;
            end

            % Update the model status and alert box based on the trained
            % state of the model
            fig = obj.Widgets.FigureDocument.Figure;
            if isempty(state.SelectedData)
                status = m('predmaint_anomaly:anomaly_app:strUntrained');
                setAlertBoxMessage(fig, "warning", m('predmaint_anomaly:anomaly_app:msgImportToGetStarted'));
            elseif ~state.Trained
                status = m('predmaint_anomaly:anomaly_app:strUntrained');
                setAlertBoxMessage(fig, "info", m('predmaint_anomaly:anomaly_app:msgPressTrain'));
            else
                status = m('predmaint_anomaly:anomaly_app:strTrained');
                setAlertBoxMessage(fig);
            end
            obj.Widgets.ModelStatus.Text = status;

            % If the results are dirty, redraw them on the document
            if state.Trained && (state.DirtyResults || force)
                obj.updateTrainingResults(model);
                obj.updateTrainingMetrics(model);
            end

            % Show/hide panels
            obj.Widgets.OverviewAccordionPanel.Collapsed = state.Trained;
            obj.Widgets.HistogramAccordionPanel.Visible = state.Trained;
            obj.Widgets.MetricsAccordionPanel.Visible = state.Trained;
            obj.Widgets.LossAccordionPanel.Visible = state.Trained && (model.Handler.DetectorType == "DeepLearning");
        end
    end

    % Event management
    methods (Access = private)
        function cbDataChanged(obj, ed)
            state = obj.getState();

            info = obj.DataStore.findTrainingData(); % Only the training dataset(s).

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
                % Selected data was modified in place — training is stale.
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
                % TODO: Call some update/plot function for per-member updates, when available.
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Figure Document
            trainOptions.Tag = obj.Tag;
            trainOptions.Closable = false;
            fd = matlab.ui.internal.FigureDocument(trainOptions);

            mainContainer = uigridlayout(fd.Figure);
            mainContainer.RowHeight = {'fit', '1x'};
            mainContainer.ColumnWidth = {'1x'};

            alertBox = anomalyAPP.internal.utils.makeAlertBox(mainContainer, "message");
            alertBox.Layout.Row = 1;
            alertBox.Layout.Column = 1;

            scrollContainer = uigridlayout(mainContainer);
            scrollContainer.Layout.Row = 2;
            scrollContainer.Layout.Column = 1;
            scrollContainer.RowHeight = {'fit', 'fit', 'fit'};
            scrollContainer.ColumnWidth = {'fit', 'fit', '1x'};
            scrollContainer.Scrollable = 'on';

            modelNameLabel = uilabel(scrollContainer);
            modelNameLabel.Layout.Row = 1;
            modelNameLabel.Layout.Column = 1;
            modelNameLabel.Text = m('predmaint_anomaly:anomaly_app:strModel')+":";

            modelName = uilabel(scrollContainer);
            modelName.Layout.Row = 1;
            modelName.Layout.Column = 2;

            modelStatusLabel = uilabel(scrollContainer);
            modelStatusLabel.Layout.Row = 2;
            modelStatusLabel.Layout.Column = 1;
            modelStatusLabel.Text = m('predmaint_anomaly:anomaly_app:strStatusTitle')+":";

            modelStatus = uilabel(scrollContainer);
            modelStatus.Layout.Row = 2;
            modelStatus.Layout.Column = 2;

            % Accordion panels
            accordion = matlab.ui.container.internal.Accordion('Parent', scrollContainer);
            accordion.Layout.Row = 3;
            accordion.Layout.Column = [1 3];

            % Overview panel
            overviewAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            overviewAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strOverviewTitle');

            overviewGridLayout = uigridlayout(overviewAccordionPanel);
            overviewGridLayout.RowHeight = {'fit','fit', 'fit', 'fit', 'fit', 'fit'};
            overviewGridLayout.ColumnWidth = {'2x', '1x'};

            % Scoring Technique Description
            scoringDescriptionLabel = uilabel(overviewGridLayout);
            scoringDescriptionLabel.Layout.Row = 1;
            scoringDescriptionLabel.Layout.Column = 1;
            scoringDescriptionLabel.Text = m('predmaint_anomaly:anomaly_app:strDetectionTechniqueTitle')+":";

            scoringDescription = uilabel(overviewGridLayout);
            scoringDescription.Layout.Row = 2;
            scoringDescription.Layout.Column = 1;
            scoringDescription.Text = '';
            scoringDescription.WordWrap = 'on';

            % Detector Best Suited For
            bestSuitedForLabel = uilabel(overviewGridLayout);
            bestSuitedForLabel.Layout.Row = 3;
            bestSuitedForLabel.Layout.Column = 1;
            bestSuitedForLabel.Text = m('predmaint_anomaly:anomaly_app:strBestSuitedForTitle')+":";

            bestSuitedFor = uilabel(overviewGridLayout);
            bestSuitedFor.Layout.Row = 4;
            bestSuitedFor.Layout.Column = 1;
            bestSuitedFor.Text = '';
            bestSuitedFor.WordWrap = 'on';

            % Detector Tuning Recommendation
            tuningRecommendationLabel = uilabel(overviewGridLayout);
            tuningRecommendationLabel.Layout.Row = 5;
            tuningRecommendationLabel.Layout.Column = 1;
            tuningRecommendationLabel.Text = m('predmaint_anomaly:anomaly_app:strDetectorTuningTitle')+":";

            tuningRecommendation = uilabel(overviewGridLayout);
            tuningRecommendation.Layout.Row = 6;
            tuningRecommendation.Layout.Column = 1;
            tuningRecommendation.Text = '';
            tuningRecommendation.WordWrap = 'on';

            % Overview Panel to host info diagram
            overviewPanel = uipanel(overviewGridLayout, 'BorderType','none');
            overviewPanel.Layout.Row = [1 6];
            overviewPanel.Layout.Column = [2 3];

            % Histogram panel
            histogramAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            histogramAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strValidationScoreDistributionTitle');

            histogramGridLayout = uigridlayout(histogramAccordionPanel);
            histogramGridLayout.RowHeight = {'1x'};
            histogramGridLayout.ColumnWidth = {'1x'};

            histogramPlotAxes = uiaxes(histogramGridLayout, 'Box', 'on');
            histogramPlotAxes.Layout.Row = 1;
            histogramPlotAxes.Layout.Column = 1;

            % Training metrics
            metricsAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            metricsAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strTrainingMetricsTitle');

            metricsGridLayout = uigridlayout(metricsAccordionPanel);
            metricsGridLayout.RowHeight = {0, 'fit', 160, 'fit', 160};
            metricsGridLayout.ColumnWidth = {'1x', '1x'};

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

            aggregateMetricsTitle = uilabel(metricsGridLayout);
            aggregateMetricsTitle.Layout.Row = 2;
            aggregateMetricsTitle.Layout.Column = [1 2];
            aggregateMetricsTitle.FontWeight = "bold";

            aggregateMetricsTable = uitable(metricsGridLayout, SelectionType="row", ...
                Multiselect="off", ColumnWidth='1x');
            aggregateMetricsTable.Layout.Row = 3;
            aggregateMetricsTable.Layout.Column = 1;

            confusionPlotPanel = uipanel(metricsGridLayout, "BorderType", "none");
            confusionPlotPanel.Layout.Row = 3;
            confusionPlotPanel.Layout.Column = 2;

            memberMetricsTitle = uilabel(metricsGridLayout);
            memberMetricsTitle.Layout.Row = 4;
            memberMetricsTitle.Layout.Column = [1 2];
            memberMetricsTitle.Text = "Per Member Metrics";
            memberMetricsTitle.FontWeight = "bold";

            memberMetricsTable = uitable(metricsGridLayout, SelectionType="row", ...
                Multiselect="off", ColumnSortable=true, ColumnWidth='1x');
            memberMetricsTable.SelectionChangedFcn = @(es,ed) MemberMetricsTableSelectionChangedFcn(weak_obj.Handle,es,ed);
            memberMetricsTable.Layout.Row = 5;
            memberMetricsTable.Layout.Column = [1 2];
            memberMetricsTable.Visible = "off";

            % Training metrics panel
            lossAccordionPanel = matlab.ui.container.internal.AccordionPanel('Parent', accordion);
            lossAccordionPanel.Title = m('predmaint_anomaly:anomaly_app:strTrainingLossFcnTitle');

            lossGridLayout = uigridlayout(lossAccordionPanel);
            lossGridLayout.RowHeight = {'1x'};
            lossGridLayout.ColumnWidth = {'1x'};

            lossPlotPanel = uipanel(lossGridLayout);
            lossPlotPanel.Layout.Row = 1;
            lossPlotPanel.Layout.Column = 1;

            % We need a secondary axes for vaelstm
            lossPlotPanelSecondary = uipanel(lossGridLayout);
            lossPlotPanelSecondary.Layout.Row = 1;
            lossPlotPanelSecondary.Layout.Column = 1;
            lossPlotPanelSecondary.Visible = "off";

            % Store all widgets on Train document.
            obj.Widgets = struct(...
                'AggregateMetricsTable', aggregateMetricsTable,...
                'AggregateMetricsTitle', aggregateMetricsTitle, ...
                'BestSuitedFor', bestSuitedFor, ...
                'BestSuitedForLabel', bestSuitedForLabel, ...
                'ConfusionPlotPanel', confusionPlotPanel,...
                'FigureDocument', fd, ...
                'HistogramAccordionPanel', histogramAccordionPanel, ...
                'HistogramPlotAxes', histogramPlotAxes, ...
                'LossAccordionPanel', lossAccordionPanel, ...
                'LossPlotPanel', lossPlotPanel, ...
                'LossPlotPanelSecondary', lossPlotPanelSecondary,...
                'MemberMetricsTable', memberMetricsTable, ...
                'MemberMetricsTitle', memberMetricsTitle,...
                'MetricsAccordionPanel', metricsAccordionPanel, ...
                'MetricsAlertLabel', metricsAlertLabel,...
                'ModelName', modelName, ...
                'ModelStatus', modelStatus, ...
                'OverviewAccordionPanel', overviewAccordionPanel, ...
                'OverviewPanel', overviewPanel, ...
                'ScoringDescription', scoringDescription, ...
                'ScoringDescriptionLabel', scoringDescriptionLabel, ...
                'TuningRecommendation', tuningRecommendation, ...
                'TuningRecommendationLabel', tuningRecommendationLabel);
        end

        function updateTrainingMetrics(obj, model)
            % Populate unsupervised training metrics
            state = obj.getState();

            validationData = model.ValidationResults(state.SelectedData);
            D_aggregate = validationData.DatasetMetrics; % Aggregate metrics table on validation data
            D = validationData.MemberMetrics; % Member level metrics table on validation data
            scores = validationData.AnomalyScores; % anomalyScores on validation data
            numValidationMembers = validationData.NumValidationMembers; % Number of members in the ValidationDataset
            numTotalMembers = validationData.TotalNumDatasetMembers; % Total number of members in the data
            numValidationSamples = validationData.NumValidationSamples;
            validationHoldout = validationData.ValidationHoldout;

            % Update text metrics
            metrics = [m('predmaint_anomaly:anomaly_app:strF1Score'); ...
                m('predmaint_anomaly:anomaly_app:strFPRate'); ...
                m('predmaint_anomaly:anomaly_app:strPrecision'); ...
                m('predmaint_anomaly:anomaly_app:strRecall');...
                m('predmaint_anomaly:anomaly_app:strAccuracy')];
            aggregateScores = [D_aggregate.F1Score; ...
                D_aggregate.FalsePositiveRate;...
                D_aggregate.Precision; ...
                D_aggregate.Recall;...
                D_aggregate.Accuracy];

            T_aggregate = table(metrics, aggregateScores, 'VariableNames', ...
                ["Metrics", "Scores"]);

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.AggregateMetricsTable.Data, T_aggregate)
                obj.Widgets.AggregateMetricsTable.Data = T_aggregate;
            end

            % Apply style to AggregateMetricsTable
            removeStyle(obj.Widgets.AggregateMetricsTable);
            s = uistyle('FontColor', 'red');
            I = ismissing(T_aggregate{:,:});
            [row,col] = find(I);
            addStyle(obj.Widgets.AggregateMetricsTable, s, "cell", [row(:),col(:)]);

            % Add confusion plot
            confusionchart(obj.Widgets.ConfusionPlotPanel, D_aggregate.ConfusionMatrix{1}.Variables, ["Normal", "Anomaly"]);

            if numValidationMembers > 1
                obj.Widgets.AggregateMetricsTitle.Text = m('predmaint_anomaly:anomaly_app:strMultiMemberValidation', validationHoldout*100, numValidationMembers, numTotalMembers);
                obj.Widgets.MemberMetricsTable.Visible = "on";
            else
                if numTotalMembers == 1
                    obj.Widgets.AggregateMetricsTitle.Text = m('predmaint_anomaly:anomaly_app:strSingleMemberValidation', validationHoldout*100, numValidationSamples);
                else
                    obj.Widgets.AggregateMetricsTitle.Text = m('predmaint_anomaly:anomaly_app:strMultiMemberValidation', validationHoldout*100, numValidationMembers, numTotalMembers);
                end
                obj.Widgets.MemberMetricsTable.Visible = "off";
                obj.Widgets.MemberMetricsTitle.Text = "";
            end

            members = arrayfun(@(i) m('predmaint_anomaly:anomaly_app:strMemberXOfY', i, numTotalMembers), (numTotalMembers-numValidationMembers+1:numTotalMembers)');
            T = table(members, D.F1Score, D.FalsePositiveRate, D.Precision, D.Recall, D.Accuracy, ...
                'VariableNames', [...
                m('predmaint_anomaly:anomaly_app:strTrainingData'), ...
                m('predmaint_anomaly:anomaly_app:strF1Score'), ...
                m('predmaint_anomaly:anomaly_app:strFPRate'), ...
                m('predmaint_anomaly:anomaly_app:strPrecision'), ...
                m('predmaint_anomaly:anomaly_app:strRecall'),...
                m('predmaint_anomaly:anomaly_app:strAccuracy')]);

            % Only update if the table data is different.
            if ~isequaln(obj.Widgets.MemberMetricsTable.Data, T)
                obj.Widgets.MemberMetricsTable.Data = T;
            end
            obj.Widgets.MemberMetricsTable.Selection = obj.Workspace.SelectedMember;

            % Apply style to MemberMetricsTable
            removeStyle(obj.Widgets.MemberMetricsTable);
            s = uistyle('FontColor', 'red');
            I = ismissing(T{:,:});
            [row,col] = find(I);
            addStyle(obj.Widgets.MemberMetricsTable, s, "cell", [row(:),col(:)]);

            labelRow = obj.Widgets.MetricsAlertLabel.Layout.Row;
            if ~any(I, 'all')
                % No missing data. Hide the alert message
                obj.Widgets.MetricsAlertLabel.Parent.RowHeight{labelRow} = 0;
            else
                % Show the alert message
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
            anomalyCLI.internal.utils.AnomalyDetection.plotHistogram(...
                obj.Widgets.HistogramPlotAxes, {allScores}, threshold);
        end

        function updateTrainingResults(obj, model)
            if model.Handler.DetectorType == "DeepLearning"
                % Set progressdlg parent to LossPlotPanel
                pnlHndl = obj.Widgets.LossPlotPanel;

                if isvalid(pnlHndl.Children)
                    pnlHndl.Children.Parent = [];
                end
                % Recreate training progress plot
                model.Monitor(1).createNewView(pnlHndl);

                % For the vaelstm case
                secondPnlHndl = obj.Widgets.LossPlotPanelSecondary;
                if (numel(model.Monitor) == 2)
                    % The secondPanel needs to be made visible and repositioned.
                    model.Monitor(2).createNewView(secondPnlHndl);
                    secondPnlHndl.Layout.Row = 2;
                    secondPnlHndl.Visible = "on";
                else
                    secondPnlHndl.Visible = "off";
                end
            end
        end

        function state = updateDirtyStates(obj, state, dataChanged)
            arguments
                obj
                state
                dataChanged (1,1) logical = false
            end

            if isempty(state.SelectedModel)
                state.Trained = false;
                state.TrainingTimestamp = [];
                state.DirtyConfig = false;
                state.DirtyResults = true;
            elseif isempty(state.SelectedData)
                state.Trained = false;
                state.TrainingTimestamp = [];

                model = obj.ModelStore.getModel(state.SelectedModel);
                state.DirtyConfig = ~isequaln(model.TipConfig, model.LKGConfig);
                state.DirtyResults = true;
            elseif dataChanged
                % Selected data was modified in place. Only reset data-dependent
                % states. DirtyConfig depends on model config, not data, so it is
                % computed normally.
                state.Trained = false;
                state.TrainingTimestamp = [];

                model = obj.ModelStore.getModel(state.SelectedModel);
                state.DirtyConfig = ~isequaln(model.TipConfig, model.LKGConfig);
                state.DirtyResults = true;
            else
                model = obj.ModelStore.getModel(state.SelectedModel);

                % Check if the model has been trained on the currently selected data.
                state.Trained = ~isempty(model.TrainingTimestamp) && ...
                    (model.TrainingDataset == state.SelectedData);

                % Check if the model's training configuration is different than the
                % LKG training configuration.
                state.DirtyConfig = ~isequaln(model.TipConfig, model.LKGConfig);

                % Redraw if the model is trained and the results were from a
                % different training.
                state.DirtyResults = state.Trained && ...
                    (isempty(state.TrainingTimestamp) || ...
                    (model.TrainingTimestamp ~= state.TrainingTimestamp));

                % Update the training timestamp with the value for the selected
                % model.
                if state.Trained
                    state.TrainingTimestamp = model.TrainingTimestamp;
                else
                    state.TrainingTimestamp = []; % No training results yet for the selected data.
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
