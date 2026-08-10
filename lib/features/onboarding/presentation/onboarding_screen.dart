import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gymgenie/core/widgets/selectable_card.dart';
import 'package:gymgenie/core/widgets/step_indicator.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/profile/domain/user_profile.dart';

/// First-run onboarding survey shown to every new user.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  static const int _totalSteps = 6;

  // Step 1: About Me
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '70');
  String _gender = 'Male';
  String _experience = 'Beginner';

  // Step 2: Goal
  String _goal = 'Build muscle';

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
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prev() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    try {
      final existing = ref.read(userProfileProvider).valueOrNull;
      final now = DateTime.now();

      final profile = UserProfile(
        uid: existing?.uid ?? '',
        displayName: existing?.displayName ?? '',
        email: existing?.email ?? '',
        createdAt: existing?.createdAt ?? now,
        weeklyWorkoutGoal: _daysPerWeek,
        onboardingComplete: true,
        age: int.tryParse(_ageController.text) ?? 25,
        heightCm: double.tryParse(_heightController.text) ?? 175.0,
        weightKg: double.tryParse(_weightController.text) ?? 70.0,
        gender: _gender,
        experience: _experience,
        fitnessGoal: _goal,
        sessionDurationMinutes: _durationMinutes,
        intensityLevel: _level,
        equipment: List.of(_selectedEquipment),
        cardioEquipment: List.of(_selectedCardio),
      );

      await ref.read(profileRepositoryProvider).saveProfile(profile);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isSaving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Setting up your profile…',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'GymGenie',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StepIndicator(
                    currentStep: _currentStep,
                    totalSteps: _totalSteps,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentStep = i),
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
                      onPressed: _prev,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: isLastStep ? _finish : _next,
                    child: Text(isLastStep ? 'Get Started' : 'Continue'),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'Welcome to GymGenie',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us a bit about yourself so GymGenie can personalise everything for you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _MetricInput(
                label: 'Age',
                controller: _ageController,
                suffix: 'years',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DropdownInput(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female', 'Other'],
                onChanged: (val) => setState(() => _gender = val ?? 'Male'),
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricInput(
                label: 'Weight',
                controller: _weightController,
                suffix: 'kg',
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
              onTap: () => setState(() => _experience = exp),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'What is your main goal?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie will build every plan around this objective.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
              onTap: () => setState(() => _goal = g['title'] as String),
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilityStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'How often can you train?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie splits your week to match your schedule.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
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
                onChanged: (v) => setState(() => _daysPerWeek = v.round()),
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
            final sel = _durationMinutes == dur;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$dur min'),
                  selected: sel,
                  onSelected: (s) {
                    if (s) setState(() => _durationMinutes = dur);
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
        'desc': 'Standard set ranges, balanced intensity.',
      },
      {
        'title': 'Hard',
        'desc': 'Maximum set volume, challenging progressive loads.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'Choose your intensity',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This controls how hard your sessions will push you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        for (final item in intensities)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableCard(
              title: item['title'] as String,
              subtitle: item['desc'] as String,
              selected: _level == item['title'],
              onTap: () => setState(() => _level = item['title'] as String),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'What equipment do you have?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie only recommends exercises you can actually do.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _equipmentOptions.map((eq) {
            final sel = _selectedEquipment.contains(eq);
            return FilterChip(
              label: Text(eq),
              selected: sel,
              onSelected: (s) => setState(() {
                if (s) {
                  _selectedEquipment.add(eq);
                } else if (eq != 'Bodyweight') {
                  _selectedEquipment.remove(eq);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'Bodyweight is always available.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCardioStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(
          'Cardio equipment available?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie will append cardio segments for fat-loss and endurance goals.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cardioOptions.map((cardio) {
            final sel = _selectedCardio.contains(cardio);
            return FilterChip(
              label: Text(cardio),
              selected: sel,
              onSelected: (s) => setState(() {
                if (s) {
                  _selectedCardio.add(cardio);
                } else {
                  _selectedCardio.remove(cardio);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost there!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Get Started" and GymGenie will save everything. You can update these details anytime.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  });

  final String label;
  final TextEditingController controller;
  final String suffix;

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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
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
