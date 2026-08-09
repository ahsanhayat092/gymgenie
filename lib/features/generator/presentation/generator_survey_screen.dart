import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gymgenie/features/generator/application/workout_generator.dart';

class GeneratorSurveyScreen extends ConsumerStatefulWidget {
  const GeneratorSurveyScreen({super.key});

  @override
  ConsumerState<GeneratorSurveyScreen> createState() => _GeneratorSurveyScreenState();
}

class _GeneratorSurveyScreenState extends ConsumerState<GeneratorSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isGenerating = false;

  // Survey state values
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '70');
  String _gender = 'Male';
  String _experience = 'Beginner';

  String _goal = 'Build Muscle';

  int _daysPerWeek = 3;
  int _durationMinutes = 45;

  String _level = 'Moderate';

  final List<String> _equipmentOptions = [
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Kettlebell',
    'Bodyweight',
  ];
  late List<String> _selectedEquipment = ['Barbell', 'Dumbbell', 'Bodyweight'];

  final List<String> _cardioOptions = [
    'Treadmill',
    'Bike',
    'Elliptical',
    'Rowing',
    'Stair climber',
  ];
  List<String> _selectedCardio = ['Treadmill', 'Bike'];

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _generatePlan() async {
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
    } catch (e) {
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'GymGenie is creating your week...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mapping muscle splits, matching equipment parameters, and structuring progressive intensity scales...',
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
        title: const Text('Personalised Workout Generator'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevPage,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress Bar Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Step ${_currentStep + 1} of 6',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentStep = idx),
              physics: const NeverScrollableScrollPhysics(), // Force using buttons for clean flow
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
          // Navigation Bottom Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: _prevPage,
                    child: const Text('Back'),
                  )
                else
                  const SizedBox(),
                FilledButton(
                  onPressed: _currentStep == 5 ? _generatePlan : _nextPage,
                  child: Text(_currentStep == 5 ? 'Generate My Week' : 'Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutMeStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Tell us about yourself',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('This helps GymGenie scale weight recommendations and baseline metrics.'),
        const SizedBox(height: 24),
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
        const SizedBox(height: 24),
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
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'What is your main goal?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        for (final g in goals) ...[
          Card(
            color: _goal == g['title'] ? theme.colorScheme.primaryContainer : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _goal == g['title']
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ListTile(
              leading: Icon(
                g['icon'] as IconData,
                color: _goal == g['title'] ? theme.colorScheme.primary : null,
              ),
              title: Text(
                g['title'] as String,
                style: TextStyle(
                  fontWeight: _goal == g['title'] ? FontWeight.bold : null,
                ),
              ),
              trailing: Radio<String>(
                value: g['title'] as String,
                groupValue: _goal,
                onChanged: (val) => setState(() => _goal = val ?? 'Build Muscle'),
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
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Specify your availability',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Text('How many days per week?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Slider(
          value: _daysPerWeek.toDouble(),
          min: 2,
          max: 6,
          divisions: 4,
          label: '$_daysPerWeek days',
          onChanged: (val) => setState(() => _daysPerWeek = val.round()),
        ),
        Center(
          child: Text(
            '$_daysPerWeek days / week',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        Text('Workout session duration?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
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
                    if (selected) setState(() => _durationMinutes = dur);
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
      {'title': 'Moderate', 'desc': 'Standard set ranges, standard intensity splits.'},
      {'title': 'Hard', 'desc': 'Maximum set volume, challenging progressive loads.'},
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Select your workout intensity',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        for (final intensity in intensities) ...[
          Card(
            color: _level == intensity['title'] ? theme.colorScheme.primaryContainer : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _level == intensity['title']
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ListTile(
              title: Text(
                intensity['title'] as String,
                style: TextStyle(
                  fontWeight: _level == intensity['title'] ? FontWeight.bold : null,
                ),
              ),
              subtitle: Text(intensity['desc'] as String),
              trailing: Radio<String>(
                value: intensity['title'] as String,
                groupValue: _level,
                onChanged: (val) => setState(() => _level = val ?? 'Moderate'),
              ),
              onTap: () => setState(() => _level = intensity['title'] as String),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildEquipmentStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Select available equipment',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('GymGenie will build your workout plan using only these options (Bodyweight is always enabled).'),
        const SizedBox(height: 20),
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
                  } else {
                    if (eq != 'Bodyweight') {
                      _selectedEquipment.remove(eq);
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCardioStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Select available cardio equipment',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('If your goal includes cardio segments, GymGenie will append sessions using these machines.'),
        const SizedBox(height: 20),
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
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
