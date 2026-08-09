import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/core/services/notification_service.dart';

class RestTimerState {
  const RestTimerState({
    required this.isActive,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  final bool isActive;
  final int remainingSeconds;
  final int totalSeconds;

  RestTimerState copyWith({
    bool? isActive,
    int? remainingSeconds,
    int? totalSeconds,
  }) {
    return RestTimerState(
      isActive: isActive ?? this.isActive,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }
}

class RestTimerController extends StateNotifier<RestTimerState> {
  RestTimerController(this._ref)
      : super(const RestTimerState(
          isActive: false,
          remainingSeconds: 0,
          totalSeconds: 0,
        ));

  final Ref _ref;

  Timer? _timer;

  void start(int seconds) {
    _timer?.cancel();
    state = RestTimerState(
      isActive: true,
      remainingSeconds: seconds,
      totalSeconds: seconds,
    );

    _ref.read(notificationServiceProvider).scheduleRestTimerNotification(seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        _onFinished();
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
        );
      }
    });
  }

  void addTime(int seconds) {
    if (!state.isActive) return;
    final newRemaining = state.remainingSeconds + seconds;
    final newTotal = state.totalSeconds + seconds;
    state = state.copyWith(
      remainingSeconds: newRemaining,
      totalSeconds: newTotal,
    );
    _ref.read(notificationServiceProvider).scheduleRestTimerNotification(newRemaining);
  }

  void skip() {
    _timer?.cancel();
    _ref.read(notificationServiceProvider).cancelRestTimerNotification();
    state = const RestTimerState(
      isActive: false,
      remainingSeconds: 0,
      totalSeconds: 0,
    );
  }

  void _onFinished() {
    _timer?.cancel();
    _ref.read(notificationServiceProvider).cancelRestTimerNotification();
    state = const RestTimerState(
      isActive: false,
      remainingSeconds: 0,
      totalSeconds: 0,
    );
    // Trigger subtle haptic feedback for user alert
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ref.read(notificationServiceProvider).cancelRestTimerNotification();
    super.dispose();
  }
}

final restTimerProvider =
    StateNotifierProvider<RestTimerController, RestTimerState>((ref) {
  return RestTimerController(ref);
});
