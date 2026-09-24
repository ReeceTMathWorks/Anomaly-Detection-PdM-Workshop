classdef (Sealed = true) AnomalyDetection
    % Run "doc anomalyCLI.internal.utils.AnomalyDetection" for more information.

    % Copyright 2025-2026 The MathWorks, Inc.

    methods (Static, Sealed = true)
        function plotAnomalies(ax, timeSeriesData, channelNames, predictionResults, predictionWindowLength, options)
            arguments
                ax
                timeSeriesData double % Can only plot one member at a time.
                channelNames (1,:) string
                predictionResults table = table([],[],[],VariableNames={'Labels','AnomalyScores','StartIndices'})
                predictionWindowLength double = []
                options.TrueLabels (:,1) = []
                options.Time (:,1) = []
            end
            [nr,nc] = size(timeSeriesData);

            % Set up the axes.
            cla(ax);
            ax.Tag = 'signal_anomalies_axes';
            box(ax, 'on');
            axis(ax, 'padded');
            hold(ax, 'on');

            % Define the default X data. If time is provided, duration or
            % datetime may be required.
            defaultX = NaN;
            if ~isempty(options.Time)
                time = options.Time;
                if isduration(time)
                    defaultX = seconds(NaN);
                    defaultX.Format = time(1).Format;
                elseif isdatetime(time)
                    defaultX = NaT;
                    defaultX.TimeZone = time(1).TimeZone;
                    defaultX.Format = time(1).Format;
                end
            else
                % Define the time vector as 1:nr.
                time = (1:nr)';
            end

            % Construct plot components
            % Ground truth anomalies patch. Build first to put it in the
            % background.
            h = patch(ax, defaultX, NaN, 'r', LineStyle='none', ...
                Tag='labeled_anomalies', FaceAlpha=0.7, PickableParts='none');
            matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                'FaceColor', '--mw-graphics-colorOrder-10-tertiary');

            % Time series signal.
            if ~isempty(timeSeriesData)
                h = plot(ax, defaultX, NaN(1,nc), LineStyle='-', Tag="raw_signal");
                matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                    'Color', '--mw-graphics-colorOrder-1-secondary');
                if isdatetime(defaultX)
                    ax.XAxis.ReferenceDate = datetime(1970,1,1,0,0,0,'TimeZone',defaultX.TimeZone);
                end
            end

            % Predicted anomalies highlight line.
            if ~isempty(predictionResults)
                h = plot(ax, defaultX, NaN(1,nc), LineStyle='-', Tag='detected_anomalies');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                    'Color', '--mw-graphics-colorOrder-2-secondary');
            end

            hold(ax, 'off');

            % Add title and labels.
            if isempty(predictionResults)
                title(ax, msg("predmaint_anomaly:anomaly:strTimeSeriesTitle"));
            else
                title(ax, msg("predmaint_anomaly:anomaly:strAnomalies"));
            end

            if isduration(defaultX) || isdatetime(defaultX)
                xlabel(ax, msg("predmaint_anomaly:anomaly:strTime"));
            else
                xlabel(ax, msg("predmaint_anomaly:anomaly:strSamples"));
            end

            ylabel(ax, msg("predmaint_anomaly:anomaly:strSignal"));

            % Add the legend.
            ws = warning('off', 'MATLAB:legend:CappingMaxEntries'); % Will have one signal legend in the end.
            legend(ax, Location="southoutside", NumColumns=3);
            warning(ws);

            % Setup to manage plot interactivity.
            fig = ancestor(ax, 'figure');
            fig.UserData = struct('LastPointer', []);

            fig.UserData.HoverFcn = event.listener(fig, 'WindowMouseMotion', @(es,ed) HoverFcn(es,ed));
            fig.UserData.HoverFcn.Enabled = true;

            if ~isempty(options.TrueLabels) % Only needed for patch.
                %fig.UserData.YLimitsFcn = event.listener(ax.YAxis, 'LimitsChanged', @(es,ed) YLimitsFcn(es,ed));
            end

            % Update data in the plot.
            anomalyCLI.internal.utils.AnomalyDetection.updateAnomalies( ...
                ax, timeSeriesData, time, channelNames, predictionResults, ...
                predictionWindowLength, options.TrueLabels);
            setSelectedChannel(fig, 1);
        end

        function updateAnomalies(ax, timeSeriesData, time, channelNames, predictionResults, predictionWindowLength, trueLabels)
            arguments
                ax
                timeSeriesData double
                time (:,1)
                channelNames (1,:) string
                predictionResults table
                predictionWindowLength double
                trueLabels (:,1)
            end
            [nr,nc] = size(timeSeriesData);

            % Time series data.
            h = findobj(ax, 'Tag', 'raw_signal');
            assert(numel(h) == nc);
            for i = 1:nc
                str = sprintf('%s (%s)', msg("predmaint_anomaly:anomaly:strRawSignal"), channelNames{i});
                set(h(i), XData=time, YData=timeSeriesData(:,i), DisplayName=str);

                % Datatips indicating detected anomalies.
                h(i).DataTipTemplate.DataTipRows = [ ...
                    dataTipTextRow('', @(x) channelNames{i}), ...
                    dataTipTextRow('X', 'XData'), ...
                    dataTipTextRow('Y', 'YData')];
            end

            % Detected anomalies
            if ~isempty(predictionResults)
                Istart = predictionResults.StartIndices(predictionResults.Labels);
                Iend = min((Istart + predictionWindowLength - 1), nr);

                h = findobj(ax, 'Tag', 'detected_anomalies');
                if ~isempty(h)
                    for i = 1:nc
                        y = NaN(1,height(time));
                        % Locate anomalous windows.
                        for j = 1:numel(Istart)
                            I = Istart(j):Iend(j);
                            y(I) = timeSeriesData(I,i);
                        end
                        str = sprintf('%s (%s)', msg("predmaint_anomaly:anomaly:strDetectedAnomalies"), channelNames{i});
                        set(h(i), XData=time, YData=y, DisplayName=str);

                        % Datatips indicating detected anomalies.
                        h(i).DataTipTemplate.DataTipRows = [ ...
                            dataTipTextRow('', @(x) channelNames{i}), ...
                            dataTipTextRow('X', 'XData'), ...
                            dataTipTextRow('Y', 'YData')];
                    end
                end
            end

            % Ground truth anomalies
            h = findobj(ax, 'Tag', 'labeled_anomalies');
            if ~isempty(h)
                I = logical(trueLabels);
                I_prev = [false; I(1:end-1)];
                I_next = [I(2:end); false];
                startIdx = I & ~I_prev;
                endIdx = I & ~I_next;
                startTime = time(startIdx,1);
                endTime = time(endIdx,1);

                if ~isempty(timeSeriesData)
                    YLims = [min(timeSeriesData,[],"all"), max(timeSeriesData,[],"all")];
                else
                    % All channels unselected.
                    YLims = [-1; 1; 1; -1];
                end
                X = [startTime'; startTime'; endTime'; endTime'];
                Y = [YLims(1); YLims(2); YLims(2); YLims(1)];
                %Y = [ax.YLim(1); ax.YLim(2); ax.YLim(2); ax.YLim(1)];
                Y = repmat(Y, 1, width(X));
                set(h, XData=X, YData=Y, DisplayName=msg("predmaint_anomaly:anomaly:strLabeledAnomalies"));

                showInLegend = char(matlab.lang.OnOffSwitchState(~isempty(trueLabels))); % Must be the char 'on' or 'off'
                h.Annotation.LegendInformation.IconDisplayStyle = showInLegend;
            end

            % Set x limits of the axes.
            ax.XLim = [time(1),time(end)];
        end

        function plotControlChart(ax, data, names, results, windowLength, method, CL, LCL, UCL)
            nc = size(data{1},2);

            cla(ax);
            ax.Tag = 'control_chart_axes';

            axis(ax, 'padded');
            box(ax, 'on');

            hold(ax, 'on');
            plot(ax, NaN, NaN(1,nc), Tag="batch_means_signal", ...
                SeriesIndex=1, LineStyle='-', MarkerSize=10, Marker='.');

            h = plot(ax, NaN, NaN(1,nc), Tag='detected_anomalies', ...
                LineStyle='none', MarkerSize=8, Marker='o');
            matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                'Color', '--mw-backgroundColor-primary-error');

            yline(ax, NaN(1,nc), Label='UCL', Tag="UCL", ...
                SeriesIndex=2, LineWidth=1.0, ...
                LabelHorizontalAlignment='left', LabelVerticalAlignment='bottom', ...
                PickableParts='none');

            str = msg("predmaint_anomaly:anomaly:strCenterline");
            l = yline(ax, NaN(1,nc), Label=str, Tag="CL", LineWidth=1.0, ...
                LabelHorizontalAlignment='left', PickableParts='none');
            matlab.graphics.internal.themes.specifyThemePropertyMappings(l, ...
                'Color', '--mw-backgroundColor-primary-success');

            yline(ax, NaN(1,nc), Label='LCL', Tag="LCL", ...
                SeriesIndex=2, LineWidth=1.0, ...
                LabelHorizontalAlignment='left', LabelVerticalAlignment='top', ...
                PickableParts='none');

            if (method == "individual")
                title_str = msg("predmaint_anomaly:anomaly:strIndividualsChartTitle");
            else
                title_str = msg("predmaint_anomaly:anomaly:strEWMAChartTitle");
            end

            title(ax, title_str);
            xlabel(ax, msg("predmaint_anomaly:anomaly:strWindowStartIndex"));
            ylabel(ax, msg("predmaint_anomaly:anomaly:strBatchMeansSignal"));

            legend(ax, Location="southoutside", NumColumns=2);
            hold(ax, 'off');

            updateControlChart(ax, data, names, results, windowLength, CL, LCL, UCL);

            fig = ancestor(ax, 'figure');
            setSelectedChannel(fig, 1);
        end

        function plotScores(ax, results, threshold)
            cla(ax);
            ax.Tag = 'scores';

            axis(ax, 'padded');
            box(ax, 'on');

            hold(ax, 'on');
            stem(ax, NaN, NaN, Tag='anomaly_scores', ...
                SeriesIndex=1, LineStyle='-', MarkerSize=10, Marker='.');

            h = plot(ax, NaN, NaN, LineStyle='none', MarkerSize=8, Marker='o', Tag="detected_anomalies");
            matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
                'Color', '--mw-backgroundColor-primary-error');

            l = yline(ax, NaN, Tag='anomaly_threshold', LineStyle='--', LineWidth=1.5, ...
                LabelHorizontalAlignment='left', LabelVerticalAlignment='top', ...
                PickableParts='none');
            l.Annotation.LegendInformation.IconDisplayStyle = 'off';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(l, ...
                'Color', '--mw-backgroundColor-primary-error');

            title(ax, msg("predmaint_anomaly:anomaly:strAnomalyScores"));
            xlabel(ax, msg("predmaint_anomaly:anomaly:strWindowStartIndex"));
            ylabel(ax, msg("predmaint_anomaly:anomaly:strScore"));

            legend(ax, Location="southoutside", NumColumns=2);
            hold(ax, 'off');

            anomalyCLI.internal.utils.AnomalyDetection.updateScores(ax, results, threshold);
        end

        function updateScores(ax, results, threshold)
            I = results.Labels;
            scores = results.AnomalyScores;
            indices = results.StartIndices;

            % Scores.
            h = findobj(ax, 'Tag', 'anomaly_scores');
            str = msg("predmaint_anomaly:anomaly:strAnomalyScores");
            set(h, XData=indices, YData=scores, DisplayName=str);

            % Detected anomalies.
            h = findobj(ax, 'Tag', 'detected_anomalies');
            str = msg("predmaint_anomaly:anomaly:strDetectedAnomalies");
            set(h, XData=indices(I), YData=scores(I), DisplayName=str);

            % Anomaly threshold.
            h = findobj(ax, 'Tag', 'anomaly_threshold');
            str = sprintf('%s = %.4g', msg('predmaint_anomaly:anomaly:strThreshold'), threshold);
            set(h, Value=threshold, Label=str);
        end

        function plotHistogram(ax, scores, threshold)
            cla(ax);
            ax.Tag = 'histogram_axes';

            axis(ax, 'padded');
            box(ax, 'on');
            grid(ax, 'on');

            hold(ax, 'on');
            ns = numel(scores);
            for i = 1:ns
                histogram(ax, NaN, Normalization='probability', Tag="scores_histogram");
            end
            ax.NextPlot = 'replaceall'; % Called after histogram since histogram overwrites it.

            l = xline(ax, NaN, Tag='anomaly_threshold', LineStyle='--', LineWidth=1.5, ...
                LabelHorizontalAlignment='left', PickableParts='none');
            l.Annotation.LegendInformation.IconDisplayStyle = 'off';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(l, ...
                'Color', '--mw-backgroundColor-primary-error');

            title(ax, msg("predmaint_anomaly:anomaly:strPLDTitle"));
            xlabel(ax, msg("predmaint_anomaly:anomaly:strAnomalyScores"));
            ylabel(ax, msg("predmaint_anomaly:anomaly:strPLDYLabel1"));

            legend(ax, Location="southoutside", NumColumns=2);
            hold(ax, 'off');

            updateHistogram(ax, scores, threshold);
        end
    end
