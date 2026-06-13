/// 클래식 비쥬얼드 스타일: 무제한(심플) / XP 진행 / 제한 시간(타임).
enum JewelGameMode {
  /// 제한 시간 없이 최고 점수 갱신.
  simple,

  /// XP 기준 레벨업마다 새 보드로 진행.
  progression,

  /// 주어진 시간 안에 최대한 점수.
  timed;

  static JewelGameMode fromQuery(String? value) => switch (value) {
    'timed' => timed,
    'progression' => progression,
    _ => simple,
  };

  String get queryParam => switch (this) {
    simple => 'simple',
    progression => 'progression',
    timed => 'timed',
  };
}
