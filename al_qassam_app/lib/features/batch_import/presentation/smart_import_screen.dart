import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/batches_provider.dart';
import '../../financial_engine/domain/models/batch_record.dart';
import '../../parsers/services/outgoing_parser.dart';
import '../../parsers/services/whatsapp_parser.dart';
import '../../reports_export/services/report_formatter.dart';
import '../../settings/providers/settings_provider.dart';
import '../../templates/presentation/templates_screen.dart';

class SmartImportScreen extends ConsumerStatefulWidget {
  final void Function(BatchType type)? onSuccessImport;

  const SmartImportScreen({
    super.key,
    this.onSuccessImport,
  });

  @override
  ConsumerState<SmartImportScreen> createState() => _SmartImportScreenState();
}

class _SmartImportScreenState extends ConsumerState<SmartImportScreen> {
  final TextEditingController _textController = TextEditingController();
  BatchType _selectedType = BatchType.incoming;
  bool _preventDuplicates = true;
  bool _isProcessing = false;
  DateTime? _lastSubmitTime;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اللصق من الحافظة بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحافظة فارغة أو لا تحتوي على نص صريح')),
      );
    }
  }

  Future<void> _processImport({
    bool copyToClipboard = true,
    bool forceSaveDuplicates = false,
  }) async {
    // 1. حاجز زمني وحماية ضد الضغط المزدوج المتسارع (Double-Click Debounce)
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 1500) {
      return;
    }
    _lastSubmitTime = now;

    if (_isProcessing) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة أو لصق نص الكشف أولاً')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final rate = ref.read(exchangeRateProvider);
      final defaultCurrency = ref.read(defaultCurrencyProvider);
      final deduplicate = forceSaveDuplicates ? false : _preventDuplicates;
      // احتراز التحقق من نوع الحوالة لمنع استيراد وارد كصادر أو العكس بالخطأ
      if (_selectedType == BatchType.incoming) {
        final outCheck = OutgoingParser.parseOutgoingText(text: text);
        final inCheck = WhatsAppParser.extractRecords(text: text, exchangeRate: rate);
        if (outCheck.records.isNotEmpty && (inCheck.records.isEmpty || outCheck.records.length > inCheck.records.length)) {
          final proceed = await _showCrossTypeWarningDialog(
            currentType: 'الوارد',
            detectedType: 'حوالات صادر (شبكات صرافة)',
            detectedCount: outCheck.records.length,
          );
          if (!proceed) {
            setState(() => _isProcessing = false);
            return;
          }
        }
      } else {
        final inCheck = WhatsAppParser.extractRecords(text: text, exchangeRate: rate);
        final outCheck = OutgoingParser.parseOutgoingText(text: text);
        if (inCheck.records.isNotEmpty && (outCheck.records.isEmpty || inCheck.records.length > outCheck.records.length)) {
          final proceed = await _showCrossTypeWarningDialog(
            currentType: 'الصادر',
            detectedType: 'حوالات وارد (حسابات بنكية / بر إثيوبي)',
            detectedCount: inCheck.records.length,
          );
          if (!proceed) {
            setState(() => _isProcessing = false);
            return;
          }
        }
      }

      if (_selectedType == BatchType.incoming) {
        final result = await ref.read(batchesProvider.notifier).importIncomingPaste(
          rawText: text,
          exchangeRate: rate,
          defaultCurrency: defaultCurrency,
          deduplicate: deduplicate,
        );

        // فحص احترازي: إذا لم يتم رصد أي حوالة واردة، هل يمثل النص حوالات صادرة وشبكات صرافة؟
        if (result.insertedCount == 0 && result.duplicateCount == 0) {
          final outCheck = OutgoingParser.parseOutgoingText(text: text);
          if (outCheck.records.isNotEmpty) {
            final confirmSwitch = await _showCrossTypeWarningDialog(
              currentType: 'الوارد (لم يُعثر على مطابقات وارد)',
              detectedType: 'حوالات صادر (شبكات صرافة)',
              detectedCount: outCheck.records.length,
            );
            if (confirmSwitch) {
              setState(() => _selectedType = BatchType.outgoing);
              final outResult = await ref.read(batchesProvider.notifier).importOutgoingPaste(
                rawText: text,
                defaultCurrency: defaultCurrency,
                deduplicate: deduplicate,
              );
              if (copyToClipboard && outResult.insertedCount > 0) {
                final copiedText = ReportFormatter.formatOutgoingListMessage(
                  outResult.savedOutgoing,
                );
                await Clipboard.setData(ClipboardData(text: copiedText));
              }
              if (!mounted) return;
              _showResultDialog(
                title: 'اكتمل استيراد كشف الصادر',
                insertedCount: outResult.insertedCount,
                duplicateCount: outResult.duplicateCount,
                duplicates: outResult.duplicateDetails,
                wasCopied: copyToClipboard && outResult.insertedCount > 0,
              );
              return;
            }
          }
        }

        if (copyToClipboard && result.insertedCount > 0) {
          final copiedText = ReportFormatter.formatBirrReport(
            result.savedIncoming,
            includeTotals: false,
          );
          await Clipboard.setData(ClipboardData(text: copiedText));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.insertedCount == 1
                      ? 'تم حفظ الحوالة ونسخ رسالة البر للحافظة بنجاح'
                      : 'تم حفظ (${result.insertedCount}) حوالات ونسخ رسالة البر للحافظة بنجاح',
                ),
                backgroundColor: AppTheme.successGreen,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        if (!mounted) return;
        _showResultDialog(
          title: 'اكتمل استيراد كشف الوارد',
          insertedCount: result.insertedCount,
          duplicateCount: result.duplicateCount,
          duplicates: result.duplicateDetails,
          wasCopied: copyToClipboard && result.insertedCount > 0,
        );
      } else {
        final result = await ref.read(batchesProvider.notifier).importOutgoingPaste(
          rawText: text,
          defaultCurrency: defaultCurrency,
          deduplicate: deduplicate,
        );

        // فحص احترازي: إذا لم يتم رصد أي حوالة صادرة، هل يمثل النص حوالات بر إثيوبي واردة؟
        if (result.insertedCount == 0 && result.duplicateCount == 0) {
          final inCheck = WhatsAppParser.extractRecords(
            text: text,
            exchangeRate: rate,
          );
          if (inCheck.records.isNotEmpty) {
            final confirmSwitch = await _showCrossTypeWarningDialog(
              currentType: 'الصادر (لم يُعثر على مطابقات صادر)',
              detectedType: 'حوالات وارد (حسابات بنكية / بر إثيوبي)',
              detectedCount: inCheck.records.length,
            );
            if (confirmSwitch) {
              setState(() => _selectedType = BatchType.incoming);
              final inResult = await ref.read(batchesProvider.notifier).importIncomingPaste(
                rawText: text,
                exchangeRate: rate,
                defaultCurrency: defaultCurrency,
                deduplicate: deduplicate,
              );
              if (copyToClipboard && inResult.insertedCount > 0) {
                final copiedText = ReportFormatter.formatBirrReport(
                  inResult.savedIncoming,
                  includeTotals: false,
                );
                await Clipboard.setData(ClipboardData(text: copiedText));
              }
              if (!mounted) return;
              _showResultDialog(
                title: 'اكتمل استيراد كشف الوارد',
                insertedCount: inResult.insertedCount,
                duplicateCount: inResult.duplicateCount,
                duplicates: inResult.duplicateDetails,
                wasCopied: copyToClipboard && inResult.insertedCount > 0,
              );
              return;
            }
          }
        }

        if (copyToClipboard && result.insertedCount > 0) {
          final copiedText = ReportFormatter.formatOutgoingListMessage(
            result.savedOutgoing,
          );
          await Clipboard.setData(ClipboardData(text: copiedText));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.insertedCount == 1
                      ? 'تم حفظ الحوالة ونسخ رسالتها للحافظة بنجاح'
                      : 'تم حفظ (${result.insertedCount}) حوالات ونسخ الكشف للحافظة بنجاح',
                ),
                backgroundColor: AppTheme.successGreen,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        if (!mounted) return;
        _showResultDialog(
          title: 'اكتمل استيراد كشف الصادر',
          insertedCount: result.insertedCount,
          duplicateCount: result.duplicateCount,
          duplicates: result.duplicateDetails,
          wasCopied: copyToClipboard && result.insertedCount > 0,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحليل والاستيراد: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showCrossTypeWarningDialog({
    required String currentType,
    required String detectedType,
    required int detectedCount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 26),
            SizedBox(width: 8),
            Text(
              'تنبيه: اشتباه في نوع الحوالة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'يبدو أن النص المُلصق يمثل $detectedType ($detectedCount سجل)، بينما الخيار المحدد حالياً هو قسم ($currentType).',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
              ),
              child: const Text(
                'لتفادي إضافة حوالة بالخطأ إلى القسم غير المخصص لها، يرجى الاختيار:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'تراجع',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'استمر',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showResultDialog({
    required String title,
    required int insertedCount,
    required int duplicateCount,
    required List<String> duplicates,
    bool wasCopied = false,
  }) {
    final bool isEmptyResult = insertedCount == 0 && duplicateCount == 0;
    final bool isAllDuplicates = insertedCount == 0 && duplicateCount > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              (isEmptyResult || isAllDuplicates)
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: (isEmptyResult || isAllDuplicates)
                  ? AppTheme.accentAmber
                  : AppTheme.successGreen,
            ),
            const SizedBox(width: 8),
            Text(
              isEmptyResult
                  ? 'لم يتم التعرف على أي حوالات'
                  : isAllDuplicates
                      ? 'حوالة مكررة ومسجلة مسبقاً'
                      : title,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEmptyResult) ...[
              Text(
                'لم يتم العثور على أي بيانات مطابقة للحوالات في النص المدخل كـ (${_selectedType == BatchType.incoming ? "كشف وارد" : "كشف صادر"}).',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ملاحظة: إذا كانت هذه الحوالة تخص كشفاً مختلفاً، جرّب التبديل بين خياري (كشف وارد / كشف صادر) بأعلى الشاشة، أو افتح شاشة القوالب لمطابقة الصيغة.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSubLight, height: 1.4),
                ),
              ),
            ] else if (isAllDuplicates) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700, width: 0.8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: AppTheme.accentAmber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم التعرف على القالب بنجاح 100%!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'القالب معتمد ومطابق، ولكن تم استبعاد هذه الحوالة لأنها مسجلة مسبقاً بنفس البيانات (الاسم ورقم الحساب والمبلغ) في قاعدة البيانات لحمايتك من التكرار المالي.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'الحوالة المسجلة مسبقاً:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 100),
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: duplicates
                        .map((d) => Text(
                              '• $d',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'إذا كنت تقصد تكرار نفس الحوالة عمداً، اضغط على زر "حفظ وتكرار استثنائياً" بالأسفل.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSubLight),
              ),
            ] else ...[
              if (wasCopied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.successGreen, width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: 18, color: AppTheme.successGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم نسخ بيانات الحوالات تلقائياً إلى الحافظة جاهزة للمشاركة',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('تم اعتماد وحفظ $insertedCount حوالة جديدة في قاعدة البيانات بنجاح.'),
              const SizedBox(height: 6),
              if (duplicateCount > 0) ...[
                Text(
                  'تم استبعاد $duplicateCount حوالة لمطابقتها مع سجلات سابقة:',
                  style: const TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: duplicates
                          .map((d) => Text(
                                '• $d',
                                style: const TextStyle(fontSize: 11),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ] else ...[
                const Text('لم يتم رصد أي حوالات مكررة في هذا الكشف.'),
              ],
              const SizedBox(height: 10),
              const Text(
                'تم حفظ الحوالات بتأريخ اليوم بنجاح، ويمكنك استعراضها والنسخ منها مباشرة من شاشات الكشوفات.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSubLight),
              ),
            ],
          ],
        ),
        actions: [
          if (isEmptyResult)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً، فهمت'),
            )
          else if (isAllDuplicates) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                _processImport(copyToClipboard: true, forceSaveDuplicates: true);
              },
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('حفظ وتكرار استثنائياً'),
            ),
          ] else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _textController.clear();
                widget.onSuccessImport?.call(_selectedType);
              },
              child: const Text('عرض الكشف المعتمد'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد وتسجيل الحوالات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: 'إدارة وتخصيص القوالب',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemplatesScreen()),
              );
            },
          ),
          TextButton.icon(
            onPressed: () => setState(() => _textController.clear()),
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            label: const Text('مسح'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segmented Control: Incoming vs Outgoing
            SegmentedButton<BatchType>(
              style: SegmentedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: BatchType.incoming,
                  label: const Text('وارد', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.call_received_rounded, size: 18),
                ),
                ButtonSegment(
                  value: BatchType.outgoing,
                  label: const Text('صادر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.call_made_rounded, size: 18),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() => _selectedType = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Paste button row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('إدراج بيانات الحوالات من الحافظة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Multiline Editor for WhatsApp messages
            TextField(
              controller: _textController,
              maxLines: 12,
              minLines: 8,
              decoration: InputDecoration(
                hintText: _selectedType == BatchType.incoming
                    ? 'أدخل أو ألصق رسائل الحوالات الواردة هنا، مثل:\nمحمد أحمد قاسم\n1000123456789\n500 ريال سعودي\n\nأو البيانات المتعددة...'
                    : 'أدخل أو ألصق رسائل الحوالات الصادرة هنا، مثل:\nحوالة شبكة الأكوع\nالمستلم: عبد الله صالح\nالمبلغ: 1000 ريال سعودي\nرقم الحوالة: 789123...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),

            // Deduplication switch
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
              ),
              child: SwitchListTile.adaptive(
                title: const Text(
                  'التحقق التلقائي ومنع التكرار',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'مطابقة البصمة المالية الموحدة مع السجلات السابقة لضمان عدم ازدواجية القيود',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSubLight),
                ),
                value: _preventDuplicates,
                activeTrackColor: AppTheme.primaryEmerald,
                onChanged: (val) => setState(() => _preventDuplicates = val),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Save with Copy (Primary) & Save only (Secondary)
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _processImport(copyToClipboard: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.assignment_turned_in_rounded, size: 20),
              label: Text(
                _isProcessing ? 'جارِ الاعتماد والنسخ...' : 'اعتماد الحوالات والنسخ للحافظة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : () => _processImport(copyToClipboard: false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppTheme.primaryEmerald, width: 1.2),
              ),
              icon: const Icon(Icons.save_rounded, size: 18, color: AppTheme.primaryEmerald),
              label: const Text(
                'حفظ في السجل المحلي فقط',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryEmerald),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
