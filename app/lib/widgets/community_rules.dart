import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// A community's rules, numbered. Its admin writes them here; anyone else
/// sees them, and nothing at all when there are none.
class CommunityRulesCard extends StatelessWidget {
  const CommunityRulesCard({
    super.key,
    required this.community,
    required this.isAdmin,
  });

  final Community community;
  final bool isAdmin;

  Future<void> _edit(BuildContext context) async {
    final s = context.s;
    final repo = buildCommunitiesRepository();
    final messenger = ScaffoldMessenger.of(context);
    final rules = await showRulesEditor(context, community.rules);
    if (rules == null || repo == null) return;
    try {
      await repo.setRules(community.id, rules);
      messenger.showSnackBar(SnackBar(content: Text(s.rulesSaved)));
    } catch (e) {
      debugPrint('rules failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final rules = community.rules;
    if (rules.isEmpty && !isAdmin) return const SizedBox.shrink();
    return SectionCard(
      title: s.communityRules,
      trailing: isAdmin
          ? TextButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(s.editRules),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
      child: rules.isEmpty
          ? Text(
              s.noRulesAdmin,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          : RulesList(rules: rules),
    );
  }
}

/// Rules, one numbered line each.
class RulesList extends StatelessWidget {
  const RulesList({super.key, required this.rules});

  final List<String> rules;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, rule) in rules.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${i + 1}.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rule,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Before joining [community]: its rules, to agree to. True to join; true at
/// once when it has none.
Future<bool> agreeToRules(BuildContext context, Community community) async {
  if (community.rules.isEmpty) return true;
  final s = context.s;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: AppColors.elevated,
          title: Text(s.rulesOf(community.name)),
          content: SingleChildScrollView(
            child: RulesList(rules: community.rules),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(s.agreeAndJoin),
            ),
          ],
        ),
      ) ??
      false;
}

/// The admin's sheet for the rules: up to five lines. The lines, or null
/// when closed without saving.
Future<List<String>?> showRulesEditor(
  BuildContext context,
  List<String> rules,
) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => RulesEditor(initial: rules),
);

class RulesEditor extends StatefulWidget {
  const RulesEditor({super.key, required this.initial});

  final List<String> initial;

  @override
  State<RulesEditor> createState() => _RulesEditorState();
}

class _RulesEditorState extends State<RulesEditor> {
  late final List<TextEditingController> _lines = [
    for (final r in widget.initial) TextEditingController(text: r),
    if (widget.initial.isEmpty) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  /// The rules count letters as they are stored, which the box may not.
  bool get _fits =>
      _lines.every((l) => l.text.trim().length <= Community.ruleMax);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.communityRules,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Gap.h8,
              for (final (i, line) in _lines.indexed)
                TextField(
                  key: ObjectKey(line),
                  controller: line,
                  maxLength: Community.ruleMax,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s.ruleLine(i + 1),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () =>
                          setState(() => _lines.removeAt(i).dispose()),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_lines.length < Community.rulesMax)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _lines.add(TextEditingController())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.addRule),
                  ),
                ),
              Gap.h8,
              FilledButton(
                onPressed: _fits
                    ? () => Navigator.of(context).pop([
                        for (final l in _lines)
                          if (l.text.trim().isNotEmpty) l.text.trim(),
                      ])
                    : null,
                child: Text(s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
