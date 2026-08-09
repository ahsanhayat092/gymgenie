import 'package:intl/intl.dart';

/// Shared formatting helpers.

final DateFormat _dateFormat = DateFormat('d MMM yyyy');
final NumberFormat _volumeFormat = NumberFormat('#,##0.##');

/// Formats a [date] as e.g. `5 Jan 2025`.
String formatDate(DateTime date) => _dateFormat.format(date);

/// Formats a volume in kilograms as e.g. `1,250 kg`.
String formatVolume(double kg) => '${_volumeFormat.format(kg)} kg';
