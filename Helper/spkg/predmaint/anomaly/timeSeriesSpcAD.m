function detector = timeSeriesSpcAD(numChannels, options)
%   Run "doc timeSeriesSpcAD" for more information.

%   Copyright 2025-2026 The MathWorks, Inc.

  arguments
    numChannels (1,1) {mustBeUnderlyingType(numChannels, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1
    options.WindowLength (1,1)  {mustBeUnderlyingType(options.WindowLength, ["single","double"]), mustBeNumeric, mustBeInteger, mustBePositive} = 1
    options.Method (1,1) string {mustBeMember(options.Method, ["individual","ewma"])} = "individual"
    options.Lambda (1,1) {mustBeUnderlyingType(options.Lambda, ["single","double"]), mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive, mustBeLessThanOrEqual(options.Lambda,1.0)} = 0.4
    options.DetectionRules (1,:) string {mustBeMember(options.DetectionRules, ["n","n1","n2","n3","n4","n5","n6","n7","n8","we","we1","we2","we3","we4","we5","we6","we7","we8","we9","we10"])} = "n1"
    options.Level (1,1) {mustBeUnderlyingType(options.Level, ["single","double"]), mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 3.0
  end
  options = namedargs2cell(options);
  detector = anomalyCLI.controlchart.TimeSeriesSPCDetector(numChannels, options{:});
end
