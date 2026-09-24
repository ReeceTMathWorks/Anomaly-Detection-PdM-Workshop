# Simscape Pump Data Generation

This folder contains the source for the workshop dataset.

- `SimscapePumpDataPlant.slx` simulates pump pressure and flow dynamics with Simscape Fluids.
- `generateSimscapePumpFleetData.m` simulates a 28-asset pump fleet, derives 38 telemetry channels, writes the workshop MAT files, and optionally trains detector checkpoints for the app, programmatic, and threshold-tuning exercises.

Run:

```matlab
generateSimscapePumpFleetData(TrainDetectors=false)
```

Use `TrainDetectors=true` when you want to regenerate `trainedPumpDetectors.mat` as well. Training is slower than data generation and is best handled before a live workshop.
