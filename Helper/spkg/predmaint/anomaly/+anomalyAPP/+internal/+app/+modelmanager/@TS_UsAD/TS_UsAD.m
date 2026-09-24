classdef TS_UsAD
    %Static utility class for Unsupervised Anomaly Detection (UsAD) model
    %related functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

%   Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strUsAD')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipUsAD')
        Type (1,1) string = "usad"
        IconName (1,1) string = "fullyConnected"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descUsad');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedUsad');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationUsad');

        % Defaults aligned with control IDs (kept as in your original class)
        defaultModelConfig (1,1) struct = struct(...
            'ObservationWindowLengthSpinner', 24, ...
            'TrainingStrideSpinner', 24, ...
            'MaxEpochsSpinner', 30, ...
            'LearnRateSpinner', 0.001, ...
            'BatchSizeSpinner', 256, ...
            'ExecEnvDropdown', 'auto', ...
            'NormalizeDropdown','zscore', ...
            'LatentSpaceSpinner', 32)

        defaultDetectConfig (1,1) struct = struct(...
            'AlphaSpinner', 0.5, ...
            'BetaSpinner', 0.5, ...
            'DetectionStrideSpinner', 10, ...
            'ThresholdMethodDropdown', 'kSigma', ...
            'ThresholdParamSpinner', 3, ...
            'ThresholdSpinner', 1, ...
            'BatchSizeSpinner', 256,...
            'ExecEnvDropdown', 'auto')

        %Detector Type
        DetectorType (1,1) string = "DeepLearning"
    end

    methods (Static)
        function createTrainOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_UsAD

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
                TS_UsAD.defaultModelConfig.MaxEpochsSpinner, step, row, roundFractional);
            maxEpochsSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'MaxEpochsSpinner');

            % Initial Learn Rate
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strInLR'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipInitialLearnRate'));
            limits = [0 inf];
            step = 0.001;
            row = 2;
            roundFractional = false;
            learnRateSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_UsAD.defaultModelConfig.LearnRateSpinner, step, row, roundFractional);
            learnRateSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LearnRateSpinner');

            % batch size
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMiniBatchSize'));
            limits = [0.9 inf];
            step = 10;
            row = 3;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_UsAD.defaultModelConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'BatchSizeSpinner');

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
                TS_UsAD.defaultModelConfig.ExecEnvDropdown, 4, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'ExecEnvDropdown');

            % --- Model Options ---
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptionsTitle'), 2, 4, Tag="ModelOptsGrid");

            % Normalization
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strZscore'), m('predmaint_anomaly:anomaly_app:strRange'), m('predmaint_anomaly:anomaly_app:strOff')], ...
                {'zscore','range','off'}, ...
                TS_UsAD.defaultModelConfig.NormalizeDropdown, 1, false);
            normalizeDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');

            % Observation Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strObservWL'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipObservationWindowLength'));
            limits = [1 inf];
            step = 10;
            row = 2;
            roundFractional = true;
            observationWindowLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, ...
                limits, ...
                TS_UsAD.defaultModelConfig.ObservationWindowLengthSpinner, ...
                step, row, roundFractional);
            observationWindowLengthSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'ObservationWindowLengthSpinner');

            % Training Stride
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strTrainingStride'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipTrainingStride'));
            limits = [1 inf];
            step = 10;
            row = 3;
            roundFractional = true;
            trainingStrideSpinner = UiWidgetFactory.createSpinner(modelGrid, ...
                limits, TS_UsAD.defaultModelConfig.TrainingStrideSpinner ...
                , step, row, roundFractional);
            trainingStrideSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'TrainingStrideSpinner');

            % Advanced Options (Accordion)
            advancedGrid = UiWidgetFactory.createAccordion(modelGrid, m('predmaint_anomaly:anomaly_app:strAdvancedOptions'), 4, 1);

            % Latent space dimension
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strLatentSpace'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipLatentSpaceSize'));
            limits = [20 100];
            step = 1;
            row = 1;
            roundFractional = true;
            latentSpaceSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_UsAD.defaultModelConfig.LatentSpaceSpinner, step, row, roundFractional);
            latentSpaceSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LatentSpaceSpinner');

            % Revert (Train) button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            % Persist handles
            wd.Model.MaxEpochsSpinner = maxEpochsSpinner;
            wd.Model.LearnRateSpinner = learnRateSpinner;
            wd.Model.BatchSizeSpinner = batchSizeSpinner;
            wd.Model.ExecEnvDropdown = execEnvDropdown;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.ObservationWindowLengthSpinner = observationWindowLengthSpinner;
            wd.Model.TrainingStrideSpinner          = trainingStrideSpinner;
            wd.Model.LatentSpaceSpinner = latentSpaceSpinner;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_UsAD

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % --- Detection Options ---
            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 6, Tag="DetectOptsGrid");

            % Detection Stride (editable dropdown)
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strDetectionStride'), 1);
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            detectionStrideSpinner = UiWidgetFactory.createSpinner(detectionGrid, ...
                limits, TS_UsAD.defaultDetectConfig.DetectionStrideSpinner, ...
                step, row, roundFractional);
            detectionStrideSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionStrideSpinner');

            % Alpha
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strAlpha'), 2);
            limits =[0 1];
            step = 0.05;
            row = 2;
            roundFractional = false;
            alphaSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_UsAD.defaultDetectConfig.AlphaSpinner, step, row, roundFractional);
            alphaSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'AlphaSpinner');
            alphaSpinner.Tag = "AlphaSpinner";

            % Beta
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strBeta'), 3);
            limits =[0 1];
            step = 0.05;
            row = 3;
            roundFractional = false;
            betaSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_UsAD.defaultDetectConfig.BetaSpinner, step, row, roundFractional);
            betaSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'BetaSpinner');
            betaSpinner.Tag = "BetaSpinner";

            % Threshold Method
            UiWidgetFactory.createLabel(detectionGrid,  m('predmaint_anomaly:anomaly_app:strThresMethod'), 4);
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strMean'), ...
                m('predmaint_anomaly:anomaly_app:strMedian'), ...
                m('predmaint_anomaly:anomaly_app:strMax'), ...
                m('predmaint_anomaly:anomaly_app:strContamFrac'), ...
                m('predmaint_anomaly:anomaly_app:strManual'), ...
                m('predmaint_anomaly:anomaly_app:strKSigma') ...
                ], ...
                {'mean','median','max', 'contaminationFraction', 'manual','kSigma'}, ...
                TS_UsAD.defaultDetectConfig.ThresholdMethodDropdown, 4, false);
            thresholdMethodDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdMethodDropdown');

            % Threshold Parameter
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strThresParam'), 5);
            limits = [-inf inf];
            step = 0.5;
            row = 5;
            roundFractional = false;
            thresholdParamSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_UsAD.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
            thresholdParamSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdParamSpinner');
            thresholdParamSpinner.Tag = "ThresholdParamSpinner";

            % Threshold  — disabled unless manual/customFunction
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strThreshold'), 6);
            limits = [-inf inf];
            step = 0.5;
            row = 6;
            roundFractional = false;
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_UsAD.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
            thresholdSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdSpinner');
            % Disable at creation since ThresholdMethod is kSigma by
            % default
            thresholdSpinner.Enable = "off";
            thresholdSpinner.Tag = "ThresholdSpinner";

            % Batch Size
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 7);
            limits = [0.9 inf];
            step = 10;
            row = 7;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_UsAD.defaultDetectConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'BatchSizeSpinner');

            % Execution Environment
            UiWidgetFactory.createLabel(detectionGrid, m('predmaint_anomaly:anomaly_app:strExecEnv'), 8);
            execEnvDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strAuto'), ...
                m('predmaint_anomaly:anomaly_app:strCpu'), ...
                m('predmaint_anomaly:anomaly_app:strGpu')], ...
                {'auto','cpu','gpu'}, ...
                TS_UsAD.defaultDetectConfig.ExecEnvDropdown, 8, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ExecEnvDropdown');

            % Revert (Detect) button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), false);

            %Persist
            wd.Model.DetectionStrideSpinner = detectionStrideSpinner;
            wd.Model.AlphaSpinner = alphaSpinner;
            wd.Model.BetaSpinner = betaSpinner;
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
            
            % Train UsAD using current training config (cc)
            mdl = usAD(size(data{1},2), ...
                "ObservationWindowLength", cc.ObservationWindowLengthSpinner, ...
                "TrainingStride", cc.TrainingStrideSpinner, ...
                "LatentSpaceDim", cc.LatentSpaceSpinner, ...
                "Normalization", cc.NormalizeDropdown);

            mdl = train(mdl, data, ...
                "ExecutionEnvironment", cc.ExecEnvDropdown, ...
                "Verbose", false, ...
                "MaxEpochs", cc.MaxEpochsSpinner, ...
                "MiniBatchSize", cc.BatchSizeSpinner, ...
                "InitialLearnRate", cc.LearnRateSpinner, ...
                "Plots", "training-progress",...
                "Monitor", monitor.Monitor);
        end

        function [tbl, model] = detect(model, trainData, testData, config, needsConfigUpdate)
            % Detect with UsAD using detection config (cc)

            % When called from detect tab, needConfigUpdate is set to true
            % only if tip and LKG are different. config is Tip always in
            % this case.
            % When called from train tab validation metrics,
            % needConfigUpdate is always set to true. config is LKG always
            % in this case.
            if needsConfigUpdate
                if config.ThresholdMethodDropdown ==  "manual"
                    model.Model = updateDetector(model.Model, ...
                        "ThresholdMethod", 'manual', ...
                        "Threshold", config.ThresholdSpinner, ...
                        "Alpha", config.AlphaSpinner, ...
                        "Beta", config.BetaSpinner, ...
                        "DetectionStride", config.DetectionStrideSpinner,...
                        "MiniBatchSize", config.BatchSizeSpinner,...
                        "ExecutionEnvironment", config.ExecEnvDropdown);
                else
                    model.Model = updateDetector(model.Model, trainData, ...
                        "ThresholdMethod", config.ThresholdMethodDropdown, ...
                        "ThresholdParameter", config.ThresholdParamSpinner, ...
                        "Alpha", config.AlphaSpinner, ...
                        "Beta", config.BetaSpinner, ...
                        "DetectionStride", config.DetectionStrideSpinner,...
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
            
            tiled = tiledlayout("horizontal", "Parent", OverviewPanel, "TileSpacing", "tight", "Padding", "tight");
            ax = nexttile(tiled, 1);
            ax.HitTest= 'off';
            ax.PickableParts ='none';
            ax.Toolbar = [];
            plot(Dlnet{1}, 'Parent', ax)
            title(ax, 'Encoder');

            ax = nexttile(tiled, 2);
            ax.HitTest= 'off';
            ax.PickableParts ='none';
            ax.Toolbar = [];
            plot(Dlnet{2}, 'Parent', ax);
            title(ax, 'Decoder 1');

            ax = nexttile(tiled, 3);
            ax.HitTest= 'off';
            ax.PickableParts ='none';
            ax.Toolbar = [];
            plot(Dlnet{3}, 'Parent', ax);
            title(ax, 'Decoder 2');
        end
    end
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end
