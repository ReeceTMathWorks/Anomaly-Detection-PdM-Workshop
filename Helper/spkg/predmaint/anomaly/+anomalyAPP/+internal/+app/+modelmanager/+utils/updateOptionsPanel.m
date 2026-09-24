function updateOptionsPanel(savedConfig, wd)

% Reload saved config: Loop through each field and assign the value.
fields = fieldnames(savedConfig);
for i = 1:numel(fields)
    fieldName = fields{i};
    if contains(fieldName, 'editfield', 'IgnoreCase', true)
        savedVal = num2str(savedConfig.(fieldName));
    else
        savedVal = savedConfig.(fieldName);
    end

    % deepSignalAnomalyDetector models store threshold as single type
    if isa(savedVal, "single")
        savedVal = double(savedVal);
    end

    wd.Model.(fieldName).Value = savedVal;
end