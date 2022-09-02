class Score {
  String name;    // 学科名称
  double score;   // 分数
  String year;    // 学年
  double credit;  // 学分
  String status;  // 修读状态
  String? classID; // 教学班序列号
  String? scoreStructure; //成绩构成
  String? scoreDetail; //分项成绩
  Score({
    required this.name,
    required this.score,
    required this.year,
    required this.credit,
    required this.status,
    this.classID,
    this.scoreStructure,
    this.scoreDetail,
  });
}

List<Score> scoreTable = [];

Score xianbei = Score(
  name: "淫梦学",
  score: 81,
  year: "2010-2009-1",
  credit: 4.0,
  status: "必修课",
  classID: "1145141919810"
);