part of 'settings_screen.dart';

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('For setup and repairs'),
                SizedBox(height: 4),
                Text(
                  'Daily reminders and dose confirmations stay in Today. Use these tools only when setting up or repairing the robot.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RobotPhoneSetupScreen(
                      gateway: dependencies.robotPhoneSetup,
                      externalActionResumeGuard:
                          dependencies.externalActionResumeGuard,
                    ),
                  ),
                ),
                icon: const Icon(Icons.phonelink_setup_outlined),
                label: const Text('Robot phone setup'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Controller'),
                      Tab(text: 'Service records'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [ControllerScreen(), _MaintenanceRecords()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceRecords extends StatelessWidget {
  const _MaintenanceRecords();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _AdminHistoryCard(),
        SizedBox(height: 12),
        _BackupDatabaseCard(),
      ],
    );
  }
}
