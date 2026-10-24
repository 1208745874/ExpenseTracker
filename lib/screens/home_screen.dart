import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../utils/date_utils.dart' as date_utils;
import 'add_expense_screen.dart'; // 录入页（第7步实现，现在会报错，别担心）

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---- 状态变量 ----
  DateTime _selectedDate = DateTime.now(); // 当前选中的日期
  String get _yearMonth => DateFormat('yyyy-MM').format(_selectedDate); // 当前年月
  double _monthTotal = 0.0; // 本月总支出
  Budget? _budget; // 本月预算（可能为null）
  bool _isLoading = true; // 加载状态

  // ---- 生命周期 ----
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---- 核心方法：加载数据 ----
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. 查询当前月份的支出
    final expenses = await DBHelper().getExpensesByMonth(_yearMonth);
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // 2. 查询当前月份的预算
    final budget = await DBHelper().getBudget(_yearMonth);

    setState(() {
      _monthTotal = total;
      _budget = budget;
      _isLoading = false;
    });

    // 3. 【核心逻辑】如果没有预算，弹出设置对话框
    if (_budget == null) {
      _showSetBudgetDialog();
    }
  }

  // ---- 弹出预算设置对话框 ----
  void _showSetBudgetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭，必须填写或取消
      builder: (ctx) => AlertDialog(
        title: Text('设置 $_yearMonth 月预算'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '请输入本月预算金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 如果用户取消，不设置预算，但首页会显示“未设置预算”
            },
            child: const Text('暂不设置'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                await DBHelper().setBudget(_yearMonth, amount);
                Navigator.pop(ctx);
                _loadData(); // 刷新页面
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('请输入有效的正数金额'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ---- 切换月份 ----
  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
        1,
      );
      _loadData();
    });
  }

  // ---- 选择日期（支持选过去日期录旧账） ----
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loadData();
      });
    }
  }

  // ---- 跳转到录入页 ----
  void _goToAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddExpenseScreen(
          defaultDate: _selectedDate,
          onSaved: _loadData, // 录入保存后回调刷新首页
        ),
      ),
    );
  }

  // ---- 构建UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 左箭头（切换上个月）
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            // 年月显示（可点击选择日期）
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightBlue.shade200),
                ),
                child: Text(
                  DateFormat('yyyy年MM月').format(_selectedDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            // 右箭头（切换下个月，不能超过当前月）
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final now = DateTime.now();
                if (_selectedDate.isBefore(DateTime(now.year, now.month, 1))) {
                  _changeMonth(1);
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            // 如果选中的是当前月，显示一个小圆点
            if (_selectedDate.year == DateTime.now().year &&
                _selectedDate.month == DateTime.now().month)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.circle, size: 8, color: Colors.green),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- 今日日期（可点击选择具体日期） ----
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Text(
                          date_utils.DateUtils.formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('选择日期'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---- 本月支出卡片 ----
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            '本月已消费',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '¥ ${_monthTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ---- 预算进度条（如果有预算） ----
                          if (_budget != null) ...[
                            LinearProgressIndicator(
                              value: _monthTotal / _budget!.amount,
                              backgroundColor: Colors.grey.shade200,
                              color: _monthTotal > _budget!.amount
                                  ? Colors.red
                                  : Colors.lightBlue,
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '预算 ¥${_budget!.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '${((_monthTotal / _budget!.amount) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _monthTotal > _budget!.amount
                                        ? Colors.red
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (_monthTotal > _budget!.amount)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Colors.red, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      '已超预算！',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ] else ...[
                            // ---- 未设置预算时的提示 ----
                            const Text(
                              '点击下方 "＋" 记账后，可设置本月预算',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ---- 底部提示文案 ----
                  Center(
                    child: Text(
                      '点击 "＋" 记录一笔支出',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

      // ---- 右下角悬浮"+"按钮 ----
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddExpense,
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ---- 供外部调用的刷新方法（录入页保存后调用） ----
  void refreshData() => _loadData();
}