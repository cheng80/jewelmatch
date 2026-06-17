enum ItemKind {
  runeHammer,
  ancientBomb,
  thorHammer,
  hyperCube,
  prismTransform,
  fateShuffle,
  timeSlip,
  hintPlus,
}

extension ItemKindMeta on ItemKind {
  static const phaseOneLoadout = [
    ItemKind.runeHammer,
    ItemKind.ancientBomb,
    ItemKind.thorHammer,
    ItemKind.hyperCube,
    ItemKind.prismTransform,
    ItemKind.fateShuffle,
    ItemKind.timeSlip,
    ItemKind.hintPlus,
  ];

  String get label => switch (this) {
    ItemKind.runeHammer => '룬\n망치',
    ItemKind.ancientBomb => '고대\n폭탄',
    ItemKind.thorHammer => '토르\n망치',
    ItemKind.hyperCube => '하이퍼\n큐브',
    ItemKind.prismTransform => '프리즘\n변환',
    ItemKind.fateShuffle => '운명\n셔플',
    ItemKind.timeSlip => '타임\n슬립',
    ItemKind.hintPlus => '힌트+',
  };

  String get shortLabel => switch (this) {
    ItemKind.runeHammer => '룬',
    ItemKind.ancientBomb => '폭',
    ItemKind.thorHammer => '토',
    ItemKind.hyperCube => '큐',
    ItemKind.prismTransform => '프',
    ItemKind.fateShuffle => '셔',
    ItemKind.timeSlip => '시',
    ItemKind.hintPlus => '힌',
  };

  bool get needsTarget => switch (this) {
    ItemKind.runeHammer ||
    ItemKind.ancientBomb ||
    ItemKind.thorHammer ||
    ItemKind.hyperCube ||
    ItemKind.prismTransform => true,
    ItemKind.fateShuffle || ItemKind.timeSlip || ItemKind.hintPlus => false,
  };
}
