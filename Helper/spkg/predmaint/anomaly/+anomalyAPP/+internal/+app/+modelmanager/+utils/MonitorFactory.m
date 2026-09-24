classdef MonitorFactory
    % MonitorFactory

    % Copyright 2025-2026 The MathWorks, Inc.

    properties
        Factory deepmonitor.internal.DLTMonitorFactory
        Model experiment.shared.model.MonitorModel
    end

    properties (Transient)
        Monitor deep.TrainingProgressMonitor
        MultiAxesView experiment.shared.view.MultiAxesView
        InfoPanelView anomalyAPP.internal.app.modelmanager.utils.TrainingInfoView
        FigHndl matlab.ui.Figure
        TrainingProgressListener event.proplistener
    end

    methods
        function obj = MonitorFactory(parent)
            arguments
                parent matlab.ui.container.GridLayout = []
            end
            import anomalyAPP.internal.app.modelmanager.utils.TrainingInfoView

            % Create monitor core objects
            obj.Factory = deepmonitor.internal.DLTMonitorFactory();
            obj.Model   = experiment.shared.model.MonitorModel();

            % Set InStandaloneMode=false so that the monitor doesn't create its own standalone figure
            obj.Monitor = deep.TrainingProgressMonitor(obj.Model, obj.Factory, InStandaloneMode=false);

            if isempty(parent)
                % Create model progress dialog
                obj.FigHndl = uifigure('Name',m('predmaint_anomaly:anomaly_app:strTrainingProgress'), ...
                    'Position',[600 450 400 300], ...
                    'WindowStyle','alwaysontop', ...
                    'Visible','off');

                % Create main component to hold the multi-axes view on the left and the info panel on the right
                infoPanelWidth = 325;
                mainComponent = uigridlayout(obj.FigHndl, ...
                    "RowHeight", {'1x'}, ...
                    "ColumnWidth", {'1x', infoPanelWidth}, ...
                    "RowSpacing", 0, "ColumnSpacing", 0, ...
                    'Padding', [0,10,0,10], ...
                    "Scrollable","on");

                % Create multi-axes view and info panel view.
                obj.MultiAxesView = obj.Factory.createMultiAxesView(mainComponent, obj.Model);
                obj.InfoPanelView = TrainingInfoView(mainComponent, obj.Model, obj.Factory);

                movegui(obj.FigHndl, "center")
                matlab.ui.internal.PositionUtils.fitToContent(obj.FigHndl);
                drawnow;

                % Show the figure automatically once some progress is made
                obj.TrainingProgressListener = listener(obj.Monitor, 'Progress', 'PostSet', ...
                    @(src, evt) customFigController(src, obj.FigHndl, obj.Monitor));

                % Assign a custom close request function
                obj.FigHndl.CloseRequestFcn = @(src, event) customCloseFunction(src, obj.Monitor);

            else
                % Create multi-axes view and info panel view.
                obj.MultiAxesView = obj.Factory.createMultiAxesView(parent, obj.Model);
                obj.InfoPanelView = TrainingInfoView(parent, obj.Model, obj.Factory);
                drawnow;
            end
        end

        function deleteCurrentFig(obj)
            % In embedded mode, FigHndl may be empty; guard appropriately.
            if ~isempty(obj.FigHndl) && isvalid(obj.FigHndl)
                delete(obj.FigHndl)
            end
        end

        function obj = createNewView(obj, pnlHndl)
            % Create new gridlayout and parent to the input pnlHndl
            layout = uigridlayout(pnlHndl, ...
                "RowHeight", {'1x'}, ...
                "ColumnWidth", {'1x', 'fit'}, ...
                "RowSpacing", 0, "ColumnSpacing", 0, ...
                'Padding', [0,10,0,10], ...
                "Scrollable","on");

            obj.MultiAxesView = obj.Factory.createMultiAxesView(layout,obj.Model);

            % Need to save the InfoStripView to the pnlHndl to prevent the
            % strip view from going out of scope
            pnlHndl.UserData = obj.Factory.createInfoStripView(layout,obj.Model);
        end

        function s = saveobj(obj)
            s = obj;
        end
    end
end

function customCloseFunction(src, monitor)
% Custom close function needs to ensure that the model stops training prior
% to closing the figure
stop(monitor, "Dialog Closed");
set(src, "Visible", "off")
drawnow
end

function customFigController(~, fig, monitor)
% To give the figure a few iterations to settle before becoming visible
if isempty(fig) || ~isvalid(fig)
    return
end
if isfield(monitor.InfoData, "Iteration") && numel(monitor.InfoData.Iteration) > 3 && strcmpi(fig.Visible, "off")
    drawnow
    set(fig, "Visible", "on")
end
end

% Helper functions
function s = m(id, varargin)
% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end