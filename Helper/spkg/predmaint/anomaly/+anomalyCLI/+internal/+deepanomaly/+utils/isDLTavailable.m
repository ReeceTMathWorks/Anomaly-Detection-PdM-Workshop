function isDLTavailable()
% isDLTavailable - Check the availability of the Deep Learning Toolbox.
%
% This function checks whether the Deep Learning Toolbox is installed and 
% if a valid license is available for use. It uses a persistent variable to 
% cache the installation check result for efficiency.
%
%   This function will throw an error if the Deep Learning Toolbox is not available.
%
%   Copyright 2024 The MathWorks, Inc.
    persistent isInstalled;
    if isempty(isInstalled)
        isInstalled = ~isempty(ver('nnet'));
    end
% Check if there is a license for using PCT
    b = builtin('license','checkout','Neural_Network_Toolbox');
    result = b && isInstalled;
if ~result
    error(message("predmaint_anomaly:anomaly:errNoDeepLearningLicense"))
end
end