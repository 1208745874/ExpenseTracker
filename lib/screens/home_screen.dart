import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../utils/date_utils.dart' as date_utils;
import 'add_expense_screen.dart';


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

  double _dailyBudget = 0.0;//每日预算
  double _todayExpense = 0.0;//选中日期当天已消费
  double _savedToDate = 0.0;//本月截至选中日期累计结余，正数已省，负数超支
  int _daysInMonth = 30; //当月天数，默认30

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

    //当月的天数
    final days =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;

    //每日预算
    final dailyBudget =
        budget == null ? 0.0 : budget.amount / days;

    //选中日期当天的支出
    final todayExpense = expenses
        .where((e) => _isSameDay(DateTime.parse(e.date), _selectedDate))
        .fold(0.0, (sum, e) => sum + e.amount);

    //本月从一号到选中日期的累计支出
    final cumulativeExpense = expenses
        .where((e) => DateTime.parse(e.date).day <= _selectedDate.day)
        .fold(0.0, (sum, e) => sum + e.amount);

    final savedToDate = budget == null
        ? 0.0
        :dailyBudget * _selectedDate.day - cumulativeExpense;

    setState(() {
      _monthTotal = total;
      _budget = budget;
      _dailyBudget = dailyBudget;
      _todayExpense = todayExpense;
      _savedToDate = savedToDate;
      _daysInMonth = days;
      _isLoading = false;
    });

    // 3. 【核心逻辑】如果没有预算，弹出设置对话框
    if (_budget == null) {
      _showSetBudgetDialog();
    }
  }

  bool _isSameDay(DateTime a, DateTime b){
    return a.year==b.year && a.month==b.month && a.day==b.day;
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
    final isToday = _isSameDay(_selectedDate, DateTime.now());

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
                  // ---- 今日日期（保持不变） ----
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

                  // ---- 本月支出主卡片 ----
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

                          // ---- 进度条和理想进度 ----
                          if (_budget != null) ...[
                            LinearProgressIndicator(
                              value: (_monthTotal / _budget!.amount).clamp(0.0, 1.0).toDouble(),
                              backgroundColor: Colors.grey.shade200,
                              color: _monthTotal > _budget!.amount ? Colors.red : Colors.lightBlue,
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
                                    color: _monthTotal > _budget!.amount ? Colors.red : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),

                            // 新增：理想进度提示（带灰色进度条）
                            if (_budget != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    // 灰色的理想进度条，高度调细一点（4px）
                                    LinearProgressIndicator(
                                      value: (_selectedDate.day / _daysInMonth).clamp(0.0, 1.0).toDouble(),
                                      backgroundColor: Colors.transparent, // 或者用 Colors.grey.shade100
                                      color: Colors.grey.shade300, // 淡淡的灰色
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    const SizedBox(height: 6),
                                    // 下面的文字行
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '理想进度：应花 ¥${(_dailyBudget * _selectedDate.day).toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                        Text(
                                          '${((_selectedDate.day / _daysInMonth) * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (_monthTotal > _budget!.amount)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      '已超预算！',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                          ] else ...[
                            const Text(
                              '点击下方 "＋" 记账后，可设置本月预算',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

          const SizedBox(height: 16),

          // ---- 新增：移到下方的两个小卡片 ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：今日预算卡片（带进度条）
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.lightBlue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSameDay(_selectedDate, DateTime.now()) ? '今日预算' : '${_selectedDate.day}日预算',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _budget == null ? '--' : '¥${_dailyBudget.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlue),
                        ),
                        const SizedBox(height: 8),

                        // 今日进度条
                        if (_budget != null) ...[
                          LinearProgressIndicator(
                            value: (_todayExpense / _dailyBudget).clamp(0.0, 1.0).toDouble(),
                            backgroundColor: Colors.lightBlue.shade50,
                            color: _todayExpense > _dailyBudget ? Colors.red : Colors.lightBlue,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_isSameDay(_selectedDate, DateTime.now()) ? '今日' : '当日'}已消费 ¥${_todayExpense.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _todayExpense > _dailyBudget ? Colors.red : Colors.grey.shade600,
                              fontWeight: _todayExpense > _dailyBudget ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '设置预算后计算',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 右侧：累计结余卡片（保持原样）
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_savedToDate >= 0 ? Colors.green : Colors.red).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (_savedToDate >= 0 ? Colors.green : Colors.red).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本月截至${_selectedDate.day}日',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _budget == null
                            ? '--'
                            : '${_savedToDate >= 0 ? '已省' : '超支'} ¥${_savedToDate.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _savedToDate >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _budget == null ? '设置预算后计算' : '含今日预算，随今日消费动态变化',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // ---- 底部提示文案（保持不变） ----
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