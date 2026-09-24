classdef VaeParallelTrainer
%

%   Copyright 2025 The MathWorks, Inc.

    properties
        NetEncoder
        NetDecoder
        DataQueue minibatchqueue
        LossFcn
        NumEpochs
        IterationCount double
        EpochCount double
        TrainingOptions
        StartTime uint64
    end

    properties (Access = private)

        StopTraining logical = false
    end

    methods (Access=public)
        function obj = VaeParallelTrainer(trainQueue, netE, netD, lossFcn, trainingOptions)
            obj.DataQueue = copy(trainQueue);
            obj.LossFcn = lossFcn;
            obj.NetEncoder = netE;
            obj.NetDecoder = netD;
            obj.TrainingOptions = trainingOptions;
            obj.IterationCount = 0;
            obj.EpochCount = 1;
        end

        function [trainedEncoder, trainedDecoder] = fit(obj, monitor)

            % initialize the average gradient and the average gradient-square decay rates of adam optimizer with empty arrays
            avgGradientsEncoder = [];
            avgGradientsSquaredEncoder = [];
            avgGradientsDecoder = [];
            avgGradientsSquaredDecoder = [];

            % Always start from begin of queue
            reset(obj.DataQueue);

            % setup verbose
            if obj.TrainingOptions.Verbose
                verboseFrequency = 50;
                fprintf("|=====================================================================|\n")
                fprintf("| Iteration | Epoch |  Time Elapsed  | Base Learning |  VAE Training  |\n")
                fprintf("|           |       |   (hh:mm:ss)   |      Rate     |      Loss      |\n")
                fprintf("|=====================================================================|\n")
            end

            % Shuffle data before partition
            if obj.TrainingOptions.Shuffle ~= "never"
                shuffle(obj.DataQueue);
            end

            % get pool
            pool = anomalyCLI.internal.deepanomaly.utils.setupParallelPool(obj.TrainingOptions.ExecutionEnvironment);
            numWorkers = pool.NumWorkers;

            % Make sure minibatchsize is greater than or equal to the
            % number of workers.
            if obj.TrainingOptions.MiniBatchSize < numWorkers
                error(message('predmaint_anomaly:anomaly:miniBatchSizeSmallerThanNumWorkers'));
            end

            workerMiniBatchSize = floor(obj.TrainingOptions.MiniBatchSize ./ repmat(numWorkers,1,numWorkers));
            remainder = obj.TrainingOptions.MiniBatchSize - sum(workerMiniBatchSize);
            workerMiniBatchSize = workerMiniBatchSize + [ones(1,remainder) zeros(1,numWorkers-remainder)];

            % Create a Dataqueue object on the workers to send a flag to stop training when the Stop button is clicked.
            spmd
                stopTrainingEventQueue = parallel.pool.DataQueue;
            end
            %Cache stop queue for just worker 1 on client side, we just need
            % to be able to communicate with one worker to signal stop.
            stopTrainingQueue = stopTrainingEventQueue{1};

            % Create a eventQueue to display the training progress
            if monitor.Visible


                monitor.Info = [monitor.Info,  "Workers"];

                eventQueue = parallel.pool.DataQueue;
                displayFcn = @(x) displayTrainingProgress(x, monitor, ...
                    obj.TrainingOptions.LearnRate,...
                    obj.TrainingOptions.NumIterations,...
                    obj.TrainingOptions.NumEpochs,...
                    numWorkers, stopTrainingQueue);
                afterEach(eventQueue,displayFcn)
            end


            spmd
                netEncoder = obj.NetEncoder;
                netDecoder = obj.NetDecoder;

                % Partition the datastore.
                workerDataQueue = partition(obj.DataQueue, numWorkers, spmdIndex);
                deep.internal.sdk.setMiniBatchSize(workerDataQueue, workerMiniBatchSize(spmdIndex));

                % initialize
                obj.IterationCount = 0;
                obj.EpochCount = 1;
                obj.StartTime = tic;
                stopRequested = false;

                for epoch = 1: obj.TrainingOptions.NumEpochs
                    while continueEpoch(workerDataQueue, stopTrainingQueue)
                        obj.IterationCount = obj.IterationCount + 1;
                        workerX = next(workerDataQueue);

                        % Evaluate loss and gradients.
                        [workerLoss, workerGradientsEncoder, workerGradientsDecoder] = dlfeval(obj.LossFcn, netEncoder, netDecoder, workerX);

                        % Aggregate the losses on all workers.
                        workerNormalizationFactor = workerMiniBatchSize(spmdIndex)./obj.TrainingOptions.MiniBatchSize ;
                        loss = spmdPlus(workerNormalizationFactor*extractdata(workerLoss));

                        % Aggregate the gradients on all workers.
                        workerGradientsEncoder.Value = aggregateAllGradients(workerGradientsEncoder.Value, workerNormalizationFactor);
                        workerGradientsDecoder.Value = aggregateAllGradients(workerGradientsDecoder.Value, workerNormalizationFactor);

                        % Update the network parameters
                        [netEncoder, avgGradientsEncoder, avgGradientsSquaredEncoder] = adamupdate(netEncoder, ...
                            workerGradientsEncoder, avgGradientsEncoder, ...
                            avgGradientsSquaredEncoder, obj.IterationCount, obj.TrainingOptions.LearnRate);

                        [netDecoder, avgGradientsDecoder, avgGradientsSquaredDecoder] = adamupdate(netDecoder, ...
                            workerGradientsDecoder, avgGradientsDecoder, ...
                            avgGradientsSquaredDecoder, obj.IterationCount, obj.TrainingOptions.LearnRate);

                        stopRequested = spmdPlus(stopTrainingQueue.QueueLength) > 0;

                        if monitor.Visible && (spmdIndex == 1)
                            % Send training progress information to the client.
                            data = [epoch loss obj.IterationCount];
                            send(eventQueue, gather(data));
                        end

                        % Update the verbose
                        if obj.TrainingOptions.Verbose && (obj.IterationCount == 1 || mod(obj.IterationCount, verboseFrequency) == 0)
                            D = duration(0,0,toc(obj.StartTime),Format="hh:mm:ss");

                            fprintf("| %9d | %5d | %14s | %13.4f | %14.4f |\n", ...
                                obj.IterationCount, obj.EpochCount, D, obj.TrainingOptions.LearnRate, loss);
                        end
                    end
                    obj.EpochCount = obj.EpochCount + 1;

                    if stopRequested
                        % If stop was called on the trainer, break out of
                        % the epoch loop.
                        break;
                    else
                        % Manage shuffle state of the data to prepare for
                        % more epochs
                        reset(workerDataQueue);
                        if obj.TrainingOptions.Shuffle == "every-epoch"
                            shuffle(workerDataQueue);
                        end
                    end
                end % epoch loop
            end %spmd
            trainedEncoder = netEncoder{1};
            trainedDecoder = netDecoder{1};
            obj = obj{1}; % now the obj is Composites as well. Get the first instance
            if obj.TrainingOptions.Verbose
                fprintf("|=====================================================================|\n")
            end
        end
    end

end

%----------------------------------------------------------------------
function displayTrainingProgress(data, monitor, learnRate, numIterations, numEpochs, numWorkers, stopTrainingQueue)

% Extract training information from array.
epoch = data(1);
loss = data(2);
iteration = data(3);

% Update training progress monitor.
recordMetrics(monitor, iteration, VAE_TrainingLoss = loss);
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
