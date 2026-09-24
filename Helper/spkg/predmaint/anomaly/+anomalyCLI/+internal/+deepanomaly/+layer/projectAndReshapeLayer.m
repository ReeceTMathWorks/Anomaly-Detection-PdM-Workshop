classdef projectAndReshapeLayer < nnet.layer.Layer ...
        & nnet.layer.Formattable ...
        & nnet.layer.Acceleratable
% projectAndReshapeLayer - Custom layer for projecting and reshaping inputs.
%
% This class defines a custom neural network layer that projects input data
% using learnable weights and biases, then reshapes the output to a specified
% size. It is useful for tasks that require dimensionality reduction or expansion
% followed by reshaping, such as in convolutional neural networks.
%
% Syntax:
%   layer = projectAndReshapeLayer(outputSize)
%   layer = projectAndReshapeLayer(outputSize, Name=name)
%
% Description:
%   projectAndReshapeLayer creates a custom layer that first projects the input
%   data using a fully connected operation and then reshapes it to the specified 
%   output size. The layer includes learnable weights and biases initialized using 
%   the Glorot method and zeros, respectively.
%
% Inputs:
%   outputSize - The desired output size, specified as a vector.
%   Name       - (optional) A name for the layer, specified as a string.
%
% Outputs:
%   layer - An instance of the projectAndReshapeLayer class.
%
% Properties:
%   OutputSize - The size to which the input is reshaped.
%   Weights    - Learnable weights for the projection.
%   Bias       - Learnable bias for the projection.
%
% Methods:
%   initialize - Initializes the layer's learnable parameters.
%                layer = initialize(layer, layout)
%
%   predict    - Forward pass through the layer.
%                Z = predict(layer, X)
%
% Example:
%   % Create a project and reshape layer with a specified output size.
%   layer = projectAndReshapeLayer([28, 28, 1], 'Name', 'project_reshape')
%
%   % Initialize the layer with a given data layout.
%   layout = networkDataLayout(["SCB"], [28, 1, 32]);
%   layer = initialize(layer, layout);
%
%#codegen

% Copyright 2024-2026 The MathWorks, Inc.
    properties
        % Layer properties.
        OutputSize
    end

    properties (Learnable)
        % Layer learnable parameters.

        Weights
        Bias
    end

    methods
        function layer = projectAndReshapeLayer(outputSize,NameValueArgs)
            % layer = projectAndReshapeLayer(outputSize)
            % creates a projectAndReshapeLayer object that projects and
            % reshapes the input to the specified output size.
            %
            % layer = projectAndReshapeLayer(outputSize,Name=name)
            % also specifies the layer name.

            % Parse input arguments.
            arguments
                outputSize
                NameValueArgs.Name = "";
            end

            % Set layer name.
            name = NameValueArgs.Name;
            layer.Name = name;

            % Set layer description.
            layer.Description = "Project and reshape to size " + ...
                join(string(outputSize));

            % Set layer type.
            layer.Type = "Project and Reshape";

            % Set output size.
            layer.OutputSize = outputSize;
        end

        function layer = initialize(layer,layout)
            % layer = initialize(layer,layout) initializes the layer
            % learnable parameters.
            %
            % Inputs:
            %         layer  - Layer to initialize
            %         layout - Data layout, specified as a 
            %                  networkDataLayout object
            %
            % Outputs:
            %         layer - Initialized layer

            % Layer output size.
            outputSize = layer.OutputSize;

            % Initialize fully connect weights.
            if isempty(layer.Weights)

                % Find number of channels.
                idx = finddim(layout,"C");
                numChannels = layout.Size(idx);

                % Initialize using Glorot.
                sz = [prod(outputSize) numChannels];
                numOut = prod(outputSize);
                numIn = numChannels;
                layer.Weights = initializeGlorot(sz,numOut,numIn);
            end

            % Initialize fully connect bias.
            if isempty(layer.Bias)

                % Initialize with zeros.
                layer.Bias = initializeZeros([prod(outputSize) 1]);
            end
        end

        function Z = predict(layer, X)
            % Forward input data through the layer at prediction time and
            % output the result.
            %
            % Inputs:
            %         layer - Layer to forward propagate through
            %         X     - Input data, specified as a formatted dlarray
            %                 with a "C" and optionally a "B" dimension.
            % Outputs:
            %         Z     - Output of layer forward function returned as
            %                 a formatted dlarray with format "SCB".

            % Fully connect.
            weights = layer.Weights;
            bias = layer.Bias;
            X = fullyconnect(X,weights,bias);

            % Reshape.
            outputSize = layer.OutputSize;
            Z = reshape(X,outputSize(1),outputSize(2),[]);
            Z = dlarray(Z,"SCB");
        end
    end

    methods(Static)
         function n = matlabCodegenNontunableProperties(~)
             n = {'OutputSize'};
         end
        
    end
end


function weights = initializeGlorot(sz,numOut,numIn,className)

arguments
    sz
    numOut
    numIn
    className = 'single'
end

Z = 2*rand(sz,className) - 1;
bound = sqrt(6 / (numIn + numOut));

weights = bound * Z;
weights = dlarray(weights);

end


function parameter = initializeZeros(sz,className)

arguments
    sz
    className = 'single'
end

parameter = zeros(sz,className);
parameter = dlarray(parameter);

end
