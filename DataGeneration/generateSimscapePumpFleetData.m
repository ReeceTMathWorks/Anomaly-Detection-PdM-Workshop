function generateSimscapePumpFleetData(opts)
%GENERATESIMSCAPEPUMPFLEETDATA Generate workshop data from a Simscape pump plant.
%
% This generator replaces the first-pass relabeled seminar data with a
% synthetic engineering dataset. A compact Simscape Fluids model supplies
% pressure and flow dynamics. MATLAB post-processing converts those plant
% outputs into realistic fleet telemetry channels for anomaly detection.
%
% Name-value options:
%   TrainDetectors - train and save TSAD detector checkpoints (default true)
%   NumTrainSamples - normal training samples per asset (default 1200)
%   NumTestSamples - labeled test samples per selected asset (default 1200)
%
% Copyright 2026 The MathWorks, Inc.

arguments
    opts.TrainDetectors (1,1) logical = true
    opts.NumTrainSamples (1,1) double {mustBeInteger,mustBePositive} = 1200
    opts.NumTestSamples (1,1) double {mustBeInteger,mustBePositive} = 1200
end

rng(42)

scriptFolder = fileparts(mfilename("fullpath"));
workshopRoot = fileparts(scriptFolder);
model = "SimscapePumpDataPlant";
modelFile = fullfile(scriptFolder,model + ".slx");
if ~isfile(modelFile)
    error("Missing Simscape plant model: %s",modelFile)
end
open_system(modelFile)

nAssets = 28;
nChannels = 38;
nTrain = opts.NumTrainSamples;
nTest = opts.NumTestSamples;
assetNames = makeAssetNames(nAssets);
selectedTestAssetIdx = [1 19 28];
selectedTestAssets = assetNames(selectedTestAssetIdx)';
channelNames = makeChannelNames();

trainData = cell(nAssets,1);
assetParameters = struct([]);

disp("Generating Simscape-backed normal training data...")
for k = 1:nAssets
    params = makeAssetParameters(k);
    if k == 1
        assetParameters = repmat(params,nAssets,1);
    end
    assetParameters(k) = params;
    [plant, command] = simulatePlant(model,nTrain,params,[]);
    trainData{k} = synthesizeTelemetry(plant,command,params,[],nChannels);
end

testData = cell(numel(selectedTestAssets),1);
testLabels = cell(numel(selectedTestAssets),1);
testFaultTables = cell(numel(selectedTestAssets),1);
disp("Generating Simscape-backed labeled test data...")
for k = 1:numel(selectedTestAssets)
    assetIdx = selectedTestAssetIdx(k);
    params = assetParameters(assetIdx);
    schedule = makeFaultSchedule(k,nTest);
    [plant, command] = simulatePlant(model,nTest,params,schedule);
    testData{k} = synthesizeTelemetry(plant,command,params,schedule,nChannels);
    testLabels{k} = schedule.Labels;
    testFaultTables{k} = schedule.Table;
end

anomalyRates = zeros(nAssets,1);
anomRates = anomalyRates;
for k = 1:numel(selectedTestAssets)
    assetIdx = selectedTestAssetIdx(k);
    anomalyRates(assetIdx) = 100*mean(testLabels{k});
    anomRates(assetIdx) = anomalyRates(assetIdx);
end

metadata = struct;
metadata.Scenario = "Simscape-generated industrial pump fleet anomaly detection";
metadata.PlantModel = modelFile;
metadata.PlantDescription = "Controlled isothermal-liquid pump flow source, discharge chamber, load resistance, pressure/flow sensors, reservoir, and Simscape solver.";
metadata.SampleTime = "1 minute equivalent per sample";
metadata.GenerationDate = string(datetime("now"));
metadata.ChannelNames = channelNames;
metadata.SelectedFaultSchedules = testFaultTables;
metadata.Note = "Pressure and mass-flow dynamics are simulated in Simscape. Current, vibration, temperature, and derived health channels are computed from simulated plant outputs and seeded asset/fault parameters.";

