import 'package:flutter/foundation.dart';

@immutable
class OrderTicketState {
  const OrderTicketState({
    this.submitting = false,
    this.checkingStatus = false,
    this.uncertain = false,
  });
  final bool submitting;
  final bool checkingStatus;
  final bool uncertain;

  OrderTicketState copyWith({
    bool? submitting,
    bool? checkingStatus,
    bool? uncertain,
  }) => OrderTicketState(
    submitting: submitting ?? this.submitting,
    checkingStatus: checkingStatus ?? this.checkingStatus,
    uncertain: uncertain ?? this.uncertain,
  );
  @override
  bool operator ==(Object other) =>
      other is OrderTicketState &&
      submitting == other.submitting &&
      checkingStatus == other.checkingStatus &&
      uncertain == other.uncertain;
  @override
  int get hashCode => Object.hash(submitting, checkingStatus, uncertain);
}
