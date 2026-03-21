import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_draft.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_presenter.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/user_input_request_card.dart';

class PendingUserInputRequestHost extends StatefulWidget {
  const PendingUserInputRequestHost({
    super.key,
    required this.request,
    this.onSubmit,
  });

  final ChatUserInputRequestContract request;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmit;

  @override
  State<PendingUserInputRequestHost> createState() =>
      _PendingUserInputRequestHostState();
}

class _PendingUserInputRequestHostState
    extends State<PendingUserInputRequestHost> {
  final _presenter = const PendingUserInputPresenter();

  @override
  Widget build(BuildContext context) {
    final scope = PendingUserInputFormScope.of(context);
    final formState = scope.stateFor(widget.request);
    final contract = _presenter.present(
      request: widget.request,
      formState: formState,
    );

    return UserInputRequestCard(
      contract: contract,
      onFieldChanged: widget.request.isResolved ? null : _handleFieldChanged,
      onSubmit: widget.onSubmit == null ? null : _handleSubmit,
    );
  }

  void _handleFieldChanged(String fieldId, String value) {
    final scope = PendingUserInputFormScope.of(context);
    scope.updateField(widget.request, fieldId, value);
    setState(() {});
  }

  Future<void> _handleSubmit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      return;
    }

    final scope = PendingUserInputFormScope.of(context);
    final contract = _presenter.present(
      request: widget.request,
      formState: scope.stateFor(widget.request),
    );
    if (contract.isSubmitEnabled == false) {
      return;
    }

    scope.setSubmissionState(
      widget.request,
      PendingUserInputSubmissionState.submitting,
    );
    setState(() {});

    try {
      await onSubmit(widget.request.requestId, contract.submitPayload);
    } finally {
      if (mounted) {
        scope.setSubmissionState(
          widget.request,
          PendingUserInputSubmissionState.idle,
          createIfMissing: false,
        );
        setState(() {});
      }
    }
  }
}
