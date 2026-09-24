function outTS = edgeContinuity(outTS, rampLen, SequenceStart, SequenceEnd, method)
%EDGECONTINUITY Smooths only inside the anomalous window using the specified ramp length.
%   The normal data outside the window remains untouched.
%
%   outTS         : time series vector (double/single). Contains anomaly already injected in the window [SequenceStart:SequenceEnd].
%   SequenceStart : start index of anomaly window (inclusive).
%   SequenceEnd   : End index of anomaly window end (inclusive).
%   rampLen       : desired number of samples for both ramp-in and ramp-out (>=0).
%                   If omitted or empty, a default is computed based on window length.
%   method        : 'linear' | 'cosine' (default: 'cosine').
%
%   Behavior:
%   - Blends the first rampLen samples inside the window from the last normal sample
%     to the anomaly values (ramp-in).
%   - Blends the last rampLen samples inside the window from the anomaly values
%     to the next normal sample (ramp-out).
%   - Ensures the effective ramp length fits within the window (<= floor(windowLen/2)).
%   - If the window touches the start/end of the series, the corresponding ramp is skipped.
%
%   Copyright 2025-2026 The MathWorks, Inc.

    arguments
        outTS (:,1) {mustBeNumeric}
        rampLen (1,1) {mustBeNonnegative, mustBeInteger}
        SequenceStart (1,1) {mustBeInteger, mustBePositive}
        SequenceEnd (1,1) {mustBeInteger, mustBePositive}        
        method (1,1) string {mustBeMember(method, ["linear","cosine"])} = "cosine"
    end

    
    % Window indices and length
    winIdx = SequenceStart:SequenceEnd;
    winLen = numel(winIdx);

    % ---- Ensure ramp fits within the window ----
    % We cannot ramp more than half the window (so core anomaly remains).
    maxRamp = floor(winLen / 2);
    effRamp = min(rampLen, maxRamp);

    % If window length is 1, effRamp becomes 0.
    if effRamp == 0
        % Nothing to do; window too short to ramp.
        return;
    end

    % Ensure that winSegment is always a row vector
    winSegment = reshape(outTS(winIdx), 1, []);

    % Ramp-in
    % If no previous normal sample available prior to window start, then skip ramp-in
    if SequenceStart > 1
        prevVal = outTS(SequenceStart - 1);
        w = localTaper(effRamp, method, "up");  % 0 -> 1
        % Blend first effRamp samples toward original anomaly, starting from prevVal
        winSegment(1:effRamp) = (1 - w) .* prevVal + w .* winSegment(1:effRamp);
    end

    % Ramp-out 
    % If no next normal sample available after window end, then skip ramp-out
    n = length(outTS);

    if SequenceEnd < n
        nextVal = outTS(SequenceEnd + 1);
        w = localTaper(effRamp, method, "up");  % 0 -> 1
        tailIdx = winLen - effRamp + 1 : winLen;
        % Blend last effRamp samples from anomaly to nextVal
        winSegment(tailIdx) = (1 - w) .* winSegment(tailIdx) + w .* nextVal;        
    end

    % Write back only inside the window
    outTS(winIdx) = winSegment;
end

% helper to produce tapers within the window
function w = localTaper(L, method, direction)
% Returns a row vector of length L:
% direction "up":   0 -> 1
% direction "down": 1 -> 0
    switch method
        case "linear"
            w = linspace(0,1,L);
        case "cosine"
            % Half cosine ramp (smoother endpoints than linear)
            t = linspace(0,1,L);
            w = 0.5 - 0.5*cos(pi*t); % 0 -> 1
    end
    if direction == "down"
        w = fliplr(w);
    end
end
