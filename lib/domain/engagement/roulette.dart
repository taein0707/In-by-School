// 랜덤 룰렛(P4-4) — 학생/모둠/번호 추첨. 기록은 groupActivities(type=roulette)로 저장(신규 컬렉션 없음).
// 추첨 로직은 P3-2의 PresenterPicker/GroupMaker 를 재사용한다.

enum RouletteMode {
  student, // 학생 추첨
  team, // 모둠 추첨
  number; // 번호 추첨

  static RouletteMode fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => RouletteMode.student);

  String get label => switch (this) {
        RouletteMode.student => '학생 추첨',
        RouletteMode.team => '모둠 추첨',
        RouletteMode.number => '번호 추첨',
      };
}

/// 룰렛 보조 로직(테스트 대상). 추첨 자체는 PresenterPicker 를 재사용.
class RouletteLogic {
  RouletteLogic._();

  /// 번호 후보(1번 ~ count번).
  static List<String> numberPool(int count) =>
      [for (var i = 1; i <= (count < 0 ? 0 : count); i++) '$i번'];

  /// 추첨 대상 후보(모드별). team 모드는 호출 측에서 구성한 모둠 라벨을 넘긴다.
  static List<String> candidates(RouletteMode mode, {List<String> students = const [], int numberCount = 0}) {
    switch (mode) {
      case RouletteMode.number:
        return numberPool(numberCount);
      case RouletteMode.student:
      case RouletteMode.team:
        return [...students];
    }
  }
}
