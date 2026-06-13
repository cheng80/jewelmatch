import 'dart:math' show max, min, pi, sin;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../services/ranking_service.dart';
import 'components/match_board_renderer.dart';
import 'components/match_game_hud.dart';
import 'components/particle_burst.dart';
import 'components/special_effect_pool.dart';
import 'components/space_bg.dart';
import 'jewel_game_mode.dart';
import 'match_board_logic.dart';

/// 8×8 매치-3 Flame 게임 (스왑·연쇄·특수 보석).
/// 보드 탭은 전체 화면 [MatchGameHud]가 받아 상단 크롬 외 좌표를 [handleBoardTap]으로 전달한다.
class MatchBoardGame extends FlameGame {
  MatchBoardGame({
    this.safeAreaPadding = EdgeInsets.zero,
    this.gameMode = JewelGameMode.simple,
  }) {
    board = MatchBoardLogic(
      rows: rows,
      cols: cols,
      colorCount: 6,
      onNoMoves: () {
        overlays.add('NoMoves');
      },
      timedModeTimeRewardScale: timedModeTimeRewardScale,
      timedModeBonusBaseUnits: timedModeBonusBaseUnits,
      timedModeBonusPerComboTierUnits: timedModeBonusPerComboTierUnits,
      onTimedModeTimeBonus: isTimedMode ? _applyTimedModeTimeBonus : null,
      onInvalidSwap: _playInvalidSwapSfx,
    );
    board.onIntroFillComplete = (BoardFillIntroKind kind) {
      overlays.remove('IntroBlock');
      if (kind == BoardFillIntroKind.roundStart) {
        SoundManager.playSfx(AssetPaths.sfxStart);
      }
    };
    board.onGemsRemoved = _spawnParticles;
    if (isTimedMode) {
      timeRemaining = timedRoundSeconds;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
  }

  final EdgeInsets safeAreaPadding;
  final JewelGameMode gameMode;

  /// 타임 모드 시작 시 남은 시간(초).
  static const double timedRoundSeconds = 60;

  /// 타임 모드에서 [timeRemaining] 상한(초). 이보다 많이 쌓이는 보상은 버린다.
  static const double timedMaxTimeSeconds = 90;

  /// 레벨/난이도용 **시간 보상 비율**.
  /// 실제 추가 초 = `round((기준합) * 이 값)` — 0.5면 보상이 절반.
  static const double timedModeTimeRewardScale = 0.6;

  /// 매치 1단계 기준 보상(정수 초). 콤보 단계 보상은 [timedModeBonusPerComboTierUnits]와 합산 후 스케일·반올림.
  static const int timedModeBonusBaseUnits = 1;

  /// 콤보 2단계부터 (combo-1)에 곱해 더하는 정수 초 단위.
  static const int timedModeBonusPerComboTierUnits = 1;

  /// 남은 시간이 이 초 이하로 떨어지면 매 정수 초마다 [sfxTimeTic] 재생.
  static const int timedLowTimeTickMaxSeconds = 10;

  late final MatchBoardLogic board;
  late final ParticlePool _particlePool;
  late final SpecialEffectPool _specialEffectPool;
  MatchGameHud? _hud;
  final Map<String, String> _localeStrings = {};
  double _shakeRemaining = 0;
  double _shakeDuration = 0;
  double _shakeIntensity = 0;
  double _shakeElapsed = 0;

  /// 타임 모드: 서버 1위 이름·점수 (비동기 fetch 완료 후 갱신).
  String? rankingTop1Name;
  int? rankingTop1Score;

  String localeString(String key, String fallback) =>
      _localeStrings[key] ?? fallback;

  void setLocaleStrings(Map<String, String> strings) {
    _localeStrings
      ..clear()
      ..addAll(strings);
    _hud?.onGameResize(size);
  }

  static const int rows = 8;
  static const int cols = 8;
  static const double _hudScaleRatio = 0.2;

  bool isPlaying = true;
  bool timeUp = false;
  int _lastSavedScore = -1;

  /// `true`이면 `onGameResize`에서 기하만 갱신하고, 보석 데이터는 유지한다.
  /// (첫 유효 레이아웃에서 한 번만 `generateFreshBoard` — 문서 5절 `onLoad` 이후 레이아웃 확정 흐름과 동일한 단계)
  bool _boardSeededFromLayout = false;

  double timeRemaining = 0;

  /// [timeRemaining]의 정수 초(내림) — 저시간 틱이 중복되지 않도록 추적.
  int _lastFlooredSecondForTimeTic = -1;

  bool get isTimedMode => gameMode == JewelGameMode.timed;

  /// 상단 1열: 일시정지 + 최고 기록만.
  static const double hudTopBarScale = 0.54;

  /// 큰 점수 블록 (라벨 + 숫자).
  static const double hudMainScoreBlockScale = 1.38;
  double get hudTopBarHeight => hudScale * hudTopBarScale;
  double get hudMainScoreBlockHeight => hudScale * hudMainScoreBlockScale;

  /// 점수 숫자 아래 ~ 콤보 줄까지 간격.
  double get hudGapScoreToCombo => hudScale * 0.1;

  /// 콤보(현재·최대) 고정 줄 높이 — 점수 블록과 보드 사이.
  double get hudComboStripHeight => hudScale * 0.88;

  /// 콤보 줄과 보드 사이 간격.
  double get hudGapBeforeBoard => hudScale * 0.22;

  /// 보드 아래: 타임바만 (여백은 [hudGapBelowBoard]·[hudGapBelowTimeBar]).
  static const double hudBottomTimeBarScale = 0.5;

  double get hudBottomTimeBarHeight => hudScale * hudBottomTimeBarScale;

  /// 보드 하단과 타임바 사이 ([MatchGameHud]와 동일).
  double get hudGapBelowBoard => hudScale * 0.26;

  /// 타임바 아래 여백.
  double get hudGapBelowTimeBar => hudScale * 0.18;

  /// [layoutRef] 계산 시 보드 아래에 확보할 높이 (타임바 + 간격만).
  double get bottomChromeHeight =>
      hudGapBelowBoard + hudBottomTimeBarHeight + hudGapBelowTimeBar;

  /// 상단: 안전영역 + 상단바 + 점수 블록 + 콤보 줄 + 보드 전 간격.
  double get topChromeHeight =>
      safeAreaPadding.top +
      10 +
      hudTopBarHeight +
      hudMainScoreBlockHeight +
      hudGapScoreToCombo +
      hudComboStripHeight +
      hudGapBeforeBoard;

  /// Flame 부트스트랩 (`code-flow-analysis.md` 5절과 같은 단계)
  /// 1) super.onLoad  2) viewfinder  3) backdrop  4) viewport(HUD)  5) world(보드 렌더러)
  /// 실제 보석 채움은 `hasLayout`·`layoutRef`가 확보된 뒤 `onGameResize` → `_syncLayout`에서 수행.
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();
    camera.backdrop.add(SpaceBg());

    _hud = MatchGameHud(
      onPausePressed: pauseGame,
      onHintPressed: requestHint,
      onTutorialPressed: showHowToPlay,
      onRankingPressed: isTimedMode ? pauseForRankingPopup : null,
    );
    camera.viewport.add(_hud!);

    world.add(MatchBoardRenderer(logic: board));

    _particlePool = ParticlePool(world);
    _specialEffectPool = SpecialEffectPool(world);

    if (isTimedMode) {
      _fetchTop1();
    }
  }

