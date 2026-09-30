import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/models/outgoing_transfer.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import '../../reports_export/services/excel_exporter.dart';
import '../../reports_export/services/report_formatter.dart';
import '../../settings/providers/settings_provider.dart';

enum OutgoingDateMode { today, customDate, customRange, all }

class OutgoingScreen extends ConsumerStatefulWidget {
  const OutgoingScreen({super.key});

  @override
  ConsumerState<OutgoingScreen> createState() => _OutgoingScreenState();
}

class _OutgoingScreenState extends ConsumerState<OutgoingScreen> {
  OutgoingDateMode _dateMode = OutgoingDateMode.today;
  DateTime? _customDate;
  DateTimeRange? _customDateRange;
  String _selectedNetwork = 'الكل';
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

    // Source list based on date mode
    List<OutgoingTransfer> sourceTransfers;
    String statementTitle;
    String dateSubtitle;

    switch (_dateMode) {
      case OutgoingDateMode.today:
        final now = DateTime.now();
        sourceTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
          fromDate: DateTime(now.year, now.month, now.day),
          toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        statementTitle = 'كشف صادر اليوم (${_formatDate(now)})';
        dateSubtitle = _formatDate(now);
        break;
      case OutgoingDateMode.customDate:
        final d = _customDate ?? DateTime.now();
        sourceTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
          fromDate: DateTime(d.year, d.month, d.day),
          toDate: DateTime(d.year, d.month, d.day, 23, 59, 59),
        );
        statementTitle = 'كشف صادر ليوم (${_formatDate(d)})';
        dateSubtitle = _formatDate(d);
        break;
      case OutgoingDateMode.customRange:
        final range = _customDateRange;
        if (range != null) {
          sourceTransfers = LocalStorageService.instance.getAllOutgoingTransfers(
            fromDate: range.start,
            toDate: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
          );
          statementTitle = 'كشف صادر من ${_formatDate(range.start)} إلى ${_formatDate(range.end)}';
          dateSubtitle = 'الفترة من ${_formatDate(range.start)} إلى ${_formatDate(range.end)}';
        } else {
          sourceTransfers = LocalStorageService.instance.getAllOutgoingTransfers();
          statementTitle = 'كشف صادر وشبكات';
          dateSubtitle = _formatDate(DateTime.now());
        }
        break;
      case OutgoingDateMode.all:
        sourceTransfers = LocalStorageService.instance.getAllOutgoingTransfers();
        statementTitle = 'كافة الحوالات الصادرة';
        dateSubtitle = 'جميع الفترات والتسجيلات';
        break;
    }

    // Filter by network and search
    final filtered = sourceTransfers.where((t) {
      if (_selectedNetwork != 'الكل' && !t.network.contains(_selectedNetwork)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.recipient.toLowerCase().contains(q) ||
            t.sender.toLowerCase().contains(q) ||
            t.transferNo.toLowerCase().contains(q) ||
            t.network.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Calculate totals by currency
    final Map<String, double> sumByCurrency = {};
    for (final t in filtered) {
      sumByCurrency[t.currency] = (sumByCurrency[t.currency] ?? 0) + t.amount;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(statementTitle),
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
            tooltip: 'نسخ ملخص الصادر',
            onPressed: () {
              if (filtered.isEmpty) return;
              final summary = ReportFormatter.formatOutgoingSummary(filtered);
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ ملخص الصادر إلى الحافظة بنجاح')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'تصدير كشف الصادر Excel',
            onPressed: () => _exportOutgoingExcel(
              context,
              statementTitle,
              filtered,
              bureauName,
              dateSubtitle,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Filter Toolbar (إصدار الكشف حسب التاريخ)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              border: Border(bottom: BorderSide(color: AppTheme.getBorderColor(context))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: AppTheme.accentAmber),
                  const SizedBox(width: 8),
                  _buildOutgoingDatePill(
                    label: 'كشف اليوم',
                    icon: Icons.today_rounded,
                    isSelected: _dateMode == OutgoingDateMode.today,
                    onTap: () => setState(() => _dateMode = OutgoingDateMode.today),
                  ),
                  const SizedBox(width: 6),
                  _buildOutgoingDatePill(
                    label: _customDate != null ? 'يوم: ${_formatDate(_customDate!)}' : 'تاريخ محدد',
                    icon: Icons.event_rounded,
                    isSelected: _dateMode == OutgoingDateMode.customDate,
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
                          _dateMode = OutgoingDateMode.customDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildOutgoingDatePill(
                    label: _customDateRange != null
                        ? '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}'
                        : 'نطاق تاريخي',
                    icon: Icons.date_range_rounded,
                    isSelected: _dateMode == OutgoingDateMode.customRange,
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
                          _dateMode = OutgoingDateMode.customRange;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildOutgoingDatePill(
                    label: 'كافة الحوالات',
                    icon: Icons.list_alt_rounded,
                    isSelected: _dateMode == OutgoingDateMode.all,
                    onTap: () => setState(() => _dateMode = OutgoingDateMode.all),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(color: AppTheme.getTextMain(context)),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.getCardColor(context),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.getTextSub(context)),
                hintText: 'بحث باسم المستلم أو المرسل أو الشبكة...',
                hintStyle: TextStyle(color: AppTheme.getTextSub(context), fontSize: 13),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: AppTheme.getTextSub(context)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Totals strip & collective copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: AppTheme.getBorderColor(context))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'عدد الحوالات: ${filtered.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.getTextMain(context),
                      ),
                    ),
                    Text(
                      sumByCurrency.isEmpty
                          ? 'الإجمالي: 0'
                          : sumByCurrency.entries
                              .map((e) => '${FinancialEngine.formatNumber(e.value)} ${e.key}')
                              .join(' • '),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ],
                );
                final buttonWidget = ElevatedButton.icon(
                  onPressed: filtered.isEmpty
                      ? null
                      : () {
                          final summary = ReportFormatter.formatOutgoingSummary(filtered);
                          Clipboard.setData(ClipboardData(text: summary));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ ملخص كشف الصادر (${filtered.length} حوالة) إلى الحافظة بنجاح'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 15),
                  label: const Text(
                    'نسخ الكشف جماعياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoWidget,
                      const SizedBox(height: 6),
                      buttonWidget,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: infoWidget),
                    buttonWidget,
                  ],
                );
              },
            ),
          ),

          // Transfers list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      sourceTransfers.isEmpty
                          ? 'لا توجد حوالات صادرة في هذا التاريخ أو الكشف المحدد'
                          : 'لا توجد نتائج مطابقة للبحث',
                      style: TextStyle(color: AppTheme.getTextSub(context)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildTransferCard(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingDatePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentAmber : AppTheme.getSubtleBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentAmber : AppTheme.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.getTextSub(context),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.getTextMain(context),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferCard(BuildContext context, OutgoingTransfer item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanedRecipient = FinancialEngine.cleanBeneficiaryName(item.recipient);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Official Voucher Header Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: AppTheme.getBorderColor(context)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: isDark ? Border.all(color: AppTheme.getBorderColor(context)) : null,
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
                  Icon(
                    Icons.hub_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سند حوالة شبكات • ${item.network}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextMain(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Official Voucher Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Beneficiary / Recipient
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryEmerald),
                      const SizedBox(width: 8),
                      Text(
                        'اسم المستلم:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextSub(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          cleanedRecipient,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getTextMain(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sender
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.getTextSub(context)),
                      const SizedBox(width: 8),
                      Text(
                        'اسم المرسل:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSub(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.sender,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextMain(context),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Transfer Number (if available)
                  if (item.transferNo != '-' && item.transferNo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.getSubtleBg(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getBorderColor(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag_rounded, size: 18, color: AppTheme.getTextSub(context)),
                          const SizedBox(width: 8),
                          Text(
                            'رقم الحوالة:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextSub(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              item.transferNo,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppTheme.getTextMain(context),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: item.transferNo));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ رقم الحوالة: ${item.transferNo}'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.getBorderColor(context)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded, size: 13, color: AppTheme.getTextSub(context)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'نسخ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.getTextSub(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Prominent Amount Payout Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F).withOpacity(0.25) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المبلغ الإجمالي للصرف:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${FinancialEngine.formatNumber(item.amount)} ${item.currency}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF78350F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.commission != '-' && item.commission.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFFF59E0B).withOpacity(0.4) : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                'العمولة: ${item.commission}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons: Copy, Edit, Delete
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final text = ReportFormatter.formatSingleOutgoingTransfer(item);
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم نسخ سند حوالة ($cleanedRecipient) إلى الحافظة بنجاح'),
                                backgroundColor: AppTheme.successGreen,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            side: isDark ? BorderSide(color: AppTheme.getBorderColor(context)) : null,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('نسخ سند الحوالة'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _editOutgoingTransferDialog(context, item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryEmerald,
                          side: BorderSide(color: AppTheme.getBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deleteOutgoingTransferDialog(context, item),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 20),
                        tooltip: 'حذف الحوالة الصادرة',
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
      ),
    );
  }

  void _exportOutgoingExcel(
    BuildContext context,
    String title,
    List<OutgoingTransfer> transfers,
    String bureauName,
    String dateSubtitle,
  ) async {
    if (transfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حوالات صادرة لتصديرها')),
      );
      return;
    }

    try {
      final filePath = await ExcelExporter.exportOutgoingTransfers(
        statementTitle: title,
        transfers: transfers,
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
                  'تم تصدير كشف الصادر إكسل',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم حفظ الكشف بنجاح: $title'),
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
  }

  void _editOutgoingTransferDialog(BuildContext context, OutgoingTransfer item) {
    final recipientCtrl = TextEditingController(text: item.recipient);
    final phoneCtrl = TextEditingController(text: item.sender);
    final transferNoCtrl = TextEditingController(text: item.transferNo);
    final networkCtrl = TextEditingController(text: item.network);
    final amountCtrl = TextEditingController(text: item.amount.toString());
    final currencyCtrl = TextEditingController(text: item.currency);
    final commissionCtrl = TextEditingController(text: item.commission);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryEmerald, size: 24),
            SizedBox(width: 8),
            Text('تعديل بيانات الحوالة الصادرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  controller: recipientCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'اسم المستلم', prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المستلم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'المرسل / الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: transferNoCtrl,
                        decoration: const InputDecoration(labelText: 'رقم الحوالة', prefixIcon: Icon(Icons.tag_rounded)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: networkCtrl,
                        decoration: const InputDecoration(labelText: 'شبكة الصرافة', prefixIcon: Icon(Icons.hub_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.payments_outlined)),
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
                  controller: commissionCtrl,
                  decoration: const InputDecoration(labelText: 'العمولة / الأجر', prefixIcon: Icon(Icons.percent_rounded)),
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

              final updated = item.copyWith(
                recipient: recipientCtrl.text.trim(),
                sender: phoneCtrl.text.trim(),
                transferNo: transferNoCtrl.text.trim(),
                network: networkCtrl.text.trim(),
                amount: newAmt,
                currency: currencyCtrl.text.trim(),
                commission: commissionCtrl.text.trim(),
              );

              await ref.read(batchesProvider.notifier).updateOutgoingTransfer(updated);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حفظ تعديلات الحوالة الصادرة بنجاح'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald, foregroundColor: Colors.white),
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  void _deleteOutgoingTransferDialog(BuildContext context, OutgoingTransfer item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.dangerRed, size: 24),
            SizedBox(width: 8),
            Text('تأكيد حذف الحوالة الصادرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف حوالة (${item.recipient}) بمبلغ (${FinancialEngine.formatNumber(item.amount)} ${item.currency}) من السجلات نهائياً؟',
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
              await ref.read(batchesProvider.notifier).deleteOutgoingTransfer(item.id);
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف الحوالة الصادرة من السجلات بنجاح'),
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
