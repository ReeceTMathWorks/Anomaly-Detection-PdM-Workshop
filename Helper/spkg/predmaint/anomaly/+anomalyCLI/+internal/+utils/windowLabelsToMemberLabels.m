function [memberLabels, memberScores, memberIndex] = windowLabelsToMemberLabels(winScores, numWindows, anomalousWindowPercentage, threshold)
%#codegen

%   Copyright 2026 The MathWorks, Inc.

coder.internal.prefer_const(anomalousWindowPercentage, threshold);

numCells = coder.internal.indexInt(numel(numWindows));
offset = coder.internal.indexInt(0);

memberLabels = coder.nullcopy(false(numCells, 1));
memberScores = coder.nullcopy(zeros(numCells, 1, "like", winScores));
memberIndex = coder.nullcopy(zeros(numCells, 1));

% Force column orientation so codegen can resolve indexing shape for
% variable-size inputs.
winScores = winScores(:);

for i = 1:numCells
    nWin = numWindows(i);
    cellScores = winScores(offset+1:offset+nWin);
    pctCutoff = prctile(cellScores, 100 - anomalousWindowPercentage);
    topScores = cellScores(cellScores >= pctCutoff);
    memberScores(i) = min(topScores);
    memberLabels(i) = sum(cellScores > threshold) / double(nWin) >= anomalousWindowPercentage / 100;
    memberIndex(i) = double(i);
    offset = offset + nWin;
end
end
