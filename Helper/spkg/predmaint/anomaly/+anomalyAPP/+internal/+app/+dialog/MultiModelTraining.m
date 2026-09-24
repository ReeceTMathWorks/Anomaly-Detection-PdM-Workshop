classdef MultiModelTraining < anomalyAPP.internal.app.AppComponent
    % Multi-Model Training dialog for the tsAD App.

    % Copyright 2026 The MathWorks

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strTrainAllTitle')
        Tag (1,1) string = "multi_model_training_dialog"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataStore anomalyAPP.internal.utils.DataStore
        ModelStore anomalyAPP.internal.utils.ModelStore

        IsTraining (1,1) logical = false   % active training loop (toggles Start/Stop All)
        ActiveRow (1,1) double  = 0     % UI-only: currently training row
        ActiveStatusColorStyle    % semantic color style
        ActiveStatusStyle    % bold style

        StopRequested (1,1) logical = false   % request to break remaining queue
        CloseRequested (1,1) logical = false % deferred close during training
        StopDlg    % uiprogressdlg handle
        LastStyledRow (1,1) double = 0
    end

    methods (Access = public)
        function obj = MultiModelTraining(stateStore, dataStore, modelStore)
            key = anomalyAPP.internal.app.dialog.MultiModelTraining.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);
            obj.DataStore = dataStore;
            obj.ModelStore = modelStore;
            createComponents(obj);
            reset(obj);

            if isvalid(obj.Widgets.Figure)
                obj.Widgets.Figure.Visible = 'on';
            end
        end

        function delete(obj)
            if ~isempty(obj.Widgets) && isfield(obj.Widgets,'Figure') && isvalid(obj.Widgets.Figure)
                delete(obj.Widgets.Figure);
            end
        end
    end

    methods (Access = protected)
        function state = getDefaultState(~)
            template = table('Size', [0 7], ...
                'VariableNames', {'DetectorName','Key','isSelected', 'StatusKey', 'Status', 'F1Score', 'TimeTaken'}, ...
                'VariableTypes', {'string','string','logical', 'string', 'string', 'double', 'duration'});
            state = struct('SelectedDetectors', template, ...
                'SelectedData', string.empty);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Training data (single selection)
            info = obj.DataStore.findTrainingData();
            state.SelectedData = info.keys;

            % Model inventory
            allmodels = obj.ModelStore.getModelNames();
            tmodels = obj.ModelStore.findTrainedModels();

            % Collect trained-but-dirty models
            dirtyKeys = strings(0,1);
            for k = tmodels.keys'
                mdl = obj.ModelStore.getModel(k);
                if ~isequaln(mdl.TipConfig,mdl.LKGConfig)
                    dirtyKeys(end+1,1) = k; %#ok<AGROW>
                end
            end

            % Get the desired models list and order them like model browser
            wantedKeys = [dirtyKeys; setdiff(allmodels.keys, tmodels.keys)];
            otherKeys  = obj.getState("model_panel").ModelTable.Key;
            orderedKeys = intersect(otherKeys, wantedKeys, 'stable');

            %Resize the table for pre-allocation
            if ~isempty(orderedKeys)
                n = numel(orderedKeys);

                % Ensure table has correct rows
                tmpl = state.SelectedDetectors;
                T = table('Size',[n width(tmpl)], ...
                    'VariableNames', tmpl.Properties.VariableNames, ...
                    'VariableTypes', tmpl.Properties.VariableTypes);
                
                %Column var assignments
                T.DetectorName(:) = "";
                T.Key(:)          = "";
                T.isSelected(:)   = true;
                T.StatusKey(:)    = "";
                T.Status(:)       = "";
                T.F1Score(:) = NaN;
                T.TimeTaken(:)= seconds(NaN);
                T.TimeTaken.Format = 'hh:mm:ss.SS';

                for i = 1:n
                    key   = orderedKeys(i);
                    model = obj.ModelStore.getModel(key);
                    T.DetectorName(i) = model.Name;
                    T.Key(i)          = key;
                    if ismember(key, dirtyKeys)
                        T.StatusKey(i) = "predmaint_anomaly:anomaly_app:strUnappliedConfig";
                    else
                        T.StatusKey(i) = "predmaint_anomaly:anomaly_app:strUntrained";
                    end
                    T.Status(i) = m(T.StatusKey(i));
                end
                state.SelectedDetectors = T;
            end
            obj.setState(state);
        end

        function update_(~, ~)
        end

        function render_(obj, ~)
            state = obj.getState();
            T = state.SelectedDetectors;
            n = height(T);

            % Build display data (cell-based UI table)
            data = cell(n,5);
            if n > 0
                data(:,1) = num2cell(T.isSelected);
                data(:,2) = cellstr(T.DetectorName);

                % Status text
                data(:,3) = cellstr(T.Status);

                f1 = T.F1Score;
                f1Cell = repmat({''},n,1);
                idx = ~isnan(f1);
                f1Cell(idx) = num2cell(f1(idx));
                data(:,4) = f1Cell;

                tt = T.TimeTaken;
                tCell = repmat({''},n,1);
                idx = ~ismissing(tt);
                tCell(idx) = cellstr(string(tt(idx)));
                data(:,5) = tCell;
            end

            tbl = obj.Widgets.SummaryTable;
            tbl.Data = data;

            % only update styles when active row changes
            if obj.ActiveRow ~= obj.LastStyledRow
                removeStyle(tbl);
                if obj.ActiveRow>=1 && obj.ActiveRow<=n
                    addStyle(tbl, obj.ActiveStatusColorStyle, "cell", [obj.ActiveRow 3]);
                    addStyle(tbl, obj.ActiveStatusStyle, "cell", [obj.ActiveRow 3]);
                end
                obj.LastStyledRow = obj.ActiveRow;
            end

            if ~obj.IsTraining
                obj.setProgressIdle();
            end

            obj.Widgets.CurrentData.Text = obj.DataStore.getData(state.SelectedData).Name;

            % Initial Start state (enabled if pending+checked exist)
            obj.updateStartToggleState();
        end
    end

    methods (Access = private)
        function createComponents(obj)
            weak_obj = matlab.lang.WeakReference(obj);

            fig = uifigure( ...
                'Name', anomalyAPP.internal.app.dialog.MultiModelTraining.Title, ...
                'Tag', anomalyAPP.internal.app.dialog.MultiModelTraining.Tag);
            fig.WindowStyle = 'alwaysontop';
            fig.Position(3) = 600;
            fig.Position(4) = 650;
            fig.Visible = 'off';
            fig.CloseRequestFcn = @(~,~) requestClose(weak_obj.Handle);

            mainLayout = uigridlayout(fig, ...
                'RowHeight', {'fit', 'fit', 'fit', '1x', 'fit', 'fit', '1x', 100, 'fit'}, ...
                'ColumnWidth', {'fit', 'fit', '1x', 'fit'});

            dataLbl = uilabel(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strTrainingData')+":", ...
                'FontWeight','bold');
            dataLbl.Layout.Row = 1;
            dataLbl.Layout.Column = 1;

            currData = uilabel(mainLayout, 'Text','');
            currData.Layout.Row = 1;
            currData.Layout.Column = 2;

            progressLbl = uilabel(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strProgress'), ...
                'FontWeight','bold');
            progressLbl.Layout.Row = 2;
            progressLbl.Layout.Column = 1;

            progWrapper = uipanel(mainLayout,"BorderType","none");
            progWrapper.Layout.Row = 2;
            progWrapper.Layout.Column = [2 3];

            inner = uigridlayout(progWrapper, [1 1], ...
                'RowHeight', {28}, 'ColumnWidth', {'1x'}, 'Padding', [0 0 0 0]);

            progBar = uihtml(inner);
            progBar.Layout.Row = 1;
            progBar.Layout.Column = 1;

            stopAllBtn = uibutton(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strStart'), ...
                'ButtonPushedFcn', @(~,~) onStartStopButton(weak_obj.Handle));
            matlab.ui.control.internal.specifyIconID(stopAllBtn, 'run', 16);
            stopAllBtn.Layout.Row = 2;
            stopAllBtn.Layout.Column = 4;

            tblHeader = uilabel(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strDetectorSelection'), ...
                'FontWeight','bold');
            tblHeader.Layout.Row = 3;
            tblHeader.Layout.Column = [1 2];

            summaryTbl = uitable(mainLayout, ...
                'RowStriping','off', ...
                'ColumnName', {'', m('predmaint_anomaly:anomaly_app:strDetector'), ...
                m('predmaint_anomaly:anomaly_app:strStatusTitle'), ...
                m('predmaint_anomaly:anomaly_app:strF1Score'), ...
                m('predmaint_anomaly:anomaly_app:strTimeElapsed')}, ...
                'ColumnEditable', [true false false false false], ...
                'ColumnWidth', {30, '2x','auto'}, ...
                'SelectionType', 'row', ...
                'RowName', cell.empty);
            summaryTbl.Layout.Row = 4;
            summaryTbl.Layout.Column = [1 4];
            summaryTbl.CellEditCallback = @(src,evt) onSelectionChanged(weak_obj.Handle, src, evt);

            currentLbl = uilabel(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strDetectorInTraining'), ...
                'FontWeight','bold');
            currentLbl.Layout.Row = 5;
            currentLbl.Layout.Column = 1;

            currModel = uilabel(mainLayout, 'Text','--');
            currModel.Layout.Row = 5;
            currModel.Layout.Column = 2;

            lossGrid = uigridlayout(mainLayout, ...
                "RowHeight", {'1x'}, "ColumnWidth", {'3x', '1x'}, ...
                "RowSpacing", 0, "ColumnSpacing", 0, ...
                'Padding', [0,10,0,10], "Scrollable", "on", 'Visible','off');
            lossGrid.Layout.Row = [6 8];
            lossGrid.Layout.Column = [1 4];

            noPlotLbl = uilabel(mainLayout, ...
                'Text', m('predmaint_anomaly:anomaly_app:strDefaultLossPlot'), ...
                'HorizontalAlignment','center', 'FontWeight','bold','Visible','on');
            noPlotLbl.Layout.Row = [6 8];
            noPlotLbl.Layout.Column = [1 4];

            ButtonPanel = controllib.widget.internal.buttonpanel.ButtonPanel(mainLayout, ["Help","Close"]);
            ButtonPanel.ButtonWidth = 'fit';
            ButtonContainer = getWidget(ButtonPanel);
            ButtonContainer.Layout.Row = 9;
            ButtonContainer.Layout.Column = [1 4];

            ButtonPanel.HelpButton.ButtonPushedFcn = @(~,~) cbHelp(weak_obj.Handle);
            ButtonPanel.CloseButton.ButtonPushedFcn = @(~,~) requestClose(weak_obj.Handle);

            obj.Widgets = struct( ...
                'Figure', fig, ...
                'CurrentModel', currModel, ...
                'CurrentData', currData, ...
                'StopAllButton', stopAllBtn, ...
                'ProgressBar', progBar, ...
                'LossPlotGrid', lossGrid, ...
                'NoPlot', noPlotLbl, ...
                'SummaryTable', summaryTbl, ...
                'ButtonPanel', ButtonPanel);

            % UI styling components
            obj.ActiveStatusColorStyle = matlab.ui.style.internal.SemanticStyle( ...
                'FontColor', '--mw-color-success');
            obj.ActiveStatusStyle = uistyle('FontWeight', 'bold');    % Bold emphasis

            obj.initProgressBarHtml(obj.Widgets.ProgressBar);
        end

        function cbStartButton(obj)
            % Start training for rows that were checked at the moment Start was pressed.
            state = obj.getState();
            T = state.SelectedDetectors;

            if height(T) == 0
                return
            end

            pendingKeys = ["predmaint_anomaly:anomaly_app:strQueued", ...
                "predmaint_anomaly:anomaly_app:strUntrained", ...
                "predmaint_anomaly:anomaly_app:strUnappliedConfig"];

            checked = T.isSelected;
            pending = ismember(T.StatusKey, pendingKeys);
            selIdx  = find(checked & pending);

            if isempty(selIdx)
                return
            end

            obj.startIndeterminate();

            % Lock checkbox column now and keep it locked forever for this dialog instance
            obj.Widgets.SummaryTable.ColumnEditable(1) = false;

            % Mark selected rows as queued (via state)
            for kk = 1:numel(selIdx)
                r = selIdx(kk);
                obj.updateRowState(r, "predmaint_anomaly:anomaly_app:strQueued", NaN, seconds(NaN));
            end

            % Train in table order
            for k = 1:numel(selIdx)
                i = selIdx(k);

                if obj.StopRequested    %If Stop All is clicked
                    break
                end

                key = T.Key(i);
                mname = T.DetectorName(i);
                obj.Widgets.CurrentModel.Text = mname;

                model = obj.ModelStore.getModel(key);

                obj.ActiveRow = i;  % sets ActiveRow so render_ can decorate
                obj.updateRowState(i, "predmaint_anomaly:anomaly_app:strTrainingOn", [], []);
                drawnow limitrate    % For switching the context to button callbacks like stop/close

                % Data split
                selectedDataName = state.SelectedData;
                [dataStruct, ~, labels, normaldata] = obj.DataStore.getData(selectedDataName);
                pct = dataStruct.ValidationHoldoutPercentage/100;
                if isscalar(normaldata)
                    cvMode = "perSeries";
                else
                    cvMode = "perCell";
                end
                cvPartition = anomalyCLI.internal.utils.timeSeriesCvpartition(normaldata, Holdout=pct, Mode=cvMode);
                trainData = subset(cvPartition, normaldata, true);
                validationData = subset(cvPartition, normaldata, false);

                cc = model.TipConfig;
                tStart = tic;
                statusText = "";    % Placeholder for the last error message

                try
                    if (model.Handler.DetectorType == "DeepLearning")
                        obj.Widgets.LossPlotGrid.Visible = "on";
                        obj.Widgets.NoPlot.Visible = "off";
                        lossPlotHostUI = obj.Widgets.LossPlotGrid;
                        delete(allchild(lossPlotHostUI));
                        [model.Model, model.Monitor] = model.Handler.trainModel(trainData, cc, lossPlotHostUI);
                    else
                        obj.Widgets.LossPlotGrid.Visible = "off";
                        obj.Widgets.NoPlot.Visible = "on";
                        obj.Widgets.NoPlot.Text = m('predmaint_anomaly:anomaly_app:strNoPlotLabel');
                        [model.Model, model.Monitor] = model.Handler.trainModel(trainData, cc);
                    end
                    drawnow limitrate    % For quick UI response when stop/close buttons are clicked

                    model = model.Handler.updateTipDetectConfig(model);
                    model.TrainingTimestamp = datetime('now', 'TimeZone', 'UTC');
                    model.TrainingDataset = selectedDataName;
                    model.LKGConfig = model.TipConfig;

                    model = obj.validateModel(model, validationData, trainData, ...
                        state, dataStruct, cvPartition, labels);

                    metricS = model.ValidationResults(state.SelectedData).DatasetMetrics.F1Score;
                    statusKey = "predmaint_anomaly:anomaly_app:strTrained";
                catch E
                    statusKey = "predmaint_anomaly:anomaly_app:strErrored";
                    metricS = NaN;
                    msg = string(E.message);
                    statusText = m(statusKey) + ": " + msg;
                end

                elapsed = toc(tStart);
                timeD = seconds(elapsed);

                obj.ActiveRow = 0; % remove glyph/style once model finishes training
                obj.updateRowState(i, statusKey, metricS, timeD, statusText);
                obj.ModelStore.setModel(key, model);    % Let other components know that the model is trained
            end

            % Make post training UI updates
            obj.setProgressValue(100);
            obj.ActiveRow = 0;
            obj.Widgets.CurrentModel.Text = '--';
            obj.Widgets.LossPlotGrid.Visible = false;
            obj.Widgets.NoPlot.Text = m('predmaint_anomaly:anomaly_app:strReopenLabel');
            obj.Widgets.NoPlot.Visible = true;

            % After a run ends, keep Start disabled until dialog is reopened
            obj.updateStartToggleState();

            % close "Stopping..." dialog if shown
            obj.closeStoppingDialog();
        end

        function model = validateModel(obj, model, validationData, trainData, state, ...
                dataStruct, cv, labels)
            try
                model.LKGDetectConfig = model.Handler.defaultDetectConfig;
                model = anomalyAPP.internal.utils.computeValidationMetrics( ...
                    model, validationData, trainData, state.SelectedData, ...
                    dataStruct.LabelIndex, cv, labels);
            catch E
                if strcmpi(E.identifier, "predmaint_anomaly:anomaly:errMaxWindowLength")
                    msg = m('predmaint_anomaly:anomaly_app:errInsufficientDataForValidation');
                else
                    msg = E.message;
                end
                uialert(obj.Widgets.Figure, msg, m('predmaint_anomaly:anomaly_app:strValidationError'));
            end
        end

        function onStopAll(obj)
            obj.StopRequested = true;
            obj.showStoppingDialog();
            obj.updateStartToggleState();

            state = obj.getState();
            T = state.SelectedDetectors;

            isQueued = T.StatusKey == "predmaint_anomaly:anomaly_app:strQueued";
            idx = find(isQueued);
            for k = 1:numel(idx)
                obj.updateRowState(idx(k), "predmaint_anomaly:anomaly_app:strCanceled", [], []);
            end
        end

        function requestClose(obj)
            % If training is not running, close immediately
            if ~obj.IsTraining
                delete(obj);
                return
            end

            % If stop already requested, don't prompt again—just defer close and show stopping UI.
            if obj.StopRequested
                obj.CloseRequested = true;
                obj.showStoppingDialog();
                return
            end

            % Confirm user intent to stop remaining training and close the dialog.
            opts = [m('predmaint_anomaly:anomaly_app:strStopAndClose'), m('predmaint_anomaly:anomaly_app:strCancel')];
            selection = uiconfirm(obj.Widgets.Figure, ...
                m('predmaint_anomaly:anomaly_app:strCloseConfirmMsg'), ...
                m('predmaint_anomaly:anomaly_app:strConfirmCloseTitle'), ...
                "Options", opts, ...
                "DefaultOption", 1, ...
                "CancelOption", 2);

            if selection == opts(1)
                obj.CloseRequested = true;
                obj.onStopAll();           % stop remaining queue + update UI state
            end
        end

        function showStoppingDialog(obj)
            % uiprogressdlg supports an indeterminate progress bar and message.
            if isempty(obj.StopDlg) || ~isvalid(obj.StopDlg)
                obj.StopDlg = uiprogressdlg(obj.Widgets.Figure, ...
                    "Title",   m('predmaint_anomaly:anomaly_app:strStopping'), ...
                    "Message", m('predmaint_anomaly:anomaly_app:strClosingMsg'), ...
                    "Indeterminate", "on", ...
                    "Cancelable", "off");
            else
                % If already open, just refresh message (optional).
                obj.StopDlg.Message = m('predmaint_anomaly:anomaly_app:strClosingMsg');
            end
        end

        function closeStoppingDialog(obj)
            % Close the stopping dialog if it is open
            if ~isempty(obj.StopDlg) && isvalid(obj.StopDlg)
                close(obj.StopDlg);
            end
            obj.StopDlg = [];
        end

        function cbHelp(~)
            helpview('predmaint','TSADAppTrainAllHelp');
        end

        function onStartStopButton(obj)
            % Two-state button: Start -> Stop All
            if obj.IsTraining
                obj.onStopAll();
                return
            end

            % Begin run (synchronous)
            obj.StopRequested = false;
            obj.CloseRequested = false;
            obj.IsTraining    = true;

            % Guaranteed cleanup even if cbStartButton errors
            cleanupObj = onCleanup(@() obj.finishRun());

            % Update UI to training mode
            obj.updateStartToggleState();

            % Run training
            obj.cbStartButton();
        end

        function finishRun(obj)
            % Cleanup after a training run
            if isempty(obj) || ~isvalid(obj)
                return
            end

            obj.IsTraining = false;
            obj.ActiveRow  = 0;

            % Close "Stopping..." dialog if still open.
            obj.closeStoppingDialog();

            % Restore UI state
            obj.Widgets.ButtonPanel.CloseButton.Enable = 'on';
            obj.updateStartToggleState();
            

            % If the user confirmed "Stop and Close", close now
            if obj.CloseRequested
                delete(obj);
            end
        end

        function updateStartToggleState(obj)
            btn      = obj.Widgets.StopAllButton;
            closeBtn = obj.Widgets.ButtonPanel.CloseButton;

            % Has a run already started once? (checkbox column becomes locked)
            tbl = obj.Widgets.SummaryTable;
            hasRunOnce = ~isempty(tbl.ColumnEditable) && tbl.ColumnEditable(1) == false;

            if obj.IsTraining
                % During a run, Close stays disabled
                closeBtn.Enable = 'off';

                % StopAll button state during training
                matlab.ui.control.internal.specifyIconID(btn, 'stop', 16);
                if obj.StopRequested
                    btn.Text = m('predmaint_anomaly:anomaly_app:strStopping');
                    btn.Enable = 'off';
                else
                    btn.Text = m('predmaint_anomaly:anomaly_app:strStopAll');
                    btn.Enable = 'on';
                end

            else
                % Idle state
                closeBtn.Enable = 'on';

                btn.Text = m('predmaint_anomaly:anomaly_app:strStart');
                matlab.ui.control.internal.specifyIconID(btn, 'run', 16);

                % After any run ends, keep Start disabled until dialog reopened (by design).
                if hasRunOnce || obj.StopRequested || obj.CloseRequested
                    btn.Enable = 'off';
                else
                    btn.Enable = obj.computePending();
                end
            end
        end

        function updateRowState(obj, rowIdx, statusKey, metric, timeTaken, statusText)
            if nargin < 6
                statusText = "";
            end

            state = obj.getState();
            T = state.SelectedDetectors;

            if ~isempty(statusKey)
                T.StatusKey(rowIdx) = string(statusKey);

                if strlength(statusText) > 0
                    T.Status(rowIdx) = string(statusText);
                else
                    T.Status(rowIdx) = m(T.StatusKey(rowIdx));
                end
            end

            if ~isempty(metric)
                T.F1Score(rowIdx) = metric;
            end
            if ~isempty(timeTaken)
                T.TimeTaken(rowIdx) = timeTaken;
            end

            state.SelectedDetectors = T;
            obj.setState(state);
        end

        function hasPendingChecked = computePending(obj)
            hasPendingChecked = false;

            state = obj.getState();
            T = state.SelectedDetectors;
            if height(T) == 0
                return
            end

            pendingKeys = ["predmaint_anomaly:anomaly_app:strQueued", ...
                "predmaint_anomaly:anomaly_app:strUntrained", ...
                "predmaint_anomaly:anomaly_app:strUnappliedConfig"];

            checked = T.isSelected;
            pending = ismember(T.StatusKey, pendingKeys);

            hasPendingChecked = any(checked & pending);
        end

        function onSelectionChanged(obj, src, ~)
            % Persist checkbox selection in state (no UI mutation here)
            state = obj.getState();
            T = state.SelectedDetectors;

            if isempty(src.Data)
                return
            end
            checked = cell2mat(src.Data(:,1));
            if numel(checked) == height(T)
                T.isSelected = checked;
                state.SelectedDetectors = T;
                obj.setState(state);
            end
            obj.updateStartToggleState();
        end

        function setProgressIdle(obj)
            sendEventToHTMLSource(obj.Widgets.ProgressBar, 'reset', struct());
        end

        function startIndeterminate(obj)
            sendEventToHTMLSource(obj.Widgets.ProgressBar, 'start', struct());
        end

        function setProgressValue(obj, v)
            if v == 100
                sendEventToHTMLSource(obj.Widgets.ProgressBar, 'complete', struct());
            else
                sendEventToHTMLSource(obj.Widgets.ProgressBar, 'reset', struct());
            end
        end

        function initProgressBarHtml(obj, htmlComp)
            htmlComp.HTMLSource = obj.getProgressBarHtml();
        end

        function html = getProgressBarHtml(~)
            lines = [
                "<!DOCTYPE html>"
                "<html><head><meta charset=""utf-8"">"
                "<style>"
                ":root{color-scheme:light dark;}"
                "body{margin:0;font-family:system-ui,""Segoe UI"",Arial,sans-serif}"
                ".wrap{display:flex;flex-direction:column;gap:6px;padding:6px}"
                "progress{width:100%;height:12px;accent-color:#0072BD;}"
                "progress::-webkit-progress-bar{background-color:#D0D0D0;}"
                "progress::-webkit-progress-value{background-color:#0072BD;}"
                "progress::-moz-progress-bar{background-color:#0072BD;}"
                "</style></head><body>"
                "<div class=""wrap""><progress id=""p"" value=""0"" max=""100"">0%</progress></div>"
                "<script>"
                "function setup(htmlComponent){"
                " const p=document.getElementById('p');"
                " htmlComponent.addEventListener('reset',    () => {p.setAttribute('max','100'); p.setAttribute('value','0');});"
                " htmlComponent.addEventListener('start',    () => {p.removeAttribute('value');});"
                " htmlComponent.addEventListener('complete', () => {p.setAttribute('max','100'); p.setAttribute('value','100');});"
                "}"
                "</script>"
                "</body></html>"];
            html = strjoin(lines, newline);
        end
    end
end

% Helper functions
function s = m(id, varargin)
% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end