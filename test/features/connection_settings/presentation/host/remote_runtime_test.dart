import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';

import 'host_test_support.dart';

void main() {
  testWidgets(
    'shared host probes remote runtime on open and exposes the result through the contract',
    (tester) async {
      final probePayloads = <ConnectionSettingsSubmitPayload>[];
      final remoteRuntimeStates = <ConnectionRemoteRuntimeState?>[];

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshRemoteRuntime: (payload) async {
            probePayloads.add(payload);
            return const ConnectionRemoteRuntimeState(
              hostCapability: ConnectionRemoteHostCapabilityState.supported(
                detail: 'ready',
              ),
              server: ConnectionRemoteServerState.unknown(),
            );
          },
          builder: (context, viewModel, actions) {
            remoteRuntimeStates.add(viewModel.contract.remoteRuntime);
            return const SizedBox();
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(probePayloads, hasLength(1));
      expect(probePayloads.single.profile.host, 'devbox.local');
      expect(probePayloads.single.profile.workspaceDir, '/workspace');
      expect(remoteRuntimeStates.last, isNotNull);
      expect(
        remoteRuntimeStates.last!.hostCapability.status,
        ConnectionRemoteHostCapabilityStatus.supported,
      );
    },
  );

  testWidgets(
    'shared host records probe failures separately from unsupported capability results',
    (tester) async {
      final remoteRuntimeStates = <ConnectionRemoteRuntimeState?>[];

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshRemoteRuntime: (payload) async {
            throw StateError('ssh failed');
          },
          builder: (context, viewModel, actions) {
            remoteRuntimeStates.add(viewModel.contract.remoteRuntime);
            return const SizedBox();
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(remoteRuntimeStates.last, isNotNull);
      expect(
        remoteRuntimeStates.last!.hostCapability.status,
        ConnectionRemoteHostCapabilityStatus.probeFailed,
      );
      expect(
        remoteRuntimeStates.last!.hostCapability.detail,
        contains(
          '[${PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed.code}]',
        ),
      );
      expect(
        remoteRuntimeStates.last!.hostCapability.detail,
        contains('ssh failed'),
      );
    },
  );

  testWidgets(
    'shared host pauses remote runtime probes while authentication settings are dirty',
    (tester) async {
      final probePayloads = <ConnectionSettingsSubmitPayload>[];
      final remoteRuntimeStates = <ConnectionRemoteRuntimeState?>[];

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshRemoteRuntime: (payload) async {
            probePayloads.add(payload);
            return const ConnectionRemoteRuntimeState(
              hostCapability: ConnectionRemoteHostCapabilityState.supported(
                detail: 'ready',
              ),
              server: ConnectionRemoteServerState.unknown(),
            );
          },
          builder: (context, viewModel, actions) {
            remoteRuntimeStates.add(viewModel.contract.remoteRuntime);
            return ConnectionSheet(
              platformBehavior: mobileSettingsBehavior,
              viewModel: viewModel,
              actions: actions,
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(probePayloads, hasLength(1));
      expect(
        remoteRuntimeStates.last,
        const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(
            detail: 'ready',
          ),
          server: ConnectionRemoteServerState.unknown(),
        ),
      );

      await tester.enterText(materialTextField('Password'), 'updated-secret');
      await tester.pump();

      expect(probePayloads, hasLength(1));
      expect(remoteRuntimeStates.last, pausedRemoteRuntimeForTest);
      expect(find.text('System status unknown'), findsOneWidget);
      expect(
        find.text(
          'Pocket Relay pauses remote checks while you edit authentication settings.',
        ),
        findsOneWidget,
      );

      await tester.enterText(materialTextField('Host'), 'otherbox.local');
      await tester.pump(const Duration(milliseconds: 400));

      expect(probePayloads, hasLength(1));
      expect(remoteRuntimeStates.last, pausedRemoteRuntimeForTest);
    },
  );

  testWidgets(
    'shared host ignores stale probe results after authentication changes pause refresh',
    (tester) async {
      final remoteRuntimeStates = <ConnectionRemoteRuntimeState?>[];
      final pendingProbe = Completer<ConnectionRemoteRuntimeState>();

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshRemoteRuntime: (_) => pendingProbe.future,
          builder: (context, viewModel, actions) {
            remoteRuntimeStates.add(viewModel.contract.remoteRuntime);
            return ConnectionSheet(
              platformBehavior: mobileSettingsBehavior,
              viewModel: viewModel,
              actions: actions,
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(materialTextField('Password'), 'updated-secret');
      await tester.pump();

      expect(remoteRuntimeStates.last, pausedRemoteRuntimeForTest);

      pendingProbe.complete(
        const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(
            detail: 'ready',
          ),
          server: ConnectionRemoteServerState.unknown(),
        ),
      );
      await tester.pump();

      expect(remoteRuntimeStates.last, pausedRemoteRuntimeForTest);
      expect(
        find.text(
          'Pocket Relay pauses remote checks while you edit authentication settings.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shared host ignores stale system test results after the system changes',
    (tester) async {
      final pendingSystemTest = Completer<ConnectionSettingsSystemTestResult>();

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialProfile: configuredConnectionProfile().copyWith(
            hostFingerprint: '',
          ),
          onTestSystem: (_, _) => pendingSystemTest.future,
          builder: (context, viewModel, actions) {
            return ConnectionSheet(
              platformBehavior: mobileSettingsBehavior,
              viewModel: viewModel,
              actions: actions,
            );
          },
        ),
      );
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.pump();

      await tester.enterText(materialTextField('Host'), 'otherbox.local');
      await tester.pump();

      pendingSystemTest.complete(
        const ConnectionSettingsSystemTestResult(
          keyType: 'ssh-ed25519',
          fingerprint: '11:22:33:44',
        ),
      );
      await tester.pump();

      final hostField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      );
      expect(hostField.controller!.text, 'otherbox.local');
      expect(find.text('11:22:33:44'), findsNothing);
      expect(find.text('SSH fingerprint needed'), findsOneWidget);
    },
  );

  testWidgets(
    'shared host exposes an initial remote runtime when no refresh callback is provided',
    (tester) async {
      final remoteRuntimeStates = <ConnectionRemoteRuntimeState?>[];

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialRemoteRuntime: const ConnectionRemoteRuntimeState(
            hostCapability: ConnectionRemoteHostCapabilityState.supported(
              detail: 'ready',
            ),
            server: ConnectionRemoteServerState.running(
              ownerId: 'conn_primary',
              sessionName: 'pocket-relay-conn_primary',
              port: 4100,
            ),
          ),
          builder: (context, viewModel, actions) {
            remoteRuntimeStates.add(viewModel.contract.remoteRuntime);
            return const SizedBox();
          },
        ),
      );
      await tester.pump();

      expect(remoteRuntimeStates.last, isNotNull);
      expect(
        remoteRuntimeStates.last!.server.status,
        ConnectionRemoteServerStatus.running,
      );
    },
  );
}
