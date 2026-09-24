classdef Train < anomalyAPP.internal.app.AppComponent
    % Train tab.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strTrain')
        Tag (1,1) string = "train_tab"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener

        DataStore anomalyAPP.internal.utils.DataStore
        DataStoreListener event.listener

        App
    end

    events
        DetectDocumentRequest
        ExportDetectorRequest
    end

    methods
        function obj = Train(stateStore, modelStore, dataStore, app)
            key = anomalyAPP.internal.app.tab.Train.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            weakObj = matlab.lang.WeakReference(obj);

            obj.ModelStore = modelStore;
            obj.ModelStoreListener = listener(modelStore, 'ModelChanged', @(~,ed) cbModelChanged(weakObj.Handle,ed));

            obj.DataStore = dataStore;
            obj.DataStoreListener = listener(dataStore, 'DataChanged', @(~,ed) cbDataChanged(weakObj.Handle,ed));

            obj.App = app; % TODO: Don't do this if possible.

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function panel = getTab(obj)
            panel = obj.Widgets.Tab;
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'Data', string.empty(0,2), ...
                'SelectedData', string.empty, ...
                'SelectedModel', string.empty, ...
                'ModelTrained', false);
        end

        function reset(obj)
            state = obj.getDefaultState();
            modelKey = string.empty;
            dataKey = string.empty;

            % Initialize state from model store.
            info = obj.ModelStore.getModelNames();
            if ~isempty(info.keys)
                modelKey = info.keys(1);
            end

            % Initialize state from data store.
            info = obj.DataStore.findTrainingData();
            state.Data = [info.keys(:) info.names(:)];
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize state from Train document, if there is one.
            if obj.hasState("train_document")
                otherState = obj.getState("train_document");

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                end

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                end
            end

            if ~isempty(modelKey)
                model = obj.ModelStore.getModel(modelKey);
                state.ModelTrained = ~isempty(model.TrainingTimestamp);
            end

            state.SelectedModel = modelKey;
            state.SelectedData = dataKey;
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "train_document")
                otherState = obj.getState(ed.Name);
                state = obj.getState();

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                    state.SelectedModel = modelKey;

                    model = obj.ModelStore.getModel(modelKey);
                    state.ModelTrained = ~isempty(model.TrainingTimestamp);
                end

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                    state.SelectedData = dataKey;
                end

                obj.setState(state);
            end
        end

        function render_(obj, ~)
            state = obj.getState();
            if ~isempty(state.SelectedModel)
                model = obj.ModelStore.getModel(state.SelectedModel);
                obj.Widgets.ModelLabel.Text = model.Name;
            else
                obj.Widgets.ModelLabel.Text = "";
            end
            obj.Widgets.ExportButton.Enabled = state.ModelTrained;

            if ~isempty(state.SelectedData)
                I = state.Data(:,1) == state.SelectedData;
                obj.Widgets.DatasetLabel.Text = state.Data(I,2);
            else
                obj.Widgets.DatasetLabel.Text = string.empty;
            end
            obj.Widgets.TrainButton.Enabled = ~isempty(state.SelectedData);
        end
    end

    % Event management
    methods (Access = private)
        function requestDetectDocument(obj)
            state = obj.getState();
            key = state.SelectedModel;
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('DetectDocumentRequest', edata); % Defer to higher authority.
        end

        function exportSelectedDetector(obj)
            state = obj.getState();
            key = state.SelectedModel;
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('ExportDetectorRequest', edata); % Defer to higher authority.
        end

        function cbDataChanged(obj, ~)
            state = obj.getState();

            info = obj.DataStore.findTrainingData(); % Only the training dataset(s).
            state.Data = [info.keys(:) info.names(:)];

            if isempty(state.SelectedData) || ~any(state.SelectedData == info.keys)
                % No dataset is selected or the selected dataset is no longer available.
                if ~isempty(info.keys)
                    % There is a dataset to select.
                    state.SelectedData = info.keys(1);
                else
                    % No dataset available.
                    state.SelectedData = string.empty;
                end
            end

            obj.setState(state);
        end

        function cbModelChanged(obj, ~)
            state = obj.getState();

            info = obj.ModelStore.getModelNames(); % All models.

            if isempty(state.SelectedModel) || ~any(state.SelectedModel == info.keys)
                % No model is selected or the selected model is no longer available.
                if ~isempty(info.keys)
                    % There is a model to select.
                    state.SelectedModel = info.keys(1);
                else
                    % No models available.
                    state.SelectedModel = string.empty;
                end
            end

            % Training status of the selected model might have changed.
            if ~isempty(state.SelectedModel)
                model = obj.ModelStore.getModel(state.SelectedModel);
                state.ModelTrained = ~isempty(model.TrainingTimestamp);
            else
                state.ModelTrained = false;
            end

            obj.setState(state);
        end

        function cbTrainButtonPushedFcn(obj)
            % Create progressdlg as soon as the button is pushed. Fetching
            % data from the backend can take time if the data is large
            % Training in progress
            h = uiprogressdlg(obj.App.AppContainer, ...
                'Message', m('predmaint_anomaly:anomaly_app:strTrainingInProgress'),...
                'Indeterminate', 'on');

            % Disable Train button
            obj.Widgets.TrainButton.Icon = 'stop';
            obj.Widgets.TrainButton.Enabled = false;

            state = obj.getState();
            model = obj.ModelStore.getModel(state.SelectedModel);
            [dataStruct, ~, labels, normaldata] = obj.DataStore.getData(state.SelectedData); % Get the training data

            % Use holdout percentage to identify training data
            pct = dataStruct.ValidationHoldoutPercentage/100;
            if isscalar(normaldata)
                cvMode = "perSeries";
            else
                cvMode = "perCell";
            end
            cv = anomalyCLI.internal.utils.timeSeriesCvpartition(normaldata, Holdout=pct, Mode=cvMode);
            trainData = subset(cv, normaldata, true);
            validationData = subset(cv, normaldata, false);

            cc = model.TipConfig; % Get configurations to use

            try
                [model.Model, model.Monitor] = model.Handler.trainModel(trainData, cc);
                % Delete training progress dlg here so that we can open a
                % new progress dialog for validation data
                delete(h);

                % Update Threshold on detector options panel config
                model = model.Handler.updateTipDetectConfig(model);

                model.TrainingTimestamp = datetime('now', 'TimeZone', 'UTC');
                model.TrainingDataset = state.SelectedData; % Remember the training dataset name
                model.LKGConfig = model.TipConfig;

                model = validateModel(obj, model, validationData, trainData, state, ...
                    dataStruct, cv, labels);
                obj.ModelStore.setModel(state.SelectedModel, model);
            catch E
                delete(h);
                msg = m('predmaint_anomaly:anomaly_app:msgTrainingError', E.message);
                uialert(obj.App.AppContainer, msg, m('predmaint_anomaly:anomaly_app:strTrainingError'));
            end

            % Enable Train button
            obj.Widgets.TrainButton.Icon = 'run';
            obj.Widgets.TrainButton.Enabled = ~isempty(state.SelectedData);
        end

        function cbSaveAsButtonPushedFcn(obj)
            state = obj.getState();

            key = obj.ModelStore.duplicateModel(state.SelectedModel);
            targetModel = obj.ModelStore.getModel(key);

            % Update model store
            obj.ModelStore.setModel(key, targetModel);

            % NOTE: setModel calls trigger a state update; so get the state again.
            state = obj.getState();
            state.SelectedModel = key;
            state.ModelTrained = ~isempty(targetModel.TrainingTimestamp);
            obj.setState(state);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            tab = matlab.ui.internal.toolstrip.Tab();
            tab.Title = obj.Title;
            tab.Tag = obj.Tag;

            % Detector section
            detectorSection = makeDetectorSection(obj);
            tab.add(detectorSection);

            % Train section
            trainSection = makeTrainSection(obj);
            tab.add(trainSection);

            % Detect section
            detectSection = makeDetectSection(obj);
            tab.add(detectSection);

            % Save section
            saveSection = makeSaveSection(obj);
            tab.add(saveSection);

            % Export section
            exportSection = makeExportSection(obj);
            tab.add(exportSection);

            % Persist
            obj.Widgets.Tab = tab;
        end

        function detectorSection = makeDetectorSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            dataLabel = Label(m('predmaint_anomaly:anomaly_app:strTrainingData') + ":");
            dataLabel.Description = m('predmaint_anomaly:anomaly_app:tipTrainingData');

            detectorLabel = Label(m('predmaint_anomaly:anomaly_app:strDetector') + ":");
            detectorLabel.Description = m('predmaint_anomaly:anomaly_app:tipSelectedDetector');

            datasetLabel = Label("");
            datasetLabel.Description = m('predmaint_anomaly:anomaly_app:tipTrainingData');

            selectedDetectorLabel = Label('');
            selectedDetectorLabel.Description = m('predmaint_anomaly:anomaly_app:tipSelectedDetector');

            % Layout
            detectorSection = Section(m('predmaint_anomaly:anomaly_app:strDataSection'));
            detectorSection.Tag = "train_tab_detector_section";

            col1 = Column();
            col1.add(dataLabel);
            col1.add(detectorLabel);
            col1.addEmptyControl();
            detectorSection.add(col1);

            col2 = Column();
            col2.add(datasetLabel);
            col2.add(selectedDetectorLabel);
            col2.addEmptyControl();
            detectorSection.add(col2);

            % Persist
            obj.Widgets.DatasetLabel = datasetLabel;
            obj.Widgets.ModelLabel = selectedDetectorLabel;
            obj.Widgets.DataModelSection = detectorSection;
        end

        function trainSection = makeTrainSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            trainButton = Button(m('predmaint_anomaly:anomaly_app:strTrain'), "run");
            trainButton.Description = m('predmaint_anomaly:anomaly_app:tipTrainButton');
            trainButton.Tag = 'train_tab_train';
            trainButton.ButtonPushedFcn = @(~,~) cbTrainButtonPushedFcn(weak_obj.Handle);

            % Layout
            trainSection = Section(m('predmaint_anomaly:anomaly_app:strTrain'));
            trainSection.Tag = "train_tab_train_section";

            col1 = Column();
            col1.add(trainButton);
            trainSection.add(col1);

            % Persist
            obj.Widgets.TrainButton = trainButton;
            obj.Widgets.TrainSection = trainSection;
        end

        function detectSection = makeDetectSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            detectButton = Button(m('predmaint_anomaly:anomaly_app:strDetect'), "goTo_detectionDocument");
            detectButton.Description = m('predmaint_anomaly:anomaly_app:tipDetectButton');
            detectButton.Tag = 'train_tab_goto_detect';
            detectButton.ButtonPushedFcn = @(~,~) requestDetectDocument(weak_obj.Handle);

            % Layout
            detectSection = Section(m('predmaint_anomaly:anomaly_app:strDetect'));
            detectSection.Tag = "train_tab_detect_section";

            col1 = Column();
            col1.add(detectButton);
            detectSection.add(col1);

            % Persist
            obj.Widgets.DetectButton = detectButton;
            obj.Widgets.DetectSection = detectSection;
        end

        function saveSection = makeSaveSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            saveButton = Button(m('predmaint_anomaly:anomaly_app:strDuplicateDetector'), "saveCopyAs");
            saveButton.Description = m('predmaint_anomaly:anomaly_app:tipDuplicateDetector');
            saveButton.Tag = 'train_tab_duplicate';
            saveButton.ButtonPushedFcn = @(~,~) cbSaveAsButtonPushedFcn(weak_obj.Handle);

            % Layout
            saveSection = Section(m('predmaint_anomaly:anomaly_app:strDuplicate'));
            saveSection.Tag = "train_tab_save_section";

            col1 = Column();
            col1.add(saveButton);
            saveSection.add(col1);

            % Persist
            obj.Widgets.SaveButton = saveButton;
            obj.Widgets.SaveSection = saveSection;
        end

        function exportSection = makeExportSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            exportButton = Button(m('predmaint_anomaly:anomaly_app:strExportDetectorButton'), "export_data");
            exportButton.Description = m('predmaint_anomaly:anomaly_app:tipExportDetectorButton');
            exportButton.Tag = 'train_tab_export';
            exportButton.ButtonPushedFcn = @(~,~) exportSelectedDetector(weak_obj.Handle);

            % Layout
            exportSection = Section(m('predmaint_anomaly:anomaly_app:strExport'));
            exportSection.Tag = "train_tab_export_section";

            col1 = Column();
            col1.add(exportButton);
            exportSection.add(col1);

            % Persist
            obj.Widgets.ExportButton = exportButton;
            obj.Widgets.ExportSection = exportSection;
        end

        function model = validateModel(obj, model, validationData, trainData, state, ...
                dataStruct, cv, labels)
            try
                % For larger data sizes or hold out percentages,
                % validation metric computation can take several
                % seconds.

                % The new detector trained will always have the default Detection Config.
                % For the retraining case (Train -> Detect with config
                % changes -> Train) the new model must update itself to the
                % LKG Detection config. Setting the LKGDetectConfig in the modelStore
                % model to force an update during the call to
                % Handler.detect() in computeValidationMetrics
                model.LKGDetectConfig = model.Handler.defaultDetectConfig;

                % Compute validation metrics
                hVal = uiprogressdlg(obj.App.AppContainer, ...
                    'Message', m('predmaint_anomaly:anomaly_app:strValidationInProgress'),...
                    'Indeterminate', 'on');
                model = anomalyAPP.internal.utils.computeValidationMetrics(model, validationData, trainData, state.SelectedData, dataStruct.LabelIndex, cv, labels);
                delete(hVal);
            catch E
                delete(hVal);

                if strcmpi(E.identifier, "predmaint_anomaly:anomaly:errMaxWindowLength")
                    msg = m('predmaint_anomaly:anomaly_app:errInsufficientDataForValidation');
                else
                    msg = E.message; % m('predmaint_anomaly:anomaly_app:errGenericValidationError');
                end
                uialert(obj.App.AppContainer, msg, ...
                    m('predmaint_anomaly:anomaly_app:strValidationError'));
            end
        end
    end
end

% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
