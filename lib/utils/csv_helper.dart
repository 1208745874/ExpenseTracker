import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';

class CSVHelper {
  /// 导出所有支出为 CSV 文件（保存到公共 Download 目录）
  static Future<File> exportExpenses(
      List<Expense> expenses,
      List<Category> categories,
      ) async {
    // 1. 获取 Downloads 目录（Android: /storage/emulated/0/Download）
    Directory? downloadsDir = await getDownloadsDirectory();

    // 2. 如果获取失败（极少情况），降级到 App 私有文档目录
    if (downloadsDir == null) {
      final appDocDir = await getApplicationDocumentsDirectory();
      downloadsDir = appDocDir;
    }

    final fileName = '支出备份_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${downloadsDir.path}/$fileName');

    // 3. 构建分类名称映射
    final categoryMap = {for (var c in categories) c.id: c.name};

    // 4. 构建 CSV 数据行
    List<List<String>> rows = [
      ['id', 'date', 'category_name', 'amount', 'note']
    ];

    for (var e in expenses) {
      final catName = categoryMap[e.categoryId] ?? '未知分类';
      rows.add([
        e.id,
        e.date,
        catName,
        e.amount.toString(),
        e.note ?? '',
      ]);
    }

    // 5. 转换为 CSV 字符串并写入文件
    final csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);
    return file;
  }

  /// 从 CSV 文件导入支出列表（返回 List<Expense>，不直接操作数据库）
  static Future<List<Expense>> importExpensesFromFile(
      String filePath,
      List<Category> categories,
      ) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final rows = const CsvToListConverter().convert(csvString);

    if (rows.length < 2) return [];

    final categoryMap = {for (var c in categories) c.name: c.id};

    List<Expense> expenses = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue;

      final id = row[0].toString().trim();
      final date = row[1].toString().trim();
      final categoryName = row[2].toString().trim();
      final amount = double.tryParse(row[3].toString().trim()) ?? 0.0;
      final note = row[4].toString().trim();

      final categoryId = categoryMap[categoryName];
      if (categoryId == null || amount <= 0) continue;

      // 从 ID 中提取创建时间
      DateTime createdAt;
      try {
        final idStr = id.length >= 14 ? id.substring(0, 14) : id;
        final year = int.parse(idStr.substring(0, 4));
        final month = int.parse(idStr.substring(4, 6));
        final day = int.parse(idStr.substring(6, 8));
        final hour = int.parse(idStr.substring(8, 10));
        final minute = int.parse(idStr.substring(10, 12));
        final second = int.parse(idStr.substring(12, 14));
        createdAt = DateTime(year, month, day, hour, minute, second);
      } catch (_) {
        createdAt = DateTime.now();
      }

      expenses.add(Expense(
        id: id,
        date: date,
        categoryId: categoryId,
        amount: amount,
        note: note.isNotEmpty ? note : null,
        createdAt: createdAt,
      ));
    }

    return expenses;
  }
}