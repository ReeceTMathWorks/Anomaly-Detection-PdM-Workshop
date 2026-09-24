function [loss1, loss2, gradientsE, gradientsD] = usadModelLoss(netE, netD1, netD2, X, epoch, ObservationWindowLength, numChannel, minibatchsize, isAE1)
%Forward pass through all the nets

%   Copyright 2025 The MathWorks, Inc.

Z = forward(netE, X);
W1 = forward(netD1, Z);
W2 = forward(netD2, Z);

%Reshape W1 for encoder
W1 = reshape(W1, [ObservationWindowLength, numChannel, minibatchsize]);
W1 = dlarray(W1, 'SCB');
W3 = forward(netD2, forward(netE,W1));

%Reshape W2 and W3 to compute the losses
W2 = reshape(W2, [ObservationWindowLength, numChannel, minibatchsize]);
W2 = dlarray(W2, 'SCB');

W3 = reshape(W3, [ObservationWindowLength, numChannel, minibatchsize]);
W3 = dlarray(W3, 'SCB');

%Calculate losses based on the equation given in the research paper
loss1 = (1/epoch)*mean((X(:)-W1(:)).^2) + (1-1/epoch)*mean((X(:)-W3(:)).^2);
loss2 = (1/epoch)*mean((X(:)-W2(:)).^2) - (1-1/epoch)*mean((X(:)-W3(:)).^2);

if isAE1
    [gradientsE, gradientsD] = dlgradient(loss1, netE.Learnables, netD1.Learnables);
else
    [gradientsE, gradientsD] = dlgradient(loss2, netE.Learnables, netD2.Learnables);
end
end
