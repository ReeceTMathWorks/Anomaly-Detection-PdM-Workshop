classdef TS_LOF
    %Static utility class for Local Outlier Factor model related
    %functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

    %   Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strLOF')
        Description (1,1) string = m('predmaint_anomaly:anomaly_app:tipLOF')
        Type (1,1) string = "lof"
        IconName (1,1) string = "cleanOutlierData"

        % Overview Panel
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descLof');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedLof');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationLof');

        defaultModelConfig (1,1) struct = struct(...
            'IncludeTiesDropdown', false, ...
            'SearchMethodDropdown', 'kdtree', ...
            'NumNeighborsSpinner', 20, ...
            'TrainStrideSpinner', 1, ...
            'FeatureExtractDropdown', true,...
            'WindowLengthSpinner', 10,...
            'NormalizeDropdown', 'zscore', ...
            'DistanceDropdown', 'euclidean' ...
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
            import anomalyAPP.internal.app.modelmanager.TS_LOF

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the "Training options" panel
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 2, Tag="TrainOptsGrid");

            % Add components to the "Training options" panel
            % Include Ties configTooltipIncludeTies
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strIncludeTies'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipIncludeTies'));
            includeTiesDropdown = UiWidgetFactory.createDropdown(trainingGrid, ...
                [m('predmaint_anomaly:anomaly_app:strFalse'), ...
                m('predmaint_anomaly:anomaly_app:strTrue')], ...
                {false, true}, TS_LOF.defaultModelConfig.IncludeTiesDropdown, 1, false);
            includeTiesDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'IncludeTiesDropdown');

            % SearchMethodDropdown
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strSearchMthd'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipSearchMethod'));
            searchMethodDropdown = UiWidgetFactory.createDropdown(trainingGrid, ...
                [ m('predmaint_anomaly:anomaly_app:strKdtree'), ...
                m('predmaint_anomaly:anomaly_app:strExhaustive')], ...
                {"kdtree", "exhaustive"}, ...
                TS_LOF.defaultModelConfig.SearchMethodDropdown, 2, false);
            searchMethodDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'SearchMethodDropdown');

            % NumNeighborsSpinner
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strNumNeigh'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipNumberOfNeighbors'));
            limits = [20 10000];
            step = 10;
            row = 3;
            roundFractional = true;
            upperLimitInclusive = true;
            lowerLimitInclusive = true;
            numNeighborsSpinner = UiWidgetFactory.createSpinner(trainingGrid,limits , ...
                TS_LOF.defaultModelConfig.NumNeighborsSpinner, step, row, roundFractional,...
                upperLimitInclusive, lowerLimitInclusive);
            numNeighborsSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NumNeighborsSpinner');

            % Training Stride
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strTrainingStride'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipTrainingStride'));
            limits = [0 inf];
            step = 1;
            row = 4;
            roundFractional = true;
            trainStrideSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_LOF.defaultModelConfig.TrainStrideSpinner, step, row, roundFractional);
            trainStrideSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'TrainStrideSpinner');

            % Create the "Model options" panel
            modelGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strModelOptionsTitle'), 2, 2, Tag="ModelOptsGrid");

            % Add components to the "Model options" panel
            % Feature Extraction
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strFeatureExtraction'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipFeatureExtraction'));
            featureExtractDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strTrue'), m('predmaint_anomaly:anomaly_app:strFalse')], ...
                {true, false}, TS_LOF.defaultModelConfig.FeatureExtractDropdown, 1, false);
            featureExtractDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'FeatureExtractDropdown');

            %Normalize
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strNormalizeData'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipNormalizeData'));
            normalizeDropdown = UiWidgetFactory.createDropdown(modelGrid, ...
                [m('predmaint_anomaly:anomaly_app:strZscore'), ...
                m('predmaint_anomaly:anomaly_app:strRange'), ...
                m('predmaint_anomaly:anomaly_app:strOff')], ...
                {'zscore', 'range', 'off'}, ...
                TS_LOF.defaultModelConfig.NormalizeDropdown, 2, false);
            normalizeDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'NormalizeDropdown');

            % Window Length
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strWinLength'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipWindowLength')); 
            limits = [1, 10000];
            step = 1;
            row = 3;
            roundFractional = true;
            windowLengthSpinner = UiWidgetFactory.createSpinner(modelGrid, limits, ...
                TS_LOF.defaultModelConfig.WindowLengthSpinner, step, row, roundFractional); %Range right limit needs to be dynamic
            windowLengthSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'WindowLengthSpinner');

            % Distance 
            UiWidgetFactory.createLabel(modelGrid, ...
                m('predmaint_anomaly:anomaly_app:strDistance'), 4,...
                m('predmaint_anomaly:anomaly_app:configTooltipDistance')); 
            distanceDropdown = UiWidgetFactory.createDropdown(modelGrid, [m('predmaint_anomaly:anomaly_app:strEuclidean'), ...
                m('predmaint_anomaly:anomaly_app:strFasteuclidean'), ...
                m('predmaint_anomaly:anomaly_app:strMahalanobis'), ...
                m('predmaint_anomaly:anomaly_app:strMinkowski'), ...
                m('predmaint_anomaly:anomaly_app:strChebychev'), ...
                m('predmaint_anomaly:anomaly_app:strCityblock'), ...
                m('predmaint_anomaly:anomaly_app:strCorrelation'), ...
                m('predmaint_anomaly:anomaly_app:strCosine'), ...
                m('predmaint_anomaly:anomaly_app:strSpearman')], ...
                ["euclidean", "fasteuclidean", ...
                "mahalanobis", "minkowski", "chebychev", "cityblock", ...
                "correlation", "cosine", "spearman"], ...
                TS_LOF.defaultModelConfig.DistanceDropdown, 4, false);
            distanceDropdown.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'DistanceDropdown');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            %Persist
            wd.Model.IncludeTiesDropdown = includeTiesDropdown;
            wd.Model.SearchMethodDropdown = searchMethodDropdown;
            wd.Model.NumNeighborsSpinner = numNeighborsSpinner;
            wd.Model.TrainStrideSpinner = trainStrideSpinner;

            wd.Model.FeatureExtractDropdown = featureExtractDropdown;
            wd.Model.WindowLengthSpinner = windowLengthSpinner;
            wd.Model.NormalizeDropdown = normalizeDropdown;
            wd.Model.DistanceDropdown = distanceDropdown;

            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_LOF

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
                TS_LOF.defaultDetectConfig.DetectionStrideSpinner, step, row, roundFractional);
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
                TS_LOF.defaultDetectConfig.ThresholdMethodDropdown, 2, false);
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
                TS_LOF.defaultDetectConfig.ThresholdParamSpinner, step, row, roundFractional);
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
            thresholdSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_LOF.defaultDetectConfig.ThresholdSpinner, step, row, roundFractional);
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

            mdl = timeSeriesLofAD(size(data{1},2), ...
                "IncludeTies", cc.IncludeTiesDropdown, ...
                "SearchMethod", cc.SearchMethodDropdown, ...
                "NumNeighbors", cc.NumNeighborsSpinner, ...
                "TrainingStride", cc.TrainStrideSpinner, ...
                "FeatureExtraction",cc.FeatureExtractDropdown, ...
                "WindowLength", cc.WindowLengthSpinner,  ...
                "Normalization", cc.NormalizeDropdown, ...
                "Distance", cc.DistanceDropdown);

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
                        "DetectionStride", config.DetectionStrideSpinner, ...
                        "ThresholdMethod", config.ThresholdMethodDropdown, ...
                        "ThresholdParameter", config.ThresholdParamSpinner);
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

            % modelOverview {{outliers, x, y, Z, Xgrid, Ygrid}}
            outliers = modelOverview{1}{1};
            x = modelOverview{1}{2};
            y = modelOverview{1}{3};
            Z = modelOverview{1}{4};
            Xgrid = modelOverview{1}{5};
            Ygrid = modelOverview{1}{6};

            hold(OverviewAxes,'on');

            contourf(OverviewAxes, Xgrid,Ygrid,Z,20,'LineColor','none');

            % Normal points
            scatter(OverviewAxes, x,y,50,'MarkerEdgeColor','k','MarkerFaceColor','w');
            % Outliers
            scatter(OverviewAxes, outliers(:,1),outliers(:,2),100,'r','filled','MarkerEdgeColor','k');
        end
    end
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end

% LocalWords:  lof IncludeTiesDropdown SearchMethodDropdown strKdtree FeatureExtractDropdown
% LocalWords:  NormalizeDropdown DistanceDropdown ThresholdMethodDropdown strKSigma strSearchMthd
% LocalWords:  kdtree strFasteuclidean strMahalanobis
