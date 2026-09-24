function trainingCleanup(rngState, monitor)
arguments
rngState
monitor anomalyAPP.internal.app.modelmanager.utils.MonitorFactory = anomalyAPP.internal.app.modelmanager.utils.MonitorFactory.empty();
end

% Restore RNG
rng(rngState);

% Close/delete the monitor figure safely
try
    if ~isempty(monitor)
        for iMon = 1:numel(monitor)
            monitor(iMon).deleteCurrentFig();
        end
    end
catch ME
end
end
