import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../utils/csv_helper.dart';
import '../utils/date_utils.dart' as date_utils;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Budget? _currentBudget;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final now = date_utils.DateUtils.formatYearMonth(DateTime.now());
    final budget = await DBHelper().getBudget(now);
    setState(() {
      _currentBudget = budget;
      _isLoading = false;
    });
  }

  // ---- 1. 设置本月预算 ----
  Future<void> _setBudget() async {
    final controller = TextEditingController();
    if (_currentBudget != null) {
      controller.text = _currentBudget!.amount.toString();
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置本月预算（${date_utils.DateUtils.formatYearMonth(DateTime.now())}）'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '预算金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
          //autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                await DBHelper().setBudget(
                  date_utils.DateUtils.formatYearMonth(DateTime.now()),
                  amount,
                );
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入有效金额')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == true) await _loadBudget();
  }

  // ---- 2. 导出CSV ----
  Future<void> _exportCSV() async {
    try {
      final expenses = await DBHelper().getAllExpenses();
      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无数据可导出')),
        );
        return;
      }
      final categories = await DBHelper().getAllCategories();
      final file = await CSVHelper.exportExpenses(expenses, categories);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出成功！文件保存在：${file.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  // ---- 3. 导入CSV（全量覆盖）【适配 file_picker v12.x】 ----
  Future<void> _importCSV() async {
    // 【v12.x 新写法】直接调用 FilePicker.pickFiles()，不再需要 .platform
    final List<PlatformFile>? files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (files == null || files.isEmpty) return;

    // 【v12.x 新写法】直接从 files 列表中获取第一个文件的路径
    final String filePath = files.first.path!;

    // 确认覆盖
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 导入将覆盖所有数据'),
        content: const Text('导入会清空当前所有支出记录，并用CSV文件中的数据替代。\n\n确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定覆盖'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final categories = await DBHelper().getAllCategories();
      final expenses = await CSVHelper.importExpensesFromFile(filePath, categories);
      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件格式有误或无有效数据')),
        );
        return;
      }
      // 全量覆盖
      await DBHelper().deleteAllExpenses();
      await DBHelper().insertExpensesBatch(expenses);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入成功！共导入 ${expenses.length} 条记录')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.lightBlue),
                title: const Text('设置本月预算'),
                subtitle: Text(
                  _currentBudget != null
                      ? '当前预算：¥${_currentBudget!.amount.toStringAsFixed(2)}'
                      : '尚未设置本月预算',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _setBudget,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_upload, color: Colors.green),
                title: const Text('导出文件'),
                subtitle: const Text('导出所有支出为CSV文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportCSV,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_download, color: Colors.orange),
                title: const Text('导入文件'),
                subtitle: const Text('从CSV文件恢复数据（覆盖当前）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importCSV,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    '💡 导入/导出说明',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• 导出文件为CSV格式，可用Excel/WPS打开',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• 导入会覆盖当前所有数据，请先导出备份',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}