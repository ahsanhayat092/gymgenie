import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _isGenerating = false;

  // Step 1: About Me
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _feetController;
  late final TextEditingController _inchesController;
  bool _useFtIn = false;
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
    _feetController = TextEditingController(text: '5');
    _inchesController = TextEditingController(text: '9');
    _weightController = TextEditingController(text: '70');
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
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
        final totalInches = profile.heightCm / 2.54;
        final feet = (totalInches / 12).floor();
        final inches = (totalInches % 12).round();
        _feetController.text = feet.toString();
        _inchesController.text = inches.toString();
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

    double heightCm = 175.0;
    if (_useFtIn) {
      final feet = double.tryParse(_feetController.text) ?? 5.0;
      final inches = double.tryParse(_inchesController.text) ?? 9.0;
      heightCm = (feet * 12 + inches) * 2.54;
    } else {
      heightCm = double.tryParse(_heightController.text) ?? 175.0;
    }

    final updated = profile.copyWith(
      age: int.tryParse(_ageController.text) ?? profile.age,
      heightCm: heightCm,
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

  Future<void> _generatePlan() async {
    HapticFeedback.lightImpact();
    _syncProfile();
    setState(() => _isGenerating = true);
    try {
      double heightCm = 175.0;
      if (_useFtIn) {
        final feet = double.tryParse(_feetController.text) ?? 5.0;
        final inches = double.tryParse(_inchesController.text) ?? 9.0;
        heightCm = (feet * 12 + inches) * 2.54;
      } else {
        heightCm = double.tryParse(_heightController.text) ?? 175.0;
      }

      final survey = SurveyData(
        age: int.tryParse(_ageController.text) ?? 25,
        gender: _gender,
        heightCm: heightCm,
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
                  'GymZish is creating your week...',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Workout Generator'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    'Customize AI Plan Parameters',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pre-filled from your profile. Feel free to adjust these options for this specific plan generation.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section 1: Goal & Experience
                  _buildSectionHeader(theme, 'Goals & Level'),
                  const SizedBox(height: 16),
                  _buildGoalSelector(theme),
                  const SizedBox(height: 16),
                  _buildLevelSelector(theme),
                  const SizedBox(height: 32),

                  // Section 2: Frequency & Duration
                  _buildSectionHeader(theme, 'Availability'),
                  const SizedBox(height: 16),
                  _buildAvailabilitySlider(theme),
                  const SizedBox(height: 16),
                  _buildDurationChips(theme),
                  const SizedBox(height: 32),

                  // Section 3: About Me
                  _buildSectionHeader(theme, 'Personal Metrics'),
                  const SizedBox(height: 16),
                  _buildMetricsInputs(theme),
                  const SizedBox(height: 32),

                  // Section 4: Equipment
                  _buildSectionHeader(theme, 'Equipment Access'),
                  const SizedBox(height: 16),
                  _buildEquipmentChips(theme),
                  const SizedBox(height: 16),
                  _buildCardioChips(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _generatePlan,
                  child: const Text('Generate My Week'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(),
      ],
    );
  }

  Widget _buildGoalSelector(ThemeData theme) {
    final goals = [
      'Lose weight',
      'Build muscle',
      'Strength',
      'Fat loss + muscle retention',
      'General fitness',
      'Improve endurance'
    ];
    return _DropdownInput(
      label: 'Main Fitness Goal',
      value: _goal,
      items: goals,
      onChanged: (val) {
        if (val != null) {
          setState(() => _goal = val);
          _syncProfile();
        }
      },
    );
  }

  Widget _buildLevelSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _DropdownInput(
            label: 'Experience Level',
            value: _experience,
            items: const ['Beginner', 'Intermediate', 'Advanced'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _experience = val);
                _syncProfile();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DropdownInput(
            label: 'Training Intensity',
            value: _level,
            items: const ['Easy', 'Moderate', 'Hard'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _level = val);
                _syncProfile();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySlider(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Workouts',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$_daysPerWeek days / week',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _daysPerWeek.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            onChanged: (val) {
              setState(() => _daysPerWeek = val.round());
              _syncProfile();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Duration',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [30, 45, 60, 90].map((dur) {
              final isSel = _durationMinutes == dur;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
      ),
    );
  }

  Widget _buildMetricsInputs(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  if (val != null) {
                    setState(() => _gender = val);
                    _syncProfile();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Height',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _useFtIn = !_useFtIn;
                  if (_useFtIn) {
                    final cm = double.tryParse(_heightController.text) ?? 175.0;
                    final totalInches = cm / 2.54;
                    final feet = (totalInches / 12).floor();
                    final inches = (totalInches % 12).round();
                    _feetController.text = feet.toString();
                    _inchesController.text = inches.toString();
                  } else {
                    final feet = double.tryParse(_feetController.text) ?? 5.0;
                    final inches = double.tryParse(_inchesController.text) ?? 9.0;
                    final cm = (feet * 12 + inches) * 2.54;
                    _heightController.text = cm.toStringAsFixed(0);
                  }
                });
                _syncProfile();
              },
              child: Text(
                _useFtIn ? 'Switch to cm' : 'Switch to ft/in',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (!_useFtIn)
              Expanded(
                child: _MetricInput(
                  label: 'Height',
                  controller: _heightController,
                  suffix: 'cm',
                  onChanged: (_) => _syncProfile(),
                ),
              )
            else
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricInput(
                        label: 'Feet',
                        controller: _feetController,
                        suffix: 'ft',
                        onChanged: (_) => _syncProfile(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricInput(
                        label: 'Inches',
                        controller: _inchesController,
                        suffix: 'in',
                        onChanged: (_) => _syncProfile(),
                      ),
                    ),
                  ],
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
      ],
    );
  }

  Widget _buildEquipmentChips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strength Equipment Available',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _buildCardioChips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cardio Equipment Available',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
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
      ),
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
