function createDetectorOverviews()
% Internal file to recreate the overview figure data that is used by each
% handler class. Generates two MAT files that can be moved to the resources directory. This is not used by the App.

%   Copyright 2025 The MathWorks, Inc.

detectorOverview = dictionary();
detectorOverview("cnnae") = {cnnaeOverview()};
detectorOverview("lstmae") = {lstmaeOverview()};
detectorOverview("lstmf") = {lstmfOverview()};
detectorOverview("tcn") = {tcnOverview()};
detectorOverview("deepant") = {deepantOverview()};
detectorOverview("usad") = {usadOverview()};
detectorOverview("vaelstm") = {vaelstmOverview()};

detectorOverview("spc") = {spcOverview()};
detectorOverview("lof") = {lofOverview()};
detectorOverview("ocsvm") = {ocsvmOverview()};
detectorOverview("iforest") = {iforestOverview()};
detectorOverview("rrcforest") = {rrcforestOverview()};

save detectorOverview detectorOverview

detectorOverview = detectorOverview.remove("cnnae");
detectorOverview = detectorOverview.remove("lstmae");
detectorOverview = detectorOverview.remove("lstmf");
detectorOverview = detectorOverview.remove("tcn");
detectorOverview = detectorOverview.remove("deepant");
detectorOverview = detectorOverview.remove("usad");
detectorOverview = detectorOverview.remove("vaelstm");
save detectorOverviewML detectorOverview
end

function out = cnnaeOverview()
d = deepSignalAnomalyDetector(1, "convautoencoder");
out = d.getModel();
end

function out = lstmaeOverview()
d = deepSignalAnomalyDetector(1, "lstmautoencoder");
out = d.getModel();
end

function out = lstmfOverview()
d = deepSignalAnomalyDetector(1, "lstmforecaster");
out = d.getModel();
end

function out = tcnOverview()
d = tcnAD(1);
out = d.Dlnet;
end

function out = deepantOverview()
d = deepantAD(1);
out = d.Dlnet;
end

function out = usadOverview()
d = usAD(1);
out = d.Dlnet;
end

function out = vaelstmOverview()
d = vaelstmAD(1);
out = d.Dlnet;
end

function out = spcOverview()
data = load("sineWaveAnomalyData.mat");

%%
spcObj = timeSeriesSpcAD(3, WindowLength=20, Method="ewma");
spcObj = spcObj.train(data.sineWaveNormal);
spcObj = spcObj.updateDetector(DetectionRules=["n1"]);
windowResults = detect(spcObj, data.sineWaveAbnormal{2});

[data, names] = convertDataToCellArray(data.sineWaveAbnormal{2});

% Batch-mean data plot.
Y = computeBatchMeans(data, spcObj.WindowLength, spcObj.Stride);

Z = spcObj.computeEWMA(Y, spcObj.Lambda, spcObj.CenterLine);

[UCL,LCL] = computeChartLimits(spcObj.CenterLine, spcObj.StandardError, spcObj.Level);
CL = spcObj.CenterLine;
windowLength = spcObj.WindowLength;
method = spcObj.Method;
out = {CL, LCL, method, names, UCL, windowLength, windowResults, Z};
end

function out = lofOverview()

% Generate synthetic LOF-like data
rng(42); % reproducibility

% Create clusters
cluster1 = randn(100,2)*0.5 + [2 2];
cluster2 = randn(100,2)*0.5 + [6 6];
outliers = [0 6; 8 1; 5 8; 7 0];
data = [cluster1; cluster2];

x = data(:,1);
y = data(:,2);

% Density background
[Xgrid,Ygrid] = meshgrid(linspace(-1,10,100));
Z = mvksdensity([x y],[Xgrid(:) Ygrid(:)]);
Z = reshape(Z,size(Xgrid));

out =  {outliers, x, y, Z, Xgrid, Ygrid};
end

function out = ocsvmOverview()
rng(42); % For reproducibility

% Generate unimodal data
rng(42);
n = 200;
X = randn(n,2) * 0.5;

