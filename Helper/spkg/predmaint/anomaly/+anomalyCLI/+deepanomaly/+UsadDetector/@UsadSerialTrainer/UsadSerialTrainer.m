classdef UsadSerialTrainer
%

%   Copyright 2025 The MathWorks, Inc.


    properties (SetAccess = private)
        pDlnetE
        pDlnetD1
        pDlnetD2
        LossFcn
        NumEpochs
        LearnRate
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
        function obj = UsadSerialTrainer(trainQueue, pDlnetE, pDlnetD1,pDlnetD2, lossFcn, options)

            obj.DataQueue = copy(trainQueue);
            obj.LossFcn = lossFcn;
            obj.pDlnetE = pDlnetE;
            obj.pDlnetD1 = pDlnetD1;
            obj.pDlnetD2 = pDlnetD2;
            obj.TrainingOptions = options;
            obj.NumEpochs = options.MaxEpochs;
            obj.LearnRate = options.LearnRate;
            obj.IterationCount = 0;
            obj.EpochCount = 1;
        end

        function [pDlnetE, pDlnetD1,pDlnetD2,trainHistory] = fit(obj, monitor, observationWindowLength, numChannels)

            % setup verbose
            if obj.TrainingOptions.Verbose
                verboseFrequency = 50;
                fprintf("|======================================================================================|\n")
                fprintf("| Iteration | Epoch |  Time Elapsed  | Base Learning |  AE1 Training  |  AE2 Training  |\n")
                fprintf("|           |       |   (hh:mm:ss)   |      Rate     |      Loss      |     Loss       |\n")
                fprintf("|======================================================================================|\n")
            end

            import anomalyCLI.internal.deepanomaly.UsadDetector.*

            % initialize the average gradient and the average gradient-square decay rates of adam optimizer with empty arrays
            avgGradientsEncoder = [];
            avgGradientsSquaredEncoder = [];
            avgGradientsDecoder1 = [];
            avgGradientsSquaredDecoder1 = [];
            avgGradientsDecoder2 = [];
            avgGradientsSquaredDecoder2 = [];


            pDlnetE = obj.pDlnetE;
            pDlnetD1= obj.pDlnetD1;
            pDlnetD2= obj.pDlnetD2;

            % Always start from begin of queue
            reset(obj.DataQueue);

            % Shuffle data.
            shuffle(obj.DataQueue);

            obj.IterationCount = 0;
            obj.EpochCount = 1;

            % Loop over epochs.
            obj.StartTime = tic;
            for epoch = 1 : obj.NumEpochs

                % Loop over mini-batches.
                while hasdata(obj.DataQueue)  && ~monitor.Stop

                    obj.IterationCount = obj.IterationCount + 1;

                    % Read mini-batch of data.
                    X = next(obj.DataQueue);

                    % Evaluate loss and gradients.
                    [loss1, ~, gradientsE, gradientsD] = dlfeval(obj.LossFcn,  pDlnetE, pDlnetD1, pDlnetD2, X, ...
                        epoch, observationWindowLength, numChannels, obj.DataQueue.MiniBatchSize, true);


                    % Update the network and learnable parameters for phase 1
                    [pDlnetE, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(pDlnetE, ...
                        gradientsE, avgGradientsEncoder, avgGradientsSquaredEncoder, obj.IterationCount, obj.LearnRate);

                    [pDlnetD1, avgGradientsDecoder1, avgGradientsSquaredDecoder1] = adamupdate(pDlnetD1, ...
                        gradientsD, avgGradientsDecoder1, avgGradientsSquaredDecoder1, obj.IterationCount, obj.LearnRate);


                    % Train AE2 for differentiating between original signal
                    % input and the input coming from the AE1. This forces AE2
                    % to learn on the subtle nuances of the input signal that
                    % were missed by AE1 in its reconstruction learning
                    % Compute loss and gradients
                    [~, loss2, gradientsE, gradientsD] = dlfeval(obj.LossFcn, pDlnetE, pDlnetD1, pDlnetD2, X, ...
                        epoch, observationWindowLength, numChannels, obj.DataQueue.MiniBatchSize, false);

                    % Update the network and learnable parameters for phase 2
                    [pDlnetE, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(pDlnetE, ...
                        gradientsE, avgGradientsEncoder, avgGradientsSquaredEncoder, obj.IterationCount, obj.LearnRate);

                    [pDlnetD2, avgGradientsDecoder2, avgGradientsSquaredDecoder2] = adamupdate(pDlnetD2, ...
                        gradientsD, avgGradientsDecoder2, avgGradientsSquaredDecoder2, obj.IterationCount, obj.LearnRate);
                    % Update the training progress monitor.
                    if monitor.Visible
                        recordMetrics(monitor, obj.IterationCount, AE1_TrainingLoss=loss1, AE2_TrainingLoss=loss2);
                        updateInfo(monitor, ...
                            LearningRate=obj.LearnRate,...
                            Iteration = obj.IterationCount + " of " + obj.TrainingOptions.NumIterations,...
                            Epoch=epoch + " of " + obj.NumEpochs);
                        monitor.Progress = 100*obj.IterationCount/obj.TrainingOptions.NumIterations;
                    end

                    % Update the verbose
                    if obj.TrainingOptions.Verbose && (obj.IterationCount == 1 || mod(obj.IterationCount, verboseFrequency) == 0)
                        D = duration(0, 0, toc(obj.StartTime),Format="hh:mm:ss");

                        fprintf("| %9d | %5d | %14s | %13.4f | %14.4f | %14.4f |\n", ...
                            obj.IterationCount, epoch, D, obj.LearnRate, loss1, loss2);
                    end
                end
                obj.EpochCount = obj.EpochCount + 1;
                reset(obj.DataQueue);
            end
            trainHistory = {monitor, avgGradientsEncoder, avgGradientsSquaredEncoder, avgGradientsDecoder1, avgGradientsSquaredDecoder1, ...
                avgGradientsDecoder2, avgGradientsSquaredDecoder2};
            
            if obj.TrainingOptions.Verbose
                fprintf("|=====================================================================|\n")
            end
        end
    end
end

