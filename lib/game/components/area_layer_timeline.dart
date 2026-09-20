import 'dart:typed_data';

import 'bomb_layer_timeline.dart';

// Same six-layer buffer as bomb: glow, ignition, ring, burst, swirl, residue.
// start, peak, end, scale0, scale1, spin, maximum alpha.
const _hyperCurves = [
  [0.00, 0.12, 1.00, 0.45, 1.14, 0.00, 0.70],
  [0.00, 0.06, 0.24, 0.28, 0.88, 0.00, 0.72],
  [0.03, 0.20, 0.78, 0.35, 1.14, 0.42, 0.66],
  [0.10, 0.29, 0.76, 0.45, 1.02, 0.00, 0.68],
  [0.30, 0.53, 0.96, 0.66, 1.08, 0.85, 0.58],
  [0.55, 0.73, 1.00, 0.70, 0.38, 0.08, 0.46],
];
const _supernovaCurves = [
  [0.00, 0.15, 1.00, 0.48, 1.25, 0.00, 0.62],
  [0.00, 0.05, 0.25, 0.25, 0.94, 0.00, 0.60],
  [0.04, 0.22, 0.84, 0.32, 1.26, 0.14, 0.70],
  [0.12, 0.32, 0.75, 0.48, 1.06, 0.00, 0.55],
  [0.34, 0.56, 0.97, 0.70, 1.16, -0.65, 0.48],
  [0.57, 0.76, 1.00, 0.64, 0.30, 0.00, 0.38],
];

void evaluateHyperLayers(double t, Float32List out) =>
    _evaluate(t, out, _hyperCurves);

void evaluateSupernovaLayers(double t, Float32List out) =>
    _evaluate(t, out, _supernovaCurves);

void _evaluate(double t, Float32List out, List<List<double>> curves) {
  assert(out.length == bombLayerBufferLength);
  final time = t.clamp(0.0, 1.0);
  for (var i = 0; i < curves.length; i++) {
    final c = curves[i];
    final base = i * bombLayerStride;
    if (time <= c[0] || time >= c[2]) {
      out[base] = out[base + 1] = out[base + 2] = 0;
      continue;
    }
    final progress = _ease((time - c[0]) / (c[2] - c[0]));
    final decay = 1 - (time - c[1]) / (c[2] - c[1]);
    final envelope = time < c[1]
        ? _ease((time - c[0]) / (c[1] - c[0]))
        : decay * decay;
    out[base] = c[3] + (c[4] - c[3]) * progress;
    out[base + 1] = envelope * c[6];
    out[base + 2] = c[5] * progress;
  }
}

double _ease(double t) => t * (2 - t);
