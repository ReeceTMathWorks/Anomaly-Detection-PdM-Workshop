classdef TimeSeriesAnomalyDetector < anomalyAPP.internal.app.AppComponent
    % Time Series Anomaly Detector app.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strAnomalyAppTitle')
        Tag (1,1) string = "anomaly_detector_app"
    end

    % UI elements
    properties (Access = public)
        AppContainer matlab.ui.container.internal.AppContainer

        PlotDocumentGroup
        TrainDocumentGroup
        DetectDocumentGroup
        CompareDocumentGroup

        Tabs (1,1) dictionary = configureDictionary("string", "cell")
        Panels (1,1) dictionary = configureDictionary("string", "cell")
        Documents (1,1) dictionary = configureDictionary("string", "cell")
        Dialogs (1,1) dictionary = configureDictionary("string", "cell")

        ModelStore anomalyAPP.internal.utils.ModelStore
        DataStore anomalyAPP.internal.utils.DataStore
    end

    properties (Access = private)
        DataStoreListener event.listener
        ModelStoreListener event.listener
    end

    % App management
    methods
        function app = TimeSeriesAnomalyDetector(options)
            arguments
                options.SessionFile string = string.empty
            end
            key = anomalyAPP.internal.app.TimeSeriesAnomalyDetector.Tag;
            store = anomalyAPP.internal.utils.StateStore;
            app = app@anomalyAPP.internal.app.AppComponent(key, store);

            app.ModelStore = anomalyAPP.internal.utils.ModelStore;
            app.ModelStoreListener = listener(app.ModelStore, 'ModelChanged', @(~,~) setDirtyState(app,true)); % When models change, make the app dirty
            app.DataStore = anomalyAPP.internal.utils.DataStore;
            app.DataStoreListener = listener(app.DataStore, 'DataChanged', @(~,ed) cbDataChanged(app,ed));

            % Initialize view components after construction.
            createComponents(app);
            reset(app);

            % If requested, load a previously saved session
            if ~isempty(options.SessionFile)
                app.loadSessionFile(options.SessionFile);
            end

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.AppContainer) && isvalid(app.AppContainer)
                %disp('Deleting app container')
                delete(app.AppContainer);
            end

            delete@anomalyAPP.internal.app.AppComponent(app);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'CurrentData', [], ...
                'CurrentModel', [], ...
                'Dirty', false, ...
                'SessionName', "Untitled");
        end

        function reset(app)
            state = app.getDefaultState();
            app.setState(state);

            app.AppContainer.ActiveContexts = {'ModalContext'};
            app.AppContainer.Visible = true;
            pause(0.1);
        end

        function update_(app, ed)
            if (ed.Name == "model_panel")
                otherState = app.getState("model_panel");
                selection = find(otherState.ModelTable.isSelected);
                ownState = app.getState();
                ownState.CurrentModel = selection;
                app.setState(ownState);
            end

            if (ed.Name == "data_panel")
                otherState = app.getState("data_panel");
                selection = find(otherState.DataTable.isSelected);
                ownState = app.getState();
                ownState.CurrentData = selection;
                app.setState(ownState);
            end
        end

        function render_(app, ~)
            state = app.getState();
            if isfield(state, 'Dirty') % We have to check this since the app creates other components, triggering an update and render before the default state is defined
                title = sprintf("%s - %s", app.Title, state.SessionName);
                if state.Dirty
                    app.AppContainer.Title = title + "*";
                else
                    app.AppContainer.Title = title;
                end
            end
        end

        function [AppData, MetaData] = serialize(app)
            AppData = struct('StateStore', app.StateStore.serialize, ...
                'ModelStore', app.ModelStore.serialize, ...
                'DataStore', app.DataStore.serialize, ...
                'Tabs', app.Tabs.keys, ...
                'Panels', app.Panels.keys, ...
                'Documents', app.Documents.keys, ...
                'Dialogs', app.Dialogs.keys, ...
                'Layout', app.AppContainer.Layout);

            MetaData = struct('App', app.Tag, ...
                'SessionName', string.empty, ... % Will be filled in while saving the session
                'Version', 1.0, ...
                'OriginRelease', matlabRelease);
        end

        function deserialize(app, AppData)
            % Deserialize the stores
            app.StateStore.deserialize(AppData.StateStore);
            app.ModelStore.deserialize(AppData.ModelStore);
            app.DataStore.deserialize(AppData.DataStore);
        end
    end

    % Event management
    methods (Access = private)
        function cbPropertyChanged(app, es, ed)
            switch ed.PropertyName
                case "LastSelectedDocument"
                    if contains(es.LastSelectedDocument.tag, 'plot_document')
                        tab = app.Tabs(anomalyAPP.internal.app.tab.Plot.Tag);
                        tab = tab{1};
                        tab.syncWithDocument(es.LastSelectedDocument.tag);

                        panel = app.Panels(anomalyAPP.internal.app.panel.PlotOptions.Tag);
                        panel = panel{1};
                        panel.syncWithDocument(es.LastSelectedDocument.tag);
                    end
            end
        end

        function cbStateChanged(app, es)
            if es.State == matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                %disp('Deleting app...')
                delete(app);
            end
        end

        function cbDataChanged(app, ed)
            key = ed.Name;
            if ed.Data.Status == "Removed"
                % Check if there is an open plot for the data set that was
                % removed. If so, remove the plot document.
                documentKeys = app.Documents.keys;
                I = contains(documentKeys, anomalyAPP.internal.app.document.Plot.Tag) & contains(documentKeys, key);
                if any(I)
                    document = app.Documents{documentKeys(I)};
                    figureDocument = document.getFigureDocument();
                    figureDocument.close();
                end
            end

            % When data changes, make the app dirty
            app.setDirtyState(true);
        end

        function cbRemoveDocument(app, tag)
            delete(app.Documents{tag});
            app.Documents(tag) = [];
            app.StateStore.removeState(tag);
        end

        function canAppClose = cbCanCloseFcn(app, es)
            % Ask user if the app should be closed when there is data in the app.
            hasExistingData = app.DataStore.hasData();
            hasExistingModels = app.ModelStore.hasModels();
            if hasExistingData || hasExistingModels
                title = m('predmaint_anomaly:anomaly_app:strCloseDlgTitle');
                msg = m('predmaint_anomaly:anomaly_app:msgConfirmAllClose');

                btn1Str = string(message('predmaint:plot:strYes'));
                btn2Str = string(message('predmaint:plot:strNo'));
                busy = app.AppContainer.Busy;
                app.AppContainer.Busy = false; % Make sure the user is able to click in the uiconfirm
                selection = uiconfirm(es, msg, title, 'Options', [btn1Str, btn2Str]);
                selection = (selection == btn1Str);
                canAppClose = selection;
                app.AppContainer.Busy = busy; % Restore
            else
                canAppClose = true;
            end
        end
    end

    % Request handlers
    methods (Access = private)
        function handleTrainDocumentRequest(app, ed)
            arguments
                app
                ed = []
            end

            if ~isempty(ed)
                key = ed.Name;
            else
                state = app.getState("model_panel");
                key = state.ModelTable.Key(state.ModelTable.isSelected);
            end

            app.addTrainDocument(); % Will construct the train document if needed

            % Set the model in the train document
            documentTag = anomalyAPP.internal.app.document.Train.Tag;
            documentGroupTag = app.TrainDocumentGroup.Tag;
            c = app.Documents(documentTag);
            c = c{1};
            c.setModel(key);

            % Before showing the document, reset the selected tab to empty
            % to force the update when we set the selected tab later
            tabgroupTag = app.TrainDocumentGroup.Context.ToolstripTabGroupTags;
            tg = app.AppContainer.getTabGroup(tabgroupTag);
            tg.SelectedTab = [];

            % Show the document
            d = app.AppContainer.getDocument(documentGroupTag, documentTag);
            d.Selected = true;
            d.Showing = true;

            % After making sure the document is showing, set the
            % selected tab to be the train tab
            tab = tg.getChildByIndex(1);
            tg.SelectedTab = tab;
        end

        function handleDetectDocumentRequest(app, ed)
            arguments
                app
                ed = []
            end

            if ~isempty(ed)
                key = ed.Name;
            else
                state = app.getState("model_panel");
                key = state.ModelTable.Key(state.ModelTable.isSelected);
            end

            app.addDetectDocument(); % Will construct the detect document if needed

            % Set the model in the detect document
            documentTag = anomalyAPP.internal.app.document.Detect.Tag;
            documentGroupTag = app.DetectDocumentGroup.Tag;
            c = app.Documents(documentTag);
            c = c{1};
            c.setModel(key);

            % Before showing the document, reset the selected tab to empty
            % to force the update when we set the selected tab later
            tabgroupTag = app.DetectDocumentGroup.Context.ToolstripTabGroupTags;
            tg = app.AppContainer.getTabGroup(tabgroupTag);
            tg.SelectedTab = [];

            % Show the document
            d = app.AppContainer.getDocument(documentGroupTag, documentTag);
            d.Selected = true;
            d.Showing = true;

            % After making sure the document is showing, set the
            % selected tab to be the detect tab
            tab = tg.getChildByIndex(1);
            tg.SelectedTab = tab;
        end

        function handleCompareDocumentRequest(app, ed)
            arguments
                app
                ed = []
            end

            if ~isempty(ed)
                key = ed.Name;
            else
                state = app.getState("model_panel");
                key = state.ModelTable.Key(state.ModelTable.isSelected);
            end

            app.addCompareDocument(); % Will construct the compare document if needed

            % Set the model in the compare document
            documentTag = anomalyAPP.internal.app.document.Compare.Tag;
            documentGroupTag = app.CompareDocumentGroup.Tag;
            c = app.Documents(documentTag);
            c = c{1};
            c.setModel(key);

            % Before showing the document, reset the selected tab to empty
            % to force the update when we set the selected tab later
            tabgroupTag = app.CompareDocumentGroup.Context.ToolstripTabGroupTags;
            tg = app.AppContainer.getTabGroup(tabgroupTag);
            tg.SelectedTab = [];

            % Show the document
            d = app.AppContainer.getDocument(documentGroupTag, documentTag);
            d.Selected = true;
            d.Showing = true;

            % After making sure the document is showing, set the
            % selected tab to be the compare tab
            tab = tg.getChildByIndex(1);
            tg.SelectedTab = tab;
        end

        function handlePlotDocumentRequest(app, ed)
            arguments
                app
                ed = []
            end

            if ~isempty(ed)
                key = ed.Name;
            else
                state = app.getState("data_panel");
                key = state.DataTable.Key(state.DataTable.isSelected);
            end

            for i = 1:numel(key)
                app.addPlotDocument(key(i));
            end
        end

        function handleSelectDetectorRequest(app, ed)
            arguments
                app
                ed = []
            end

            if ~isempty(ed)
                key = ed.Name;
            else
                state = app.getState("model_panel");
                key = state.ModelTable.Key(state.ModelTable.isSelected);
            end

            % Store the last selected document
            lastSelected = app.AppContainer.LastSelectedDocument;

            trainDocumentGroupTag = app.TrainDocumentGroup.Tag;
            trainDocumentTag = anomalyAPP.internal.app.document.Train.Tag;
            detectDocumentTag = anomalyAPP.internal.app.document.Detect.Tag;
            compareDocumentTag = anomalyAPP.internal.app.document.Compare.Tag;

            % If the train, detect, and compare documents need to be constructed,
            % construct them.
            constructionFlag = isempty(app.AppContainer.getDocument(...
                trainDocumentGroupTag, trainDocumentTag)); % Assume both documents are created at the same time
            app.addTrainDocument(); % Will construct the train document if needed
            app.addDetectDocument(); % Will construct the detect document if needed
            app.addCompareDocument(); % Will construct the compare document if needed

            % Set the model in both the train and detect documents
            trainDocument = app.Documents(trainDocumentTag);
            trainDocument = trainDocument{1};
            trainDocument.setModel(key);

            detectDocument = app.Documents(detectDocumentTag);
            detectDocument = detectDocument{1};
            detectDocument.setModel(key);

            compareDocument = app.Documents(compareDocumentTag);
            compareDocument = compareDocument{1};
            compareDocument.setModel(key);

            % Update which document is selected in the app. If the
            % documents were just constructed, revert to the previously
            % selected tab.
            drawnow; % Documents must be done rendering before we switch the selected document
            if constructionFlag
                if ~isempty(lastSelected.tag)
                    % Restore the document selection
                    D = app.AppContainer.getDocument(lastSelected.documentGroupTag, lastSelected.tag);
                    D.Showing = true;
                else
                    % There was no document selected when the train/detect
                    % documents were created. Bring the train document into
                    % view but select the home tab.
                    D = app.AppContainer.getDocument(trainDocumentGroupTag, trainDocumentTag);
                    D.Showing = true;
                    drawnow; % Make sure rendering is done before switching the selected tab
                    TG = app.AppContainer.getTabGroup("home_tabgroup");
                    T = TG.getChildByIndex(1);
                    TG.SelectedTab = T;
                end
            end
        end

        function handleImportDialogRequest(app, ed)
            if ed.Data.UseNewSession
                % If the user has requested a new session, then check if there
                % is existing datasets or models. If so, confirm that these
                % will be removed and then remove them.
                modelInfo = app.ModelStore.getModelNames();
                dataInfo = app.DataStore.getDataNames();

                hasExistingData = ~isempty(dataInfo.keys);
                hasExistingModels = ~isempty(modelInfo.keys);
                if hasExistingData || hasExistingModels
                    title = m('predmaint_anomaly:anomaly_app:strNewSessionConfirmTitle');
                    msg = m('predmaint_anomaly:anomaly_app:msgConfirmNewSession');
                    btn1Str = string(message('predmaint:plot:strYes'));
                    btn2Str = string(message('predmaint:plot:strNo'));
                    selection = uiconfirm(app.AppContainer, msg, title, 'Options', [btn1Str, btn2Str]);
                    selection = (selection == btn1Str);

                    if selection
                        strTitle = m('predmaint_anomaly:anomaly_app:strClearingDataTitle');
                        strMessage = m('predmaint_anomaly:anomaly_app:msgClearingSessionData');
                        pDlg = uiprogressdlg(app.AppContainer, 'Title', strTitle, 'Message', strMessage);
                        pDlg.Indeterminate = true;

                        resetAppData(app);
                    else
                        return
                    end
                end
            end
            k = anomalyAPP.internal.app.dialog.DataImport.Tag;
            if isKey(app.Dialogs, k)
                dlg = app.Dialogs{k};
            else
                % Construct the dialog
                dlg = anomalyAPP.internal.app.dialog.DataImport(app.StateStore, app.DataStore);
                addlistener(dlg.Widgets.Figure, 'Visible', 'PostSet', @(~,ed)set(app.AppContainer, 'Busy', ed.AffectedObject.Visible));
                app.Dialogs(k) = {dlg};
            end
            initialize(dlg);
            app.positionDialogFigure(dlg);
        end

        function handleExportDetectorRequest(app, ed)
            exportTitle = string(message('predmaint_anomaly:anomaly_app:strExport'));
            noTrainedDetectorsMsg = string(message('predmaint_anomaly:anomaly_app:strWarnNoTrainedDetectors'));
            if ~isempty(ed.Name)
                key = ed.Name;
            else
                trainedModels = app.ModelStore.findTrainedModels();
                if isempty(trainedModels.keys)
                    uialert(app.AppContainer, noTrainedDetectorsMsg, exportTitle, Icon='warning');
                else
                    openExportDialog(app);
                end
                return
            end

            if isempty(key)
                % Nothing to export
                uialert(app.AppContainer, noTrainedDetectorsMsg, exportTitle, Icon='warning');
                return
            end

            msgs = cell(size(key));
            allnames = evalin('base','who');
            for iK = 1:numel(key)
                model = app.ModelStore.getModel(key(iK));
                name = "trainedDetector";
                name_unique = matlab.lang.makeUniqueStrings(name, allnames);
                name_valid = matlab.lang.makeValidName(name_unique);
                assignin('base', name_valid, model.Model)
                msgs{iK} = getString(message('predmaint_anomaly:anomaly_app:strDetectorExported', model.Name, name_valid));
                allnames = [allnames(:); cellstr(name_valid)]; % Append the new name so that it is checked the next time through the loop
            end
            msg = strjoin(msgs,newline);
            uialert(app.AppContainer, msg, exportTitle, Icon='success');
        end

        function handleExportResultsDialogRequest(app, ed)
            % The dialog was requested. Create and open the dialog
            weak_app = matlab.lang.WeakReference(app);

            % If the event data does not specify models to use,
            % validate that at least one model has results for the
            % selected data set.
            if isempty(ed.Data.Model)
                trainedModels = app.ModelStore.findTrainedModels(); % Only trained models can have detection results
                valid = false;
                for iM = 1:numel(trainedModels.keys)
                    model = app.ModelStore.getModel(trainedModels.keys(iM));
                    if isKey(model.DetectResults, ed.Data.Data)
                        valid = true;
                        break
                    end
                end

                % If there are no models with results, error
                if ~valid
                    title = m('predmaint_anomaly:anomaly_app:strExportError');
                    msg = m('predmaint_anomaly:anomaly_app:errNoDetectionResults');
                    uialert(app.AppContainer, msg, title)
                    return
                end
            end

            % Construct the dialog. It is destroyed every time it is closed
            dlg = anomalyAPP.internal.app.dialog.ExportResults(app.StateStore, app.ModelStore, app.DataStore, ed.Data.Data, ed.Data.Model);
            addlistener(dlg, 'ExportResultsRequest', @(~,ed) handleExportResultsRequest(weak_app.Handle, ed));
            addlistener(dlg, 'ObjectBeingDestroyed', @(es,~) cbDialogDestroyed(weak_app.Handle, es));
            k = anomalyAPP.internal.app.dialog.ExportResults.Tag;
            app.Dialogs(k) = {dlg};
            app.positionDialogFigure(dlg);
        end

        function handleExportResultsRequest(app, ed)
            % The request was to directly export the results. Generate
            % the results table using the event data to determine which
            % detectors and data to use.
            tbl = app.generateResultsTable(ed.Data);

            % Construct a valid variable name for the results. The
            % format should be: detectionResults_dataName
            dataName = app.DataStore.getData(ed.Data.Data).Name;
            name = "detectionResults_" + dataName;
            name_unique = matlab.lang.makeUniqueStrings(name, evalin('base','who'));
            name_valid = matlab.lang.makeValidName(name_unique);

            % Assign the variable in the base workspace and show a
            % uialert to indicate success
            assignin('base', name_valid, tbl)
            title = m('predmaint_anomaly:anomaly_app:strExportResults');
            msg = m('predmaint_anomaly:anomaly_app:strResultsExported', dataName);
            uialert(app.AppContainer, msg, title, Icon='success');
        end

        function handleSaveSessionRequest(app)
            % Open a progress dialog so the app is not usable while
            % saving.
            title = replace(m('predmaint_anomaly:anomaly_app:strSaveSession'), newline, ' ');
            p = uiprogressdlg(app.AppContainer, Message=m('predmaint_anomaly:anomaly_app:strSavingSession'), ...
                Title=title, Indeterminate='on', Cancelable='off');

            % If there is a session name already, use that in the save file
            % window. Otherwise, default to TSADSession.mldatx.
            state = app.getState();
            defaultName = state.SessionName;
            if defaultName == "Untitled"
                defaultName = "TSADSession";
            end
            [fileName, pathName] = uiputfile(defaultName+".mldatx", title);
            if isequal(fileName,0), return; end
            fullFilePath = fullfile(pathName, fileName);

            try
                % First create the .MLDATX file by exporting the data
                % backend from the DataStore
                app.DataStore.DataBackend.export(fullFilePath);

                % Serialize the remaining app data and save to a .MAT file
                [AppData, MetaData] = serialize(app);
                [~, fileNameNoExt, ~] = fileparts(fullFilePath);
                MetaData.SessionName = fileNameNoExt;
                appDataFileName = fullfile(tempdir, 'TSAD_AppData.mat');
                save(appDataFileName, 'AppData', 'MetaData');

                % Add the app data to the .MLDATX container
                fObj = mldatxfile(fullFilePath);
                fObj.addFile(appDataFileName);
                cleanup = onCleanup(@()delete(appDataFileName));

                % Close the progress dialog
                delete(p);

                % Show a success message
                uialert(app.AppContainer, m('predmaint_anomaly:anomaly_app:strSuccessfulSave', fileName), ...
                    title, Icon='success');

                % Make the app not dirty and update the session name
                app.setDirtyState(false, fileNameNoExt);
            catch E
                % There was an error saving the session. Show a uialert on
                % the app after deleting the partial saved session file.
                if isfile(fullFilePath)
                    delete(fullFilePath);
                end
                delete(p);
                uialert(app.AppContainer, E.message, m('predmaint_anomaly:anomaly_app:strSaveSessionError'));
                return
            end
        end

        function handleLoadSessionRequest(app)
            % If there is any data or models in the app, confirm that these
            % will be removed.
            hasExistingData = app.DataStore.hasData();
            hasExistingModels = app.ModelStore.hasModels();
            title = replace(m('predmaint_anomaly:anomaly_app:strLoadSession'), newline, ' ');
            if hasExistingData || hasExistingModels
                msg = m('predmaint_anomaly:anomaly_app:msgConfirmLoadSession');

                btn1Str = string(message('predmaint:plot:strYes'));
                btn2Str = string(message('predmaint:plot:strNo'));
                busy = app.AppContainer.Busy;
                app.AppContainer.Busy = false; % Make sure the user is able to click in the uiconfirm
                selection = uiconfirm(app.AppContainer, msg, title, 'Options', [btn1Str, btn2Str]);
                selection = (selection == btn1Str);
                app.AppContainer.Busy = busy; % Restore
                if ~selection
                    % User opted not to continue
                    return
                end
            end

            [fileName, pathName] = uigetfile('*.mldatx', title);
            if isequal(fileName,0), return; end
            fullFilePath = fullfile(pathName, fileName);

            app.loadSessionFile(fullFilePath);
        end

        function handleModelRequest(app, ed)
            app.createModel(ed.Data.ModelHandlers);
        end

        function openExportDialog(app)
            k = anomalyAPP.internal.app.dialog.ExportDetectors.Tag;
            % Construct the dialog. It is destroyed every time it is closed
            dlg = anomalyAPP.internal.app.dialog.ExportDetectors(app.StateStore, app.ModelStore);
            addlistener(dlg, 'ExportDetectorRequest', @(~,ed) handleExportDetectorRequest(app, ed));
            addlistener(dlg, 'ObjectBeingDestroyed', @(es,~) cbDialogDestroyed(app, es));
            app.Dialogs(k) = {dlg};
            app.positionDialogFigure(dlg);
        end

        function cbDialogDestroyed(app, es)
            % Remove both the dialog and its state
            app.Dialogs = remove(app.Dialogs, es.Tag);
            app.StateStore.removeState(es.Tag);
            app.AppContainer.Busy = false; % Make sure the app is not busy
        end

        function handleMultiModelTrainingDialogRequest(app, ~)
            k = anomalyAPP.internal.app.dialog.MultiModelTraining.Tag;

            % Find if there are any models to train and if there are none,
            % then throw an error dlg for user
            allmodels = app.ModelStore.getModelNames();
            tmodels = app.ModelStore.findTrainedModels();
            dirtyKeys = strings(0,1);
            for mk = tmodels.keys'
                mdl = app.ModelStore.getModel(mk);
                if ~isequaln(mdl.TipConfig,mdl.LKGConfig)
                    dirtyKeys(end+1,1) = mk; %#ok<AGROW>
                end
            end
            modelKeysToTrain = [dirtyKeys; setdiff(allmodels.keys, tmodels.keys)];

            if ~isempty(modelKeysToTrain)
                % Construct the dialog. It is destroyed every time it is closed
                dlg = anomalyAPP.internal.app.dialog.MultiModelTraining(app.StateStore, app.DataStore, app.ModelStore);
                addlistener(dlg, 'ObjectBeingDestroyed', @(es,~) cbDialogDestroyed(app, es));
                app.Dialogs(k) = {dlg};
                app.AppContainer.Busy = true;    % Make the app busy
                app.positionDialogFigure(dlg);
            else
                % Throw an error if there are no models to train
                uialert(app.AppContainer, ...
                    m('predmaint_anomaly:anomaly_app:strNoTrainableDetectorsMsg'), ...
                    m('predmaint_anomaly:anomaly_app:strNoTrainableDetectorsTitle'), ...
                    'Icon','error');
            end
        end
    end

    methods (Access = public)
        function createModel(app, modelHandlers)
            % Creates the model object and also initializes the empty model.
            keys = strings(size(modelHandlers));
            models(1:numel(modelHandlers)) = struct( ...
                'Name', [], 'Type', [], 'Model', [], 'Handler', [], ...
                'TipConfig', [], 'LKGConfig', [], 'TipDetectConfig', [], ...
                'ExecutedDetectConfig', configureDictionary("string", "struct"), ...
                'LKGDetectConfig', [], 'DetectResults', configureDictionary("string", "cell"), ...
                'ValidationResults', configureDictionary("string", "struct"), ...
                'TrainingDataset', string(0), 'TrainingTimestamp', [], ...
                'DetectionTimestamp', configureDictionary("string", "datetime"));


            for k = 1:numel(modelHandlers)
                handler = modelHandlers{k}; % Heterogeneous array

                name = app.ModelStore.makeUniqueModelName(handler.Name);
                keys(k) = matlab.lang.internal.uuid(1);
                models(k).Name = name;
                models(k).Type = handler.Type;
                models(k).Handler = handler;
                models(k).TipConfig = handler.defaultModelConfig;
                models(k).LKGConfig = handler.defaultModelConfig;
                models(k).TipDetectConfig = handler.defaultDetectConfig;
                models(k).LKGDetectConfig = handler.defaultDetectConfig;
            end
            app.ModelStore.addModel(keys, models);
        end
    end

    methods (Access = private)
        function createComponents(app)
            options = struct( ...
                'Title', app.Title, ...
                'Tag', sprintf('%s (%s)', app.Tag, matlab.lang.internal.uuid), ...
                'ToolstripEnabled', true, ...
                'EnableTheming', true, ...
                'Product', "Predictive Maintenance Toolbox", ...
                'Scope', "Time Series Anomaly Detector");
            appContainer = matlab.ui.container.internal.AppContainer(options);
            appContainer.WindowBounds(3:4) = [1200, 720];

            app.AppContainer = appContainer;
            app.AppContainer.CanCloseFcn = @(es) cbCanCloseFcn(app,es);
            addlistener(app.AppContainer, 'StateChanged', @(es,~) cbStateChanged(app,es));
            addlistener(app.AppContainer, 'PropertyChanged', @(es,ed) cbPropertyChanged(app,es,ed));

            % Add contextual help button on the QAB.
            qabHelpButton = matlab.ui.internal.toolstrip.qab.QABHelpButton();
            qabHelpButton.DocName = 'predmaint/TSADAppGeneralHelp';
            app.AppContainer.add(qabHelpButton);

            % Global models panel
            modelPanel = anomalyAPP.internal.app.panel.ModelBrowser(app.StateStore, app.ModelStore);
            addlistener(modelPanel, 'SelectDetectorRequest', @(~,ed) handleSelectDetectorRequest(app,ed));
            app.AppContainer.add(modelPanel.getFigurePanel());
            app.Panels(modelPanel.Tag) = {modelPanel};

            % Global data panel
            dataPanel = anomalyAPP.internal.app.panel.DataBrowser(app.StateStore, app.DataStore);
            addlistener(dataPanel, 'PlotDocumentRequest', @(~,ed) handlePlotDocumentRequest(app,ed));
            app.AppContainer.add(dataPanel.getFigurePanel());
            app.Panels(dataPanel.Tag) = {dataPanel};

            makeAppDocumentGroup(app);
            makePlotDocumentGroup(app);
            makeTrainDocumentGroup(app);
            makeDetectDocumentGroup(app);
            makeCompareDocumentGroup(app);
        end

        function makeAppDocumentGroup(app)
            appContainer = app.AppContainer;

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "home_tabgroup";
            appContainer.add(tabGroup);

            tab = anomalyAPP.internal.app.tab.Home(app.StateStore);
            addlistener(tab, 'PlotDocumentRequest', @(~,~) handlePlotDocumentRequest(app));
            addlistener(tab, 'TrainDocumentRequest', @(~,~) handleTrainDocumentRequest(app));
            addlistener(tab, 'DetectDocumentRequest', @(~,~) handleDetectDocumentRequest(app));
            addlistener(tab, 'CompareDocumentRequest', @(~,~) handleCompareDocumentRequest(app));
            addlistener(tab, 'ModelRequest', @(~,ed) handleModelRequest(app, ed));
            addlistener(tab, 'ImportDialogRequest', @(~,ed) handleImportDialogRequest(app, ed));
            addlistener(tab, 'SaveSessionRequest', @(~,~) handleSaveSessionRequest(app));
            addlistener(tab, 'LoadSessionRequest', @(~,~) handleLoadSessionRequest(app));
            addlistener(tab, 'MultiModelTrainingDialogRequest', @(~,ed) handleMultiModelTrainingDialogRequest(app, ed));
            addlistener(tab, 'ExportDetectorRequest', @(~,ed) handleExportDetectorRequest(app, ed));
            addlistener(tab, 'ExportResultsDialogRequest', @(~,ed) handleExportResultsDialogRequest(app, ed));
            tabGroup.add(tab.getTab());
            app.Tabs(tab.Tag) = {tab};

            documentGroup = matlab.ui.internal.FigureDocumentGroup();
            documentGroup.Title = m('predmaint_anomaly:anomaly_app:strGettingStarted');
            documentGroup.Tag = "getting_started_documentgroup";
            appContainer.add(documentGroup);

            app.addGettingStartedDocument();
        end

        function makePlotDocumentGroup(app)
            appContainer = app.AppContainer;

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "plot_tabgroup";
            tabGroup.Contextual = true;
            appContainer.add(tabGroup);

            tab = anomalyAPP.internal.app.tab.Plot(app.StateStore, app.DataStore);
            tabGroup.add(tab.getTab());
            app.Tabs(tab.Tag) = {tab};

            panel = anomalyAPP.internal.app.panel.PlotOptions(app.StateStore, app.DataStore);
            app.AppContainer.add(panel.getFigurePanel());
            app.Panels(panel.Tag) = {panel};

            % Document group context has a toolstrip tab and an options
            % panel. Context must be set during construction before the
            % document group is added to the AppContainer (g4016738).
            context = matlab.ui.container.internal.appcontainer.ContextDefinition();
            context.Tag = "plot_context";
            context.PanelTags = {panel.getFigurePanel().Tag};
            context.ToolstripTabGroupTags = {tabGroup.Tag};
            documentGroupOptions.Context = context;

            documentGroup = matlab.ui.internal.FigureDocumentGroup(documentGroupOptions);
            documentGroup.Title = m('predmaint_anomaly:anomaly_app:strPlots');
            documentGroup.Tag = "plot_documentgroup";
            appContainer.add(documentGroup);

            app.PlotDocumentGroup = documentGroup;
        end

        function makeTrainDocumentGroup(app)
            appContainer = app.AppContainer;

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "train_tabgroup";
            tabGroup.Contextual = true;
            appContainer.add(tabGroup);

            tab = anomalyAPP.internal.app.tab.Train(app.StateStore, app.ModelStore, app.DataStore, app);
            tabGroup.add(tab.getTab());
            app.Tabs(tab.Tag) = {tab};
            addlistener(tab, 'DetectDocumentRequest', @(~,ed) handleDetectDocumentRequest(app,ed));
            addlistener(tab, 'ExportDetectorRequest', @(~,ed) handleExportDetectorRequest(app, ed));

            panel = anomalyAPP.internal.app.panel.TrainOptions(app.StateStore, app.ModelStore);
            appContainer.add(panel.getFigurePanel());
            app.Panels(panel.Tag) = {panel};

            % Document group context has a toolstrip tab and an options
            % panel. Context must be set during construction before the
            % document group is added to the AppContainer (g4016738).
            context = matlab.ui.container.internal.appcontainer.ContextDefinition();
            context.Tag = "train_context";
            context.PanelTags = {panel.getFigurePanel().Tag};
            context.ToolstripTabGroupTags = {tabGroup.Tag};
            documentGroupOptions.Context = context;

            documentGroup = matlab.ui.internal.FigureDocumentGroup(documentGroupOptions);
            % documentGroup.ConstrainToSubContainer = true;
            documentGroup.Title = "Train Models";
            documentGroup.Tag = "train_documentgroup";
            appContainer.add(documentGroup);

            app.TrainDocumentGroup = documentGroup;
        end

        function makeDetectDocumentGroup(app)
            appContainer = app.AppContainer;

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "detect_tabgroup";
            tabGroup.Contextual = true;
            appContainer.add(tabGroup);

            tab = anomalyAPP.internal.app.tab.Detect(app.StateStore, app.ModelStore, app.DataStore, app);
            tabGroup.add(tab.getTab());
            app.Tabs(tab.Tag) = {tab};
            addlistener(tab, 'TrainDocumentRequest', @(~,ed) handleTrainDocumentRequest(app,ed));
            addlistener(tab, 'CompareDocumentRequest', @(~,ed) handleCompareDocumentRequest(app,ed));
            addlistener(tab, 'ImportDialogRequest', @(~,ed) handleImportDialogRequest(app,ed));
            addlistener(tab, 'ExportDetectorRequest', @(~,ed) handleExportDetectorRequest(app, ed));
            addlistener(tab, 'ExportResultsDialogRequest', @(~,ed) handleExportResultsDialogRequest(app, ed));

            panel = anomalyAPP.internal.app.panel.DetectOptions(app.StateStore, app.ModelStore);
            appContainer.add(panel.getFigurePanel());
            app.Panels(panel.Tag) = {panel};

            % Document group context has a toolstrip tab and an options
            % panel. Context must be set during construction before the
            % document group is added to the AppContainer (g4016738).
            context = matlab.ui.container.internal.appcontainer.ContextDefinition();
            context.Tag = "detect_context";
            context.PanelTags = {panel.getFigurePanel().Tag};
            context.ToolstripTabGroupTags = {tabGroup.Tag};
            documentGroupOptions.Context = context;

            documentGroup = matlab.ui.internal.FigureDocumentGroup(documentGroupOptions);
            documentGroup.Title = "Detect Models";
            documentGroup.Tag = "detect_documentgroup";
            appContainer.add(documentGroup);

            app.DetectDocumentGroup = documentGroup;
        end

        function makeCompareDocumentGroup(app)
            appContainer = app.AppContainer;

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "compare_tabgroup";
            tabGroup.Contextual = true;
            appContainer.add(tabGroup);

            tab = anomalyAPP.internal.app.tab.Compare(app.StateStore, app.ModelStore, app.DataStore, app);
            tabGroup.add(tab.getTab());
            app.Tabs(tab.Tag) = {tab};
            addlistener(tab, 'ImportDialogRequest', @(~,ed) handleImportDialogRequest(app,ed));
            addlistener(tab, 'ExportDetectorRequest', @(~,ed) handleExportDetectorRequest(app, ed));
            addlistener(tab, 'ExportResultsDialogRequest', @(~,ed) handleExportResultsDialogRequest(app, ed));

            panel = anomalyAPP.internal.app.panel.CompareOptions(app.StateStore, app.ModelStore);
            appContainer.add(panel.getFigurePanel());
            app.Panels(panel.Tag) = {panel};

            % Document group context has a toolstrip tab and an options
            % panel. Context must be set during construction before the
            % document group is added to the AppContainer (g4016738).
            context = matlab.ui.container.internal.appcontainer.ContextDefinition();
            context.Tag = "compare_context";
            context.PanelTags = {panel.getFigurePanel().Tag};
            context.ToolstripTabGroupTags = {tabGroup.Tag};
            documentGroupOptions.Context = context;

            documentGroup = matlab.ui.internal.FigureDocumentGroup(documentGroupOptions);
            documentGroup.Title = "Compare Models";
            documentGroup.Tag = "compare_documentgroup";
            appContainer.add(documentGroup);

            app.CompareDocumentGroup = documentGroup;
        end

        function positionDialogFigure(app, dlg)
            % Position a dialog so that it is centered on the AppContainer.
            screensize = get(0,'ScreenSize');
            fig = dlg.Widgets.Figure;
            units = fig.Units;
            fig.Units = 'pixels';
            appsize = app.AppContainer.WindowBounds; % top-left = [0 0]
            appsize(2) = screensize(4) - (appsize(2)+appsize(4)); % convert to bottom-left = [0 0]
            center = [appsize(1)+appsize(3)/2, appsize(2)+appsize(4)/2];
            fig.Position(1:2) = [center(1)-fig.Position(3)/2, center(2)-fig.Position(4)/2];
            figure(fig);
            fig.Units = units;
        end

        function tbl = generateResultsTable(app, edata)
            models = arrayfun(@(x)app.ModelStore.getModel(x).Name, edata.Model(:));
            [~, index, groundTruthLabels] = app.DataStore.getData(edata.Data);
            results = cell(size(models));
            for iM = 1:numel(models)
                model = app.ModelStore.getModel(edata.Model(iM));
                rawPredictedLabels = model.DetectResults(edata.Data); % This should not be reachable if the results don't exist for the specified data
                results{iM} = cellfun(@(i,g,p) generateMemberResultTable(i,g,p,edata.LabelResolution,edata.IncludeGroundTruth,model), ...
                    index, groundTruthLabels, rawPredictedLabels{1}, UniformOutput=false);
                if isscalar(index)
                    % There is only one member. Rather than storing a 1x1
                    % cell array in the table cell, extract the contents so
                    % they are more visible.
                    results{iM} = results{iM}{1};
                end
            end
            varNames = [m('predmaint_anomaly:anomaly_app:strDetector'), ...
                m('predmaint_anomaly:anomaly_app:strResults')];
            tbl = table(models, results, VariableNames=varNames);
        end

        function resetAppData(app)
            modelInfo = app.ModelStore.getModelNames();
            dataInfo = app.DataStore.getDataNames();

            % Close the train, detect, and compare documents before
            % removing models to avoid updating the documents.
            trainDocumentTag = anomalyAPP.internal.app.document.Train.Tag;
            detectDocumentTag = anomalyAPP.internal.app.document.Detect.Tag;
            compareDocumentTag = anomalyAPP.internal.app.document.Compare.Tag;
            if isKey(app.Documents, trainDocumentTag)
                doc = app.Documents{trainDocumentTag};
                doc.setModel(string.empty);
                doc.setData(string.empty);
                doc.getFigureDocument.close();
            end
            if isKey(app.Documents, detectDocumentTag)
                doc = app.Documents{detectDocumentTag};
                doc.setModel(string.empty);
                doc.setData(string.empty);
                doc.getFigureDocument.close();
            end
            if isKey(app.Documents, compareDocumentTag)
                doc = app.Documents{compareDocumentTag};
                doc.setModel(string.empty);
                doc.setData(string.empty);
                doc.getFigureDocument.close();
            end

            keys = modelInfo.keys;
            app.ModelStore.removeModel(keys);

            keys = dataInfo.keys;
            for iK = 1:numel(keys)
                % Before removing data, check if there is an
                % existing plot and remove it
                tag = anomalyAPP.internal.app.document.Plot.Tag + "-" + keys(iK);
                if isKey(app.Documents, tag)
                    app.Documents{tag}.getFigureDocument.close();
                end
                app.DataStore.removeData(keys(iK));
            end

            % Make the app not dirty and update the session name
            app.setDirtyState(false, "Untitled");
        end

        function setDirtyState(app, dirty, sessionName)
            arguments
                app
                dirty (1,1) logical
                sessionName string = string.empty % Allow caller to set the app's session name in the same call
            end
            state = app.getState();
            state.Dirty = dirty;
            if ~isempty(sessionName)
                state.SessionName = sessionName;
            end
            app.setState(state);
        end

        function valid = validateSerializedSession(app, AppData)
            % First validate that AppData has the appropriate fields
            expFieldNames = {'StateStore', 'ModelStore', 'DataStore', 'Tabs', ...
                'Panels', 'Documents', 'Dialogs', 'Layout'};
            valid = isstruct(AppData) && all(ismember(expFieldNames, fieldnames(AppData)));

            % Validate the serialized states of the StateStore, ModelStore,
            % and DataStore
            valid = valid && app.StateStore.validateSerializedState(AppData.StateStore) && ...
                app.ModelStore.validateSerializedState(AppData.ModelStore) && ...
                app.DataStore.validateSerializedState(AppData.DataStore);

            % The Tabs, Panels, Documents, and Dialogs fields should be
            % string arrays.
            valid = valid && isstring(AppData.Tabs) && ...
                isstring(AppData.Panels) && ...
                isstring(AppData.Documents) && ...
                isstring(AppData.Dialogs);

            % Validate that any app components (tabs, panels, documents,
            % dialogs) that exist are also present in the StateStore.
            % Conversely, the StateStore should have no other components
            % except the app itself.
            expKeys = vertcat(AppData.Tabs, AppData.Panels, AppData.Documents, AppData.Dialogs, app.Tag);
            actKeys = AppData.StateStore.State.keys;
            valid = valid && isempty(setdiff(actKeys, expKeys));

            % The Layout field should be a struct. Contents of this struct
            % are controlled by the AppContainer class, so we cannot check
            % for specific fields. We rely on the AppContainer class for
            % backwards compatibility of the layout struct.
            valid = valid && isstruct(AppData.Layout);
        end

        function loadSessionFile(app, fullFilePath)
            % Open a progress dialog so the app is not usable while
            % saving.
            title = replace(m('predmaint_anomaly:anomaly_app:strLoadSession'), newline, ' ');
            p = uiprogressdlg(app.AppContainer, Message=m('predmaint_anomaly:anomaly_app:strLoadingSession'), ...
                Title=title, Indeterminate='on', Cancelable='off');

            % The first try-catch block is to catch errors if the session
            % information file cannot be found in the .MLDATX file. In this
            % case, we haven't yet changed the existing session, so there
            % is no need to remove any models/data.
            try
                % First unpack the .MLDATX file to get the AppData
                fObj = mldatxfile(fullFilePath);
                matFileName = 'TSAD_AppData.mat';
                fObj.getFile(matFileName, OutputPath=tempdir);
                appDataFileName = fullfile(tempdir, matFileName);
                cleanup = onCleanup(@()delete(appDataFileName));

                % Load the AppData and MetaData from the .MAT file
                S = load(appDataFileName, 'AppData', 'MetaData');
                AppData = S.AppData;
                MetaData = S.MetaData;
            catch
                delete(p);
                uialert(app.AppContainer, m('predmaint_anomaly:anomaly_app:errInvalidSessionFile'), ...
                    m('predmaint_anomaly:anomaly_app:strLoadSessionError'));
                return
            end

            % Validate that the session file was generated by the Time
            % Series Anomaly Detector app
            valid = MetaData.App == app.Tag;

            % Validate the AppData
            valid = valid && app.validateSerializedSession(AppData);

            % If the session is not valid, error and return. We haven't yet
            % changed the existing session, so there is no need to remove
            % any models/data.
            if ~valid
                delete(p);
                uialert(app.AppContainer, m('predmaint_anomaly:anomaly_app:errInvalidSessionFile'), ...
                    m('predmaint_anomaly:anomaly_app:strLoadSessionError'));
                return
            end

            % The second try-catch block is to catch errors while updating
            % the app session (data, models, UI, etc.). These actions will
            % change the state of the app, so if there are errors we should
            % remove all data and models to put the app in a clean state.
            try
                % Create a DataBackend by importing from the saved .MLDATX
                % file. Do this prior to hiding the AppContainer so that
                % the progress dialog shows while the data is loaded.
                DataBackend = predmaint.internal.backend.DataBackend.import(fullFilePath, ...
                    OriginalSaveName=MetaData.SessionName); % Use the original session name when importing so that the backend can find the data sets

                % Determine the full set of documents the current app version
                % requires given the session content. Older sessions may not list
                % documents that were introduced later.
                requiredDocuments = AppData.Documents;
                hasModels = ~isempty(AppData.ModelStore.Model.keys);
                if hasModels
                    modelDocuments = [
                        anomalyAPP.internal.app.document.Train.Tag
                        anomalyAPP.internal.app.document.Detect.Tag
                        anomalyAPP.internal.app.document.Compare.Tag];
                    requiredDocuments = union(requiredDocuments, modelDocuments);
                end

                % Close documents that should no longer be there
                extraDocuments = setdiff(app.Documents.keys, requiredDocuments);
                for iDoc = 1:numel(extraDocuments)
                    fd = app.Documents{extraDocuments(iDoc)}.getFigureDocument();
                    delete(fd);
                end

                % Re-create documents if needed. This must be done before
                % deserializing so that the StateStore does not attempt to
                % add duplicate states.
                missingDocuments = setdiff(requiredDocuments, app.Documents.keys);
                for iDoc = 1:numel(missingDocuments)
                    switch missingDocuments(iDoc)
                        case anomalyAPP.internal.app.document.GettingStarted.Tag
                            % Create the getting started document
                            app.addGettingStartedDocument();
                        case anomalyAPP.internal.app.document.Train.Tag
                            % Create the train document
                            app.addTrainDocument(MakeAppBusy=false);
                        case anomalyAPP.internal.app.document.Detect.Tag
                            % Create the detect document
                            app.addDetectDocument(MakeAppBusy=false);
                        case anomalyAPP.internal.app.document.Compare.Tag
                            % Create the compare document
                            app.addCompareDocument(MakeAppBusy=false);
                        otherwise
                            if startsWith(missingDocuments(iDoc), anomalyAPP.internal.app.document.Plot.Tag)
                                % Create a plot document for the data
                                key = extractAfter(missingDocuments(iDoc), anomalyAPP.internal.app.document.Plot.Tag+"-");
                                app.addPlotDocument(key);
                            else
                                % Unknown document. No-op is the safest path forward.
                            end
                    end
                end

                % Re-create dialogs if needed. This must be done before
                % deserializing so that the StateStore does not attempt to
                % add duplicate states.
                missingDialogs = AppData.Dialogs(~ismember(AppData.Dialogs, app.Dialogs.keys));
                for iDlg = 1:numel(missingDialogs)
                    switch missingDialogs(iDlg)
                        case anomalyAPP.internal.app.dialog.DataImport.Tag
                            % Create the data import dialog
                            dlg = anomalyAPP.internal.app.dialog.DataImport(app.StateStore, app.DataStore);
                            addlistener(dlg.Widgets.Figure, 'Visible', 'PostSet', @(~,ed)set(app.AppContainer, 'Busy', ed.AffectedObject.Visible));
                            app.Dialogs(anomalyAPP.internal.app.dialog.DataImport.Tag) = {dlg};
                        case {anomalyAPP.internal.app.dialog.ExportDetectors.Tag, ...
                                anomalyAPP.internal.app.dialog.ExportResults.Tag, ...
                                anomalyAPP.internal.app.dialog.MultiModelTraining.Tag}
                            % These dialogs are removed when they are
                            % closed, so there is no need to re-construct.
                        otherwise
                            % Unknown dialog. No-op is the safest path forward.
                    end
                end

                % Restore the layout of the AppContainer
                app.AppContainer.Layout = AppData.Layout;

                % Deserialize the app data
                app.deserialize(AppData);

                % Attach the DataBackend to the DataStore.
                delete(app.DataStore.DataBackend); % Make sure all previous data is removed properly
                app.DataStore.DataBackend = DataBackend;

                % Force render for all components
                for key = app.Tabs.keys'
                    app.Tabs{key}.render(Force=true);
                end

                for key = app.Panels.keys'
                    app.Panels{key}.render(Force=true);
                end

                for key = app.Documents.keys'
                    app.Documents{key}.render(Force=true);
                end

                % Workaround for g4266596: Layout restore does not activate
                % the contextual panel for the restored document selection.
                drawnow;
                lastDoc = app.AppContainer.LastSelectedDocument;
                if ~isempty(lastDoc)
                    docTag = string(lastDoc.tag);
                    panelTag = "";
                    if docTag == anomalyAPP.internal.app.document.Train.Tag
                        panelTag = anomalyAPP.internal.app.panel.TrainOptions.Tag;
                    elseif docTag == anomalyAPP.internal.app.document.Detect.Tag
                        panelTag = anomalyAPP.internal.app.panel.DetectOptions.Tag;
                    elseif docTag == anomalyAPP.internal.app.document.Compare.Tag
                        panelTag = anomalyAPP.internal.app.panel.CompareOptions.Tag;
                    end
                    if panelTag ~= "" && app.Panels.isKey(panelTag)
                        fp = app.Panels{panelTag}.getFigurePanel();
                        fp.Opened = false;
                        fp.Opened = true;
                    end
                end

                % Close the progress dialog
                delete(p);

                % Show a success message
                [~, fileNameNoExt, ext] = fileparts(fullFilePath);
                uialert(app.AppContainer, m('predmaint_anomaly:anomaly_app:strSuccessfulLoad', strcat(fileNameNoExt,ext)), ...
                    title, Icon='success');

                % Make the app not dirty and update the session name
                app.setDirtyState(false, fileNameNoExt);
            catch E
                % There was an error loading the session. Show a uialert on
                % the app after resetting the app state.
                resetAppData(app);
                delete(p);
                uialert(app.AppContainer, E.message, m('predmaint_anomaly:anomaly_app:strLoadSessionError'));
                return
            end
        end
    end

    methods (Access = public)
        function addPlotDocument(app, dataKey)
            appContainer = app.AppContainer;

            documentTag = anomalyAPP.internal.app.document.Plot.Tag + "-" + dataKey;
            documentGroupTag = app.PlotDocumentGroup.Tag;

            d = app.AppContainer.getDocument(documentGroupTag, documentTag);
            if ~isempty(d)
                d.Selected = true;
                d.Showing = true; % Buggy. Show other contextual panel!
            else
                plotDocument = anomalyAPP.internal.app.document.Plot(app.StateStore, app.DataStore, dataKey);
                fd = plotDocument.getFigureDocument();
                fd.DocumentGroupTag = documentGroupTag;
                appContainer.add(fd);

                tag = fd.Tag;
                assert(documentTag == tag); % They should be the same.
                app.Documents(tag) = {plotDocument};

                addlistener(plotDocument.getFigureDocument(), 'ObjectBeingDestroyed', @(~,~) cbRemoveDocument(app,tag));
            end

            % Bring Plot tab to the front
            tag = app.PlotDocumentGroup.Context.ToolstripTabGroupTags;
            tg = app.AppContainer.getTabGroup(tag);
            tab = tg.getChildByIndex(1);
            tg.SelectedTab = tab;
        end

        function addGettingStartedDocument(app)
            appContainer = app.AppContainer;

            documentTag = anomalyAPP.internal.app.document.GettingStarted.Tag;
            documentGroupTag = "getting_started_documentgroup";

            d = appContainer.getDocument(documentGroupTag, documentTag);
            if isempty(d)
                document = anomalyAPP.internal.app.document.GettingStarted(app.StateStore, documentGroupTag);
                fd = document.getFigureDocument();
                fd.DocumentGroupTag = documentGroupTag;
                appContainer.add(fd);

                tag = document.getFigureDocument().Tag;
                assert(document.Tag == tag); % They should be the same.
                app.Documents(tag) = {document};

                addlistener(document.getFigureDocument(), 'ObjectBeingDestroyed', @(~,~) cbRemoveDocument(app,tag));
            end
        end

        function addTrainDocument(app, options)
            arguments
                app
                options.MakeAppBusy (1,1) logical = true
            end
            appContainer = app.AppContainer;

            documentTag = anomalyAPP.internal.app.document.Train.Tag;
            documentGroupTag = app.TrainDocumentGroup.Tag;

            d = appContainer.getDocument(documentGroupTag, documentTag);
            if isempty(d)
                % Make the app busy while creating the train document, as
                % it may take a second or two to load the overviews and
                % render the document
                appContainer.Busy = options.MakeAppBusy;

                % Load the DetectorOverview Dictionary
                % If DLT is not present, load the version with only non-DL models
                [~, ~, dltFlag] = anomalyAPP.internal.utils.checkRequiredToolboxes;
                ipath = anomalyAPP.internal.utils.getAppRoot;
                if dltFlag
                    detectorOverview = load(fullfile(ipath, 'resources', 'detectorOverview.mat'), "detectorOverview");
                else
                    detectorOverview = load(fullfile(ipath, 'resources', 'detectorOverviewML.mat'), "detectorOverview");
                end

                trainDocument = anomalyAPP.internal.app.document.Train(app.StateStore, app.ModelStore, app.DataStore, detectorOverview.detectorOverview);
                fd = trainDocument.getFigureDocument();
                fd.DocumentGroupTag = documentGroupTag;
                appContainer.add(fd);

                appContainer.Busy = false; % Restore

                tag = fd.Tag;
                assert(documentTag == tag); % They should be the same.
                app.Documents(trainDocument.Tag) = {trainDocument};

                addlistener(trainDocument.getFigureDocument(), 'ObjectBeingDestroyed', @(~,~) cbRemoveDocument(app,tag));
            end
        end

        function addDetectDocument(app, options)
            arguments
                app
                options.MakeAppBusy (1,1) logical = true
            end
            appContainer = app.AppContainer;

            documentTag = anomalyAPP.internal.app.document.Detect.Tag;
            documentGroupTag = app.DetectDocumentGroup.Tag;

            d = appContainer.getDocument(documentGroupTag, documentTag);
            if isempty(d)
                % Make the app busy while creating the detect document, as
                % it may take a second or two to render the document
                appContainer.Busy = options.MakeAppBusy;

                detectDocument = anomalyAPP.internal.app.document.Detect(app.StateStore, app.ModelStore, app.DataStore);
                fd = detectDocument.getFigureDocument();
                fd.DocumentGroupTag = documentGroupTag;
                appContainer.add(fd);

                appContainer.Busy = false; % Restore

                tag = fd.Tag;
                assert(documentTag == tag); % They should be the same.
                app.Documents(detectDocument.Tag) = {detectDocument};

                addlistener(detectDocument.getFigureDocument(), 'ObjectBeingDestroyed', @(~,~) cbRemoveDocument(app,tag));
            end
        end

        function addCompareDocument(app, options)
            arguments
                app
                options.MakeAppBusy (1,1) logical = true
            end
            appContainer = app.AppContainer;

            documentTag = anomalyAPP.internal.app.document.Compare.Tag;
            documentGroupTag = app.CompareDocumentGroup.Tag;

            d = appContainer.getDocument(documentGroupTag, documentTag);
            if isempty(d)
                % Make the app busy while creating the detect document, as
                % it may take a second or two to render the document
                appContainer.Busy = options.MakeAppBusy;

                compareDocument = anomalyAPP.internal.app.document.Compare(app.StateStore, app.ModelStore, app.DataStore);
                fd = compareDocument.getFigureDocument();
                fd.DocumentGroupTag = documentGroupTag;
                appContainer.add(fd);

                appContainer.Busy = false; % Restore

                tag = fd.Tag;
                assert(documentTag == tag); % They should be the same.
                app.Documents(compareDocument.Tag) = {compareDocument};

                addlistener(compareDocument.getFigureDocument(), 'ObjectBeingDestroyed', @(~,~) cbRemoveDocument(app,tag));
            end
        end
    end
