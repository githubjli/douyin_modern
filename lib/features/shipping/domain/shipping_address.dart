/// A user's saved shipping address.
class ShippingAddress {
  const ShippingAddress({
    required this.id,
    required this.receiverName,
    required this.phone,
    required this.country,
    required this.state,
    required this.city,
    required this.district,
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
    required this.isDefault,
  });

  final int id;
  final String receiverName;
  final String phone;
  final String country;
  final String state;
  final String city;
  final String district;
  final String addressLine1;
  final String addressLine2;
  final String postalCode;
  final bool isDefault;

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['id'] as int? ?? 0,
      receiverName: json['receiver_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      country: json['country'] as String? ?? '',
      state: json['state'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      addressLine1: json['address_line1'] as String? ?? '',
      addressLine2: json['address_line2'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'receiver_name': receiverName,
        'phone': phone,
        'country': country,
        'state': state,
        'city': city,
        'district': district,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'postal_code': postalCode,
        'is_default': isDefault,
      };

  /// Human-readable one-line address string.
  String get oneLine {
    final List<String> parts = <String>[
      if (addressLine1.isNotEmpty) addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (postalCode.isNotEmpty) postalCode,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  ShippingAddress copyWith({
    int? id,
    String? receiverName,
    String? phone,
    String? country,
    String? state,
    String? city,
    String? district,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    bool? isDefault,
  }) {
    return ShippingAddress(
      id: id ?? this.id,
      receiverName: receiverName ?? this.receiverName,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      district: district ?? this.district,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