  Future<void> _fetchTop1() async {
    final top = await RankingService.fetchTop1();
    if (top != null) {
      rankingTop1Name = top.name;
      rankingTop1Score = top.score;
    }
  }

  double get hudScale => (size.x < size.y ? size.x : size.y) * _hudScaleRatio;

  /// 레이아웃용 [hudScale]은 50~100대라 그대로 `fontSize`에 곱하면 글자가 비정상적으로 커진다.
  static const double _hudLayoutRef = 72.0;
  double get hudTextScale => (hudScale / _hudLayoutRef).clamp(0.68, 1.42);

  double get panelCenterY => safeAreaPadding.top + hudScale * 0.62;

  double get safeContentLeft => safeAreaPadding.left + size.x * 0.03;

  double get safeContentRight => size.x - safeAreaPadding.right - size.x * 0.03;

  double get safeContentWidth =>
      (safeContentRight - safeContentLeft).clamp(0.0, double.infinity);

  double get safeContentCenterX => safeContentLeft + safeContentWidth / 2;

  double get gridTopY => topChromeHeight;

  double get layoutRef {
    final availW = safeContentWidth;
    final maxGridH =
        (size.y - safeAreaPadding.bottom - gridTopY - bottomChromeHeight - 12)
            .clamp(0.0, double.infinity);
    return availW < maxGridH ? availW : maxGridH;
  }

