import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../utils/date_utils.dart' as date_utils;

/// 录入页 —— 分类网格 + 点击放大动画 + 金额输入
class AddExpenseScreen extends StatefulWidget {
  final DateTime defaultDate; // 从首页传入的默认日期
  final VoidCallback onSaved; // 保存后的回调（刷新首页）

  const AddExpenseScreen({
    super.key,
    required this.defaultDate,
    required this.onSaved,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen>
    with SingleTickerProviderStateMixin {
  // ---- 状态变量 ----
  List<Category> _categories = [];
  Category? _selectedCategory; // 当前选中的分类
  late DateTime _selectedDate; // 当前选中的日期
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _showInputForm = false; // 是否显示输入表单
  bool _isLoading = true;

  // ---- 动画控制器 ----
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.defaultDate;
    _loadCategories();

    // 初始化动画
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  // ---- 加载分类 ----
  Future<void> _loadCategories() async {
    final cats = await DBHelper().getAllCategories();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  // ---- 点击分类 ----
  void _selectCategory(Category category) {
    setState(() {
      _selectedCategory = category;
    });
    // 播放放大动画
    _animationController.forward(from: 0.0);

    // 动画结束后展开输入表单
    Future.delayed(const Duration(milliseconds: 250), () {
      setState(() {
        _showInputForm = true;
      });
      // 自动聚焦到金额输入框
      Future.delayed(const Duration(milliseconds: 100), () {
        FocusScope.of(context).requestFocus(FocusNode());
      });
    });
  }

  // ---- 保存支出 ----
  Future<void> _saveExpense() async {
    // 校验：是否选择了分类
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一个分类'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 校验：金额是否有效
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的金额（大于0）'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 生成唯一ID：年月日时分秒毫秒 + 3位随机数
    final now = DateTime.now();
    final id =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}'
        '${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';

    final expense = Expense(
      id: id,
      date: date_utils.DateUtils.formatDate(_selectedDate),
      categoryId: _selectedCategory!.id!,
      amount: amount,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      createdAt: now,
    );

    // 保存到数据库
    await DBHelper().insertExpense(expense);

    // 回调刷新首页
    widget.onSaved();

    // 返回上一页
    Navigator.pop(context);
  }

  // ---- 选择日期 ----
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // ---- 重置录入状态（回到分类选择） ----
  void _resetToCategorySelection() {
    setState(() {
      _showInputForm = false;
      _selectedCategory = null;
      _amountController.clear();
      _noteController.clear();
    });
    _animationController.reverse();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveExpense,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- 日期选择器 ----
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            date_utils.DateUtils.formatDate(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_selectedDate.isBefore(DateTime.now()))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '补录旧账',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 32),

                  // ---- 分类网格（或输入表单） ----
                  if (!_showInputForm) ...[
                    const Text(
                      '选择分类',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory?.id == cat.id;

                          return GestureDetector(
                            onTap: () => _selectCategory(cat),
                            child: AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (ctx, child) {
                                return Transform.scale(
                                  scale: isSelected ? _scaleAnimation.value : 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.lightBlue.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.lightBlue.shade400
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          cat.icon,
                                          style: const TextStyle(fontSize: 32),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.lightBlue.shade800
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Colors.lightBlue,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // ---- 输入表单 ----
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_selectedCategory!.icon} ${_selectedCategory!.name}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _resetToCategorySelection,
                                  icon: const Icon(Icons.edit),
                                  tooltip: '重新选择分类',
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: '金额',
                                prefixText: '¥ ',
                                border: OutlineInputBorder(),
                                hintText: '0.00',
                              ),
                              onSubmitted: (_) => _saveExpense(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _noteController,
                              decoration: const InputDecoration(
                                labelText: '备注（可选）',
                                border: OutlineInputBorder(),
                                hintText: '例如：午餐',
                              ),
                              onSubmitted: (_) => _saveExpense(),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _saveExpense,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '保存',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ],
              ),
            ),
    );
  }
}