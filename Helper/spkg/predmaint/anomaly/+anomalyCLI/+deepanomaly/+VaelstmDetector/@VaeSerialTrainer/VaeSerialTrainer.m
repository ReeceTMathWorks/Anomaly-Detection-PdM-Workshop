classdef VaeSerialTrainer
%

%   Copyright 2025 The MathWorks, Inc.


    properties (SetAccess = private)
        NetEncoder
        NetDecoder
        LossFcn
        NumEpochs
        IterationCount double
        EpochCount double
        TrainingOptions
        StartTime uint64
    end

    properties (Access = private)
        DataQueue minibatchqueue
        StopTraining logical = false
    end

    methods (Access=public)
        function obj = VaeSerialTrainer(trainQueue, netE, netD, lossFcn, options)

            obj.DataQueue = copy(trainQueue);
            obj.LossFcn = lossFcn;
            obj.NetEncoder = netE;
            obj.NetDecoder = netD;
            obj.TrainingOptions = options;
            obj.IterationCount = 0;
            obj.EpochCount = 1;
        end

        function [netEncoder, netDecoder] = fit(obj, monitor)
            import anomalyCLI.internal.deepanomaly.VaelstmDetector.*

            % setup verbose
            if obj.TrainingOptions.Verbose
                verboseFrequency = 50;
                fprintf("|=====================================================================|\n")
                fprintf("| Iteration | Epoch |  Time Elapsed  | Base Learning |  VAE Training  |\n")
                fprintf("|           |       |   (hh:mm:ss)   |      Rate     |      Loss      |\n")
                fprintf("|=====================================================================|\n")
            end

            % initialize the average gradient and the average gradient-square decay rates of adam optimizer with empty arrays
            avgGradientsEncoder = [];
            avgGradientsSquaredEncoder = [];
            avgGradientsDecoder = [];
            avgGradientsSquaredDecoder = [];

            netEncoder = obj.NetEncoder;
            netDecoder = obj.NetDecoder;

            % Always start from begin of queue
            reset(obj.DataQueue);

            % Shuffle data
            if obj.TrainingOptions.Shuffle ~= "never"
                shuffle(obj.DataQueue);
            end

            obj.IterationCount = 0;
            obj.EpochCount = 1;

            % Loop over epochs.
            obj.StartTime = tic;
            for epoch = 1 : obj.TrainingOptions.NumEpochs

                % Loop over mini-batches.
                while hasdata(obj.DataQueue)  && ~monitor.Stop

                    obj.IterationCount = obj.IterationCount + 1;

                    % Read mini-batch of data.
                    X = next(obj.DataQueue);

                    % Evaluate loss and gradients.
                    [loss, gradientsEncoder, gradientsDecoder] = dlfeval(obj.LossFcn, netEncoder, netDecoder, X);

                    % Update learnable parameters.
                    [netEncoder, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(netEncoder, ...
                        gradientsEncoder, avgGradientsEncoder,avgGradientsSquaredEncoder, obj.IterationCount, obj.TrainingOptions.LearnRate);

                    [netDecoder, avgGradientsDecoder, avgGradientsSquaredDecoder] = adamupdate(netDecoder, ...
                        gradientsDecoder, avgGradientsDecoder, avgGradientsSquaredDecoder, obj.IterationCount, obj.TrainingOptions.LearnRate);

                    % Update the training progress monitor.
                    if monitor.Visible
                        recordMetrics(monitor, obj.IterationCount, TrainingLoss = loss);
                        updateInfo(monitor, ...
                            LearningRate = obj.TrainingOptions.LearnRate,...
                            Iteration = obj.IterationCount + " of " + obj.TrainingOptions.NumIterations,...
                            Epoch=epoch + " of " + obj.TrainingOptions.NumEpochs);
                        monitor.Progress = 100*obj.IterationCount/obj.TrainingOptions.NumIterations;
                    end

                    % Update the verbose
                    if obj.TrainingOptions.Verbose && (obj.IterationCount == 1 || mod(obj.IterationCount, verboseFrequency) == 0)
                        D = duration(0, 0, toc(obj.StartTime),Format="hh:mm:ss");

                        fprintf("| %9d | %5d | %14s | %13.4f | %14.4f |\n", ...
                            obj.IterationCount, obj.EpochCount, D, obj.TrainingOptions.LearnRate, loss);
                    end
                end
                obj.EpochCount = obj.EpochCount + 1;
                reset(obj.DataQueue);
                if obj.TrainingOptions.Shuffle == "every-epoch"
                    shuffle(obj.DataQueue);
                end
            end

            if obj.TrainingOptions.Verbose
                fprintf("|=====================================================================|\n")
            end
        end
    end
end

