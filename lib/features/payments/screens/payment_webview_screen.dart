import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/paystack_models.dart';

class PaymentWebviewScreen extends StatefulWidget {
  final String tableId;
  final PaystackInitializeResponse paymentResponse;

  const PaymentWebviewScreen({
    super.key,
    required this.tableId,
    required this.paymentResponse,
  });

  @override
  State<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends State<PaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.snow)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading indicator
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _errorMessage = error.description;
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check if this is the callback URL
            if (_isCallbackUrl(request.url)) {
              _handlePaymentCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentResponse.authorizationUrl));
  }

  bool _isCallbackUrl(String url) {
    // Check if the URL matches the callback pattern
    final callbackUrl = widget.paymentResponse.callbackUrl;
    if (callbackUrl.isNotEmpty && url.startsWith(callbackUrl)) {
      return true;
    }

    // Also check for common callback patterns
    return url.contains('payment/callback') ||
        url.contains('payment/success') ||
        url.contains('payment/complete');
  }

  void _handlePaymentCallback(String url) {
    // Parse the callback URL for any parameters
    final uri = Uri.parse(url);
    final status = uri.queryParameters['status'];

    // Navigate to processing screen
    context.pushReplacement(
      '/payment-processing/${widget.tableId}',
      extra: {
        'paymentReference': widget.paymentResponse.reference,
        'gatewayStatus': status,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.deepBerry,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            _buildErrorView()
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && _errorMessage == null)
            Container(
              color: AppColors.snow.withOpacity(0.8),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.warmSpice,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Payment Failed to Load',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _controller.reload();
              },
              child: const Text('Retry'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to cancel this payment? You can try again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warmSpice),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (cancel == true && mounted) {
      context.pop();
    }
  }
}
