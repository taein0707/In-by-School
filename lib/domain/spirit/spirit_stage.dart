/// The 10 evolution stages of 토리 (the knowledge spirit).
///
/// A single character that evolves — these are growth states of the *same*
/// being, not separate characters. Each stage carries what 토리 "learned"
/// (its analysis ability) AND a `sampleLine` showing how its voice deepens.
/// 정령 성장 = AI 성장: higher stages analyse deeper and speak more precisely.
class SpiritStage {
  final int index;
  final String name; // 한국어
  final String en;
  final int levelMin;
  final int levelMax; // inclusive; archive uses a large sentinel
  final String lore;
  final String learned; // "토리가 배운 것" — surfaced on the growth screen
  final String sampleLine; // how 토리 speaks at this stage (tone/depth)

  const SpiritStage({
    required this.index,
    required this.name,
    required this.en,
    required this.levelMin,
    required this.levelMax,
    required this.lore,
    required this.learned,
    required this.sampleLine,
  });

  bool get isFinal => index == all.length - 1;

  static const List<SpiritStage> all = [
    SpiritStage(index: 0, name: '알', en: 'Egg', levelMin: 1, levelMax: 5,
        lore: '아직 깨어나지 않은 지식의 알. 안에서 작은 빛이 맴돌아요.',
        learned: '함께 공부 시간을 기록해요.',
        sampleLine: '오늘 30분 공부했어요. 잘하고 있어요.'),
    SpiritStage(index: 1, name: '빛의 점', en: 'Light Point', levelMin: 6, levelMax: 10,
        lore: '껍질을 깨고 나온 한 점의 빛. 호기심이 막 피어나요.',
        learned: '오늘 얼마나 공부했는지 짚어줘요.',
        sampleLine: '오늘은 40분 집중했어요. 어제보다 길어요.'),
    SpiritStage(index: 2, name: '작은 정령', en: 'Small Spirit', levelMin: 11, levelMax: 20,
        lore: '눈을 뜬 작은 정령. 당신의 리듬을 보기 시작해요.',
        learned: '집중이 잘 되는 시간대를 알아채요.',
        sampleLine: '저녁 시간대에 집중이 잘 되는 것 같아요.'),
    SpiritStage(index: 3, name: '정령', en: 'Spirit', levelMin: 21, levelMax: 35,
        lore: '또렷한 표정을 갖춘 정령. 곁에서 함께 살펴봐요.',
        learned: '과목 편중을 분석하고 균형을 제안해요.',
        sampleLine: '이번 주는 수학 비중이 높았어요. 다른 과목도 볼까요?'),
    SpiritStage(index: 4, name: '고급 정령', en: 'Advanced Spirit', levelMin: 36, levelMax: 50,
        lore: '빛의 두건을 두른 정령. 흐름을 읽어요.',
        learned: '주간 추세를 읽고 맞춤 공부법을 추천해요.',
        sampleLine: '최근 집중 시간이 길어지는 추세예요. 지금 방식이 잘 맞아요.'),
    SpiritStage(index: 5, name: '현명한 정령', en: 'Wise Spirit', levelMin: 51, levelMax: 70,
        lore: '빛의 관을 쓴 학자. 조언이 깊어졌어요.',
        learned: '과목별로 복습 시점을 구체적으로 제안해요.',
        sampleLine: '영어는 마지막 복습이 5일 전이에요. 오늘 가볍게 돌아보면 좋겠어요.'),
    SpiritStage(index: 6, name: '수호 정령', en: 'Guardian Spirit', levelMin: 71, levelMax: 100,
        lore: '수호자의 자세를 갖춘 정령. 꾸준함을 지켜줘요.',
        learned: '백지복습을 정밀하게 분석해요.',
        sampleLine: '백지복습을 보니 핵심 개념은 잡았는데, 예시 연결이 약해요.'),
    SpiritStage(index: 7, name: '대정령', en: 'Great Spirit', levelMin: 101, levelMax: 150,
        lore: '위엄을 갖춘 큰 정령. 지식이 몸을 따라 흘러요.',
        learned: '장기 학습과 시험 대비를 정교하게 설계해요.',
        sampleLine: '시험이 12일 남았어요. 하루 2시간 30분, 수학에 40%를 배분하길 권해요.'),
    SpiritStage(index: 8, name: '현자 정령', en: 'Sage Spirit', levelMin: 151, levelMax: 250,
        lore: '원숙한 현자. 통찰이 깊어요.',
        learned: '여러 주의 데이터로 약점을 짚어줘요.',
        sampleLine: '최근 3주 데이터를 보면 오답이 함수 그래프 유형에 집중돼 있어요.'),
    SpiritStage(index: 9, name: '아카이브 정령', en: 'Archive Spirit', levelMin: 251, levelMax: 1 << 30,
        lore: '지식으로 직조된 존재. 함께한 모든 학습이 몸에 새겨져요.',
        learned: '당신만의 학습 아카이브로 가장 깊은 분석을 제공해요.',
        sampleLine: '지난 6개월을 종합하면 저녁 8~10시·45분 세션에서 가장 높은 효율을 보였습니다.'),
  ];

  static SpiritStage forLevel(int level) {
    for (int i = all.length - 1; i >= 0; i--) {
      if (level >= all[i].levelMin) return all[i];
    }
    return all.first;
  }

  static int indexForLevel(int level) => forLevel(level).index;
}
