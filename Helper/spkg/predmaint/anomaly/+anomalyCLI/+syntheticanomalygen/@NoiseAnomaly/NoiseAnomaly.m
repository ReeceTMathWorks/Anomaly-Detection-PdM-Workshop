classdef NoiseAnomaly < matlab.mixin.CustomDisplay & anomalyCLI.syntheticanomalygen.AbstractAnomaly
% NoiseAnomaly class defines the Noise anomaly type and
% handles the injection of the anomaly into the specified time series.

%   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % Parameters to define the distribution
        Mean (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite}
        Std (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBeNonnegative}
        % Noise distribution: Gaussian, Uniform, or Laplacian
        Distribution (1,1) string {mustBeMember(Distribution, ["Gaussian", "Uniform", "Laplacian"])} = "Gaussian"
        % Noise can be either FullWindow or Burst. FullWindow noise is
        % added to every sample in the window
        Type (1,1) string {mustBeMember(Type, ["FullWindow", "Burst"])} = "FullWindow"
        % Number of bursts to introduce in the given window
        NumBursts (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger} = 2
        % Length of each burst in samples
        BurstDuration (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger} = 5
    end

    methods
        function obj = NoiseAnomaly(NameValueArgs)
            arguments
                NameValueArgs.Mean (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite} = 0
                NameValueArgs.Std (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBeNonnegative} = 1
                NameValueArgs.Distribution (1,1) string {mustBeMember(NameValueArgs.Distribution, ["Gaussian", "Uniform", "Laplacian"])} = "Gaussian"
                NameValueArgs.Type (1,1) string {mustBeMember(NameValueArgs.Type, ["FullWindow", "Burst"])} = "FullWindow"
                NameValueArgs.NumBursts (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger}
                NameValueArgs.BurstDuration (1,1) {mustBeNumeric, mustBeNonNan, mustBeFinite, mustBePositive, mustBeInteger}
            end

            % Add check to error if Type is white and any Burst parameters
            % are specified
            if (NameValueArgs.Type == "FullWindow") && any([isfield(NameValueArgs, "NumBursts"), isfield(NameValueArgs, "BurstDuration")])
                error(message("predmaint_anomaly:anomaly:errBurstWithFullWindow"))
            end

            obj.Mean = NameValueArgs.Mean;
            obj.Std = NameValueArgs.Std;
            obj.Distribution = NameValueArgs.Distribution;
            obj.Type = NameValueArgs.Type;

            if  ~isfield(NameValueArgs, "NumBursts")
                obj.NumBursts = 2;
            else
                obj.NumBursts = NameValueArgs.NumBursts;
            end

            if ~isfield(NameValueArgs, "BurstDuration")
                obj.BurstDuration = 5;
            else
                obj.BurstDuration = NameValueArgs.BurstDuration;
            end
        end

    end

    methods(Access=protected)
        function [outTS, labels] = applyAnomaly_(obj, outTS, inTS, windowStart, windowEnd, windowLength, labels)

            if obj.Type == "FullWindow"
                noise = generateNoise(obj, windowLength);

                % Inject noise and create label vector
                outTS(windowStart:windowEnd) = inTS(windowStart:windowEnd) + noise;
                labels(windowStart:windowEnd) = true;
            elseif obj.Type == "Burst"
                % Check that BurstDuration is shorter than WindowLength
                if obj.BurstDuration > windowLength
                    error(message("predmaint_anomaly:anomaly:errBurstTooLong"))
                end

                % Inject each burst and create label vector
                for i = 1:obj.NumBursts
                    burst_start = windowStart + randi([0, windowLength - obj.BurstDuration]); % Random start index within segment
                    burst_end = burst_start + obj.BurstDuration-1; % End index of burst
                    burstLen = burst_end - burst_start + 1;
                    outTS(burst_start:burst_end) = outTS(burst_start:burst_end) + generateNoise(obj, burstLen);
                    labels(burst_start:burst_end) = true;
                end
            end
        end
    end

    methods(Access=private)
        function noise = generateNoise(obj, n)
        %generateNoise Generate n noise samples from the configured distribution.
        %   Returns a column vector of length n with the specified Mean and Std.
            switch obj.Distribution
                case "Gaussian"
                    noise = obj.Mean + obj.Std * randn(n, 1);
                case "Uniform"
                    % Uniform on [Mean - a, Mean + a] where a = Std*sqrt(3)
                    % so that the variance equals Std^2.
                    a = obj.Std * sqrt(3);
                    noise = obj.Mean + a * (2*rand(n, 1) - 1);
                case "Laplacian"
                    % Laplace distribution via inverse CDF.
                    % Scale b = Std/sqrt(2) gives variance = Std^2.
                    b = obj.Std / sqrt(2);
                    u = rand(n, 1) - 0.5;
                    noise = obj.Mean - b * sign(u) .* log(1 - 2*abs(u));
            end
        end
    end

    methods (Access = protected)
        function groups = getPropertyGroups(obj)
            % Implement the custom display for scalar obj
            if obj.Type == "Burst"
                propList = {'Type', 'Distribution', 'Mean', 'Std', 'NumBursts', 'BurstDuration'};
            else
                propList = {'Type', 'Distribution', 'Mean', 'Std'};
            end
            groups = matlab.mixin.util.PropertyGroup(propList);
        end
    end
end
