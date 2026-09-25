import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/avatars.dart';
import '../../data/session_controller.dart';
import '../../i18n/strings.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_image.dart';

/// Whether the typed username can be used.
enum _NameStatus { empty, invalid, checking, available, taken }

/// Four-step sign-up: language, identity, gender, avatar.
///
/// Language comes first so every screen after it — including the rest of this
/// flow — is already in the language the person chose.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _stepCount = 4;

  final _pages = PageController();
  int _page = 0;

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  _NameStatus _nameStatus = _NameStatus.empty;
  List<String> _suggestions = const [];
  Timer? _debounce;

  Gender? _gender;
  int? _avatarId;

  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _pages.dispose();
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  // --- Username availability ----------------------------------------------

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();

    final value = AuthRepository.normalise(raw);
    if (value.isEmpty) {
      setState(() {
        _nameStatus = _NameStatus.empty;
        _suggestions = const [];
      });
      return;
    }
    if (!AuthRepository.usernamePattern.hasMatch(value)) {
      setState(() {
        _nameStatus = _NameStatus.invalid;
        _suggestions = const [];
      });
      return;
    }

    setState(() => _nameStatus = _NameStatus.checking);

    // Debounced so a fast typist does not fire a lookup per keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final session = context.session;
      final free = await session.isUsernameAvailable(value);
      final suggestions = free
          ? const <String>[]
          : await session.suggestUsernames(value);

      if (!mounted || AuthRepository.normalise(_username.text) != value) return;
      setState(() {
        _nameStatus = free ? _NameStatus.available : _NameStatus.taken;
        _suggestions = suggestions;
      });
    });
  }

  // --- Navigation ----------------------------------------------------------

  bool get _canAdvance => switch (_page) {
    0 => true,
    1 =>
      _name.text.trim().isNotEmpty &&
          _nameStatus == _NameStatus.available &&
          _password.text.length >= AuthRepository.minPasswordLength,
    2 => _gender != null,
    3 => _avatarId != null,
    _ => false,
  };

  void _next() {
    if (_page == _stepCount - 1) {
      _create();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).pop();
      return;
    }
    _pages.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _create() async {
    setState(() => _busy = true);

    final result = await context.session.signUp(
      username: _username.text,
      password: _password.text,
      displayName: _name.text,
      gender: _gender!,
      avatarId: _avatarId!,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result is AuthFailure) {
      // The only failure that can survive the per-step checks is someone else
      // taking the name in the meantime.
      setState(() {
        _nameStatus = _NameStatus.taken;
        _page = 1;
      });
      _pages.animateToPage(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    // On success the AuthGate swaps this whole route out for the app.
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _back,
        ),
        title: _StepDots(current: _page, total: _stepCount),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _languageStep(s),
          _identityStep(s),
          _genderStep(s),
          _avatarStep(s),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
        child: FilledButton(
          onPressed: _canAdvance && !_busy ? _next : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(_page == _stepCount - 1 ? s.finish : s.next),
        ),
      ),
    );
  }

  // --- Step 0: language ----------------------------------------------------

  Widget _languageStep(Strings s) {
    return _StepBody(
      title: s.chooseLanguage,
      subtitle: s.chooseLanguageHint,
      children: [
        for (final language in AppLanguage.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _ChoiceCard(
              selected: context.session.language == language,
              // Changing this rebuilds the whole flow in the new language.
              onTap: () =>
                  setState(() => context.session.setLanguage(language)),
              child: Row(
                children: [
                  Text(language.flag, style: const TextStyle(fontSize: 26)),
                  Gap.w16,
                  Text(
                    language.nativeName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Step 1: identity ----------------------------------------------------

  Widget _identityStep(Strings s) {
    return _StepBody(
      title: s.yourDetails,
      subtitle: s.usernameIsPermanent,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.fullName,
            prefixIcon: const Icon(Icons.badge_outlined, size: 19),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Gap.h16,
        TextField(
          controller: _username,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.username,
            helperText: s.usernameHint,
            helperStyle: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(Icons.alternate_email, size: 19),
            suffixIcon: _usernameStatusIcon(),
          ),
          onChanged: _onUsernameChanged,
        ),
        if (_nameStatus != _NameStatus.empty) ...[
          Gap.h8,
          _usernameStatusLine(s),
        ],
        if (_suggestions.isNotEmpty) ...[
          Gap.h12,
          Text(
            s.usernameSuggestions,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Gap.h8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    _username.text = suggestion;
                    _onUsernameChanged(suggestion);
                  },
                  backgroundColor: AppColors.elevated,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
            ],
          ),
        ],
        Gap.h16,
        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: s.password,
            helperText: s.passwordTooShort,
            helperStyle: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                size: 19,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget? _usernameStatusIcon() => switch (_nameStatus) {
    _NameStatus.checking => const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textMuted,
        ),
      ),
    ),
    _NameStatus.available => const Icon(
      Icons.check_circle,
      size: 19,
      color: AppColors.profit,
    ),
    _NameStatus.taken || _NameStatus.invalid => const Icon(
      Icons.cancel,
      size: 19,
      color: AppColors.loss,
    ),
    _NameStatus.empty => null,
  };

  Widget _usernameStatusLine(Strings s) {
    final (text, color) = switch (_nameStatus) {
      _NameStatus.checking => (s.usernameChecking, AppColors.textMuted),
      _NameStatus.available => (s.usernameAvailable, AppColors.profit),
      _NameStatus.taken => (s.usernameTaken, AppColors.loss),
      _NameStatus.invalid => (
        _username.text.trim().length < 3
            ? s.usernameTooShort
            : s.usernameBadChars,
        AppColors.loss,
      ),
      _NameStatus.empty => ('', AppColors.textMuted),
    };

    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  // --- Step 2: gender ------------------------------------------------------

  Widget _genderStep(Strings s) {
    return _StepBody(
      title: s.chooseGender,
      children: [
        for (final gender in Gender.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _ChoiceCard(
              selected: _gender == gender,
              onTap: () => setState(() => _gender = gender),
              child: Row(
                children: [
                  Text(gender.emoji, style: const TextStyle(fontSize: 24)),
                  Gap.w16,
                  Text(
                    gender.label(s.isBangla),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Step 3: avatar ------------------------------------------------------

  Widget _avatarStep(Strings s) {
    return _StepBody(
      title: s.chooseAvatar,
      subtitle: s.chooseAvatarHint,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: Gap.md,
            mainAxisSpacing: Gap.md,
            childAspectRatio: 0.85,
          ),
          itemCount: Avatars.all.length,
          itemBuilder: (context, i) {
            final avatar = Avatars.all[i];
            final selected = _avatarId == avatar.id;

            return GestureDetector(
              onTap: () => setState(() => _avatarId = avatar.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandDim : AppColors.surface,
                  borderRadius: Radii.tile,
                  border: Border.all(
                    color: selected ? AppColors.brand : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: const Duration(milliseconds: 140),
                      child: AvatarImage(avatar.id, size: 52),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      avatar.label(s.isBangla),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Gap.h16,
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: AppColors.brandDim.withValues(alpha: 0.5),
            borderRadius: Radii.tile,
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.savings_outlined,
                size: 17,
                color: AppColors.brand,
              ),
              Gap.w8,
              Expanded(
                child: Text(
                  s.startingBalanceNote,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Progress dots in the app bar.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.brand : AppColors.elevated,
              borderRadius: Radii.pill,
            ),
          ),
      ],
    );
  }
}

/// Title, optional subtitle, then the step's own content.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Not a ListView: these steps hold text fields, and a lazy list disposes
    // whatever scrolls out of the viewport when the keyboard opens — taking
    // the field's connection to the keyboard with it.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          if (subtitle != null) ...[
            Gap.h8,
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          Gap.h24,
          ...children,
        ],
      ),
    );
  }
}

/// Large tappable row used by the language and gender steps.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandDim : AppColors.surface,
          borderRadius: Radii.card,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            if (selected)
              const Icon(Icons.check_circle, size: 21, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}
