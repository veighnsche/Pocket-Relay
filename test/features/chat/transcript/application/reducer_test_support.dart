import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
export 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
export 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

ChatComposerDraft imageDraft({
  required String imageUrl,
  required String displayName,
}) {
  return ChatComposerDraft(
    text: 'See [Image #1]',
    textElements: const <ChatComposerTextElement>[
      ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
    ],
    imageAttachments: <ChatComposerImageAttachment>[
      ChatComposerImageAttachment(
        imageUrl: imageUrl,
        displayName: displayName,
        placeholder: '[Image #1]',
      ),
    ],
  );
}
