function varargout = prepareLayerParamVec(numLayer, layerName, varNameList, varargin)
% prepareLayerParamVec Adjusts input parameters based on their types and lengths.
%
% This function processes a set of input parameters, which can be either
% scalars or vectors, and prepares them for use in a multi-layer context.
% The behavior depends on whether the parameters are scalars or vectors
% and if the vectors are of the same length.
% If all paramters are vectors with >1 length, ignore the numLayer. If parameter is
% scaler,  repeat it to create a vector of length equal to numLayer. If
% parameter is a vector, the length of the vector should be equal to
% numLayer.
%
% Parameters:
%   numLayer (scalar): The number of layers, which indicates the desired
%                      length for scalar parameters when repeated.
%   layerName (string scalar): The name of numLayer variable, used for error
%   message
%   varName (List): The list of layer parameter vector name, used for error message
%   varargin (cell array): A variable-length input argument list containing
%                          the parameters to process, each of which can be
%                          a scalar or a vector.
%
% Returns:
%   paramVec (cell array): A cell array where each element is a vector of
%                          parameters prepared according to the rules
%                          outlined in the function description.
% Example:
%   NumConvLayers = 2;
%   FilterSize = [3, 2];        % Vector specifying filter sizes for each layer
%   NumFilters = 32;            % Scalar specifying the number of filters (same for all layers)
%   ConvLayerStride = 2;        % Scalar specifying the stride for convolution layers
%   PoolLayerStride = 2;        % Scalar specifying the stride for pooling layers
%   PoolSize = 2;               % Scalar specifying the pooling size
% [filterSizeVec, numFiltersVec, convStrideVec, poolStrideVec, poolSizeVec] = ...
%     prepareLayerParamVec(NumConvLayers, "numConvLayers", ["FilterSize", "NumFilters", "ConvLayerStride", "PoolLayerStride", "PoolSize"], FilterSize, NumFilters, ConvLayerStride, PoolLayerStride, PoolSize);
% filterSizeVec=[3, 2]; numFiltersVec=[32, 32], convStrideVec=[2,2],
% poolStrideVec=[2,2], poolSizeVec=[2,2]


%   Copyright 2024 The MathWorks, Inc.


% Check if all layer parameters are vectors of the same length
    areAllVectors = all(cellfun(@(x) isvector(x) && numel(x) == numel(varargin{1}), varargin));
    
    if areAllVectors & length(varargin{1}) ~=1
        % Ignore number of layer variable
        varargout = varargin;
    else
        varargout = varargin;
        % Process each variable
        for i = 1:length(varargin)
            if isscalar(varargin{i})
                % Repelem the scalar to generate a vector of length 'a'
                varargout{i} = repelem(varargin{i}, numLayer);
            elseif isvector(varargin{i}) && numel(varargin{i}) ~= numLayer
                error(message("predmaint_anomaly:anomaly:errInvalidLayerParam", string(varNameList(i)), string(layerName)));
            end
        end
    end
end