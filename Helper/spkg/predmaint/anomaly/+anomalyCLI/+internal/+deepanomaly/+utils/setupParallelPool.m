function pool = setupParallelPool(executionEnvironment)
%SETUPANDVALIDATEPOOL Sets up and validates a parallel pool given the
% executionEnvironment and dispatchInBackground options.

% Copyright 2025 The MathWorks, Inc.

pool = gcp('nocreate');

if ~isempty(pool)
    % Check that the open pool is not a thread pool
    if isa(pool,'parallel.ThreadPool')
        error(message('nnet_cnn:internal:cnn:util:setupAndValidateParallel:ThreadsPoolNotSupported',executionEnvironment))
    end
    % Check that the open pool is local
    if ~isa(pool.Cluster, 'parallel.cluster.Local' )
        error(message('nnet_cnn:internal:cnn:util:setupAndValidateParallel:ExpectedLocalPool'));
    end
else
    if strcmp(executionEnvironment,'gpu')
        availableGpus = nnz(parallel.gpu.GPUDevice.isAvailable(1:gpuDeviceCount));
        numGpus = max(1, availableGpus);
        pool = parpool('local',numGpus); % As many local workers as available GPUs
    else
        pool = parpool(); % Use default pool.
    end
end
end
