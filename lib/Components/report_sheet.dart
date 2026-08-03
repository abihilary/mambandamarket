import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// A report reason: [code] goes to the API, [label] resolves the display text.
class _Reason {
  final String code;
  final String Function(AppLocalizations) label;
  const _Reason(this.code, this.label);
}

const List<_Reason> _reasons = [
  _Reason('spam', _spam),
  _Reason('prohibited', _prohibited),
  _Reason('offensive', _offensive),
  _Reason('counterfeit', _counterfeit),
  _Reason('other', _other),
];

String _spam(AppLocalizations l) => l.reportReasonSpam;
String _prohibited(AppLocalizations l) => l.reportReasonProhibited;
String _offensive(AppLocalizations l) => l.reportReasonOffensive;
String _counterfeit(AppLocalizations l) => l.reportReasonCounterfeit;
String _other(AppLocalizations l) => l.reportReasonOther;

/// Opens the report sheet for [targetType] (`user` | `store` | `listing`).
/// [title] is the already-localized header (e.g. "Report seller").
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String title,
}) {
  // Reporting is a write; anonymous users can't (the API would 401 anyway).
  if (AuthService.instance.session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.reportSignInRequired)),
    );
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      title: title,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String title;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reasonCode;
  final _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_reasonCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportSelectReason)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReportsRepository.instance.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reasonCode!,
        detail: _detailController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reportSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isUnauthorized ? l10n.reportSignInRequired : l10n.reportError),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reportError),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      // Lift above the keyboard when the details field is focused.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.reportReasonLabel,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reasons)
                ChoiceChip(
                  label: Text(r.label(l10n)),
                  selected: _reasonCode == r.code,
                  onSelected: (_) => setState(() => _reasonCode = r.code),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailController,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: l10n.reportDetailsLabel,
              hintText: l10n.reportDetailsHint,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary),
                    )
                  : Text(l10n.reportSubmit,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
