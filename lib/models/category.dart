/// 分类模型 —— 比如“餐饮”、“交通”
class Category {
  final int? id; // 数据库自增主键，新增时为 null，从数据库读出时有值
  final String name; // 分类名称，如“餐饮”
  final String icon; // Emoji 图标，如“🍜”

  Category({this.id, required this.name, required this.icon});

  /// 把对象转成 Map，用于插入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }

  /// 从数据库查询结果的 Map 转成 Category 对象
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
    );
  }
}