function outCurve = cubicSplineCurve(curveLength, scale) 
% CUBICSPLINECURVE generates a smooth curve of specified length and scale
% using the Cubic Spline approach.

%   Copyright 2025 The MathWorks, Inc.

% Generate random control points
num_Ctrl_Points = 10;
x = rand(1, num_Ctrl_Points) * 10;
y = rand(1, num_Ctrl_Points) * 10;

% Sort x values to avoid issues with splines
[x, sortIdx] = sort(x);
y = y(sortIdx);

% Create cubic spline
t = linspace(min(x), max(x), curveLength)';
y_spline = spline(x, y, t);

% normalize range and scale the curve
outCurve = scale * normalize(y_spline, "range", [-1, 1]);
