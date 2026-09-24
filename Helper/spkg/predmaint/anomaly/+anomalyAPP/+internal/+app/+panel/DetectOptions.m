classdef DetectOptions < anomalyAPP.internal.app.AppComponent
    % Detect options panel.

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strDetectionConfig')
        Tag (1,1) string = "detect_options_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener
    end

    methods
        function obj = DetectOptions(stateStore, modelStore)
            key = anomalyAPP.internal.app.panel.DetectOptions.Tag;
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

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'SelectedModel', string.empty, ...
                'PreviousSelectedModel', string.empty, ...
                'Detected', false, ... % Logical flag indicating whether the selected model has detected the current data
                'DirtyFromLKGConfig', false); % Logical flag indicating whether the configuration of the selected model is different than the LKG stored in the model itself
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Initialize state from model store, first.
            info = obj.ModelStore.findTrainedModels();
            if ~isempty(info.keys)
                modelKey = info.keys(1);
            else
                modelKey = string.empty;
            end

            % Initialize from Detect document, if there is one.
            if obj.hasState("detect_document")
                otherState = obj.getState("detect_document");

                if ~isempty(otherState.SelectedModel)
                    modelKey = otherState.SelectedModel;
                end

                state.Detected = otherState.Detected;
            end

            state.SelectedModel = modelKey;
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "detect_document")
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
            end

            if isfield(obj.Widgets.Model, 'RevertButton')
                obj.Widgets.Model.RevertButton.Enable = state.DirtyFromLKGConfig;
            end
        end
    end

    % Event management
    methods (Access = private)
        function cbSelectionChangedFcn(obj, ed)
            state = obj.getState();
            state.Selection = ed.Selection;
            obj.setState(state);
        end

        function cbModelChanged(obj, ed)
            key = ed.Name;
            state = obj.getState();

            switch ed.Data.Status
                case "Added"
                case "Removed"
                case "Changed"
                    % Needs to update only if the selected model has changed.
                    if ~isempty(state.SelectedModel) && any(state.SelectedModel == key)
                        % Force the object to re-render since the model's
                        % properties may have changed (for example if
                        % training re-computes the threshold value).
                        render_(obj)
                    end
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            %Base configuration containers are constructed here. This is to be
            %used by all the models
            detectPanelOptions.Title = obj.Title;
            detectPanelOptions.Tag = obj.Tag;
            detectPanelOptions.Region = "right";
            fp = matlab.ui.internal.FigurePanel(detectPanelOptions);
            fp.Contextual = true;

            % Create the main grid layout with a banner at the top and a
            % scrollable container for the rest of the panel and the revert
            % button at the bottom
            mainGrid = uigridlayout(fp.Figure);
            mainGrid.RowHeight = {'1x', 'fit', 'fit'};
            mainGrid.ColumnWidth = {'1x', 'fit'};
            mainGrid.Padding = 10;

            % Create the content grid layout
            contentGrid = uigridlayout(mainGrid);
            contentGrid.Layout.Row = 1;
            contentGrid.Layout.Column = [1 2];
            contentGrid.RowHeight = {'fit', 'fit', '1x'}; % Panels fit content, extra space at the bottom
            contentGrid.ColumnWidth = {'1x', 'fit'};
            contentGrid.Padding = 0;
            contentGrid.Scrollable = 'on';

            % Create the alert box
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
            % Model specific configuration widgets are constructed here along
            % with the reloading of the default/saved config values.
            state = obj.getState();
            model = obj.ModelStore.getModel(modelName);

            if force || isempty(fieldnames(obj.Widgets.Model)) || ~isequal(state.PreviousSelectedModel, modelName) % Use isequal to support case where state.PreviousSelectedModel is empty
                % Only reconstruct widgets if there are no widgets or the model has changed
                obj.Widgets.Model = struct();
                delete(obj.Widgets.MainGrid.Children);

                model.Handler.createDetectOptionsPanel(obj, obj.ModelStore, modelName);
            end

            % Restore values if changed by user
            anomalyAPP.internal.app.modelmanager.utils.updateOptionsPanel(model.TipDetectConfig, obj.Widgets);
        end
    end
end

%% Local helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