fleetDataFile02 = fullfile(workshopRoot,"02-PumpFleetDetectorApp","Data","pumpFleetData.mat");
fleetDataFile02Programmatic = fullfile(workshopRoot,"02-PumpFleetDetectorProgrammatic","Data","pumpFleetData.mat");
fleetDataFile03 = fullfile(workshopRoot,"03-ThresholdTuning","Data","pumpFleetData.mat");
save(fleetDataFile02,"trainData","testData","testLabels","assetNames","selectedTestAssets","channelNames","anomRates","anomalyRates","metadata","assetParameters","-v7.3")
save(fleetDataFile02Programmatic,"trainData","testData","testLabels","assetNames","selectedTestAssets","channelNames","anomRates","anomalyRates","metadata","assetParameters","-v7.3")
save(fleetDataFile03,"trainData","testData","testLabels","assetNames","selectedTestAssets","channelNames","anomRates","anomalyRates","metadata","assetParameters","-v7.3")

disp("Generating Simscape-backed high-rate current trace...")
[healthyData, faultyData, currentMetadata] = generateCurrentTrace(model, assetParameters(1));
currentDataFile = fullfile(workshopRoot,"01-CurrentMatrixProfile","Data","pumpCurrentData.mat");
save(currentDataFile,"healthyData","faultyData","currentMetadata")

testDataLabeled = prepareLabeledTestDataForSave(testData,testLabels);
appPreparedFile = fullfile(workshopRoot,"02-PumpFleetDetectorApp","Checkpoints","appPreparedData.mat");
save(appPreparedFile,"trainData","testData","testLabels","testDataLabeled","assetNames","selectedTestAssets","channelNames","anomalyRates","metadata","-v7.3")

if opts.TrainDetectors
    trainAndSaveDetectors(workshopRoot,trainData,nChannels)
end

disp("Generated Simscape pump workshop dataset.")
disp("Data file: " + fleetDataFile02)
end

function assetNames = makeAssetNames(nAssets)
assetNames = cell(nAssets,1);
for k = 1:nAssets
    group = ceil(k/10);
    withinGroup = k - 10*(group-1);
    assetNames{k} = sprintf('pump-%d-%d',group,withinGroup);
end
end

function channelNames = makeChannelNames()
channelNames = [
    "MotorCurrent","VibrationRMS","BearingTemperature","OutletPressure", ...
    "InletPressure","FlowRate","ShaftSpeed","TorqueEstimate", ...
    "ValveCommand","PowerDraw","CaseTemperature","PressureRipple", ...
    "FlowRipple","MotorVoltage","CurrentTHD","PumpEfficiency", ...
    "SealLeakIndex","CavitationIndex","BearingKurtosis","BearingCrestFactor", ...
    "AxialVibration","RadialVibration","SuctionPressure","DischargePressure", ...
    "OilTemperature","OilPressure","CoolantTemperature","AmbientTemperature", ...
    "CommandedSpeed","MeasuredSpeed","SpeedError","LoadEstimate", ...
    "PhaseA_Current","PhaseB_Current","PhaseC_Current","HydraulicPower", ...
    "ControllerOutput","ResidualLoad"];
end

function params = makeAssetParameters(assetIdx)
group = ceil(assetIdx/10);
params.AssetIndex = assetIdx;
params.Group = group;
params.NominalMassFlow = 2.0 + 0.18*group + 0.18*randn;
params.NominalMassFlow = max(params.NominalMassFlow,1.4);
params.LoadPressureDrop = (1.5e5 + 0.25e5*group) * (0.88 + 0.24*rand);
params.ChamberVolume = 0.008 + 0.004*rand;
params.Efficiency = 0.72 + 0.10*rand;
params.MotorVoltage = 460 + 8*randn;
params.BaseSpeedRPM = 1750 + 45*randn;
params.Friction = 0.08 + 0.04*rand;
params.Imbalance = 0.02 + 0.03*rand;
params.TemperatureOffset = -2 + 4*rand;
params.SensorBias = 0.02*randn(1,38);
end

