import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/models/template_rule.dart';
import '../providers/templates_provider.dart';
import '../services/template_matcher.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen>
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
    final templatesState = ref.watch(templatesProvider);
    final incomingList = templatesState.incomingTemplates;
    final outgoingList = templatesState.outgoingTemplates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قوالب الحوالات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'استعادة القوالب الافتراضية',
            onPressed: () => _confirmResetDefaults(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryEmerald,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryEmerald,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.call_received_rounded),
              text: 'قوالب الوارد (${incomingList.length})',
            ),
            Tab(
              icon: const Icon(Icons.call_made_rounded),
              text: 'قوالب الصادر (${outgoingList.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesList(incomingList, TemplateType.incoming),
          _buildTemplatesList(outgoingList, TemplateType.outgoing),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة قالب جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openAddTemplateSheet(
          context,
          initialType: _tabController.index == 0
              ? TemplateType.incoming
              : TemplateType.outgoing,
        ),
      ),
    );
  }

  Widget _buildTemplatesList(List<TemplateRule> list, TemplateType type) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا توجد قوالب ${type.label} مضافة حالياً',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _openAddTemplateSheet(context, initialType: type),
              icon: const Icon(Icons.add),
              label: const Text('إضافة قالب الآن'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final template = list[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(TemplateRule template) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: AppTheme.getCardColor(context),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: template.isEnabled
              ? AppTheme.getBorderColor(context)
              : (isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: template.type == TemplateType.incoming
                        ? AppTheme.primaryEmerald.withOpacity(0.15)
                        : AppTheme.accentAmber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.strategy.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: template.type == TemplateType.incoming
                          ? (isDark ? const Color(0xFF34D399) : AppTheme.primaryEmerald)
                          : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (template.isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.4) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'افتراضي مدمج',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF93C5FD) : Colors.blue.shade700,
                      ),
                    ),
                  ),
                const Spacer(),
                Switch.adaptive(
                  value: template.isEnabled,
                  activeColor: AppTheme.primaryEmerald,
                  onChanged: (val) {
                    ref.read(templatesProvider.notifier).toggleTemplate(template.id, val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextMain(context),
              ),
            ),
            if (template.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                template.description,
                style: TextStyle(fontSize: 12, color: AppTheme.getTextSub(context)),
              ),
            ],
            const SizedBox(height: 10),
            // Preview Sample Text Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.getSubtleBg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code_rounded, size: 14, color: AppTheme.getTextSub(context)),
                      const SizedBox(width: 4),
                      Text(
                        'نموذج الرسالة المتوافقة:',
                        style: TextStyle(fontSize: 11, color: AppTheme.getTextSub(context)),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _testTemplateDialog(template),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'تجربة القالب',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryEmerald,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.sampleText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            if (!template.isBuiltIn) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('حذف القالب', style: TextStyle(fontSize: 12)),
                  onPressed: () => _confirmDeleteTemplate(template),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTemplate(TemplateRule template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف القالب'),
        content: Text('هل أنت متأكد من حذف القالب "${template.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(templatesProvider.notifier).deleteTemplate(template.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف القالب بنجاح')),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة القوالب الافتراضية'),
        content: const Text(
          'سيتم إعادة ضبط جميع القوالب إلى الحالة الافتراضية المدمجة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(templatesProvider.notifier).resetToDefaults();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم استعادة القوالب الافتراضية')),
                );
              }
            },
            child: const Text('تأكيد الاستعادة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _testTemplateDialog(TemplateRule template) {
    final result = TemplateMatcher.testTemplate(template, template.sampleText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('نتائج اختبار: ${template.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: result.isMatch ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.isMatch ? Icons.check_circle : Icons.error,
                      color: result.isMatch ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      result.isMatch ? 'تطابق ناجح بنسبة 100%' : 'تعذر المطابقة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: result.isMatch ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (result.beneficiary != null)
                _resultRow('المستفيد:', result.beneficiary!),
              if (result.account != null)
                _resultRow('رقم الحساب:', result.account!),
              if (result.phone != null)
                _resultRow('رقم الهاتف:', result.phone!),
              if (result.amount != null)
                _resultRow('المبلغ:', '${result.amount} ${result.currency ?? ""}'),
              if (result.network != null)
                _resultRow('الشبكة:', result.network!),
              if (result.fee != null)
                _resultRow('العمولة:', '${result.fee}'),
              if (result.transferNumber != null)
                _resultRow('رقم العملية:', result.transferNumber!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddTemplateSheet(BuildContext context, {required TemplateType initialType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTemplateSheet(initialType: initialType),
    );
  }
}

class _AddTemplateSheet extends ConsumerStatefulWidget {
  final TemplateType initialType;

  const _AddTemplateSheet({required this.initialType});

  @override
  ConsumerState<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends ConsumerState<_AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _sampleController = TextEditingController();
  final _regexController = TextEditingController();

  late TemplateType _selectedType;
  late ExtractionStrategy _selectedStrategy;
  TemplateMatchResult? _testResult;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedStrategy = _selectedType == TemplateType.incoming
        ? ExtractionStrategy.phoneIncluded
        : ExtractionStrategy.outgoingNetwork;

    // Set initial sample
    if (_selectedType == TemplateType.incoming) {
      _sampleController.text = 'he mahar atsbaha\n1000832605746\n00251914740800\n400';
    } else {
      _sampleController.text = 'شبكة الأكوع للصرافة\nسند حوالة رقم: 994821\nالمستفيد: صالح محمد أحمد\nالمبلغ: 150000 ريال يمني\nالعمولة: 2500';
    }
    _runTest();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _sampleController.dispose();
    _regexController.dispose();
    super.dispose();
  }

  void _runTest() {
    final tempRule = TemplateRule(
      id: 'temp-test',
      name: _nameController.text.trim(),
      type: _selectedType,
      description: _descController.text.trim(),
      strategy: _selectedStrategy,
      sampleText: _sampleController.text,
      customRegex: _selectedStrategy == ExtractionStrategy.customRegex
          ? _regexController.text.trim()
          : null,
      createdAt: DateTime.now(),
    );

    setState(() {
      _testResult = TemplateMatcher.testTemplate(tempRule, _sampleController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.note_add_rounded, color: AppTheme.primaryEmerald),
                const SizedBox(width: 8),
                const Text(
                  'إضافة قالب مالي جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // نوع القالب (صادر أو وارد)
            const Text('نوع الحوالة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SegmentedButton<TemplateType>(
              segments: const [
                ButtonSegment(
                  value: TemplateType.incoming,
                  label: Text('حوالة واردة (إثيوبيا)'),
                  icon: Icon(Icons.call_received_rounded),
                ),
                ButtonSegment(
                  value: TemplateType.outgoing,
                  label: Text('حوالة صادرة (شبكات)'),
                  icon: Icon(Icons.call_made_rounded),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedType = set.first;
                  _selectedStrategy = _selectedType == TemplateType.incoming
                      ? ExtractionStrategy.phoneIncluded
                      : ExtractionStrategy.outgoingNetwork;
                });
                _runTest();
              },
            ),
            const SizedBox(height: 16),

            // اسم القالب
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم القالب *',
                hintText: 'مثال: قالب شبكة الحظا، أو قالب هاتف إثيوبي مخصص',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'يرجى إدخال اسم القالب' : null,
            ),
            const SizedBox(height: 12),

            // الوصف
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'وصف القالب (اختياري)',
                hintText: 'ملاحظات حول طريقة الاستخراج أو المجموعة',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // استراتيجية الاستخراج
            const Text('نمط / استراتيجية الاستخراج:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<ExtractionStrategy>(
              value: _selectedStrategy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: (_selectedType == TemplateType.incoming
                      ? [
                          ExtractionStrategy.phoneIncluded,
                          ExtractionStrategy.equalSign,
                          ExtractionStrategy.singleLine,
                          ExtractionStrategy.standardOrder,
                          ExtractionStrategy.millionsFormat,
                          ExtractionStrategy.customRegex,
                        ]
                      : [
                          ExtractionStrategy.outgoingNetwork,
                          ExtractionStrategy.customRegex,
                        ])
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStrategy = val);
                  _runTest();
                }
              },
            ),
            const SizedBox(height: 16),

            // في حال تم اختيار Regex مخصص
            if (_selectedStrategy == ExtractionStrategy.customRegex) ...[
              TextFormField(
                controller: _regexController,
                decoration: const InputDecoration(
                  labelText: 'التعبير النمطي (Regex) *',
                  hintText: r'(?<name>[^\n]+)\n(?<account>1000\d+)\n(?<amount>\d+)',
                  prefixIcon: Icon(Icons.code_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _runTest(),
              ),
              const SizedBox(height: 16),
            ],

            // منطقة الاختبار المباشر (Live Sandbox)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المختبر الحي: نص الرسالة التجريبية *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _runTest,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('اختبار الاستخراج'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _sampleController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'الصق نص رسالة حقيقية هنا لاختبار استخراج القالب فورياً...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _runTest(),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'يرجى إدخال نص تجريبي' : null,
            ),
            const SizedBox(height: 12),

            // حاوية نتائج الاختبار الفوري
            if (_testResult != null) _buildLiveTestCard(_testResult!),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saveTemplate,
              child: const Text(
                'حفظ القالب الجديد',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTestCard(TemplateMatchResult res) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: res.isMatch
            ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF7F1D1D).withOpacity(0.3) : const Color(0xFFFEF2F2)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: res.isMatch
              ? (isDark ? const Color(0xFF059669) : Colors.green.shade300)
              : (isDark ? const Color(0xFFDC2626) : Colors.red.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                res.isMatch ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: res.isMatch ? (isDark ? const Color(0xFF34D399) : Colors.green.shade700) : (isDark ? const Color(0xFFF87171) : Colors.red.shade700),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                res.isMatch ? 'الاستخراج المباشر ناجح:' : 'فشل الاستخراج:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: res.isMatch ? (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900) : (isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (res.isMatch) ...[
            if (res.beneficiary != null) _miniBadge('المستفيد', res.beneficiary!),
            if (res.account != null) _miniBadge('الحساب', res.account!),
            if (res.phone != null) _miniBadge('الهاتف', res.phone!),
            if (res.amount != null) _miniBadge('المبلغ', '${res.amount} ${res.currency ?? ""}'),
            if (res.network != null) _miniBadge('الشبكة', res.network!),
            if (res.fee != null) _miniBadge('العمولة', '${res.fee}'),
          ] else
            Text(
              res.errorMessage ?? 'تأكد من صيغة النص أو اختيار النمط الملائم',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.getTextSub(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getTextMain(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    final newRule = TemplateRule(
      id: 'custom-${const Uuid().v4().substring(0, 8)}',
      name: _nameController.text.trim(),
      type: _selectedType,
      description: _descController.text.trim(),
      strategy: _selectedStrategy,
      sampleText: _sampleController.text.trim(),
      customRegex: _selectedStrategy == ExtractionStrategy.customRegex
          ? _regexController.text.trim()
          : null,
      isEnabled: true,
      isBuiltIn: false,
      createdAt: DateTime.now(),
    );

    await ref.read(templatesProvider.notifier).addTemplate(newRule);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة قالب "${newRule.name}" بنجاح!'),
          backgroundColor: AppTheme.primaryEmerald,
        ),
      );
    }
  }
}
