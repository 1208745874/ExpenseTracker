import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/budget.dart';

/// 数据库帮助类（单例模式）
/// 整个App只维护一个数据库连接，避免重复打开
class DBHelper {
  // 1. 私有构造函数（单例模式）
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  // 2. 数据库实例（全局唯一，懒加载）
  static Database? _database;

  // 3. 获取数据库实例（如果未打开则初始化）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // 4. 初始化数据库（创建文件 + 建表）
  Future<Database> _initDB() async {
    // 获取应用文档目录（Android: /data/data/包名/app_flutter/，iOS: NSDocumentDirectory）
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'book_keep.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // 5. 首次创建数据库时执行（建表 + 插入默认分类）
  Future<void> _onCreate(Database db, int version) async {
    // ---- 5.1 创建分类表 ----
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    // ---- 5.2 创建支出表 ----
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // ---- 5.3 创建预算表 ----
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_month TEXT NOT NULL UNIQUE,
        amount REAL NOT NULL
      )
    ''');

    // ---- 5.4 插入9个默认分类 ----
    final defaultCategories = [
      {'name': '餐饮', 'icon': '🍜'},
      {'name': '交通', 'icon': '🚌'},
      {'name': '购物', 'icon': '🛍️'},
      {'name': '居住', 'icon': '🏠'},
      {'name': '通讯', 'icon': '📱'},
      {'name': '娱乐', 'icon': '🎮'},
      {'name': '医疗', 'icon': '💊'},
      {'name': '人情', 'icon': '🎁'},
      {'name': '其他', 'icon': '❓'},
    ];
    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  // ============================================================
  //  以下为对外暴露的 CRUD 方法（供各页面调用）
  // ============================================================

  // ---------- 分类相关 ----------
  /// 获取所有分类（按 id 升序）
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'id');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  // ---------- 支出相关 ----------
  /// 插入一条支出
  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.toMap());
  }

  /// 获取所有支出（默认按创建时间倒序，即最新在前）
  Future<List<Expense>> getAllExpenses({String? orderBy = 'created_at DESC'}) async {
    final db = await database;
    final result = await db.query('expenses', orderBy: orderBy);
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  /// 按年月查询支出（用于首页、统计页）
  /// yearMonth 格式: '2026-09'
  Future<List<Expense>> getExpensesByMonth(String yearMonth) async {
    final db = await database;
    final result = await db.query(
      'expenses',
      where: 'date LIKE ?',
      whereArgs: ['$yearMonth%'], // 匹配 '2026-09-01', '2026-09-15'...
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  /// 按年月 + 分类汇总（用于饼图）
  /// 返回 Map<分类ID, 该分类的总支出>
  Future<Map<int, double>> getCategoryTotalByMonth(String yearMonth) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM expenses
      WHERE date LIKE ?
      GROUP BY category_id
    ''', ['$yearMonth%']);
    Map<int, double> map = {};
    for (var row in result) {
      map[row['category_id'] as int] = (row['total'] as num).toDouble();
    }
    return map;
  }

  /// 按年查询各月支出（用于折线图）
  /// 返回 Map<"2026-01", 总金额>
  Future<Map<String, double>> getMonthlyTotalByYear(String year) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m', date) as month, SUM(amount) as total
      FROM expenses
      WHERE date LIKE ?
      GROUP BY month
      ORDER BY month
    ''', ['$year%']);
    Map<String, double> map = {};
    for (var row in result) {
      map[row['month'] as String] = (row['total'] as num).toDouble();
    }
    return map;
  }

  /// 删除单条支出
  Future<int> deleteExpense(String id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// 清空所有支出（用于导入时的全量覆盖）
  Future<void> deleteAllExpenses() async {
    final db = await database;
    await db.delete('expenses');
  }

  /// 批量插入支出（用于导入）
  Future<void> insertExpensesBatch(List<Expense> expenses) async {
    final db = await database;
    final batch = db.batch();
    for (var e in expenses) {
      batch.insert('expenses', e.toMap());
    }
    await batch.commit();
  }

  // ---------- 预算相关 ----------
  /// 获取某个月的预算（如果没有设置，返回 null）
  Future<Budget?> getBudget(String yearMonth) async {
    final db = await database;
    final result = await db.query(
      'budgets',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );
    if (result.isEmpty) return null;
    return Budget.fromMap(result.first);
  }

  /// 设置某个月的预算（如果已存在则更新，不存在则插入）
  Future<void> setBudget(String yearMonth, double amount) async {
    final db = await database;
    final existing = await getBudget(yearMonth);
    if (existing != null) {
      // 更新
      await db.update(
        'budgets',
        {'amount': amount},
        where: 'year_month = ?',
        whereArgs: [yearMonth],
      );
    } else {
      // 插入
      await db.insert('budgets', {'year_month': yearMonth, 'amount': amount});
    }
  }
}