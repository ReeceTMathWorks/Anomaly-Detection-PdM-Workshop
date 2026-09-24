classdef DataBrowser < anomalyAPP.internal.app.AppComponent
    % Training and detection data panel.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = string(message('predmaint_anomaly:anomaly_app:strDatasetsTitle'))
        Tag (1,1) string = "data_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        DataStore anomalyAPP.internal.utils.DataStore
        DataStoreListener event.listener
    end

    events
        PlotDocumentRequest
    end

    methods
        function obj = DataBrowser(statestore, datastore)
            key = anomalyAPP.internal.app.panel.DataBrowser.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, statestore);

            weakObj = matlab.lang.WeakReference(obj);
            obj.DataStore = datastore;
            obj.DataStoreListener = listener(datastore, 'DataChanged', @(~,ed) cbDataChanged(weakObj.Handle,ed));

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
            template = table('Size', [0 5], 'VariableNames', {'Key', 'Name', 'isTrainingData', 'LabelVariable', 'isSelected'}, ...
                'VariableTypes', {'string', 'string', 'logical', 'string', 'logical'});
            state = struct(...
                'DataTable', template, ...
                'Selection', string.empty, ...
                'FocusedElementID', 0);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Initialize own state from data store.
            info = obj.DataStore.getDataNames();
            keys = info.keys;
            for key = keys(:)'
                metadata = obj.DataStore.getData(key);
                state.DataTable(end+1,:) = {key, metadata.Name, metadata.isTrainingData, metadata.LabelVariable, false};
            end

            obj.setState(state);
        end

        function update_(~, ~)
        end

        function render_(obj, ~)
            state = obj.getState();

            rowsInState = cellstr(state.DataTable.Key);
            rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowGrids, 'UniformOutput', false);

            if ~isequal(rowsInState, rowsInView)
                % First add any new rows that are present in the state but are
                % not in the current view
                newRows = setdiff(rowsInState, rowsInView, 'stable');
                nNew = numel(newRows);
                if nNew > 0
                    obj.Widgets.MainGrid.RowHeight = [obj.Widgets.MainGrid.RowHeight(1:end-1) repmat({'fit'},1,nNew) obj.Widgets.MainGrid.RowHeight(end)];
                    for iAdd = 1:nNew
                        iRow = numel(rowsInView) + iAdd;
                        obj.addRow(state.DataTable(strcmp(state.DataTable.Key,newRows(iAdd)),:), iRow);
                    end
                    newGrids = setdiff(obj.Widgets.MainGrid.Children(4:end), obj.Widgets.RowGrids, 'stable');
                    obj.Widgets.RowGrids = [obj.Widgets.RowGrids; newGrids];
                end

                % Next remove any rows that are present in the view but are no
                % longer in the state
                rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowGrids, 'UniformOutput', false);
                isValidRow = ismember(rowsInView, rowsInState);
                iRemove = find(~isValidRow);
                if ~isempty(iRemove)
                    rowAdjust = zeros(numel(rowsInView), 1);
                    for i = 1:numel(iRemove)
                        iRow = iRemove(i);
                        rowAdjust(iRow+1:end) = rowAdjust(iRow+1:end) + 1;
                    end
                    for i = 1:numel(rowsInView)
                        obj.Widgets.RowGrids(i).Layout.Row = obj.Widgets.RowGrids(i).Layout.Row - rowAdjust(i);
                    end
                    delete(obj.Widgets.RowGrids(iRemove));
                    obj.Widgets.RowGrids(iRemove) = [];
                    obj.Widgets.MainGrid.RowHeight(iRemove+1) = []; % Add 1 to account for the column title labels
                end

                % At this point, the rows in the view should match the rows in
                % the state. However, they may not be in the proper order. If
                % needed, reorder the rows.
                rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowGrids, 'UniformOutput', false);
                [~, iOrder] = ismember(rowsInState, rowsInView);
                if ~issorted(iOrder)
                    for i = 1:numel(rowsInView)
                        obj.Widgets.RowGrids(iOrder(i)).Layout.Row = 1 + i; % Add 1 to account for the column title labels
                    end
                    obj.Widgets.RowGrids = obj.Widgets.RowGrids(iOrder);
                end
            end

            % All rows are present and in the right order. Make sure the
            % widgets inside the rows accurately represent the name, label
            % status, and training data status.
            strUnlabeled = getString(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            strLabeled = getString(message('predmaint_anomaly:anomaly_app:strLabeled'));
            for i = 1:numel(obj.Widgets.RowGrids)
                % Name label
                if ~strcmp(obj.Widgets.RowGrids(i).Children(2).Text, state.DataTable.Name(i))
                    obj.Widgets.RowGrids(i).Children(2).Text = state.DataTable.Name(i);
                end

                % Labeled status
                if strcmp(state.DataTable.LabelVariable(i), strUnlabeled)
                    isLabeledStr = strUnlabeled;
                else
                    isLabeledStr = strLabeled;
                end
                if ~strcmp(obj.Widgets.RowGrids(i).Children(3).Text, isLabeledStr)
                    obj.Widgets.RowGrids(i).Children(3).Text = isLabeledStr;
                end

                % Training data icon/tooltip
                if state.DataTable.isTrainingData(i)
                    matlab.ui.control.internal.specifyIconID(...
                        obj.Widgets.RowGrids(i).Children(1), 'greenCircleStatusUI', 12);
                    obj.Widgets.RowGrids(i).Children(end-1).Tooltip = ...
                        getString(message('predmaint_anomaly:anomaly_app:tipTrainingDataset'));
                else
                    matlab.ui.control.internal.specifyIconID(...
                        obj.Widgets.RowGrids(i).Children(1), '');
                    obj.Widgets.RowGrids(i).Children(end-1).Tooltip = '';
                end
            end

            % Unhighlight all the rows that are not selected, and highlight
            % the selected row(s)
            % selectedKeys = state.DataTable.Key(state.DataTable.isSelected);
            % allKeys = arrayfun(@(x)x.Tag, obj.Widgets.RowGrids, 'UniformOutput', false);
            % isSelected = ismember(allKeys, selectedKeys);
            % controllib.plot.internal.utils.setColorProperty(...
            %   obj.Widgets.RowGrids(~isSelected), ...
            %   'BackgroundColor', '--mw-backgroundColor-input');
            % controllib.plot.internal.utils.setColorProperty(...
            %   obj.Widgets.RowGrids(isSelected), ...
            %   'BackgroundColor', '--mw-backgroundColor-input');

            % Focus on the most recently selected row. If no row is
            % selected, then focus on the figure.
            rowToFocus = ceil(state.FocusedElementID/2);
            if rowToFocus == 0
                % No row is in focus. Focus on the figure
                focus(obj.Widgets.FigurePanel.Figure);
            elseif rem(state.FocusedElementID, 2) == 1
                % The dataset item is in focus
                focus(obj.Widgets.RowGrids(rowToFocus).Children(end-1));
            else
                % The hamburger menu item is in focus
                focus(obj.Widgets.RowGrids(rowToFocus).Children(end));
            end

            % The message should be visible only if there are no datasets.
            % In that case, don't show the column titles.
            V = isempty(state.DataTable.Key);
            obj.Widgets.MessageLabel.Visible = V;
            obj.Widgets.NameTitle.Visible = ~V;
            obj.Widgets.StatusTitle.Visible = ~V;
        end
    end

    % Event management
    methods (Access = private)
        function cbDataChanged(obj, ed)
            key = ed.Name;
            state = obj.getState();

            switch ed.Data.Status
                case "Added"
                    for iK = 1:numel(key)
                        metadata = obj.DataStore.getData(key(iK));
                        state.DataTable(end+1,:) = {key(iK), metadata.Name, metadata.isTrainingData, metadata.LabelVariable, false};
                    end
                case "Removed"
                    I = ismember(state.DataTable.Key, key);
                    state.DataTable(I,:) = [];
                    if ~isempty(state.Selection)
                        if any(strcmp(state.Selection, key))
                            state.Selection = string.empty;
                            state.FocusedElementID = 0;
                        else
                            % Update the focused item after removing rows
                            I_selected = find(strcmp(state.DataTable.Key, state.Selection));
                            state.FocusedElementID = 1 + 2*(I_selected-1);
                        end
                    end
                case "Changed"
                    metadata = obj.DataStore.getData(key);
                    I = (state.DataTable{:,1} == key);
                    state.DataTable.Name(I) = metadata.Name;
                    state.DataTable.isTrainingData(I) = metadata.isTrainingData;
                    state.DataTable.LabelVariable(I) = metadata.LabelVariable;
            end

            state.DataTable = sortrows(state.DataTable, ["isTrainingData", "Name"], {'descend', 'ascend'});
            obj.setState(state);
        end

        function cbKeyPressFcn(obj, ed)
            state = obj.getState();

            % If there is no data, return
            if height(state.DataTable) == 0
                return
            end

            switch ed.Key
                case {'downarrow', 'uparrow'}
                    % The down arrow will select one row below the
                    % selection. The up arrow will select one row above the
                    % selection.
                    if strcmp(ed.Key, 'downarrow')
                        inc = 1;
                    else
                        inc = -1;
                    end

                    % If nothing was selected prior to the arrow key being
                    % pressed, then the selected key is just the first key.
                    % Otherwise, the selected key is one below or above the
                    % selection.
                    if isempty(state.Selection)
                        I = 1;
                    else
                        I = find(strcmp(state.DataTable.Key, state.Selection)) + inc;
                        I = max(1, min(I, height(state.DataTable)));
                    end
                    selectedKey = state.DataTable.Key(I);

                    % The arrow keys will always update the selection
                    state.Selection = selectedKey;

                    % For a regular up/down arrow, everything should be
                    % unselected except the selection.
                    state.DataTable.isSelected(:) = false;
                    I = strcmp(state.DataTable.Key, state.Selection);
                    state.DataTable.isSelected(I) = true;

                    % After updating the selection, make sure the selection
                    % is the appropriately focused item.
                    I = find(strcmp(state.DataTable.Key, state.Selection));
                    state.FocusedElementID = 1 + 2*(I-1);
                case {'leftarrow','rightarrow'}
                    % The left and right arrows will only update focus, not
                    % selection. They should not switch focus to a
                    % different row but can help cycle between elements in
                    % the row.
                    if strcmp(ed.Key, 'rightarrow')
                        inc = 1;
                        allowChange = rem(state.FocusedElementID,2) == 1;
                    else
                        inc = -1;
                        allowChange = rem(state.FocusedElementID,2) == 0;
                    end

                    if state.FocusedElementID > 0 && allowChange
                        state.FocusedElementID = state.FocusedElementID + inc;
                    end
                case 'tab'
                    % There are two scenarios for the tab key: tab,
                    % shift-tab.
                    if isempty(ed.Modifier)
                        % Regular tab. Increase the focused element by 1.
                        state.FocusedElementID = state.FocusedElementID + 1;
                    elseif strcmp(ed.Modifier{1}, 'shift')
                        % Shift-tab. Decrease the focused element by 1.
                        state.FocusedElementID = state.FocusedElementID - 1;
                    end

                    % Make sure the FocusedElementID is valid. It must be
                    % between 0 and 2*n.
                    if state.FocusedElementID < 1 || ...
                            state.FocusedElementID > 2*height(state.DataTable)
                        state.FocusedElementID = 0;
                    end

                    % After updating the FocusedElementID, make sure the
                    % selection is the appropriately row.
                    state.DataTable.isSelected(:) = false;
                    if state.FocusedElementID == 0
                        % No row should be selected. Clear the selection.
                        state.Selection = string.empty();
                    else
                        I = ceil(state.FocusedElementID/2);
                        rowToFocus = state.DataTable.Key(I);
                        state.Selection = rowToFocus;
                        state.DataTable.isSelected(I) = true;
                    end
                case 'return'
                    if rem(state.FocusedElementID, 2) == 1 % Only execute if row item is selected
                        key = state.DataTable.Key(state.DataTable.isSelected);
                        for k = 1:numel(key)
                            edata = anomalyAPP.internal.utils.EventData(key(k));
                            obj.notify('PlotDocumentRequest', edata);
                        end
                    end
                    return
                case 'delete'
                    if rem(state.FocusedElementID, 2) == 1 % Only execute if row item is selected
                        if ~state.DataTable.isTrainingData(state.DataTable.isSelected) % Can't delete training data
                            cbDeleteMenuItemSelected(obj);
                        end
                    end
                    return
                otherwise
                    % no-op
                    return
            end
            obj.setState(state);
        end

        function cbFigureClicked(obj, es)
            if isa(es.CurrentObject, 'matlab.ui.container.GridLayout')
                state = obj.getState();
    
                % Update the focused element to be the figure
                state.FocusedElementID = 0;
                state.Selection = string.empty;
                state.DataTable.isSelected(:) = false;
    
                obj.setState(state);
            end
        end

        function cbContextMenuOpening(obj, ed)
            % If the item where the right-click occurred is not already
            % selected, then select it as the sole selection.
            state = obj.getState();
            selectedKey = ed.ContextObject.Tag;
            I = strcmp(state.DataTable.Key, selectedKey);
            rowI = find(I, 1);
            if isa(ed, 'struct')
                % The event is mocked when the kebab button was clicked
                state.FocusedElementID = 2*rowI;
            else
                % The event is a real event from right-clicking the image
                state.FocusedElementID = 2*rowI - 1;
            end
            obj.setState(state);

            % Filter the context menu items based on the selection. The
            % code above will select a dataset if it was not previously
            % selected, so we can be sure that at least one selection
            % exists. Plotting is always enabled. Deletion should be
            % enabled if the training dataset is not selected.
            if selectedKey ~= state.DataTable.Key(state.DataTable.isTrainingData)
                obj.Widgets.DeleteMenuItem.Enable = true;
                obj.Widgets.DeleteMenuItem.Tooltip = '';
            else
                obj.Widgets.DeleteMenuItem.Enable = false;
                obj.Widgets.DeleteMenuItem.Tooltip = string(message('predmaint_anomaly:anomaly_app:tipDeleteDatasetDisabled'));
            end
        end

        function cbPlotMenuItemSelected(obj)
            state = obj.getState();
            row = ceil(state.FocusedElementID/2);
            key = state.DataTable.Key(row);
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('PlotDocumentRequest', edata);
        end

        function cbDeleteMenuItemSelected(obj)
            state = obj.getState();
            row = ceil(state.FocusedElementID/2);
            key = state.DataTable.Key(row);
            obj.DataStore.removeData(key);
            ed = anomalyAPP.internal.utils.EventData(key, struct('Status', 'Removed'));
            cbDataChanged(obj, ed); % Update browser after deleting the datasets
        end

        function cbKebabButtonPressed(obj, es)
            % First trigger the context menu opening callback. We will have
            % to fake the event data as a struct with a ContextObject
            % field. Then, open the context menu where the click happened.
            contextObj = es.Parent.Children(end-1); % The parent is the row grid. The 2nd to last child in the row is the clickable image.
            ed = struct('ContextObject', contextObj);
            cbContextMenuOpening(obj, ed);
            pos = getpixelposition(es, true); % pixel position of the kebab menu with respect to the figure
            x = pos(1) + pos(3)/2;
            y = pos(2) + pos(4)/2;
            obj.Widgets.ContextMenu.open(x, y);
        end

        function cbSelectionChangedFcn(obj, es)
            state = obj.getState();

            % Find the row in the state's table that corresponds to the
            % selection and update the isSelected column.
            selectedKey = string(es.Tag);

            % A click will always update the selection
            state.Selection = selectedKey;

            % For a regular click, everything should be unselected except
            % the selection.
            state.DataTable.isSelected(:) = false;
            I = strcmp(state.DataTable.Key, state.Selection);
            state.DataTable.isSelected(I) = true;

            % After updating the selection, make sure the selection is the
            % appropriately focused item.
            if isempty(state.Selection)
                state.FocusedElementID = 0;
            else
                I = find(strcmp(state.DataTable.Key, state.Selection));
                state.FocusedElementID = 1+ 2*(I-1);
            end

            % Update the component's state
            obj.setState(state);

            % If the click was a double click, then request a plot for the
            % selected dataset(s)
            if strcmp(obj.Widgets.FigurePanel.Figure.SelectionType, "open")
                key = state.DataTable.Key(state.DataTable.isSelected);
                edata = anomalyAPP.internal.utils.EventData(key);
                obj.notify('PlotDocumentRequest', edata);
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            weak_obj = matlab.lang.WeakReference(obj);

            options.Title = obj.Title;
            options.Tag = obj.Tag;
            options.Region = "left";
            options.PreferredHeight = 150;
            fp = matlab.ui.internal.FigurePanel(options);

            % Populate data panel.
            % Add the key press and key release functions
            fp.Figure.WindowKeyPressFcn = @(~,ed) cbKeyPressFcn(weak_obj.Handle,ed);
            fp.Figure.WindowButtonDownFcn = @(es,~) cbFigureClicked(weak_obj.Handle,es);

            % Main grid for the panel
            mainGrid = uigridlayout(fp.Figure);
            mainGrid.RowHeight = {24, '1x'};
            mainGrid.ColumnWidth = {24, 'fit', '1x', 'fit', 5, 16};
            mainGrid.Padding = 0;
            mainGrid.RowSpacing = 0;
            mainGrid.ColumnSpacing = 0;
            mainGrid.Scrollable = 'on';
            controllib.plot.internal.utils.setColorProperty(mainGrid, 'BackgroundColor', '--mw-backgroundColor-input');

            % Name label
            str = getString(message('predmaint_anomaly:anomaly_app:strNameTitle'));
            nameLabel = uilabel(mainGrid, 'Text', str, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
            nameLabel.Layout.Column = 2;

            % Status label
            str = getString(message('predmaint_anomaly:anomaly_app:strStatusTitle'));
            statusLabel = uilabel(mainGrid, 'Text', str, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
            statusLabel.Layout.Column = 4;

            % Import data message
            str = getString(message('predmaint_anomaly:anomaly_app:msgImportToGetStarted'));
            messageLabel = uilabel(mainGrid, 'Text', str);
            messageLabel.Layout.Row = [1 2];
            messageLabel.Layout.Column = [1 6];
            messageLabel.FontAngle = 'italic';
            messageLabel.WordWrap = true;
            messageLabel.HorizontalAlignment = 'center';
            messageLabel.VerticalAlignment = 'center';
            messageLabel.Visible = 'off';

            % Context menu
            cMenu = uicontextmenu(fp.Figure);
            cMenu.ContextMenuOpeningFcn = @(~,ed)cbContextMenuOpening(weak_obj.Handle, ed);
            plotMenuItem = uimenu(cMenu, 'Text', string(message('predmaint_anomaly:anomaly_app:strPlotItem')), 'Tag', 'plot');
            plotMenuItem.MenuSelectedFcn = @(~,~)cbPlotMenuItemSelected(weak_obj.Handle);
            deleteMenuItem = uimenu(cMenu, 'Text', string(message('predmaint_anomaly:anomaly_app:strDeleteItem')), 'Tag', 'delete', 'Separator', 'on');
            deleteMenuItem.MenuSelectedFcn = @(~,~)cbDeleteMenuItemSelected(weak_obj.Handle);

            % Store the widgets
            obj.Widgets = struct( ...
                'FigurePanel', fp, ...
                'MainGrid', mainGrid, ...
                'RowGrids', [], ...
                'MessageLabel', messageLabel, ...
                'NameTitle', nameLabel, ...
                'StatusTitle', statusLabel, ...
                'ContextMenu', cMenu, ...
                'PlotMenuItem', plotMenuItem, ...
                'DeleteMenuItem', deleteMenuItem);
        end

        function addRow(obj, rowState, rowIndex)
            weak_obj = matlab.lang.WeakReference(obj);

            rowGrid = uigridlayout(obj.Widgets.MainGrid);
            rowGrid.Layout.Row = rowIndex + 1;
            rowGrid.Layout.Column = [1 6];
            rowGrid.RowHeight = {24};
            rowGrid.ColumnWidth = {24, 'fit', '1x', 'fit', 5, 16};
            rowGrid.Padding = 0;
            rowGrid.ColumnSpacing = 0;
            rowGrid.Tag = rowState.Key(1);
            controllib.plot.internal.utils.setColorProperty(rowGrid, 'BackgroundColor', '--mw-backgroundColor-input');
            rowGrid.Visible = 'off';

            % Add the training icon if needed
            trainIcon = uiimage(rowGrid);
            trainIcon.Tag = "TrainingDataIcon";
            trainIcon.Layout.Column = 1;
            trainIcon.ImageSource = nan(5,5,3);
            if rowState.isTrainingData(1)
                matlab.ui.control.internal.specifyIconID(trainIcon, 'greenCircleStatusUI', 12);
            end

            % Name label
            nameLabel = uilabel(rowGrid, 'Text', rowState.Name(1));
            nameLabel.Layout.Column = 2;

            % Is labeled label
            if strcmp(rowState.LabelVariable, getString(message('predmaint_anomaly:anomaly_app:strUnlabeled')))
                isLabeledStr = getString(message('predmaint_anomaly:anomaly_app:strUnlabeled'));
            else
                isLabeledStr = getString(message('predmaint_anomaly:anomaly_app:strLabeled'));
            end
            isLabeledLabel = uilabel(rowGrid, 'Text', isLabeledStr);
            isLabeledLabel.HorizontalAlignment = 'right';
            isLabeledLabel.Layout.Column = 4;

            % Clickable image
            im = uiimage(rowGrid, 'ScaleMethod', 'stretch');
            im.Layout.Row = 1;
            im.Layout.Column = [1 numel(rowGrid.ColumnWidth)-1];
            im.ImageSource = nan(5,5,3);
            im.Tag = rowState.Key(1);
            im.AltText = strjoin([rowState.Name(1) ": " isLabeledStr]);
            if rowState.isTrainingData(1)
                im.Tooltip = getString(message('predmaint_anomaly:anomaly_app:tipTrainingDataset'));
            end
            im.ImageClickedFcn = @(es,~)cbSelectionChangedFcn(weak_obj.Handle,es);
            im.ContextMenu = obj.Widgets.ContextMenu;

            % Hamburger menu button
            kebabBtn = uiimage(rowGrid);
            kebabBtn.Layout.Column = numel(rowGrid.ColumnWidth);
            matlab.ui.control.internal.specifyIconID(kebabBtn, 'kebabMenuUI', 16);
            kebabBtn.ImageClickedFcn = @(es,~)cbKebabButtonPressed(weak_obj.Handle,es);
            kebabBtn.Tag = 'MenuButton';
            kebabBtn.AltText = getString(message('predmaint_anomaly:anomaly_app:strMoreOptions'));

            drawnow
            rowGrid.Visible = 'on';
        end
    end

    % QE methods
    methods (Hidden)
        function qeUpdateContextMenu(obj, contextObj)
            ed = struct('ContextObject', contextObj);
            cbContextMenuOpening(obj, ed);
        end
    end
end