end


%% Helper functions
function s = msg(id,varargin)
    % Read string with the given ID from a resource bundle.
    s = string(message(id, varargin{:}));
end

function updateControlChart(ax, data, names, results, windowLength, CL, LCL, UCL)
    [~,nc] = size(data{1});

    labels = results.Labels; % Logical
    indices = results.StartIndices;
    rules = results.ActiveRules;

    % Batch-means series data.
    h = findobj(ax, 'Tag', 'batch_means_signal');
    assert(numel(h) == nc);
    for i = 1:nc
        str = sprintf('%s (%s)', msg("predmaint_anomaly:anomaly:strBatchMeansSignal"), names{i});
        set(h(i), XData=indices, YData=data{1}(:,i), DisplayName=str);
    end

    % Anomaly markers.
    h = findobj(ax, 'Tag', 'detected_anomalies');
    assert(numel(h) == nc);
    for i = 1:nc
        str = sprintf("%s (across all channels)", msg("predmaint_anomaly:anomaly:strDetectedAnomalies"));
        set(h(i), XData=indices(labels), YData=data{1}(labels,i), DisplayName=str); % Reverse stacking order.

        % Datatips indicating detected anomalies.
        h(i).DataTipTemplate.DataTipRows = [ ...
            dataTipTextRow("Anomalies", @(x)join(rules{1+round((x-1)/windowLength)},', ')), ...
            dataTipTextRow('X', 'XData'), ...
            dataTipTextRow('Y', 'YData')];
    end

    % Control chart levels.
    h = findobj(ax, 'Tag', 'UCL');
    assert(numel(h) == nc);
    for i = 1:nc
        set(h(i), Value=UCL(i), DisplayName='UCL'); % Reverse stacking order.
    end

    h = findobj(ax, 'Tag', 'CL');
    assert(numel(h) == nc);
    for i = 1:nc
        set(h(i), Value=CL(i), DisplayName='CL'); % Reverse stacking order.
    end

    h = findobj(ax, 'Tag', 'LCL');
    assert(numel(h) == nc);
    for i = 1:nc
        set(h(i), Value=LCL(i), DisplayName='LCL'); % Reverse stacking order.
    end
