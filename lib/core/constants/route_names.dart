class RouteNames {
  static const String onboarding = 'onboarding';
  static const String auth = 'auth';
  static const String home = 'home';
  static const String terms = 'terms';
  static const String settings = 'settings';
  static const String activeTables = 'active-tables';
  static const String createTable = 'create-table';
  static const String table = 'table';
  static const String scanBill = 'scan-bill';
  static const String inviteParticipants = 'invite-participants';
  static const String joinTable = 'join-table';
  static const String claimTable = 'claim-table';
  static const String hostDashboard = 'host-dashboard';
  static const String participantPayment = 'participant-payment';
  static const String paymentWebview = 'payment-webview';
  static const String paymentProcessing = 'payment-processing';
  static const String history = 'history';
}

class RoutePaths {
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String terms = '/terms';
  static const String settings = '/settings';
  static const String activeTables = '/tables';
  static const String createTable = '/table/create';
  static const String table = '/table/:code';
  static const String scanBill = '/table/:tableId/scan';
  static const String inviteParticipants = '/table/:tableId/invite';
  static const String joinTable = '/table/join';
  static const String claimTable = '/table/:tableId/claim';
  static const String hostDashboard = '/table/:tableId/dashboard';
  static const String participantPayment = '/table/:tableId/payment';
  static const String paymentWebview = '/payment-webview/:tableId';
  static const String paymentProcessing = '/payment-processing/:tableId';
  static const String history = '/history';
}
