import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String toShortDate() => DateFormat('EEE, d MMM yyyy').format(this);

  String toTicketDate() => DateFormat('d MMM yyyy').format(this);

  String toTimeLabel() => DateFormat('HH:mm').format(this);
}



