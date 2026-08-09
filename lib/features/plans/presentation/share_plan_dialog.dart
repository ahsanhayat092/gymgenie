import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

/// Shows a dialog with a QR code and share code for [plan].
///
/// Returns the share code, or `null` if the dialog was dismissed while the
/// share link was still being generated.
Future<String?> showSharePlanDialog(
  BuildContext context,
  WidgetRef ref,
  WorkoutPlan plan,
) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SharePlanDialogContent(plan: plan),
  );
}

class _SharePlanDialogContent extends ConsumerStatefulWidget {
  const _SharePlanDialogContent({required this.plan});

  final WorkoutPlan plan;

  @override
  ConsumerState<_SharePlanDialogContent> createState() =>
      _SharePlanDialogContentState();
}

class _SharePlanDialogContentState
    extends ConsumerState<_SharePlanDialogContent> {
  String? _code;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    try {
      final code = await ref.read(planRepositoryProvider).sharePlan(widget.plan);
      if (mounted) {
        setState(() {
          _code = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating share code...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text('Could not share'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final shareUrl = 'https://gymgenie.app/share?code=$_code';

    return AlertDialog(
      title: const Text('Share Workout Plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Let other GymGenie users scan this QR code or use the share code below to import your plan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: QrImageView(
                data: shareUrl,
                version: QrVersions.auto,
                size: 180,
                gapless: false,
                foregroundColor: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Share Code:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(
              _code!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied link to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Share Link'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_code),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
