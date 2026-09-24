classdef AbstractAnomaly < matlab.mixin.Heterogeneous & matlab.mixin.CustomDisplay

    methods (Abstract, Access=protected)
        % Subclasses implement per-window transformation only.
        % outTS/labels are modified in-place for the single window defined
        % by windowStart..windowEnd (length = windowLength).
        % Both the cumulative outTS and original inTS are provided so
        % subclasses can choose their overlap semantics.
        [outTS, labels] = applyAnomaly_(obj, outTS, inTS, windowStart, windowEnd, windowLength, labels);
    end

    methods (Sealed, Access=protected)
        function [outTS, labels] = injectAnomaly_(obj, inTS, windowStart, windowLength, edgeContinuity, transitionLength)
            % Centralized injection loop - handles iteration over windows,
            % label bookkeeping, and edge continuity so that subclasses
            % only implement applyAnomaly_ for a single window.
            outTS = inTS;
            labels = false(size(inTS));
            for numInj = 1:numel(windowStart)
                wLen   = windowLength(numInj);
                wStart = windowStart(numInj);
                wEnd   = wStart + wLen - 1;

                [outTS, labels] = applyAnomaly_(obj, outTS, inTS, wStart, wEnd, wLen, labels);

                if edgeContinuity
                    outTS = anomalyCLI.syntheticanomalygen.utils.edgeContinuity(outTS, transitionLength, wStart, wEnd);
                end
            end
        end
    end

    methods(Sealed)        
        function [outTS, labelsOut] = injectAnomaly(obj, inTS, NameValueArgs)
            % INJECTANOMALY injects the anomaly defined by AnomalyType
            % input into a univariate timeseries specified by inTS input.
            %
            % Description:
            %   INJECTANOMALY allows the injection of specified anomaly at
            %   the chosen location and length into a time series. This
            %   enables the creation of a labeled time series dataset with
            %   subWindow anomalies. Having these labeled anomalous dataset
            %   will alleviate the data imbalance issues encountered during
            %   the development of robust anomaly detection models.
            %
            % Input argument:
            %   AnomalyType              - NoiseAnomaly, DriftAnomaly, BiasAnomaly,
            %                              PointOutliersAnomaly, WarpingAnomaly,
            %                              StuckAtConstantAnomaly
            %
            % Input Name-Value pairs:
            %   inTS                    - Input time series specified as either a
            %                             column vector or a timetable
            %
            %   WindowStart             - Sample index to start injection of anomaly.
            %
            %   WindowLength            - Sample Length for introducing the anomaly.
            %
            %   EdgeContinuity          - Specify edge smoothing on either side of
            %                             introduced anomaly.
            %
            %   TransitionLength        - Sample length for edge smoothing on either
            %                             side of introduced anomaly.
            %
            %   LabelAggregation        - Specify true or false
            %
            %   UseParallel             - Specify "auto", "on" or "off".
            %
            %  Output Argument:
            %
            %   outTS                   - Time series with specified anomalous
            %                             injected. The input datatype is preserved. 
            % 
            %   labels                  - By default, is the aggregated
            %                             sample level label vector that is
            %                             1 for all samples that have any
            %                             anomaly injected and 0 for the
            %                             rest. If LabelAggregation is set
            %                             to false, this is a
            %                             multi-variable table where each
            %                             variable is the label for a
            %                             anomaly type injected.
            %
            %  Examples:
            %
            %  nAnomaly = syntheticAnomaly("Noise");
            %  outTS = injectAnomaly(nAnomaly, inTS, "WindowStart", 100);
            %
            %
            % See also syntheticAnomaly, tcnAD, vaelstmAD, deepantAD, usAD, deepSignalAnomalyDetector, lof, ocsvm.


            % Copyright 2025-2026 The MathWorks, Inc.

            arguments
                obj anomalyCLI.syntheticanomalygen.AbstractAnomaly
                inTS {validateInputTS}
                NameValueArgs.WindowLength (1,:) {validateWindowLength} = 10;
                NameValueArgs.WindowStart (1,:) {validateWindowStart} = "Random";
                NameValueArgs.VariableName (1,1) string = strings;
                NameValueArgs.EdgeContinuity (1,1) {mustBeA(NameValueArgs.EdgeContinuity, 'logical')} = false;
                NameValueArgs.TransitionLength (1,1) {mustBeInteger, mustBePositive} = 5;                
                NameValueArgs.ColumnNumber (1,1) {mustBeNumeric} = 1;
                NameValueArgs.LabelAggregation (1,1) {mustBeA(NameValueArgs.LabelAggregation, 'logical')} = true;
                NameValueArgs.UseParallel (1,1) {matlab.internal.parallel.validateUseParallelOption} = "off";
            end

            
            % Check if input is cell array, that all elements are homogeneous
            if iscell(inTS)

                % Get the class of each element in the cell array
                membertypes = cellfun(@class, inTS, 'UniformOutput', false);

                % Check if all elements have the same type
                if numel(unique(membertypes)) ~= 1
                    error(message("predmaint_anomaly:anomaly:errHeterogenousCellArray"))
                end

                % If members are numeric, then process them to ensure that
                % they are all column vectors
                if unique(membertypes) == "double"
                    inTS = cellfun(@(x) x(:), inTS, 'UniformOutput', false);
                end

                % Validate WindowLength and WindowStart
                cellfun(@(x)validateWindowLengthandStart(numel(obj), NameValueArgs.WindowLength, NameValueArgs.WindowStart, size(x,1)), inTS);
                inTS_cell = inTS;
            else % if the input is not cell array, then create a cell array
                % to enable consistent processing

                % if input is a row vector, then make it a column vector
                if ~istimetable(inTS)
                    inTS = inTS(:);
                end

                % Validate WindowLength and WindowStart
                validateWindowLengthandStart(numel(obj), NameValueArgs.WindowLength, NameValueArgs.WindowStart, size(inTS,1))

                inTS_cell{1} = inTS;
            end

            % Check if the input is a timetable, then pick the appropriate
            % variable name to introduce the anomalies
            if istimetable(inTS_cell{1})
                isTT = 1;
                if NameValueArgs.VariableName == ""
                    variableName_ = inTS_cell{1}.Properties.VariableNames{1};
                else
                    variableName_ = NameValueArgs.VariableName;
                end
            else
                isTT = 0;
                variableName_ = "";
            end

            % For each member of the cell array, introduce the anomaly
            % types defined in the obj vector. If UseParallel is true, use
            % parfor.
            pool = matlab.internal.parallel.resolveUseParallel(NameValueArgs.UseParallel);

            if isempty(pool)
                [outTS, labelsOut] = serialImplementation(obj, inTS_cell, NameValueArgs, variableName_, isTT);
            else % If UseParallel is false
                [outTS, labelsOut] = parallelImplementation(obj, pool, inTS_cell, NameValueArgs, variableName_, isTT);
            end

            % Convert the output format to be consistent with input format
            if ~iscell(inTS)
                outTS = outTS{1};
                labelsOut = labelsOut{1};
            end
        end
    end

    methods(Sealed, Access=private)
        function [outTS, labelsOut] = parallelImplementation(obj, pool, inTS_cell, NameValueArgs, variableName_, isTT)
            nMembers = numel(inTS_cell);
            outTS = cell(size(inTS_cell));
            labelsOut = cell(size(inTS_cell));
            % Add attached files before the parfor loop
            addAttachedFiles(pool, {'singleMemberInjector.m'});
            parfor (nC = 1:nMembers, pool)
                % For each member of the input cell array, inject all
                % the specified anomalies
                inTS_ = inTS_cell{nC};
                [outTS{nC}, labelsOut{nC}] = singleMemberWrapper(obj, inTS_, NameValueArgs, variableName_, isTT);
            end
        end

        function [outTS, labelsOut] = serialImplementation(obj, inTS_cell, NameValueArgs, variableName_, isTT)
            % For each member of the cell array
            outTS = inTS_cell;
            labelsOut = cell(size(inTS_cell));
            for nC = 1:numel(inTS_cell)
                inTS_ = inTS_cell{nC};
                [outTS{nC}, labelsOut{nC}] = singleMemberWrapper(obj, inTS_, NameValueArgs, variableName_, isTT);
            end
        end

        function [outTS, labelsOut] = singleMemberWrapper(obj, inTS_, NameValueArgs, variableName_, isTT)
            outTS = inTS_;
            % Inject all the specified anomalies into each member
            [outTS_Adjusted, labelsOut]  = ...
                singleMemberInjector(obj, inTS_, ...
                NameValueArgs.ColumnNumber, variableName_, ...
                NameValueArgs.WindowStart, ...
                NameValueArgs.WindowLength, ...
                NameValueArgs.EdgeContinuity, ...
                NameValueArgs.TransitionLength, ...
                NameValueArgs.LabelAggregation);

            % Append the results into the output data
            if isTT                
                outTS.(variableName_) = outTS_Adjusted;
            else
                outTS(:, NameValueArgs.ColumnNumber) = outTS_Adjusted;
            end
        end

        [outTS_Adjusted, labelVariable] = singleMemberInjector(obj, ...
            inTS_, ColumnNumber, VariableName_, WindowStart,...
            WindowLength, EdgeContinuity, TransitionLength, LabelAggregation)
    end

    methods(Sealed, Access = protected)        
        % Control the display of a Heterogeneous array of SyntheticAnomaly objects
        function displayNonScalarObject(obj)
            dimStr = matlab.mixin.CustomDisplay.convertDimensionsToString(obj);
            cName = "AnomalyTypes";
            headerStr = [dimStr, cName,':'];
            header = sprintf('%s %s%s\n',headerStr);
            disp(header);
            numStr = [];
            for iAType = 1:length(obj)
                anomalyObj = obj(iAType);

                numStr = [numStr, ', ', strrep(class(anomalyObj), 'anomalyCLI.syntheticanomalygen.', '')];
            end
            disp(numStr(2:end));            
        end
    end
