part of 'board_juice_layer.dart';

/// 숫자는 마운트당 한 번 굽는다. 이벤트에서 문자 코드를 슬롯에 복사하고,
/// 매 프레임에는 미리 확보한 typed 버퍼와 길이별 뷰만 사용한다.
class _JuiceGlyphs {
  static const _alphabet = '0123456789+s.';
  static const _slots = 6;
  static const _digits = 16;
  static const _capacity = _slots * _digits;
  static const _cell = 48.0;
  final _codes = Uint8List(_capacity);
  final _length = Uint8List(_slots);
  final _x = Float32List(_slots);
  final _y = Float32List(_slots);
  final _size = Float32List(_slots);
  final _age = Float32List(_slots);
  final _duration = Float32List(_slots);
  final _rise = Float32List(_slots);
  final _colors = Int32List(_slots);
  final _widths = Float32List(_alphabet.length);
  final _rst = Float32List(_capacity * 4);
  final _src = Float32List(_capacity * 4);
  final _argb = Int32List(_capacity);
  late final _rstViews = List.generate(
    _capacity + 1,
    (n) => Float32List.sublistView(_rst, 0, n * 4),
  );
  late final _srcViews = List.generate(
    _capacity + 1,
    (n) => Float32List.sublistView(_src, 0, n * 4),
  );
  late final _colorViews = List.generate(
    _capacity + 1,
    (n) => Int32List.sublistView(_argb, 0, n),
  );
  final _paint = Paint();
  ui.Image? _atlas;
  int _next = 0;
  int _count = 0;

  void mount() {
    if (_atlas != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < _alphabet.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: _alphabet[i],
          style: const TextStyle(
            fontFamily: AssetPaths.fontNexonLv2Gothic,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [Shadow(color: Color(0xEE000000), offset: Offset(0, 2))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _widths[i] = painter.width;
      painter.paint(
        canvas,
        Offset(
          i * _cell + (_cell - painter.width) / 2,
          (_cell - painter.height) / 2,
        ),
      );
      painter.dispose();
    }
    final picture = recorder.endRecording();
    _atlas = picture.toImageSync(
      (_cell * _alphabet.length).toInt(),
      _cell.toInt(),
    );
    picture.dispose();
    _rstViews;
    _srcViews;
    _colorViews;
  }

  void dispose() {
    _atlas?.dispose();
    _atlas = null;
    _length.fillRange(0, _slots, 0);
    _count = 0;
    _next = 0;
  }

  void show(
    String text, {
    required double x,
    required double y,
    required double size,
    required double rise,
    required int rgb,
    required double left,
    required double right,
    bool time = false,
  }) {
    // 시간 보상은 마지막 슬롯과 하단 레인을 전용으로 쓴다.
    final slot = time ? _slots - 1 : _next;
    if (!time) _next = (_next + 1) % (_slots - 1);
    final length = math.min(text.length, _digits);
    var width = 0.0;
    for (var i = 0; i < length; i++) {
      final code = _alphabet.indexOf(text[i]);
      _codes[slot * _digits + i] = code < 0 ? 0 : code;
      width += _widths[_codes[slot * _digits + i]];
    }
    final half = width * size / 34 * 1.15 / 2;
    _length[slot] = length;
    _x[slot] = left + half <= right - half
        ? x.clamp(left + half, right - half).toDouble()
        : (left + right) / 2;
    _y[slot] = y;
    _size[slot] = size;
    _age[slot] = 0;
    _duration[slot] = time ? 0.8 : 0.65;
    _rise[slot] = rise;
    _colors[slot] = rgb;
  }

  void update(double dt) {
    var count = 0;
    for (var slot = 0; slot < _slots; slot++) {
      final length = _length[slot];
      if (length == 0) continue;
      _age[slot] += dt;
      final p = _age[slot] / _duration[slot];
      if (p >= 1) {
        _length[slot] = 0;
        continue;
      }
      final pop = p < 0.18
          ? 0.4 + 0.75 * p / 0.18
          : p < 0.3
          ? 1.15 - 0.15 * (p - 0.18) / 0.12
          : 1.0;
      final scale = _size[slot] / 34 * pop;
      var width = 0.0;
      for (var i = 0; i < length; i++) {
        width += _widths[_codes[slot * _digits + i]] * scale;
      }
      var x = _x[slot] - width / 2;
      final y = _y[slot] - _rise[slot] * (1 - (1 - p) * (1 - p));
      final alpha = p < 0.55 ? 255 : (255 * (1 - p) / 0.45).round();
      for (var i = 0; i < length; i++) {
        final code = _codes[slot * _digits + i];
        final o = count * 4;
        _rst[o] = scale;
        _rst[o + 1] = 0;
        _rst[o + 2] = x - (_cell - _widths[code]) * scale / 2;
        _rst[o + 3] = y - _cell * scale / 2;
        _src[o] = code * _cell;
        _src[o + 1] = 0;
        _src[o + 2] = (code + 1) * _cell;
        _src[o + 3] = _cell;
        _argb[count] = (alpha << 24) | _colors[slot];
        x += _widths[code] * scale;
        count++;
      }
    }
    _count = count;
  }

  void render(Canvas canvas) {
    final atlas = _atlas;
    if (atlas == null || _count == 0) return;
    canvas.drawRawAtlas(
      atlas,
      _rstViews[_count],
      _srcViews[_count],
      _colorViews[_count],
      BlendMode.modulate,
      null,
      _paint,
    );
  }
}
