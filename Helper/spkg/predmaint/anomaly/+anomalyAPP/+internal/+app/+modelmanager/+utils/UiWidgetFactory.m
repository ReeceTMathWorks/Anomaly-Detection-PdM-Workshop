classdef UiWidgetFactory
    % UIWIDGETFACTORY
    % Provides static methods to create common UI components with consistent layout.

%   Copyright 2025 The MathWorks, Inc.

    methods (Static)
        function grid = createGrid(parent, title, row, nRows, opts)
            arguments
                parent matlab.ui.container.GridLayout
                title string
                row double
				nRows double
                opts.Tag string = ""
            end
            panel = uipanel(parent, 'Title', title);
            panel.Layout.Row = row;
            panel.Layout.Column = [1 numel(parent.ColumnWidth)];
            grid = uigridlayout(panel);
            grid.Scrollable = 'on';
            grid.Tag = opts.Tag;
            grid.RowHeight = repmat({'fit'}, 1, nRows);
            grid.ColumnWidth = {130, 70, '1x'}; % First column is for labels. Second column is minimum widget width. Third column is excess space for widget to expand with panel size
        end

        function lbl = createLabel(parent, text, row, tip)
            arguments
                parent matlab.ui.container.GridLayout
                text string
                row double
                tip string = ""
            end
            lbl = uilabel(parent, 'Text', text);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;
            lbl.WordWrap = 'on';
            lbl.Tooltip = tip;
        end

        function sp = createSpinner(parent, limits, value, step, row, roundFractional, upperLimitInclusive, lowerLimitInclusive, tip)
            arguments
                parent matlab.ui.container.GridLayout
                limits double
                value double
                step double
                row double
                roundFractional logical = false
                upperLimitInclusive logical = false
                lowerLimitInclusive logical = false
                tip string = ""
            end
            sp = uispinner(parent, 'Limits', limits, 'Value', value, 'Step', step);
            sp.Layout.Row = row;
            sp.Layout.Column = [2 3];
            sp.RoundFractionalValues = roundFractional;
            sp.UpperLimitInclusive = upperLimitInclusive;
            sp.LowerLimitInclusive = lowerLimitInclusive;
            sp.Tooltip = tip;
        end

        function dd = createDropdown(parent, items, itemsData, value, row, editable)
            arguments
                parent matlab.ui.container.GridLayout
                items
                itemsData
                value
                row double
                editable logical = false
            end

            dd = uidropdown(parent, ...
                'Items', items, ...
                'ItemsData', itemsData, ...
                'Value', value, ...
                'Editable', editable);
            dd.Layout.Row = row;
            dd.Layout.Column = [2 3];
        end

        function ef = createEditField(parent, value, row)
            arguments
                parent matlab.ui.container.GridLayout
                value
                row double
            end
            ef = uieditfield(parent, 'Value', value);
            ef.Layout.Row = row;
            ef.Layout.Column = [2 3];
        end

        function component = createAccordion(parent, title, row, nRows)
            arguments
                parent matlab.ui.container.GridLayout
                title string
                row double
                nRows double
            end
            accordion = matlab.ui.container.internal.Accordion('Parent', parent);
            accordion.Layout.Row = row;
            accordion.Layout.Column = [1 numel(parent.ColumnWidth)]; % Use the full space
            advancedAccordion = matlab.ui.container.internal.AccordionPanel('Parent', ...
                accordion, 'Title', title);
            component = uigridlayout(advancedAccordion);
            component.RowHeight = repmat({'fit'}, 1, nRows);
            component.ColumnWidth = {130, 70, '1x'}; % First column is for labels. Second column is minimum widget width. Third column is excess space for widget to expand with panel size
        end

        function component = createRevertButton(parent, p, row, ModelStore, modelName, buttonName, trainFlag)
            arguments
                parent
                p
                row
                ModelStore
                modelName
                buttonName
                trainFlag
            end
            import anomalyAPP.internal.app.modelmanager.utils.GenericCallbacks
            component = uibutton(p, 'Text', buttonName);
            if trainFlag
                component.Tag = 'train_panel_revert';
            else
                component.Tag = 'detect_panel_revert';
            end
            component.Layout.Row = row;
            component.Layout.Column = 2;
            component.ButtonPushedFcn = @(es,ed) GenericCallbacks.RevertButton(parent, ed, ModelStore, modelName, trainFlag);
            matlab.ui.control.internal.specifyIconID(component, 'restore', 16)
        end
    
        function lb = createListBox(parent, items, row, multiSelect)
            arguments
                parent matlab.ui.container.GridLayout
                items
                row double
                multiSelect logical = false
            end
            lb = uilistbox(parent, 'Items', items);
            lb.Layout.Row = row;
            lb.Layout.Column = [2 3];

            lb.Multiselect = multiSelect;
        end
    end
end
