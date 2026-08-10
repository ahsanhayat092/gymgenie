import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/selectable_card.dart';
import 'package:gymgenie/core/widgets/step_indicator.dart';
import 'package:gymgenie/features/generator/application/workout_generator.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';

class GeneratorSurveyScreen extends ConsumerStatefulWidget {
  const GeneratorSurveyScreen({super.key});

  @override
  ConsumerState<GeneratorSurveyScreen> createState() =>
      _GeneratorSurveyScreenState();
}

class _GeneratorSurveyScreenState
    extends ConsumerState<GeneratorSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isGenerating = false;

  static const int _totalSteps = 6;

  // Step 1: About Me
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  String _gender = 'Male';
  String _experience = 'Beginner';

  // Step 2: Goal
  String _goal = 'Build Muscle';

  // Step 3: Availability
  int _daysPerWeek = 3;
  int _durationMinutes = 45;

  // Step 4: Intensity
  String _level = 'Moderate';

  // Step 5: Equipment
  final List<String> _equipmentOptions = [
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Kettlebell',
    'Bodyweight',
  ];
  final List<String> _selectedEquipment = ['Barbell', 'Dumbbell', 'Bodyweight'];

  // Step 6: Cardio
  final List<String> _cardioOptions = [
    'Treadmill',
    'Bike',
    'Elliptical',
    'Rowing',
    'Stair climber',
  ];
  final List<String> _selectedCardio = ['Treadmill', 'Bike'];

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: '25');
    _heightController = TextEditingController(text: '175');
    _weightController = TextEditingController(text: '70');
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _prefillFromProfile() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null || !mounted) return;

    setState(() {
      if (profile.age > 0) _ageController.text = profile.age.toString();
      if (profile.heightCm > 0) {
        _heightController.text = profile.heightCm.round().toString();
      }
      if (profile.weightKg > 0) {
        _weightController.text = profile.weightKg.round().toString();
      }
      if (profile.gender.isNotEmpty) _gender = profile.gender;
      if (profile.experience.isNotEmpty) _experience = profile.experience;
      if (profile.fitnessGoal.isNotEmpty) _goal = profile.fitnessGoal;
      _daysPerWeek = profile.weeklyWorkoutGoal.clamp(2, 6);
      if (profile.sessionDurationMinutes > 0) {
        _durationMinutes = profile.sessionDurationMinutes;
      }
      if (profile.intensityLevel.isNotEmpty) _level = profile.intensityLevel;
      if (profile.equipment.isNotEmpty) {
        _selectedEquipment.clear();
        _selectedEquipment.addAll(profile.equipment);
      }
      if (profile.cardioEquipment.isNotEmpty) {
        _selectedCardio.clear();
        _selectedCardio.addAll(profile.cardioEquipment);
      }
    });
  }

  void _syncProfile() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    final updated = profile.copyWith(
      age: int.tryParse(_ageController.text) ?? profile.age,
      heightCm: double.tryParse(_heightController.text) ?? profile.heightCm,
      weightKg: double.tryParse(_weightController.text) ?? profile.weightKg,
      gender: _gender,
      experience: _experience,
      fitnessGoal: _goal,
      weeklyWorkoutGoal: _daysPerWeek,
      sessionDurationMinutes: _durationMinutes,
      intensityLevel: _level,
      equipment: List.of(_selectedEquipment),
      cardioEquipment: List.of(_selectedCardio),
    );

    ref.read(profileRepositoryProvider).saveProfile(updated);
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _syncProfile();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _generatePlan() async {
    HapticFeedback.lightImpact();
    _syncProfile();
    setState(() => _isGenerating = true);
    try {
      final survey = SurveyData(
        age: int.tryParse(_ageController.text) ?? 25,
        gender: _gender,
        heightCm: double.tryParse(_heightController.text) ?? 175.0,
        weightKg: double.tryParse(_weightController.text) ?? 70.0,
        experience: _experience,
        goal: _goal,
        daysPerWeek: _daysPerWeek,
        durationMinutes: _durationMinutes,
        level: _level,
        equipment: _selectedEquipment,
        cardioAvailable: _selectedCardio,
      );

      await ref.read(workoutGeneratorProvider).generateAndSaveProgram(survey);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly program generated successfully!')),
      );
      context.go('/plans');
    } on StateError catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finish your current week first'),
          content: Text(e.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate program: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isGenerating) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 28),
                Text(
                  'GymGenie is creating your week...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mapping muscle splits, matching equipment, and structuring progressive intensity.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Workout Generator'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: StepIndicator(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAboutMeStep(theme),
                  _buildGoalStep(theme),
                  _buildAvailabilityStep(theme),
                  _buildLevelStep(theme),
                  _buildEquipmentStep(theme),
                  _buildCardioStep(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _prevPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: isLastStep ? _generatePlan : _nextPage,
                    child: Text(
                        isLastStep ? 'Generate My Week' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMeStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Tell us about yourself',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.sync, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Pre-filled from your profile — changes sync back.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _MetricInput(
                label: 'Age',
                controller: _ageController,
                suffix: 'years',
                onChanged: (_) => _syncProfile(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DropdownInput(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female', 'Other'],
                onChanged: (val) {
                  setState(() => _gender = val ?? 'Male');
                  _syncProfile();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricInput(
                label: 'Height',
                controller: _heightController,
                suffix: 'cm',
                onChanged: (_) => _syncProfile(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricInput(
                label: 'Weight',
                controller: _weightController,
                suffix: 'kg',
                onChanged: (_) => _syncProfile(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Fitness Experience',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final exp in ['Beginner', 'Intermediate', 'Advanced'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableCard(
              title: exp,
              selected: _experience == exp,
              onTap: () {
                setState(() => _experience = exp);
                _syncProfile();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGoalStep(ThemeData theme) {
    final goals = [
      {'title': 'Lose weight', 'icon': Icons.trending_down, 'desc': 'Calorie-focused plans with cardio'},
      {'title': 'Build muscle', 'icon': Icons.fitness_center, 'desc': 'Hypertrophy-focused resistance training'},
      {'title': 'Strength', 'icon': Icons.bolt, 'desc': 'Lower reps, heavier loads'},
      {'title': 'Fat loss + muscle retention', 'icon': Icons.shield, 'desc': 'Body recomposition approach'},
      {'title': 'General fitness', 'icon': Icons.favorite_outline, 'desc': 'Balanced mix of strength and cardio'},
      {'title': 'Improve endurance', 'icon': Icons.speed, 'desc': 'Higher volume cardio and conditioning'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'What is your main goal?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        for (final g in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableCard(
              icon: g['icon'] as IconData,
              title: g['title'] as String,
              subtitle: g['desc'] as String,
              selected: _goal == g['title'],
              onTap: () {
                setState(() => _goal = g['title'] as String);
                _syncProfile();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilityStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Specify your availability',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: [
              Text(
                'Days per week',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _daysPerWeek.toDouble(),
                min: 2,
                max: 6,
                divisions: 4,
                label: '$_daysPerWeek days',
                onChanged: (val) {
                  setState(() => _daysPerWeek = val.round());
                  _syncProfile();
                },
              ),
              Text(
                '$_daysPerWeek days',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Session duration',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [30, 45, 60, 90].map((dur) {
            final isSel = _durationMinutes == dur;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$dur min'),
                  selected: isSel,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _durationMinutes = dur);
                      _syncProfile();
                    }
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLevelStep(ThemeData theme) {
    final intensities = [
      {
        'title': 'Easy',
        'desc': 'Lower set counts, comfortable rest times.',
      },
      {
        'title': 'Moderate',
        'desc': 'Standard set ranges, standard intensity splits.',
      },
      {
        'title': 'Hard',
        'desc': 'Maximum set volume, challenging progressive loads.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Select your workout intensity',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        for (final intensity in intensities)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableCard(
              title: intensity['title'] as String,
              subtitle: intensity['desc'] as String,
              selected: _level == intensity['title'],
              onTap: () {
                setState(() => _level = intensity['title'] as String);
                _syncProfile();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Select available equipment',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie will build your workout plan using only these options (Bodyweight is always enabled).',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _equipmentOptions.map((eq) {
            final isSel = _selectedEquipment.contains(eq);
            return FilterChip(
              label: Text(eq),
              selected: isSel,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedEquipment.add(eq);
                  } else if (eq != 'Bodyweight') {
                    _selectedEquipment.remove(eq);
                  }
                });
                _syncProfile();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCardioStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Select available cardio equipment',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If your goal includes cardio segments, GymGenie will append sessions using these machines.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cardioOptions.map((cardio) {
            final isSel = _selectedCardio.contains(cardio);
            return FilterChip(
              label: Text(cardio),
              selected: isSel,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCardio.add(cardio);
                  } else {
                    _selectedCardio.remove(cardio);
                  }
                });
                _syncProfile();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MetricInput extends StatelessWidget {
  const _MetricInput({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: onChanged,
                ),
              ),
              Text(
                suffix,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
