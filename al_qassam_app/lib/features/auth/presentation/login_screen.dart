import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isRegisterMode = false;

  // Login Controllers
  final _usernameController = TextEditingController(text: 'مدير النظام');
  final _pinController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();

  // Registration Controllers
  final _regBureauController = TextEditingController(text: 'نظام القسام للصرافة');
  final _regUsernameController = TextEditingController();
  final _regPinController = TextEditingController();
  final _regConfirmPinController = TextEditingController();
  final _registerFormKey = GlobalKey<FormState>();
  String _regCurrency = 'سعودي';

  bool _obscurePin = true;
  bool _obscureRegPin = true;
  bool _obscureRegConfirmPin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _regBureauController.dispose();
    _regUsernameController.dispose();
    _regPinController.dispose();
    _regConfirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 250));

    final success = await ref.read(authStateProvider.notifier).login(
      _usernameController.text,
      _pinController.text,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      });
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);
    if (!_registerFormKey.currentState!.validate()) return;

    if (_regPinController.text.trim() != _regConfirmPinController.text.trim()) {
      setState(() => _errorMessage = 'كلمة المرور وتأكيدها غير متطابقين');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).register(
        username: _regUsernameController.text.trim(),
        pin: _regPinController.text.trim(),
        bureauName: _regBureauController.text.trim(),
        defaultCurrency: _regCurrency,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(accountsListProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF042F2E)]
                : [const Color(0xFFF8FAFC), const Color(0xFFF0FDF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    AppLogo(
                      size: 90,
                      showText: true,
                      isDarkBackground: isDark,
                    ),
                    const SizedBox(height: 24),

                    // Card Container
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab Segment Selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isRegisterMode = false;
                                      _errorMessage = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isRegisterMode
                                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                        boxShadow: !_isRegisterMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.06),
                                                  blurRadius: 4,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'تسجيل الدخول',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: !_isRegisterMode ? FontWeight.bold : FontWeight.w600,
                                          color: !_isRegisterMode
                                              ? AppTheme.primaryEmerald
                                              : (isDark ? Colors.white60 : Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isRegisterMode = true;
                                      _errorMessage = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isRegisterMode
                                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                        boxShadow: _isRegisterMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.06),
                                                  blurRadius: 4,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'إنشاء حساب مستقل',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: _isRegisterMode ? FontWeight.bold : FontWeight.w600,
                                          color: _isRegisterMode
                                              ? AppTheme.primaryEmerald
                                              : (isDark ? Colors.white60 : Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!_isRegisterMode) ...[
                            // ==================== LOGIN FORM ====================
                            Text(
                              'تسجيل الدخول للنظام',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.surfaceDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'اختر حسابك أو أدخل بيانات الدخول',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSubLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Quick account selector if multiple accounts exist
                            if (accounts.isNotEmpty) ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: accounts.map((acc) {
                                    final isSelected = _usernameController.text.trim() == acc.username;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: ChoiceChip(
                                        label: Text(acc.username),
                                        selected: isSelected,
                                        selectedColor: AppTheme.primaryEmerald.withOpacity(0.18),
                                        onSelected: (_) {
                                          setState(() {
                                            _usernameController.text = acc.username;
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            Form(
                              key: _loginFormKey,
                              child: Column(
                                children: [
                                  // Username
                                  TextFormField(
                                    controller: _usernameController,
                                    textDirection: TextDirection.rtl,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المستخدم',
                                      hintText: 'أدخل اسم المستخدم',
                                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال اسم المستخدم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Password
                                  TextFormField(
                                    controller: _pinController,
                                    obscureText: _obscurePin,
                                    keyboardType: TextInputType.text,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور',
                                      hintText: 'أدخل كلمة المرور',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                      ),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال كلمة المرور';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _handleLogin(),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // ==================== REGISTER FORM ====================
                            Text(
                              'إنشاء حساب مستقل جديد',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.surfaceDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryEmerald.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🔒 ستحصل على قاعدة بيانات معزولة ومستقلة 100% لكشوفاتك وحوالاتك.',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.primaryEmerald, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Form(
                              key: _registerFormKey,
                              child: Column(
                                children: [
                                  // Bureau Name
                                  TextFormField(
                                    controller: _regBureauController,
                                    textDirection: TextDirection.rtl,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المنشأة / الصراف',
                                      hintText: 'مثال: صرافة القسام',
                                      prefixIcon: const Icon(Icons.business_rounded, size: 20),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال اسم المنشأة أو الصراف';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Username
                                  TextFormField(
                                    controller: _regUsernameController,
                                    textDirection: TextDirection.rtl,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المستخدم للولوج',
                                      hintText: 'مثال: ahmed أو qassam1',
                                      prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال اسم المستخدم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Default Currency
                                  DropdownButtonFormField<String>(
                                    value: _regCurrency,
                                    decoration: InputDecoration(
                                      labelText: 'العملة الافتراضية',
                                      prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'سعودي', child: Text('ريال سعودي')),
                                      DropdownMenuItem(value: 'دولار', child: Text('دولار أمريكي')),
                                      DropdownMenuItem(value: 'يمني', child: Text('ريال يمني')),
                                      DropdownMenuItem(value: 'درهم', child: Text('درهم إماراتي')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _regCurrency = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Password
                                  TextFormField(
                                    controller: _regPinController,
                                    obscureText: _obscureRegPin,
                                    keyboardType: TextInputType.text,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور / الرمز السري',
                                      hintText: 'أدخل كلمة المرور',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureRegPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscureRegPin = !_obscureRegPin),
                                      ),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال كلمة المرور';
                                      }
                                      if (val.trim().length < 3) {
                                        return 'كلمة المرور يجب أن لا تقل عن 3 خانات';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Confirm Password
                                  TextFormField(
                                    controller: _regConfirmPinController,
                                    obscureText: _obscureRegConfirmPin,
                                    keyboardType: TextInputType.text,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      labelText: 'تأكيد كلمة المرور',
                                      hintText: 'أعد إدخال كلمة المرور',
                                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureRegConfirmPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscureRegConfirmPin = !_obscureRegConfirmPin),
                                      ),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى تأكيد كلمة المرور';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _handleRegister(),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(fontSize: 12, color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Action Button
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_isRegisterMode ? _handleRegister : _handleLogin),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_isRegisterMode ? Icons.person_add_rounded : Icons.login_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isRegisterMode ? 'إنشاء الحساب وقاعدة البيانات' : 'تسجيل الدخول',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Official footer
                    Center(
                      child: Text(
                        'نظام القسام • لإدارة الحوالات والصرافة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : AppTheme.surfaceDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'الإصدار 1.0.0 • جميع الحقوق محفوظة',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : AppTheme.textSubLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
