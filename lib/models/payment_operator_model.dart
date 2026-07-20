class SupportedCountry {
  final String name;
  final String currency;

  SupportedCountry({
    required this.name,
    required this.currency,
  });

  factory SupportedCountry.fromJson(Map<String, dynamic> json) {
    return SupportedCountry(
      name: json['name'] ?? '',
      currency: json['currency'] ?? '',
    );
  }
}

class PaymentOperator {
  final int id;
  final String name;
  final String refId;
  final String shortCode;
  final String? logo;
  final bool supportsWithdrawals;
  final SupportedCountry? supportedCountry;

  PaymentOperator({
    required this.id,
    required this.name,
    required this.refId,
    required this.shortCode,
    this.logo,
    required this.supportsWithdrawals,
    this.supportedCountry,
  });

  factory PaymentOperator.fromJson(Map<String, dynamic> json) {
    return PaymentOperator(
      id: json['id'],
      name: json['name'] ?? '',
      refId: json['ref_id'] ?? '',
      shortCode: json['short_code'] ?? '',
      logo: json['logo'],
      supportsWithdrawals: json['supports_withdrawals'] ?? false,
      supportedCountry: json['supported_country'] != null 
          ? SupportedCountry.fromJson(json['supported_country']) 
          : null,
    );
  }
}
