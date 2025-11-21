import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class PaymentMethodWebviewScreen extends StatefulWidget {
  const PaymentMethodWebviewScreen({super.key, required this.redirectUrl});

  static const String routePath = '/payment-methods/add';

  final String redirectUrl;

  @override
  State<PaymentMethodWebviewScreen> createState() =>
      _PaymentMethodWebviewScreenState();
}

class _PaymentMethodWebviewScreenState
    extends State<PaymentMethodWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() {
              _errorMessage = error.description;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add payment method'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            _buildError()
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.deepBerry),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.warmSpice, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage ?? 'Unable to load page'),
            const SizedBox(height: AppSpacing.sm),
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
          ],
        ),
      ),
    );
  }
}
