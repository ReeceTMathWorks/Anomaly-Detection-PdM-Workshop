classdef Detect < anomalyAPP.internal.app.AppComponent
    % Detect tab.

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strDetect')
        Tag (1,1) string = "detect_tab"
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
        ImportDialogRequest
        ExportDetectorRequest
        ExportResultsDialogRequest
        TrainDocumentRequest
        CompareDocumentRequest
    end

    methods
        function obj = Detect(stateStore, modelStore, dataStore, app)
            key = anomalyAPP.internal.app.tab.Detect.Tag;
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
                'AllowDetect', false, ...
                'HasDetectionResult', false);
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
            info = obj.DataStore.getDataNames();
            state.Data = [info.keys(:) info.names(:)];
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize state from Detect document, if there is one.
            if obj.hasState("detect_document")
                otherState = obj.getState("detect_document");

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                end

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                end

                state.HasDetectionResult = otherState.Detected;
            end

            state.SelectedModel = modelKey;
            state.SelectedData = dataKey;

            if ~isempty(modelKey)
                model = obj.ModelStore.getModel(modelKey);
                state.AllowDetect = ~isempty(model.TrainingTimestamp);
            end

            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "detect_document")
                otherState = obj.getState(ed.Name);
                state = obj.getState();

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                    state.SelectedModel = modelKey;

                    model = obj.ModelStore.getModel(modelKey);
                    state.AllowDetect = ~isempty(model.TrainingTimestamp);
                end

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                    state.SelectedData = dataKey;
                end

                state.HasDetectionResult = otherState.Detected;

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

            obj.Widgets.DataDropDown.replaceAllItems(cellstr(state.Data));
            obj.Widgets.DataDropDown.Value = state.SelectedData;
            obj.Widgets.DataDropDown.Enabled = ~isempty(state.SelectedData);

            obj.Widgets.DetectButton.Enabled = state.AllowDetect;
            obj.Widgets.ExportDetectorItem.Enabled = state.AllowDetect;
            obj.Widgets.ExportResultsItem.Enabled = state.HasDetectionResult;
        end
    end

    % Event management
    methods (Access = private)
        function openImportDialog(obj)
            ed = anomalyAPP.internal.utils.EventData("ImportDialogRequest", struct('UseNewSession', false));
            obj.notify('ImportDialogRequest', ed);
        end

        function requestTrainDocument(obj)
            state = obj.getState();
            key = state.SelectedModel;
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('TrainDocumentRequest', edata); % Defer to higher authority.
        end

        function requestCompareDocument(obj)
            state = obj.getState();
            key = state.SelectedModel;
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('CompareDocumentRequest', edata); % Defer to higher authority.
        end

        function exportSelectedDetector(obj)
            state = obj.getState();
            key = state.SelectedModel;
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('ExportDetectorRequest', edata); % Defer to higher authority.
        end

        function exportDetectionResults(obj)
            state = obj.getState();
            edata = anomalyAPP.internal.utils.EventData('ExportResultsDialogRequest', ...
                struct('Data', state.SelectedData, 'Model', state.SelectedModel));
            obj.notify('ExportResultsDialogRequest', edata); % Defer to higher authority.
        end

        function cbDataChanged(obj, ~)
            state = obj.getState();

            info = obj.DataStore.getDataNames(); % All datasets.
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
                state.AllowDetect = ~isempty(model.TrainingTimestamp);
            else
                state.AllowDetect = false;
            end

            obj.setState(state);
        end

        function cbDataDropDownValueChangedFcn(obj, es)
            state = obj.getState();
            state.SelectedData = string(es.SelectedItem);
            obj.setState(state);
        end

        function cbDetectButtonPushedFcn(obj)
            % Create progressdlg at the beginning cause fetching data can take some
            % time if data is large
            % Detection in progress
            h = uiprogressdlg(obj.App.AppContainer, 'Title', '', ...
                'Message', m('predmaint_anomaly:anomaly_app:strDetecting'), ...
                'Indeterminate', 'on');

            % Disable Detect button
            obj.Widgets.DetectButton.Icon = 'stop';
            obj.Widgets.DetectButton.Enabled = false;

            state = obj.getState();
            model = obj.ModelStore.getModel(state.SelectedModel);
            [~, ~, ~, testData] = obj.DataStore.getData(state.SelectedData); % Get the testing data
            [dataStruct, ~, ~, normaldata] = obj.DataStore.getData(model.TrainingDataset); % Get the training data for threshold computation

            % To ensure that the automated threshold computation doesn't
            % change for the same detection parameters, we need to ensure
            % that the same data (training without the validation holdout)
            % is presented for updateDetector call
            pct = dataStruct.ValidationHoldoutPercentage/100;
            if isscalar(normaldata)
                cvMode = "perSeries";
            else
                cvMode = "perCell";
            end
            cv = anomalyCLI.internal.utils.timeSeriesCvpartition(normaldata, Holdout=pct, Mode=cvMode);
            trainData = subset(cv, normaldata, true);

            cc = model.TipDetectConfig; % Get configurations to use
            if isKey(model.ExecutedDetectConfig, state.SelectedData)
                oc = model.ExecutedDetectConfig(state.SelectedData); % Get configurations to use
            else
                oc = [];
            end

            try
                % ConfigUpdate is needed only if Tip (cc) is different than LKG (oc)
                needsConfigUpdate = ~isequal(cc, oc);
                [resultsTable, model] = model.Handler.detect(model, trainData, testData, cc, needsConfigUpdate);
                delete(h);

                % Update Detector config panel post updateDetector + detect call
                model.ExecutedDetectConfig(state.SelectedData) = model.TipDetectConfig;
                model.LKGDetectConfig = model.TipDetectConfig;
                model.DetectResults(state.SelectedData) = {resultsTable};
                model.DetectionTimestamp(state.SelectedData) = datetime('now', 'TimeZone', 'UTC');

                obj.ModelStore.setModel(state.SelectedModel, model);
            catch E
                delete(h);
                msg = m('predmaint_anomaly:anomaly_app:msgDetectionError', E.message);
                uialert(obj.App.AppContainer, msg, m('predmaint_anomaly:anomaly_app:strDetectionError'));
            end

            % Enable Detect button
            obj.Widgets.DetectButton.Icon = 'run';
            obj.Widgets.DetectButton.Enabled = state.AllowDetect;
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
            state.AllowDetect = ~isempty(targetModel.TrainingTimestamp);
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

            % Detect section
            detectSection = makeDetectSection(obj);
            tab.add(detectSection);

            % Compare section
            compareSection = makeCompareSection(obj);
            tab.add(compareSection);

            % Save section
            saveSection = makeSaveSection(obj);
            tab.add(saveSection);

            % Retrain section
            retrainSection = makeRetrainSection(obj);
            tab.add(retrainSection);

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
            importDataButton = Button(m('predmaint_anomaly:anomaly_app:strImportDataButton'), "import_data");
            importDataButton.Description = m('predmaint_anomaly:anomaly_app:tipImportDataButton');
            importDataButton.Tag = 'detect_tab_import_data';
            importDataButton.ButtonPushedFcn = @(~,~) openImportDialog(weak_obj.Handle);

            dataLabel = Label(m('predmaint_anomaly:anomaly_app:strDetectionData'));
            dataLabel.Description = m('predmaint_anomaly:anomaly_app:tipDetectionData');

            detectorLabel = Label(m('predmaint_anomaly:anomaly_app:strDetector') + ":");
            detectorLabel.Description = m('predmaint_anomaly:anomaly_app:tipSelectedDetector');

            dataDropDown = matlab.ui.internal.toolstrip.DropDown();
            dataDropDown.Description = m('predmaint_anomaly:anomaly_app:tipDetectionData');
            dataDropDown.Tag = 'detect_tab_data_set';
            dataDropDown.ValueChangedFcn = @(es,~) cbDataDropDownValueChangedFcn(weak_obj.Handle,es);

            selectedDetectorLabel = Label();
            selectedDetectorLabel.Description = m('predmaint_anomaly:anomaly_app:tipSelectedDetector');

            % Layout
            detectorSection = Section(m('predmaint_anomaly:anomaly_app:strDataSection'));
            detectorSection.Tag = "detect_tab_detector_section";

            col1 = Column();
            col1.add(importDataButton);
            detectorSection.add(col1);

            col2 = Column();
            col2.add(dataLabel);
            col2.add(detectorLabel);
            col2.addEmptyControl();
            detectorSection.add(col2);

            col3 = Column();
            col3.add(dataDropDown);
            col3.add(selectedDetectorLabel);
            col3.addEmptyControl();
            detectorSection.add(col3);

            % Persist
            obj.Widgets.ImportDataButton = importDataButton;
            obj.Widgets.ModelLabel = selectedDetectorLabel;
            obj.Widgets.DataDropDown = dataDropDown;
        end

        function detectSection = makeDetectSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            detectButton = Button(m('predmaint_anomaly:anomaly_app:strDetect'), "run");
            detectButton.Description = m('predmaint_anomaly:anomaly_app:tipDetectButton');
            detectButton.Tag = 'detect_tab_detect';
            detectButton.ButtonPushedFcn = @(~,~) cbDetectButtonPushedFcn(weak_obj.Handle);

            % Layout
            detectSection = Section(m('predmaint_anomaly:anomaly_app:strDetect'));
            detectSection.Tag = "detect_tab_detect_section";

            col1 = Column();
            col1.add(detectButton);
            detectSection.add(col1);

            % Persist
            obj.Widgets.DetectButton = detectButton;
        end

        function compareSection = makeCompareSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            compareButton = Button(m('predmaint_anomaly:anomaly_app:strCompare'), "compareTrainedModel");
            compareButton.Description = m('predmaint_anomaly:anomaly_app:tipCompareButton');
            compareButton.Tag = 'detect_tab_goto_compare';
            compareButton.ButtonPushedFcn = @(~,~) requestCompareDocument(weak_obj.Handle);

            % Layout
            compareSection = Section(m('predmaint_anomaly:anomaly_app:strCompare'));
            compareSection.Tag = "detect_tab_compare_section";

            col1 = Column();
            col1.add(compareButton);
            compareSection.add(col1);

            % Persist
            obj.Widgets.CompareButton = compareButton;
        end

        function saveSection = makeSaveSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            saveButton = Button(m('predmaint_anomaly:anomaly_app:strDuplicateDetector'), "saveCopyAs");
            saveButton.Description = m('predmaint_anomaly:anomaly_app:tipDuplicateDetector');
            saveButton.Tag = 'detect_tab_duplicate';
            saveButton.ButtonPushedFcn = @(~,~) cbSaveAsButtonPushedFcn(weak_obj.Handle);

            % Layout
            saveSection = Section(m('predmaint_anomaly:anomaly_app:strDuplicate'));
            saveSection.Tag = "detect_tab_save_section";

            col1 = Column();
            col1.add(saveButton);
            saveSection.add(col1);

            % Persist
            obj.Widgets.SaveButton = saveButton;
        end

        function retrainSection = makeRetrainSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            retrainButton = Button(m('predmaint_anomaly:anomaly_app:strRetrain'), "goTo_trainingDocument");
            retrainButton.Description = m('predmaint_anomaly:anomaly_app:tipRetrainButton');
            retrainButton.Tag = 'detect_tab_goto_train';
            retrainButton.ButtonPushedFcn = @(~,~) requestTrainDocument(weak_obj.Handle);

            % Layout
            retrainSection = Section(m('predmaint_anomaly:anomaly_app:strRetrain'));
            retrainSection.Tag = "detect_tab_retrain_section";

            col1 = Column();
            col1.add(retrainButton);
            retrainSection.add(col1);

            % Persist
            obj.Widgets.RetrainButton = retrainButton;
        end

        function exportSection = makeExportSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            exportDropdownButton = DropDownButton(m('predmaint_anomaly:anomaly_app:strExport'), "export");
            exportDropdownButton.Tag = 'detect_tab_export';

            exportDetectorItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportDetectorButton'), "export_data");
            exportDetectorItem.Description = m('predmaint_anomaly:anomaly_app:tipExportDetectorButton');
            exportDetectorItem.Tag = 'detect_tab_export_detector';
            exportDetectorItem.ItemPushedFcn = @(~,~) exportSelectedDetector(weak_obj.Handle);

            exportResultsItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportResults'), "export_data");
            exportResultsItem.Description = m('predmaint_anomaly:anomaly_app:tipExportResultsSingle');
            exportResultsItem.Tag = 'detect_tab_export_results';
            exportResultsItem.ItemPushedFcn = @(~,~) exportDetectionResults(weak_obj.Handle);

            popup = PopupList();
            popup.add(exportDetectorItem);
            popup.add(exportResultsItem);
            exportDropdownButton.Popup = popup;

            % Layout
            exportSection = Section(m('predmaint_anomaly:anomaly_app:strExport'));
            exportSection.Tag = "detect_tab_export_section";

            col1 = Column();
            col1.add(exportDropdownButton);
            exportSection.add(col1);

            % Persist
            obj.Widgets.ExportButton = exportDropdownButton;
            obj.Widgets.ExportDetectorItem = exportDetectorItem;
            obj.Widgets.ExportResultsItem = exportResultsItem;
        end
    end
end

% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
