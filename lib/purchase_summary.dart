/// Server snapshot shared by the three apps, without any visual skin.
class PurchaseSummary {
  const PurchaseSummary(this.quantity, this.minDays, this.maxDays);
  final int quantity;
  final int? minDays;
  final int? maxDays;
  bool get isDeferred => quantity > 0;
  factory PurchaseSummary.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final prep = map['preparation'] is Map
        ? map['preparation'] as Map
        : const {};
    int? integer(dynamic value) => int.tryParse('$value');
    return PurchaseSummary(
      integer(map['backorder_quantity']) ?? 0,
      integer(prep['min_days']),
      integer(prep['max_days']),
    );
  }
  String describe(String Function(String, Map<String, String>) translate) {
    if (!isDeferred) return '';
    final delay = minDays == null || maxDays == null
        ? ''
        : translate(
            minDays == maxDays
                ? (maxDays == 1 ? 'purchase.delay.one' : 'purchase.delay.days')
                : 'purchase.delay.range',
            {'min': '$minDays', 'max': '$maxDays'},
          );
    return translate(
      quantity == 1 ? 'purchase.deferred.one' : 'purchase.deferred.many',
      {'quantity': '$quantity', 'delay': delay},
    );
  }
}