end

function updateHistogram(ax, scores, threshold)
    ns = numel(scores);

    h = findobj(ax, 'Tag', 'scores_histogram');
    assert(numel(h) == ns);
    binWidth = -Inf;
    binLimits = [Inf, -Inf];
    for i = 1:ns
        k = ns-i+1; % Reverse stacking order.
        str = sprintf("%s %d", msg('predmaint_anomaly:anomaly:strAnomalyScores'), k);
        set(h(i), Data=scores{k}, DisplayName=str);

        binWidth = max(binWidth, h(i).BinWidth);
        binLimits = [min(binLimits(1),h(i).BinLimits(1)), max(binLimits(2),h(i).BinLimits(2))];
    end
    set(h, 'BinWidth', binWidth);
    set(h, 'BinLimits', binLimits); % BinWidth affects original BinLimits.

    % Anomaly threshold.
    h = findobj(ax, 'Tag', 'anomaly_threshold');
    str = sprintf('%s = %.4g', msg('predmaint_anomaly:anomaly:strThreshold'), threshold);
    set(h, Value=threshold, Label=str);
end

function YLimitsFcn(ax, ed)
    targetAxes = ancestor(ax, 'axes');
    h = findobj(targetAxes, 'Tag', 'labeled_anomalies');
    if ~isempty(h) && ~isempty(h.Vertices) && ~isnan(h.Vertices(1,1))
        % If the patch for labeled anomalies exists and has vertices, then
        % update the y limits of the patch to cover the full axes range
        nC = width(h.YData);
        Y0 = ed.NewLimits(1);
        Y1 = ed.NewLimits(2);
        YData = [repmat(Y0,1,nC); repmat(Y1,1,nC); repmat(Y1,1,nC); repmat(Y0,1,nC)];
        h.YData = YData;
    end
