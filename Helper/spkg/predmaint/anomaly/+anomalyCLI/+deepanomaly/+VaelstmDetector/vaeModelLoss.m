function [loss,gradientsE,gradientsD] = vaeModelLoss(netE,netD,X)
% Forward through encoder.

%   Copyright 2025 The MathWorks, Inc.

[Z,mu,logSigmaSq] = forward(netE,X);

% Forward through decoder.
Y = forward(netD,Z);

% Calculate loss and gradients.
loss = elboLoss(Y,X,mu,logSigmaSq);
[gradientsE,gradientsD] = dlgradient(loss,netE.Learnables,netD.Learnables);
end



function loss = elboLoss(Y,T,mu,logSigmaSq)
% Reconstruction loss
reconstructionLoss = mse(Y,T);

% KL divergence
KL = -0.5 * sum(1 + logSigmaSq - mu.^2 - exp(logSigmaSq),1);
% loss
loss = reconstructionLoss + mean(KL);
end
