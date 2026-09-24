classdef GettingStarted < anomalyAPP.internal.app.AppComponent
    % Getting Started document.

    % Copyright 2024-2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = m('predmaint_anomaly:anomaly_app:strGettingStarted')
        Tag (1,1) string = "getting_started_document"
    end

    properties (Access = public)
        Widgets
    end

    methods
        function obj = GettingStarted(store, groupTag)
            key = anomalyAPP.internal.app.document.GettingStarted.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, store);

            % Initialize view components after construction.
            createComponents(obj, groupTag);
            reset(obj);
        end

        function panel = getFigureDocument(obj)
            panel = obj.Widgets.FigureDocument;
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'Info', string.empty);
        end

        function reset(obj)
            state = obj.getDefaultState();
            obj.setState(state);
        end

        function update_(obj, ed)
            %state = obj.getState();

            %obj.setState(state);
        end

        function render_(obj, ~)
            %state = obj.getState();
        end

    end

    % Event management
    methods (Access = private)
    end

    methods (Access = private)
        function createComponents(obj, groupTag)
            import matlab.ui.internal.toolstrip.*;
            weak_obj = matlab.lang.WeakReference(obj);

            % Figure Document
            options.Title = obj.Title;
            options.DocumentGroupTag = groupTag;
            options.Tag = obj.Tag;
            options.Description = obj.Title;
            options.Closable = true;
            fd = matlab.ui.internal.FigureDocument(options);
            addlistener(fd, 'ObjectBeingDestroyed', @(~,~) delete(weak_obj.Handle));

            mainContainer = uigridlayout(fd.Figure);
            mainContainer.RowHeight = {'1x'};
            mainContainer.ColumnWidth = {'1x'};
            mainContainer.Padding = 0;

            %uihtml
            html = uihtml(mainContainer, "Tag", "getting_started_html_content");
            html.Layout.Row = 1;
            html.Layout.Column = 1;
            % html.Position = [0 0 mainContainer.Position(3) mainContainer.Position(4)];
            % get theme
            currentTheme = fd.Figure.Theme;
            ipath = anomalyAPP.internal.utils.getAppRoot;
            if strcmpi(currentTheme.Name, 'Dark Theme')
                htmlSource = fullfile(ipath, 'resources', 'gettingStarted_dark.html');
            else
                htmlSource = fullfile(ipath, 'resources', 'gettingStarted_light.html');
            end

            html.HTMLSource = htmlSource;            

            % Define listener for theme change
            addlistener(fd.Figure, 'ThemeChanged', @(src, ed)cbFigureThemeChanged(src, ed, html));
            obj.Widgets = struct( ...
                'FigureDocument', fd);
        end
    end
end

function cbFigureThemeChanged(src, ~, html)
currentTheme = src.Theme;
ipath = anomalyAPP.internal.utils.getAppRoot;
if strcmpi(currentTheme.Name, 'Dark Theme')
    htmlSource = fullfile(ipath, 'resources', 'gettingStarted_dark.html');
else
    htmlSource = fullfile(ipath, 'resources', 'gettingStarted_light.html');
end

html.HTMLSource = htmlSource;
end

% Local helper functions
function s = m(id, varargin)
    % Reads string with the given ID from its resource bundle.
    s = string(message(id, varargin{:}));
end
