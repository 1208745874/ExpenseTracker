import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../utils/date_utils.dart' as date_utils;
import 'edit_expense_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Expense> _allExpenses = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedMonth = '';

  @override
  void initState() {
    super.initState();
    //_selectedMonth = date_utils.DateUtils.formatYearMonth(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allExpenses = await DBHelper().getAllExpenses(orderBy: 'date DESC, created_at DESC');
    _categories = await DBHelper().getAllCategories();

    // 【修复】如果没有任何数据，将选中的月份重置为 '全部'
    if (_allExpenses.isEmpty) {
      _selectedMonth = '';
    } else {
      // 如果当前选中的月份在已有数据中不存在，也重置为 '全部'
      final availableMonths = _allExpenses.map((e) => e.date.substring(0, 7)).toSet();
      if (_selectedMonth.isNotEmpty && !availableMonths.contains(_selectedMonth)) {
        _selectedMonth = '';
      }
    }

    setState(() => _isLoading = false);
  }

  List<Expense> _filteredExpenses() {
    var list = _allExpenses;
    if (_selectedMonth.isNotEmpty) {
      list = list.where((e) => e.date.startsWith(_selectedMonth)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) {
        final catName = _categories
            .firstWhere((c) => c.id == e.categoryId, orElse: () => Category(id: 0, name: '未知', icon: '❓'))
            .name;
        return e.note?.contains(_searchQuery) == true ||
            catName.contains(_searchQuery) ||
            e.amount.toString().contains(_searchQuery);
      }).toList();
    }
    return list;
  }

  Future<void> _deleteExpense(String id) async {
    await DBHelper().deleteExpense(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: Column(
        children: [
          // ---- 搜索栏 ----
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: '搜索（备注/分类/金额）',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          // ---- 月份筛选 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('月份：'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部')),
                      ..._allExpenses
                          .map((e) => e.date.substring(0, 7))
                          .toSet()
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                    ],
                    onChanged: (val) => setState(() => _selectedMonth = val ?? ''),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          const Divider(),
          // ---- 列表 ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses().isEmpty
                ? const Center(child: Text('暂无记录'))
                : ListView.builder(
              itemCount: _filteredExpenses().length,
              itemBuilder: (ctx, index) {
                final e = _filteredExpenses()[index];
                final cat = _categories.firstWhere(
                      (c) => c.id == e.categoryId,
                  orElse: () => Category(id: 0, name: '未知', icon: '❓'),
                );
                return Dismissible(
                  key: Key(e.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteExpense(e.id),
                  child: ListTile(
                    leading: Text(cat.icon, style: const TextStyle(fontSize: 28)),
                    title: Text('${cat.name}  ¥${e.amount.toStringAsFixed(2)}'),
                    subtitle: Text('${e.date}  ${e.note ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => EditExpenseScreen(
                            expense: e,
                            categories: _categories,
                          ),
                        ),
                      );
                      if (result == true) _loadData();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void refreshData() => _loadData();
}