function y = miniBatchPredictTCB(net,data,miniBatchSize)
% This is an internal utility and may be removed in future

%   Copyright 2026 The MathWorks, Inc.

% Inputs: net - a dlnetwork
%      : data - 
%        1. a 3D single precision matrix, where the first dimension is
%           time, second dimension is the channels and third dimension is the
%           batch, ie data is organized in TCB format.
%        2. A cell array containing 2D single precision matrices. Each
%           matrix represents a batch stored in TC format.
%      : miniBatchSize - input data is grouped into batches of size
%           miniBatchSize and network inference is run on each batch.
%#codegen

coder.internal.prefer_const(miniBatchSize);
if iscell(data)   
    nbatches = coder.internal.indexInt(length(data));
else
    nbatches = coder.internal.indexInt(size(data,3));
end
if isnumeric(data)
    m = coder.internal.indexInt(size(data,1));
    n = coder.internal.indexInt(size(data,2));
else
    m = coder.internal.indexInt(size(data{1},1));
    n = coder.internal.indexInt(size(data{1},2));
end
iminiBatchSize = coder.internal.indexInt(miniBatchSize);
numMiniBatches = coder.internal.indexDivide(nbatches,iminiBatchSize);
% we are making a strong assumption that the output from the predict method
% has the same size as input. This hold's true for the detectors we use.
y = coder.nullcopy(data);

for i = 1:numMiniBatches
    batchIdx = (i-1)*iminiBatchSize + (1:iminiBatchSize);
    if isnumeric(data)
        batch = data(:,:,batchIdx);
    else
        batch = coder.nullcopy(zeros(m,n,iminiBatchSize,"like",data{1}));
        begin = batchIdx(1);
        for j = 1:iminiBatchSize
            batch(:,:,j) = data{begin + j - 1};
        end
    end
    batchRes= net.predict(dlarray(batch,'TCB'));
    % Network returns the output in CBT format, convert it into TCB to
    % match input dimensions
    res = permute(extractdata(batchRes),[3 1 2]); % CBT --> TCB
    if isnumeric(data)
        y(:,:,batchIdx) = res;
    else
        begin = batchIdx(1);
        for j = 1:iminiBatchSize
            y{begin + j - 1} = res(:,:,j);
        end

    end

end
lastMiniBatchStart = iminiBatchSize*numMiniBatches + 1;
if lastMiniBatchStart <= nbatches
    nremaining = nbatches - lastMiniBatchStart + 1;
    if coder.internal.isConst(nremaining)
        % we know the exact number of windows that remain,
        % group them to form a (smaller) minibatch and run
        % inference.
        if isnumeric(data)
            lastMiniBatch = data(:,:,lastMiniBatchStart:end);
        else
            lastMiniBatch = coder.nullcopy(zeros(m,n,nremaining,"like",data{1}));
            for i = 1:nremaining
                 lastMiniBatch(:,:,i) = data{lastMiniBatchStart+i-1};
            end
        end
    else
        % we don't know the exact number of batches that remain
        % but it is always less than minibatchSize. In code generation, 
        % network inference requires the size of batch dimension to be 
        % a constant, so we create batch of size minibatchSize by padding
        % with zeros.
        if isnumeric(data)
            lastMiniBatch = zeros(m,n,iminiBatchSize,"like",data);
            lastMiniBatch(:,:,1:nremaining) = data(:,:,lastMiniBatchStart:end);
        else
            lastMiniBatch = zeros(m,n,iminiBatchSize,"like",data{1});
            for i = 1:nremaining
                lastMiniBatch(:,:,i) = data{lastMiniBatchStart+i-1};
            end
        end
    end
     
    lastRes = net.predict(dlarray(lastMiniBatch,'TCB'));
    % Extract only the valid portion of the output.
    lastResReq = extractdata(lastRes(:,1:nremaining,:)); 
    lastResD = permute(lastResReq,[3 1 2]); %CBT --> TCB
    if isnumeric(data)
        y(:,:,lastMiniBatchStart + (0:nremaining-1)) = lastResD;
    else
        begin = lastMiniBatchStart;
        for j = 1:nremaining
            y{begin+j-1} = lastResD(:,:,j);
        end
    end
end
end
