class AppConstants {
  // Supabase Configuration
  // TODO: Replace with actual Supabase credentials
  static const String supabaseUrl = 'https://bxowbpqduwvywzdtqarc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4b3dicHFkdXd2eXd6ZHRxYXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyMzQ0MzgsImV4cCI6MjA3ODgxMDQzOH0.eu7D5iu7DeabcGVtB2Pq4bE6BUUMTqBDiLkMsqj1vqw';

  // API Configuration
  // TODO: Replace with actual Azure Function URLs
  static const String apiBaseUrl =
      'https://pyble-dev-functions-dcb7dfhagxg3grcv.southafricanorth-01.azurewebsites.net/api';
  // static const String apiBaseUrl = 'http://10.0.2.2:7071/api';

  // Paystack config (injected at build time via --dart-define; do NOT hard-code secrets here)
  static const String paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: '',
  );
  static const String paystackEnv = String.fromEnvironment(
    'PAYSTACK_ENV',
    defaultValue: 'test',
  );
  static const String paystackCallbackUrl = String.fromEnvironment(
    'PAYSTACK_CALLBACK_URL',
    defaultValue: '',
  );
  // Secrets (PAYSTACK_SECRET_KEY, PAYSTACK_WEBHOOK_SECRET) must stay on the backend only.

  // Deep Link Configuration
  static const String appScheme = 'com.pyble';
  static const String joinPath = 'join';

  // App Info
  static const String appName = 'Pyble';
  static const String appVersion = '1.0.0';

  // Payment
  static const double appFeePercentage = 0.04; // 4% fee
  static const String currencySymbol = 'R'; // ZAR (South African Rand)

  // Polling Intervals (milliseconds)
  static const int tablePollingInterval = 3000;
  static const int paymentStatusPollingInterval = 2000;

  // Local Storage Keys
  static const String tutorialSeenKey = 'tutorial_seen';
  static const String lastTableCodeKey = 'last_table_code';
}