  /// 보드(셀) 영역 하단 Y — HUD에서 하단 패널 배치·히트 테스트에 사용.
  double get boardPixelBottom {
    final t = board.tileSize;
    if (t <= 0) return gridTopY;
    return board.boardY + rows * t;
  }

  /// 인트로 중에는 Flutter [IntroBlock] 오버레이로 전체 입력 차단(투명).
  void _syncIntroInputBlock() {
    if (board.introFillInProgress) {
      if (!overlays.isActive('IntroBlock')) {
        overlays.add('IntroBlock');
      }
    } else {
      overlays.remove('IntroBlock');
    }
  }

  void _syncLayout() {
    if (!hasLayout || size.x <= 0 || size.y <= 0) return;

    final ref = layoutRef;
    if (ref <= 0 || !ref.isFinite) return;

    const spacingRatio = 0.06;
    final denom = cols + spacingRatio * (cols + 1);
    final tile = ref / denom;
    if (tile <= 0 || !tile.isFinite) return;

    final spacing = tile * spacingRatio;
    final gridW = cols * tile + (cols + 1) * spacing;
    final left = safeContentLeft + (safeContentWidth - gridW) / 2 + spacing;
    final top = gridTopY + spacing;

    board.setGeometry(x: left, y: top, tile: tile);

    if (!_boardSeededFromLayout) {
      board.generateFreshBoard();
      _boardSeededFromLayout = true;
    } else if (board.state == 'idle' && !board.introFillInProgress) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final g = board.getGem(r, c);
          if (g != null) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
    _syncIntroInputBlock();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncLayout();
  }

