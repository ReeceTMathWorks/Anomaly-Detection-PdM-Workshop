function setupWorkshop()
%SETUPWORKSHOP Add workshop folders to the MATLAB path.
root = fileparts(mfilename("fullpath"));
spkgPath = fullfile(root, "Helper", "spkg");
matlab.internal.msgcat.setAdditionalResourceLocation(spkgPath);
addpath(genpath(root));

