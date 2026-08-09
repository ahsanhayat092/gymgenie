import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gymgenie/features/profile/data/profile_repository.dart';
import 'package:gymgenie/features/profile/domain/user_profile.dart';

/// First-run onboarding survey shown to every new user.
/// Collects personal details + fitness preferences, saves them to the
/// Firestore profile, sets [UserProfile.onboardingComplete] = true,
/// and navigates to [/home].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // ── Step 1: About Me ──────────────────────────────────────────────────────
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '70');
  String _gender = 'Male';
  String _experience = 'Beginner';

  // ── Step 2: Goal ──────────────────────────────────────────────────────────
  String _goal = 'Build muscle';

  // ── Step 3: Availability ──────────────────────────────────────────────────
  int _daysPerWeek = 3;
  int _durationMinutes = 45;

  // ── Step 4: Intensity ─────────────────────────────────────────────────────
  String _level = 'Moderate';

  // ── Step 5: Equipment ─────────────────────────────────────────────────────
  final List<String> _equipmentOptions = [
    'Barbell', 'Dumbbell', 'Cable', 'Machine', 'Kettlebell', 'Bodyweight',
  ];
  late List<String> _selectedEquipment = ['Barbell', 'Dumbbell', 'Bodyweight'];

  // ── Step 6: Cardio ────────────────────────────────────────────────────────
  final List<String> _cardioOptions = [
    'Treadmill', 'Bike', 'Elliptical', 'Rowing', 'Stair climber',
  ];
  List<String> _selectedCardio = ['Treadmill', 'Bike'];

  static const int _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      // Build a profile with the survey answers + onboardingComplete flag.
      final existing = ref.read(userProfileProvider).valueOrNull;
      final now = DateTime.now();

      final profile = UserProfile(
        uid: existing?.uid ?? '',
        displayName: existing?.displayName ?? '',
        email: existing?.email ?? '',
        createdAt: existing?.createdAt ?? now,
        weeklyWorkoutGoal: _daysPerWeek,
        onboardingComplete: true,
        // Personal metrics
        age: int.tryParse(_ageController.text) ?? 25,
        heightCm: double.tryParse(_heightController.text) ?? 175.0,
        weightKg: double.tryParse(_weightController.text) ?? 70.0,
        gender: _gender,
        // Fitness prefs
        experience: _experience,
        fitnessGoal: _goal,
        sessionDurationMinutes: _durationMinutes,
        intensityLevel: _level,
        equipment: List.of(_selectedEquipment),
        cardioEquipment: List.of(_selectedCardio),
      );

      await ref.read(profileRepositoryProvider).saveProfile(profile);

      if (!mounted) return;
      // Router redirect will detect onboardingComplete = true and allow /home.
      context.go('/home');
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isSaving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Setting up your profile…',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
            // ── Progress bar + step counter ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // App logo / brand
                      Text(
                        'GymGenie',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────────
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

            // ── Navigation footer ─────────────────────────────────────────────
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
                    const SizedBox(),
                  FilledButton(
                    onPressed: isLastStep ? _finish : _next,
                    child: Text(isLastStep ? 'Get Started 🚀' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step builders ─────────────────────────────────────────────────────────

  Widget _buildAboutMeStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Welcome to GymGenie! 👋',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
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
              child: TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) => setState(() => _gender = val ?? 'Male'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Fitness Experience', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final exp in ['Beginner', 'Intermediate', 'Advanced'])
          RadioListTile<String>(
            title: Text(exp),
            value: exp,
            groupValue: _experience,
            onChanged: (val) => setState(() => _experience = val ?? 'Beginner'),
          ),
      ],
    );
  }

  Widget _buildGoalStep(ThemeData theme) {
    final goals = [
      {'title': 'Lose weight', 'icon': Icons.trending_down},
      {'title': 'Build muscle', 'icon': Icons.fitness_center},
      {'title': 'Strength', 'icon': Icons.bolt},
      {'title': 'Fat loss + muscle retention', 'icon': Icons.shield},
      {'title': 'General fitness', 'icon': Icons.favorite_outline},
      {'title': 'Improve endurance', 'icon': Icons.speed},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'What is your main goal?',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie will build every plan around this objective.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        for (final g in goals) ...[
          Card(
            color: _goal == g['title']
                ? theme.colorScheme.primaryContainer
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _goal == g['title']
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ListTile(
              leading: Icon(g['icon'] as IconData,
                  color: _goal == g['title']
                      ? theme.colorScheme.primary
                      : null),
              title: Text(g['title'] as String,
                  style: TextStyle(
                    fontWeight: _goal == g['title'] ? FontWeight.bold : null,
                  )),
              trailing: Radio<String>(
                value: g['title'] as String,
                groupValue: _goal,
                onChanged: (val) =>
                    setState(() => _goal = val ?? 'Build muscle'),
              ),
              onTap: () => setState(() => _goal = g['title'] as String),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAvailabilityStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'How often can you train?',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie splits your week to match your schedule.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Text('Days per week', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Slider(
          value: _daysPerWeek.toDouble(),
          min: 2, max: 6, divisions: 4,
          label: '$_daysPerWeek days',
          onChanged: (v) => setState(() => _daysPerWeek = v.round()),
        ),
        Center(
          child: Text(
            '$_daysPerWeek days / week',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        Text('Session duration', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
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
      {'title': 'Easy', 'desc': 'Lower set counts, comfortable rest times.'},
      {'title': 'Moderate', 'desc': 'Standard set ranges, balanced intensity.'},
      {'title': 'Hard', 'desc': 'Maximum set volume, challenging progressive loads.'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Choose your intensity',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This controls how hard your sessions will push you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        for (final item in intensities) ...[
          Card(
            color: _level == item['title']
                ? theme.colorScheme.primaryContainer
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _level == item['title']
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ListTile(
              title: Text(item['title'] as String,
                  style: TextStyle(
                    fontWeight:
                        _level == item['title'] ? FontWeight.bold : null,
                  )),
              subtitle: Text(item['desc'] as String),
              trailing: Radio<String>(
                value: item['title'] as String,
                groupValue: _level,
                onChanged: (val) =>
                    setState(() => _level = val ?? 'Moderate'),
              ),
              onTap: () =>
                  setState(() => _level = item['title'] as String),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildEquipmentStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'What equipment do you have?',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie only recommends exercises you can actually do.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8, runSpacing: 8,
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
        const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Cardio equipment available?',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'GymGenie will append cardio segments for fat-loss and endurance goals.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8, runSpacing: 8,
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

        // ── Final summary card ────────────────────────────────────────────
        Card(
          color: theme.colorScheme.primaryContainer.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Almost there!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile is ready. Tap "Get Started" and GymGenie will save everything. You can always update these details from the AI Generator or your Profile at any time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
