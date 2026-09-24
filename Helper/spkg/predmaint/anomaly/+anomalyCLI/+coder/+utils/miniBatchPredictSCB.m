function y = miniBatchPredictSCB(net,data,miniBatchSize)
% This is an internal utility and may be removed in future

%   Copyright 2026 The MathWorks, Inc.

% Inputs: net - a dlnetwork
%      : data - a single precision  2D dlarray of 'CB' format or 3D dlarray
%               of 'SCB' format. It is assumed that network returns output 
%               in 'CB' or 'SCB' format
%      : miniBatchSize - input data is grouped into batches of size
%           miniBatchSize and network inference is run on each batch.
%#codegen

coder.internal.prefer_const(miniBatchSize);

batchDim = finddim(data,"B");
nbatches = coder.internal.indexInt(size(data,batchDim));
iminiBatchSize = coder.internal.indexInt(miniBatchSize);

if coder.internal.isConst(nbatches)
    y = predictFixedSizeBatchDim(net,data,iminiBatchSize,nbatches);
else
    y = predictVarSizeBatchDim(net,data,iminiBatchSize,nbatches);
end

end

function y = predictFixedSizeBatchDim(net,data,miniBatchSize,nbatches)
coder.internal.prefer_const(miniBatchSize,nbatches);
if coder.const(nbatches <= miniBatchSize)
    y = net.predict(data);
    return;
end
numMiniBatches = coder.internal.indexDivide(nbatches,miniBatchSize);
batch = getBatch(data,1:miniBatchSize);
ybatch = net.predict(batch);
% we are making a strong assumption that the predict method outputs a
% dlarray of 'CB' or 'SCB' format, this holds true for our use cases in
% anomaly detectors.

% Infer the output type by running predict on the first batch and then
% allocate memory for the entire output.
if coder.internal.ndims(ybatch) == 3
    y = coder.nullcopy(dlarray(zeros(size(ybatch,1),size(ybatch,2),nbatches,'single'),'SCB'));
    y(:,:,1:miniBatchSize) = ybatch;
else
    y = coder.nullcopy(dlarray(zeros(size(ybatch,1),nbatches,'single'),'CB'));
    y(:,1:miniBatchSize) = ybatch;
end

for i = 2:numMiniBatches
    batchIdx = (i-1)*miniBatchSize + (1:miniBatchSize);
    batch = getBatch(data,batchIdx);
    if coder.internal.ndims(y) == 3
        y(:,:,batchIdx) = net.predict(batch);
    else
        y(:,batchIdx) = net.predict(batch);
    end
end
lastMiniBatchStart = coder.const(miniBatchSize*numMiniBatches + 1);
if lastMiniBatchStart <= nbatches
    lastBatch = getBatch(data,lastMiniBatchStart:nbatches);
    nremaining = nbatches - lastMiniBatchStart + 1;
    if coder.internal.ndims(y) == 3
        y(:,:,lastMiniBatchStart+(0:nremaining-1)) = net.predict(lastBatch);
    else
        y(:,lastMiniBatchStart + (0:nremaining-1)) = net.predict(lastBatch);
    end
end

end

function y = predictVarSizeBatchDim(net,data,miniBatchSize,nbatches)
coder.internal.prefer_const(miniBatchSize)

%crete an initial batch of size miniBatchSize, the actual number of batches
%can be less than minibatchSize at runtime.
if coder.internal.ndims(data) == 3
    batch = dlarray(zeros(size(data,1),size(data,2),miniBatchSize,'single'),'SCB');
    batch(:,:,1:min(nbatches,miniBatchSize)) = getBatch(data,1:min(nbatches,miniBatchSize));
else
    batch = dlarray(zeros(size(data,1),miniBatchSize,'single'),'CB');
    batch(:,1:min(nbatches,miniBatchSize)) = getBatch(data,1:min(nbatches,miniBatchSize));
end
ytemp = net.predict(batch);
if nbatches <= miniBatchSize
    % Actual number of batches is less than mini batch size, fetch the
    % relevant portion of output.
    if coder.internal.ndims(ytemp) == 3
        y = ytemp(:,:,1:nbatches);
    else
        y = ytemp(:,1:nbatches);
    end
else
    % We have at least miniBatchsize number of batches at runtime
    % Fill the results for first batch.
    if coder.internal.ndims(ytemp) == 3
        y = coder.nullcopy(dlarray(zeros(size(ytemp,1),size(ytemp,2),nbatches,'single'),'SCB'));
        y(:,:,1:miniBatchSize) = ytemp;
    else
        y = coder.nullcopy(dlarray(zeros(size(ytemp,1),nbatches,'single'),'CB'));
        y(:,1:miniBatchSize) = ytemp;
    end
    numMiniBatches = coder.internal.indexDivide(nbatches,miniBatchSize);
    % Form the result for remaining batches
    for i = 2:numMiniBatches
        % Note:  this loop is not executed when miniBatchSize <= nbatches < 2*miniBatchSize
        batchIdx = (i-1)*miniBatchSize + (1:miniBatchSize);
        batch = getBatch(data,batchIdx);
        if coder.internal.ndims(y) == 3
            y(:,:,batchIdx) = net.predict(batch);
        else
            y(:,batchIdx) = net.predict(batch);
        end
    end
    lastMiniBatchStart = miniBatchSize*numMiniBatches + 1;
    if lastMiniBatchStart <= nbatches
        % we don't know the exact number of batches that remain
        % but it is always less than minibatchSize. In code generation, 
        % network inference requires the size of batch dimension to be 
        % a constant, so we create batch of size minibatchSize by padding
        % with zeros.
        nremaining = nbatches - lastMiniBatchStart + 1;
        if coder.internal.ndims(data) == 3
            batch = dlarray(zeros(size(data,1),size(data,2),miniBatchSize,'single'),'SCB');
            batch(:,:,1:nremaining) = getBatch(data,lastMiniBatchStart:nbatches);
        else
            batch = dlarray(zeros(size(data,1),miniBatchSize,'single'),'CB');
            batch(:,1:nremaining) = getBatch(data,lastMiniBatchStart:nbatches);
        end
        ytemp = net.predict(batch);
        % Fetch the valid portion of the output.
        if coder.internal.ndims(y) == 3
            y(:,:,lastMiniBatchStart + (0:nremaining-1)) = ytemp(:,:,1:nremaining);
        else
            y(:,lastMiniBatchStart + (0:nremaining-1)) = ytemp(:,1:nremaining);
        end
    end
end
end

function batch = getBatch(data,batchIdx)
if coder.internal.ndims(data) == 2 %CB
    batch = data(:,batchIdx);
else
    batch = data(:,:,batchIdx);
end
end
