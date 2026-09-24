function pth = getAppRoot()
%GETAPPROOT()
%
%Utility to return the root directory of the tsadapp, used to determine
%resource location when the app is used as an add-on. 

% Copyright 2026 The MathWorks, Inc.

ft = which("anomalyAPP.internal.app.TimeSeriesAnomalyDetector", "-all");
pth = regexprep(ft{1},['\',filesep,'\+app\',filesep,'TimeSeriesAnomalyDetector\.m'],'');

end
