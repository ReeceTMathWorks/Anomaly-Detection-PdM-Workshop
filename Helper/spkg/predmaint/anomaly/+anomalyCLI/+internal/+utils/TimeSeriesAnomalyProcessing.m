classdef (Sealed = true) TimeSeriesAnomalyProcessing
    % Run "doc anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing" for more information.

    % Copyright 2025-2026 The MathWorks, Inc.
    %#codegen

    methods (Static, Sealed = true)
        function [out, varnames] = convertDataToCellArray(data)
            % Convert the input data into cell array of 2-D arrays.
            if isnumeric(data) % Includes numeric gpuArray.
                out = {data};
                [~,nc] = size(data);
                varnames = formVarNamesforNumericData(nc);
            elseif istimetable(data)
                out = cell(1,1);
                [out{1}, varnames] = extractFromTimeTable(data);
            elseif iscell(data)
                if isnumeric(data{1}) % Includes numeric gpuArray.
                    out = data;
                    [~,nc] = size(data{1});
                    varnames = formVarNamesforNumericData(nc);
                elseif istimetable(data{1})
                    out = cell(1,numel(data));
                    [out{1},varnames] = extractFromTimeTable(data{1});
                    coder.unroll();
                    for i = 2:numel(data)
                        out{i} = extractFromTimeTable(data{i});
                    end
                end
            end
        end

        function featureVec = extractStatisticsFeaturesVec(data)
            % extractStatisticsFeatures computes statistical features for each column of data.
            % Input:
            %   data - matrix (rows: samples, columns: features)
            % Output:
            %   features - structure with fields: mean, rms, std, peak, skewness, kurtosis
            %              each is a row vector (1 x num_channel x num_features)
            featureVec = [mean(data, 1), rms(data, 1), std(data, 0, 1), max(abs(data), [], 1), mad(data, 1, 1)];
        end

        function featureMatrix = extractStatisticsFeaturesCell(dataCell)
            numSamples = numel(dataCell);
            numStats = 5;
            numChannels = size(dataCell{1}, 2);
            featureMatrix = zeros(numSamples, numChannels*numStats);
            for i = 1:numSamples
                featureMatrix(i,:) = anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.extractStatisticsFeaturesVec(dataCell{i});
            end
        end

        function featureMatrix = extractStatisticsFeaturesArray3D(dataArray3D)
            % Vectorized feature extraction on a 3D array
            % Input:
            %   dataArray3D - (windowLength x numChannels x numWindows)
            % Output:
            %   featureMatrix - (numWindows x numChannels*5)
            numWindows = size(dataArray3D, 3);
            numChannels = size(dataArray3D, 2);
            m = reshape(mean(dataArray3D, 1), numChannels, numWindows)';
            r = reshape(rms(dataArray3D, 1), numChannels, numWindows)';
            s = reshape(std(dataArray3D, 0, 1), numChannels, numWindows)';
            pk = reshape(max(abs(dataArray3D), [], 1), numChannels, numWindows)';
            md = reshape(mad(dataArray3D, 1, 1), numChannels, numWindows)';
            featureMatrix = [m, r, s, pk, md];
        end

        function [center,scaling] = getNormalizationParameters(dataCell, normalizationMethod)
            % Compute normalization parameters incrementally without
            % concatenating all data into a single array.
            numChannels = size(dataCell{1}, 2);
            switch normalizationMethod
                case "zscore"
                    totalN = 0;
                    sumX = zeros(1, numChannels, 'like', dataCell{1}(1,:));
                    sumX2 = zeros(1, numChannels, 'like', dataCell{1}(1,:));
                    for i = 1:numel(dataCell)
                        n = size(dataCell{i}, 1);
                        totalN = totalN + n;
                        sumX = sumX + sum(dataCell{i}, 1);
                        sumX2 = sumX2 + sum(dataCell{i}.^2, 1);
                    end
                    center = sumX / totalN;
                    scaling = sqrt(sumX2/(totalN-1) - (sumX.^2)/(totalN*(totalN-1)));
                case "range"
                    minVal = inf(1, numChannels, 'like', dataCell{1}(1,:));
                    maxVal = -inf(1, numChannels, 'like', dataCell{1}(1,:));
                    for i = 1:numel(dataCell)
                        minVal = min(minVal, min(dataCell{i}, [], 1));
                        maxVal = max(maxVal, max(dataCell{i}, [], 1));
                    end
                    center = minVal;
                    scaling = maxVal - minVal;
                otherwise
                    allData = cat(1, dataCell{:});
                    [~, center, scaling] = normalize(allData, 1, normalizationMethod);
            end
            center = gather(center);
            scaling = gather(scaling);
        end

        function normalizedDataCell = normalizeData(dataCellProcessed, dataCenter, dataScale)
            % Normalize the whole data using data center and scale obtained
            % from training data
            normalizedDataCell = cellfun(@(cellData) normalize(cellData, "center",  dataCenter, "scale", dataScale), ...
                dataCellProcessed, 'UniformOutput', false);
        end

        function validateTrained(isTrained)
            % Validate if the detector is trained.
            coder.internal.assert(isTrained, "predmaint_anomaly:anomaly:errNotTrained");
        end

        function validateInputData(data, numChannels, windowLength, stride)
            % Validate input data.
            coder.internal.prefer_const(numChannels,windowLength,stride);
            validateNumericData = @anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateNumericData;
            validateTimetableData = @anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateTimetableData;
            validateattributes(data, {'gpuArray', 'numeric', 'timetable', 'cell'}, {'nonempty'}, '', 'Input data');

            if isnumeric(data) % Includes numeric gpuArray.
                validateNumericData(data,numChannels, windowLength, stride); % A single matrix.
            elseif istimetable(data)
                validateTimetableData(data, numChannels, windowLength, stride);
            elseif iscell(data)
                validateattributes(data, {'cell'}, {'vector','nonempty'}, '', 'Input data');
                isNumericData = isnumeric(data{1});
                isTimeTableData = istimetable(data{1});
                coder.internal.assert(isNumericData || isTimeTableData, ...
                    "predmaint_anomaly:anomaly:errInvalidCellElement");
                if isNumericData
                    % Cell array of matrices.
                    cellfun(@(X)coder.internal.assert(isnumeric(X), "predmaint_anomaly:anomaly:errInvalidCellElement"), data);
                    cellfun(@(X)validateNumericData(X, numChannels, windowLength, stride), data);
                else
                    cellfun(@(X)coder.internal.assert(istimetable(X), "predmaint_anomaly:anomaly:errInvalidCellElement"), data);
                    varnames = extractVarNamesFromTimeTable(data{1});
                    cellfun(@(tt)coder.internal.assert(isequal(varnames, extractVarNamesFromTimeTable(tt)),...
                        "predmaint_anomaly:anomaly:errInconsistentColNames"), data);
                    cellfun(@(tt)validateTimetableData(tt, numChannels, windowLength, stride), data);
                end
            end
        end

        function validateTimetableData(T, numChannels, windowLength, stride)
            % Validate if the timetable data contains supported numeric data.
            coder.internal.prefer_const(numChannels, windowLength, stride);
            validateNumericData = @anomalyCLI.internal.utils.TimeSeriesAnomalyProcessing.validateNumericData;

            validateattributes(T, {'timetable'}, {'nonempty'}, '', 'Input data');
            coder.internal.assert(issorted(T), "predmaint_anomaly:anomaly:errUnsortedTT"); % Ascending.
            coder.internal.assert(isregular(T), "predmaint_anomaly:anomaly:errUniformTT"); % Uniformly-sampled.
            D = extractFromTimeTable(T);
            validateNumericData(D, numChannels, windowLength, stride);
        end

        function validateNumericData(X, numChannels, windowLength, stride)
            % Validate if the numeric data is a 2-D double or
            % single-precision array on CPU or GPU memory.
            coder.internal.prefer_const(numChannels, windowLength, stride);
            mustBeUnderlyingType(X, {'single', 'double'}); % Allows gpuArray.
            validateattributes(X, {'single', 'double', 'gpuArray'}, {'2d', 'nonempty', 'real', 'nonsparse','nonnan','finite'}, '', 'Input data');

            % Check consistency of each data matrix.
            [nr,nc] = size(X);
            coder.internal.assert(numChannels == nc, "predmaint_anomaly:anomaly:errNumChannels", numChannels);
            coder.internal.assert(windowLength <= nr, "predmaint_anomaly:anomaly:errMaxWindowLength", nr);
            coder.internal.assert(stride <= nr, "predmaint_anomaly:anomaly:errMaxStrideLength", nr);
        end
    end
