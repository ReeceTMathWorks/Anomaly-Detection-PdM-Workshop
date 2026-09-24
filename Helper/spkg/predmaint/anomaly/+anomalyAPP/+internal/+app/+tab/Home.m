classdef Home < anomalyAPP.internal.app.AppComponent
    % Home tab.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strHomeTabTitle')
        Tag (1,1) string = "home_tab"
    end

    properties (Access = public)
        Widgets
    end

    events
        PlotDocumentRequest
        TrainDocumentRequest
        DetectDocumentRequest
        CompareDocumentRequest

        ModelRequest
        ImportDialogRequest
        SaveSessionRequest
        LoadSessionRequest
        MultiModelTrainingDialogRequest
        ExportDetectorRequest
        ExportResultsDialogRequest
    end

    methods
        function obj = Home(stateStore)
            key = anomalyAPP.internal.app.tab.Home.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

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
                'DataSelected', false, ...
                'SingleSelectedModel', false, ...
                'AnyTrainedModel', false, ...
                'AnyTrainingData', false, ...
                'AppDirty', false);
        end

        function reset(obj)
            state = obj.getDefaultState();
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "data_panel")
                otherState = obj.getState("data_panel");
                state = obj.getState();
                state.DataSelected = any(otherState.DataTable.isSelected);
                state.AnyTrainingData = any(otherState.DataTable.isTrainingData);
                obj.setState(state);
            end

            if (ed.Name == "model_panel")
                otherState = obj.getState("model_panel");
                state = obj.getState();
                state.SingleSelectedModel = nnz(otherState.ModelTable.isSelected) == 1; % True on single selection.
                state.AnyTrainedModel = any(otherState.ModelTable.Trained);
                obj.setState(state);
            end

            if (ed.Name == "anomaly_detector_app")
                otherState = obj.getState("anomaly_detector_app");
                state = obj.getState();
                state.AppDirty = otherState.Dirty;
                obj.setState(state);
            end
        end

        function render_(obj, ~)
            state = obj.getState();

            obj.Widgets.TimePlotButton.Enabled = state.DataSelected;
            obj.Widgets.TrainButton.Enabled = state.SingleSelectedModel;
            obj.Widgets.TrainAllButton.Enabled = state.SingleSelectedModel && state.AnyTrainingData;
            obj.Widgets.DetectButton.Enabled = state.SingleSelectedModel;
            obj.Widgets.CompareButton.Enabled = state.SingleSelectedModel;
            obj.Widgets.ExportButton.Enabled = state.AnyTrainedModel;

            % Only update the save session button if it has a real change.
            % This can help avoid flickering.
            if state.AppDirty && isequal(obj.Widgets.SaveSessionButton.Icon, matlab.ui.internal.toolstrip.Icon('saved'))
                % App is dirty, but button shows that it is not dirty
                obj.Widgets.SaveSessionButton.Icon = matlab.ui.internal.toolstrip.Icon('unsaved');
            elseif ~state.AppDirty && isequal(obj.Widgets.SaveSessionButton.Icon, matlab.ui.internal.toolstrip.Icon('unsaved'))
                % App is clean, but button shows that it is dirty
                obj.Widgets.SaveSessionButton.Icon = matlab.ui.internal.toolstrip.Icon('saved');
            end
        end
    end

    % Event management
    methods (Access = private)
        function requestPlotDocument(obj)
            obj.notify('PlotDocumentRequest');
        end

        function requestTrainDocument(obj)
            obj.notify('TrainDocumentRequest');
        end

        function requestDetectDocument(obj)
            obj.notify('DetectDocumentRequest');
        end

        function requestCompareDocument(obj)
            obj.notify('CompareDocumentRequest');
        end

        function openImportDialog(obj, useNewSession)
            ed = anomalyAPP.internal.utils.EventData("ImportDialogRequest", struct('UseNewSession', useNewSession));
            obj.notify('ImportDialogRequest', ed);
        end

        function saveSession(obj)
            obj.notify('SaveSessionRequest');
        end

        function loadSession(obj)
            obj.notify('LoadSessionRequest');
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

        function popup = generateExportResultsPopup(obj, es)
            weak_obj = matlab.lang.WeakReference(obj);
            popup = matlab.ui.internal.toolstrip.PopupList();

            % Get the data sets from the data panel
            otherState = obj.getState(anomalyAPP.internal.app.panel.DataBrowser.Tag);

            % Build a popup item for each data set in the browser
            for i = 1:height(otherState.DataTable)
                item = matlab.ui.internal.toolstrip.ListItem(otherState.DataTable.Name(i));
                item.Tag = es.Tag;
                item.ItemPushedFcn = @(~,~) exportDetectionResults(weak_obj.Handle, otherState.DataTable.Key(i));
                popup.add(item);
            end
        end

        function exportDetectionResults(obj, dataKey)
            edata = anomalyAPP.internal.utils.EventData('ExportResultsDialogRequest', ...
                struct('Data', dataKey, 'Model', string.empty));
            obj.notify('ExportResultsDialogRequest', edata); % Defer to higher authority.
        end

        function openMultiModelTrainingDialog(obj)
            edata = anomalyAPP.internal.utils.EventData(string.empty);
            obj.notify('MultiModelTrainingDialogRequest', edata); % Defer to higher authority.
        end

        function requestModel(obj, modelHandlers)
            ed = anomalyAPP.internal.utils.EventData('ModelRequest', struct('ModelHandlers', {modelHandlers}));
            obj.notify('ModelRequest', ed);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            tab = matlab.ui.internal.toolstrip.Tab();
            tab.Title = obj.Title;
            tab.Tag = obj.Tag;

            % File section
            fileSection = makeFileSection(obj);
            tab.add(fileSection);

            % Plot section
            plotsSection = makePlotSection(obj);
            tab.add(plotsSection);

            % Detectors section
            detectorsSection = makeDetectorsSection(obj);
            tab.add(detectorsSection);

            % Train section
            trainSection = makeTrainSection(obj);
            tab.add(trainSection);

            % Detect section
            detectSection = makeDetectSection(obj);
            tab.add(detectSection);

            % Compare section
            compareSection = makeCompareSection(obj);
            tab.add(compareSection);

            % Export section
            exportSection = makeExportSection(obj);
            tab.add(exportSection);

            % Persist
            obj.Widgets.Tab = tab;
        end

        function fileSection = makeFileSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            newSessionButton = Button(m('predmaint_anomaly:anomaly_app:strNewSessionButton'), 'new');
            newSessionButton.Description = m('predmaint_anomaly:anomaly_app:tipNewSessionButton');
            newSessionButton.Tag = 'home_tab_new_session';
            newSessionButton.ButtonPushedFcn = @(~,~) openImportDialog(weak_obj.Handle, true);

            importDataButton = Button(m('predmaint_anomaly:anomaly_app:strImportDataButton'), "import_data");
            importDataButton.Description = m('predmaint_anomaly:anomaly_app:tipImportDataButton');
            importDataButton.Tag = 'home_tab_import_data';
            importDataButton.ButtonPushedFcn = @(~,~) openImportDialog(weak_obj.Handle, false);

            saveSessionButton = Button(m('predmaint_anomaly:anomaly_app:strSaveSession'), "saved");
            saveSessionButton.Tag = 'home_tab_save_session';
            saveSessionButton.ButtonPushedFcn = @(~,~) saveSession(weak_obj.Handle);

            loadSessionButton = Button(m('predmaint_anomaly:anomaly_app:strLoadSession'), "openFolder");
            loadSessionButton.Tag = 'home_tab_load_session';
            loadSessionButton.ButtonPushedFcn = @(~,~) loadSession(weak_obj.Handle);

            % Layout
            fileSection = Section(m('predmaint_anomaly:anomaly_app:strFile'));

            col1 = Column();
            col1.add(newSessionButton);
            fileSection.add(col1);

            col2 = Column();
            col2.add(importDataButton);
            fileSection.add(col2);

            col3 = Column();
            col3.add(saveSessionButton);
            fileSection.add(col3);

            col4 = Column();
            col4.add(loadSessionButton);
            fileSection.add(col4);

            % Persist
            obj.Widgets.NewSessionButton = newSessionButton;
            obj.Widgets.ImportDataButton = importDataButton;
            obj.Widgets.SaveSessionButton = saveSessionButton;
            obj.Widgets.LoadSessionButton = loadSessionButton;
            obj.Widgets.FileSection = fileSection;
        end

        function plotSection = makePlotSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            plotButton = Button(m('predmaint_anomaly:anomaly_app:strPlotDataButton'), 'plot');
            plotButton.Description = m('predmaint_anomaly:anomaly_app:tipPlotDataButton');
            plotButton.Tag = 'home_tab_plot';
            plotButton.ButtonPushedFcn = @(~,~) requestPlotDocument(weak_obj.Handle);

            % Layout
            plotSection = Section(m('predmaint_anomaly:anomaly_app:strPlot'));

            col1 = Column();
            col1.add(plotButton);
            plotSection.add(col1);

            % Persist
            obj.Widgets.TimePlotButton = plotButton;
            obj.Widgets.PlotSection = plotSection;
        end

        function detectorsSection = makeDetectorsSection(obj)
            import matlab.ui.internal.toolstrip.*;
            import anomalyAPP.internal.app.modelmanager.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            gcGS = GalleryCategory(m('predmaint_anomaly:anomaly_app:strGetStartedCategory'));
            gcGS.Tag = 'home_tab_get_started_gc';

            quickItem = GalleryItem(m('predmaint_anomaly:anomaly_app:strQuickDetectors'), "time_trainingPlotMultiple");
            quickItem.Description = m('predmaint_anomaly:anomaly_app:tipQuickDetectors');
            quickItem.Tag = 'home_tab_quick_detectors';
            gcGS.add(quickItem);
            quickModels = {TS_SPC, TS_OneClassSVM, TS_LOF, TS_RRCForest, TS_IsolationForest};
            addlistener(quickItem, 'ItemPushed', @(~,~) requestModel(weak_obj.Handle, quickModels));

            allItem = GalleryItem(m('predmaint_anomaly:anomaly_app:strAllDetectors'), "trainingPlotMultiple");
            allItem.Description =  m('predmaint_anomaly:anomaly_app:tipAllDetectors');
            allItem.Tag = 'home_tab_all_detectors';
            gcGS.add(allItem);
            allModels = {TS_SPC, TS_OneClassSVM, TS_LOF, TS_RRCForest, TS_IsolationForest, TS_DeepAnT, TS_TCN, TS_CNNAE, TS_LSTMAE, TS_LSTMF,...
                TS_UsAD, TS_VAELSTM};
            addlistener(allItem, 'ItemPushed', @(~,~) requestModel(weak_obj.Handle, allModels));

            % Inner function for gallery item construction
            function item = makeGalleryItem(trainObj)
                item = GalleryItem(trainObj.Name, trainObj.IconName);
                item.Description = trainObj.Description;
                item.Tag = ['home_tab_' char(trainObj.Type) '_detector'];
                addlistener(item, 'ItemPushed', @(~,~) requestModel(weak_obj.Handle, {trainObj}));
            end

            % Statistical detectors
            gcCL = GalleryCategory(m('predmaint_anomaly:anomaly_app:strCLCategory'));
            gcCL.Tag = 'home_tab_statistical_gc';
            gcCL.add(makeGalleryItem(TS_SPC));

            % Machine learning detectors
            gcML = GalleryCategory(m('predmaint_anomaly:anomaly_app:strMLCategory'));
            gcML.Tag = 'home_tab_machine_learning_gc';

            allMLItem = GalleryItem(m('predmaint_anomaly:anomaly_app:strAllMLDetectors'), "tsSvmOneClassMultiple");
            allMLItem.Description =  m('predmaint_anomaly:anomaly_app:tipAllMLDetectors');
            allMLItem.Tag = 'home_tab_all_ML_detectors';
            allMLModels = {TS_OneClassSVM, TS_LOF, TS_RRCForest, TS_IsolationForest};
            addlistener(allMLItem, 'ItemPushed', @(~,~) requestModel(weak_obj.Handle, allMLModels));

            gcML.add(allMLItem);
            gcML.add(makeGalleryItem(TS_OneClassSVM));
            gcML.add(makeGalleryItem(TS_LOF));
            gcML.add(makeGalleryItem(TS_RRCForest));
            gcML.add(makeGalleryItem(TS_IsolationForest));

            % Deep learning detectors
            gcDL = GalleryCategory(m('predmaint_anomaly:anomaly_app:strDLCategory'));
            gcDL.Tag = 'home_tab_deep_learning_gc';

            allDLItem = GalleryItem(m('predmaint_anomaly:anomaly_app:strAllDLDetectors'), "fullyConnectedMultiple");
            allDLItem.Description =  m('predmaint_anomaly:anomaly_app:tipAllDLDetectors');
            allDLItem.Tag = 'home_tab_all_DL_detectors';
            allDLModels = {TS_DeepAnT, TS_TCN, TS_CNNAE, TS_LSTMAE, TS_LSTMF, TS_UsAD, TS_VAELSTM};
            addlistener(allDLItem, 'ItemPushed', @(~,~) requestModel(weak_obj.Handle, allDLModels));

            gcDL.add(allDLItem);
            gcDL.add(makeGalleryItem(TS_DeepAnT));
            gcDL.add(makeGalleryItem(TS_TCN));
            gcDL.add(makeGalleryItem(TS_CNNAE));
            gcDL.add(makeGalleryItem(TS_LSTMAE));
            gcDL.add(makeGalleryItem(TS_LSTMF));
            gcDL.add(makeGalleryItem(TS_UsAD));
            gcDL.add(makeGalleryItem(TS_VAELSTM));

            % If DLT is not present, disable the galleryItem
            [~, ~, dltFlag] = anomalyAPP.internal.utils.checkRequiredToolboxes;

            if ~dltFlag
                gcDL.disableAll;
                gcGS.remove(allItem);
                allItem.Description = m('predmaint_anomaly:anomaly_app:tipDLTUnavailable');
                allDLItem.Description =  m('predmaint_anomaly:anomaly_app:tipDLTUnavailable');
            end

            popup = GalleryPopup('GalleryItemTextLineCount', 2, 'DisplayState', 'icon_view');
            popup.add(gcGS);
            popup.add(gcCL);
            popup.add(gcML);
            popup.add(gcDL);
            gallery = Gallery(popup, 'MaxColumnCount', 4, 'MinColumnCount', 2);

            % Layout
            detectorsSection = Section(m('predmaint_anomaly:anomaly_app:strDetectors'));

            col1 = Column();
            col1.add(gallery);
            detectorsSection.add(col1);

            % Persist
            obj.Widgets.GalleryPopups = popup;
            obj.Widgets.DetectorsSection = detectorsSection;
        end

        function trainSection = makeTrainSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            trainAllButton = Button(m('predmaint_anomaly:anomaly_app:strTrainAll'), "run");
            trainAllButton.Description = m('predmaint_anomaly:anomaly_app:descTrainAll');
            trainAllButton.Tag = 'home_tab_train_all';
            trainAllButton.ButtonPushedFcn = @(~,~) openMultiModelTrainingDialog(weak_obj.Handle);

            trainButton = Button(m('predmaint_anomaly:anomaly_app:strTrain'), "goTo_trainingDocument");
            trainButton.Description = m('predmaint_anomaly:anomaly_app:tipTrainButton');
            trainButton.Tag = 'home_tab_train';
            trainButton.ButtonPushedFcn = @(~,~) requestTrainDocument(weak_obj.Handle);

            % Layout
            trainSection = Section(m('predmaint_anomaly:anomaly_app:strTrain'));

            col1 = Column();
            col1.add(trainAllButton);
            trainSection.add(col1);

            col2 = Column();
            col2.add(trainButton);
            trainSection.add(col2);

            % Persist
            obj.Widgets.TrainAllButton = trainAllButton;
            obj.Widgets.TrainButton = trainButton;
            obj.Widgets.TrainSection = trainSection;
        end

        function detectSection = makeDetectSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            detectButton = Button(m('predmaint_anomaly:anomaly_app:strDetect'), "goTo_detectionDocument");
            detectButton.Description = m('predmaint_anomaly:anomaly_app:tipDetectButton');
            detectButton.Tag = 'home_tab_detect';
            detectButton.ButtonPushedFcn = @(~,~) requestDetectDocument(weak_obj.Handle);

            % Layout
            detectSection = Section(m('predmaint_anomaly:anomaly_app:strDetect'));

            col1 = Column();
            col1.add(detectButton);
            detectSection.add(col1);

            % Persist
            obj.Widgets.DetectButton = detectButton;
            obj.Widgets.DetectSection = detectSection;
        end

        function compareSection = makeCompareSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            compareButton = Button(m('predmaint_anomaly:anomaly_app:strCompare'), "compareTrainedModel");
            compareButton.Description = m('predmaint_anomaly:anomaly_app:tipCompareButton');
            compareButton.Tag = 'home_tab_compare';
            compareButton.ButtonPushedFcn = @(~,~) requestCompareDocument(weak_obj.Handle);

            % Layout
            compareSection = Section(m('predmaint_anomaly:anomaly_app:strCompare'));

            col1 = Column();
            col1.add(compareButton);
            compareSection.add(col1);

            % Persist
            obj.Widgets.CompareButton = compareButton;
            obj.Widgets.CompareSection = compareSection;
        end

        function exportSection = makeExportSection(obj)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Widgets
            exportButton = DropDownButton(m('predmaint_anomaly:anomaly_app:strExport'), "export");
            exportButton.Tag = 'home_tab_export';

            detectorsHeader = PopupListHeader(m('predmaint_anomaly:anomaly_app:strExportDetectorsHeader'));

            exportAllTrainedDetectorsItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportTrainedDetectorsItem'), 'export_data');
            exportAllTrainedDetectorsItem.Description = m('predmaint_anomaly:anomaly_app:tipExportTrainedDetectors');
            exportAllTrainedDetectorsItem.Tag = 'home_tab_export_trained';
            exportAllTrainedDetectorsItem.ItemPushedFcn = @(~,~) exportTrainedDetectors(weak_obj.Handle);

            exportSelectedDetectorsItem = ListItem(m('predmaint_anomaly:anomaly_app:strExportSelectedDetectorsItem'), 'export_data');
            exportSelectedDetectorsItem.Description = m('predmaint_anomaly:anomaly_app:tipExportSelectedDetectors');
            exportSelectedDetectorsItem.Tag = 'home_tab_export_selected';
            exportSelectedDetectorsItem.ItemPushedFcn = @(~,~) openExportDialog(weak_obj.Handle);

            resultsHeader = PopupListHeader(m('predmaint_anomaly:anomaly_app:strExportResultsHeader'));

            exportResultsItem = ListItemWithPopup(m('predmaint_anomaly:anomaly_app:strExportResults'), 'export_data');
            exportResultsItem.Description = m('predmaint_anomaly:anomaly_app:tipExportResultsMultiple');
            exportResultsItem.Tag = 'home_tab_export_results';
            exportResultsItem.DynamicPopupFcn = @(es,~) generateExportResultsPopup(weak_obj.Handle, es);

            % Layout
            exportSection = Section(m('predmaint_anomaly:anomaly_app:strExport'));

            p = PopupList();
            p.add(detectorsHeader);
            p.add(exportAllTrainedDetectorsItem);
            p.add(exportSelectedDetectorsItem);
            p.add(resultsHeader);
            p.add(exportResultsItem);
            exportButton.Popup = p;

            col1 = Column();
            col1.add(exportButton);
            exportSection.add(col1);

            % Persist
            obj.Widgets.ExportButton = exportButton;
            obj.Widgets.ExportSection = exportSection;
        end
    end
end

%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
