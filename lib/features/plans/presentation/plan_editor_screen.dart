import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/error_view.dart';
import 'package:gymgenie/core/widgets/loading_view.dart';
import 'package:gymgenie/features/exercises/data/exercise_repository.dart';
import 'package:gymgenie/features/exercises/domain/exercise.dart';
import 'package:gymgenie/features/plans/data/plan_repository.dart';
import 'package:gymgenie/features/plans/domain/workout_plan.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<PlannedExercise> _exercises = [];
  WorkoutPlan? _original;
  bool _loading = false;
  String? _loadError;
  bool _saving = false;

  bool get _isEdit => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _loadPlan();
    }
  }

  Future<void> _loadPlan() async {
    try {
      final plan =
          await ref.read(planRepositoryProvider).getPlan(widget.planId!);
      if (!mounted) return;
      if (plan == null) {
        setState(() {
          _loadError = 'Plan not found';
          _loading = false;
        });
        return;
      }
      final exercises = [...plan.exercises]
        ..sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _original = plan;
        _nameController.text = plan.name;
        _descriptionController.text = plan.description;
        _exercises = exercises;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<PlannedExercise> _reindexed(List<PlannedExercise> exercises) {
    return [
      for (var i = 0; i < exercises.length; i++)
        exercises[i].copyWith(order: i),
    ];
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      var target = newIndex;
      if (target > oldIndex) target--;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(target, item);
      _exercises = _reindexed(_exercises);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _exercises = _reindexed(_exercises);
    });
  }

  void _updateExercise(int index, PlannedExercise updated) {
    setState(() {
      _exercises[index] = updated;
    });
  }

  Future<void> _addExercise() async {
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (selected == null) return;
    setState(() {
      _exercises = [
        ..._exercises,
        PlannedExercise(
          exerciseId: selected.id,
          exerciseName: selected.name,
          targetSets: 3,
          targetReps: 10,
          targetWeight: 0,
          order: _exercises.length,
        ),
      ];
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(planRepositoryProvider);
    try {
      final exercises = _reindexed(_exercises);
      if (_isEdit) {
        final original = _original;
        if (original == null) {
          throw StateError('Plan not loaded');
        }
        await repo.updatePlan(
          original.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            exercises: exercises,
          ),
        );
      } else {
        final now = DateTime.now();
        await repo.createPlan(
          WorkoutPlan(
            id: '',
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            exercises: exercises,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Plan' : 'New Plan')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(
                  message: _loadError!,
                  onRetry: () {
                    setState(() {
                      _loadError = null;
                      _loading = true;
                    });
                    _loadPlan();
                  },
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Plan name',
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Name is required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _exercises.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fitness_center_outlined,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No exercises yet',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap "Add Exercise" below to build your plan.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: _exercises.length,
                                onReorder: _onReorder,
                                itemBuilder: (context, index) {
                                  final exercise = _exercises[index];
                                  return _PlannedExerciseCard(
                                    key: ValueKey(
                                        '${exercise.exerciseId}-$index'),
                                    exercise: exercise,
                                    onChanged: (updated) =>
                                        _updateExercise(index, updated),
                                    onRemove: () => _removeExercise(index),
                                  );
                                },
                              ),
                      ),
                      SafeArea(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border(
                              top: BorderSide(
                                  color: theme.colorScheme.outline),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _addExercise,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Exercise'),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Text('Save Plan'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _PlannedExerciseCard extends StatelessWidget {
  const _PlannedExerciseCard({
    super.key,
    required this.exercise,
    required this.onChanged,
    required this.onRemove,
  });

  final PlannedExercise exercise;
  final ValueChanged<PlannedExercise> onChanged;
  final VoidCallback onRemove;

  String _formatWeight(double weight) =>
      weight == weight.roundToDouble() ? '${weight.toInt()}' : '$weight';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              Icons.drag_handle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          exercise.exerciseName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${exercise.targetSets} sets × ${exercise.targetReps} reps'
          '${exercise.targetWeight > 0 ? ' @ ${_formatWeight(exercise.targetWeight)} kg' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          _StepperRow(
            label: 'Sets',
            value: '${exercise.targetSets}',
            onDecrement: exercise.targetSets > 1
                ? () => onChanged(
                    exercise.copyWith(targetSets: exercise.targetSets - 1))
                : null,
            onIncrement: () => onChanged(
                exercise.copyWith(targetSets: exercise.targetSets + 1)),
          ),
          _StepperRow(
            label: 'Reps',
            value: '${exercise.targetReps}',
            onDecrement: exercise.targetReps > 1
                ? () => onChanged(
                    exercise.copyWith(targetReps: exercise.targetReps - 1))
                : null,
            onIncrement: () => onChanged(
                exercise.copyWith(targetReps: exercise.targetReps + 1)),
          ),
          _StepperRow(
            label: 'Weight (kg)',
            value: _formatWeight(exercise.targetWeight),
            onDecrement: exercise.targetWeight > 0
                ? () {
                    final next = exercise.targetWeight - 2.5;
                    onChanged(exercise.copyWith(
                        targetWeight: next < 0 ? 0 : next));
                  }
                : null,
            onIncrement: () => onChanged(exercise.copyWith(
                targetWeight: exercise.targetWeight + 2.5)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error, size: 18),
              label: Text(
                'Remove',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: onDecrement,
            icon: Icon(
              Icons.remove_circle_outline,
              color: onDecrement != null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: Icon(
              Icons.add_circle_outline,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet();

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedGroup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);
    final query = _query.trim().toLowerCase();

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedGroup == null,
                    onSelected: (_) => setState(() => _selectedGroup = null),
                  ),
                ),
                for (final group in ExerciseRepository.muscleGroups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(group),
                      selected: _selectedGroup == group,
                      onSelected: (_) =>
                          setState(() => _selectedGroup = group),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: library.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'Failed to load exercises',
                onRetry: () => ref.invalidate(exerciseLibraryProvider),
              ),
              data: (exercises) {
                final filtered = exercises.where((e) {
                  if (_selectedGroup != null &&
                      e.muscleGroup != _selectedGroup) {
                    return false;
                  }
                  if (query.isNotEmpty &&
                      !e.name.toLowerCase().contains(query) &&
                      !e.muscleGroup.toLowerCase().contains(query) &&
                      !e.equipment.toLowerCase().contains(query)) {
                    return false;
                  }
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No exercises found'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final exercise = filtered[index];
                    return _ExerciseGridCard(
                      exercise: exercise,
                      onTap: () => Navigator.of(context).pop(exercise),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseGridCard extends StatelessWidget {
  const _ExerciseGridCard({
    required this.exercise,
    required this.onTap,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFF1B1B1F),
                child: exercise.gifUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: exercise.gifUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.fitness_center,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.fitness_center,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.equipment}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