% Fit one-class SVM with Gaussian (RBF) kernel
mdl = fitcsvm(X, ones(n,1), ...
    'KernelFunction', 'rbf', ...
    'KernelScale', 'auto', ...
    'Standardize', true, ...
    'OutlierFraction', 0.05);

% Create grid for visualization
[x1Grid,x2Grid] = meshgrid(linspace(-3,3,200), linspace(-3,3,200));
XGrid = [x1Grid(:), x2Grid(:)];

% Predict scores for grid and original points
[~,scoreGrid] = predict(mdl, XGrid);
[~,scoreData] = predict(mdl, X);

insideIdx = scoreData >= 0; % Inside boundary
outsideIdx = scoreData < 0; % Outside boundary

out =  {insideIdx, outsideIdx, scoreGrid, X, x1Grid, x2Grid};
end

function out = iforestOverview()
X = (1:10)';
anomaly = 15;
maxDepth = 4;

X = [X; anomaly];

rng(42);
tree = buildIsolationTree(X, 0, maxDepth, anomaly);
[~, nodes, edges] = assignIdsAndCollect(tree);

anomalyLeafId = find([nodes.isLeaf] & [nodes.containsAnomaly], 1, 'first');

G = digraph(edges(:,1), edges(:,2));

nodeLabels = repmat({''}, numel(nodes), 1);
for i = 1:numel(nodes)
    if nodes(i).isLeaf
        if i == anomalyLeafId
            nodeLabels{i} = '[Anomaly]';
        else
            nodeLabels{i} = '';
        end
    end
end

out = {G, nodeLabels, anomalyLeafId};
end

function out = rrcforestOverview()
anomaly   = [3 3];
maxDepth  = 4;
minLeaf   = 2;
showDepth = false;

rng(42);
X = [mvnrnd([ 2  2], 0.35*eye(2), 100);
    mvnrnd([-2 -2], 0.35*eye(2), 100)];

X = [X; anomaly];

tree = buildRRCFTree(X, 0, maxDepth, minLeaf, anomaly);

[~, nodes, edges] = assignIdsAndCollectRRC(tree);

anomalyLeafId = find([nodes.isLeaf] & [nodes.containsAnomaly], 1, 'first');

nodeLabels = repmat({''}, numel(nodes), 1);
for i = 1:numel(nodes)
    if nodes(i).isLeaf
        if i == anomalyLeafId
            nodeLabels{i} = '[Anomaly]';
        else
            nodeLabels{i} = '';
        end
    end
end

G = digraph(edges(:,1), edges(:,2));

out =  {anomalyLeafId, G, nodeLabels};
end

function [data, varnames] = convertDataToCellArray(data)
if iscell(data)
    [~,nc] = size(data{1});
else
    [~,nc] = size(data);
end

varnames = m("predmaint_anomaly:anomaly:strChannel") + " " + (1:nc);
end


function Y = computeBatchMeans(X, b, s)
% Columnwise batch means of matrix X with batch size b and stride s.
[nr,nc] = size(X);
nb = floor((nr+s-b)/s); % Number of batches.

Y = zeros(nb, nc, "like", X);
for i = 1:nb
    I = (i-1)*s + (1:b); % Rows of kth batch.
    Y(i,:) = mean(X(I,:), 1, "omitmissing"); % Mean of each column for rows I.
end
end

function [UCL,LCL] = computeChartLimits(CL, SE, level)
% Computes the control chart limits of each channel from the control chart
% parameters.
UCL = CL + level*SE;
LCL = CL - level*SE;
end

function node = buildIsolationTree(X, depth, maxDepth, anomaly)
node = struct('isLeaf',false,'splitValue',[],'left',[], 'right',[], ...
    'containsAnomaly',false,'id',NaN,'depth',depth);
if depth >= maxDepth || numel(X) <= 1 || min(X) == max(X)
    node.isLeaf = true;
    node.containsAnomaly = any(X == anomaly);
    return;
end
sv = min(X) + rand()*(max(X) - min(X));
node.splitValue = sv;
L = X < sv; R = ~L;
node.left  = buildIsolationTree(X(L), depth+1, maxDepth, anomaly);
node.right = buildIsolationTree(X(R), depth+1, maxDepth, anomaly);
node.containsAnomaly = node.left.containsAnomaly || node.right.containsAnomaly;
end

