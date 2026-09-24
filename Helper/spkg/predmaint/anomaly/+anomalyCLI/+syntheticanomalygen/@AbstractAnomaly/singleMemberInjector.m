function [outTS_, labelVariable] = singleMemberInjector(obj, inTS_, columnNumber, variableName_, windowStart, windowLength, edgeContinuity, transitionLength, labelAggregation)
% SINGLEMEMBERINJECTOR injects the specified types and number of anomalies
% into each member of the specified timeseries. It implements the logic to
% make windowStart and windowLength to be of the same length. The outputs
% of this function includes the timeseries with the anomaly injections and
% the labels with the selected aggregation logic.

%   Copyright 2025-2026 The MathWorks, Inc.

if isnumeric(inTS_) %if matrix
    % If more than one column is specified then generate an
    % error
    if size(inTS_, 2) > 1
        inTS_ = inTS_(:,columnNumber);
    end
elseif istimetable(inTS_) % if timetable, pick up the specified variableName
    if size(inTS_, 2) > 1 && isempty(variableName_)
        error(message("predmaint_anomaly:anomaly:errMultipleVariablesTT"))
    end

    try
        inTS_ = inTS_.(variableName_);
    catch
        error(message("predmaint_anomaly:anomaly:errAccessTTVariable"))
    end
else    
    error(message("predmaint_anomaly:anomaly:errInputDatatype"))
end

% Compute all the WindowStart and WindowLengths to be used for
% injecting the different anomalies into the selected univariate time
% series in inTS_
[windowStart_, windowLength_] = processWindowParams(windowStart, windowLength, length(inTS_), 10, numel(obj));

% Insert anomalies into the data
[outTS_, labelVariable] = localSingleMemberInjector(obj, inTS_, windowStart_, windowLength_, edgeContinuity, transitionLength, labelAggregation);

end

function [outTS_, labelVariable] = localSingleMemberInjector(obj, inTS_, windowStart_, windowLength_, edgeContinuity, transitionLength, labelAggregation)
% LOCALSINGLEMEMBERINJECTOR injects the specified number and types of
% anomalies into a single timeseries (member). It accepts a scalar or array
% of anomaly types, single member timeseries, scalar or array of
% WindowStart, WindowLength, and EdgeContinuity and TransitionLength
% parameters to then call the injectAnomaly_() method of the anomaly type
% object the required number of times. After injection of the anomaly type,
% this function manages EdgeContinuity and label vector aggregation for the
% input time series member.

outTS_ = inTS_;
labelVariable_ = false(size(inTS_,1), numel(obj));
if numel(obj) > 1
    for iAnomaly = 1:numel(obj)
        anomalyType_ = obj(iAnomaly);

        windowLength = windowLength_(iAnomaly);
        windowStart = windowStart_(iAnomaly);

        [outTS_, labelVariable_(:,iAnomaly)] = anomalyType_.injectAnomaly_(outTS_, windowStart, windowLength, edgeContinuity, transitionLength);

        if ~labelAggregation
            labelVariableName(iAnomaly) = strrep(class(anomalyType_), "anomalyCLI.syntheticanomalygen.", ""); %#ok<AGROW>
        end
    end
else
    [outTS_, labelVariable_] = obj.injectAnomaly_(outTS_, windowStart_, windowLength_, edgeContinuity, transitionLength);

    if ~labelAggregation
        labelVariableName = strrep(class(obj), "anomalyCLI.syntheticanomalygen.", "");
    end
end

if labelAggregation
    labelVariable = any(labelVariable_,2);
else
    labelVariable = array2table(labelVariable_, "VariableNames", matlab.lang.makeUniqueStrings(labelVariableName));
end
end

function [windowStart_, windowLength_] = processWindowParams(windowStart, windowLength, inTS_Length, defaultWindowLength, numObjs)
% ProcessWindowParams function accepts the different combinations of
% WindowStart, WindowLength, the length of the time series and the number
% of anomaly types being injected to create the required WindowStart_ and
% WindowLength_ vectors that can be used by downstream functions. It
% ensures that the output window parameters are the correct length and are
% equal in length to each other.


% Ensure that length of WindowStart and WindowLength are the same
% If WindowStart is scalar and WindowLength is vector, then expand
% WindowStart to have the same length as WindowLength. All expanded
% values of WindowStart will be "random". Ensure that scalar
% WindowStart is random.

% If WindowLength is scalar and WindowStart is vector, then expand
% Window WindowLength to have the same length as WindowStart. All
% expanded values of WindowLength will be default of 10

if isscalar(windowStart) && isscalar(windowLength) && numObjs > 1
    windowStart = repmat(windowStart, [1,numObjs]);
    windowLength = repmat(windowLength, [1,numObjs]);
end


if (numel(windowStart) < numel(windowLength))
    if ~strcmpi(windowStart, "random")
        error(message("predmaint_anomaly:anomaly:errStringStartForVectorLength"))
    end
    windowStart = repmat("random", size(windowLength));
elseif numel(windowLength) < numel(windowStart)
    windowLength = [windowLength, repmat(defaultWindowLength, [1, numel(windowStart)-1])];
end

% Process WindowStart to find all "random" and then replace
windowStart_ = zeros(1, numel(windowStart));
for iStart = 1:numel(windowStart)
    if strcmpi(windowStart(iStart), "random")
        if isnumeric(windowLength(iStart))
            maxStart = inTS_Length - windowLength(iStart) + 1;
            if maxStart < 1
                error(message("predmaint_anomaly:anomaly:errSignalTooShort", string(windowLength(iStart))))
            end
            windowStart_(iStart) = randi([1, maxStart]);
        else
            maxStart = inTS_Length - defaultWindowLength*2;
            if maxStart < 1
                error(message("predmaint_anomaly:anomaly:errSignalTooShort", string(defaultWindowLength*2)))
            end
            windowStart_(iStart) = randi([1, maxStart]);
        end
    else
        windowStart_(iStart) = windowStart(iStart);
    end
end

windowLength_ = zeros(1, numel(windowLength));
for iLength = 1:numel(windowLength)
    if strcmpi(windowLength(iLength), "end")
        windowLength_(iLength) = inTS_Length - windowStart_(iLength)+1;
    else
        windowLength_(iLength) = windowLength(iLength);
    end
end

end

% LocalWords:  TT LOCALSINGLEMEMBERINJECTOR Windowlengths windowsize
