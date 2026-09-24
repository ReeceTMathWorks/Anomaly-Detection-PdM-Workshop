classdef ModelBrowser < anomalyAPP.internal.app.AppComponent
    % DL and ML models panel.

    % Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Title (1,1) string = string(message('predmaint_anomaly:anomaly_app:strDetectorsTitle'))
        Tag (1,1) string = "model_panel"
    end

    properties (Access = public)
        Widgets
    end

    properties (Access = private)
        ModelStore anomalyAPP.internal.utils.ModelStore
        ModelStoreListener event.listener
    end

    events
        SelectDetectorRequest
    end

    methods
        function obj = ModelBrowser(statestore, modelstore)
            key = anomalyAPP.internal.app.panel.ModelBrowser.Tag;
            obj = obj@anomalyAPP.internal.app.AppComponent(key, statestore);

            weakObj = matlab.lang.WeakReference(obj);

            obj.ModelStore = modelstore;
            obj.ModelStoreListener = listener(modelstore, 'ModelChanged', @(~,ed) cbModelChanged(weakObj.Handle,ed));

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
            template = table('Size', [0 6], 'VariableNames', {'Key', 'Model', 'Trained', 'isSelected', 'Favorite', 'TimeStamp'}, ...
                'VariableTypes', {'string', 'string', 'logical', 'logical', 'logical', 'int8'});
            state = struct(...
                'ModelTable', template, ...
                'SortMethod', 'oldestfirst', ...
                'FocusedElementID', 0);
        end

        function reset(obj)
            state = obj.getDefaultState();

            % Initialize own state from model store.
            info = obj.ModelStore.getModelNames();
            keys = info.keys;
            for iK = 1:numel(keys)
                model = obj.ModelStore.getModel(keys(iK));
                state.ModelTable(end+1,:) = {keys(iK), model.Name, ~isempty(model.TrainingTimestamp), false, false, iK};
            end

            obj.setState(state);
        end

        function update_(obj, ed)
            if (ed.Name == "train_tab") || (ed.Name == "detect_tab")
                otherState = obj.getState(ed.Name);

                state = obj.getState();
                if ~isempty(otherState.SelectedModel) && height(state.ModelTable)>0
                    % Both states have models
                    selection = state.ModelTable.Key(state.ModelTable.isSelected);
                    if otherState.SelectedModel ~= selection
                        % Selected model has changed from the train or detect
                        % tab. Make sure the browser selection matches.
                        I = strcmp(otherState.SelectedModel, state.ModelTable.Key);
                        state.ModelTable.isSelected = I;
                        obj.setState(state); % Update the view

                        % Selection changed, so notify the event listeners
                        edata = anomalyAPP.internal.utils.EventData(state.ModelTable.Key(I));
                        obj.notify('SelectDetectorRequest', edata);
                    end
                end
            end
        end

        function render_(obj, ~)
            state = obj.getState();

            rowsInState = cellstr(state.ModelTable.Key);
            rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowPanels, 'UniformOutput', false);

            if ~isequal(rowsInState, rowsInView)
                % The message should be visible only if there are no datasets.
                % In that case, don't show the column titles.
                V = isempty(state.ModelTable.Key);
                obj.Widgets.MessageLabel.Visible = V;
                obj.Widgets.NameTitle.Visible = ~V;
                obj.Widgets.StatusTitle.Visible = ~V;
                obj.Widgets.SortbyGrid.Visible = ~V;

                % First add any new rows that are present in the state but are
                % not in the current view
                newRows = setdiff(rowsInState, rowsInView, 'stable');
                nNew = numel(newRows);
                if nNew > 0
                    obj.Widgets.MainGrid.RowHeight = [obj.Widgets.MainGrid.RowHeight(1:end-1) repmat({'fit'},1,nNew) obj.Widgets.MainGrid.RowHeight(end)];
                    for iAdd = 1:nNew
                        iRow = numel(rowsInView) + iAdd;
                        obj.addRow(state.ModelTable(strcmp(state.ModelTable.Key,newRows(iAdd)),:), iRow);
                    end
                    newPanels = setdiff(obj.Widgets.MainGrid.Children(5:end), obj.Widgets.RowPanels);
                    obj.Widgets.RowPanels = [obj.Widgets.RowPanels; newPanels];
                    obj.Widgets.RowGrids = arrayfun(@(x)x.Children(1), obj.Widgets.RowPanels); % First child is the row gridlayout
                end

                % Next remove any rows that are present in the view but are no
                % longer in the state
                rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowPanels, 'UniformOutput', false);
                isValidRow = ismember(rowsInView, rowsInState);
                iRemove = find(~isValidRow);
                if ~isempty(iRemove)
                    rowAdjust = zeros(numel(rowsInView), 1);
                    for i = 1:numel(iRemove)
                        iRow = iRemove(i);
                        rowAdjust(iRow+1:end) = rowAdjust(iRow+1:end) + 1;
                    end
                    for i = 1:numel(rowsInView)
                        obj.Widgets.RowPanels(i).Layout.Row = obj.Widgets.RowPanels(i).Layout.Row - rowAdjust(i);
                    end
                    delete(obj.Widgets.RowPanels(iRemove));
                    obj.Widgets.RowPanels(iRemove) = [];
                    obj.Widgets.RowGrids(iRemove) = [];
                    obj.Widgets.MainGrid.RowHeight(iRemove+2) = []; % Add 2 to account for the column title labels and sortby
                end

                % At this point, the rows in the view should match the rows in
                % the state. However, they may not be in the proper order. If
                % needed, reorder the rows.
                rowsInView = arrayfun(@(x)x.Tag, obj.Widgets.RowPanels, 'UniformOutput', false);
                [~, iOrder] = ismember(rowsInState, rowsInView);
                if ~issorted(iOrder)
                    for i = 1:numel(rowsInView)
                        obj.Widgets.RowPanels(iOrder(i)).Layout.Row = 2 + i; % Add 2 to account for the column title labels and sortby
                    end
                    obj.Widgets.RowPanels = obj.Widgets.RowPanels(iOrder);
                    obj.Widgets.RowGrids = obj.Widgets.RowGrids(iOrder);
                end
            end

            % Go through each model and update its widgets as needed
            for iR = 1:numel(obj.Widgets.RowGrids)
                % Make sure the name of each model is correct based on the
                % state.ModelTable
                name = state.ModelTable.Model(iR);
                if ~strcmp(obj.Widgets.RowGrids(iR).Children(2).Text, name)
                    obj.Widgets.RowGrids(iR).Children(2).Text = name;
                end

                % Make sure the trained status of each model is correct based
                % on the state.ModelTable
                if state.ModelTable.Trained(iR)
                    isTrainedStr = getString(message('predmaint_anomaly:anomaly_app:strTrained'));
                else
                    isTrainedStr = getString(message('predmaint_anomaly:anomaly_app:strUntrained'));
                end
                obj.Widgets.RowGrids(iR).Children(end-2).Text = isTrainedStr;

                % Based on the new training status label, update the alt
                % text of the clickable image
                obj.Widgets.RowGrids(iR).Children(end-1).AltText = strjoin([state.ModelTable.Model(iR) ": " isTrainedStr]);

                % Make sure the favorite icon is correct
                if state.ModelTable.Favorite(iR)
                    matlab.ui.control.internal.specifyIconID(obj.Widgets.RowGrids(iR).Children(1), 'favorite', 16);
                else
                    matlab.ui.control.internal.specifyIconID(obj.Widgets.RowGrids(iR).Children(1), 'favoriteInactive', 16);
                end
            end

            % Unhighlight all the rows that are not selected, and highlight
            % the selected row(s)
            selectedKeys = state.ModelTable.Key(state.ModelTable.isSelected);
            allKeys = arrayfun(@(x)x.Tag, obj.Widgets.RowPanels, 'UniformOutput', false);
            isSelected = ismember(allKeys, selectedKeys);
            controllib.plot.internal.utils.setColorProperty(...
              obj.Widgets.RowGrids(~isSelected), ...
              'BackgroundColor', '--mw-backgroundColor-primary');
            controllib.plot.internal.utils.setColorProperty(...
              obj.Widgets.RowGrids(isSelected), ...
              'BackgroundColor', '--mw-backgroundColor-selectedFocus');

            % Update the focused element in the panel if the panel is
            % selected
            if obj.Widgets.FigurePanel.Selected
                if state.FocusedElementID == 0
                    % No row is in focus. Focus on the figure
                    focus(obj.Widgets.FigurePanel.Figure);
                elseif state.FocusedElementID == 1
                    % The sortby dropdown is in focus
                    focus(obj.Widgets.SortbyDropdown);
                else
                    % The focused element is somewhere in one of the models'
                    % rows. Determine if it is the favorite button, the row
                    % itself, or the kebab button, and focus it.
                    rowToFocus = ceil((state.FocusedElementID-1)/3); % subtract 1 because of sortby dropdown
                    if rem(state.FocusedElementID, 3) == 2
                        % The favorite button is in focus
                        focus(obj.Widgets.RowGrids(rowToFocus).Children(1));
                    elseif rem(state.FocusedElementID, 3) == 0
                        % The model row is in focus
                        focus(obj.Widgets.RowGrids(rowToFocus).Children(end-1));
                    else
                        % The kebab menu button is in focus
                        focus(obj.Widgets.RowGrids(rowToFocus).Children(end));
                    end
                end
            end
        end
    end

    % Event management
    methods (Access = private)
        function cbModelChanged(obj, ed)
            key = ed.Name;
            state = obj.getState();

            prevSelectedKey = state.ModelTable.Key(state.ModelTable.isSelected);
            switch ed.Data.Status
                case "Added"
                    maxTimeStamp = 0;
                    if height(state.ModelTable) > 0
                        maxTimeStamp = max(state.ModelTable.TimeStamp);
                    end
                    for iK = 1:numel(key)
                        model = obj.ModelStore.getModel(key(iK));
                        state.ModelTable(end+1,:) = {key(iK), model.Name, ~isempty(model.TrainingTimestamp), false, false, maxTimeStamp+iK};
                    end
                    state.ModelTable = sortModelTable(state.ModelTable, state.SortMethod);
                    if isempty(prevSelectedKey)
                        state.ModelTable.isSelected(1) = true;
                    end
                case "Removed"
                    % Delete the selected model(s) in the state
                    I = ismember(state.ModelTable.Key, key);
                    state.ModelTable(I,:) = [];

                    % If no selection remains, then the selected model was
                    % removed. Update the selection to be the first
                    % available model.
                    if height(state.ModelTable) > 0 && ~any(state.ModelTable.isSelected)
                        state.ModelTable.isSelected(1) = true;
                    end

                    % When a model is removed, likely the focused element
                    % was the one removed. It is also possible that all the
                    % models are being removed. In any case, set the
                    % focused element ID to 0.
                    state.FocusedElementID = 0;
                case "Changed"
                    model = obj.ModelStore.getModel(key);
                    I = (state.ModelTable{:,1} == key);
                    state.ModelTable.Model(I) = model.Name;
                    state.ModelTable.Trained(I) = ~isempty(model.TrainingTimestamp);
            end

            obj.setState(state);

            selectedKey = state.ModelTable.Key(state.ModelTable.isSelected);
            if ~isempty(selectedKey) && (isempty(prevSelectedKey) || prevSelectedKey ~= selectedKey)
                % When selection changes, ask for an update
                edata = anomalyAPP.internal.utils.EventData(selectedKey);
                obj.notify('SelectDetectorRequest', edata);
            end
        end

        function cbKeyPressFcn(obj, ed)
            state = obj.getState();

            % If there are no models, return
            if height(state.ModelTable) == 0
                return
            end

            switch ed.Key
                case {'uparrow','downarrow'}
                    % The down arrow will focus one row below the current
                    % focus. The up arrow will select one row above the
                    % current focus.
                    if strcmp(ed.Key, 'downarrow')
                        inc = 3; % Add 3 to get to the same column on the next row
                    else
                        inc = -3;
                    end
                    if rem(state.FocusedElementID,3) == 1
                        % On the kebab menu. Increment by one less to get
                        % the model element.
                        inc = inc - 1;
                    elseif rem(state.FocusedElementID,3) == 2
                        inc = inc + 1;
                    end
                    id = state.FocusedElementID + inc;
                    id = min(max(id, 3),3*height(state.ModelTable));
                    if state.FocusedElementID ~= 1
                        state.FocusedElementID = id;
                    end
                case {'leftarrow','rightarrow'}
                    % The left and right arrows will only update focus, not
                    % selection. They should not switch focus to a
                    % different row but can help cycle between elements in
                    % the row.
                    if strcmp(ed.Key, 'rightarrow')
                        inc = 1;
                        allowChange = any(rem(state.FocusedElementID,3) == [0 2]);
                    else
                        inc = -1;
                        allowChange = any(rem(state.FocusedElementID,3) == [0 1]);
                    end

                    if state.FocusedElementID > 1 && allowChange
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
                    % between 0 and 3n+1.
                    if state.FocusedElementID < 1 || ...
                            state.FocusedElementID > 3*height(state.ModelTable)+1
                        state.FocusedElementID = 0;
                    end
                case 'delete'
                    if rem(state.FocusedElementID, 3) == 0 % Only execute if row item is selected
                        cbDeleteMenuItemSelected(obj);
                        return
                    end
                otherwise
                    % no-op
                    return
            end

            % Update the state. render_ will take care of redrawing
            % things.
            obj.setState(state);
        end

        function cbFigureClicked(obj, es)
            if isa(es.CurrentObject, 'matlab.ui.container.GridLayout')
                state = obj.getState();

                % Update the focused element to be the figure
                state.FocusedElementID = 0;

                obj.setState(state);
            end
        end

        function cbSelectionChangedFcn(obj, es)
            state = obj.getState();

            % Find the row in the state's table that corresponds to the
            % selection and update the isSelected column.
            selectedKey = string(es.Tag);

            % Everything should be unselected except the selection.
            state.ModelTable.isSelected(:) = false;
            I = strcmp(state.ModelTable.Key, selectedKey);
            state.ModelTable.isSelected(I) = true;

            % After updating the selection, make sure the selection
            % is the appropriately focused item.
            I = find(I);
            state.FocusedElementID = 3*I;

            % Update the component's state
            obj.setState(state);

            % Request updates for the training and detection documents for
            % the last selected model
            key = state.ModelTable.Key(state.ModelTable.isSelected);
            edata = anomalyAPP.internal.utils.EventData(key);
            obj.notify('SelectDetectorRequest', edata);
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

        function cbFavoriteButtonPressed(obj, es)
            state = obj.getState();

            % Update the favorite status
            I = strcmp(state.ModelTable.Key, es.UserData); % UserData will have the key
            state.ModelTable.Favorite(I) = ~state.ModelTable.Favorite(I);
            if strcmp(state.SortMethod, 'favorite') && ~issorted(state.ModelTable.Favorite, 'descend')
                state.ModelTable = sortrows(state.ModelTable, "Favorite", 'descend');
            end
            
            % Update the focused item
            I_new = strcmp(state.ModelTable.Key, es.UserData); % UserData will have the key
            state.FocusedElementID = 3*find(I_new) - 1;          

            obj.setState(state);
        end

        function cbSortbyDropdown(obj, ed)
            state = obj.getState();

            state.ModelTable = sortModelTable(state.ModelTable, ed.Value);

            state.SortMethod = ed.Value;
            state.FocusedElementID = 1;

            obj.setState(state);

            % Log a DDUX event for the dropdown
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.SELECTION_CHANGED, ... % event type
                matlab.ddux.internal.ElementType.DROP_DOWN, ... % element type
                obj.Widgets.SortbyDropdown.Tag); % element ID
            eventData = struct('SortbyMethod', ed.Value);
            matlab.ddux.internal.logUIEvent(eventID, eventData);
        end

        function cbContextMenuOpening(obj, ed)
            % If the item where the right-click occurred is not already
            % selected, then select it as the sole selection
            state = obj.getState();
            selectedKey = ed.ContextObject.Tag;
            I = strcmp(state.ModelTable.Key, selectedKey);
            rowI = find(I, 1);
            if isa(ed, 'struct')
                % The event is mocked when the kebab button was clicked
                state.FocusedElementID = 1 + 3*rowI;
            else
                % The event is a real event from right-clicking the image
                state.FocusedElementID = 1 + 3*rowI - 1;
            end
            obj.setState(state);
        end

        function cbDeleteMenuItemSelected(obj)
            % Delete the selected model in the state
            state = obj.getState();
            row = ceil((state.FocusedElementID-1)/3); % subtract 1 because of sortby dropdown
            key = state.ModelTable.Key(row);
            state.ModelTable(row,:) = [];

            % If no selection remains, then the selected model was
            % removed. Update the selection to be the first
            % available model.
            if height(state.ModelTable) > 0
                if ~any(state.ModelTable.isSelected)
                    state.ModelTable.isSelected(1) = true;
                end

                % Deletion is not possible in a row that doesn't have
                % the focus, so use the selection to set the new focus.
                I_selected = find(state.ModelTable.isSelected);
                state.FocusedElementID = 3*I_selected;
            else
                % There are no models left, so make sure the figure
                % is the focused element
                state.FocusedElementID = 0;
            end
            obj.setState(state);

            % Remove the model from the model store
            obj.ModelStore.removeModel(key);

            % Make sure the documents update since the selection may
            % have changed
            if any(state.ModelTable.isSelected)
                edata = anomalyAPP.internal.utils.EventData(state.ModelTable.Key(state.ModelTable.isSelected));
                obj.notify('SelectDetectorRequest', edata);
            end
        end

        function cbDuplicateMenuItemSelected(obj)
            % Duplicate the selected model(s)
            state = obj.getState();
            row = ceil((state.FocusedElementID-1)/3); % subtract 1 because of sortby dropdown
            key = state.ModelTable.Key(row);
            obj.ModelStore.duplicateModel(key);
        end
    end

    methods (Access = private)
        function createComponents(obj)
           weak_obj = matlab.lang.WeakReference(obj);

            options.Title = obj.Title;
            options.Tag = obj.Tag;
            options.Region = "left";
            fp = matlab.ui.internal.FigurePanel(options);

            % Populate model panel.
            % Add the key press and key release functions
            fp.Figure.WindowKeyPressFcn = @(~,ed) cbKeyPressFcn(weak_obj.Handle,ed);
            fp.Figure.WindowButtonDownFcn = @(es,~) cbFigureClicked(weak_obj.Handle,es);

            % Main grid for the panel
            mainGrid = uigridlayout(fp.Figure);
            mainGrid.RowHeight = {24, 24, '1x'};
            mainGrid.ColumnWidth = {29, 'fit', '1x', 'fit', 5, 16};
            mainGrid.Padding = [0 0 0 5];
            mainGrid.RowSpacing = 0;
            mainGrid.ColumnSpacing = 0;
            mainGrid.Scrollable = 'on';
            controllib.plot.internal.utils.setColorProperty(mainGrid, 'BackgroundColor', '--mw-backgroundColor-input');

            % Sortby dropdown
            sortbyGrid = uigridlayout(mainGrid);
            sortbyGrid.Layout.Row = 1;
            sortbyGrid.Layout.Column = [1 6];
            sortbyGrid.RowHeight = {'1x'};
            sortbyGrid.ColumnWidth = {'1x', 'fit', 120, '1x'};
            sortbyGrid.Padding = 0;
            sortbyGrid.Tag = 'sortbyGrid';
            controllib.plot.internal.utils.setColorProperty(sortbyGrid, 'BackgroundColor', '--mw-backgroundColor-input');

            str = string(message('predmaint_anomaly:anomaly_app:strSortby'));
            sortbyLabel = uilabel(sortbyGrid, 'Text', str);
            sortbyLabel.Layout.Column = 2;

            sortbyDropdown = uidropdown(sortbyGrid);
            sortbyDropdown.Tag = 'model_panel_sortby';
            sortbyDropdown.Layout.Column = 3;
            s1 = string(message('predmaint_anomaly:anomaly_app:strSortbyOldestFirst'));
            s2 = string(message('predmaint_anomaly:anomaly_app:strSortbyNewestFirst'));
            s3 = string(message('predmaint_anomaly:anomaly_app:strSortbyFavorites'));
            s4 = string(message('predmaint_anomaly:anomaly_app:strSortbyName'));
            sortbyDropdown.Items = [s1, s2, s3, s4];
            sortbyDropdown.ItemsData = {'oldestfirst', 'newestfirst', 'favorite', 'alpha'};
            sortbyDropdown.Value = 'oldestfirst';
            sortbyDropdown.ValueChangedFcn = @(~,ed)cbSortbyDropdown(weak_obj.Handle,ed);

            % Name label
            str = getString(message('predmaint_anomaly:anomaly_app:strNameTitle'));
            nameLabel = uilabel(mainGrid, 'Text', str, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
            nameLabel.Layout.Row = 2;
            nameLabel.Layout.Column = 2;

            % Status label
            str = getString(message('predmaint_anomaly:anomaly_app:strStatusTitle'));
            statusLabel = uilabel(mainGrid, 'Text', str, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
            statusLabel.Layout.Row = 2;
            statusLabel.Layout.Column = 4;

            % Import data message
            str = getString(message('predmaint_anomaly:anomaly_app:msgAddDetectorToGetStarted'));
            messageLabel = uilabel(mainGrid, 'Text', str);
            messageLabel.Layout.Row = [1 3];
            messageLabel.Layout.Column = [1 6];
            messageLabel.FontAngle = 'italic';
            messageLabel.WordWrap = true;
            messageLabel.HorizontalAlignment = 'center';
            messageLabel.VerticalAlignment = 'center';
            messageLabel.Visible = 'off';

            % Context menu
            cMenu = uicontextmenu(fp.Figure);
            cMenu.ContextMenuOpeningFcn = @(~,ed)cbContextMenuOpening(weak_obj.Handle, ed);
            deleteMenuItem = uimenu(cMenu, 'Text', string(message('predmaint_anomaly:anomaly_app:strDeleteItem')), 'Tag', 'delete', 'Separator', 'on');
            deleteMenuItem.MenuSelectedFcn = @(~,~)cbDeleteMenuItemSelected(weak_obj.Handle);
            duplicateMenuItem = uimenu(cMenu, 'Text', string(message('predmaint_anomaly:anomaly_app:strDuplicateItem')), 'Tag', 'duplicate');
            duplicateMenuItem.MenuSelectedFcn = @(~,~)cbDuplicateMenuItemSelected(weak_obj.Handle);

            % Store the widgets
            obj.Widgets = struct( ...
                'FigurePanel', fp, ...
                'MainGrid', mainGrid, ...
                'SortbyGrid', sortbyGrid, ...
                'SortbyDropdown', sortbyDropdown, ...
                'RowPanels', [], ...
                'RowGrids', [], ...
                'MessageLabel', messageLabel, ...
                'NameTitle', nameLabel, ...
                'StatusTitle', statusLabel, ...
                'ContextMenu', cMenu, ...
                'DeleteMenuItem', deleteMenuItem, ...
                'DuplicateMenuItem', duplicateMenuItem);
        end

        function addRow(obj, rowState, rowIndex)
            weak_obj = matlab.lang.WeakReference(obj);

            rowPanel = uipanel(obj.Widgets.MainGrid);
            rowPanel.Layout.Row = rowIndex + 2;
            rowPanel.Layout.Column = [1 6];
            rowPanel.Tag = rowState.Key(1);
            controllib.plot.internal.utils.setColorProperty(rowPanel, 'BorderColor', '--mw-borderColor-primary');

            rowGrid = uigridlayout(rowPanel);
            rowGrid.RowHeight = {24, 24};
            rowGrid.ColumnWidth = {24, 5, 'fit', '1x', 'fit', 5, 16};
            rowGrid.Padding = 2;
            rowGrid.ColumnSpacing = 2;
            rowGrid.RowSpacing = 0;
            rowGrid.Tag = rowState.Key(1);
            controllib.plot.internal.utils.setColorProperty(rowGrid, 'BackgroundColor', '--mw-backgroundColor-input');
            rowGrid.Visible = 'off';

            % Favorite icon
            favoriteBtn = uibutton(rowGrid, Text='');
            favoriteBtn.Layout.Row = 1;
            favoriteBtn.Layout.Column = 1;
            favoriteBtn.Tag = 'FavoriteButton';
            matlab.ui.control.internal.specifyIconID(favoriteBtn, 'favoriteInactive', 16);
            favoriteBtn.ButtonPushedFcn = @(es,~)cbFavoriteButtonPressed(weak_obj.Handle,es);
            favoriteBtn.UserData = rowState.Key(1);

            % Name label
            nameLabel = uilabel(rowGrid, 'Text', rowState.Model(1));
            nameLabel.Layout.Row = 1;
            nameLabel.Layout.Column = 3;

            % Is trained label
            isTrainedLabel = uilabel(rowGrid, 'Text', ""); % Will be set during rendering based on the trained status of the model
            isTrainedLabel.HorizontalAlignment = 'right';
            isTrainedLabel.Layout.Row = 2;
            isTrainedLabel.Layout.Column = 5;

            % Clickable image
            im = uiimage(rowGrid, 'ScaleMethod', 'stretch');
            im.Layout.Row = [1 2];
            im.Layout.Column = [2 numel(rowGrid.ColumnWidth)-1];
            im.ImageSource = nan(5,5,3);
            im.Tag = rowState.Key(1);
            im.ImageClickedFcn = @(es,~)cbSelectionChangedFcn(weak_obj.Handle,es);
            im.ContextMenu = obj.Widgets.ContextMenu;

            % Hamburger menu button
            kebabBtn = uiimage(rowGrid);
            kebabBtn.Layout.Row = [1 2];
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

function sortedTable = sortModelTable(modelTable, sortbyMethod)
if strcmp(sortbyMethod, 'oldestfirst')
    % Sort the model table by time stamp with the oldest first
    sortedTable = sortrows(modelTable, "TimeStamp");
elseif strcmp(sortbyMethod, 'newestfirst')
    % Sort the model table by time stamp with the newest first
    sortedTable = sortrows(modelTable, "TimeStamp", 'descend');
elseif strcmp(sortbyMethod, 'favorite')
    sortedTable = sortrows(modelTable, "Favorite", 'descend');
elseif strcmp(sortbyMethod, 'alpha')
    sortedTable = sortrows(modelTable, "Model");
end
end