  void pauseGame() {
    if (!isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('PauseMenu');
  }

  void resumeGame() {
    if (timeUp) return;
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    overlays.remove('PauseMenu');
    overlays.remove('RankingList');
    isPlaying = true;
  }

  /// 타임 모드 HUD 랭킹 버튼: 게임 일시정지 + 랭킹 팝업.
  void pauseForRankingPopup() {
    if (!isTimedMode || !isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('RankingList');
  }

  void closeRankingPopup() {
    if (timeUp) return;
    overlays.remove('RankingList');
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    isPlaying = true;
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return;
      case AppLifecycleState.detached:
        super.lifecycleStateChange(state);
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        super.lifecycleStateChange(state);
        SoundManager.pauseBgm(onlyIfCurrent: AssetPaths.bgmMain);
        if (isPlaying && !timeUp) {
          isPlaying = false;
          overlays.add('PauseMenu');
        }
        break;
    }
  }

  void _triggerTimeUp() {
    if (!isTimedMode || timeUp) return;
    timeUp = true;
    isPlaying = false;
    GameSettings.saveBestMatchScoreIfBetter(gameMode, board.score);
    _lastSavedScore = board.score;
    pauseEngine();
    overlays.add('TimeUp');
    SoundManager.playSfx(AssetPaths.sfxTimeUp);
  }

  /// 같은 모드로 점수·타이머·보드 초기화.
  void restartRound() {
    overlays.remove('TimeUp');
    overlays.remove('PauseMenu');
    overlays.remove('NoMoves');
    overlays.remove('HowToPlay');
    overlays.remove('RankingList');
    timeUp = false;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    _lastSavedScore = -1;
    if (isTimedMode) {
      timeRemaining = timedRoundSeconds;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
    board.generateFreshBoard();
    _syncIntroInputBlock();
    resumeEngine();
    isPlaying = true;
    SoundManager.playBgm(AssetPaths.bgmMain);
  }

  @override
  void update(double dt) {
    board.update(dt);
    _spawnSpecialEffectEvents();
    _updateCameraShake(dt);

    if (isTimedMode && isPlaying && !timeUp && !board.introFillInProgress) {
      timeRemaining -= dt;
      final floored = timeRemaining.floor();
      if (timeRemaining > 0 &&
          floored >= 1 &&
          floored <= timedLowTimeTickMaxSeconds) {
        if (_lastFlooredSecondForTimeTic >= 0 &&
            floored < _lastFlooredSecondForTimeTic) {
          SoundManager.playSfx(AssetPaths.sfxTimeTic);
        }
      }
      _lastFlooredSecondForTimeTic = floored;

      if (timeRemaining <= 0) {
        timeRemaining = 0;
        _triggerTimeUp();
      }
    }

    if (!timeUp && board.state == 'idle' && board.score != _lastSavedScore) {
      GameSettings.saveBestMatchScoreIfBetter(gameMode, board.score);
      _lastSavedScore = board.score;
    }
    super.update(dt);
  }

  void _spawnSpecialEffectEvents() {
    final events = board.consumeSpecialEffectEvents();
    if (events.isEmpty || board.tileSize <= 0) return;

    for (final event in events) {
      final color =
          event.triggerColor != null &&
              event.triggerColor! >= 1 &&
              event.triggerColor! <= MatchBoardLogic.palette.length
          ? MatchBoardLogic.palette[event.triggerColor! - 1]
          : _colorAt(event.origin.x, event.origin.y);
      _specialEffectPool.spawn(
        effectKind: event.effectKind,
        origin: _cellCenter(event.origin.x, event.origin.y),
        affectedCenters: event.affectedCells
            .map((cell) => _cellCenter(cell.x, cell.y))
            .toList(growable: false),
        tileSize: board.tileSize,
        baseColor: color,
      );
      _queueCameraShake(event.shake);
    }
  }

  /// Browser QA hook for previewing every high-impact special VFX path.
  void debugTriggerSpecialEffects() {
    if (board.tileSize <= 0) return;

    final centerRow = rows ~/ 2;
    final centerCol = cols ~/ 2;
    final effects = <_DebugSpecialEffect>[
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: -3,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: -3,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 2,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: 2,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.bomb,
        rowOffset: -1,
        colOffset: -1,
        colorIndex: 0,
        shake: SpecialEffectShake(intensity: 4.8, duration: 0.30),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.star,
        rowOffset: -1,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 4.2, duration: 0.26),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.hyper,
        rowOffset: 0,
        colOffset: -1,
        colorIndex: 2,
        shake: SpecialEffectShake(intensity: 5.4, duration: 0.36),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.supernova,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 3,
        shake: SpecialEffectShake(intensity: 7.2, duration: 0.46),
      ),
    ];

    for (final effect in effects) {
      final row = (centerRow + effect.rowOffset).clamp(0, rows - 1);
      final col = (centerCol + effect.colOffset).clamp(0, cols - 1);
      _specialEffectPool.spawn(
        effectKind: effect.kind,
        origin: _cellCenter(row, col),
        affectedCenters: _debugAffectedCenters(effect.kind, row, col),
        tileSize: board.tileSize,
        baseColor: MatchBoardLogic.palette[effect.colorIndex],
      );
      _queueCameraShake(effect.shake);
    }
  }

