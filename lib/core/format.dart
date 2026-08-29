import 'package:intl/intl.dart';

final _rub = NumberFormat.currency(
  locale: 'ru_RU',
  symbol: '₽',
  decimalDigits: 0,
);

/// Цена в рублях без копеек. null → «Цена договорная» (объявления без
/// указанной цены, в т.ч. «куплю»).
String formatRub(double? price) {
  if (price == null) return 'Цена договорная';
  return _rub.format(price);
}
