part of 'board_juice_layer.dart';

extension BoardJuiceEvents on BoardJuiceLayer {
  /// 탄생 종류별 실루엣: 폭탄 대각 파편, 별 십자, 하이퍼 오색 별,
  /// 초신성 이중 방사. 기존 네 칸 아틀라스와 192슬롯 안에서만 방출한다.
  void onSpecialsBorn(List<SpecialSpawn> spawns) {
    final board = game.board;
    final ts = board.tileSize;
    if (ts <= 0) return;
    for (final spawn in spawns) {
      _specialSignature(
        spawn.kind,
        board.boardX + (spawn.col + 0.5) * ts,
        board.boardY + (spawn.row + 0.5) * ts,
        BoardJuiceLayer._sparkRgb(spawn.color),
        birth: true,
      );
    }
  }

  void onSpecialsActivated(List<SpecialEffectEvent> events) {
    if (events.isEmpty || game.board.tileSize <= 0) return;
    final board = game.board;
    final ts = board.tileSize;
    for (final event in events) {
      _specialSignature(
        event.effectKind,
        board.boardX + (event.origin.y + 0.5) * ts,
        board.boardY + (event.origin.x + 0.5) * ts,
        BoardJuiceLayer._sparkRgb(event.triggerColor ?? 0),
        birth: false,
      );
    }
    final label = events.length > 1
        ? 'CHAIN ×${events.length}'
        : switch (events.first.effectKind) {
            GemKind.row => 'ROW!',
            GemKind.col => 'COLUMN!',
            GemKind.bomb => 'BOMB!',
            GemKind.star => 'STAR!',
            GemKind.hyper => 'HYPER!',
            GemKind.supernova => 'SUPERNOVA!',
            GemKind.normal => '',
          };
    if (label.isEmpty) return;
    _showText(
      slot: 0,
      text: label,
      x: board.boardX + board.cols * ts / 2,
      y: board.boardY + ts * 0.55,
      fontSize: ts * (events.length > 1 ? 0.56 : 0.48),
      color: BoardJuiceLayer._gold,
      duration: 0.8,
      rise: ts * 0.22,
    );
    // 같은 제거의 콤보 문구가 실제 특수 발동 콜아웃을 덮지 않는다.
    _calloutHold = 0.8;
  }

  void _specialSignature(
    GemKind kind,
    double x,
    double y,
    int rgb, {
    required bool birth,
  }) {
    final ts = game.board.tileSize;
    final unit = ts / BoardJuiceLayer._atlasSize;
    final count = switch (kind) {
      GemKind.supernova => 20,
      GemKind.hyper => 15,
      GemKind.star => 12,
      _ => 8,
    };
    final color = switch (kind) {
      GemKind.bomb => 0xFFB45D,
      GemKind.star => 0x8CEEFF,
      GemKind.supernova => 0xF9A5FF,
      _ => rgb,
    };
    _emit(
      BoardJuiceLayer._ring,
      x,
      y,
      life: 0.32,
      scale: unit * (kind == GemKind.supernova ? 2.0 : 1.4),
      rgb: color,
    );
    for (var i = 0; i < count; i++) {
      final angle = switch (kind) {
        GemKind.row => i.isEven ? 0.0 : math.pi,
        GemKind.col => i.isEven ? math.pi / 2 : -math.pi / 2,
        GemKind.star => i * math.pi / 2,
        GemKind.bomb => i * math.pi / 2 + math.pi / 4,
        _ => i * 2 * math.pi / count,
      };
      final speed = ts * (birth ? 1.8 : 3.0) * (1 + (i % 3) * 0.25);
      _emit(
        kind == GemKind.hyper || kind == GemKind.supernova
            ? BoardJuiceLayer._star
            : BoardJuiceLayer._shard,
        x,
        y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        life: birth ? 0.48 : 0.58,
        scale: unit * (birth ? 0.42 : 0.55),
        rgb: kind == GemKind.hyper
            ? BoardJuiceLayer._sparkRgb(i % 6 + 1)
            : color,
      );
    }
    _busyTime = math.max(_busyTime, birth ? 0.48 : 0.58);
  }

  void onTimeBonus(double seconds) {
    if (seconds <= 0) return;
    final board = game.board;
    final ts = board.tileSize;
    if (ts <= 0) return;
    // 상한에서 잘린 보상은 소수 한 자리까지 내림해 과장하지 않는다.
    final tenths = (seconds * 10 + 0.000001).floor();
    if (tenths == 0) return;
    final value = tenths % 10 == 0
        ? '${tenths ~/ 10}'
        : '${tenths ~/ 10}.${tenths % 10}';
    _glyphs.show(
      '+$value'
      's',
      x: board.boardX + board.cols * ts / 2,
      y: board.boardY + board.rows * ts - ts * 0.4,
      size: ts * 0.43,
      rise: ts * 0.55,
      rgb: 0x9DFFD2,
      left: board.boardX,
      right: board.boardX + board.cols * ts,
      time: true,
    );
    _busyTime = math.max(_busyTime, 0.8);
  }

  /// update/input 소유 파일을 건드리지 않고 낙하 좌표의 경계 통과를 관측한다.
  /// 같은 보석은 다음 낙하 전까지 다시 방출하지 않는다. 유휴 busy와 분리한다.
  void _observeGemMotion() {
    final board = game.board;
    if (!game.isPlaying || board.tileSize <= 0) return;
    final ts = board.tileSize;
    final unit = ts / BoardJuiceLayer._atlasSize;
    for (var row = 0; row < board.rows; row++) {
      for (var col = 0; col < board.cols; col++) {
        final gem = board.getGem(row, col);
        if (gem == null) continue;
        final dy = gem.targetY - gem.y;
        if (gem.juiceRefillPending) {
          gem.juiceRefillPending = false;
          gem.juiceFalling = true;
          _emit(
            BoardJuiceLayer._star,
            gem.x + ts * 0.5,
            math.max(board.boardY + ts * 0.15, gem.y + ts * 0.5),
            vy: ts * 0.7,
            life: 0.28,
            scale: unit * 0.4,
            rgb: BoardJuiceLayer._sparkRgb(gem.color),
          );
        }
        if (dy > ts * 0.5) {
          gem.juiceFalling = true;
        } else if (gem.juiceFalling && dy.abs() <= ts * 0.12) {
          gem.juiceFalling = false;
          for (var i = 0; i < 3; i++) {
            _emit(
              BoardJuiceLayer._flash,
              gem.targetX + ts * (0.25 + i * 0.25),
              gem.targetY + ts * 0.9,
              life: 0.16,
              scale: unit * 0.3,
              rgb: BoardJuiceLayer._sparkRgb(gem.color),
            );
          }
        }
      }
    }
  }
}
