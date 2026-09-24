classdef Compare < anomalyAPP.internal.app.AppComponent
    % Compare tab.

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strCompare')
        Tag (1,1) string = "compare_tab"
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
    end

    methods
        function obj = Compare(statestore, modelStore, dataStore, app)
            key = anomalyAPP.internal.app.tab.Compare.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, statestore);

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
                'Models', string.empty(0,2), ...
                'AnyTrainedModel', false);
        end

        function reset(obj)
            state = obj.getDefaultState();
            dataKey = string.empty;

            % Initialize state from model store.
            info = obj.ModelStore.findTrainedModels();
            state.Models = [info.keys(:) info.names(:)];
            state.AnyTrainedModel = ~isempty(info.keys);

            % Initialize state from data store.
            info = obj.DataStore.findLabeledData();
            state.Data = [info.keys(:) info.names(:)];
            if ~isempty(info.keys)
                dataKey = info.keys(1);
            end

            % Initialize from Compare document, if there is one.
            if obj.hasState("compare_document")
                otherState = obj.getState("compare_document");

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                end
            end
            state.SelectedData = dataKey;

            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "compare_document")
                otherState = obj.getState(ed.Name);
                state = obj.getState();

                if ~isempty(otherState.SelectedData)
                    dataKey = otherState.SelectedData;
                    state.SelectedData = dataKey;
                end

                obj.setState(state);
            end
        end

        function render_(obj, ~)
            state = obj.getState();

            obj.Widgets.DataDropDown.replaceAllItems(cellstr(state.Data));
            obj.Widgets.DataDropDown.Value = state.SelectedData;
            obj.Widgets.DataDropDown.Enabled = ~isempty(state.SelectedData);

            obj.Widgets.CompareButton.Enabled = state.AnyTrainedModel && ~isempty(state.SelectedData);
            obj.Widgets.ExportButton.Enabled = state.AnyTrainedModel;
            obj.Widgets.ExportResultsItem.Enabled = ~isempty(state.SelectedData);
        end
    end

    % Event management
    methods (Access = private)
        function openImportDialog(obj)
            ed = anomalyAPP.internal.utils.EventData("ImportDialogRequest", struct('UseNewSession', false));
            obj.notify('ImportDialogRequest', ed);
        end

        function exportTrainedDetectors(obj)
            otherState = obj.getState('model_panel');
            modelTable = otherState.ModelTable;
            keys = modelTable.Key(modelTable.Trained);
            edata = anomalyAPP.internal.utils.EventData(keys);
            obj.notify('ExportDetectorRequest', edata); % Defer to higher authority.
        end

        function openExportDialog(obj)
            edata = anomalyAPP.internal.utils.EventData(string.empty);
            obj.notify('ExportDetectorRequest', edata); % Defer to higher authority.
        end

        function exportDetectionResults(obj)
            state = obj.getState();
            edata = anomalyAPP.internal.utils.EventData('ExportResultsDialogRequest', ...
                struct('Data', state.SelectedData, 'Model', string.empty));
            obj.notify('ExportResultsDialogRequest', edata); % Defer to higher authority.
        end

        function cbDataChanged(obj, ~)
            state = obj.getState();

            info = obj.DataStore.findLabeledData(); % Only the labeled datasets.
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

            info = obj.ModelStore.findTrainedModels(); % Only the trained models.
            state.Models = [info.keys(:) info.names(:)];
            state.AnyTrainedModel = ~isempty(info.keys);

            obj.setState(state);
        end

        function cbDataDropDownValueChangedFcn(obj, es)
            state = obj.getState();
            state.SelectedData = string(es.SelectedItem);
            obj.setState(state);
        end

        function cbCompareButtonPushedFcn(obj)
            % Create progressdlg at the beginning cause fetching data can take some
            % time if data is large
            h = uiprogressdlg(obj.App.AppContainer, 'Title', '', ...
                'Message', m('predmaint_anomaly:anomaly_app:strDetecting'), ...
                'Indeterminate', 'on');

            % Disable Compare button
            obj.Widgets.CompareButton.Icon = 'stop';
            obj.Widgets.CompareButton.Enabled = false;

            state = obj.getState();
            modelKeys = state.Models(:,1);

            try
                for i = 1:numel(modelKeys)
                    model = obj.ModelStore.getModel(modelKeys(i));

                    % Skip models that already have up-to-date detection
                    % results for the selected data and whose detection
                    % config has not been modified.
                    if isKey(model.DetectionTimestamp, state.SelectedData) ...
                            && model.DetectionTimestamp(state.SelectedData) >= model.TrainingTimestamp ...
                            && isKey(model.ExecutedDetectConfig, state.SelectedData) ...
                            && isequaln(model.TipDetectConfig, model.ExecutedDetectConfig(state.SelectedData))
                        continue;
                    end

                    [~, ~, ~, testData] = obj.DataStore.getData(state.SelectedData);
                    [dataStruct, ~, ~, normaldata] = obj.DataStore.getData(model.TrainingDataset);

                    % To ensure that the automated threshold computation doesn't
                    % change for the same detection parameters, we need to ensure
                    % that the same data (training without the validation holdout)
                    % is presented for updateDetector call.
                    pct = dataStruct.ValidationHoldoutPercentage/100;
                    if isscalar(normaldata)
                        cvMode = "perSeries";
                    else
                        cvMode = "perCell";
                    end
                    cv = anomalyCLI.internal.utils.timeSeriesCvpartition(normaldata, Holdout=pct, Mode=cvMode);
                    trainData = subset(cv, normaldata, true);

                    cc = model.TipDetectConfig;
                    if isKey(model.ExecutedDetectConfig, state.SelectedData)
                        oc = model.ExecutedDetectConfig(state.SelectedData);
                    else
                        oc = [];
                    end

                    needsConfigUpdate = ~isequal(cc, oc);
                    [resultsTable, model] = model.Handler.detect(model, trainData, testData, cc, needsConfigUpdate);

                    % Update Detector config panel post updateDetector + detect call.
                    model.ExecutedDetectConfig(state.SelectedData) = model.TipDetectConfig;
                    model.LKGDetectConfig = model.TipDetectConfig;
                    model.DetectResults(state.SelectedData) = {resultsTable};
                    model.DetectionTimestamp(state.SelectedData) = datetime('now', 'TimeZone', 'UTC');
                    obj.ModelStore.setModel(modelKeys(i), model);
                end
                delete(h);
            catch E
                delete(h);
                msg = m('predmaint_anomaly:anomaly_app:msgDetectionError', E.message);
                uialert(obj.App.AppContainer, msg, m('predmaint_anomaly:anomaly_app:strDetectionError'));
            end

            % Enable Compare button.
            obj.Widgets.CompareButton.Icon = 'run';
            obj.Widgets.CompareButton.Enabled = state.AnyTrainedModel && ~isempty(state.SelectedData);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            tab = matlab.ui.internal.toolstrip.Tab();
            tab.Title = obj.Title;
            tab.Tag = obj.Tag;

            % Data section
            dataSection = makeDataSection(obj);
            tab.add(dataSection);

            % Compare section
            compareSection = makeCompareSection(obj);
            tab.add(compareSection);

            % Export section
            exportSection = makeExportSection(obj);
            tab.add(exportSection);

            % Persist
            obj.Widgets.Tab = tab;
        end

        function dataSection = makeDataSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            importDataButton = Button(m('predmaint_anomaly:anomaly_app:strImportDataButton'), "import_data");
            importDataButton.Description = m('predmaint_anomaly:anomaly_app:tipImportDataButton');
            importDataButton.Tag = 'compare_tab_import_data';
            importDataButton.ButtonPushedFcn = @(~,~) openImportDialog(weak_obj.Handle);

            dataLabel = Label(m('predmaint_anomaly:anomaly_app:strDetectionData'));
            dataLabel.Description = m('predmaint_anomaly:anomaly_app:tipDetectionData');

            dataDropDown = matlab.ui.internal.toolstrip.DropDown();
            dataDropDown.Description = m('predmaint_anomaly:anomaly_app:tipDetectionData');
            dataDropDown.Tag = 'compare_tab_data_set';
            dataDropDown.ValueChangedFcn = @(es,~) cbDataDropDownValueChangedFcn(weak_obj.Handle,es);

            % Layout
            dataSection = Section(m('predmaint_anomaly:anomaly_app:strDataSection'));
            dataSection.Tag = "compare_tab_data_section";

            col1 = Column();
            col1.add(importDataButton);
            dataSection.add(col1);

            col2 = Column();
            col2.add(dataLabel);
            col2.addEmptyControl();
            col2.addEmptyControl();
            dataSection.add(col2);

            col3 = Column();
            col3.add(dataDropDown);
            col3.addEmptyControl();
            col3.addEmptyControl();
            dataSection.add(col3);

            % Persist
            obj.Widgets.ImportDataButton = importDataButton;
            obj.Widgets.DataDropDown = dataDropDown;
        end

        function compareSection = makeCompareSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            compareButton = Button(m('predmaint_anomaly:anomaly_app:strCompare'), "run");
            compareButton.Description = m('predmaint_anomaly:anomaly_app:tipCompareButton');
            compareButton.Tag = 'compare_tab_compare';
            compareButton.ButtonPushedFcn = @(~,~) cbCompareButtonPushedFcn(weak_obj.Handle);

            % Layout
            compareSection = Section(m('predmaint_anomaly:anomaly_app:strCompare'));
            compareSection.Tag = "compare_tab_compare_section";

            col1 = Column();
            col1.add(compareButton);
            compareSection.add(col1);

            % Persist
            obj.Widgets.CompareButton = compareButton;
        end

        function exportSection = makeExportSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            exportButton = DropDownButton(m('predmaint_anomaly:anomaly_app:strExport'), "export");

            detectorsHeader = PopupListHeader(m('predmaint_anomaly:anomaly_app:strExportDetectorsHeader'));

            exportAllTrainedItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportTrainedDetectorsItem'), 'export_data');
            exportAllTrainedItem.Description = m('predmaint_anomaly:anomaly_app:tipExportTrainedDetectors');
            exportAllTrainedItem.Tag = 'compare_tab_export_trained';
            exportAllTrainedItem.ItemPushedFcn = @(~,~) exportTrainedDetectors(weak_obj.Handle);

            exportSelectedItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportSelectedDetectorsItem'), 'export_data');
            exportSelectedItem.Description = m('predmaint_anomaly:anomaly_app:tipExportSelectedDetectors');
            exportSelectedItem.Tag = 'compare_tab_export_selected';
            exportSelectedItem.ItemPushedFcn = @(~,~) openExportDialog(weak_obj.Handle);

            resultsHeader = PopupListHeader(m('predmaint_anomaly:anomaly_app:strExportResultsHeader'));

            exportResultsItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportResults'), "export_data");
            exportResultsItem.Description = m('predmaint_anomaly:anomaly_app:tipExportResultsMultiple');
            exportResultsItem.Tag = 'compare_tab_export_results';
            exportResultsItem.ItemPushedFcn = @(~,~) exportDetectionResults(weak_obj.Handle);

            % Layout
            exportSection = Section(m('predmaint_anomaly:anomaly_app:strExport'));
            exportSection.Tag = "compare_tab_export_section";

            p = PopupList();
            p.add(detectorsHeader);
            p.add(exportAllTrainedItem);
            p.add(exportSelectedItem);
            p.add(resultsHeader);
            p.add(exportResultsItem);
            exportButton.Popup = p;

            col1 = Column();
            col1.add(exportButton);
            exportSection.add(col1);

            % Persist
            obj.Widgets.ExportButton = exportButton;
            obj.Widgets.ExportSection = exportSection;
            obj.Widgets.ExportResultsItem = exportResultsItem;
        end
    end
end

%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
