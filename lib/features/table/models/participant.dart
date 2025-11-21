import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum PaymentStatus {
  owing,
  pendingConfirmation,
  pendingDirectConfirmation,
  paid,
  failed;

  factory PaymentStatus.fromString(String value) {
    switch (value) {
      case 'owing':
        return PaymentStatus.owing;
      case 'pending_confirmation':
      case 'awaiting_confirmation':
        return PaymentStatus.pendingConfirmation;
      case 'pending_direct_confirmation':
        return PaymentStatus.pendingDirectConfirmation;
      case 'pending':
        return PaymentStatus.pendingConfirmation;
      case 'paid':
      case 'paid_in_app':
      case 'paid_outside':
      case 'paid_direct':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.owing;
    }
  }

  // UX Helper: Get the color directly from the model
  Color get color {
    switch (this) {
      case PaymentStatus.owing:
        return AppColors.darkFig; // Neutral
      case PaymentStatus.pendingConfirmation:
        return AppColors.warmSpice; // Alert/Action Needed
      case PaymentStatus.pendingDirectConfirmation:
        return AppColors.warmSpice; // Alert/Action Needed (same as pending)
      case PaymentStatus.paid:
        return AppColors.lushGreen; // Success
      case PaymentStatus.failed:
        return AppColors.warmSpice;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.owing:
        return 'Owing';
      case PaymentStatus.pendingConfirmation:
        return 'Awaiting Confirmation';
      case PaymentStatus.pendingDirectConfirmation:
        return 'Awaiting Direct Confirmation';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
    }
  }
}

class Participant {
  final String id;
  final String tableId;
  final String userId;
  final String displayName;
  final String? avatarUrl; // NEW: For social feel
  final PaymentStatus paymentStatus;
  final double totalOwed;
  final bool isHost; // NEW: Helper for UI logic

  const Participant({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.paymentStatus,
    this.totalOwed = 0.0,
    this.isHost = false,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      // Robust ID parsing (Keep your existing logic, it's safe)
      id: json['id'] as String? ?? json['participantId'] as String? ?? '',
      tableId: json['tableId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Guest',
      avatarUrl: json['avatarUrl'] as String?,

      paymentStatus: PaymentStatus.fromString(
        json['status'] as String? ??
            json['paymentStatus'] as String? ??
            'owing',
      ),

      // Parse the method separate from statu
      totalOwed: (json['totalOwed'] as num?)?.toDouble() ?? 0.0,
      isHost: json['isHost'] as bool? ?? false,
    );
  }

  // Helper for Avatar generation (Initials)
  String get initials {
    if (displayName.isEmpty) return '?';
    final parts = displayName.trim().split(
      RegExp(r'\s+'),
    ); // Handle multiple spaces
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  // Helper: Does this participant require Host attention?
  bool get requiresAction =>
      paymentStatus == PaymentStatus.pendingConfirmation ||
      paymentStatus == PaymentStatus.pendingDirectConfirmation ||
      paymentStatus == PaymentStatus.failed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'status': paymentStatus.name,
      'totalOwed': totalOwed,
      'isHost': isHost,
    };
  }

  // Mapping helper: business logic calls this claimedAmountZar.
  double get claimedAmountZar => totalOwed;

  Participant copyWith({
    String? id,
    String? tableId,
    String? userId,
    String? displayName,
    String? avatarUrl,
    PaymentStatus? paymentStatus,
    double? totalOwed,
    bool? isHost,
  }) {
    return Participant(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalOwed: totalOwed ?? this.totalOwed,
      isHost: isHost ?? this.isHost,
    );
  }
}