end

function HoverFcn(fig, ed)
    hoverObj = ed.HitObject;
    hoverAxes = ancestor(hoverObj, 'axes');

    % Return if the axis is already in an interactive mode.
    axesInMode = matlab.graphics.interaction.internal.containsAxesInMode(hoverAxes);
    if axesInMode
        return;
    end

    % Signal highlighting.
    targetAxes = findobj(fig, 'Type', 'axes', ...
        {'Tag', 'signal_anomalies_axes', '-or', 'Tag', 'zoom_anomalies_axes'});
    hiliteTargets = findobj(targetAxes, 'Type', 'line', ...
        {'Tag', 'raw_signal', '-or', 'Tag', 'detected_anomalies', '-or', 'Tag', 'zoom_data', '-or', 'Tag', 'zoom_detected_anomalies'});
    if ~isempty(hiliteTargets) && any(hoverObj == hiliteTargets)
        h = findobj(targetAxes, 'Tag', hoverObj.Tag); % All objects with same tag as hover object.
        idx = find(h == hoverObj);
        setSelectedChannel(fig, idx);
    end

    % Draggable objects (for TSAD app only).
    targetAxes = findobj(fig, 'Type', 'axes', {'Tag', 'signal_anomalies_axes'});
    dragTargets = findobj(targetAxes, {'Tag', 'zoom_location'});
    if ~isempty(dragTargets) && any(hoverObj == dragTargets)
        if isempty(fig.UserData.LastPointer)
            fig.UserData.LastPointer = fig.Pointer;
        end
        fig.Pointer = 'left';
    else
        if ~isempty(fig.UserData.LastPointer)
            fig.Pointer = fig.UserData.LastPointer;
            fig.UserData.LastPointer = [];
        end
    end

