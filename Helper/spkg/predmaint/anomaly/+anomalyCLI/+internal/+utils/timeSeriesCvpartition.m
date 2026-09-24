classdef timeSeriesCvpartition
    %TIMESERIESCVPARTITION Partition single or multi-series time series data for holdout validation.
    %
    %   obj = timeSeriesCvpartition(data, 'Holdout', 0.2)
    %       Performs a chronological holdout split within each series (perSeries mode).
    %
    %   obj = timeSeriesCvpartition(data, 'Holdout', 0.2, 'Gap', 50, 'Mode', 'perCell')
    %       Holds out entire cells (last 20%) for test data.
    %
    %   Supports:
    %       - Numeric array (N×D)
    %       - Timetable
    %       - Cell array of numeric arrays (each possibly different length)
    %       - Cell array of timetables (each possibly different length)

    % Copyright 2025 The MathWorks, Inc.
    
    properties        
        Mode (1,1) string = "perSeries"           % 'perSeries' or 'perCell'
        Gap (1,1) double {mustBeNonnegative} = 0
        HoldoutRatio (1,1) double {mustBeGreaterThan(HoldoutRatio,0), mustBeLessThan(HoldoutRatio,1)} = 0.2
    end

    properties (SetAccess=private)
        NumSeries (1,1) double
        TrainIndices
        TestIndices
        InputType
    end

    methods
        function obj = timeSeriesCvpartition(data, options)
            arguments
                data
                options.Holdout (1,1) double {mustBeGreaterThan(options.Holdout,0), mustBeLessThan(options.Holdout,1)} = 0.2
                options.Gap (1,1) double {mustBeNonnegative} = 0
                options.Mode (1,:) char {mustBeMember(options.Mode, {'perSeries','perCell'})} = 'perSeries'
            end

            obj.HoldoutRatio = options.Holdout;
            obj.Gap = options.Gap;
            obj.Mode = lower(options.Mode);

            % --- Determine input type ---
            if istimetable(data)
                obj.InputType = 'timetable';
                obj.NumSeries = 1;
            elseif isnumeric(data)
                obj.InputType = 'numeric';
                obj.NumSeries = 1;
            elseif iscell(data)
                if istimetable(data{1})
                    obj.InputType = 'cell-timetable';
                elseif isnumeric(data{1})
                    obj.InputType = 'cell-numeric';
                else
                    error('Unsupported cell element type.');
                end
                obj.NumSeries = numel(data);
            else
                error('Unsupported data type.');
            end

            % --- Initialize partition indices ---
            obj.TrainIndices = cell(obj.NumSeries, 1);
            obj.TestIndices  = cell(obj.NumSeries, 1);

            switch obj.Mode
                case 'perseries'
                    for s = 1:obj.NumSeries
                        N = obj.seriesLength(data, s);
                        cutoff = floor(N * (1 - obj.HoldoutRatio));
                        trainEnd = max(1, cutoff - obj.Gap);

                        trainIdx = false(N,1);
                        testIdx  = false(N,1);
                        trainIdx(1:trainEnd) = true;
                        testIdx((cutoff+1):end) = true;

                        obj.TrainIndices{s} = trainIdx;
                        obj.TestIndices{s}  = testIdx;
                    end

                case 'percell'
                    if ~iscell(data) 
                        error('Mode "perCell" is only valid for cell array data.');
                    end
                    numCells = obj.NumSeries;

                    if numCells<2
                        error('Mode "perCell" needs atleast two cell elements.');
                    end
                    cutoff = floor(numCells * (1 - obj.HoldoutRatio));
                    obj.TrainIndices{1} = 1:cutoff;
                    obj.TestIndices{1}  = (cutoff+1):numCells;
            end
        end

        function N = seriesLength(~, data, s)
            if iscell(data)
                N = size(data{s}, 1);
            else
                N = size(data, 1);
            end
        end

        function idx = training(obj, s)
            arguments
                obj
                s = 1
            end

            if strcmp(obj.Mode, 'percell')
                idx = obj.TrainIndices{1};
            else
                idx = obj.TrainIndices{s};
            end
        end

        function idx = test(obj, s)
            arguments
                obj
                s = 1
            end
            if strcmp(obj.Mode, 'percell')
                idx = obj.TestIndices{1};
            else
                idx = obj.TestIndices{s};
            end
        end

        function subsetData = subset(obj, data, isTrain)
            %SUBSET Return all training or test data subsets
            arguments
                obj
                data
                isTrain (1,1) logical
            end

            switch obj.InputType
                case {'numeric','timetable'}
                    if isTrain
                        idx = obj.TrainIndices{1};
                    else
                        idx = obj.TestIndices{1};
                    end
                    subsetData = data(idx,:);
                    
                case {'cell-numeric','cell-timetable'}
                    subsetData = cell(obj.NumSeries,1);
                    if strcmp(obj.Mode, 'percell')
                        if isTrain
                            subsetData = data(obj.TrainIndices{1});
                        else
                            subsetData = data(obj.TestIndices{1});
                        end
                    else
                        for s = 1:obj.NumSeries
                            if isTrain
                                idx = obj.TrainIndices{s};
                            else
                                idx = obj.TestIndices{s};
                            end
                            subsetData{s} = data{s}(idx,:);
                        end
                    end
                otherwise
                    error('Unsupported input type.');
            end
        end
    end
end
