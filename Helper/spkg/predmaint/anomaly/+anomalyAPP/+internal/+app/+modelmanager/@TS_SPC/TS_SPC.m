classdef TS_SPC
    %Static utility class for Statistical Process Control (SPC) model
    %related functionalities like constructing the training & detection
    %configuration panel along with the train and detect actions

    %   Copyright 2025 The MathWorks, Inc.

    properties (Constant)
        Name (1,1) string = m('predmaint_anomaly:anomaly_app:strSPC')
        Description (1,1) string =  m('predmaint_anomaly:anomaly_app:tipSPC')
        Type (1,1) string = "spc"
        IconName (1,1) string = "boundedSignal"

        % Overview Panel Info
        ScoringDescription (1,1) string = m('predmaint_anomaly:anomaly_app:descSpc');
        BestSuitedDescription (1,1) string = m('predmaint_anomaly:anomaly_app:bestSuitedSpc');
        TuningRecommendationDescription (1,1) string = m('predmaint_anomaly:anomaly_app:tuningRecommendationSpc');

        defaultModelConfig (1,1) struct = struct(...
            'WindowLengthSpinner',  10, ...
            'MethodDropdown',       'individual', ...
            'LambdaSpinner',        0.4)

        defaultDetectConfig (1,1) struct = struct(...
            'DetectionRulesListBox',  {{'n1'}}, ... % double cell prevents struct from converting cell to char
            'ThresholdMethodDropdown', 'auto', ...
            'LevelSpinner',             3, ...
            'CenterLineEditField',      0, ...
            'StandardErrorEditField',   3, ...
            'MeanEditField',            1, ...
            'SigmaEditField',           1)

        %Detector Type
        DetectorType (1,1) string = "Statistical"
    end

    methods (Static)
        function createTrainOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_SPC

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the "Training options" panel
            trainingGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strTrainingOptions'), 1, 4, Tag="TrainOptsGrid");

            % Add components to the "Training options" panel
            % Window Length
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strWinLength'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipWindowLength'));
            limits = [1 inf];
            step = 1;
            row = 1;
            roundFractional = true;
            upperLimitInclusive = false;
            lowerLimitInclusive = true;
            windowLengthSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_SPC.defaultModelConfig.WindowLengthSpinner, step, row, roundFractional,...
                upperLimitInclusive, lowerLimitInclusive);
            windowLengthSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'WindowLengthSpinner');

            %Method Dropdown 
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strMethod'), 2,...
                m('predmaint_anomaly:anomaly_app:configTooltipMethod'));
            methodDropdown = UiWidgetFactory.createDropdown(trainingGrid, ...
                [m('predmaint_anomaly:anomaly_app:strIndividual'), ...
                m('predmaint_anomaly:anomaly_app:strEwma')], {'individual', 'ewma'}, ...
                TS_SPC.defaultModelConfig.MethodDropdown, 2, false);
            methodDropdown.ValueChangedFcn  = @(es,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'MethodDropdown');

            % Lambda
            UiWidgetFactory.createLabel(trainingGrid, ...
                m('predmaint_anomaly:anomaly_app:strLambda'), 3,...
                m('predmaint_anomaly:anomaly_app:configTooltipLambda'));
            limits = [0 1];
            step = 0.05;
            row = 3;
            roundFractional = false;
            upperLimitInclusive = true;
            lowerLimitInclusive = false;
            lambdaSpinner = UiWidgetFactory.createSpinner(trainingGrid, limits, ...
                TS_SPC.defaultModelConfig.LambdaSpinner, step, row, roundFractional, ...
                upperLimitInclusive, lowerLimitInclusive);
            lambdaSpinner.ValueChangedFcn  = @(es,ed) GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipConfig', 'LambdaSpinner');

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), true);

            %Persist
            wd.Model.WindowLengthSpinner    = windowLengthSpinner;
            wd.Model.MethodDropdown         = methodDropdown;
            wd.Model.LambdaSpinner          = lambdaSpinner;
            wd.Model.RevertButton           = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function createDetectOptionsPanel(PanelOptionsObj, ModelStore, modelName)
            import anomalyAPP.internal.app.modelmanager.utils.*
            import anomalyAPP.internal.app.modelmanager.TS_SPC

            weak_obj = matlab.lang.WeakReference(PanelOptionsObj);
            wd = PanelOptionsObj.Widgets;
            mainGrid = wd.MainGrid;

            % Create the detection panel
            detectionGrid = UiWidgetFactory.createGrid(mainGrid, m('predmaint_anomaly:anomaly_app:strDetectionConfig'), 1, 7, Tag="DetectOptsGrid");

            % Add components to the "Detection Configurations" panel
            % Detection Rules
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strDetectionRule'), 1,...
                m('predmaint_anomaly:anomaly_app:configTooltipDetectionRules'));
            items = ["n1", "n2", "n3", "n4", "n5", "n6", "n7", "n8",...
                "we1", "we2", "we3", "we4", "we5", "we6","we7", "we8", "we9", "we10",...
                "n", "we"];
            multiSelect = true;
            row = 1;
            detectionRulesListBox = UiWidgetFactory.createListBox(detectionGrid, items, row, multiSelect);
            detectionRulesListBox.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'DetectionRulesListBox');

            % Threshold Method
            UiWidgetFactory.createLabel(detectionGrid,  ...
                m('predmaint_anomaly:anomaly_app:strThresMethod'), 2);
            thresholdMethodDropdown = UiWidgetFactory.createDropdown(detectionGrid, [...
                m('predmaint_anomaly:anomaly_app:strAuto'),...
                m('predmaint_anomaly:anomaly_app:strManual')...
                ], {'auto', 'manual'}, ...
                TS_SPC.defaultDetectConfig.ThresholdMethodDropdown, 2, false);
            thresholdMethodDropdown.ValueChangedFcn = @(~,ed) ...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'ThresholdMethodDropdown');

            % Level Spinner
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strLevel'), 3, ...
                m('predmaint_anomaly:anomaly_app:configTooltipLevel'));
            limits = [0 inf];
            step = 1;
            row = 3;
            roundFractional = false;
            upperLimitInclusive = false;
            lowerLimitInclusive = false;
            levelSpinner = UiWidgetFactory.createSpinner(detectionGrid, limits, ...
                TS_SPC.defaultDetectConfig.LevelSpinner, step, row, roundFractional, upperLimitInclusive, lowerLimitInclusive);
            levelSpinner.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'LevelSpinner');

            % Center Line
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strCenterLine'), 4, ...
                m('predmaint_anomaly:anomaly_app:configTooltipCenterLine'));
            centerLineEditField = UiWidgetFactory.createEditField(detectionGrid, ...
                mat2str(TS_SPC.defaultDetectConfig.CenterLineEditField), 4);
            centerLineEditField.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'CenterLineEditField');
            centerLineEditField.Tag = "CenterLineEditField";
            centerLineEditField.Enable = "off";

            % Standard Error
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strStandardError'), 5, ...
                m('predmaint_anomaly:anomaly_app:configTooltipStandardError'));
            standardErrorEditField = UiWidgetFactory.createEditField(detectionGrid, ...
                mat2str(TS_SPC.defaultDetectConfig.StandardErrorEditField), 5);
            standardErrorEditField.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'StandardErrorEditField');
            standardErrorEditField.Tag = "StandardErrorEditField";
            standardErrorEditField.Enable = "off";

            % Mean
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strMean'), 6, ...
                m('predmaint_anomaly:anomaly_app:configTooltipMean'));
            meanEditField = UiWidgetFactory.createEditField(detectionGrid, ...
                mat2str(TS_SPC.defaultDetectConfig.MeanEditField), 6);
            meanEditField.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'MeanEditField');
            meanEditField.Tag = "MeanEditField";
            meanEditField.Enable = "off";

            % Sigma
            UiWidgetFactory.createLabel(detectionGrid, ...
                m('predmaint_anomaly:anomaly_app:strSigma'), 7, ...
                m('predmaint_anomaly:anomaly_app:configTooltipSigma'));
            sigmaEditField = UiWidgetFactory.createEditField(detectionGrid, ...
                mat2str(TS_SPC.defaultDetectConfig.SigmaEditField), 7);
            sigmaEditField.ValueChangedFcn  = @(~,ed)...
                GenericCallbacks.updateField(ed, ModelStore, modelName, 'TipDetectConfig', 'SigmaEditField');
            sigmaEditField.Tag = "SigmaEditField";
            sigmaEditField.Enable = "off";

            % Add the "Revert" button
            parent = mainGrid.Parent; % Revert button should be on the top grid, not the content grid
            row = numel(parent.RowHeight); % Last row
            revertButton = UiWidgetFactory.createRevertButton(weak_obj.Handle, ...
                parent, row, ModelStore, modelName,...
                m('predmaint_anomaly:anomaly_app:strRevert'), false);

            %Persist
            wd.Model.DetectionRulesListBox = detectionRulesListBox;
            wd.Model.ThresholdMethodDropdown = thresholdMethodDropdown;
            wd.Model.LevelSpinner = levelSpinner;
            wd.Model.CenterLineEditField = centerLineEditField;
            wd.Model.StandardErrorEditField = standardErrorEditField;
            wd.Model.MeanEditField = meanEditField;
            wd.Model.SigmaEditField = sigmaEditField;
            wd.Model.RevertButton = revertButton;

            PanelOptionsObj.Widgets.Model = wd.Model;
        end

        function [mdl, monitor] = trainModel(data, cc)
            import anomalyAPP.internal.app.modelmanager.utils.*

            %For reproducibility
            old = rng;             % save current state (type, seed, substream, etc.)
            restoreRng = onCleanup(@() trainingCleanup(old));  % restore to previous state and delete training progress
            rng('default');        % set the deterministic default stream            

            mdl = timeSeriesSpcAD(size(data{1},2), ...
                "WindowLength", cc.WindowLengthSpinner, ...
                "Lambda", cc.LambdaSpinner,...
                "Method", cc.MethodDropdown);

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
                % No need to provide training data because unlike other
                % models SPC does not use it for generating scores. If data
                % is provided then SPC detector calls train again. In the
                % App right now, there is only one train data per session.
                model.Model = updateDetector(model.Model, ...
                    "DetectionRules",   config.DetectionRulesListBox,...
                    "Level",            config.LevelSpinner, ...
                    "Mean",             config.MeanEditField, ...
                    "CenterLine",       config.CenterLineEditField, ...
                    "Sigma",            config.SigmaEditField, ...
                    "StandardError",    config.StandardErrorEditField);
            end

            tbl = detect(model.Model, testData);

            % Downstream functionality assumes that detectionResults are
            % always formatted for member level access
            if ~iscell(tbl)
                tbl = {tbl};
            end

            % Update Detector config panel to reflect the properties post
            % call to updateDetector() - this is important when the data
            % input to updateDetector is different than to train or
            % previous updateDetector calls.
            model = model.Handler.updateTipDetectConfig(model);
        end

        function model = updateTipDetectConfig(model)
            model.TipDetectConfig.LevelSpinner = model.Model.Level;
            if model.TipDetectConfig.ThresholdMethodDropdown ~= "manual"
                % Update the necessary values in both the current config
                % and the LKG config since the model's values changed
                model.TipDetectConfig.CenterLineEditField = model.Model.CenterLine;
                model.TipDetectConfig.MeanEditField = model.Model.Mean;
                model.TipDetectConfig.SigmaEditField = model.Model.Sigma;
                model.TipDetectConfig.StandardErrorEditField = model.Model.StandardError;
                model.LKGDetectConfig.CenterLineEditField = model.Model.CenterLine;
                model.LKGDetectConfig.MeanEditField = model.Model.Mean;
                model.LKGDetectConfig.SigmaEditField = model.Model.Sigma;
                model.LKGDetectConfig.StandardErrorEditField = model.Model.StandardError;
            end
        end

        function [windowLength, detectionStride, obsWinLen] = getCommonWindowDefinitions(model)


            windowLength = model.WindowLength;
            obsWinLen = 0;
            detectionStride = model.Stride;
        end

        function fillOverviewDiagram(OverviewPanel, modelOverview)

            OverviewAxes = uiaxes(OverviewPanel, 'Visible', 'off', ...
                'Units', 'normalized', 'Position', [0 0 1 1],...
                'HitTest','off','PickableParts','none', 'Toolbar', []);

            %modelOverview order:{CL, LCL, method, names, UCL, windowLength, windowResults, Z}
            CL = modelOverview{1}{1};
            LCL = modelOverview{1}{2};
            method = modelOverview{1}{3}; 
            names = modelOverview{1}{4};
            UCL = modelOverview{1}{5};
            windowLength = modelOverview{1}{6};
            windowResults = modelOverview{1}{7};
            Z = modelOverview{1}{8};

            anomalyCLI.internal.utils.AnomalyDetection.plotControlChart(OverviewAxes, {Z}, names, ...
                windowResults, windowLength, method, CL, LCL, UCL);

            legend(OverviewAxes, "off");
        end
    end

end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end