end

function setSelectedChannel(fig, idx)
    % Time series and anomaly data.
    ax = findobj(fig, 'Type', 'axes', {'Tag', 'signal_anomalies_axes'});
    tags = {'raw_signal', 'detected_anomalies'};
    primaryColorPerTag = {'--mw-graphics-colorOrder-1-primary', '--mw-graphics-colorOrder-2-primary'};
    secondaryColorPerTag = {'--mw-graphics-colorOrder-1-secondary', '--mw-graphics-colorOrder-2-secondary'};

    for i = 1:numel(tags)
        h = findobj(ax, 'Tag', tags{i});
        if isempty(h)
            continue;
        end

        set(h, 'LineWidth', 0.5);
        matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
            'Color', secondaryColorPerTag{i});
        set(h(idx), 'LineWidth', 1.5);
        matlab.graphics.internal.themes.specifyThemePropertyMappings(h(idx), ...
            'Color', primaryColorPerTag{i});

        for j = 1:numel(h)
            if j == idx
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'on';
            else
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'off';
            end
        end
    end

    % Batch-means data (for SPC detector only).
    ax = findobj(fig, 'Type', 'axes', 'Tag', 'control_chart_axes');
    tags = {'batch_means_signal', 'detected_anomalies', 'UCL', 'CL', 'LCL'};

    for i = 1:numel(tags)
        h = findobj(ax, 'Tag', tags{i});
        if isempty(h)
            continue;
        end

        set(h, 'Visible', false);
        set(h(idx), 'Visible', true);

        for j = 1:numel(h)
            if (j == idx) && ~any(tags{i} == ["UCL", "CL", "LCL"])
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'on';
            else
                % No legends for control lines either.
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'off';
            end
        end
    end

    % Zoom view of time series anomaly data (for TSAD app only).
    ax = findobj(fig, 'Type', 'axes', {'Tag', 'zoom_anomalies_axes'});
    tags = {'zoom_data', 'zoom_detected_anomalies'};
    primaryColorPerTag = {'--mw-graphics-colorOrder-1-primary', '--mw-graphics-colorOrder-2-primary'};
    secondaryColorPerTag = {'--mw-graphics-colorOrder-1-secondary', '--mw-graphics-colorOrder-2-secondary'};

    for i = 1:numel(tags)
        h = findobj(ax, 'Tag', tags{i});
        if isempty(h)
            continue;
        end

        set(h, 'LineWidth', 0.5);
        matlab.graphics.internal.themes.specifyThemePropertyMappings(h, ...
            'Color', secondaryColorPerTag{i});
        set(h(idx), 'LineWidth', 1.5);
        matlab.graphics.internal.themes.specifyThemePropertyMappings(h(idx), ...
            'Color', primaryColorPerTag{i});

        for j = 1:numel(h)
            if j == idx
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'on';
            else
                h(j).Annotation.LegendInformation.IconDisplayStyle = 'off';
            end
        end
    end
end
