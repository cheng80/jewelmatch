import 'dart:typed_data';
import 'dart:ui';

/// Bomb 범위 효과를 이루는 레이어. 그리는 순서이기도 하다.
/// [BombLayer.glow]만 구운 글로우이고 나머지는 `board_atlas.png`의 `bomb_0`~`bomb_4` 칸 순서다.
enum BombLayer { glow, ignition, ring, burst, swirl, ember }

/// 레이어 하나가 쓰는 float 개수: scale, alpha, angle(라디안).
const int bombLayerStride = 3;

/// 아틀라스에 실제 칸이 있는 레이어 수([BombLayer.glow] 제외).
const int bombLayerSpriteCount = 5;

/// [evaluateBombLayers]에 넘길 버퍼 길이.
const int bombLayerBufferLength = (bombLayerSpriteCount + 1) * bombLayerStride;

/// 레이어별 (등장, 정점, 소멸, 시작 배율, 끝 배율, 총 회전).
/// 시간은 전부 정규화된 t다. 수명이 바뀌어도 곡선은 그대로다.
const List<List<double>> _curves = [
  //       start  peak   end    scale0 scale1 spin
  /* glow     */ [0.00, 0.10, 1.00, 0.50, 1.30, 0.00],
  /* ignition */ [0.00, 0.05, 0.26, 0.30, 1.05, 0.00],
  /* ring     */ [0.02, 0.16, 0.68, 0.22, 1.30, 0.45],
  /* burst    */ [0.08, 0.30, 0.84, 0.55, 1.20, 0.00],
  /* swirl    */ [0.26, 0.52, 1.00, 0.80, 1.16, 1.10],
  /* ember    */ [0.52, 0.70, 1.00, 1.05, 0.62, 0.55],
];

/// 범위 효과 레이어 칸 규격 검사. 칸은 [bombLayerSpriteCount]개이고 모두 같은 정수 크기의
/// 정사각형이며, 정수 좌표로 이미지 안에 있어야 한다.
bool isValidAreaLayerFrames({
  required List<Rect> frames,
  required int imageWidth,
  required int imageHeight,
  required double scale,
}) {
  if (frames.length != bombLayerSpriteCount) return false;
  if (!scale.isFinite || scale <= 0) return false;
  final cell = frames.first.width;
  if (!cell.isFinite || cell <= 0 || cell != cell.roundToDouble()) return false;
  for (final f in frames) {
    if (f.width != cell || f.height != cell) return false;
    if (f.left != f.left.roundToDouble() || f.top != f.top.roundToDouble()) {
      return false;
    }
    if (f.left < 0 || f.top < 0) return false;
    if (f.right > imageWidth || f.bottom > imageHeight) return false;
  }
  return true;
}

double _easeOut(double x) => x * (2 - x);

/// t(0~1)에서 각 레이어의 배율, 알파, 회전각을 [out]에 채운다.
/// 순수 함수이고 객체를 만들지 않는다. [out] 길이는 [bombLayerBufferLength]다.
void evaluateBombLayers(double t, Float32List out) {
  assert(out.length == bombLayerBufferLength);
  final time = t.clamp(0.0, 1.0);
  for (var i = 0; i < _curves.length; i++) {
    final curve = _curves[i];
    final start = curve[0];
    final peak = curve[1];
    final end = curve[2];
    final base = i * bombLayerStride;

    double alpha;
    if (time <= start || time >= end) {
      alpha = 0;
    } else if (time < peak) {
      alpha = _easeOut((time - start) / (peak - start));
    } else {
      final fell = 1 - (time - peak) / (end - peak);
      alpha = fell * fell;
    }

    if (alpha <= 0) {
      out[base] = 0;
      out[base + 1] = 0;
      out[base + 2] = 0;
      continue;
    }

    final progress = _easeOut(((time - start) / (end - start)).clamp(0.0, 1.0));
    out[base] = curve[3] + (curve[4] - curve[3]) * progress;
    out[base + 1] = alpha;
    out[base + 2] = curve[5] * progress;
  }
}
