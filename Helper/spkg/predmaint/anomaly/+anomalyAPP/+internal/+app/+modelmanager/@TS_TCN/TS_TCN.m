classdef TS_TCN
    %Static utility class for Temporal Convolutional Network (TCN) model
    %related functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

    %   Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strTCN')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipTCN')
        Type (1,1) string = "tcn"
        IconName (1,1) string = "convolution1d"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descTcn');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedTcn');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationTcn');

        % Defaults aligned with control IDs
        defaultModelConfig (1,1) struct = struct(...
            'MaxEpochsSpinner',     100, ...
            'LearnRateSpinner',     0.001, ...
            'BatchSizeSpinner',     256, ...
            'ExecEnvDropdown',      'auto', ...
            'NormalizeDropdown',    'zscore', ...
            'FilterSizeSpinner',    7, ...
            'NumFiltersSpinner',    32, ...
            'DropoutSpinner',       0.25,...
            'SolverDropdown', 'adam')

        defaultDetectConfig (1,1) struct = struct(...
            'DetectWindowLengthSpinner', 10, ...
            'DetectionStrideSpinner', 10, ...
            'ThresholdMethodDropdown', 'kSigma', ...
            'ThresholdParamSpinner',  3, ...
            'ThresholdSpinner', 1, ...
            'BatchSizeSpinner', 256,...
            'ExecEnvDropdown', 'auto')

        %Detector Type
        DetectorType (1,1) string = "DeepLearning"
    end

    methods (Static)
        function createTrainOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_TCN

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % --- Training Options ---
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 4, Tag="TrainOptsGrid");

            % Max Epochs
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strMaxEpochs'), 1, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMaxEpochs'));
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            maxEpochsSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_TCN.defaultModelConfig.MaxEpochsSpinner, step, row, roundFractional);
            maxEpochsSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'MaxEpochsSpinner');

            % Learning Rate
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strInLR'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipInitialLearnRate'));
            limits = [0 inf];
            step = 0.001;
            row = 2;
            roundFractional = false;
            learnRateSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_TCN.defaultModelConfig.LearnRateSpinner, step, row, roundFractional);
            learnRateSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LearnRateSpinner');

            % Batch Size
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMiniBatchSize'));
            limits = [0.9 inf];
            step = 10;
            row = 3;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_TCN.defaultModelConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'BatchSizeSpinner');

            % Execution Environment
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strExecEnv'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipExecutionEnvironment'));
            execEnvDropdown = UiWidgetFactory.createDropdown(trainingGrid, [...
                m('predmaint_anomaly:anomaly_app:strAuto'), ...
                m('predmaint_anomaly:anomaly_app:strCpu'), ...
                m('predmaint_anomaly:anomaly_app:strGpu'), ...
                m('predmaint_anomaly:anomaly_app:strMultigpu')], ...
                {'auto', 'cpu', 'gpu', 'multi-gpu'}, ...
                TS_TCN.defaultModelConfig.ExecEnvDropdown, 4, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'ExecEnvDropdown');

            % Solver Name
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strSolverName'), 5,...
                m('predmaint_anomaly:anomaly_app:configTooltipSolverName'));
            solverDropdown = UiWidgetFactory.createDropdown(trainingGrid, [...
                m('predmaint_anomaly:anomaly_app:strSolverSgdm'), ...
                m('predmaint_anomaly:anomaly_app:strSolverAdam'), ...
                m('predmaint_anomaly:anomaly_app:strSolverRmsprop'), ...
                m('predmaint_anomaly:anomaly_app:strSolverLbfgs'), ...
                m('predmaint_anomaly:anomaly_app:strSolverLm')], ...
                {'sgdm','adam','rmsprop','lbfgs','lm'}, ...
                TS_TCN.defaultModelConfig.SolverDropdown, 5, false);
            solverDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'SolverDropdown');


            % --- Model Options ---
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptionsTitle'), 2, 4, Tag="ModelOptsGrid");

            % Add components to the "Model options" panel

            % Normalization
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid, [m('predmaint_anomaly:anomaly_app:strZscore'), ...
                m('predmaint_anomaly:anomaly_app:strRange'), m('predmaint_anomaly:anomaly_app:strOff')], {'zscore','range','off'}, ...
                TS_TCN.defaultModelConfig.NormalizeDropdown, 1, false);
            normalizeDropdown.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');

            % Create the accordion for "Advanced options"
            advancedGrid = UiWidgetFactory.createAccordion(modelGrid, m('predmaint_anomaly:anomaly_app:strAdvancedOptions'), 2, 3);

            % Filter Size
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strFilterSize'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipFilterSize'));
            limits = [0.9 inf];
            step = 1;
            row = 2;
            roundFractional = true;
            filterSizeSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_TCN.defaultModelConfig.FilterSizeSpinner, step, row, roundFractional);
            filterSizeSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'FilterSizeSpinner');

            % Num Filters
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumFilters'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfFilters'));
            limits = [0.9 inf];
            step = 1;
            row = 3;
            roundFractional = true;
            numFiltersSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_TCN.defaultModelConfig.NumFiltersSpinner, step, row, roundFractional);
            numFiltersSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumFiltersSpinner');

            % Dropout
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strDropProb'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipDropoutProbability'));
            limits = [0 1];
            step = 0.1;
            row = 4;
            roundFractional = false;
            upperLimitInclusive = true;
            lowerLimitInclusive = true;
            dropoutSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_TCN.defaultModelConfig.DropoutSpinner, step, row, ...
                roundFractional, upperLimitInclusive, lowerLimitInclusive);
            dropoutSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'DropoutSpinner');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            %Persist
            wd.Model.MaxEpochsSpinner = maxEpochsSpinner;
            wd.Model.LearnRateSpinner = learnRateSpinner;
            wd.Model.BatchSizeSpinner = batchSizeSpinner;
            wd.Model.ExecEnvDropdown = execEnvDropdown;
            wd.Model.SolverDropdown  = solverDropdown;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.FilterSizeSpinner = filterSizeSpinner;
            wd.Model.NumFiltersSpinner = numFiltersSpinner;
            wd.Model.DropoutSpinner = dropoutSpinner;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_TCN

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 6, Tag="DetectOptsGrid");

            % Detection Window Length
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strDetectWL'), 1);
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            detectWindowLengthSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_TCN.defaultDetectConfig.DetectWindowLengthSpinner, step, row, roundFractional);
            detectWindowLengthSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectWindowLengthSpinner');

            % Detection Stride
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strDetectionStride'), 2);
            limits = [0.9 inf];
            step = 1;
            row = 2;
            roundFractional = true;
            detectionStrideSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_TCN.defaultDetectConfig.DetectionStrideSpinner, step, row, roundFractional);
            detectionStrideSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionStrideSpinner');

            % Threshold Method
            UiWidgetFactory.createLabel(detectionGrid,  m('predmaint_anomaly:anomaly_app:strThresMethod'), 3);
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strMean'), ...
                m('predmaint_anomaly:anomaly_app:strMedian'), ...
                m('predmaint_anomaly:anomaly_app:strMax'), ...
                m('predmaint_anomaly:anomaly_app:strContamFrac'), ...
                m('predmaint_anomaly:anomaly_app:strManual'), ...
                m('predmaint_anomaly:anomaly_app:strKSigma') ...
                ], ...
                {'mean','median','max','contamfrac', 'manual','kSigma'}, ...
                TS_TCN.defaultDetectConfig.ThresholdMethodDropdown, 3, false);
            thresholdMethodDropdown.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdMethodDropdown');

            % Threshold Parameter
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strThresParam'), 4);
            limits = [-inf inf];
            step = 0.5;
            row = 4;
            roundFractional = false;
            thresholdParamSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_TCN.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
            thresholdParamSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdParamSpinner');
            thresholdParamSpinner.Tag = "ThresholdParamSpinner";

            % Threshold
            UiWidgetFactory.createLabel(detectionGrid,  m('predmaint_anomaly:anomaly_app:strThreshold'), 5);
            limits = [-inf inf];
            step = 0.5;
            row = 5;
            roundFractional = false;
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_TCN.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
            thresholdSpinner.ValueChangedFcn = @(~,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdSpinner');
            thresholdSpinner.Enable = "off";
            thresholdSpinner.Tag = "ThresholdSpinner";
            % Disable at creation since ThresholdMethod is kSigma by
            % default
            thresholdSpinner.Enable = "off";
            thresholdSpinner.Tag = "ThresholdSpinner";

            % Batch Size
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 6);
            limits = [0.9 inf];
            step = 10;
            row = 6;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_TCN.defaultDetectConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'BatchSizeSpinner');

            % Execution Environment
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strExecEnv'), 7);
            execEnvDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strAuto'), ...
                m('predmaint_anomaly:anomaly_app:strCpu'), ...
                m('predmaint_anomaly:anomaly_app:strGpu')], ...
                {'auto','cpu','gpu'}, ...
                TS_TCN.defaultDetectConfig.ExecEnvDropdown, 7, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ExecEnvDropdown');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), false);

            %Persist
            wd.Model.DetectWindowLengthSpinner = detectWindowLengthSpinner;
            wd.Model.DetectionStrideSpinner = detectionStrideSpinner;
            wd.Model.ThresholdMethodDropdown = thresholdMethodDropdown;
            wd.Model.ThresholdParamSpinner = thresholdParamSpinner;
            wd.Model.ThresholdSpinner = thresholdSpinner;
            wd.Model.BatchSizeSpinner = batchSizeSpinner;
            wd.Model.ExecEnvDropdown = execEnvDropdown;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function [mdl, monitor] = trainModel(data, cc, host)
            arguments
                data
                cc
                host matlab.ui.container.GridLayout = []
            end

            import anomalyAPP.internal.app.modelmanager.utils.*

            if ~isempty(host)
                monitor = MonitorFactory(host);
            else
                monitor = MonitorFactory();
            end

            %For reproducibility
            old = rng;             % save current state (type, seed, substream, etc.)
            restoreRng = onCleanup(@() trainingCleanup(old, monitor));  % restore to previous state
            rng('default');        % set the deterministic default stream

            mdl = tcnAD(size(data{1},2), ...
                "FilterSize", cc.FilterSizeSpinner, ...
                "NumFilters", cc.NumFiltersSpinner,...
                "Normalization", cc.NormalizeDropdown, ...
                "DropoutProbability", cc.DropoutSpinner);

            trainOpts = trainingOptions(cc.SolverDropdown, ...
                "ExecutionEnvironment", cc.ExecEnvDropdown, ...
                "Verbose", false, ...
                "MaxEpochs", cc.MaxEpochsSpinner,...
                "MiniBatchSize", cc.BatchSizeSpinner, ...
                "InitialLearnRate", cc.LearnRateSpinner);

            mdl = train(mdl, data, TrainingOpts=trainOpts, Monitor=monitor.Monitor);
        end

        function [tbl, model] = detect(model, trainData, testData, config, needsConfigUpdate)

            % When called from detect tab, needConfigUpdate is set to true
            % only if tip and LKG are different. config is Tip always in
            % this case.
            % When called from train tab validation metrics,
            % needConfigUpdate is always set to true. config is LKG always
            % in this case.
            if needsConfigUpdate
                if config.ThresholdMethodDropdown ==  "manual"
                    model.Model = updateDetector(model.Model, ...
                        "ThresholdMethod",          'manual', ...
                        "Threshold",                config.ThresholdSpinner, ...
                        "DetectionWindowLength",    config.DetectWindowLengthSpinner, ...
                        "DetectionStride",          config.DetectionStrideSpinner,...
                        "MiniBatchSize", config.BatchSizeSpinner,...
                        "ExecutionEnvironment", config.ExecEnvDropdown);
                else
                    model.Model = updateDetector(model.Model, trainData, ...
                        "ThresholdMethod",          config.ThresholdMethodDropdown, ...
                        "ThresholdParameter",       config.ThresholdParamSpinner, ...
                        "DetectionWindowLength",    config.DetectWindowLengthSpinner, ...
                        "DetectionStride",          config.DetectionStrideSpinner,...
                        "MiniBatchSize", config.BatchSizeSpinner,...
                        "ExecutionEnvironment", config.ExecEnvDropdown);
                end
            end
            
            tbl = detect(model.Model, testData,...
                "MiniBatchSize", config.BatchSizeSpinner,...
                "ExecutionEnvironment", config.ExecEnvDropdown);

            % Downstream functionality assumes that detectionResults are
            % always formatted for member level access
            if ~iscell(tbl)
                tbl = {tbl};
            end

            model = model.Handler.updateTipDetectConfig(model);
        end

        function model = updateTipDetectConfig(model)
            if model.TipDetectConfig.ThresholdMethodDropdown ~= "manual"
                % Update the threshold value in both the current config and
                % the LKG config since the model's value changed
                model.TipDetectConfig.ThresholdSpinner = model.Model.Threshold;
                model.LKGDetectConfig.ThresholdSpinner = model.Model.Threshold;
            end
        end

        function [windowLength, detectionStride, obsWinLen] = getCommonWindowDefinitions(model)


            windowLength = model.DetectionWindowLength;
            obsWinLen = 0;
            detectionStride = model.DetectionStride;
        end

        function fillOverviewDiagram(OverviewPanel, modelOverview)
            
            Dlnet = modelOverview{1};

            % Create an axes and plot the network
            OverviewAxes = uiaxes(OverviewPanel, 'Visible', 'off', ...
                'Units', 'normalized', 'Position', [0 0 1 1],...
                'HitTest', 'off', 'PickableParts', 'none', ...
                'Toolbar', []);

            plot(Dlnet, 'Parent', OverviewAxes);
        end

    end

end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));

end
