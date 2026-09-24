function outCurve = gprCurve(curveLength, scale) 
% GPRCURVE function generates a smooth curve of specified length and scale
% using the Gaussian Process Regression approach.

%   Copyright 2025 The MathWorks, Inc.

% Rasmussen, C. E., & Williams, C. K. I. (2006). Gaussian Processes for Machine Learning. MIT Press.

%% Generate a Gaussian Process Sample
% Define input points The range of x is picked to be [0, 10]. Depending on
% the curve length, the generated function might have (large curveLength) a
% large number of closely spaced samples with some small variations in the
% curve while a small curveLength will have a smoother curve due to the
% lower number of samples.
x = linspace(0, 10, curveLength)'; 

%% Define the covariance function (RBF Kernel) 
% 
% length-scale controls how quickly the function values can change with
% respect to the inputs. If length_scale is small, points need to be very
% close in x-space to be strongly correlated. This means wiggly functions,
% fast changes. If length-scale is large, even distant points are still
% correlated. This means smooth, slowly varying functions. This will be
% hardcoded to a value of 2.0.

% The parameter \sigma is a scaling factor that determines the output scale
% of the kernel function. Large \sigma Points in the input space will
% have more influence on each other, leading to larger values in the GP's
% predictions. Small \sigma: Points in the input space will have less
% influence on each other, leading to smaller values in the GP's
% predictions. Set \sigma to 1.0 to allow for only length_scale to be the
% controlling parameter

length_scale = 2.0; % Controls smoothness
sigma_f = 1.0; % Output variance
K = sigma_f^2 * exp(-pdist2(x, x).^2 / (2 * length_scale^2));

% Add some jitter to avoid numerical issues when decomposing the matrix.
jitter = 1e-6;
K = K + jitter * eye(curveLength);

%% Generate a random function sample from GP
outCurve = mvnrnd(zeros(size(x)), K)'; % Sample from multivariate normal

% Scale the output curve by the provided scale factor
outCurve = scale * normalize(outCurve, "range", [-1, 1]);

% LocalWords:  RBF
