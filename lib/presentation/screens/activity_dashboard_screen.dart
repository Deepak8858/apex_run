import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/daily_activity.dart';
import '../providers/app_providers.dart';
import '../providers/step_tracking_provider.dart';

/// Activity Dashboard Screen
///
/// Full-screen dashboard showing:
/// - Circular progress ring for daily step goal
/// - Today's stats (calories, distance, active minutes)
/// - Weekly bar chart of steps
/// - Monthly trend line chart
/// - Weekly summary stats
class ActivityDashboardScreen extends ConsumerStatefulWidget {
  const ActivityDashboardScreen({super.key});

  @override
  ConsumerState<ActivityDashboardScreen> createState() =>
      _ActivityDashboardScreenState();
}

class _ActivityDashboardScreenState
    extends ConsumerState<ActivityDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayActivityProvider);
    final snapshot = ref.watch(todayActivitySnapshotProvider);
    final today = todayAsync.valueOrNull ?? snapshot;
    final stepGoal = ref.watch(stepGoalProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Activity Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_rounded),
            tooltip: 'Set step goal',
            onPressed: () => _showGoalDialog(context, stepGoal),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Progress Ring ────────────────────────────────
            _buildProgressRing(context, today),
            const SizedBox(height: 24),

            // ── Today's Stats Row ───────────────────────────
            _buildStatsRow(context, today),
            const SizedBox(height: 24),

            // ── Chart Tabs ──────────────────────────────────
            _buildChartSection(context),
            const SizedBox(height: 24),

            // ── Weekly Summary ──────────────────────────────
            _buildWeeklySummary(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(BuildContext context, DailyActivity today) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 100.0,
            lineWidth: 14.0,
            percent: today.goalProgress,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${today.steps}',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                ),
                Text(
                  'of ${today.stepGoal} steps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
            progressColor: today.goalReached
                ? AppTheme.success
                : AppTheme.electricLime,
            backgroundColor: AppTheme.surfaceLight,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 800,
          ),
          if (today.goalReached) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration_rounded,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Goal reached!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, DailyActivity today) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Calories',
          value: today.formattedCalories,
          unit: 'cal',
          color: AppTheme.elevation,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.straighten_rounded,
          label: 'Distance',
          value: today.distanceKm >= 1.0
              ? today.distanceKm.toStringAsFixed(1)
              : '${(today.distanceKm * 1000).toInt()}',
          unit: today.distanceKm >= 1.0 ? 'km' : 'm',
          color: AppTheme.distance,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.timer_rounded,
          label: 'Active',
          value: '${today.activeMinutes}',
          unit: 'min',
          color: AppTheme.info,
        ),
      ],
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.electricLime,
            labelColor: AppTheme.electricLime,
            unselectedLabelColor: AppTheme.textTertiary,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
          SizedBox(
            height: 240,
            child: TabBarView(
              controller: _tabController,
              children: [
                _WeeklyBarChart(),
                _MonthlyLineChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary(BuildContext context) {
    final weekly = ref.watch(weeklyActivityProvider);
    if (weekly.isEmpty) return const SizedBox.shrink();

    final totalSteps = weekly.fold<int>(0, (sum, d) => sum + d.steps);
    final totalCalories =
        weekly.fold<double>(0.0, (sum, d) => sum + d.caloriesBurned);
    final totalDistance =
        weekly.fold<double>(0.0, (sum, d) => sum + d.distanceKm);
    final daysGoalReached = weekly.where((d) => d.goalReached).length;
    final avgSteps = weekly.isNotEmpty ? totalSteps ~/ weekly.length : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Avg Steps',
                  value: avgSteps.toString(),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Total Cal',
                  value: totalCalories.toInt().toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Total Dist',
                  value: '${totalDistance.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Goals Hit',
                  value: '$daysGoalReached / ${weekly.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGoalDialog(BuildContext context, int currentGoal) {
    final controller =
        TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Daily Step Goal',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. 10000',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.surfaceLight),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.electricLime),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final goal = int.tryParse(controller.text);
              if (goal != null && goal > 0) {
                ref.read(profileControllerProvider.notifier).updateProfile(
                      dailyStepGoal: goal,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save',
                style: TextStyle(color: AppTheme.electricLime)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Private Helper Widgets
// ═══════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                )),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Charts
// ═══════════════════════════════════════════════════════════

class _WeeklyBarChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyActivityProvider);
    final stepGoal = ref.watch(stepGoalProvider);

    if (weekly.isEmpty) {
      return const Center(
        child: Text('No data yet',
            style: TextStyle(color: AppTheme.textTertiary)),
      );
    }

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxSteps = weekly
        .fold<int>(0, (max, d) => d.steps > max ? d.steps : max)
        .toDouble();
    final yMax = (maxSteps > stepGoal ? maxSteps : stepGoal.toDouble()) * 1.15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: BarChart(
        BarChartData(
          maxY: yMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} steps',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dayLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dayLabels[idx],
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.surfaceLight,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: stepGoal.toDouble(),
                color: AppTheme.electricLime.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    color: AppTheme.electricLime.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  labelResolver: (_) => 'Goal',
                ),
              ),
            ],
          ),
          barGroups: List.generate(weekly.length, (i) {
            final d = weekly[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.steps.toDouble(),
                  color: d.goalReached
                      ? AppTheme.success
                      : AppTheme.electricLime,
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MonthlyLineChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(monthlyActivityProvider);
    final stepGoal = ref.watch(stepGoalProvider);

    if (monthly.isEmpty) {
      return const Center(
        child: Text('No data yet',
            style: TextStyle(color: AppTheme.textTertiary)),
      );
    }

    final maxSteps = monthly
        .fold<int>(0, (max, d) => d.steps > max ? d.steps : max)
        .toDouble();
    final yMax = (maxSteps > stepGoal ? maxSteps : stepGoal.toDouble()) * 1.15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: LineChart(
        LineChartData(
          maxY: yMax,
          minY: 0,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toInt()} steps',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < monthly.length) {
                    final d = monthly[idx].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${d.day}/${d.month}',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.surfaceLight,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: stepGoal.toDouble(),
                color: AppTheme.electricLime.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(monthly.length, (i) {
                return FlSpot(i.toDouble(), monthly[i].steps.toDouble());
              }),
              isCurved: true,
              color: AppTheme.electricLime,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.electricLime.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
