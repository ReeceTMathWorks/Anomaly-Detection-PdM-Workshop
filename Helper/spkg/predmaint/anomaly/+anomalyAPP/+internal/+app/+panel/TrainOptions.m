classdef TrainOptions < anomalyAPP.internal.app.AppComponent
    % Train configuration panel.

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strConfig')
        Tag (1,1) string = "train_options_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
    end

    methods
        function obj = TrainOptions(stateStore, modelStore)
            key = anomalyAPP.internal.app.panel.TrainOptions.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.ModelStore = modelStore;

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
                'DirtyConfig', false, ... % Logical flag indicating whether the configuration of the selected model is different than the LKG stored in the model itself from the last training
                'Trained', false); % Logical flag indicating whether the selected model is trained
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Initialize state from model store, first.
            info = obj.ModelStore.getModelNames();
            if ~isempty(info.keys)
                key = info.keys(1);
            else
                key = string.empty();
            end

            % Initialize from Train document, if there is one.
            if obj.hasState("train_document")
                otherState = obj.getState("train_document");

                if ~isempty(otherState.SelectedModel)
                    key = otherState.SelectedModel;
                end
            end

            state.SelectedModel = key;
            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "train_document")
                state = obj.getState();

                otherState = obj.getState(ed.Name);
                key = otherState.SelectedModel;

                state.PreviousSelectedModel = state.SelectedModel;
                state.SelectedModel = key;
                state.DirtyConfig = otherState.DirtyConfig;
                state.Trained = otherState.Trained;

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
                createModelConfig(obj, state.SelectedModel, force);
                if state.DirtyConfig
                    if state.Trained
                        msg = m('predmaint_anomaly:anomaly_app:warnTrainingConfigDirty');
                    else
                        msg = m('predmaint_anomaly:anomaly_app:warnTrainingConfigDirtyFromDefault');
                    end
                    setAlertBoxMessage(fig, "warning", msg);
                else
                    setAlertBoxMessage(fig);
                end

            end

            if isfield(obj.Widgets.Model, 'RevertButton')
                obj.Widgets.Model.RevertButton.Enable = state.DirtyConfig;
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
    end

    methods (Access = private)
        function createComponents(obj)
            %Base configuration containers are constructed here. This is to be
            %used by all the models
            trainPanelOptions.Title = obj.Title;
            trainPanelOptions.Tag = obj.Tag;
            trainPanelOptions.Region = "right";
            fp = matlab.ui.internal.FigurePanel(trainPanelOptions);
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
            contentGrid.RowHeight = {'fit', 'fit', '1x', 'fit'}; % Panels fit content, extra space at the bottom
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

        function createModelConfig(obj, modelName, force)
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

                % Create default panel
                model.Handler.createTrainOptionsPanel(obj, obj.ModelStore, modelName);
            end

            % Restore values if changed by user
            anomalyAPP.internal.app.modelmanager.utils.updateOptionsPanel(model.TipConfig, obj.Widgets);
        end
    end
end

%% Local helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
