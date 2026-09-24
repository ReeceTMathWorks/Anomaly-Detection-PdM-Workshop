function [sampleLabels,sampleScores, sampleIdx] = windowLabelsToSampleLabels(windowLabels, windowLength, winStartIdx, options)
% windowLabelsToSampleLabels Convert window-level labels to sample-level labels
%
% This function converts window-level anomaly labels to sample-level labels using
% different methods to resolve overlapping windows.
%
% Inputs:
%   windowLabels - Logical vector of window-level anomaly labels (true = anomaly)
%   windowLength - Length of each window in samples
%   winStartIdx  - Starting indices of each window in the original data
%   options      - Name-value options:
%    Method     - Method to resolve overlapping windows:
%                   "anomalyPriority" - If any window covering a sample is anomalous,
%                                      the sample is labeled as anomalous (default)
%                   "normalPriority"  - If any window covering a sample is normal,
%                                      the sample is labeled as normal
%                   "majorityVoting"  - Label is determined by majority vote of
%                                      overlapping windows (anomaly wins ties)
%    WinScores  - Optional scores for each window (used for sample scores)
%    DataLength - Optional length of the original data (default: computed from inputs)
%
% Outputs:
%   sampleLabels - Logical vector of sample-level anomaly labels
%   sampleScores - Numeric vector of sample-level scores
%   sampleIdx    - Vector of sample indices (1:numSamples)
%
% Algorithm Details:
%   anomalyPriority:
%     - Each sample inherits the label of the last window that covers it
%     - If any window covering a sample is anomalous, the sample is labeled as anomalous
%     - Scores are assigned from maximum window scores
%
%   normalPriority:
%     - Each sample inherits the inverted label of the last window that covers it
%     - If any window covering a sample is normal, the sample is labeled as normal
%     - Scores are assigned from minimum window scores
%
%   majorityVoting:
%     - Each sample's label is determined by majority vote of all windows covering it
%     - In case of a tie, the sample is labeled as anomalous
%     - Scores are calculated as the average of all window scores covering each sample
%#codegen

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    windowLabels (:,1) logical {mustBeNonNan}
    windowLength (1,1) {mustBeInteger, mustBePositive}
    winStartIdx (:,1) {mustBeInteger, mustBePositive}
    options.Method (1,1) string {mustBeMember(options.Method, {'majorityVoting','normalPriority','anomalyPriority'})} ="anomalyPriority";
    options.WinScores (:,1) double {mustBeNonNan}
    options.DataLength = []
end
coder.internal.prefer_const(windowLength,options);
numWindows = numel(windowLabels);
% Determine dataLength
if ~isempty(options.DataLength)
    numSamples = options.DataLength;
else
    numSamples = max(winStartIdx) + windowLength - 1;
end

sampleLabels = false(numSamples,1);
sampleScores = NaN(numSamples, 1);
sampleIdx = (1:numSamples)';

% Check if window scores are provided
hasScores = isfield(options, 'WinScores') && ~isempty(options.WinScores);

switch options.Method
    case "anomalyPriority"
        for w = 1:numWindows
            idx = winStartIdx(w)+(0:(windowLength-1));
            sampleLabels(idx) = sampleLabels(idx) | windowLabels(w);
            if hasScores
                % Sample score is the maximum scores across multiple
                % winScores if windows are overlapped
                sampleScores(idx) = max(sampleScores(idx), options.WinScores(w));
            end
        end

    case "normalPriority"
        coveredMask  = false(numSamples,1);    % tracks any coverage
        sampleLabels = true(numSamples,1);
        for w = 1:numWindows
            idx = winStartIdx(w)+(0:(windowLength-1));
            coveredMask(idx) = true;
            isNormalWin = ~windowLabels(w);
            if isNormalWin
                sampleLabels(idx) = false;  % If any normal window covers a sample, mark it as normal
            end
            if hasScores
                % Sample score is the minimum scores across multiple
                % winScores if windows are overlapped
                sampleScores(idx) = min(sampleScores(idx), options.WinScores(w));
            end
        end
        % set false for uncovered data points
        if nnz(coveredMask) ~= numel(coveredMask)
            sampleLabels(~coveredMask) = false;
        end

    case "majorityVoting"
        votes = zeros(numSamples, 1);      % For majority voting
        numVotes = zeros(numSamples, 1);  % Number of votes per sample
        scoreSum = zeros(numSamples, 1);   % For accumulating scores
        for w = 1:numWindows
            idx = winStartIdx(w)+(0:(windowLength-1));
            votes(idx) = votes(idx) + double(windowLabels(w)); % Accumulate anomaly votes
            numVotes(idx) = numVotes(idx) + 1;
            if hasScores
                scoreSum(idx) = scoreSum(idx) + options.WinScores(w);
            end
        end

        idxVoted = numVotes > 0;
        halfVotes = numVotes(idxVoted) / 2;
        sampleLabels(idxVoted) = votes(idxVoted) > halfVotes | ...
            (votes(idxVoted) == halfVotes & votes(idxVoted) > 0); % anomaly priority on tie

        % Calculate scores as the average of accumulated scores
        if hasScores
            sampleScores(idxVoted) = scoreSum(idxVoted) ./ numVotes(idxVoted);
        end
end

end
