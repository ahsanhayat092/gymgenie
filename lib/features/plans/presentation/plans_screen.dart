import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/generator/application/workout_generator.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/plans/presentation/share_plan_dialog.dart';

// ── Accent colour matching the design spec ──────────────────────────────────
const _kAccent = Color(0xFFf5a623);
const _kSurface = Color(0xFF1E1E1E);
const _kDivider = Color(0xFF2A2A2A);
const _kSecondary = Color(0xFFA0A0A0);

// ── Data helpers ─────────────────────────────────────────────────────────────

/// Groups a flat list of plans into weeks by clustering plans created within
/// the same 7-day window (rounded to the nearest Monday-aligned week).
/// Fallback: chunk every 7 plans as one week (for manual plans).
List<_WeekGroup> _groupIntoWeeks(List<WorkoutPlan> plans) {
  if (plans.isEmpty) return [];

  // Sort oldest-first so Day 1 always appears first.
  final sorted = [...plans]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final weeks = <_WeekGroup>[];
  var weekStart = sorted.first.createdAt;
  var current = <WorkoutPlan>[];
  var weekIndex = 1;

  for (final plan in sorted) {
    final diff = plan.createdAt.difference(weekStart).inDays;
    if (diff > 6 && current.isNotEmpty) {
      weeks.add(_WeekGroup(index: weekIndex++, plans: List.of(current)));
      current.clear();
      weekStart = plan.createdAt;
    }
    current.add(plan);
  }

  if (current.isNotEmpty) {
    weeks.add(_WeekGroup(index: weekIndex, plans: current));
  }

  return weeks;
}

/// Derives a human-readable phase name from the week's plans.
String _phaseName(int weekIndex, List<WorkoutPlan> plans) {
  const phases = [
    'Foundation Phase',
    'Progressive Overload',
    'Strength Accumulation',
    'Peak Phase',
    'Deload & Recovery',
  ];
  if (weekIndex <= phases.length) return phases[weekIndex - 1];
  return 'Continuation Phase';
}

