import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../utils/date_utils.dart' as date_utils;

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _viewMode = 'month';
  String _selectedMonth = date_utils.DateUtils.formatYearMonth(DateTime.now());
  String _selectedYear = DateTime.now().year.toString();
  bool _isLoading = true;
  List<Category> _categories = [];
  Map<int, double> _categoryTotal = {};
  Map<String, double> _monthlyTotal = {};
  double _monthTotal = 0;
  Budget? _budget;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _categories = await DBHelper().getAllCategories();
    if (_viewMode == 'month') {
      _categoryTotal = await DBHelper().getCategoryTotalByMonth(_selectedMonth);
      _monthTotal = _categoryTotal.values.fold(0.0, (sum, v) => sum + v);
      _budget = await DBHelper().getBudget(_selectedMonth);
    } else {
      _monthlyTotal = await DBHelper().getMonthlyTotalByYear(_selectedYear);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计分析'),
        actions: [
          DropdownButton<String>(
            value: _viewMode,
            items: const [
              DropdownMenuItem(value: 'month', child: Text('月视图')),
              DropdownMenuItem(value: 'year', child: Text('年视图')),
            ],
            onChanged: (val) {
              setState(() => _viewMode = val!);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_viewMode == 'month') ...[
              _buildMonthSelector(),
              const SizedBox(height: 16),
              _buildPieChart(),
              const SizedBox(height: 16),
              _buildAnalysisCards(),
            ] else ...[
              _buildYearSelector(),
              const SizedBox(height: 16),
              _buildLineChart(),
              const SizedBox(height: 16),
              _buildYearAnalysis(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final parts = _selectedMonth.split('-');
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final newMonth = month == 1 ? 12 : month - 1;
            final newYear = month == 1 ? year - 1 : year;
            setState(() {
              _selectedMonth = '$newYear-${newMonth.toString().padLeft(2, '0')}';
              _loadData();
            });
          },
        ),
        Text(_selectedMonth, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final now = DateTime.now();
            final currentMonth = date_utils.DateUtils.formatYearMonth(now);
            if (_selectedMonth == currentMonth) return;
            final parts = _selectedMonth.split('-');
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final newMonth = month == 12 ? 1 : month + 1;
            final newYear = month == 12 ? year + 1 : year;
            setState(() {
              _selectedMonth = '$newYear-${newMonth.toString().padLeft(2, '0')}';
              _loadData();
            });
          },
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedYear = (int.parse(_selectedYear) - 1).toString();
              _loadData();
            });
          },
        ),
        Text('$_selectedYear 年', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final now = DateTime.now().year.toString();
            if (_selectedYear == now) return;
            setState(() {
              _selectedYear = (int.parse(_selectedYear) + 1).toString();
              _loadData();
            });
          },
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    if (_categoryTotal.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('本月暂无支出')));
    final total = _categoryTotal.values.fold(0.0, (sum, v) => sum + v);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('各类支出占比', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: _categoryTotal.entries.map((entry) {
                    final cat = _categories.firstWhere((c) => c.id == entry.key);
                    final percentage = (entry.value / total) * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${cat.icon}\n${percentage.toStringAsFixed(1)}%',
                      color: Colors.primaries[entry.key % Colors.primaries.length],
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (_monthlyTotal.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('本年暂无支出')));
    final months = List.generate(12, (i) => '${_selectedYear}-${(i+1).toString().padLeft(2, '0')}');
    final maxVal = _monthlyTotal.values.isEmpty ? 100 : _monthlyTotal.values.reduce((a,b) => a > b ? a : b) * 1.2;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('月度趋势', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final month = months[value.toInt()]?.substring(5) ?? '';
                          return Text(month, style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: 11,
                  minY: 0,
                  maxY: maxVal.toDouble(),   // <--- 这里就是 maxY，写法正确
                  lineBarsData: [
                    LineChartBarData(
                      spots: months.asMap().entries.map((entry) {
                        final value = _monthlyTotal[entry.value] ?? 0;
                        return FlSpot(entry.key.toDouble(), value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.lightBlue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: true, color: Colors.lightBlue.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCards() {
    List<Widget> cards = [];
    cards.add(_infoCard('本月总支出', '¥${_monthTotal.toStringAsFixed(2)}', Icons.money_off));
    if (_budget != null) {
      final remaining = _budget!.amount - _monthTotal;
      cards.add(_infoCard(
        '预算剩余',
        '¥${remaining.toStringAsFixed(2)}',
        remaining >= 0 ? Icons.check_circle : Icons.warning,
        color: remaining >= 0 ? Colors.green : Colors.red,
      ));
      if (_monthTotal > _budget!.amount) {
        cards.add(_infoCard('超预算', '超支 ${(_monthTotal - _budget!.amount).toStringAsFixed(2)}', Icons.error, color: Colors.red));
      }
    }
    if (_categoryTotal.isNotEmpty) {
      final maxEntry = _categoryTotal.entries.reduce((a,b) => a.value > b.value ? a : b);
      final cat = _categories.firstWhere((c) => c.id == maxEntry.key);
      // ----- 修正这里：把金额作为第二个位置参数，而不是命名参数 -----
      cards.add(_infoCard('最高消费', '¥${maxEntry.value.toStringAsFixed(2)}', Icons.trending_up));
      // 如果你想同时显示分类名，可以改成：
      // cards.add(_infoCard('最高消费', '${cat.icon} ${cat.name}  ¥${maxEntry.value.toStringAsFixed(2)}', Icons.trending_up));
    }
    cards.add(_infoCard('记录笔数', '${_categoryTotal.values.length}', Icons.receipt_long));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards,
    );
  }

  Widget _buildYearAnalysis() {
    final totalYear = _monthlyTotal.values.fold(0.0, (sum, v) => sum + v);
    final avgMonth = _monthlyTotal.isEmpty ? 0 : totalYear / _monthlyTotal.length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _infoCard('年度总支出', '¥${totalYear.toStringAsFixed(2)}', Icons.money_off),
        _infoCard('月均支出', '¥${avgMonth.toStringAsFixed(2)}', Icons.calendar_month),
        _infoCard('有支出月份', '${_monthlyTotal.length}/12', Icons.date_range),
      ],
    );
  }

  Widget _infoCard(String title, String value, IconData icon, {Color color = Colors.lightBlue}) {
    return Card(
      elevation: 2,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void refreshData() => _loadData();
}