function [plant, command] = simulatePlant(model,nSamples,params,schedule)
t = (0:nSamples-1)';
profile = 1 + 0.07*sin(2*pi*t/180 + 0.3*params.AssetIndex) + ...
    0.04*sin(2*pi*t/47 + params.Group) + 0.015*randn(nSamples,1);
profile = smoothdata(profile,"movmean",5);
profile = max(profile,0.55);
if ~isempty(schedule)
    profile = applyFaultToFlowProfile(profile,schedule);
end
massFlowCommand = -params.NominalMassFlow*profile;
flowCommandTs = timeseries(massFlowCommand,t);
simStopTime = nSamples - 1;
loadPressureDrop = params.LoadPressureDrop;
nominalMassFlow = params.NominalMassFlow;
chamberVolume = params.ChamberVolume;
in = Simulink.SimulationInput(model);
in = in.setVariable("flowCommandTs",flowCommandTs);
in = in.setVariable("simStopTime",simStopTime);
in = in.setVariable("loadPressureDrop",loadPressureDrop);
in = in.setVariable("nominalMassFlow",nominalMassFlow);
in = in.setVariable("chamberVolume",chamberVolume);
in = in.setModelParameter("StopTime",string(simStopTime));
out = sim(in);
q = out.q_out;
p = out.p_out;
plant.Time = t;
plant.MassFlow = interp1(q.Time,q.Data,t,"linear","extrap");
plant.Pressure = interp1(p.Time,p.Data,t,"linear","extrap");
command.Profile = profile;
command.MassFlow = -massFlowCommand;
end

