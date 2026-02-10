import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Database Test Screen
///
/// Simple UI to test Supabase database connection and verify migration
class DatabaseTestScreen extends ConsumerStatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  ConsumerState<DatabaseTestScreen> createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends ConsumerState<DatabaseTestScreen> {
  String _status = 'Ready to test';
  bool _isLoading = false;
  final List<String> _results = [];

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _results.clear();
      _status = 'Running tests...';
    });

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Test 1: Check if we can connect
      _addResult('✅ Supabase client initialized');

      // Test 2: Query user_profiles table
      try {
        await supabase
            .from('user_profiles')
            .select('id')
            .limit(1);
        _addResult('✅ user_profiles table accessible');
      } catch (e) {
        _addResult('❌ user_profiles: ${e.toString()}');
      }

      // Test 3: Query activities table
      try {
        await supabase
            .from('activities')
            .select('id')
            .limit(1);
        _addResult('✅ activities table accessible');
      } catch (e) {
        _addResult('❌ activities: ${e.toString()}');
      }

      // Test 4: Query segments table
      try {
        await supabase
            .from('segments')
            .select('id')
            .limit(1);
        _addResult('✅ segments table accessible');
      } catch (e) {
        _addResult('❌ segments: ${e.toString()}');
      }

      // Test 5: Query segment_efforts table
      try {
        await supabase
            .from('segment_efforts')
            .select('id')
            .limit(1);
        _addResult('✅ segment_efforts table accessible');
      } catch (e) {
        _addResult('❌ segment_efforts: ${e.toString()}');
      }

      // Test 6: Query planned_workouts table
      try {
        await supabase
            .from('planned_workouts')
            .select('id')
            .limit(1);
        _addResult('✅ planned_workouts table accessible');
      } catch (e) {
        _addResult('❌ planned_workouts: ${e.toString()}');
      }

      setState(() {
        _status = 'Tests complete!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
      _addResult('❌ Connection error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addResult(String result) {
    setState(() {
      _results.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test Supabase Connection',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Verify that all tables are accessible',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _results.any((r) => r.startsWith('❌'))
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _results.any((r) => r.startsWith('❌'))
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Run Test Button
            ElevatedButton(
              onPressed: _isLoading ? null : _runTests,
              child: const Text('Run Database Tests'),
            ),
            const SizedBox(height: 24),

            // Results
            if (_results.isNotEmpty) ...[
              Text(
                'Results:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return Text(
                        _results[index],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
