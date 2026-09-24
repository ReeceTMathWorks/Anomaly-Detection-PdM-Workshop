function setupWorkshop()
%SETUPWORKSHOP Add workshop folders to the MATLAB path.
root = fileparts(mfilename("fullpath"));
addpath(genpath(root));

