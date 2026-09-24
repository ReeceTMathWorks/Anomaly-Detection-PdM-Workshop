classdef samplingLayer < nnet.layer.Layer
% SAMPLINGLAYER - Custom layer for Variational Autoencoders (VAEs).
%
% This class defines a custom layer for use in Variational Autoencoders (VAEs),
% implementing a sampling mechanism based on the mean and log-variance of the 
% latent variables. The layer supports both prediction and training phases.
%
% Syntax:
%   layer = samplingLayer()
%   layer = samplingLayer(Name=name)
%
% Description:
%   samplingLayer creates a custom layer for VAEs that performs sampling 
%   from a Gaussian distribution defined by the mean and log-variance 
%   of the latent variables. This layer is useful for the reparameterization 
%   trick in VAEs, allowing gradients to flow through the sampling process.
%
% Inputs:
%   Name - (optional) A name for the layer, specified as a string. 
%
% Outputs:
%   layer - An instance of the samplingLayer class.
%
% Properties:
%   Name        - The name of the layer.
%   Type        - The type of the layer, set to "Sampling".
%   Description - A brief description of the layer's functionality.
%   OutputNames - Names of the outputs, specified as ["out" "mean" "log-variance"].
%
% Methods:
%   predict - Perform forward pass through the layer.
%             [Z, mu, logSigmaSq] = predict(~, X)
%
%             Inputs:
%               X - Concatenated input data where X(1:K,:) and 
%                   X(K+1:end,:) correspond to the mean and 
%                   log-variances, respectively, and K is the number 
%                   of latent channels.
%
%             Outputs:
%               Z          - Sampled output.
%               mu         - Mean vector.
%               logSigmaSq - Log-variance vector.
%
% Example:
%   % Create a sampling layer with a specified name.
%   layer = samplingLayer('Name', 'vae_sampling')
%
% Note:
%   This layer is specifically designed for use in the context of 
%   Variational Autoencoders and may not be suitable for other types of models.
%
%#codegen

% Copyright 2024-2026 The MathWorks, Inc.
    methods
        function layer = samplingLayer(args)
            % layer = samplingLayer creates a sampling layer for VAEs.
            %
            % layer = samplingLayer(Name=name) also specifies the layer 
            % name.

            % Parse input arguments.
            arguments
                args.Name = "";
            end

            % Layer properties.
            layer.Name = args.Name;
            layer.Type = "Sampling";
            layer.Description = "Mean and log-variance sampling";
            layer.OutputNames = ["out" "mean" "log-variance"];
        end

        function [Z,mu,logSigmaSq] = predict(~,X)
            % predict - Deterministic forward pass at inference time.
            % Returns the mean of the latent distribution without sampling.

            numLatentChannels = size(X,1)/2;

            mu = X(1:numLatentChannels,:);
            logSigmaSq = X(numLatentChannels+1:end,:);

            Z = mu;
        end

        function [Z,mu,logSigmaSq] = forward(~,X)
            % forward - Stochastic forward pass at training time.
            % Samples using the reparameterization trick for gradient flow.

            numLatentChannels = size(X,1)/2;
            miniBatchSize = size(X,2);

            mu = X(1:numLatentChannels,:);
            logSigmaSq = X(numLatentChannels+1:end,:);

            epsilon = randn(numLatentChannels,miniBatchSize,"like",X);
            sigma = exp(.5 * logSigmaSq);
            Z = epsilon .* sigma + mu;
        end

    end
    
end
