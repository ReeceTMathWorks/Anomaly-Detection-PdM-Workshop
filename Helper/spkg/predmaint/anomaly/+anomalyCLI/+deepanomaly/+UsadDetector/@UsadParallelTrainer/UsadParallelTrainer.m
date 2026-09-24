classdef UsadParallelTrainer
%

%   Copyright 2025 The MathWorks, Inc.

    properties
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
        DataQueue minibatchqueue
    end

    properties (Access = private)
        StopTraining logical = false
    end

    methods (Access=public)
        function obj = UsadParallelTrainer(trainQueue, pDlnetE, pDlnetD1,pDlnetD2, lossFcn, trainingOptions)
            obj.DataQueue = copy(trainQueue);
            obj.LossFcn = lossFcn;
            obj.pDlnetE = pDlnetE;
            obj.pDlnetD1 = pDlnetD1;
            obj.pDlnetD2 = pDlnetD2;
            obj.TrainingOptions = trainingOptions;
            obj.NumEpochs = trainingOptions.MaxEpochs;
            obj.LearnRate = trainingOptions.LearnRate;
            obj.IterationCount = 0;
            obj.EpochCount = 1;
        end

        function [trainedNetE, trainedNetD1,trainedNetD2, trainHistory] = fit(obj, monitor, observationWindowLength, numChannels)

            % initialize the average gradient and the average gradient-square decay rates of adam optimizer with empty arrays
            avgGradientsEncoder = [];
            avgGradientsSquaredEncoder = [];
            avgGradientsDecoder1 = [];
            avgGradientsSquaredDecoder1 = [];
            avgGradientsDecoder2 = [];
            avgGradientsSquaredDecoder2 = [];

            % Always start from begin of queue
            reset(obj.DataQueue);

            % Shuffle data before partition
            shuffle(obj.DataQueue);

            % get pool
            pool = anomalyCLI.internal.deepanomaly.utils.setupParallelPool(obj.TrainingOptions.ExecutionEnvironment);
            %[UseParallel, isMultiGpu, IsThreadPool, pool, IsNewPool] =  deep.internal.parallel.setupAndValidatePool(obj.TrainingOptions.ExecutionEnvironment, 1);
            numWorkers = pool.NumWorkers;

            % Make sure minibatchsize is greater than or equal to the
            % number of workers.
            if obj.TrainingOptions.MiniBatchSize < numWorkers
                error(message('predmaint_anomaly:anomaly:miniBatchSizeSmallerThanNumWorkers'));
            end

            workerMiniBatchSize = floor(obj.TrainingOptions.MiniBatchSize ./ repmat(numWorkers,1,numWorkers));
            remainder = obj.TrainingOptions.MiniBatchSize - sum(workerMiniBatchSize);
            workerMiniBatchSize = workerMiniBatchSize + [ones(1,remainder) zeros(1,numWorkers-remainder)];

            % setup verbose
            if obj.TrainingOptions.Verbose
                verboseFrequency = 50;
                fprintf("|======================================================================================|\n")
                fprintf("| Iteration | Epoch |  Time Elapsed  | Base Learning |  AE1 Training  |  AE2 Training  |\n")
                fprintf("|           |       |   (hh:mm:ss)   |      Rate     |      Loss      |     Loss       |\n")
                fprintf("|======================================================================================|\n")
            end

            % Create a Dataqueue object on the workers to send a flag to stop training when the Stop button is clicked.
            spmd
                stopTrainingEventQueue = parallel.pool.DataQueue;
            end
            stopTrainingQueue = stopTrainingEventQueue{1};

            % Create a eventQueue to display the training progress
            if monitor.Visible

                monitor.Visible = true;
                monitor.Metrics=["AE1_TrainingLoss", "AE2_TrainingLoss"];
                monitor.Info = [monitor.Info,  "Workers"];
                %Cache stop queue for just worker 1 on client side, we just need
                % to be able to communicate with one worker to signal stop.
                eventQueue = parallel.pool.DataQueue;
                displayFcn = @(x) displayTrainingProgress(x, monitor, ...
                    obj.LearnRate,...
                    obj.TrainingOptions.NumIterations,...
                    obj.NumEpochs,...
                    numWorkers, stopTrainingQueue);
                afterEach(eventQueue,displayFcn)
            end
           
            spmd
                netE = obj.pDlnetE;
                netD1= obj.pDlnetD1;
                netD2= obj.pDlnetD2;

                % Partition the datastore.
                workerDataQueue = partition(obj.DataQueue, numWorkers, spmdIndex);
                deep.internal.sdk.setMiniBatchSize(workerDataQueue, workerMiniBatchSize(spmdIndex));

                % initialize
                obj.IterationCount = 0;
                obj.EpochCount = 1;
                obj.StartTime = tic;
                stopRequested = false;

                for epoch = 1: obj.NumEpochs
                    while continueEpoch(workerDataQueue, stopTrainingQueue)
                        obj.IterationCount = obj.IterationCount + 1;
                        workerX = next(workerDataQueue);

                        % Evaluate loss and gradients.
                        [workerLoss1, ~, workerGradientsEncoder, workerGradientsDecoder] = dlfeval(obj.LossFcn, netE, netD1, netD2, workerX, ...
                            epoch, observationWindowLength, numChannels, workerMiniBatchSize(spmdIndex), true);

                        % Aggregate the losses on all workers.
                        workerNormalizationFactor = workerMiniBatchSize(spmdIndex)./obj.TrainingOptions.MiniBatchSize;
                        loss1 = spmdPlus(workerNormalizationFactor*extractdata(workerLoss1));

                        % Aggregate the gradients on all workers.
                        workerGradientsEncoder.Value = aggregateAllGradients(workerGradientsEncoder.Value, workerNormalizationFactor);
                        workerGradientsDecoder.Value = aggregateAllGradients(workerGradientsDecoder.Value, workerNormalizationFactor);


                        % Update the network and learnable parameters for phase 1
                        [netE, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(netE, ...
                            workerGradientsEncoder, avgGradientsEncoder, avgGradientsSquaredEncoder, obj.IterationCount, obj.LearnRate);

                        [netD1, avgGradientsDecoder1, avgGradientsSquaredDecoder1] = adamupdate(netD1, ...
                            workerGradientsDecoder, avgGradientsDecoder1, avgGradientsSquaredDecoder1, obj.IterationCount, obj.LearnRate);


                        % Train AE2 for differentiating between original signal
                        % input and the input coming from the AE1. This forces AE2
                        % to learn on the subtle nuances of the input signal that
                        % were missed by AE1 in its reconstruction learning
                        % Compute loss and gradients
                        [~, workerLoss2, workerGradientsEncoder, workerGradientsDecoder] = dlfeval(obj.LossFcn, netE, netD1, netD2, workerX, ...
                            epoch, observationWindowLength, numChannels, workerMiniBatchSize(spmdIndex), false);

                        % Aggregate the losses on all workers.
                        workerNormalizationFactor = workerMiniBatchSize(spmdIndex)./obj.TrainingOptions.MiniBatchSize ;
                        loss2 = spmdPlus(workerNormalizationFactor*extractdata(workerLoss2));

                        % Aggregate the gradients on all workers.
                        workerGradientsEncoder.Value = aggregateAllGradients(workerGradientsEncoder.Value, workerNormalizationFactor);
                        workerGradientsDecoder.Value = aggregateAllGradients(workerGradientsDecoder.Value, workerNormalizationFactor);

                        % Update the network and learnable parameters for phase 2
                        [netE, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(netE, ...
                            workerGradientsEncoder, avgGradientsEncoder, avgGradientsSquaredEncoder, obj.IterationCount, obj.LearnRate);

                        [netD2, avgGradientsDecoder2, avgGradientsSquaredDecoder2] = adamupdate(netD2, ...
                            workerGradientsDecoder, avgGradientsDecoder2, avgGradientsSquaredDecoder2, obj.IterationCount, obj.LearnRate);

                        stopRequested = spmdPlus(stopTrainingQueue.QueueLength) > 0;

                        % Send training progress information to the client and update the plots
                        if strcmp(obj.TrainingOptions.Plots, 'training-progress') && (spmdIndex == 1)
                            data = [epoch loss1 loss2 obj.IterationCount];
                            send(eventQueue, gather(data));
                        end

                        % Update the verbose
                        if obj.TrainingOptions.Verbose && (obj.IterationCount == 1 || mod(obj.IterationCount, verboseFrequency) == 0)
                            D = duration(0,0,toc(obj.StartTime),Format="hh:mm:ss");
                            fprintf("| %9d | %5d | %14s | %13.4f | %14.4f | %14.4f |\n", ...
                                obj.IterationCount, epoch, D, obj.LearnRate, loss1, loss2);
                        end
                    end % within one epoch
                    obj.EpochCount = obj.EpochCount + 1;
                    if stopRequested
                        % If stop was called on the trainer, break out of
                        % the epoch loop.
                        break;
                    else
                        % Manage shuffle state of the data to prepare for
                        % more epochs
                        reset(workerDataQueue);
                    end
                end
            end % spmd
            trainedNetE = netE{1};
            trainedNetD1 = netD2{1};
            trainedNetD2 = netD2{1};
            obj = obj{1}; % now the obj is Composites as well. Get the first instance
            trainHistory = {monitor, avgGradientsEncoder, avgGradientsSquaredEncoder, avgGradientsDecoder1, avgGradientsSquaredDecoder1, ...
                avgGradientsDecoder2, avgGradientsSquaredDecoder2};
            if obj.TrainingOptions.Verbose
                fprintf("|======================================================================================|\n")
            end
        end
    end

end

%----------------------------------------------------------------------
function displayTrainingProgress(data, monitor, learnRate, numIterations, numEpochs, numWorkers, stopTrainingQueue)

% Extract training information from array.
epoch = data(1);
loss1 = data(2);
loss2 = data(3);
iteration = data(4);

% Update training progress monitor.
recordMetrics(monitor, iteration, AE1_TrainingLoss=loss1, AE2_TrainingLoss=loss2);
updateInfo(monitor, ...
    LearningRate = learnRate,...
    Iteration = iteration + " of " + numIterations,...
    Epoch = epoch + " of " + numEpochs,...
    Workers= numWorkers);
monitor.Progress = 100*iteration/numIterations;

% Send flag if the Stop button is clicked.
if monitor.Stop
    send(stopTrainingQueue,true);
end
end

%----------------------------------------------------------------------

function tf = continueEpoch(workerMbq,stopTrainingQueue)

% Create a struct that will be concatenated across the workers.
info.HasData = hasdata(workerMbq);
info.StopRequested = stopTrainingQueue.QueueLength > 0;

% Use spmdCat to aggregate the info from all the workers.
info = spmdCat(info);

% Continue training if all the workers have data, and if we were not asked to stop.
stopRequest = any([info.StopRequested]);
tf = ~stopRequest && all([info.HasData]);

end

%----------------------------------------------------------------------

function gradients = aggregateAllGradients(gradients,normalizationFactor)

% Inspect array of gradients and create cell array for storing aggregated
% data.
numArrays = numel(gradients);
aggregationData = cell(numArrays);
arraySizes = cell(numArrays,1);
numElements = zeros(numArrays,1);

% Extract the data from all the arrays
for idxArray = 1:numArrays
    data = gradients{idxArray};
    gradients{idxArray} = [];

    % Extract data from dlarray.
    data = extractdata(data);

    % Save the size of the array.
    arraySizes{idxArray} = size(data);
    numElements(idxArray) = numel(data);

    % Flatten the array to prepare for concatenation.
    aggregationData{idxArray} = data(:);
end

% Concatenate all arrays.
aggregationData = cat(1,aggregationData{:});

% Aggregate the data from the workers.
aggregationData = spmdPlus(normalizationFactor.*aggregationData);

% Reconstruct the gradient arrays.
i = 1;
for idxArray = 1:numArrays
    n = numElements(idxArray);
    if n > 0
        % Reshape the flattened data to the original size.
        data = reshape(aggregationData(i:(i+n-1)),arraySizes{idxArray});
        % Reinsert the aggregated data as a dlarray.
        gradients{idxArray} = dlarray(data);
        i = i + n;
    end
end
end