  List<Vector2> _debugAffectedCenters(GemKind kind, int row, int col) {
    final cells = <Vector2>[];

    void addCell(int r, int c) {
      if (board.isInside(r, c)) {
        cells.add(_cellCenter(r, c));
      }
    }

    switch (kind) {
      case GemKind.bomb:
        for (var r = row - 1; r <= row + 1; r++) {
          for (var c = col - 1; c <= col + 1; c++) {
            addCell(r, c);
          }
        }
        break;
      case GemKind.star:
        for (var c = 0; c < cols; c++) {
          addCell(row, c);
        }
        for (var r = 0; r < rows; r++) {
          addCell(r, col);
        }
        break;
      case GemKind.hyper:
        for (var r = row - 2; r <= row + 2; r++) {
          for (var c = col - 2; c <= col + 2; c++) {
            if ((r - row).abs() + (c - col).abs() <= 2) {
              addCell(r, c);
            }
          }
        }
        break;
      case GemKind.supernova:
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            addCell(r, c);
          }
        }
        break;
      case GemKind.row:
        for (var c = 0; c < cols; c++) {
          addCell(row, c);
        }
        break;
      case GemKind.col:
        for (var r = 0; r < rows; r++) {
          addCell(r, col);
        }
        break;
      case GemKind.normal:
        break;
    }

    return cells;
  }

  Vector2 _cellCenter(int row, int col) {
    final half = board.tileSize / 2;
    return Vector2(
      board.boardX + col * board.tileSize + half,
      board.boardY + row * board.tileSize + half,
    );
  }

  Color _colorAt(int row, int col) {
    final gem = board.getGem(row, col);
    final color = gem?.color ?? 0;
    if (color >= 1 && color <= MatchBoardLogic.palette.length) {
      return MatchBoardLogic.palette[color - 1];
    }
    return Colors.white;
  }

  void _queueCameraShake(SpecialEffectShake shake) {
    if (shake.intensity <= 0 || shake.duration <= 0) return;
    _shakeIntensity = max(_shakeIntensity, shake.intensity);
    _shakeDuration = max(_shakeDuration, shake.duration);
    _shakeRemaining = max(_shakeRemaining, shake.duration);
    _shakeElapsed = 0;
  }

  void _updateCameraShake(double dt) {
    if (_shakeRemaining <= 0 || _shakeDuration <= 0) {
      camera.viewfinder.position = Vector2.zero();
      _shakeIntensity = 0;
      _shakeDuration = 0;
      _shakeRemaining = 0;
      _shakeElapsed = 0;
      return;
    }

    _shakeRemaining = max(0, _shakeRemaining - dt);
    _shakeElapsed += dt;
    if (_shakeRemaining <= 0) {
      camera.viewfinder.position = Vector2.zero();
      _shakeIntensity = 0;
      _shakeDuration = 0;
      _shakeElapsed = 0;
      return;
    }

    final falloff = _shakeRemaining / _shakeDuration;
    final amplitude = _shakeIntensity * falloff * falloff;
    final phase = _shakeElapsed / _shakeDuration;
    final primary = sin(phase * pi * 9.0);
    final secondary = sin(phase * pi * 13.0 + pi / 3);
    final vertical = sin(phase * pi * 7.0 + pi / 2);
    camera.viewfinder.position = Vector2(
      (primary * 0.82 + secondary * 0.18) * amplitude,
      vertical * amplitude * 0.48,
    );
  }

  void handleBoardTap(double x, double y) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    board.handleTap(x, y);
  }

  /// 스와이프 입력: 시작 좌표(px)에서 [dr]/[dc] 방향으로 1칸 스왑 시도.
  void handleBoardSwipe(double startX, double startY, int dr, int dc) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    board.clearHint();
    final cell = board.pixelToCell(startX, startY);
    if (cell == null) return;
    final fromRow = cell.x;
    final fromCol = cell.y;
    final toRow = fromRow + dr;
    final toCol = fromCol + dc;
    if (!board.isInside(toRow, toCol)) return;
    board.selected = null;
    board.trySwap(fromRow, fromCol, toRow, toCol);
  }

  void requestHint() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    if (board.state != 'idle') return;
    if (board.showHint()) {
      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    }
  }

  /// 힌트 디밍만 해제 (보드 탭 외 UI 탭 등).
  void dismissHint() => board.clearHint();

  void showHowToPlay() {
    if (!isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('HowToPlay');
  }

  void closeHowToPlay() {
    if (timeUp) return;
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    overlays.remove('HowToPlay');
    isPlaying = true;
  }

  void shuffleBoard() {
    board.shuffle();
    overlays.remove('NoMoves');
    _syncIntroInputBlock();
  }

  void newBoard() {
    board.generateFreshBoard();
    overlays.remove('NoMoves');
    _syncIntroInputBlock();
  }

  /// [seconds]는 정수 초. [timedMaxTimeSeconds]까지 남은 여유(`room`)만큼만 가산하고,
  /// 보상 초 중 **초과분은 제외**(버림)한다.
  void _playInvalidSwapSfx() {
    SoundManager.playSfx(AssetPaths.sfxFail);
  }

  /// 매치 제거 시 파티클 스폰 + 추가 SFX.
  void _spawnParticles(
    List<({int row, int col, int color})> cells,
    bool bigMatch,
    bool hasSpecial,
    int combo,
  ) {
    // SFX: 특수 보석 > 4+매치 > 콤보 > 일반 매치 순으로 1개만 재생.
    if (hasSpecial) {
      SoundManager.playSfx(AssetPaths.sfxSpecialGem);
    } else if (bigMatch) {
      SoundManager.playSfx(AssetPaths.sfxBigMatch);
    } else if (combo >= 2) {
      SoundManager.playComboSfxDelayed(AssetPaths.sfxComboHit);
    } else {
      SoundManager.playSfx(AssetPaths.sfxCollect);
    }

    final ts = board.tileSize;
    final half = ts / 2;

    final bool intense = combo >= 3 || (bigMatch && combo >= 2);
    final bool medium = !intense && (bigMatch || combo >= 2);

    final int count;
    final double speed;
    final double size;
    final double life;
    final bool glow;
    if (intense) {
      count = 28;
      speed = 1.38;
      size = 1.38;
      life = 0.62;
      glow = true;
    } else if (medium) {
      count = 18;
      speed = 1.1;
      size = 1.14;
      life = 0.52;
      glow = true;
    } else {
      count = 12;
      speed = 0.9;
      size = 0.9;
      life = 0.46;
      glow = false;
    }

    for (final c in cells) {
      final px = board.boardX + c.col * ts + half;
      final py = board.boardY + c.row * ts + half;
      final color = c.color >= 1 && c.color <= MatchBoardLogic.palette.length
          ? MatchBoardLogic.palette[c.color - 1]
          : Colors.white;
      _particlePool.spawn(
        center: Vector2(px, py),
        baseColor: color,
        count: count,
        lifetime: life,
        speedScale: speed,
        sizeScale: size,
        withGlow: glow,
      );
    }
  }

  void _applyTimedModeTimeBonus(int seconds) {
    if (!isTimedMode || timeUp || seconds <= 0) return;
    final cap = timedMaxTimeSeconds;
    final room = cap - timeRemaining;
    if (room <= 0) {
      return;
    }
    final applied = min(seconds.toDouble(), room);
    timeRemaining += applied;
  }
}

class _DebugSpecialEffect {
  const _DebugSpecialEffect({
    required this.kind,
    required this.rowOffset,
    required this.colOffset,
    required this.colorIndex,
    required this.shake,
  });

  final GemKind kind;
  final int rowOffset;
  final int colOffset;
  final int colorIndex;
  final SpecialEffectShake shake;
}
