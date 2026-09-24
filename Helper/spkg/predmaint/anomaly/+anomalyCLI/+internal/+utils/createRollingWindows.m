function [windowData, numWindows, startIdx] = createRollingWindows(data, windowLength, stride, options)
% createRollingWindows - Generate rolling windows from a signal observation.
%
% This function generates a series of rolling windows from the input data.
% Each window is of a specified length and moves along the data with a 
% specified stride, allowing for overlapping windows. The number of windows
% is computed based on the length of the data, the window length, and the
% stride. If the data cannot be segmented by given windowLenth and stride,
% the last too-short window will be discard.
%
% Syntax:
%   [windowData, numWindows, startIdx] = createRollingWindows(data, windowLength, stride, options)
%
% Inputs:
%   data        - The input data from which rolling windows are to be created.
%                 It should be a vector or matrix where rows represent observations.
%   windowLength - The length of each rolling window.
%   stride      - The number of samples to move the starting point of each window
%                 forward. Default is 1, meaning windows are created with maximum overlap.
%   options     - A structure containing optional parameters:
%                 NumWindows - The number of windows to create. If not specified,
%                               it defaults to the maximum possible number of windows
%                               given the data length, window length, and stride.
%
% Outputs:
%   windowData  - A cell array containing the rolling windows. Each cell contains
%                 a matrix representing one window of data.
%   numWindows  - The total number of windows created.
%   startIdx    - A vector containing the starting index of each window in the original data.

%   Copyright 2024 The MathWorks, Inc.

arguments
    data
    windowLength
    stride = 1
    options.NumWindows = floor((size(data,1) - windowLength)/stride) + 1
end

numWindows = options.NumWindows;


windowData = cell(numWindows, 1);
startIdx = zeros(numWindows, 1);
if numWindows ~= 0
for i = 1:numWindows
    startIdx(i) = 1 + (i-1) * stride;
    windowData{i} = data(startIdx(i):startIdx(i) + windowLength - 1,:);
end
end
end
