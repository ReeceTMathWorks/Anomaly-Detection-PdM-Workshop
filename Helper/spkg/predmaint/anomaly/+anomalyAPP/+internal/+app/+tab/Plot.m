classdef Plot < anomalyAPP.internal.app.AppComponent
    % Plot tab.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = string(message('predmaint_anomaly:anomaly_app:strPlot'))
        Tag (1,1) string = "plot_tab"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataStore anomalyAPP.internal.utils.DataStore
    end

    methods
        function obj = Plot(stateStore, dataStore)
            key = anomalyAPP.internal.app.tab.Plot.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, stateStore);

            obj.DataStore = dataStore;

            % Initialize view components after construction.
            createComponents(obj);
            reset(obj);
        end

        function panel = getTab(obj)
            panel = obj.Widgets.Tab;
        end

        function syncWithDocument(obj, plotTag)
            state = obj.getState();
            otherState = obj.getState(plotTag);

            state.CurrentMember = otherState.CurrentMember;
            state.NormalizationMethod = otherState.NormalizationMethod;
            state.DataSetKey = otherState.DataSetKey;

            obj.setState(state);
        end
    end

    % State management
    methods (Access = protected)
        function state = getDefaultState(~)
            state = struct(...
                'DataSetKey', string.empty, ...
                'CurrentMember', 1, ...
                'NormalizationMethod', 'off');
        end

        function reset(obj)
            state = obj.getDefaultState();
            obj.setState(state);
        end

        function update_(obj, ed)
        end

        function render_(obj, ~)
            state = obj.getState();
            if isempty(state.DataSetKey)
                return
            end
            metadata = obj.DataStore.getData(state.DataSetKey);
            obj.Widgets.MemberSpinner.Limits(2) = metadata.Members;
            obj.Widgets.MemberSpinner.Value = state.CurrentMember;
            obj.Widgets.NormalizationMethodDropdown.Value = state.NormalizationMethod;
        end
    end

    % Event management
    methods (Access = private)
        function cbMemberSpinner(obj, ed)
            state = obj.getState();
            state.CurrentMember = ed.EventData.Value;
            obj.setState(state);
        end

        function cbMethodDropdown(obj, ed)
            state = obj.getState();
            state.NormalizationMethod = ed.EventData.NewValue;
            obj.setState(state);
        end
    end

    methods (Access = private)
        function createComponents(obj)
            weak_obj = matlab.lang.WeakReference(obj);

            % Construct the tab
            tab = matlab.ui.internal.toolstrip.Tab();
            tab.Title = obj.Title;
            tab.Tag = obj.Tag;

            % Data section. Will have two columns
            dataSection = matlab.ui.internal.toolstrip.Section;
            dataSection.Title = string(message('predmaint_anomaly:anomaly_app:strData'));
            tab.add(dataSection);
            col1 = matlab.ui.internal.toolstrip.Column();
            col2 = matlab.ui.internal.toolstrip.Column();

            % Member label
            memberLabel = matlab.ui.internal.toolstrip.Label( ...
                string(message('predmaint_anomaly:anomaly_app:strMember')));
            col1.add(memberLabel);
            dataSection.add(col1);

            % Member spinner
            memberSpinner = matlab.ui.internal.toolstrip.Spinner([1 1], 1); % Upper limit will be set when the data set is known
            memberSpinner.Tag = 'plot_tab_member';
            memberSpinner.ValueChangedFcn = @(~, ed)cbMemberSpinner(weak_obj.Handle, ed);
            col2.add(memberSpinner);
            dataSection.add(col2);

            % Normalize section. Will have 2 column
            normalizeSection = matlab.ui.internal.toolstrip.Section;
            normalizeSection.Title = string(message('predmaint_anomaly:anomaly_app:strNormalize'));
            tab.add(normalizeSection);
            col1 = matlab.ui.internal.toolstrip.Column();
            col2 = matlab.ui.internal.toolstrip.Column();

            % Normalization method label
            methodLabel = matlab.ui.internal.toolstrip.Label(...
                string(message('predmaint_anomaly:anomaly_app:strNormalizationMethod')));
            col1.add(methodLabel);
            normalizeSection.add(col1);

            % Normalization method dropdown
            strOff = getString(message('predmaint_anomaly:anomaly_app:strOff'));
            strZscore = getString(message('predmaint_anomaly:anomaly_app:strZscore'));
            strRange = getString(message('predmaint_anomaly:anomaly_app:strRange'));
            items = {'off', strOff; 'zscore' strZscore; 'range' strRange};
            methodDropdown = matlab.ui.internal.toolstrip.DropDown(items);
            methodDropdown.Tag = 'plot_tab_normalization_method';
            methodDropdown.Value = items{1};
            methodDropdown.ValueChangedFcn = @(~, ed)cbMethodDropdown(weak_obj.Handle, ed);
            col2.add(methodDropdown);
            normalizeSection.add(col2);

            obj.Widgets = struct(...
                'Tab', tab, ...
                'MemberSpinner', memberSpinner, ...
                'MemberLabel', memberLabel, ...
                'NormalizationMethodDropdown', methodDropdown, ...
                'NormalizationMethodLabel', methodLabel, ...
                'DataSection', dataSection, ...
                'NormalizeSection', normalizeSection);
        end
    end
end
