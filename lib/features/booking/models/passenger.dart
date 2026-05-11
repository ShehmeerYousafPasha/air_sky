/// Represents passenger information for a flight booking.
///
/// Required for each passenger:
/// - firstName & lastName: Passenger's full name (as on travel document)
/// - email: Contact email address
/// - phone: Contact phone number
/// - nationality: Country of citizenship (IATA code or full name)
/// - passportNumber: Passport or travel document number
///
/// Used in:
/// - Multi-passenger booking form
/// - Seat assignment mapping
/// - Trip history and ticket generation
/// - Firestore booking storage
class Passenger {
  const Passenger({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.passportNumber,
  });

  /// Creates an empty passenger (used for form initialization)
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

  /// Returns formatted full name or '-' if empty
  String get fullName {
    final String value = '$firstName $lastName'.trim();
    return value.isEmpty ? '-' : value;
  }

  /// Converts to Firestore-compatible map
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

  /// Converts from Firestore map (handles missing fields gracefully)
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