/// Extracts just the "Day N" or focus name from a plan name.
/// e.g. "Build muscle - Day 1 (Push A)" → "Day 1", "Push A"
({String dayLabel, String focus}) _parsePlanName(String name, int fallbackDay) {
  // Match "Day N" pattern anywhere in the name.
  final dayMatch = RegExp(r'Day\s+(\d+)', caseSensitive: false).firstMatch(name);
  final dayLabel = dayMatch != null ? 'Day ${dayMatch.group(1)}' : 'Day $fallbackDay';

  // Extract parenthesised focus e.g. (Push A).
  final focusMatch = RegExp(r'\(([^)]+)\)').firstMatch(name);
  if (focusMatch != null) return (dayLabel: dayLabel, focus: focusMatch.group(1)!);

  // Strip "Goal - " prefix and "Day N" suffix.
  var cleaned = name
      .replaceAll(RegExp(r'^.*?-\s*'), '')
      .replaceAll(RegExp(r'Day\s+\d+', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\(\)]'), '')
      .trim();
  if (cleaned.isEmpty) cleaned = name;
  return (dayLabel: dayLabel, focus: cleaned);
}

class _WeekGroup {
  _WeekGroup({required this.index, required this.plans});
  final int index;
  final List<WorkoutPlan> plans;
}

// ── Main screen ───────────────────────────────────────────────────────────────

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  int _expandedWeek = 1; // accordion: only one week open at a time

  Future<void> _confirmAndDelete(WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('This will permanently delete "${plan.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(planRepositoryProvider).deletePlan(plan.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _onGenerateAIPressed() async {
    final plans = ref.read(plansProvider).valueOrNull ?? const <WorkoutPlan>[];
    final generator = ref.read(workoutGeneratorProvider);
    final canGenerate = await generator.isLatestWeekFinished(plans);

    if (!mounted) return;
    if (!canGenerate) {
      final unattempted = await generator.unattemptedDaysInLatestWeek(plans);
      final days = unattempted.map((n) => '• $n').join('\n');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finish your current week first'),
          content: Text(
            'Finish your current week before generating the next one.\n\n'
            'These days still need a workout:\n$days',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (mounted) context.push('/plans/generate');
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    var importing = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Shared Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Enter the share code or paste the shared URL to import the workout plan.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                enabled: !importing,
                decoration: const InputDecoration(
                  labelText: 'Share Code or Link',
                  hintText: 'e.g. 5xG8yK...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: importing
                  ? null
                  : () async {
                      final value = controller.text.trim();
                      if (value.isEmpty) return;
                      setState(() => importing = true);
                      try {
                        await ref.read(planRepositoryProvider).importPlan(value);
                        if (!context.mounted) return;
                        ref.invalidate(plansProvider);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Plan imported!')),
                        );
                      } catch (e) {
                        setState(() => importing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
              child: importing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Import'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        actions: [
          IconButton(
            tooltip: 'Generate AI Plan',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _onGenerateAIPressed,
          ),
          IconButton(
            tooltip: 'Import Shared Plan',
            icon: const Icon(Icons.download_outlined),
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: plans.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Failed to load plans',
          onRetry: () => ref.invalidate(plansProvider),
        ),
        data: (planList) {
          if (planList.isEmpty) {
            return EmptyView(
              icon: Icons.list_alt,
              title: 'No plans yet',
              subtitle:
                  'Create a custom plan or let GymGenie generate a personalised week for you.',
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: _onGenerateAIPressed,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate AI Plan'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/plans/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Custom Plan'),
                  ),
                ],
              ),
            );
          }

          final weeks = _groupIntoWeeks(planList);

          // Find the very first plan across all weeks (resume target).
          final firstPlan = weeks.isNotEmpty && weeks.first.plans.isNotEmpty
              ? weeks.first.plans.first
              : null;

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: weeks.length,
                itemBuilder: (context, wi) {
                  final week = weeks[wi];
                  final isExpanded = _expandedWeek == week.index;
                  return _WeekCard(
                    week: week,
                    isExpanded: isExpanded,
                    onToggle: () => setState(() {
                      _expandedWeek = isExpanded ? -1 : week.index;
                    }),
                    onDayTap: (plan) => context.push('/plans/${plan.id}'),
                    onDayDelete: _confirmAndDelete,
                    ref: ref,
                    nextPlanId: firstPlan?.id,
                  );
                },
              ),

              // ── "New Plan" FAB ───────────────────────────────────────────
              Positioned(
                right: 16,
                bottom: 100,
                child: FloatingActionButton(
                  heroTag: 'new_plan_fab',
                  onPressed: () => context.push('/plans/new'),
                  child: const Icon(Icons.add),
                ),
              ),

              // ── Floating "Resume" pill ───────────────────────────────────
              if (firstPlan != null)
                Positioned(
                  left: 16,
                  right: 80, // leave space for FAB
                  bottom: 16,
                  child: _ResumePill(plan: firstPlan),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Week card (collapsible accordion) ────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.isExpanded,
    required this.onToggle,
    required this.onDayTap,
    required this.onDayDelete,
    required this.ref,
    this.nextPlanId,
  });

  final _WeekGroup week;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(WorkoutPlan) onDayTap;
  final void Function(WorkoutPlan) onDayDelete;
  final WidgetRef ref;
  final String? nextPlanId;

  @override
  Widget build(BuildContext context) {
    final allComplete = false; // future: drive from workout logs
    final completedCount = 0;  // future: drive from workout logs
    final totalDays = week.plans.length;
    final phase = _phaseName(week.index, week.plans);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: _kSurface,
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Week ${week.index}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phase,
                              style: const TextStyle(
                                color: _kSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress ring
                      _ProgressRing(
                        completed: completedCount,
                        total: totalDays,
                        allComplete: allComplete,
                      ),

                      const SizedBox(width: 12),

                      // Rotating chevron
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: const Icon(
                          Icons.chevron_right,
                          color: _kSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Animated day rows ─────────────────────────────────────────
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 280),
                crossFadeState: isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    const Divider(color: _kDivider, height: 1),
                    ...List.generate(week.plans.length, (i) {
                      final plan = week.plans[i];
                      final isNext = plan.id == nextPlanId;
                      final isLast = i == week.plans.length - 1;
                      final parsed = _parsePlanName(plan.name, i + 1);
                      return Column(
                        children: [
                          _DayRow(
                            plan: plan,
                            dayLabel: parsed.dayLabel,
                            focus: parsed.focus,
                            isCompleted: false,
                            isNext: isNext,
                            onTap: () => onDayTap(plan),
                            onDelete: () => onDayDelete(plan),
                            onShare: () => showSharePlanDialog(context, ref, plan),
                          ),
                          if (!isLast)
                            const Divider(color: _kDivider, height: 1, indent: 60),
                        ],
                      );
                    }),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress ring ─────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.completed,
    required this.total,
    required this.allComplete,
  });

  final int completed;
  final int total;
  final bool allComplete;

  @override
  Widget build(BuildContext context) {
    if (allComplete) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withValues(alpha: 0.15),
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 22),
      );
    }

    return SizedBox(
      width: 42, height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: total > 0 ? completed / total : 0,
            strokeWidth: 3,
            backgroundColor: const Color(0xFF3A3A3A),
            valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
          ),
          Text(
            '$completed/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatefulWidget {
  const _DayRow({
    required this.plan,
    required this.dayLabel,
    required this.focus,
    required this.isCompleted,
    required this.isNext,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  final WorkoutPlan plan;
  final String dayLabel;
  final String focus;
  final bool isCompleted;
  final bool isNext;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isNext) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_DayRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNext && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isNext && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('day_${widget.plan.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        widget.onDelete();
        return false;
      },
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // ── Status circle ────────────────────────────────────────
                ScaleTransition(
                  scale: widget.isNext ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isCompleted
                          ? _kAccent
                          : Colors.transparent,
                      border: widget.isCompleted
                          ? null
                          : Border.all(
                              color: widget.isNext
                                  ? _kAccent
                                  : const Color(0xFF3A3A3A),
                              width: 2,
                            ),
                    ),
                    child: widget.isCompleted
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                ),

                const SizedBox(width: 16),

                // ── Day label + focus ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.dayLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.focus,
                        style: const TextStyle(
                          color: _kSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ── Exercise count + chevron ─────────────────────────────
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.plan.exercises.length} exercises',
                      style: const TextStyle(color: _kSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined,
                      color: _kSecondary, size: 20),
                  onPressed: widget.onShare,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _kSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resume pill ───────────────────────────────────────────────────────────────

class _ResumePill extends StatelessWidget {
  const _ResumePill({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final parsed = _parsePlanName(plan.name, 1);

    return GestureDetector(
      onTap: () => context.push('/plans/${plan.id}'),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Color(0xFF121212), size: 22),
            const SizedBox(width: 8),
            Text(
              'Resume ${parsed.dayLabel}',
              style: const TextStyle(
                color: Color(0xFF121212),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
