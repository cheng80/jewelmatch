/// 클래식 비쥬얼드 스타일: 무제한(심플) / 제한 시간(타임).
enum JewelGameMode {
  /// 제한 시간 없이 최고 점수 갱신.
  simple,

  /// 주어진 시간 안에 최대한 점수.
  timed;

  static JewelGameMode fromQuery(String? value) =>
      value == 'timed' ? timed : simple;

  String get queryParam => switch (this) {
        simple => 'simple',
        timed => 'timed',
      };
}
