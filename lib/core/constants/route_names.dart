class RouteNames {
  static const String onboarding = 'onboarding';
  static const String auth = 'auth';
  static const String home = 'home';
  static const String terms = 'terms';
  static const String settings = 'settings';
  static const String createTable = 'create-table';
  static const String table = 'table';
  static const String scanBill = 'scan-bill';
  static const String inviteParticipants = 'invite-participants';
  static const String joinTable = 'join-table';
  static const String paymentProcessing = 'payment-processing';
  static const String history = 'history';
}

class RoutePaths {
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String terms = '/terms';
  static const String settings = '/settings';
  static const String createTable = '/create-table';
  static const String table = '/table/:code';
  static const String scanBill = '/table/:tableId/scan';
  static const String inviteParticipants = '/table/:tableId/invite';
  static const String joinTable = '/join';
  static const String paymentProcessing = '/payment-processing/:tableId';
  static const String history = '/history';
}
