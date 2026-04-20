import 'package:intl/intl.dart';

class DateTimeUtils {
  static final DateFormat _docDateFormat = DateFormat('yyyyMMdd');
  static final DateFormat _displayDateTimeFormat = DateFormat(
    'MMM d, yyyy • h:mm a',
  );
  static final DateFormat _displayDateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _displayTimeFormat = DateFormat('h:mm a');

  static String documentDateKey(DateTime dateTime) {
    return _docDateFormat.format(dateTime);
  }

  static String displayDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Not recorded';
    }
    return _displayDateTimeFormat.format(dateTime.toLocal());
  }

  static String displayDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Not recorded';
    }
    return _displayDateFormat.format(dateTime.toLocal());
  }

  static String displayTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Not recorded';
    }
    return _displayTimeFormat.format(dateTime.toLocal());
  }

  static DateTime? tryParse(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }
    return DateTime.tryParse(input)?.toLocal();
  }
}