function profile = applyFaultToFlowProfile(profile,schedule)
for i = 1:height(schedule.Table)
    idx = schedule.Table.Start(i):schedule.Table.End(i);
    idx = idx(idx >= 1 & idx <= numel(profile));
    switch schedule.Table.FaultType(i)
        case "cavitation"
            profile(idx) = profile(idx) .* (0.78 + 0.08*sin(2*pi*(1:numel(idx))'/9));
        case "bearing_wear"
            ramp = linspace(1.0,0.92,numel(idx))';
            profile(idx) = profile(idx).*ramp;
        case "seal_leak"
            profile(idx) = profile(idx).*0.82;
        case "blocked_discharge"
            profile(idx) = profile(idx).*0.70;
    end
end
profile = max(profile,0.35);
end

function schedule = makeFaultSchedule(testAssetOrdinal,nSamples)
switch testAssetOrdinal
    case 1
        startIdx = [280; 780];
        duration = [130; 150];
        faultType = ["cavitation"; "seal_leak"];
    case 2
        startIdx = [420; 860];
        duration = [220; 120];
        faultType = ["bearing_wear"; "blocked_discharge"];
    otherwise
        startIdx = [210; 620; 970];
        duration = [120; 170; 110];
        faultType = ["seal_leak"; "cavitation"; "bearing_wear"];
end
endIdx = min(startIdx + duration - 1,nSamples);
labels = false(nSamples,1);
for i = 1:numel(startIdx)
    labels(startIdx(i):endIdx(i)) = true;
end
schedule.Table = table(startIdx,endIdx,faultType,VariableNames=["Start","End","FaultType"]);
schedule.Labels = labels;
end

function X = synthesizeTelemetry(plant,command,params,schedule,nChannels)
n = numel(plant.Time);
t = plant.Time;
rho = 997;
qMass = max(plant.MassFlow,0);
qVol = qMass/rho;
pPa = max(plant.Pressure,0);
pBar = pPa/1e5;
speed = params.BaseSpeedRPM*(0.95 + 0.08*command.Profile) + 4*randn(n,1);
hydraulicPower = pPa .* qVol;
powerDraw = hydraulicPower/max(params.Efficiency,0.4) + 450 + 35*randn(n,1);
current = powerDraw/(sqrt(3)*params.MotorVoltage*0.86);
current = current + 0.4*params.Friction + 0.15*randn(n,1);
flowLpm = 60000*qVol;
pressureRipple = movstd(pBar,25,Endpoints="shrink") + 0.03*randn(n,1);
flowRipple = movstd(flowLpm,25,Endpoints="shrink") + 0.02*randn(n,1);
vibration = 0.12 + 0.03*abs(speed-mean(speed))/std(speed) + ...
    0.18*params.Imbalance + 0.025*randn(n,1);
temperature = firstOrderTemperature(36 + params.TemperatureOffset, powerDraw, params.Friction);
caseTemperature = temperature - 5 + 0.8*randn(n,1);
oilTemperature = temperature - 8 + 0.6*randn(n,1);
coolantTemperature = 30 + 0.15*(temperature-35) + 0.5*randn(n,1);
valveCommand = 55 + 20*(command.Profile-mean(command.Profile)) + 2*randn(n,1);
loadEstimate = normalize01(pBar).*0.65 + normalize01(current).*0.35;
efficiency = 100*(hydraulicPower./max(powerDraw,1));
efficiency = min(max(efficiency,35),88);
sealLeakIndex = 0.04 + 0.02*randn(n,1);
cavitationIndex = 0.05 + 0.03*randn(n,1);
bearingKurtosis = 3 + 0.3*randn(n,1);
bearingCrestFactor = 2.6 + 0.2*randn(n,1);
currentTHD = 2.5 + 0.25*randn(n,1);
if ~isempty(schedule)
    [current,vibration,temperature,pBar,flowLpm,pressureRipple,flowRipple, ...
        sealLeakIndex,cavitationIndex,bearingKurtosis,bearingCrestFactor,currentTHD] = ...
        applyFaultTelemetry(current,vibration,temperature,pBar,flowLpm,pressureRipple, ...
        flowRipple,sealLeakIndex,cavitationIndex,bearingKurtosis,bearingCrestFactor, ...
        currentTHD,schedule);
end
measuredSpeed = speed + 3*randn(n,1);
commandedSpeed = params.BaseSpeedRPM*(0.95 + 0.08*command.Profile);
speedError = commandedSpeed - measuredSpeed;
torqueEstimate = hydraulicPower ./ max(speed*pi/30,10) + 0.4*randn(n,1);
phaseA = current + 0.05*randn(n,1);
phaseB = current.*(0.99 + 0.01*randn(n,1));
phaseC = current.*(1.01 + 0.01*randn(n,1));
residualLoad = loadEstimate - movmean(loadEstimate,80,Endpoints="shrink") + 0.02*randn(n,1);
ambientTemperature = 24 + 2*sin(2*pi*t/1440) + 0.4*randn(n,1);
inletPressure = 1.00 + 0.03*randn(n,1);
suctionPressure = inletPressure - 0.02*abs(flowRipple);
oilPressure = 3.0 + 0.1*normalize01(speed) - 0.02*(oilTemperature-35) + 0.04*randn(n,1);
controllerOutput = 0.55 + 0.25*normalize01(command.Profile) + 0.03*randn(n,1);
axialVibration = 0.8*vibration + 0.03*randn(n,1);
radialVibration = 1.2*vibration + 0.04*randn(n,1);
outletPressure = pBar;
dischargePressure = pBar + 0.02*randn(n,1);
X = [current,vibration,temperature,outletPressure,inletPressure,flowLpm, ...
    speed,torqueEstimate,valveCommand,powerDraw,caseTemperature,pressureRipple, ...
    flowRipple,params.MotorVoltage + 1.5*randn(n,1),currentTHD,efficiency, ...
    sealLeakIndex,cavitationIndex,bearingKurtosis,bearingCrestFactor, ...
    axialVibration,radialVibration,suctionPressure,dischargePressure, ...
    oilTemperature,oilPressure,coolantTemperature,ambientTemperature, ...
    commandedSpeed,measuredSpeed,speedError,loadEstimate,phaseA,phaseB,phaseC, ...
    hydraulicPower,controllerOutput,residualLoad];
X = X(:,1:nChannels);
X = fillmissing(X,"linear");
X = X + 0.002*randn(size(X)).*max(std(X,0,1),1);
X = X + params.SensorBias(1:nChannels);
end

function [current,vibration,temperature,pBar,flowLpm,pressureRipple,flowRipple,sealLeakIndex,cavitationIndex,bearingKurtosis,bearingCrestFactor,currentTHD] = applyFaultTelemetry(current,vibration,temperature,pBar,flowLpm,pressureRipple,flowRipple,sealLeakIndex,cavitationIndex,bearingKurtosis,bearingCrestFactor,currentTHD,schedule)
for i = 1:height(schedule.Table)
    idx = schedule.Table.Start(i):schedule.Table.End(i);
    idx = idx(idx >= 1 & idx <= numel(current));
    ramp = linspace(0,1,numel(idx))';
    switch schedule.Table.FaultType(i)
        case "cavitation"
            cavitationIndex(idx) = cavitationIndex(idx) + 0.65 + 0.15*sin(2*pi*(1:numel(idx))'/7);
            vibration(idx) = vibration(idx) + 0.45 + 0.08*randn(numel(idx),1);
            pressureRipple(idx) = pressureRipple(idx) + 0.45;
            flowRipple(idx) = flowRipple(idx) + 4.0;
            currentTHD(idx) = currentTHD(idx) + 2.0;
        case "bearing_wear"
            bearingKurtosis(idx) = bearingKurtosis(idx) + 2.0 + 2.0*ramp;
            bearingCrestFactor(idx) = bearingCrestFactor(idx) + 0.8 + 0.7*ramp;
            vibration(idx) = vibration(idx) + 0.25 + 0.55*ramp;
            temperature(idx) = temperature(idx) + 2.0 + 6.0*ramp;
            current(idx) = current(idx) + 0.4 + 0.7*ramp;
        case "seal_leak"
            sealLeakIndex(idx) = sealLeakIndex(idx) + 0.75;
            pBar(idx) = pBar(idx).*0.82;
            flowLpm(idx) = flowLpm(idx).*0.88;
            current(idx) = current(idx) + 0.25;
            pressureRipple(idx) = pressureRipple(idx) + 0.18;
        case "blocked_discharge"
            pBar(idx) = pBar(idx).*1.35;
            flowLpm(idx) = flowLpm(idx).*0.72;
            current(idx) = current(idx) + 0.9;
            vibration(idx) = vibration(idx) + 0.25;
            temperature(idx) = temperature(idx) + 3.0;
    end
end
end

function temp = firstOrderTemperature(baseTemp,powerDraw,friction)
n = numel(powerDraw);
temp = zeros(n,1);
temp(1) = baseTemp;
drive = normalize01(powerDraw);
for i = 2:n
    target = baseTemp + 12*drive(i) + 18*friction;
    temp(i) = 0.985*temp(i-1) + 0.015*target + 0.05*randn;
end
end

function y = normalize01(x)
range = max(x) - min(x);
if range < eps
    y = zeros(size(x));
else
    y = (x - min(x))/range;
end
end

function [healthyData, faultyData, currentMetadata] = generateCurrentTrace(model,params)
nSamples = 7000;
t = (0:nSamples-1)'/100;
profile = 1 + 0.06*sin(2*pi*t/18) + 0.03*sin(2*pi*t/4.7);
flowCommandTs = timeseries(-params.NominalMassFlow*profile,t);
simStopTime = t(end);
loadPressureDrop = params.LoadPressureDrop;
nominalMassFlow = params.NominalMassFlow;
chamberVolume = params.ChamberVolume;
in = Simulink.SimulationInput(model);
in = in.setVariable("flowCommandTs",flowCommandTs);
in = in.setVariable("simStopTime",simStopTime);
in = in.setVariable("loadPressureDrop",loadPressureDrop);
in = in.setVariable("nominalMassFlow",nominalMassFlow);
in = in.setVariable("chamberVolume",chamberVolume);
in = in.setModelParameter("StopTime",string(simStopTime));
out = sim(in);
q = interp1(out.q_out.Time,out.q_out.Data,t,"linear","extrap");
p = interp1(out.p_out.Time,out.p_out.Data,t,"linear","extrap");
rho = 997;
hydraulicPower = max(p,0).*max(q,0)/rho;
baseCurrent = hydraulicPower/(sqrt(3)*params.MotorVoltage*0.86*params.Efficiency) + 2.0;
ripple = 0.28*sin(2*pi*35*t) + 0.12*sin(2*pi*70*t);
healthyCurrent = baseCurrent + ripple + 0.08*randn(nSamples,1);
faultyCurrent = healthyCurrent + 0.18*sin(2*pi*12*t) + 0.04*(t > 45).*(t-45);
tacho = double(mod(t*params.BaseSpeedRPM/60,1) < 0.12);
rowTimes = seconds(t);
healthyData = timetable(rowTimes,healthyCurrent,tacho,VariableNames=["MotorCurrent","TachoPulse"]);
faultyData = timetable(rowTimes,faultyCurrent,tacho,VariableNames=["MotorCurrent","TachoPulse"]);
healthyData.Properties.DimensionNames{1} = 'Time';
faultyData.Properties.DimensionNames{1} = 'Time';
currentMetadata = struct;
currentMetadata.Source = "SimscapePumpDataPlant";
currentMetadata.SampleRateHz = 100;
currentMetadata.Description = "High-rate motor-current trace derived from Simscape-simulated pump pressure and flow.";
end

function testDataLabeled = prepareLabeledTestDataForSave(testData,testLabels)
testDataLabeled = cell(numel(testData),1);
for k = 1:numel(testData)
    testDataLabeled{k} = [testData{k}, testLabels{k}];
end
end

function trainAndSaveDetectors(workshopRoot,trainData,nChannels)
disp("Training detector checkpoints on Simscape-generated data...")
windowLength = 120;
detectorIForest = timeSeriesIforestAD(nChannels, ...
    WindowLength=windowLength, ...
    TrainingStride=30, ...
    NumLearners=120, ...
    NumObservationsPerLearner=300);
detectorIForest = train(detectorIForest,trainData);
detectorUsAD = usAD(nChannels, ...
    ObservationWindowLength=windowLength, ...
    TrainingStride=30, ...
    LatentSpaceDim=16, ...
    Alpha=0.7, ...
    Beta=0.3);
detectorUsAD = train(detectorUsAD,trainData,MaxEpochs=6,MiniBatchSize=128,Verbose=false);
detectorDeepAnt = deepantAD(nChannels, ...
    ObservationWindowLength=windowLength, ...
    DetectionWindowLength=10, ...
    TrainingStride=30, ...
    DetectionStride=10, ...
    NumFilters=16, ...
    DropoutProbability=0.1);
opts = trainingOptions("adam", ...
    MaxEpochs=12, ...
    InitialLearnRate=1e-4, ...
    Verbose=false, ...
    Shuffle="every-epoch", ...
    MiniBatchSize=128);
detectorDeepAnt = train(detectorDeepAnt,trainData,TrainingOpts=opts);
save(fullfile(workshopRoot,"02-PumpFleetDetectorApp","Checkpoints","trainedPumpDetectors.mat"),"detectorUsAD","detectorDeepAnt","detectorIForest","-v7.3")
save(fullfile(workshopRoot,"02-PumpFleetDetectorProgrammatic","Checkpoints","trainedPumpDetectors.mat"),"detectorUsAD","detectorDeepAnt","detectorIForest","-v7.3")
save(fullfile(workshopRoot,"03-ThresholdTuning","Checkpoints","trainedPumpDetectors.mat"),"detectorUsAD","detectorDeepAnt","detectorIForest","-v7.3")
end
