/// 预算模型 —— 每个自然月一个预算
class Budget {
  final int? id; // 数据库自增主键
  final String yearMonth; // 年月，格式：yyyy-MM（例如 2026-09）
  final double amount; // 预算金额

  Budget({this.id, required this.yearMonth, required this.amount});

  /// 转 Map，用于插入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year_month': yearMonth,
      'amount': amount,
    };
  }

  /// 从数据库 Map 转成 Budget 对象
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      yearMonth: map['year_month'],
      amount: map['amount'] is int 
          ? (map['amount'] as int).toDouble() 
          : map['amount'],
    );
  }
}