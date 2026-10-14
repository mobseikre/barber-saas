import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/auth_errors.dart';
import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_header.dart';
import 'app_logo.dart';
import 'app_text_field.dart';

/// Goes in `MaterialApp.builder`: keeps the app hidden under [ChangePasswordRequiredScreen]
/// while the session carries `must_change_password`.
class PasswordChangeGate extends ConsumerStatefulWidget {
  const PasswordChangeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PasswordChangeGate> createState() => _PasswordChangeGateState();
}

class _PasswordChangeGateState extends ConsumerState<PasswordChangeGate> {
  Route<void>? _backBlocker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBackBlocker(ref.read(mustChangePasswordProvider)));
  }

  @override
  void dispose() {
    _removeBackBlocker();
    super.dispose();
  }

  NavigatorState? _appNavigator() {
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    visit(context as Element);
    return found;
  }

  /// The system back button goes to the app's own navigator, never to the one under the change screen,
  /// so a route there that refuses to pop keeps the hidden app from popping or closing.
  void _syncBackBlocker(bool locked) {
    if (!mounted) return;
    if (!locked) return _removeBackBlocker();
    if (_backBlocker?.isActive ?? false) return;
    final route = _BackBlockerRoute();
    final navigator = _appNavigator();
    if (navigator == null) return;
    _backBlocker = route;
    navigator.push(route);
  }

  void _removeBackBlocker() {
    final route = _backBlocker;
    _backBlocker = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(mustChangePasswordProvider);
    ref.listen(
      mustChangePasswordProvider,
      (_, next) => WidgetsBinding.instance.addPostFrameCallback((_) => _syncBackBlocker(next)),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: TickerMode(
            enabled: !locked,
            child: ExcludeFocus(excluding: locked, child: widget.child),
          ),
        ),
        if (locked)
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const ChangePasswordRequiredScreen()),
            ),
          ),
      ],
    );
  }
}

class _BackBlockerRoute extends PageRoute<void> {
  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      const PopScope(canPop: false, child: SizedBox.shrink());
}

class ChangePasswordRequiredScreen extends ConsumerStatefulWidget {
  const ChangePasswordRequiredScreen({super.key});

  @override
  ConsumerState<ChangePasswordRequiredScreen> createState() => _ChangePasswordRequiredScreenState();
}

class _ChangePasswordRequiredScreenState extends ConsumerState<ChangePasswordRequiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).completePasswordChange(_new.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = authErrorMessage(e);
        });
      }
      return;
    }
    messenger?.showSnackBar(const SnackBar(content: Text('تم حفظ كلمة المرور الجديدة')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const AppHeader(
                title: 'اختر كلمة مرور جديدة',
                subtitle: 'أعادت الإدارة تعيين كلمة مرورك. اختر كلمة مرور خاصة بك للمتابعة.',
                subtitleBelow: true,
                leading: AppLogo(),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PasswordField(
                          controller: _new,
                          label: 'كلمة المرور الجديدة',
                          hint: '${PasswordField.minLength} أحرف على الأقل',
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PasswordField(
                          controller: _confirm,
                          label: 'تأكيد كلمة المرور الجديدة',
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) => v != _new.text ? 'كلمتا المرور غير متطابقتين' : null,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(label: 'حفظ والمتابعة', loading: _saving, onPressed: _submit),
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: TextButton(
                            onPressed: _saving ? null : () => signOut(ref),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
