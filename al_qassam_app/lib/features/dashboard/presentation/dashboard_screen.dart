import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import '../../reports_export/services/excel_exporter.dart';
import '../../reports_export/services/pdf_exporter.dart';
import '../../reports_export/services/report_formatter.dart';
import '../../settings/providers/settings_provider.dart';

enum DashboardDateMode { today, customDate, customRange, all }

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToImport;
  final VoidCallback onNavigateToIncoming;

  const DashboardScreen({
    super.key,
    required this.onNavigateToImport,
    required this.onNavigateToIncoming,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardDateMode _dateMode = DashboardDateMode.today;
  DateTime? _customDate;
  DateTimeRange? _customDateRange;
  int _selectedTab = 0; // 0: كشف الوارد والعمليات, 1: المركز المالي والأرباح

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final batchesState = ref.watch(batchesProvider);
    final buyRate = ref.watch(buyRateProvider);
    final sellRate = ref.watch(sellRateProvider);
    final bureauName = ref.watch(bureauNameProvider);
    final isClassificationEnabled = ref.watch(sizeClassificationEnabledProvider);
    final largeThreshold = ref.watch(largeThresholdProvider);

    // Fetch remittances and outgoing transfers based on date mode
    List<IncomingRemittance> remittances;
    List<OutgoingTransfer> outgoingTransfers;
    String statementTitle;

    switch (_dateMode) {
      case DashboardDateMode.today:
        final now = DateTime.now();
        remittances = LocalStorageService.instance.getAllIncomingRemittances(
          fromDate: DateTime(now.year, now.month, now.day),
          toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        outgoingTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
          fromDate: DateTime(now.year, now.month, now.day),
          toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        statementTitle = 'كشف اليوم (${_formatDate(now)})';
        break;
      case DashboardDateMode.customDate:
        final d = _customDate ?? DateTime.now();
        remittances = LocalStorageService.instance.getAllIncomingRemittances(
          fromDate: DateTime(d.year, d.month, d.day),
          toDate: DateTime(d.year, d.month, d.day, 23, 59, 59),
        );
        outgoingTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
          fromDate: DateTime(d.year, d.month, d.day),
          toDate: DateTime(d.year, d.month, d.day, 23, 59, 59),
        );
        statementTitle = 'كشف ليوم (${_formatDate(d)})';
        break;
      case DashboardDateMode.customRange:
        final range = _customDateRange;
        if (range != null) {
          remittances = LocalStorageService.instance.getAllIncomingRemittances(
            fromDate: range.start,
            toDate: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
          );
          outgoingTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
            fromDate: range.start,
            toDate: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
          );
          statementTitle = 'كشف من ${_formatDate(range.start)} إلى ${_formatDate(range.end)}';
        } else {
          remittances = LocalStorageService.instance.getAllIncomingRemittances();
          outgoingTransfers = LocalStorageService.instance.getAllOutgoingTransfers();
          statementTitle = 'كشف الحوالات';
        }
        break;
      case DashboardDateMode.all:
        remittances = LocalStorageService.instance.getAllIncomingRemittances();
        outgoingTransfers = LocalStorageService.instance.getAllOutgoingTransfers();
        statementTitle = 'كافة الحوالات المسجلة';
        break;
    }

    final totals = FinancialEngine.calculateTotals(remittances, largeThreshold);
    final combinedProfitReport = FinancialEngine.calculateCombinedProfitReport(
      incoming: remittances,
      outgoing: outgoingTransfers,
      buyRate: buyRate,
      sellRate: sellRate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(bureauName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الحسابات',
            onPressed: () {
              setState(() {});
              ref.read(batchesProvider.notifier).loadBatches();
            },
          ),
        ],
      ),
      body: batchesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sleek Compact Exchange Rate Bar
                  _buildCompactRateBar(context, ref, buyRate, sellRate),
                  const SizedBox(height: 10),

                  // 2. Date Classification Toolbar
                  _buildDateFilterToolbar(context),
                  const SizedBox(height: 14),

                  // 3. Segmented Navigation Hub (Ease of Use & Flexibility)
                  _buildSectionSwitcher(
                    context,
                    incomingCount: remittances.length,
                    hasProfitData: remittances.isNotEmpty || outgoingTransfers.isNotEmpty,
                  ),
                  const SizedBox(height: 14),

                  // 4. Content Area Based on Selected Tab
                  if (_selectedTab == 0) ...[
                    // --- TAB 0: كشف الوارد والعمليات ---
                    if (remittances.isEmpty) ...[
                      _buildEmptyState(context, statementTitle),
                    ] else ...[
                      // Executive Grand Total Card
                      _buildGrandTotalCard(context, totals),
                      const SizedBox(height: 12),

                      // Optional Categorization into Small vs Large Remittances
                      if (isClassificationEnabled) ...[
                        Row(
                          children: [
                            Text(
                              'تصنيف الحوالات (الحد: ${FinancialEngine.formatNumber(largeThreshold)} بر)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryEmerald),
                              tooltip: 'تعديل الحد الفاصل',
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(24, 24),
                              ),
                              onPressed: () => _showEditThresholdDialog(context, ref, largeThreshold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoryCard(
                                context,
                                title: 'حوالات صغرى',
                                subTitle: 'أقل من ${FinancialEngine.formatNumber(largeThreshold)} بر',
                                count: totals.smallCount,
                                birrAmount: totals.smallBirrTotal,
                                color: const Color(0xFF0284C7),
                                icon: Icons.compress_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCategoryCard(
                                context,
                                title: 'حوالات كبرى',
                                subTitle: '${FinancialEngine.formatNumber(largeThreshold)} بر فأكثر',
                                count: totals.largeCount,
                                birrAmount: totals.largeBirrTotal,
                                color: AppTheme.accentAmber,
                                icon: Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Mini Audit Stats Strip
                      _buildAuditStatsStrip(context, totals),
                      const SizedBox(height: 14),

                      // Unified Action Hub
                      _buildOperationsActionHub(
                        context: context,
                        remittances: remittances,
                        statementTitle: statementTitle,
                        bureauName: bureauName,
                        totalCount: totals.totalCount,
                        isClassificationEnabled: isClassificationEnabled,
                        largeThreshold: largeThreshold,
                      ),
                    ],
                  ] else ...[
                    // --- TAB 1: المركز المالي والأرباح ---
                    _buildFinancialCenterCard(
                      context: context,
                      report: combinedProfitReport,
                      statementTitle: statementTitle,
                      bureauName: bureauName,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  /// Compact, elegant dual rate bar showing Buy, Sell and Spread in a single row
  Widget _buildCompactRateBar(BuildContext context, WidgetRef ref, double buyRate, double sellRate) {
    final double spread = (buyRate - sellRate).abs();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryEmerald, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRateColumn(context, 'شراء', '$buyRate', const Color(0xFF0284C7)),
                Container(height: 22, width: 1, color: AppTheme.getBorderColor(context)),
                _buildRateColumn(context, 'بيع', '$sellRate', AppTheme.primaryEmerald),
                Container(height: 22, width: 1, color: AppTheme.getBorderColor(context)),
                _buildRateColumn(context, 'الهامش', spread.toStringAsFixed(2), AppTheme.accentAmber),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryEmerald),
            tooltip: 'تعديل أسعار الصرف',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald.withOpacity(0.08),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            ),
            onPressed: () => _showEditDualRateDialog(context, ref, buyRate, sellRate),
          ),
        ],
      ),
    );
  }

  Widget _buildRateColumn(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.getTextSub(context), fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
      ],
    );
  }

  /// Modern Segmented Switcher providing immediate flexibility between Operations and Financial Center
  Widget _buildSectionSwitcher(BuildContext context, {required int incomingCount, required bool hasProfitData}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: _selectedTab == 0 ? AppTheme.primaryEmerald : AppTheme.getTextSub(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'كشف الوارد والعمليات',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 0
                            ? AppTheme.getTextMain(context)
                            : AppTheme.getTextSub(context),
                      ),
                    ),
                    if (incomingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppTheme.primaryEmerald.withOpacity(0.2)
                              : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$incomingCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 0
                                ? (isDark ? AppTheme.primaryLight : AppTheme.primaryEmerald)
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 16,
                      color: _selectedTab == 1 ? AppTheme.primaryEmerald : AppTheme.getTextSub(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'المركز المالي والأرباح',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 1
                            ? AppTheme.getTextMain(context)
                            : AppTheme.getTextSub(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontally scrollable date toolbar with intuitive pills
  Widget _buildDateFilterToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, size: 18, color: AppTheme.primaryEmerald),
            const SizedBox(width: 8),
            _buildDatePill(
              context: context,
              label: 'اليوم',
              icon: Icons.today_rounded,
              isSelected: _dateMode == DashboardDateMode.today,
              onTap: () => setState(() => _dateMode = DashboardDateMode.today),
            ),
            const SizedBox(width: 6),
            _buildDatePill(
              context: context,
              label: _customDate != null ? _formatDate(_customDate!) : 'تاريخ مخصص',
              icon: Icons.event_rounded,
              isSelected: _dateMode == DashboardDateMode.customDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() {
                    _customDate = picked;
                    _dateMode = DashboardDateMode.customDate;
                  });
                }
              },
            ),
            const SizedBox(width: 6),
            _buildDatePill(
              context: context,
              label: _customDateRange != null
                  ? '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}'
                  : 'نطاق زمني',
              icon: Icons.date_range_rounded,
              isSelected: _dateMode == DashboardDateMode.customRange,
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDateRange: _customDateRange,
                );
                if (picked != null) {
                  setState(() {
                    _customDateRange = picked;
                    _dateMode = DashboardDateMode.customRange;
                  });
                }
              },
            ),
            const SizedBox(width: 6),
            _buildDatePill(
              context: context,
              label: 'الكل',
              icon: Icons.list_alt_rounded,
              isSelected: _dateMode == DashboardDateMode.all,
              onTap: () => setState(() => _dateMode = DashboardDateMode.all),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePill({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryEmerald : AppTheme.getSubtleBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryEmerald : AppTheme.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppTheme.getTextSub(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.getTextMain(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grand Total Birr Card with high contrast and executive styling
  Widget _buildGrandTotalCard(BuildContext context, FinancialTotals totals) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجمالي المبلغ المستحق بالبر الإثيوبي',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ETB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${FinancialEngine.formatNumber(totals.totalBirr)} بر',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المبلغ المقبوض: ${FinancialEngine.formatNumber(totals.totalAmount)} ر.س',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${totals.totalCount} حوالة مسجلة',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subTitle,
    required int count,
    required double birrAmount,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.getTextMain(context))),
          Text(subTitle, style: TextStyle(fontSize: 10, color: AppTheme.getTextSub(context))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${FinancialEngine.formatNumber(birrAmount)} بر',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditStatsStrip(BuildContext context, FinancialTotals totals) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rtl_rounded, size: 16, color: AppTheme.primaryEmerald),
              const SizedBox(width: 6),
              Text(
                'إجمالي القيود: ${totals.totalCount}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextMain(context)),
              ),
            ],
          ),
          Container(height: 16, width: 1, color: AppTheme.getBorderColor(context)),
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, size: 16, color: AppTheme.accentAmber),
              const SizedBox(width: 6),
              Text(
                'الكسور المستقطعة: ${totals.totalCutCents.toStringAsFixed(2)} سنت',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextMain(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Unified Action Hub: Resolves the 5-button vertical pile into a clean, balanced command center
  Widget _buildOperationsActionHub({
    required BuildContext context,
    required List<IncomingRemittance> remittances,
    required String statementTitle,
    required String bureauName,
    required int totalCount,
    required bool isClassificationEnabled,
    required double largeThreshold,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الإجراءات والتصدير الرسمي',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getTextSub(context)),
          ),
          const SizedBox(height: 10),

          // Primary Full-Width Action: WhatsApp Copy
          ElevatedButton.icon(
            onPressed: () => _copyBirrReport(context, remittances, statementTitle),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(
              'نسخ كشف البر للواتساب ($totalCount حوالة)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Action Grid (3 Balanced Actions)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onNavigateToIncoming,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.table_rows_rounded, size: 16),
                  label: const Text('عرض الكشف', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportExcel(
                    context,
                    statementTitle,
                    remittances,
                    bureauName,
                    isClassificationEnabled,
                    largeThreshold,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('إكسل Excel', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportPdf(
                    context,
                    statementTitle,
                    remittances,
                    bureauName,
                    isClassificationEnabled,
                    largeThreshold,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('طباعة PDF', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Financial Center & Profit Reconciliation (Accounting Standards Compliant)
  Widget _buildFinancialCenterCard({
    required BuildContext context,
    required CombinedProfitReport report,
    required String statementTitle,
    required String bureauName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryEmerald.withOpacity(isDark ? 0.4 : 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryEmerald.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryEmerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقرير المركز المالي والأرباح التشغيلية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.getTextMain(context)),
                    ),
                    Text(
                      'المطابقة بين الوارد (فارق البر) والصادر (العمولات)',
                      style: TextStyle(fontSize: 11, color: AppTheme.getTextSub(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.help_outline_rounded, color: AppTheme.getTextSub(context), size: 18),
                tooltip: 'شرح المعايير المحاسبية',
                onPressed: () => _showProfitExplanationDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2x2 Financial Metric Tiles
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'أرباح مصارفة البر',
                  value: '+${FinancialEngine.formatNumber(report.birrProfitInOriginal, 2)} ر.س',
                  sub: '${FinancialEngine.formatNumber(report.birrProfitInBirr)} بر إثيوبي',
                  color: AppTheme.primaryEmerald,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'عمولات الحوالات الصادرة',
                  value: '+${FinancialEngine.formatNumber(report.outgoingCommissionsTotal, 2)} ر.س',
                  sub: '${report.outgoingCount} حوالة صادرة',
                  color: const Color(0xFF0284C7),
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'صافي حركة النقد (السيولة)',
                  value: '${FinancialEngine.formatNumber(report.netCashFlow, 2)} ر.س',
                  sub: report.netCashFlow >= 0 ? 'فائض مقبوض (وارد > صادر)' : 'منصرف أكبر (صادر > وارد)',
                  color: report.netCashFlow >= 0 ? const Color(0xFF0F766E) : Colors.red.shade700,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comprehensive Operating Net Profit Highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي صافي الربح التشغيلي',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        'أرباح البر + عمولات الصادر',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+${FinancialEngine.formatNumber(report.totalNetProfitInOriginal, 2)} ر.س',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // WhatsApp Copy Button for Operating Profit
          ElevatedButton.icon(
            onPressed: () => _copyCombinedProfitReport(context, report, statementTitle, bureauName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text(
              'نسخ تقرير المركز المالي والأرباح للواتساب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.getTextMain(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: AppTheme.getTextSub(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String currentTitle) {
    return Container(
      padding: const EdgeInsets.all(28),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryEmerald, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حوالات مسجلة في $currentTitle',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.getTextMain(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك استيراد كشف جديد من نصوص وبيانات الحوالات، وسيتم تصنيفه وفهرسته تلقائياً وفق تاريخ المعاملة.',
            style: TextStyle(fontSize: 12, color: AppTheme.getTextSub(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: widget.onNavigateToImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('الانتقال إلى استيراد الحوالات'),
          ),
        ],
      ),
    );
  }

  void _showEditDualRateDialog(BuildContext context, WidgetRef ref, double currentBuy, double currentSell) {
    final buyCtrl = TextEditingController(text: currentBuy.toString());
    final sellCtrl = TextEditingController(text: currentSell.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bVal = double.tryParse(buyCtrl.text) ?? currentBuy;
          final sVal = double.tryParse(sellCtrl.text) ?? currentSell;
          final spread = (bVal - sVal).abs();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryEmerald),
                SizedBox(width: 8),
                Text('تعديل أسعار صرف البر', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: buyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر شراء رصيد البر',
                      hintText: 'مثال: 50.0',
                      suffixText: 'بر / ر.س',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر بيع وصرف البر للعميل',
                      hintText: 'مثال: 48.0',
                      suffixText: 'بر / ر.س',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('هامش الربح لكل 1 ر.س:', style: TextStyle(fontSize: 12)),
                        Text(
                          '${spread.toStringAsFixed(2)} بر إثيوبي',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newBuy = double.tryParse(buyCtrl.text);
                  final newSell = double.tryParse(sellCtrl.text);
                  if (newBuy != null && newBuy > 0 && newSell != null && newSell > 0) {
                    ref.read(buyRateProvider.notifier).updateBuyRate(newBuy);
                    ref.read(sellRateProvider.notifier).updateSellRate(newSell);
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث أسعار الشراء ($newBuy) والبيع ($newSell) بنجاح')),
                    );
                  }
                },
                child: const Text('حفظ واعتـماد'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProfitExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: AppTheme.primaryEmerald),
            SizedBox(width: 8),
            Text('معايير احتساب المركز المالي', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. أرباح الوارد (مصارفة العملة):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryEmerald),
              ),
              SizedBox(height: 4),
              Text(
                'عند استلام مبلغ بالريال وصرفه بالبر للعميل بسعر البيع، يتم احتساب تكلفة شراء ذلك الرصيد بسعر الشراء، ويمثل الفارق الربح الصافي المحقق بالريال وبالبر.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '2. إيرادات عمولات الحوالات الصادرة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
              ),
              SizedBox(height: 4),
              Text(
                'تُجمع عمولات الحوالات الصادرة المستقطعة من العملاء عبر شبكات الصرافة المختلفة كإيراد تشغيلي مباشر.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '3. إجمالي صافي الربح التشغيلي:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
              ),
              SizedBox(height: 4),
              Text(
                'مجموع أرباح مصارفة البر + عمولات الحوالات الصادرة = إجمالي الربح الفعلي للمكتب.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '4. صافي حركة النقد (السيولة):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'إجمالي المقبوض من الوارد مطروحاً منه إجمالي المنصرف في الحوالات الصادرة لتتبع رصيد السيولة في الصندوق.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _copyCombinedProfitReport(
    BuildContext context,
    CombinedProfitReport report,
    String statementTitle,
    String bureauName,
  ) {
    final formatted = ReportFormatter.formatCombinedProfitReport(
      report,
      bureauName: bureauName,
      dateLabel: statementTitle,
    );
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ تقرير الأرباح والمطابقة لـ $statementTitle بنجاح'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
    );
  }

  void _copyBirrReport(BuildContext context, List<IncomingRemittance> remittances, String statementTitle) {
    if (remittances.isEmpty) return;
    final formatted = ReportFormatter.formatBirrReport(remittances);
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ رسالة البر لـ $statementTitle بنجاح')),
    );
  }

  Future<void> _exportExcel(
    BuildContext context,
    String title,
    List<IncomingRemittance> remittances,
    String bureauName,
    bool enableClassification,
    double largeThreshold,
  ) async {
    try {
      final filePath = await ExcelExporter.exportIncomingRemittances(
        batchLabel: title,
        remittances: remittances,
        bureauName: bureauName,
        enableClassification: enableClassification,
        largeThreshold: largeThreshold,
      );
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم تصدير ملف الإكسل',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم حفظ وتصدير ملف الإكسل بنجاح إلى:'),
              const SizedBox(height: 8),
              SelectableText(
                filePath,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ExcelExporter.openFile(filePath);
              },
              icon: const Icon(Icons.file_open_rounded, size: 18),
              label: const Text('فتح الملف الآن'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تصدير الإكسل: $e')),
      );
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    String title,
    List<IncomingRemittance> remittances,
    String bureauName,
    bool enableClassification,
    double largeThreshold,
  ) async {
    try {
      await PdfExporter.exportAndPrintIncomingReport(
        batchLabel: title,
        remittances: remittances,
        bureauName: bureauName,
        enableClassification: enableClassification,
        largeThreshold: largeThreshold,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء توليد الـ PDF: $e')),
      );
    }
  }

  void _showEditThresholdDialog(BuildContext context, WidgetRef ref, double currentThreshold) {
    final ctrl = TextEditingController(text: currentThreshold.toStringAsFixed(0));
    final quickValues = [50000.0, 100000.0, 150000.0, 200000.0, 500000.0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.price_change_rounded, color: AppTheme.primaryEmerald),
                SizedBox(width: 8),
                Text('الحد الفاصل للحوالات الكبيرة', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الحوالات التي تبلغ قيمتها هذا الحد أو تتجاوزه ستُصنف كـ "حوالة كبيرة" في الكشف والإحصائيات:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubLight),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الحد الفاصل بالبر الإثيوبي',
                      hintText: '100000',
                      suffixText: 'بر',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text('خيارات سريعة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickValues.map((val) {
                      final isSelected = double.tryParse(ctrl.text) == val;
                      return ChoiceChip(
                        label: Text('${FinancialEngine.formatNumber(val)} بر', style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryEmerald.withOpacity(0.2),
                        onSelected: (selected) {
                          if (selected) {
                            ctrl.text = val.toStringAsFixed(0);
                            setDialogState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(ctrl.text);
                  if (val != null && val > 0) {
                    ref.read(largeThresholdProvider.notifier).updateThreshold(val);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث الحد الفاصل إلى ${FinancialEngine.formatNumber(val)} بر')),
                    );
                  }
                },
                child: const Text('حفظ واعتـماد'),
              ),
            ],
          );
        },
      ),
    );
  }
}
