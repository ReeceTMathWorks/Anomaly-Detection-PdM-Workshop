classdef TS_IsolationForest
    %Static utility class for Isolation Forest model related
    %functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

%   Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strIForest')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipIForest')
        Type (1,1) string = "iforest"
        IconName (1,1) string = "decisionTreeSimple"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descIforest');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedIforest');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationIforest');

        defaultModelConfig (1,1) struct = struct(...
            'NumLearnersSpinner', 100, ...
            'NumObservationPerLearnerSpinner', 256, ...
            'UseParallelDropdown', 'no', ...
            'TrainingStrideSpinner', 1, ...
            'FeatureExtractDropdown', true,...
            'WindowLengthSpinner', 10,...
            'NormalizeDropdown', 'zscore' ...
            )

        defaultDetectConfig (1,1) struct = struct(...
            'DetectionStrideSpinner', 10, ...
            'ThresholdSpinner', 1, ...
            'ThresholdMethodDropdown', 'kSigma',...
            'ThresholdParamSpinner', 3)

        %Detector Type
        DetectorType (1,1) string = "MachineLearning"
    end

    methods (Static)
        function createTrainOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_IsolationForest

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the "Training options" panel
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 3, Tag="TrainOptsGrid");

            % Add components to the "Training options" panel
            % Number of Learners
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumLearn'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfLearners'));
            limits = [1 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            numLearnersSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits,...
                TS_IsolationForest.defaultModelConfig.NumLearnersSpinner, step, row, roundFractional);
            numLearnersSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumLearnersSpinner');

            % Number of Observations per Learner
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumObLearn'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfObservationsPerLearner'));
            limits = [3 inf];
            step = 1;
            row = 2;
            roundFractional = true;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            numObservationPerLearnerSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits,...
                TS_IsolationForest.defaultModelConfig.NumObservationPerLearnerSpinner, step, row, ...
                roundFractional, upperLimitInclusive, lowerLimitInclusive);
            numObservationPerLearnerSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumObservationPerLearnerSpinner');

            % UseParallel Dropdown
            UiWidgetFactory.createLabel(trainingGrid, m('predmaint_anomaly:anomaly_app:strUseParallel'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipUseParallel'));            
            useParallelDropdown = UiWidgetFactory.createDropdown(trainingGrid, ...
                [m('predmaint_anomaly:anomaly_app:strYes'),...
                m('predmaint_anomaly:anomaly_app:strNo')], ...
                {'yes', 'no'}, ...
                TS_IsolationForest.defaultModelConfig.UseParallelDropdown, 3, false);
            useParallelDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'UseParallelDropdown');

            % Training Stride
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strTrainingStride'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipTrainingStride'));
            limits = [1 inf];
            step = 1;
            row = 4;
            roundFractional = true;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            trainingStrideSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits,...
                TS_IsolationForest.defaultModelConfig.TrainingStrideSpinner, step, row, ...
                roundFractional, upperLimitInclusive, lowerLimitInclusive);
            trainingStrideSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'TrainingStrideSpinner');

            % Create the "Model options" panel
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptionsTitle'), 2, 2, Tag="ModelOptsGrid");

            % Add components to the "Model options" panel
            % Feature Extraction
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strFeatureExtraction'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipFeatureExtraction'));
            featureExtractDropdown = UiWidgetFactory.createDropdown(modelGrid, [m('predmaint_anomaly:anomaly_app:strTrue'), ...
                m('predmaint_anomaly:anomaly_app:strFalse')], {true, false}, ...
                TS_IsolationForest.defaultModelConfig.FeatureExtractDropdown, 1, false);
            featureExtractDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'FeatureExtractDropdown');

            %Normalize
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid,...
                [m('predmaint_anomaly:anomaly_app:strZscore'), ...
                m('predmaint_anomaly:anomaly_app:strRange'), ...
                m('predmaint_anomaly:anomaly_app:strOff')], ...
                {'zscore', 'range', 'off'}, TS_IsolationForest.defaultModelConfig.NormalizeDropdown, 2, false);
            normalizeDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');

            % Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strWinLength'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipWindowLength')); 
            limits = [1 inf];
            step = 1;
            row = 3;
            roundFractional = true;
            windowLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, limits,...
                TS_IsolationForest.defaultModelConfig.WindowLengthSpinner, step, row, roundFractional); %Range right limit needs to be dynamic
            windowLengthSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'WindowLengthSpinner');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            %Persist

            wd.Model.NumLearnersSpinner = numLearnersSpinner;
            wd.Model.NumObservationPerLearnerSpinner = numObservationPerLearnerSpinner;
            wd.Model.UseParallelDropdown = useParallelDropdown;
            wd.Model.TrainingStrideSpinner = trainingStrideSpinner;
            wd.Model.FeatureExtractDropdown = featureExtractDropdown;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.WindowLengthSpinner = windowLengthSpinner;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_IsolationForest

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the detection panel
            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 4, Tag="DetectOptsGrid");

            % Add components to the "Detection Configurations" panel
            %Detection Stride
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strDetectionStride'), 1, ...
                m('predmaint_anomaly:anomaly_app:configTooltipDetectionStride'));
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            detectionStrideSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_IsolationForest.defaultDetectConfig.DetectionStrideSpinner, step, row, roundFractional);
            detectionStrideSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionStrideSpinner');

            %Threshold Method
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strThresMethod'), 2, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThresholdMethod'));
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid,...
                [...
                m('predmaint_anomaly:anomaly_app:strKSigma'),...
                m('predmaint_anomaly:anomaly_app:strMean'), ...
                m('predmaint_anomaly:anomaly_app:strMedian'), ...
                m('predmaint_anomaly:anomaly_app:strMax'), ...
                m('predmaint_anomaly:anomaly_app:strContamFrac'), ...
                m('predmaint_anomaly:anomaly_app:strManual')...
                ], ...
                {'kSigma', 'mean','median','max', 'contaminationFraction', 'manual'}, ...
                TS_IsolationForest.defaultDetectConfig.ThresholdMethodDropdown, 2, false);
            thresholdMethodDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdMethodDropdown');

            %Threshold Parameter
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strThresParam'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThresholdParameter'));
            limits = [-inf inf];
            step = 0.5;
            row = 3;
            roundFractional = false;
            thresholdParamSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_IsolationForest.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
            thresholdParamSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdParamSpinner');
            thresholdParamSpinner.Tag = "ThresholdParamSpinner";

            % Needs to be enabled only if ThresholdMethod is set to
            % 'manual'
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strThreshold'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThreshold'));
            limits = [-inf inf];
            step = 0.5;
            row = 4;
            roundFractional = false;
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits,...
                TS_IsolationForest.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
            thresholdSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdSpinner');
            % Disable at creation since ThresholdMethod is kSigma by
            % default
            thresholdSpinner.Enable = "off";
            thresholdSpinner.Tag = "ThresholdSpinner";

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), false);

            %Persist
            wd.Model.DetectionStrideSpinner = detectionStrideSpinner;
            wd.Model.ThresholdMethodDropdown = thresholdMethodDropdown;
            wd.Model.ThresholdParamSpinner = thresholdParamSpinner;
            wd.Model.ThresholdSpinner = thresholdSpinner;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function [mdl, monitor] = trainModel(data, cc)
            import anomalyAPP.internal.app.modelmanager.utils.*

            %For reproducibility
            old = rng;             % save current state (type, seed, substream, etc.)
            restoreRng = onCleanup(@() trainingCleanup(old));  % restore to previous state and delete training progress
            rng('default');        % set the deterministic default stream

            
            mdl = timeSeriesIforestAD(size(data{1},2), ...
                "NumLearners", cc.NumLearnersSpinner, ...
                "NumObservationsPerLearner", cc.NumObservationPerLearnerSpinner, ...
                "TrainingStride", cc.TrainingStrideSpinner, ...
                "Normalization", cc.NormalizeDropdown,...
                "WindowLength", cc.WindowLengthSpinner, ...
                "FeatureExtraction", cc.FeatureExtractDropdown); %,...
            % "UseParallel", cc.UseParallelDropdown... % TODO: timeSeriesIforest
            % needs to support useparallel
            % );

            mdl = train(mdl, data);
            monitor = [];
        end

        function [tbl, model] = detect(model, trainData, testData, config, needsConfigUpdate)

            % When called from detect tab, needConfigUpdate is set to true
            % only if tip and LKG are different. config is Tip always in
            % this case.
            % When called from train tab validation metrics,
            % needConfigUpdate is always set to true. config is LKG always
            % in this case.
            if needsConfigUpdate
                % If method is selected to be manual, then none of the other
                % options are needed. Update the detector with the current
                % config.
                if config.ThresholdMethodDropdown ==  "manual"
                    model.Model = updateDetector(model.Model, ...
                        "ThresholdMethod", "manual", ...
                        "Threshold", config.ThresholdSpinner);
                else
                    model.Model = updateDetector(model.Model, trainData, ...
                        "DetectionStride",      config.DetectionStrideSpinner, ...
                        "ThresholdMethod",      config.ThresholdMethodDropdown, ...
                        "ThresholdParameter",   config.ThresholdParamSpinner);
                end
            end

            % Call detect on the updated detector
            tbl = detect(model.Model, testData);

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

            windowLength = model.WindowLength;
            obsWinLen = 0;
            detectionStride = model.DetectionStride;
        end

        function fillOverviewDiagram(OverviewPanel, modelOverview)
            OverviewAxes = uiaxes(OverviewPanel, 'Visible', 'off',...
                'Units', 'normalized', 'Position', [0 0 1 1],...
                'HitTest','off','PickableParts','none', 'Toolbar', []);

            
            % Modeloverview content {{G, nodeLabels, anomalyLeafId}}
            G = modelOverview{1}{1};
            nodeLabels = modelOverview{1}{2};
            anomalyLeafId = modelOverview{1}{3};

            gp = plot(G, 'Parent',OverviewAxes, ...
                'Layout','layered', 'Direction','right', ...
                'NodeLabel', nodeLabels, ...
                'Interpreter','none', ...
                'MarkerSize', 10);

            highlight(gp, anomalyLeafId, 'NodeColor', [1 0 0], 'MarkerSize', 8);           

        end
    end
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end

% LocalWords:  strIForest tipIForest iforest UseParallelDropdown FeatureExtractDropdown
% LocalWords:  NormalizeDropdown ThresholdMethodDropdown strKSigma Dropdown TipDetectConfig
% LocalWords:  strThresMethod strContamFrac strThresParam useparallel
