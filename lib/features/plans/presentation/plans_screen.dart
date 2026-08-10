import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/empty_view.dart';
import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/generator/application/workout_generator.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';
import 'package:gymgenie/features/plans/presentation/share_plan_dialog.dart';

List<_WeekGroup> _groupIntoWeeks(List<WorkoutPlan> plans) {
  if (plans.isEmpty) return [];

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

({String dayLabel, String focus}) _parsePlanName(
    String name, int fallbackDay) {
  final dayMatch =
      RegExp(r'Day\s+(\d+)', caseSensitive: false).firstMatch(name);
  final dayLabel =
      dayMatch != null ? 'Day ${dayMatch.group(1)}' : 'Day $fallbackDay';

  final focusMatch = RegExp(r'\(([^)]+)\)').firstMatch(name);
  if (focusMatch != null) {
    return (dayLabel: dayLabel, focus: focusMatch.group(1)!);
  }

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

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  int _expandedWeek = 1;

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
                'Enter the share code or paste the shared URL to import the workout plan.',
              ),
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
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
    final theme = Theme.of(context);

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
          final firstPlan = weeks.isNotEmpty && weeks.first.plans.isNotEmpty
              ? weeks.first.plans.first
              : null;

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
              if (firstPlan != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _ResumeBar(
                    plan: firstPlan,
                    onCreatePlan: () => context.push('/plans/new'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final allComplete = false;
    final completedCount = 0;
    final totalDays = week.plans.length;
    final phase = _phaseName(week.index, week.plans);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Week ${week.index}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phase,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ProgressRing(
                      completed: completedCount,
                      total: totalDays,
                      allComplete: allComplete,
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(color: theme.colorScheme.outline, height: 1),
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
                          Divider(
                            color: theme.colorScheme.outline,
                            height: 1,
                            indent: 60,
                          ),
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
    );
  }
}

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
    final theme = Theme.of(context);
    if (allComplete) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
        ),
        child: Icon(Icons.check_circle,
            color: theme.colorScheme.secondary, size: 24),
      );
    }

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: total > 0 ? completed / total : 0,
            strokeWidth: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          Text(
            '$completed/$total',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _DayRowState extends State<_DayRow>
    with SingleTickerProviderStateMixin {
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
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('day_${widget.plan.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
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
                ScaleTransition(
                  scale: widget.isNext
                      ? _pulseAnim
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isCompleted
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: widget.isCompleted
                          ? null
                          : Border.all(
                              color: widget.isNext
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: 2,
                            ),
                    ),
                    child: widget.isCompleted
                        ? const Icon(Icons.check,
                            color: Colors.black, size: 14)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.dayLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.focus,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.plan.exercises.length} exercises',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.share_outlined,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onPressed: widget.onShare,
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({required this.plan, required this.onCreatePlan});

  final WorkoutPlan plan;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsePlanName(plan.name, 1);

    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push('/plans/${plan.id}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Resume ${parsed.dayLabel}'),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: IconButton(
              onPressed: onCreatePlan,
              icon: Icon(Icons.add, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