function [node, nodes, edges] = assignIdsAndCollect(node)
nodes = struct('id',{},'isLeaf',{},'splitValue',{},'containsAnomaly',{},'depth',{});
edges = zeros(0,2);
nextId = 1;

    function nid = dfsAssign(n)
        nid = nextId; nextId = nextId + 1;
        n.id = nid;
        nodes(end+1) = struct('id',nid,'isLeaf',n.isLeaf,'splitValue',n.splitValue, ...
            'containsAnomaly',n.containsAnomaly,'depth',n.depth);
        if ~n.isLeaf
            lid = dfsAssign(n.left);
            rid = dfsAssign(n.right);
            edges(end+1,:) = [nid, lid];
            edges(end+1,:) = [nid, rid];
            n.left.id  = lid;
            n.right.id = rid;
        end
        node = n;
    end

dfsAssign(node);
end

function node = buildRRCFTree(X, depth, maxDepth, minLeaf, anomaly)
[n,d] = size(X);
node = struct('isLeaf',false,'splitDim',[], 'splitValue',[], ...
    'left',[],'right',[], ...
    'containsAnomaly',false, 'id',NaN, 'depth',depth);

spans = max(X,[],1) - min(X,[],1);
if depth >= maxDepth || n <= minLeaf || all(spans <= eps)
    node.isLeaf = true;
    node.containsAnomaly = any(ismemberRowTol(X, anomaly, 1e-12));
    return;
end

w = spans; w = w / sum(w);
if any(isnan(w)) || all(w==0)
    node.isLeaf = true;
    node.containsAnomaly = any(ismemberRowTol(X, anomaly, 1e-12));
    return;
end
splitDim = randsample(1:d, 1, true, w);

xmin = min(X(:,splitDim)); xmax = max(X(:,splitDim));
if abs(xmax - xmin) <= eps
    node.isLeaf = true;
    node.containsAnomaly = any(ismemberRowTol(X, anomaly, 1e-12));
    return;
end

maxTrials = 20;
for t = 1:maxTrials
    splitValue = xmin + rand()*(xmax - xmin);
    leftMask  = X(:,splitDim) <  splitValue;
    rightMask = ~leftMask;
    if any(leftMask) && any(rightMask)
        break;
    end
end
if ~(any(leftMask) && any(rightMask))
    node.isLeaf = true;
    node.containsAnomaly = any(ismemberRowTol(X, anomaly, 1e-12));
    return;
end

node.splitDim   = splitDim;
node.splitValue = splitValue;

node.left  = buildRRCFTree(X(leftMask,:),  depth+1, maxDepth, minLeaf, anomaly);
node.right = buildRRCFTree(X(rightMask,:), depth+1, maxDepth, minLeaf, anomaly);
node.containsAnomaly = node.left.containsAnomaly || node.right.containsAnomaly;
end

function [node, nodes, edges] = assignIdsAndCollectRRC(node)
nodes = struct('id',{},'isLeaf',{},'splitDim',{},'splitValue',{}, ...
    'containsAnomaly',{},'depth',{});
edges = zeros(0,2);
nextId = 1;

    function nid = dfs(n)
        nid = nextId; nextId = nextId + 1;
        n.id = nid;
        nodes(end+1) = struct('id',nid,'isLeaf',n.isLeaf, ...
            'splitDim',n.splitDim,'splitValue',n.splitValue, ...
            'containsAnomaly',n.containsAnomaly,'depth',n.depth);
        if ~n.isLeaf
            lid = dfs(n.left);
            rid = dfs(n.right);
            edges(end+1,:) = [nid, lid];
            edges(end+1,:) = [nid, rid];
            n.left.id  = lid;
            n.right.id = rid;
        end
        node = n;
    end
dfs(node);
end

function tf = ismemberRowTol(Arow, B, tol)
if isempty(B), tf = false; return; end
tf = any(all(abs(B - Arow) <= tol, 2));
end

% Local Helper
function s = m(id, varargin)

% Reads string with the given ID from its resource bundle.
s = string(message(id, varargin{:}));
end
