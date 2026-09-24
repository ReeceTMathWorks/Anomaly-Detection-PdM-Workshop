function [ready, msgID, varargout] = checkRequiredToolboxes()
%CHECKREQUIREDTOOLBOXES Check if the toolboxes required by the Time Series
%Anomaly Detection support package are installed and available.

% This function will handle two cases
% - is the base product "PMT" installed.
% - is the required for product "DLT" installed.

% Copyright 2025 The MathWorks, Inc.

% To limit the number of calls to ver().
persistent isToolboxPresent

% Check if each required toolbox is installed.
toolboxDirs = ["predmaint", "stats", "signal", "ident"];

dltDir = "nnet";

% Default assignment for DLT presence if nargout is 3 and there is an error
% during the PMT license checkout phase.
varargout{1} = 0;
%% These toolboxes are required for the support package to work
if isempty(isToolboxPresent)
    for i = 1:numel(toolboxDirs)
        isToolboxPresent(i) = ~isempty(ver(toolboxDirs(i)));
    end
end

% Check if a license for each required toolbox is available.
products = [ ...
    "pred_maintenance_toolbox", "statistics_toolbox", ...
    "signal_toolbox", "identification_toolbox"];
msgIDs = [ ...
    "predmaint:general:errNoPredmaintLicense", "predmaint:general:errNoStatsLicense", ...
    "predmaint:general:errNoSignalLicense", "predmaint:general:errNoIdentLicense"];
msgID = "";
ready = true;
for i = 1:numel(toolboxDirs)
    isToolboxAvailable = isToolboxPresent(i) && license('test', products(i));
    % All toolboxes need to be installed and available.
    ready = ready && isToolboxAvailable;
    if ~ready
        msgID = msgIDs(i);
        return;
    end
end

[status, ~] = license('checkout','Pred_Maintenance_Toolbox');
if ~status
    error(message('predmaint:general:errLicenseCheckoutFailure'));
end

%% DLT is required to enable DL based models in the App
if nargout == 3

    isDLTPresent = ~isempty(ver(dltDir));

    % Check if a license for each required toolbox is available.
    products = "neural_network_toolbox";

    isDLTPresent = isDLTPresent && license('test', products);

    dltAvailability = isDLTPresent;

    [status, ~] = license('checkout','neural_network_toolbox');

    dltAvailability = dltAvailability && status;
   
    varargout{1} = dltAvailability;
end

% LocalWords:  PMT DLT pred DL
