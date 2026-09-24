function varargout = timeSeriesAnomalyDetector(varargin)
%   Run "doc timeSeriesAnomalyDetector" for more information.

%   Copyright 2024-2026 The MathWorks, Inc.

    narginchk(0,1);

    % Check for required toolboxes and licenses.
    [ready, msgID] = anomalyAPP.internal.utils.checkRequiredToolboxes;
    if ~ready
        error(message(msgID, mfilename));
    end

    % Create and launch the app.
    if nargin == 1
        % A session name was provided. Make sure we can find the session
        % file and launch the app with the session.
        sessionFile = varargin{1};
        if ~(isStringScalar(sessionFile) || ischar(sessionFile))
            error(message('predmaint_anomaly:anomaly_app:errSessionNameNotString'));
        end

        % If the session file does not already contain the extension
        % '.mldatx', add it.
        [fPath,~,ext] = fileparts(sessionFile);
        if strlength(ext) == 0
            sessionFile = sessionFile+".mldatx";
        end

        % The file may not be in the current folder, so we should get the
        % path with 'which' if the path was not provided
        if strlength(fPath) == 0
            filePath = which(sessionFile);
        else
            filePath = sessionFile;
        end
        if isempty(filePath) || ~isfile(filePath)
            error(message('predmaint_anomaly:anomaly_app:errCannotFindSessionFile'));
        end

        hApp = anomalyAPP.internal.app.TimeSeriesAnomalyDetector(SessionFile=filePath);
    else
        hApp = anomalyAPP.internal.app.TimeSeriesAnomalyDetector;
    end

    if nargout > 0
        varargout{1} = hApp;
    end
end
