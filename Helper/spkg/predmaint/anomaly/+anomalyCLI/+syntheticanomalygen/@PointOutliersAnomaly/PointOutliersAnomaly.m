classdef PointOutliersAnomaly < anomalyCLI.syntheticanomalygen.AbstractAnomaly
% PointOutliersAnomaly class defines the PointOutliers anomaly type and
% handles the injection of the anomaly into the specified time series.

%   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Define the number of point outliers
        NumOutliers {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger} = 10
        % Define the scale of the outliers
        Scale {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 3
    end

    methods
        function obj = PointOutliersAnomaly(NameValueArgs)
            arguments
                NameValueArgs.NumOutliers {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger} = 10;
                NameValueArgs.Scale {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive} = 3;
            end

            obj.NumOutliers = NameValueArgs.NumOutliers;
            obj.Scale = NameValueArgs.Scale;
        end
    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, inTS, windowStart, windowEnd, ~, labels)

            winSegment = inTS(windowStart:windowEnd);
            sigma = std(winSegment);

            % Generate unique random indices for outliers within the window
            windowLength = windowEnd - windowStart + 1;
            if obj.NumOutliers > windowLength
                error(message("predmaint_anomaly:anomaly:errTooManyOutliers"))
            end
            perm = randperm(windowLength, obj.NumOutliers);
            outlier_indices = windowStart - 1 + perm;

            % Inject anomalies at mean +/- Scale*sigma (random sign)
            signs = randi([0,1], obj.NumOutliers, 1)*2 - 1; % +/-1

            % Inject outliers by adding random noise of specified magnitude
            outTS(outlier_indices) = outTS(outlier_indices) + signs*obj.Scale*sigma;
            % Create label vector
            labels(outlier_indices) = true;
        end
    end
end