end

%% Helper functions
function [out,varnames] = extractFromTimeTable(data)
    isInMATLAB = isempty(coder.target);
    if isInMATLAB
        % Extract single- or double-precision variables only.
        I = cellfun(@(var) isUnderlyingType(data.(var),'double') || isUnderlyingType(data.(var),'single'), data.Properties.VariableNames);
        data = data(:,I);
        varnames = string(data.Properties.VariableNames);
        out = data{:,:};
    else
        k = coder.internal.indexInt(0);
        idx = zeros(1,size(data,2),coder.internal.indexIntClass);
        coder.unroll();
        for i = coder.internal.indexInt(1):size(data,2)
            if(isfloat(data{:,i}))
                k = k + 1;
                idx(k) = coder.const(i);
            end
        end
        idx2 = coder.const(idx(1:k));
        out = data{:,idx2};
        allNames = data.Properties.VariableNames;
        varnames = {allNames{idx2}}; % Note this is a cell array of char vectors
    end
end

function varnames = extractVarNamesFromTimeTable(tt)
    [~,varnames] = extractFromTimeTable(tt);
end

function varnames = formVarNamesforNumericData(numChannels)
    % varnames is a string array in MATLAB Simulation and cell array of character
    % vectors in code generation.
    coder.internal.prefer_const(numChannels)
    id = "predmaint_anomaly:anomaly:strChannel";
    if isempty(coder.target)
        str = string(message(id));
        varnames = str + " " + (1:numChannels);
    else
        str = 'Channel';
        varnames = cell(1,numChannels);
        coder.unroll;
        for i = 1:numChannels
            varnames{i} = [str ' ' coder.const(@feval, 'num2str', i)];
        end
    end
end
