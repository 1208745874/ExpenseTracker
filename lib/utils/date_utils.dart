/// 日期工具类 —— 统一管理日期格式转换
class DateUtils {
  /// 将 DateTime 格式化为 yyyy-MM-dd（例如 2026-09-05）
  static String formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  /// 将 DateTime 格式化为 yyyy-MM（例如 2026-09）
  static String formatYearMonth(DateTime date) {
    return '${date.year}-${_pad(date.month)}';
  }

  /// 补零：1 -> 01, 12 -> 12
  static String _pad(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// 从 yyyy-MM-dd 字符串解析为 DateTime
  static DateTime parseDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 获取当前月份的第一天
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 判断两个 DateTime 是否在同一个月
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}