end

function validateWindowLength(windowLength)
% WindowLength -> data type, value ranges (positive only,
% if WindowLength is larger than the timeseries length then
% we will use end instead;

% check if it is a string. If it is a string, it can only be
% 'end'
if isstring(windowLength) || ischar(windowLength)
    if ~strcmpi(windowLength, "end")
        error(message("predmaint_anomaly:anomaly:errWindowStringValue", "WindowLength", "end"))
    end
else %if isnumeric(WindowLength)
    validateattributes(windowLength, {'numeric'}, {'positive', 'nonnan', 'integer', 'size', [1,NaN]})
end
end

function validateWindowStart(windowStart)
% check if it is a string. If it is a string, it can only be
% 'end'
if isstring(windowStart) || ischar(windowStart)
    if ~strcmpi(windowStart, "random")
        error(message("predmaint_anomaly:anomaly:errWindowStringValue", "WindowStart", "Random"))
    end
else %if isnumeric(WindowStart)
    validateattributes(windowStart, {'numeric'}, {'positive', 'nonnan', 'integer', 'size', [1,NaN]})
end
end

function validateWindowLengthandStart(numAnomalyTypes, windowLength, windowStart, signalLength)
% If multiple anomaly types are specified, then the numel of WindowLength
% has to be one or equal to the number of objects. If a single anomaly type
% is specified and WindowLength is a vector, then WindowStart needs to be
% checked to see if its a vector of the same size or a scalar.

if (numAnomalyTypes> 1) && ((numel(windowLength) > 1) || (numel(windowStart) > 1)) && (max(numel(windowLength), numel(windowStart)) ~= numAnomalyTypes)
    error(message("predmaint_anomaly:anomaly:errMultipleAnomalyWindowParams"))
elseif (numel(windowLength) ~= numel(windowStart)) && numel(windowStart) > 1 && numel(windowLength) > 1
    error(message("predmaint_anomaly:anomaly:errMultipleWindowParams"))
end

if isnumeric(windowStart) && any(windowStart > signalLength)
    error(message("predmaint_anomaly:anomaly:errWindowParamTooLarge", "WindowStart"))
end

if isnumeric(windowLength) && any(windowLength > signalLength)
    error(message("predmaint_anomaly:anomaly:errWindowParamTooLarge", "WindowLength"))
end

if isnumeric(windowStart) && isnumeric(windowLength) && any(windowStart + windowLength - 1 > signalLength)
    error(message("predmaint_anomaly:anomaly:errWindowParamTooLarge", "WindowStart + WindowLength"))
end
end


% Helper - validator

function validateInputTS(inTS)
%VALIDATEINPUTTS Ensures input is:
%   - a numeric row/column vector, OR
%   - a timetable with numeric variables only, OR
%   - a cell array containing only the above types.
%
% Throws descriptive errors if the input is invalid.

    if iscell(inTS)
        % Optional: disallow empty cell arrays (comment out if you want to allow)
        if isempty(inTS)
            error(message("predmaint_anomaly:anomaly:errInvalidCellInput"));
        end

        for k = 1:numel(inTS)
            e = inTS{k};
            if isnumeric(e)
                validateattributes(e, {'double','single'}, {'vector','real'});
            elseif istimetable(e)
                validateTimetableNumericVarsOnly(e);
            else
                error(message("predmaint_anomaly:anomaly:errHeterogenousCellInput"));
            end
        end

    elseif isnumeric(inTS)
        validateattributes(inTS, {'double','single'}, {'vector','real'});

    elseif istimetable(inTS)
        validateTimetableNumericVarsOnly(inTS);

    else
        error(message("predmaint_anomaly:anomaly:errInvalidInput"));
    end
end


% Helper - validator 
function validateTimetableNumericVarsOnly(tt)
% Ensures:
%   - tt is a timetable
%   - tt is non-empty (has at least one row)
%   - tt has at least one variable
%   - ALL variables are numeric (no chars/strings/categoricals/cells, etc.)

    if ~istimetable(tt)
        error(message("predmaint_anomaly:anomaly:errInvalidInput"));
    end

    if height(tt) == 0
        error(message("predmaint_anomaly:anomaly:errInvalidInput"));
    end

    if width(tt) == 0
        error(message("predmaint_anomaly:anomaly:errInvalidInput"));
    end

    % Check that every variable in the timetable is numeric.
    % varfun applies a function to each variable; OutputFormat 'uniform' returns a logical vector.
    areNumeric = varfun(@(v) isnumeric(v), tt, 'OutputFormat', 'uniform');
    if ~all(areNumeric)
        % Identify offending variable names for a precise error message         
        error(message("predmaint_anomaly:anomaly:errInvalidTTInput")); 
    end
end


% LocalWords:  INJECTANOMALY
