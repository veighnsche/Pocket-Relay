import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

import 'host_test_support.dart';

void main() {
  testWidgets(
    'shared host submits the expected payload semantics through the material renderer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ConnectionSettingsSubmitPayload? materialPayload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          availableModelCatalog: codexReferenceModelCatalog(
            connectionId: 'host-submit-test',
          ),
          onSubmit: (payload) {
            materialPayload = payload;
          },
        ),
      );

      await tester.enterText(materialTextField('Profile label'), '  ');
      await tester.enterText(materialTextField('Host'), '  ios.example.com  ');
      await tester.enterText(materialTextField('Port'), '2222');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5.4').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(materialPayload, isNotNull);
      expect(materialPayload!.profile.label, 'Developer Box');
      expect(materialPayload!.profile.host, 'ios.example.com');
      expect(materialPayload!.profile.port, 2222);
      expect(materialPayload!.profile.model, 'gpt-5.4');
      expect(
        materialPayload!.profile.reasoningEffort,
        CodexReasoningEffort.high,
      );
    },
  );

  testWidgets(
    'advanced toggle labels keep tile-level interaction in the material renderer',
    (tester) async {
      ConnectionSettingsSubmitPayload? materialPayload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (payload) {
            materialPayload = payload;
          },
        ),
      );

      await tester.ensureVisible(find.text('Ephemeral turns'));
      await tester.tap(find.text('Ephemeral turns'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(materialPayload, isNotNull);
      expect(materialPayload!.profile.ephemeralSession, isTrue);
    },
  );
}
