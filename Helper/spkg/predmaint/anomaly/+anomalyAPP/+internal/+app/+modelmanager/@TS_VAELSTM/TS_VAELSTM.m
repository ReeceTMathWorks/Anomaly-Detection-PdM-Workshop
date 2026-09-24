classdef TS_VAELSTM
    %Static utility class for Variational Auto-Encoder (VAELSTM) model
    %related functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

    %   Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strVAELSTM')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipVAELSTM')
        Type (1,1) string = "vaelstm"
        IconName (1,1) string = "sequenceLSTM"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descVaelstm');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedVaelstm');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationVaelstm');

        defaultModelConfig (1,1) struct = struct(...
            'ObservationWindowLengthSpinner', 100, ...
            'TrainingStrideSpinner', 10, ...
            'DetectWindowLengthSpinner', 10, ...
            'LstmMaxEpochsSpinner', 30, ...
            'LstmLearnRateSpinner', 0.001, ...
            'VaeMaxEpochsSpinner', 10, ...
            'VaeLearnRateSpinner', 0.001, ...
            'BatchSizeSpinner', 256, ...
            'ExecEnvDropdown', 'auto', ...
            'NormalizeDropdown', 'zscore', ...
            'FilterSizeSpinner', 7, ...
            'NumFiltersSpinner', 32, ...
            'DropoutSpinner', 0.3, ...
            'LatentSpaceSpinner', 5, ...
            'NumDownSampleSpinner', 2, ...
            'NumHiddenUnitsSpinner', 16)

        defaultDetectConfig (1,1) struct = struct(...
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
            import anomalyAPP.internal.app.modelmanager.TS_VAELSTM

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % --- Training Options ---
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 6, Tag="TrainOptsGrid");
           
            % VAE Max Epochs
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strVaeMaxEpochs'), 1, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMaxEpochs'));
            limits = [0.9, inf];
            step = 1;
            row = 1;
            roundFractional = true;
            vaeMaxEpochsSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.VaeMaxEpochsSpinner, step, row, roundFractional);
            vaeMaxEpochsSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'VaeMaxEpochsSpinner');

            % LSTM Max Epochs
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strLstmMaxEpochs'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMaxEpochs'));
            limits = [0.9, inf];
            step = 1;
            row = 2;
            roundFractional = true;
            lstmMaxEpochsSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.LstmMaxEpochsSpinner, step, row, roundFractional);
            lstmMaxEpochsSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LstmMaxEpochsSpinner');

            % VAE Learn Rate
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strVaeInLR'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipInitialLearnRate'));
            limits = [0 inf];
            step = 0.001;
            row = 3;
            roundFractional = false;
            vaeLearnRateSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.VaeLearnRateSpinner, step, row, roundFractional);
            vaeLearnRateSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'VaeLearnRateSpinner');

            % LSTM Learn Rate
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strLstmInLR'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipInitialLearnRate'));
            limits = [0 inf];
            step = 0.001;
            row = 4;
            roundFractional = false;
            lstmLearnRateSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.LstmLearnRateSpinner, step, row, roundFractional);
            lstmLearnRateSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LstmLearnRateSpinner');

            % Batch Size
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 5, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMiniBatchSize'));
            limits = [0.9 inf];
            step = 10;
            row = 5;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'BatchSizeSpinner');

            % Execution Environment
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strExecEnv'), 6,...
                m('predmaint_anomaly:anomaly_app:configTooltipExecutionEnvironment'));
            execEnvDropdown = UiWidgetFactory.createDropdown(trainingGrid, ...
                [m('predmaint_anomaly:anomaly_app:strAuto'), ...
                m('predmaint_anomaly:anomaly_app:strCpu'), ...
                m('predmaint_anomaly:anomaly_app:strGpu'), ...
                m('predmaint_anomaly:anomaly_app:strMultigpu')], ...
                {'auto', 'cpu', 'gpu', 'multi-gpu'}, ...
                TS_VAELSTM.defaultModelConfig.ExecEnvDropdown, 6, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'ExecEnvDropdown');

            % Create the "Model options" panel
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptionsTitle'), 2, 5, Tag="ModelOptsGrid");

            % Add components to the "Model options" panel
            % Normalization
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strZscore'), ...
                m('predmaint_anomaly:anomaly_app:strRange'), ...
                m('predmaint_anomaly:anomaly_app:strOff')], ...
                {'zscore','range','off'}, ...
                TS_VAELSTM.defaultModelConfig.NormalizeDropdown, 1, false);
            normalizeDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');
            
            % Observation Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strObsWindLength'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipObservationWindowLength'));
            limits = [1 inf];
            step = 1;
            row = 2;
            roundFractional = true;
            observationWindowLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.ObservationWindowLengthSpinner, step, row, roundFractional);
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
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            trainingStrideSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.TrainingStrideSpinner, step, row, ...
                roundFractional, upperLimitInclusive, lowerLimitInclusive);
            trainingStrideSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'TrainingStrideSpinner');

            % Detection Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strDetectWL'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipDetectionWindowLength'));
            limits = [0.9 inf];
            step = 1;
            row = 4;
            roundFractional = true;
            detectWindowLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.DetectWindowLengthSpinner, step, row, roundFractional);
            detectWindowLengthSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'DetectWindowLengthSpinner');
            
            % Advanced Grid
            advancedGrid = UiWidgetFactory.createAccordion(modelGrid, m('predmaint_anomaly:anomaly_app:strAdvancedOptions'), 5, 6);

            % Filter Size
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strFilterSize'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipFilterSize'));
            limits = [0.9, inf];
            step = 1;
            row = 1;
            roundFractional = true;
            filterSizeSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.FilterSizeSpinner, step, row, roundFractional);
            filterSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'FilterSizeSpinner');

            % Num Filters
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumFilters'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfFilters'));
            limits = [0.9, inf];
            step = 1;
            row = 2;
            roundFractional = true;
            NumFiltersSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.NumFiltersSpinner, step, row, roundFractional);
            NumFiltersSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumFiltersSpinner');

            % Drop out
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strDropProb'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipDropoutProbability'));
            limits = [0, 1];
            step = 0.1;
            row = 3;
            roundFractional = false;
            upperLimitInclusive = true;
            lowerLimitInclusive = true;
            dropoutSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.DropoutSpinner, step, row, ...
                roundFractional, upperLimitInclusive, lowerLimitInclusive);
            dropoutSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'DropoutSpinner');

            % Latent Space
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strLatentSpace'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipLatentSpaceSize'));
            limits = [1, 100];
            step = 1;
            row = 4;
            roundFractional = true;
            latentSpaceSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.LatentSpaceSpinner, step, row, roundFractional);
            latentSpaceSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LatentSpaceSpinner');

            % Num Downsample
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumDownSample'), 5,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfDownsampleLayers'));
            limits = [0.9, 10000];
            step = 1;
            row = 5;
            roundFractional = true;
            numDownSampleSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.NumDownSampleSpinner, step, row, roundFractional);
            numDownSampleSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumDownSampleSpinner');

            % Num Hidden Units
            UiWidgetFactory.createLabel(advancedGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumHU'), 6,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfHiddenUnits'));
            limits = [8, 1e4];
            step = 2;
            row = 6;
            roundFractional = true;
            numHiddenUnitsSpinner = UiWidgetFactory.createSpinner(advancedGrid, limits, ...
                TS_VAELSTM.defaultModelConfig.NumHiddenUnitsSpinner, step, row, roundFractional);
            numHiddenUnitsSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumHiddenUnitsSpinner');

            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            wd.Model.ObservationWindowLengthSpinner = observationWindowLengthSpinner;
            wd.Model.TrainingStrideSpinner = trainingStrideSpinner;
            wd.Model.DetectWindowLengthSpinner = detectWindowLengthSpinner;
            wd.Model.LstmMaxEpochsSpinner = lstmMaxEpochsSpinner;
            wd.Model.VaeMaxEpochsSpinner = vaeMaxEpochsSpinner;
            wd.Model.LstmLearnRateSpinner = lstmLearnRateSpinner;
            wd.Model.VaeLearnRateSpinner = vaeLearnRateSpinner;
            wd.Model.BatchSizeSpinner = batchSizeSpinner;
            wd.Model.ExecEnvDropdown = execEnvDropdown;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.FilterSizeSpinner = filterSizeSpinner;
            wd.Model.NumFiltersSpinner = NumFiltersSpinner;
            wd.Model.DropoutSpinner = dropoutSpinner;
            wd.Model.LatentSpaceSpinner = latentSpaceSpinner;
            wd.Model.NumDownSampleSpinner = numDownSampleSpinner;
            wd.Model.NumHiddenUnitsSpinner = numHiddenUnitsSpinner;

            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_VAELSTM

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 6, Tag="DetectOptsGrid");

            % Detection Stride
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strDetectionStride'), 1, ...
                m('predmaint_anomaly:anomaly_app:configTooltipDetectionStride'));
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            detectionStrideSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_VAELSTM.defaultDetectConfig.DetectionStrideSpinner, step, row, roundFractional);
            detectionStrideSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionStrideSpinner');


            % Threshold Method
            UiWidgetFactory.createLabel(detectionGrid,  ...
                m('predmaint_anomaly:anomaly_app:strThresMethod'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThresholdMethod'));
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strMean'), ...
                m('predmaint_anomaly:anomaly_app:strMedian'), ...
                m('predmaint_anomaly:anomaly_app:strMax'), ...
                m('predmaint_anomaly:anomaly_app:strContamFrac'), ...
                m('predmaint_anomaly:anomaly_app:strManual'), ...
                m('predmaint_anomaly:anomaly_app:strKSigma') ...
                ], ...
                {'mean','median','max','contaminationFraction', 'manual','kSigma'}, ...
                TS_VAELSTM.defaultDetectConfig.ThresholdMethodDropdown, 2, false);
            thresholdMethodDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdMethodDropdown');

            % Threshold Parameter
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strThresParam'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThresholdParameter'));
            limits = [-inf inf];
            step = 0.5;
            row = 3;
            roundFractional = false;
            thresholdParamSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_VAELSTM.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
            thresholdParamSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdParamSpinner');
            thresholdParamSpinner.Tag = "ThresholdParamSpinner";

            % Threshold
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strThreshold'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThreshold'));
            limits = [-inf inf];
            step = 0.5;
            row = 4;
            roundFractional = false;
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_VAELSTM.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
            thresholdSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdSpinner');
            % Disable at creation since ThresholdMethod is kSigma by
            % default
            thresholdSpinner.Enable = "off";
            thresholdSpinner.Tag = "ThresholdSpinner";

            % Batch Size
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strMiniBatchSize'), 5, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMiniBatchSize'));
            limits = [0.9 inf];
            step = 10;
            row = 5;
            roundFractional = true;
            batchSizeSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_VAELSTM.defaultDetectConfig.BatchSizeSpinner, step, row, roundFractional);
            batchSizeSpinner.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'BatchSizeSpinner');

            % Execution Environment
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strExecEnv'), 6, ...
                m('predmaint_anomaly:anomaly_app:configTooltipExecutionEnvironment'));
            execEnvDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strAuto'), ...
                m('predmaint_anomaly:anomaly_app:strCpu'), ...
                m('predmaint_anomaly:anomaly_app:strGpu')], ...
                {'auto','cpu','gpu'}, ...
                TS_VAELSTM.defaultDetectConfig.ExecEnvDropdown, 6, false);
            execEnvDropdown.ValueChangedFcn = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ExecEnvDropdown');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), false);

            %Persist
            wd.Model.DetectionStrideSpinner  = detectionStrideSpinner;
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
                monitorVae = MonitorFactory(host);
                monitorLstm = MonitorFactory(host);
            else
                monitorVae = MonitorFactory();
                monitorLstm = MonitorFactory();
            end
            monitor = [monitorVae, monitorLstm];

            %For reproducibility
            old = rng;             % save current state (type, seed, substream, etc.)
            restoreRng = onCleanup(@() trainingCleanup(old, monitor));  % restore to previous state
            rng('default');        % set the deterministic default stream


            mdl = vaelstmAD(size(data{1},2), ...
                "ObservationWindowLength",  cc.ObservationWindowLengthSpinner, ...
                "TrainingStride", cc.TrainingStrideSpinner, ...
                "DetectionWindowLength", cc.DetectWindowLengthSpinner, ...
                "Normalization", cc.NormalizeDropdown, ...
                "FilterSize", cc.FilterSizeSpinner, ...
                "NumFilters", cc.NumFiltersSpinner, ...
                "DropoutProbability", cc.DropoutSpinner, ...
                "LatentSpaceDim", cc.LatentSpaceSpinner, ...
                "NumDownsampleLayers", cc.NumDownSampleSpinner, ...
                "NumHiddenUnits", cc.NumHiddenUnitsSpinner);

            % Define callback to turn visibility of the first
            % monitor
            mdl.OnVaeTrainingDone = @()set(monitor(1).FigHndl, "Visible", "off");

            trainOpts = trainingOptions("adam", ...
                "ExecutionEnvironment", cc.ExecEnvDropdown, ...
                "Verbose", false, ...
                "MaxEpochs", cc.LstmMaxEpochsSpinner, ...
                "MiniBatchSize", cc.BatchSizeSpinner, ...
                "InitialLearnRate", cc.LstmLearnRateSpinner,...
                "Plots", "training-progress");

            mdl = train(mdl, data, TrainingOpts=trainOpts, ...
                VaeMaxEpochs = cc.VaeMaxEpochsSpinner, ...
                VaeInitialLearnRate = cc.VaeLearnRateSpinner,...
                VaeMonitor=monitor(1).Monitor, LstmMonitor=monitor(2).Monitor);
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
                        "ThresholdMethod", 'manual', ...
                        "Threshold", config.ThresholdSpinner, ...
                        "DetectionStride", config.DetectionStrideSpinner,...
                        "MiniBatchSize", config.BatchSizeSpinner,...
                        "ExecutionEnvironment", config.ExecEnvDropdown);
                else
                    model.Model = updateDetector(model.Model, trainData, ...
                        "ThresholdMethod", config.ThresholdMethodDropdown, ...
                        "ThresholdParameter", config.ThresholdParamSpinner, ...
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
            obsWinLen = model.ObservationWindowLength;
            detectionStride = model.DetectionStride;
        end

        function fillOverviewDiagram(OverviewPanel, modelOverview)

            Dlnet = modelOverview{1};

            tiled = tiledlayout("horizontal", "Parent", OverviewPanel,...
                "TileSpacing", "tight", "Padding", "tight");
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
            title(ax, 'Decoder');

            ax = nexttile(tiled, 3);
            ax.HitTest= 'off';
            ax.PickableParts ='none';
            ax.Toolbar = [];
            plot(Dlnet{3}, 'Parent', ax);
            title(ax, 'LSTM');
        end
    end
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end
