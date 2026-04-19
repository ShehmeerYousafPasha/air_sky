class Passenger {
  const Passenger({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.passportNumber,
  });

  const Passenger.empty()
    : firstName = '',
      lastName = '',
      email = '',
      phone = '',
      nationality = '',
      passportNumber = '';

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String nationality;
  final String passportNumber;

  String get fullName {
    final String value = '$firstName $lastName'.trim();
    return value.isEmpty ? '-' : value;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'nationality': nationality,
      'passportNumber': passportNumber,
    };
  }

  factory Passenger.fromMap(Map<dynamic, dynamic> map) {
    return Passenger(
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      nationality: map['nationality'] as String? ?? '',
      passportNumber: map['passportNumber'] as String? ?? '',
    );
  }
}
