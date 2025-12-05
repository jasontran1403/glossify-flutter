enum BookingStatus {
  booked,
  checkedIn,
  inProgress,
  waitingPayment,
  paid,
  canceled;

  String get name {
    switch (this) {
      case BookingStatus.booked:
        return 'BOOKED';
      case BookingStatus.checkedIn:
        return 'CHECKED_IN';
      case BookingStatus.inProgress:
        return 'IN_PROGRESS';
      case BookingStatus.waitingPayment:
        return 'WAITING_PAYMENT';
      case BookingStatus.paid:
        return 'PAID';
      case BookingStatus.canceled:
        return 'CANCELED';
    }
  }

  static BookingStatus fromString(String status) {
    switch (status) {
      case 'BOOKED':
        return BookingStatus.booked;
      case 'CHECKED_IN':
        return BookingStatus.checkedIn;
      case 'IN_PROGRESS':
        return BookingStatus.inProgress;
      case 'WAITING_PAYMENT':
        return BookingStatus.waitingPayment;
      case 'PAID':
        return BookingStatus.paid;
      case 'CANCELED':
        return BookingStatus.canceled;
      default:
        return BookingStatus.booked;
    }
  }
}