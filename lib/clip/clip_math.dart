import 'dart:math';
import 'dart:typed_data';

Float32List l2Normalize(Float32List v) {
  double sum = 0;
  for (final x in v) {
    sum += x * x;
  }
  final norm = sqrt(sum);
  if (norm == 0) return v;
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = (v[i] / norm).toDouble();
  }
  return out;
}

/// Returns a normalized copy of [v] or `null` if it is not normalizable
/// (all-zeros, NaN/Inf, or contains invalid values).
Float32List? l2NormalizeOrNull(Float32List v) {
  double sum = 0;
  for (final x in v) {
    final xd = x.toDouble();
    if (!xd.isFinite) return null;
    sum += xd * xd;
    if (!sum.isFinite) return null;
  }
  if (sum == 0) return null;
  final norm = sqrt(sum);
  if (norm == 0 || !norm.isFinite) return null;

  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    final y = v[i] / norm;
    if (!y.isFinite) return null;
    out[i] = y.toDouble();
  }
  return out;
}

double l2Norm(Float32List v) {
  double sum = 0;
  for (final x in v) {
    final xd = x.toDouble();
    sum += xd * xd;
  }
  return sqrt(sum);
}

double dot(Float32List a, Float32List b) {
  final n = min(a.length, b.length);
  double s = 0;
  for (var i = 0; i < n; i++) {
    s += a[i] * b[i];
  }
  return s;
}
