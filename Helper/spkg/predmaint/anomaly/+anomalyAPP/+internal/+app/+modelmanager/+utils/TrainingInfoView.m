classdef TrainingInfoView < handle
    % TrainingInfoView  

    %   Copyright 2025 The MathWorks, Inc.

    properties (Access = private)
        % MonitorModel (experiment.shared.MonitorModel.MonitorModel)
        % The monitor's MonitorModel which fires training update events.
        MonitorModel

        % MonitorFactory (deepmonitor.internal.MonitorFactory) Factory to
        % create the monitor view components.
        MonitorFactory

        % MainLayout (uigridlayout) Main grid layout holding all the
        % components.
        MainLayout

        % InfoStripView  (experiment.shared.view.InfoStripView)
        % View for displaying info names and values as two columns with
        % multiple rows in a gridlayout, where the first column is the info
        % names and the second column the info values.
        InfoStripView

        % ProgressLayout  (uigridlayout) Layout which hold the progress
        % bar, stop button and status labels.
        ProgressLayout

        % ProgressBar (matlab.ui.control.internal.ProgressIndicator)
        % Horizontal progress bar
        ProgressBar

        StopButton

        % ElapsedTimeValue  (uilabel) The label which displays the elapsed time.
        ElapsedTimeValue

        % StatusLabelValue (uilabel) The label which displays the status
        % value.
        StatusLabelValue

        % StopReasonLabelName (uilabel) The label which displays the stop
        % reason name.
        StopReasonLabelName

        % StopReasonLabelValue (uilabel) The label which displays the stop
        % reason value.
        StopReasonLabelValue

        % WarningSectionParent  (uigridlayout) Section which hold the log
        % scale warning icon and uilabel.
        WarningSectionParent

        % WarningTextLabel  (uilabel) Hold the log warning text.
        WarningTextLabel

        % Listeners  cell array of listeners on the TrainingViewModel and
        % MonitorModel
        Listeners
    end

    methods
        function this = TrainingInfoView(parent,monitorModel,monitorFactory)
            this.MonitorFactory = monitorFactory;
            this.MonitorModel = monitorModel;

            this.MainLayout = uigridlayout(parent,...
                RowHeight={'fit','fit','fit','fit'},...
                ColumnWidth={'1x'},...
                RowSpacing=10,...
                Padding=[10,10,10,10],...
                Scrollable=true);

            this.createWarningSection();
            this.createProgressAndStopSection();
            this.createTimeSection();
            this.createInfoSection();

            weakThis = matlab.lang.WeakReference(this);
            this.Listeners{end+1} = listener(this.MonitorModel, 'Progress', 'PostSet', @(~, evtData) weakThis.Handle.onProgressPostSet(evtData));
            this.Listeners{end+1} = listener(this.MonitorModel, 'Status', 'PostSet', @(~, evtData) weakThis.Handle.onStatusPostSet(evtData));
            this.Listeners{end+1} = listener(this.MonitorModel, 'StopReason', 'PostSet', @(~, evtData) weakThis.Handle.onStopReasonPostSet(evtData));
            this.Listeners{end+1} = listener(this.MonitorModel, 'LogWarningString', 'PostSet', @(~, evtData) weakThis.Handle.onLogWarningUpdated(evtData));
            this.Listeners{end+1} = listener(this.MonitorModel, 'ElapsedTimeUpdated', @(~, ~) weakThis.Handle.onElapsedTimeUpdated());
            this.Listeners{end+1} = listener(this.MonitorModel, 'HasStopBeenAccessed', 'PostSet', @(~, ~)weakThis.Handle.onStopAccessed());
        end

        function delete(this)
            for i = 1:length(this.Listeners)
                delete(this.Listeners{i});
            end
            this.Listeners = {};
        end
    end

    methods (Access = private)
        function createWarningSection(this)
            this.WarningSectionParent = uigridlayout(this.MainLayout,...
                RowHeight = {0},...
                ColumnWidt = {'fit', '1x'},...
                Padding = [0, 0, 0, 0],...
                RowSpacing = 0,...
                Visible = "off");

            warningIcon = uiimage(this.WarningSectionParent);
            matlab.ui.control.internal.specifyIconID(warningIcon, 'warning', 16);

            this.WarningTextLabel = uilabel(this.WarningSectionParent,...
                Text = "",...
                WordWrap = "on");

            this.updateWarningSection(this.MonitorModel.LogWarningString);
        end

        function updateWarningSection(this, logWarningString)
            if isempty(logWarningString)
                this.WarningTextLabel.Text = "";
                this.WarningSectionParent.Visible = "off";
                this.WarningSectionParent.RowHeight{1} = 0;

            else
                this.WarningTextLabel.Text = logWarningString;
                this.WarningSectionParent.Visible = "on";
                this.WarningSectionParent.RowHeight{1} = 'fit';
            end
        end

        function createProgressAndStopSection(this)
            % Third row is hidden as it's the stop reason which should only
            % appear once training has stopped.
            this.ProgressLayout = uigridlayout(this.MainLayout,...
                RowHeight =  {iPreferredHeight(), iPreferredHeight(), 0},...
                ColumnWidth = {'fit', '1x', iStopButtonWidth()},...
                Padding = [0, 0, 0, 0],...
                RowSpacing = 0);

            this.createProgressBar();
            this.createStopButton();
            this.createStatusLabel();
            this.createStopReasonLabel();
        end

        function createProgressBar(this)
            uilabel(this.ProgressLayout,...
                Text = string(message('nnet_deepmonitor:view:ProgressName')),...
                FontSize = iFontSizeInPixels());

            this.ProgressBar = matlab.ui.control.internal.ProgressIndicator(...
                Parent = this.ProgressLayout,...
                Value = this.MonitorModel.Progress/100);
        end

        function createStopButton(this)
            this.StopButton = experiment.shared.view.StopButton(this.ProgressLayout);
            this.StopButton.ButtonClickedFcn = @(~,~)this.onStopButtonPushed();
        end

        function createStatusLabel(this)
            statusLabelName = uilabel(this.ProgressLayout,...
                Text = string(message('nnet_deepmonitor:view:StatusName')),...
                FontSize = iFontSizeInPixels());
            statusLabelName.Layout.Column = 1;
            statusLabelName.Layout.Row = 2;

            this.StatusLabelValue = uilabel(this.ProgressLayout,...
                Text = this.MonitorModel.Status,...
                FontSize = iFontSizeInPixels());
            this.StatusLabelValue.Layout.Column = 2;
            this.StatusLabelValue.Layout.Row = 2;
        end

        function createStopReasonLabel(this)
            this.StopReasonLabelName = uilabel(this.ProgressLayout,...
                Text = string(message('nnet_deepmonitor:view:StopReasonName')),...
                FontSize = iFontSizeInPixels(),...
                Visible = "off");
            this.StopReasonLabelName.Layout.Column = 1;
            this.StopReasonLabelName.Layout.Row = 3;

            this.StopReasonLabelValue = uilabel(this.ProgressLayout,...
                Text = this.MonitorModel.StopReason,...
                FontSize = iFontSizeInPixels(),...
                Visible = "off");
            this.StopReasonLabelValue.Layout.Column = 2;
            this.StopReasonLabelValue.Layout.Row = 3;
        end

        function createTimeSection(this)
            timeSection = uigridlayout(this.MainLayout, ...
                RowHeight = {iTextHeightInPixels(), iTextHeightInPixels(), iTextHeightInPixels()}, ...
                ColumnWidth = {'1x'}, ...
                RowSpacing = 0, ColumnSpacing = 0,...
                Padding = [0, 0, 0, 0]);

            uilabel(timeSection,...
                Text = string(message('nnet_deepmonitor:view:TimeHeading')),...
                FontSize = iFontSizeInPixels(),...
                FontWeight = "bold");
            this.createStartTimeLabel(timeSection);
            this.createElapsedTimeLabel(timeSection);
        end

        function createStartTimeLabel(this, parent)
            startTimeSection = uigridlayout(parent, ...
                RowHeight =  {'fit'}, ...
                ColumnWidth = {'0.5x', '0.5x'}, ...
                Padding = [0, 0, 0, 0],...
                RowSpacing = 0, ColumnSpacing = 0);

            uilabel(startTimeSection, ...
                Text = string(message('nnet_deepmonitor:view:StartTimeLabel')), ...
                FontSize = iFontSizeInPixels());

            str = iDateTimeAsString(this.MonitorModel.StartTime);

            uilabel(startTimeSection, ...
                Text = str, ...
                FontSize = iFontSizeInPixels());
        end

        function createElapsedTimeLabel(this, parent)
            elapsedTimeSection = uigridlayout(parent, ...
                RowHeight = {'fit'}, ...
                ColumnWidth = {'0.5x', '0.5x'}, ...
                Padding = [0, 0, 0, 0],...
                RowSpacing = 0, ColumnSpacing = 0);

            uilabel(elapsedTimeSection, ...
                Text = string(message('nnet_deepmonitor:view:ElapsedTimeLabel')), ...
                FontSize = iFontSizeInPixels());

            elapsedTime = string(this.MonitorModel.ElapsedTime);
            this.ElapsedTimeValue = uilabel(elapsedTimeSection, ...
                Text = elapsedTime, ...
                FontSize = iFontSizeInPixels());
        end

        function createInfoSection(this)
            infoSection = uigridlayout(this.MainLayout, ...
                RowHeight = {'fit', 'fit'}, ...
                ColumnWidth = {'1x'}, ...
                RowSpacing = 0, ColumnSpacing = 0,...
                Padding = 0);
            uilabel(infoSection,...
                Text = string(message('nnet_deepmonitor:view:InformationHeading')),...
                FontSize = iFontSizeInPixels(),...
                FontWeight = "bold");
            this.InfoStripView = this.MonitorFactory.createInfoStripView(infoSection, this.MonitorModel);
        end

        function onLogWarningUpdated(this, ~)
            this.updateWarningSection(this.MonitorModel.LogWarningString);
        end

        function onProgressPostSet(this, ~)
            this.ProgressBar.Value = this.MonitorModel.Progress/100;
        end

        function onStopButtonPushed(this)
            this.MonitorModel.StopRequested = true;
        end

        function onElapsedTimeUpdated(this)
            elapsedTime = this.MonitorModel.ElapsedTime;

            str = string(elapsedTime);

            this.ElapsedTimeValue.Text = str;
        end

        function onStatusPostSet(this, evtData)
            this.StatusLabelValue.Text = evtData.AffectedObject.Status;
        end

        function onStopReasonPostSet(this, evtData)
            this.StopReasonLabelValue.Text = evtData.AffectedObject.StopReason;
            this.StopReasonLabelName.Visible = "on";
            this.StopReasonLabelValue.Visible = "on";
            this.ProgressLayout.RowHeight{3} = iPreferredHeight();
            this.StopButton.Disabled = true;
        end

        function onStopAccessed(this)
            if this.MonitorModel.StopRequested
                this.StopButton.Disabled = true;
            end
        end
    end
end

function p = iPreferredHeight()
p = 25;
end

function w = iStopButtonWidth()
w = 44;
end

function pixels = iFontSizeInPixels()
pixels = 12;
end

function height = iTextHeightInPixels()
height = 23;
end

function str = iDateTimeAsString(dt)
% Use default locale's format.
defaultFormat = datetime().Format;
dt.Format = defaultFormat;
str = char(dt);
end