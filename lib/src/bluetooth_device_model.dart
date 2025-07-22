class BluetoothDeviceModel {
  final String name;
  final String address;
  final int type;
  final bool bonded;

  const BluetoothDeviceModel({
    required this.name,
    required this.address,
    required this.type,
    this.bonded = false,
  });

  factory BluetoothDeviceModel.fromMap(Map<String, dynamic> map) {
    return BluetoothDeviceModel(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      type: map['type'] ?? 0,
      bonded: map['bonded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'type': type,
      'bonded': bonded,
    };
  }

  String get displayName => name.isNotEmpty ? name : address;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDeviceModel && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'BluetoothDeviceModel(name: $name, address: $address)';
}
