import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';

/// 编辑页 —— 修改已有支出记录
class EditExpenseScreen extends StatefulWidget {
  final Expense expense;
  final List<Category> categories;

  const EditExpenseScreen({
    super.key,
    required this.expense,
    required this.categories,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  late Expense _editedExpense;
  late Category _selectedCategory;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editedExpense = widget.expense;
    _selectedCategory = widget.categories.firstWhere(
      (c) => c.id == widget.expense.categoryId,
    );
    _amountController.text = widget.expense.amount.toString();
    _noteController.text = widget.expense.note ?? '';
  }

  Future<void> _saveEdit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效金额'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 创建更新后的 Expense 对象
    final updated = Expense(
      id: _editedExpense.id,
      date: _editedExpense.date,
      categoryId: _selectedCategory.id!,
      amount: amount,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      createdAt: _editedExpense.createdAt,
    );

    // 删除旧记录，插入新记录（避免复杂的 UPDATE 逻辑）
    await DBHelper().deleteExpense(updated.id);
    await DBHelper().insertExpense(updated);

    // 返回并告知历史页刷新
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑支出'),
        actions: [
          TextButton(
            onPressed: _saveEdit,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 日期（只读展示） ----
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _editedExpense.date,
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                const Text(
                  '日期不可修改',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 32),

            // ---- 分类选择（使用 ChoiceChip） ----
            const Text(
              '选择分类',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((cat) {
                final isSelected = _selectedCategory.id == cat.id;
                return ChoiceChip(
                  label: Text('${cat.icon} ${cat.name}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                  selectedColor: Colors.lightBlue.shade100,
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.lightBlue.shade800 : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ---- 金额输入 ----
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 备注输入 ----
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            // ---- 删除按钮（红色警示） ----
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定要删除这条记录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await DBHelper().deleteExpense(_editedExpense.id);
                    Navigator.pop(context, true);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('删除此记录'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}