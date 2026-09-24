classdef CompareOptions < anomalyAPP.internal.app.AppComponent
    % Compare options panel.

    % Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strComparisonConfig')
        Tag (1,1) string = "compare_options_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener
    end

    methods
        function obj = CompareOptions(stateStore, modelStore)
            key = anomalyAPP.internal.app.panel.CompareOptions.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            weakObj = matlab.lang.WeakReference(obj);

            obj.ModelStore = modelStore;
            obj.ModelStoreListener = listener(modelStore, 'ModelChanged', @(~,ed) cbModelChanged(weakObj.Handle,ed));

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function panel = getFigurePanel(obj)
            panel = obj.Widgets.FigurePanel;
        end
    end

    % State management.
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'SelectedModel', string.empty, ...
                'PreviousSelectedModel', string.empty, ...
                'Detected', false, ...
                'DirtyFromLKGConfig', false);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Initialize state from model store.
            info = obj.ModelStore.findTrainedModels();
            if ~isempty(info.keys)
                modelKey = info.keys(1);
            else
                modelKey = string.empty;
            end

            % Initialize from Compare document, if there is one.
            if obj.hasState("compare_document")
                otherState = obj.getState("compare_document");

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                end

                state.DirtyFromLKGConfig = otherState.DirtyFromLKGConfig;
                state.Detected = otherState.Detected;
            end

            state.SelectedModel = modelKey;
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "compare_document")
                state = obj.getState();

                otherState = obj.getState(ed.Name);
                key = otherState.SelectedModel;

                state.PreviousSelectedModel = state.SelectedModel;
                state.SelectedModel = key;
                state.DirtyFromLKGConfig = otherState.DirtyFromLKGConfig;
                state.Detected = otherState.Detected;

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

            fig = obj.Widgets.FigurePanel.Figure;
            if ~isempty(state.SelectedModel)
                createDetectConfig(obj, state.SelectedModel, force);
                if state.DirtyFromLKGConfig
                    if state.Detected
                        msg = m('predmaint_anomaly:anomaly_app:warnDetectionConfigDirty');
                    else
                        msg = m('predmaint_anomaly:anomaly_app:warnDetectionConfigDirtyFromDefault');
                    end
                    setAlertBoxMessage(fig, "warning", msg);
                else
                    setAlertBoxMessage(fig);
                end
            else
                setAlertBoxMessage(fig);
            end

            if isfield(obj.Widgets.Model, 'RevertButton')
                obj.Widgets.Model.RevertButton.Enable = state.DirtyFromLKGConfig;
            end
        end
    end

    % Event management.
    methods (Access = private)
        function cbModelChanged(obj, ed)
            key = ed.Name;
            state = obj.getState();

            switch ed.Data.Status
                case "Added"
                case "Removed"
                case "Changed"
                    % Re-render if the selected model has changed.
                    if ~isempty(state.SelectedModel) && any(state.SelectedModel == key)
                        render_(obj)
                    end
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            comparePanelOptions.Title = obj.Title;
            comparePanelOptions.Tag = obj.Tag;
            comparePanelOptions.Region = "right";
            fp = matlab.ui.internal.FigurePanel(comparePanelOptions);
            fp.Contextual = true;

            % Main grid layout with scrollable content area and alert box.
            mainGrid = uigridlayout(fp.Figure);
            mainGrid.RowHeight = {'1x', 'fit', 'fit'};
            mainGrid.ColumnWidth = {'1x', 'fit'};
            mainGrid.Padding = 10;

            % Scrollable content grid for configuration widgets.
            contentGrid = uigridlayout(mainGrid);
            contentGrid.Layout.Row = 1;
            contentGrid.Layout.Column = [1 2];
            contentGrid.RowHeight = {'fit', 'fit', '1x'};
            contentGrid.ColumnWidth = {'1x', 'fit'};
            contentGrid.Padding = 0;
            contentGrid.Scrollable = 'on';

            % Alert box for dirty config warning.
            alertBox = anomalyAPP.internal.utils.makeAlertBox(mainGrid, "message");
            alertBox.Layout.Row = 2;
            alertBox.Layout.Column = [1 2];

            obj.Widgets = struct(...
                'FigurePanel', fp, ...
                'MainGrid', contentGrid, ...
                'Model', struct());
        end

        function createDetectConfig(obj, modelName, force)
            arguments
                obj
                modelName
                force (1,1) logical = false
            end
            state = obj.getState();
            model = obj.ModelStore.getModel(modelName);

            if force || isempty(fieldnames(obj.Widgets.Model)) || ~isequal(state.PreviousSelectedModel, modelName)
                % Reconstruct widgets when the model changes.
                obj.Widgets.Model = struct();
                delete(obj.Widgets.MainGrid.Children);

                model.Handler.createDetectOptionsPanel(obj, obj.ModelStore, modelName);
            end

            % Sync widget values with the current tip config.
            anomalyAPP.internal.app.modelmanager.utils.updateOptionsPanel(model.TipDetectConfig, obj.Widgets);
        end
    end
end

%% Helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
