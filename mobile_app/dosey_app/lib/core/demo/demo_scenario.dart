enum DemoScenarioId {
  happyPath,
  missedRecognized,
  offlineReconnect,
  nack,
  preAcceptanceTimeout,
  jam,
  disconnectAfterAcceptance,
  globalSerialization,
}

class DemoScenarioStep {
  const DemoScenarioStep(this.label);

  final String label;
}

class DemoScenarioDefinition {
  const DemoScenarioDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
  });

  final DemoScenarioId id;
  final String title;
  final String description;
  final List<DemoScenarioStep> steps;
}

const demoScenarioCatalog = <DemoScenarioDefinition>[
  DemoScenarioDefinition(
    id: DemoScenarioId.happyPath,
    title: 'Happy path',
    description: 'Approaching through separate visible and taken confirmation.',
    steps: [
      DemoScenarioStep('Dose approaching'),
      DemoScenarioStep('Dose ready'),
      DemoScenarioStep('Command sent'),
      DemoScenarioStep('Command accepted'),
      DemoScenarioStep('Movement started'),
      DemoScenarioStep('Servo done'),
      DemoScenarioStep('Dose visible'),
      DemoScenarioStep('Dose taken'),
    ],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.missedRecognized,
    title: 'Missed and recognized',
    description: 'Missed-dose detection followed by seen-only recognition.',
    steps: [
      DemoScenarioStep('Dose missed'),
      DemoScenarioStep('Warning recognized'),
    ],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.offlineReconnect,
    title: 'Offline and reconnect',
    description: 'A missed heartbeat followed by a healthy reconnect.',
    steps: [
      DemoScenarioStep('Controller offline'),
      DemoScenarioStep('Controller reconnected'),
    ],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.nack,
    title: 'Command rejected',
    description: 'A proven pre-movement NACK leaves the dose loaded.',
    steps: [DemoScenarioStep('NACK received')],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.preAcceptanceTimeout,
    title: 'Pre-accept timeout',
    description: 'A proven pre-acceptance timeout leaves the dose loaded.',
    steps: [DemoScenarioStep('Acceptance timed out')],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.jam,
    title: 'Jam after acceptance',
    description: 'Ambiguous movement quarantines the slot for review.',
    steps: [DemoScenarioStep('Jam reported')],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.disconnectAfterAcceptance,
    title: 'Disconnect after acceptance',
    description: 'Transport loss after acceptance requires slot review.',
    steps: [DemoScenarioStep('Connection lost')],
  ),
  DemoScenarioDefinition(
    id: DemoScenarioId.globalSerialization,
    title: 'Global serialization',
    description: 'A second physical command is rejected while one is active.',
    steps: [
      DemoScenarioStep('Competing command rejected'),
      DemoScenarioStep('Original command completed'),
    ],
  ),
];

class DemoScenarioState {
  const DemoScenarioState({
    required this.scenario,
    required this.completedSteps,
    required this.isPlaying,
    this.isPresenting = false,
    this.lastMessage,
  });

  final DemoScenarioDefinition scenario;
  final int completedSteps;
  final bool isPlaying;
  final bool isPresenting;
  final String? lastMessage;

  bool get isComplete => completedSteps >= scenario.steps.length;

  DemoScenarioStep? get nextStep =>
      isComplete ? null : scenario.steps[completedSteps];

  DemoScenarioState copyWith({
    int? completedSteps,
    bool? isPlaying,
    bool? isPresenting,
    String? lastMessage,
    bool clearLastMessage = false,
  }) {
    return DemoScenarioState(
      scenario: scenario,
      completedSteps: completedSteps ?? this.completedSteps,
      isPlaying: isPlaying ?? this.isPlaying,
      isPresenting: isPresenting ?? this.isPresenting,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
    );
  }
}
