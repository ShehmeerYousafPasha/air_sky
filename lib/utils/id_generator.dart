import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();

  static String bookingId() {
    final String number = List<String>.generate(
      6,
      (_) => _random.nextInt(10).toString(),
    ).join();
    return 'AIR-$number';
  }

  static String psid() {
    final String number = List<String>.generate(
      12,
      (_) => _random.nextInt(10).toString(),
    ).join();
    return 'PSID$number';
  }
}



