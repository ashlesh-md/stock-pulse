class OrderRejection implements Exception {
  const OrderRejection(this.code, this.message, {this.status = 400});

  final String code;
  final String message;
  final int status;
}
