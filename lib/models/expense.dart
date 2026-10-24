/// 支出记录模型 —— 每一笔具体花销
class Expense {
  final String id; // 自定义主键，格式：yyyyMMddHHmmssSSS + 3位随机数（确保唯一）
  final String date; // 交易日期，格式：yyyy-MM-dd
  final int categoryId; // 关联的分类ID
  final double amount; // 金额（正数）
  final String? note; // 备注（可选）
  final DateTime createdAt; // 这条记录的创建时间（用于排序，区分录入先后）

  Expense({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  /// 转 Map，用于插入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'created_at': createdAt.toIso8601String(), // 转成字符串存进数据库
    };
  }

  /// 从数据库 Map 转成 Expense 对象
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: map['date'],
      categoryId: map['category_id'],
      // 防止数据库里存的是 int，转成 double
      amount: map['amount'] is int 
          ? (map['amount'] as int).toDouble() 
          : map['amount'],
      note: map['note'],
      createdAt: DateTime.parse(map['created_at']), // 字符串转回 DateTime
    );
  }
}