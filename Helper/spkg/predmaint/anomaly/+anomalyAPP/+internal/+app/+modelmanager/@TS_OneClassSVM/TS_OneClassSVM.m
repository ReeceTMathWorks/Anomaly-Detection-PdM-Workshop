classdef TS_OneClassSVM
    %Static utility class for One-Class SVM model related
    %functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

%   Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strOCSVM')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipOCSVM')
        Type (1,1) string = "ocsvm"
        IconName (1,1) string = "tsSvmOneClass"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descOcsvm');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedOcsvm');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationOcsvm');

        defaultModelConfig (1,1) struct = struct(...
            'IterLimSpinner', 2000, ...
            'BetaTolSpinner', 1, ...
            'GradientTolSpinner', 0,...
            'TrainStrideSpinner', 1, ...
            'FeatureExtractDropdown', true,...
            'WindowLengthSpinner', 10,...
            'KernelScaleSpinner', 1,...
            'NormalizeDropdown', 'zscore', ...
            'NumExpanDimSpinner', 2^5, ...
            'LambdaSpinner', 0.01)

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
            import anomalyAPP.internal.app.modelmanager.TS_OneClassSVM

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % --- Training Options Panel ---
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 4, Tag="TrainOptsGrid");

            % Iteration Limit
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strIterLimit'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipIterationLimit'));
            limits = [1 10000];
            step = 1;
            row = 1;
            roundFractional = true;
            iterLimSpinner = UiWidgetFactory.createSpinner(trainingGrid,...
                limits, TS_OneClassSVM.defaultModelConfig.IterLimSpinner, step, row, roundFractional);
            iterLimSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'IterLimSpinner');

            % Beta Tolerance
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strBetaTol'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipBetaTolerance'));
            limits = [0 inf];
            step = 1e-2;
            row = 2;
            roundFractional = false;
            betaTolSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits,...
                TS_OneClassSVM.defaultModelConfig.BetaTolSpinner, step, row, roundFractional);
            betaTolSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'BetaTolSpinner');

            % Gradient Tolerance
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strGradientTol'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipGradientTolerance'));
            limits = [0 inf];
            step = 1e-4;
            row = 3;
            roundFractional = false;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            gradientTolSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_OneClassSVM.defaultModelConfig.GradientTolSpinner, step, row, roundFractional,...
                upperLimitInclusive, lowerLimitInclusive);
            gradientTolSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'GradientTolSpinner');

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
            trainStrideSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits,...
                TS_OneClassSVM.defaultModelConfig.TrainStrideSpinner, step, row, roundFractional, ...
                upperLimitInclusive, lowerLimitInclusive);
            trainStrideSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'TrainStrideSpinner');

            % --- Model Options Panel ---
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptions'), 2, 6, Tag="ModelOptsGrid");

            % Feature Extraction
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strFeatureExtraction'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipFeatureExtraction'));
            featureExtractDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strTrue'), m('predmaint_anomaly:anomaly_app:strFalse')], ..., ...
                {true,false}, TS_OneClassSVM.defaultModelConfig.FeatureExtractDropdown, 1, false);
            featureExtractDropdown.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'FeatureExtractDropdown');

            % Normalization
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strZscore'),...
                m('predmaint_anomaly:anomaly_app:strRange'),...
                m('predmaint_anomaly:anomaly_app:strOff')], {'zscore','range','off'}, ...
                TS_OneClassSVM.defaultModelConfig.NormalizeDropdown, 2, false);
            normalizeDropdown.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');

            % Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strWinLength'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipWindowLength'));
            limits = [1 inf];
            step = 1;
            row = 3;
            roundFractional = true;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            winLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_OneClassSVM.defaultModelConfig.WindowLengthSpinner, step, row, roundFractional, ...
                upperLimitInclusive, lowerLimitInclusive);
            winLengthSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'WindowLengthSpinner');

            % Kernel Scale
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strKernelScale'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipKernelScale'));
            limits = [1 inf];
            step = 1;
            row = 4;
            roundFractional = true;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            kernelScaleSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_OneClassSVM.defaultModelConfig.KernelScaleSpinner, step, row, roundFractional, ...
                upperLimitInclusive, lowerLimitInclusive);
            kernelScaleSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'KernelScaleSpinner');

            % Num Expansion Dimensions
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumExpanDim'), 5,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfExpansionDimensions'));
            limits = [1 inf];
            step = 1;
            row = 5;
            roundFractional = true;
            numExpanDimSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_OneClassSVM.defaultModelConfig.NumExpanDimSpinner, step, row, roundFractional);
            numExpanDimSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumExpanDimSpinner');

            % Lambda
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strLambda'), 6,...
                m('predmaint_anomaly:anomaly_app:configTooltipLambdaOCSVM'));
            limits = [0 inf];
            step = 1e-2;
            row = 6;
            roundFractional = false;
            upperLimitInclusive = false;
            lowerLimitInclusive = false;
            lambdaSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_OneClassSVM.defaultModelConfig.LambdaSpinner, step, row, roundFractional,...
                upperLimitInclusive, lowerLimitInclusive);
            lambdaSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LambdaSpinner');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            %Persist
            wd.Model.IterLimSpinner = iterLimSpinner;
            wd.Model.BetaTolSpinner = betaTolSpinner;
            wd.Model.GradientTolSpinner = gradientTolSpinner;
            wd.Model.TrainStrideSpinner = trainStrideSpinner;

            wd.Model.FeatureExtractDropdown = featureExtractDropdown;
            wd.Model.KernelScaleSpinner = kernelScaleSpinner;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.NumExpanDimSpinner = numExpanDimSpinner;
            wd.Model.LambdaSpinner = lambdaSpinner;
            wd.Model.WindowLengthSpinner = winLengthSpinner;

            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_OneClassSVM

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the detection panel
            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 4, Tag="DetectOptsGrid");

            % Add components to the "Detection Configurations" panel
            % Detection Stride
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strDetectionStride'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipDetectionStride'));
            limits = [0.9 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            detectionStrideSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_OneClassSVM.defaultDetectConfig.DetectionStrideSpinner, step, row, roundFractional);
            detectionStrideSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionStrideSpinner');
            
            % Threshold Method
            UiWidgetFactory.createLabel(detectionGrid,  ...
                m('predmaint_anomaly:anomaly_app:strThresMethod'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipThresholdMethod'));
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strKSigma'),...
                m('predmaint_anomaly:anomaly_app:strMean'), ...
                m('predmaint_anomaly:anomaly_app:strMedian'), ...
                m('predmaint_anomaly:anomaly_app:strMax'), ...
                m('predmaint_anomaly:anomaly_app:strContamFrac'), ...
                m('predmaint_anomaly:anomaly_app:strManual')...
                ], ...
                {'kSigma', 'mean','median','max', 'contaminationFraction', 'manual'}, ...
                TS_OneClassSVM.defaultDetectConfig.ThresholdMethodDropdown, 2, false);
            thresholdMethodDropdown.ValueChangedFcn = @(~,ed) ...
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
                TS_OneClassSVM.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
            thresholdParamSpinner.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdParamSpinner');
            thresholdParamSpinner.Tag = "ThresholdParamSpinner";

            % Threshold
            UiWidgetFactory.createLabel(detectionGrid,  ...
                m('predmaint_anomaly:anomaly_app:strThreshold'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipThreshold'));
            limits = [-inf inf];
            step = 0.5;
            row = 4;
            roundFractional = false;
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_OneClassSVM.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
            thresholdSpinner.ValueChangedFcn = @(~,ed) ...
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
            
            mdl = timeSeriesOcsvmAD(size(data{1},2), ...
                "BetaTolerance", cc.BetaTolSpinner, ...
                "IterationLimit", cc.IterLimSpinner, ...
                "GradientTolerance", cc.GradientTolSpinner, ...
                "TrainingStride", cc.TrainStrideSpinner, ...
                "FeatureExtraction", cc.FeatureExtractDropdown, ...
                "WindowLength", cc.WindowLengthSpinner,  ...
                "Normalization", cc.NormalizeDropdown, ...
                "NumExpansionDimensions", cc.NumExpanDimSpinner, ... Needs to be fixed
                "Lambda", cc.LambdaSpinner);

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
                        "DetectionStride",      config.DetectionStrideSpinner,...
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

            OverviewAxes = uiaxes(OverviewPanel, 'Visible', 'off', ...
                'Units', 'normalized', 'Position', [0 0 1 1],...
                'HitTest','off','PickableParts','none', 'Toolbar', []);

            %modeloverview {{insideIdx, outsideIdx, scoreGrid, X, x1Grid, x2Grid}}
            insideIdx = modelOverview{1}{1};
            outsideIdx = modelOverview{1}{2};
            scoreGrid = modelOverview{1}{3};
            X = modelOverview{1}{4};
            x1Grid = modelOverview{1}{5};
            x2Grid = modelOverview{1}{6};

            % Plot decision boundary and heatmap
            hold(OverviewAxes,"on");            
            contourf(OverviewAxes, x1Grid, x2Grid, reshape(scoreGrid, size(x1Grid)), 30, 'LineColor', 'none'); % Score heatmap
            
            % Color points based on score            
            scatter(OverviewAxes, X(insideIdx,1), X(insideIdx,2), 40,'g', 'filled', 'MarkerEdgeColor','k'); % Green inside
            scatter(OverviewAxes, X(outsideIdx,1), X(outsideIdx,2), 50, 'r', 'filled', 'MarkerEdgeColor','k'); % Red outside
            contour(OverviewAxes, x1Grid, x2Grid, reshape(scoreGrid, size(x1Grid)), [0 0], 'r', 'LineWidth', 2); % Decision boundary
        end
    end
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));

end
