classdef GenericCallbacks
    % GENERICCALLBACKS
    % Provides generic handlers to update configurations.

    % Copyright 2025 The MathWorks, Inc.

    methods (Static)
        function updateField(ed, modelStore, modelName, configType, fieldName)
            arguments
                ed matlab.ui.eventdata.ValueChangedData
                modelStore anomalyAPP.internal.utils.ModelStore
                modelName string
                configType string
                fieldName string
            end
            % ed: event data from UI control
            % ModelStore: struct holding model configurations
            % modelName: string key for the model
            % configType: 'TipConfig' or 'TipDetectConfig'
            % fieldName: name of the field to update

            % At present only uieditfield needs this validation
            [value, ed] = localValidateValue(ed);

            model = modelStore.getModel(modelName);

            % model.Model is not defined until training
            if isempty(model.Model)
                numChannels = [];
            else
                numChannels = model.Model.NumChannels;
            end

            % Manage cross widget relationship
            [value, vField, vValue] = validateCrossWidgetValues(ed, fieldName, value, numChannels);

            model.(configType).(fieldName) = value;
            
            if ~isempty(vField)
                model.(configType).(vField) = vValue;
            end

            modelStore.setModel(modelName, model); 
        end

        function RevertButton(obj, ~, modelStore, modelName, trainFlag)
            % Revert all configuration values to the LKG.
            model = modelStore.getModel(modelName);

            if trainFlag
                % Update the current training config values with LKG.
                savedConfig = model.LKGConfig;
                model.TipConfig = savedConfig;
            else
                % Update the current detection config values with LKG.
                savedConfig = model.LKGDetectConfig;
                model.TipDetectConfig = savedConfig;
            end
            modelStore.setModel(modelName, model);

            % Loop through each field and copy the value to the new widgets
            fields = fieldnames(savedConfig);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if isfield(obj.Widgets.Model, fieldName)
                    if isa(obj.Widgets.Model.(fieldName).Value, 'char')
                        savedVal = num2str(savedConfig.(fieldName));
                    else
                        savedVal = savedConfig.(fieldName);
                    end
                    obj.Widgets.Model.(fieldName).Value = savedVal;
                end
            end

            % Log a DDUX event for the button
            eventID = matlab.ddux.internal.UIEventIdentification(...
                'Predictive Maintenance Toolbox', ... % product
                'Time Series Anomaly Detector', ... % scope
                matlab.ddux.internal.EventType.CLICK, ... % event type
                matlab.ddux.internal.ElementType.BUTTON, ... % element type
                obj.Widgets.Model.RevertButton.Tag); % element ID
            matlab.ddux.internal.logUIEvent(eventID);
        end
    end
end

function [value, ed] = localValidateValue(ed)

if isempty(ed.Source)
    % For callbacks used in unit tests, skip additional checking.
    value = ed.Value;
elseif strcmpi(ed.Source.Type, "uieditfield")
    % Check if the new value can be successfully converted
    % to numeric type. If not then reassign to previous value.
    try
        value = str2num(ed.Value);
        if isempty(value)
            value = str2num(ed.PreviousValue);
            ed.Source.Value = ed.PreviousValue;
        end
    catch
        value = str2num(ed.PreviousValue);
        ed.Source.Value = ed.PreviousValue;
    end

    % Check if the size of the new value is 1 or equal to max
    % of the other fields
else
    % For other ui widgets that do not require additional validation
    value = ed.Value;
end
end

function [value, varargout] = validateCrossWidgetValues(ed, fieldName, value, numChannels)
arguments
    ed matlab.ui.eventdata.ValueChangedData
    fieldName string
    value
    numChannels double = []
end

varargout{1} = [];
varargout{2} = [];
if ismember(fieldName, ["AlphaSpinner", "BetaSpinner"])
    if strcmpi(fieldName, "AlphaSpinner")
        % Set BetaSpinner to 1-AlphaSpinner value
        betaSpinner = findobj(ed.Source.Parent.Children, "Tag", "BetaSpinner");
        betaSpinner.Value = 1-ed.Value;
        varargout{1} = "BetaSpinner";
        varargout{2} = betaSpinner.Value;
    else
        % Set BetaSpinner to 1-AlphaSpinner value
        alphaSpinner = findobj(ed.Source.Parent.Children, "Tag", "AlphaSpinner");
        alphaSpinner.Value = 1-ed.Value;
        varargout{1} = "AlphaSpinner";
        varargout{2} = alphaSpinner.Value;
    end
elseif strcmpi(fieldName, "ThresholdMethodDropdown")
    ismanual = strcmpi(value, "manual");
    % Most detectors use the threshold spinner and threshold parameter
    % spinner
    thresholdSpinner = findobj(ed.Source.Parent.Children, "Tag", "ThresholdSpinner");
    thresholdParamSpinner = findobj(ed.Source.Parent.Children, "Tag", "ThresholdParamSpinner");
    if ~isempty(thresholdSpinner)
        thresholdSpinner.Enable = ismanual;      
        thresholdParamSpinner.Enable = ~ismanual; % Assume if thresholdSpinner is valid, then so is thresholdParamSpinner
    end
    % SPC detectors use the center line edit field, mean edit field, sigma
    % edit field, and standard error edit field
    centerLineEditField = findobj(ed.Source.Parent.Children, "Tag", "CenterLineEditField");
    meanEditField = findobj(ed.Source.Parent.Children, "Tag", "MeanEditField");
    sigmaEditField = findobj(ed.Source.Parent.Children, "Tag", "SigmaEditField");
    standardErrorEditField = findobj(ed.Source.Parent.Children, "Tag", "StandardErrorEditField");
    if ~isempty(centerLineEditField)
        centerLineEditField.Enable = ismanual;
        meanEditField.Enable = ismanual; % Assume if center line is valid, then so are the others
        sigmaEditField.Enable = ismanual;
        standardErrorEditField.Enable = ismanual;
    end
elseif ismember(fieldName, ["CenterLineEditField", "MeanEditField", "SigmaEditField", "StandardErrorEditField"] )
    % Check that the new value has size == 1 or equal to the max of all
    % other fields. If not, then revert
    if ~xor(numel(value) ~=1, numel(value) ~= numChannels)
        ed.Source.Value = ed.PreviousValue;
        value = str2num(ed.PreviousValue);
    end
end
end