end


%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end

function tbl = generateMemberResultTable(index, groundTruthLabels, predictedLabels, resolution, includeGroundTruth, model)
    if isduration(index) || isdatetime(index)
        indexName = m('predmaint_anomaly:anomaly:strTime');
    else
        indexName = m('predmaint_anomaly:anomaly_app:strSampleIndices');
    end
    varNames = [indexName, ...
        m('predmaint_anomaly:anomaly_app:strPredictedLabels'), ...
        m('predmaint_anomaly:anomaly_app:strGroundTruthLabels')];

    % Get some configuration information from the model
    [windowLength, detectionStride, obsWindowLength] = model.Handler.getCommonWindowDefinitions(model.Model);
    modelType = model.Type;

    % Extract the information for the results table
    if strcmp(resolution, 'sample')
        % Index is already in samples, so no action.

        % Predicted labels are in window resolution by default. Convert to
        % sample resolution.
        predictedLabels = anomalyCLI.internal.utils.windowLabelsToSampleLabels(...
            predictedLabels.Labels, windowLength, predictedLabels.StartIndices, ...
            DataLength=height(index));

        % Ground truth labels are already in sample resolution, so no action.
    else % window resolution
        % Rather than the sample index (or time), we should use the window
        % start index as the index variable. The variable name should be Start
        % Indices.
        index = predictedLabels.StartIndices;
        varNames(1) = m('predmaint_anomaly:anomaly_app:strWinStartIndices');

        % Extract the predicted labels column from the detection results.
        predictedLabels = predictedLabels.Labels;

        % Ground truth labels are in sample resolution by default. Convert to
        % window resolution.
        groundTruthLabels = anomalyCLI.internal.utils.sampleLabelsToWindowLabels(...
            {groundTruthLabels}, windowLength, detectionStride, obsWindowLength, modelType);
        if ~isempty(groundTruthLabels) && iscell(groundTruthLabels)
            groundTruthLabels = groundTruthLabels{1};
        end
    end

    % At this point, the index, ground truth labels, and predicted labels are
    % all the same height. Combine them into a single results table.
    if includeGroundTruth
        tbl = table(index, predictedLabels, groundTruthLabels, 'VariableNames', varNames);
    else
        tbl = table(index, predictedLabels, 'VariableNames', varNames(1:2));
    end
end
