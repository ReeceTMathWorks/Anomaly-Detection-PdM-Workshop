function tf = isPCTavailable()
% isPCTavailable - Check the availability of the Parallel Computing Toolbox.
%
% This function determines whether the Parallel Computing Toolbox is installed 
% and if a valid license is available for its use. It employs a persistent 
% variable to store the result of the installation check for improved efficiency.
%   The function does not throw an error if the toolbox is unavailable; it simply returns false.
%
%   Copyright 2024 The MathWorks, Inc.

% Check if the Parallel Computing Toolbox is installed
persistent RESULT;
if isempty(RESULT)
    RESULT = ~isequal(exist('parallel.Cluster', 'class'), 0);
end
tf = RESULT;
% Check if there is a license for using PCT
tf = tf && license('test', 'Distrib_Computing_Toolbox') == 1;
end