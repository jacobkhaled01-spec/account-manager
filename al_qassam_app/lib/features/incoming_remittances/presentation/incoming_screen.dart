import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/models/incoming_remittance.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import '../../reports_export/services/excel_exporter.dart';
import '../../reports_export/services/pdf_exporter.dart';
import '../../reports_export/services/report_formatter.dart';
import '../../settings/providers/settings_provider.dart';

enum IncomingFilter { all, small, large }
enum DateFilterMode { today, customDate, customRange, all }

class IncomingScreen extends ConsumerStatefulWidget {
  const IncomingScreen({super.key});

  @override
  ConsumerState<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends ConsumerState<IncomingScreen> {
  IncomingFilter _currentFilter = IncomingFilter.all;
  DateFilterMode _dateFilterMode = DateFilterMode.today;
  DateTime? _customDate;
  DateTimeRange? _customDateRange;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bureauName = ref.watch(bureauNameProvider);
    ref.watch(batchesProvider);

    List<IncomingRemittance> sourceRemittances;
    String statementTitle;
    String dateSubtitle;

    switch (_dateFilterMode) {
      case DateFilterMode.today:
        final now = DateTime.now();
        sourceRemittances = LocalStorageService.instance.getAllIncomingRemittances(
          fromDate: DateTime(now.year, now.month, now.day),
          toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        statementTitle = 'كشف وارد اليوم (${_formatDate(now)})';
        dateSubtitle = _formatDate(now);
        break;
      case DateFilterMode.customDate:
        final d = _customDate ?? DateTime.now();
        sourceRemittances = LocalStorageService.instance.getAllIncomingRemittances(
          fromDate: DateTime(d.year, d.month, d.day),
          toDate: DateTime(d.year, d.month, d.day, 23, 59, 59),
        );
        statementTitle = 'كشف وارد ليوم (${_formatDate(d)})';
        dateSubtitle = _formatDate(d);
        break;
      case DateFilterMode.customRange:
        final range = _customDateRange;
        if (range != null) {
          sourceRemittances = LocalStorageService.instance.getAllIncomingRemittances(
            fromDate: range.start,
            toDate: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
          );
          statementTitle =
              'كشف وارد من ${_formatDate(range.start)} إلى ${_formatDate(range.end)}';
          dateSubtitle =
              'الفترة من ${_formatDate(range.start)} إلى ${_formatDate(range.end)}';
        } else {
          sourceRemittances = LocalStorageService.instance.getAllIncomingRemittances();
          statementTitle = 'كشف وارد';
          dateSubtitle = _formatDate(DateTime.now());
        }
        break;
      case DateFilterMode.all:
        sourceRemittances = LocalStorageService.instance.getAllIncomingRemittances();
        statementTitle = 'كافة الحوالات الواردة';
        dateSubtitle = 'جميع الفترات والتسجيلات';
        break;
    }

    final effectiveTotals = FinancialEngine.calculateTotals(sourceRemittances);

    final filtered = sourceRemittances.where((r) {
      if (_currentFilter == IncomingFilter.small && r.isLarge) return false;
      if (_currentFilter == IncomingFilter.large && !r.isLarge) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return r.name.toLowerCase().contains(q) || r.account.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          statementTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الكشف',
            onPressed: () {
              setState(() {});
              ref.read(batchesProvider.notifier).loadBatches();
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'نسخ رسالة البر للكشف المعروض',
            onPressed: () => _copyIsolatedBirr(context, filtered, statementTitle),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'excel') {
                try {
                  final filePath = await ExcelExporter.exportIncomingRemittances(
                    batchLabel: statementTitle,
                    remittances: filtered,
                    bureauName: bureauName,
                    dateSubtitle: dateSubtitle,
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
                              'تم تصدير كشف الإكسل',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تم حفظ الكشف بنجاح: $statementTitle'),
                          const SizedBox(height: 8),
                          SelectableText(
                            filePath,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryEmerald,
                            ),
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
              } else if (val == 'pdf') {
                PdfExporter.exportAndPrintIncomingReport(
                  batchLabel: statementTitle,
                  remittances: filtered,
                  bureauName: bureauName,
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'excel', child: Text('تصدير Excel (.xlsx)')),
              PopupMenuItem(value: 'pdf', child: Text('طباعة PDF')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Date Filter Bar ───────────────────────────────────────────
          Container(
            color: AppTheme.getCardColor(context),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تصفية حسب الفترة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextSub(context),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 7),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _dateChip(
                        label: 'اليوم',
                        mode: DateFilterMode.today,
                        icon: Icons.today_rounded,
                      ),
                      const SizedBox(width: 6),
                      _dateChip(
                        label: _customDate != null
                            ? _formatDate(_customDate!)
                            : 'تاريخ محدد',
                        mode: DateFilterMode.customDate,
                        icon: Icons.event_rounded,
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
                              _dateFilterMode = DateFilterMode.customDate;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _dateChip(
                        label: _customDateRange != null
                            ? '${_formatDate(_customDateRange!.start)} – ${_formatDate(_customDateRange!.end)}'
                            : 'نطاق تاريخي',
                        mode: DateFilterMode.customRange,
                        icon: Icons.date_range_rounded,
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
                              _dateFilterMode = DateFilterMode.customRange;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _dateChip(
                        label: 'كافة الحوالات',
                        mode: DateFilterMode.all,
                        icon: Icons.list_alt_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppTheme.getBorderColor(context)),

          // ─── Search + Size Filter ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(fontSize: 14, color: AppTheme.getTextMain(context)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppTheme.primaryEmerald,
                    ),
                    hintText: 'بحث باسم المستفيد أو رقم الحساب...',
                    hintStyle: TextStyle(color: AppTheme.getTextSub(context), fontSize: 13),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'الكل  (${sourceRemittances.length})',
                        IncomingFilter.all,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        'صغيرة < 100K  (${effectiveTotals.smallCount})',
                        IncomingFilter.small,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        'كبيرة ≥ 100K  (${effectiveTotals.largeCount})',
                        IncomingFilter.large,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Summary Strip ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [const Color(0xFF064E3B).withOpacity(0.35), const Color(0xFF134E4A).withOpacity(0.35)]
                      : [const Color(0xFFECFDF5), const Color(0xFFF0FDFA)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF047857)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 340;
                  final totals = FinancialEngine.calculateTotals(filtered);
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final infoWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المعروض: ${filtered.length} حوالة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'إجمالي البر: ${FinancialEngine.formatNumber(totals.totalBirr)} ETB',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  );
                  final btnWidget = ElevatedButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _copyIsolatedBirr(context, filtered, statementTitle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.copy_all_rounded, size: 15),
                    label: const Text('نسخ كشف البر'),
                  );
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [infoWidget, const SizedBox(height: 8), btnWidget],
                    );
                  }
                  return Row(children: [Expanded(child: infoWidget), btnWidget]);
                },
              ),
            ),
          ),

          // ─── List ─────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 60,
                          color: AppTheme.textSubLight.withOpacity(0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sourceRemittances.isEmpty
                              ? 'لا توجد حوالات في هذه الفترة'
                              : 'لا توجد نتائج مطابقة للبحث',
                          style: const TextStyle(
                            color: AppTheme.textSubLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'حاول تغيير التاريخ أو مصطلح البحث',
                          style: TextStyle(
                            color: AppTheme.textSubLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildRemittanceCard(context, filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Date Filter Pill ────────────────────────────────────────────────────
  Widget _dateChip({
    required String label,
    required DateFilterMode mode,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isSelected = _dateFilterMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap ?? (isSelected ? null : () => setState(() => _dateFilterMode = mode)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryEmerald
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryEmerald
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
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
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.getTextMain(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Size Filter Pill ────────────────────────────────────────────────────
  Widget _buildFilterChip(String label, IncomingFilter filter) {
    final isSelected = _currentFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryEmerald.withOpacity(isDark ? 0.25 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryEmerald
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppTheme.primaryLight : AppTheme.primaryEmerald)
                : AppTheme.getTextSub(context),
          ),
        ),
      ),
    );
  }

  // ── Remittance Card (Official Voucher) ──────────────────────────────────
  // ── Remittance Card (Official Voucher) ──────────────────────────────────
  Widget _buildRemittanceCard(BuildContext context, IncomingRemittance item) {
    final isLarge = item.isLarge;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLarge ? const Color(0xFFFCD34D) : AppTheme.getBorderColor(context),
          width: isLarge ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Strip ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLarge
                    ? [const Color(0xFF92400E), const Color(0xFFD97706)]
                    : [AppTheme.primaryEmerald, AppTheme.primaryLight],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '#${item.sequence}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.account_balance_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'سند حوالة وارد • البنك التجاري الإثيوبي',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLarge) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'حوالة كبرى',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Card Body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ①  Beneficiary Name
                Text(
                  'اسم المستفيد',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.getTextSub(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  FinancialEngine.cleanBeneficiaryName(item.name),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.getTextMain(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // ②  Account Number
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                  decoration: BoxDecoration(
                    color: AppTheme.getSubtleBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.getBorderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card_rounded, size: 16, color: AppTheme.getTextSub(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رقم الحساب',
                              style: TextStyle(fontSize: 10, color: AppTheme.getTextSub(context)),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              item.account,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.getTextMain(context),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _inlineCopyBtn(
                        context: context,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: item.account));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ: ${item.account}'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ③  Amount + Rate
                Row(
                  children: [
                    Expanded(
                      child: _infoCell(
                        context: context,
                        label: 'المبلغ المقبوض',
                        value: '${FinancialEngine.formatNumber(item.amount)} ${item.currency}',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoCell(
                        context: context,
                        label: 'سعر الصرف',
                        value: '1 ${item.currency} = ${item.rate} ب',
                        icon: Icons.currency_exchange_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ④  Payout Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B).withOpacity(0.35)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF047857) : const Color(0xFF6EE7B7),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المبلغ المستحق للتسليم',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${FinancialEngine.formatNumber(item.birr)} بر إثيوبي (ETB)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.cutCents > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF78350F).withOpacity(0.35)
                                : const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            'كسر\n${item.cutCents.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ⑤  Action Buttons: Copy, Edit, Delete
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = ReportFormatter.formatSingleBirrMessage(item);
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ سند (${FinancialEngine.cleanBeneficiaryName(item.name)}) إلى الحافظة بنجاح'),
                              backgroundColor: AppTheme.successGreen,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('نسخ السند'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _editRemittanceDialog(context, item),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryEmerald,
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteRemittanceDialog(context, item),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 20),
                      tooltip: 'حذف الحوالة',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared Info Cell ────────────────────────────────────────────────────
  Widget _infoCell({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.getSubtleBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppTheme.getTextSub(context)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.getTextSub(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.getTextMain(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Inline Copy Button ──────────────────────────────────────────────────
  Widget _inlineCopyBtn({required BuildContext context, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.getSubtleBg(context),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppTheme.primaryEmerald),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 13, color: AppTheme.primaryEmerald),
            SizedBox(width: 4),
            Text(
              'نسخ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryEmerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyIsolatedBirr(
      BuildContext context, List<IncomingRemittance> remittances, String batchLabel) {
    if (remittances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حوالات لنسخها في العملية الملصقة')),
      );
      return;
    }

    final formatted = ReportFormatter.formatBirrReport(remittances);
    Clipboard.setData(ClipboardData(text: formatted));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ كشف البر لـ ($batchLabel) حصراً دون خلط مع أي تواريخ أخرى'),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _editRemittanceDialog(BuildContext context, IncomingRemittance item) {
    final nameCtrl = TextEditingController(text: item.name);
    final accountCtrl = TextEditingController(text: item.account);
    final amountCtrl = TextEditingController(text: item.amount.toString());
    final rateCtrl = TextEditingController(text: item.rate.toString());
    final currencyCtrl = TextEditingController(text: item.currency);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final amt = double.tryParse(amountCtrl.text) ?? 0.0;
          final rt = double.tryParse(rateCtrl.text) ?? 0.0;
          final calcBirr = (amt * rt).floorToDouble();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppTheme.primaryEmerald, size: 24),
                SizedBox(width: 8),
                Text('تعديل بيانات الحوالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'اسم المستفيد', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المستفيد' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accountCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'رقم الحساب', prefixIcon: Icon(Icons.credit_card_rounded)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال رقم الحساب' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'المبلغ المقبوض', prefixIcon: Icon(Icons.payments_outlined)),
                            onChanged: (_) => setDlgState(() {}),
                            validator: (v) {
                              final parsed = double.tryParse(v ?? '');
                              return (parsed == null || parsed <= 0) ? 'مبلغ غير صحيح' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: currencyCtrl,
                            decoration: const InputDecoration(labelText: 'العملة'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'سعر الصرف (بر لكل وحدة)', prefixIcon: Icon(Icons.currency_exchange_rounded)),
                      onChanged: (_) => setDlgState(() {}),
                      validator: (v) {
                        final parsed = double.tryParse(v ?? '');
                        return (parsed == null || parsed <= 0) ? 'سعر صرف غير صحيح' : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المقابل بالبر بعد التعديل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          Text('${FinancialEngine.formatNumber(calcBirr.toInt())} بر', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final newAmt = double.parse(amountCtrl.text);
                  final newRt = double.parse(rateCtrl.text);
                  final finalBirr = (newAmt * newRt).floorToDouble();
                  final finalCents = (newAmt * newRt) - finalBirr;

                  final updated = item.copyWith(
                    name: nameCtrl.text.trim(),
                    account: accountCtrl.text.trim(),
                    amount: newAmt,
                    currency: currencyCtrl.text.trim(),
                    rate: newRt,
                    birrEquivalent: finalBirr,
                    cutCents: finalCents,
                  );

                  await ref.read(batchesProvider.notifier).updateIncomingRemittance(updated);
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ تعديلات الحوالة بنجاح'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald, foregroundColor: Colors.white),
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteRemittanceDialog(BuildContext context, IncomingRemittance item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.dangerRed, size: 24),
            SizedBox(width: 8),
            Text('تأكيد حذف الحوالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف حوالة (${item.name}) بمبلغ (${FinancialEngine.formatNumber(item.amount)} ${item.currency}) من السجلات نهائياً؟',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(batchesProvider.notifier).deleteIncomingRemittance(item.id);
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف الحوالة من السجلات بنجاح'),
                  backgroundColor: AppTheme.dangerRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف نهائي', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
