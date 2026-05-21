class DateFormatter {
  static String compact(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String storageDayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
