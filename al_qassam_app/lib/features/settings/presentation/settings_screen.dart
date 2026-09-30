import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../financial_engine/domain/services/financial_engine.dart';
import '../../templates/presentation/templates_screen.dart';
import '../../templates/providers/templates_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyRate = ref.watch(buyRateProvider);
    final sellRate = ref.watch(sellRateProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final bureauName = ref.watch(bureauNameProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final templatesState = ref.watch(templatesProvider);
    final isClassificationEnabled = ref.watch(sizeClassificationEnabledProvider);
    final largeThreshold = ref.watch(largeThresholdProvider);
    final fingerprints = LocalStorageService.instance.getAllFingerprints();
    final currentPin = LocalStorageService.instance.getSecurityPin();
    final spread = (buyRate - sellRate).abs();
    final profitPer1000 = spread * 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: General Settings
          _buildSectionHeader('إعدادات الحساب والصرف'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_agenda_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('قوالب التحويلات'),
                  subtitle: Text(
                    '${templatesState.incomingTemplates.length} وارد • ${templatesState.outgoingTemplates.length} صادر',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('اسم المنشأة'),
                  subtitle: Text(bureauName),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editBureauNameDialog(context, ref, bureauName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.arrow_downward_rounded, color: AppTheme.accentAmber),
                  title: const Text('سعر شراء البر'),
                  subtitle: Text('1 ريال = $buyRate بر (التكلفة)'),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editBuyRateDialog(context, ref, buyRate),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.arrow_upward_rounded, color: AppTheme.successGreen),
                  title: const Text('سعر بيع البر'),
                  subtitle: Text('1 ريال = $sellRate بر (سعر الصرف)'),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editSellRateDialog(context, ref, sellRate),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryEmerald.withOpacity(0.08),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph_rounded, size: 16, color: AppTheme.primaryEmerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هامش الربح: ${spread.toStringAsFixed(2)} بر لكل ريال (${FinancialEngine.formatNumber(profitPer1000)} بر لكل 1,000 ريال)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monetization_on_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('العملة الأساسية'),
                  subtitle: Text(currency),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _selectCurrencyDialog(context, ref, currency),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppTheme.primaryEmerald,
                  ),
                  title: const Text('المظهر الداكن'),
                  subtitle: Text(isDark ? 'مفعل' : 'معطل'),
                  value: isDark,
                  activeTrackColor: AppTheme.primaryEmerald,
                  onChanged: (val) => ref.read(isDarkModeProvider.notifier).toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Size Classification (Optional and Customizable)
          _buildSectionHeader('تصنيف الحوالات (صغيرة / كبيرة)'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.tune_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('تفعيل ميزة تصنيف الحوالات'),
                  subtitle: Text(
                    isClassificationEnabled
                        ? 'مفعل (يتم تصنيف الكشف إلى فئتين صغرى وكبرى)'
                        : 'معطل (عرض وتلخيص الحوالات كوحدة واحدة)',
                  ),
                  value: isClassificationEnabled,
                  activeTrackColor: AppTheme.primaryEmerald,
                  onChanged: (val) => ref.read(sizeClassificationEnabledProvider.notifier).setEnabled(val),
                ),
                if (isClassificationEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.price_change_rounded, color: AppTheme.accentAmber),
                    title: const Text('الحد الفاصل للحوالات الكبيرة'),
                    subtitle: Text('${FinancialEngine.formatNumber(largeThreshold)} بر فأكثر'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _editThresholdDialog(context, ref, largeThreshold),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Database & Deduplication Stats
          _buildSectionHeader('البيانات ومنع التكرار'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('بصمات منع التكرار'),
                  subtitle: const Text('فحص آلي لعدم تكرار الحوالات المكررة'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${fingerprints.length} بصمة',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('سجل العمليات المحفوظة'),
                  subtitle: Text(
                    '${LocalStorageService.instance.getAllIncomingRemittances().length} وارد • ${LocalStorageService.instance.getAllOutgoingTransfers().length} صادر',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Security & Access Control
          _buildSectionHeader('الأمان وتسجيل الدخول'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_rounded, color: AppTheme.primaryEmerald),
                  title: const Text('كلمة مرور النظام'),
                  subtitle: const Text('تغيير كلمة المرور لحماية العمليات والسجلات'),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editPinDialog(context, currentPin),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
                  title: const Text('تسجيل الخروج'),
                  subtitle: const Text('قفل الجلسة والعودة لشاشة تسجيل الدخول'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _confirmLogoutDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dangerous Actions
          ElevatedButton.icon(
            onPressed: () => _confirmResetAllData(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('إعادة ضبط ومسح البيانات'),
          ),

          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text(
                  'نظام القسام',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppTheme.surfaceDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'نظام إدارة الحوالات والصرافة • الإصدار 1.0.0',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSubLight),
                ),
                const SizedBox(height: 2),
                const Text(
                  'جميع الحقوق محفوظة',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSubLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSubLight),
      ),
    );
  }

  void _editBureauNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم المنشأة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم المعتمد في التقارير والكشوفات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(bureauNameProvider.notifier).updateName(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _editBuyRateDialog(BuildContext context, WidgetRef ref, double currentRate) {
    final controller = TextEditingController(text: currentRate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل سعر شراء البر'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'سعر التكلفة (مثلاً 50.0)',
            suffixText: 'بر / ريال',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                ref.read(buyRateProvider.notifier).updateBuyRate(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _editSellRateDialog(BuildContext context, WidgetRef ref, double currentRate) {
    final controller = TextEditingController(text: currentRate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل سعر بيع البر'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'سعر الصرف للعميل (مثلاً 48.0)',
            suffixText: 'بر / ريال',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                ref.read(sellRateProvider.notifier).updateSellRate(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _selectCurrencyDialog(BuildContext context, WidgetRef ref, String currentCurrency) {
    final currencies = ['سعودي', 'دولار', 'يمني', 'درهم', 'بر'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اختر العملة الأساسية'),
        children: currencies
            .map(
              (c) => SimpleDialogOption(
                onPressed: () {
                  ref.read(defaultCurrencyProvider.notifier).updateCurrency(c);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontWeight: c == currentCurrency ? FontWeight.bold : FontWeight.normal,
                      color: c == currentCurrency ? AppTheme.primaryEmerald : null,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _confirmDeleteBatch(BuildContext context, WidgetRef ref, String batchId, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ($label) مع جميع سجلاتها وبصماتها؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              ref.read(batchesProvider.notifier).deleteBatch(batchId);
              Navigator.pop(ctx);
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _confirmResetAllData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه مسح جميع البيانات'),
        content: const Text(
          'سيؤدي هذا الإجراء إلى حذف كافة الدفعات والحوالات المحفوظة والبصمات محلياً. هل ترغب في المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalStorageService.instance.clearAll();
              ref.read(batchesProvider.notifier).loadBatches();
            },
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }

  void _editPinDialog(BuildContext context, String currentPin) {
    final ctrl = TextEditingController(text: currentPin);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryEmerald),
            SizedBox(width: 8),
            Text('تعديل الرمز السري'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل الرمز السري الجديد لحماية التطبيق وتسجيل الدخول:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSubLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: const InputDecoration(
                labelText: 'الرمز السري الجديد',
                hintText: 'مثال: 1234',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = ctrl.text.trim();
              if (newPin.isNotEmpty) {
                await LocalStorageService.instance.setSecurityPin(newPin);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث رمز الدخول بنجاح'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ الرمز'),
          ),
        ],
      ),
    );
  }

  void _confirmLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
            SizedBox(width: 8),
            Text('تأكيد تسجيل الخروج'),
          ],
        ),
        content: const Text(
          'هل تريد قفل الجلسة الحالية والعودة إلى شاشة تسجيل الدخول المعتمد؟',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _editThresholdDialog(BuildContext context, WidgetRef ref, double currentThreshold) {
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
                Text('الحد الفاصل للحوالة الكبيرة', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الحوالات التي تبلغ قيمتها هذا الحد أو تتجاوزه ستُصنف كـ "حوالة كبيرة" في الكشوفات والإحصائيات:',
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
