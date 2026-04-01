import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders approval request actions', (tester) async {
    String? approvedRequestId;

    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptApprovalRequestBlock(
            id: 'request_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'request_1',
            requestType: TranscriptCanonicalRequestType.fileChangeApproval,
            title: 'File change approval',
            body: 'Allow Codex to write files.',
          ),
          onApproveRequest: (requestId) async {
            approvedRequestId = requestId;
          },
          onDenyRequest: (_) async {},
        ),
      ),
    );

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pump();

    expect(approvedRequestId, 'request_1');
  });

  testWidgets('routes resolved approvals through the decision surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptApprovalRequestBlock(
            id: 'request_resolved_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'request_resolved_1',
            requestType: TranscriptCanonicalRequestType.fileChangeApproval,
            title: 'File change approval resolved',
            body: 'Codex received approval for this request.',
            isResolved: true,
            resolutionLabel: 'approved',
          ),
        ),
      ),
    );

    expect(find.byType(ApprovalDecisionSurface), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('approved'), findsOneWidget);
  });

  testWidgets(
    'renders the unpinned host key SSH surface with save and settings actions',
    (tester) async {
      String? savedBlockId;
      var openedSettings = 0;

      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptSshUnpinnedHostKeyBlock(
              id: 'ssh_unpinned_1',
              createdAt: DateTime(2026, 3, 14, 12),
              host: 'example.com',
              port: 22,
              keyType: 'ssh-ed25519',
              fingerprint: 'aa:bb:cc:dd',
            ),
            onSaveHostFingerprint: (blockId) async {
              savedBlockId = blockId;
            },
            onConfigure: () {
              openedSettings += 1;
            },
          ),
        ),
      );

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.textContaining(
          'Pocket Relay does not have a pinned fingerprint for example.com:22 yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('save_host_fingerprint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('host_fingerprint_value')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save_host_fingerprint')));
      await tester.pump();

      expect(openedSettings, 1);
      expect(savedBlockId, 'ssh_unpinned_1');
    },
  );

  testWidgets('renders the connect failure SSH surface with settings only', (
    tester,
  ) async {
    var openedSettings = 0;

    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptSshConnectFailedBlock(
            id: 'ssh_connect_1',
            createdAt: DateTime(2026, 3, 14, 12),
            host: 'example.com',
            port: 22,
            message: 'Connection refused',
          ),
          onConfigure: () {
            openedSettings += 1;
          },
        ),
      ),
    );

    expect(find.text('SSH connection failed'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
    await tester.pump();

    expect(openedSettings, 1);
  });

  testWidgets(
    'renders the host key mismatch SSH surface without save affordances',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptSshHostKeyMismatchBlock(
              id: 'ssh_mismatch_1',
              createdAt: DateTime(2026, 3, 14, 12),
              host: 'example.com',
              port: 22,
              keyType: 'ssh-ed25519',
              expectedFingerprint: 'aa:bb:cc:dd',
              actualFingerprint: '11:22:33:44',
            ),
            onConfigure: () {},
          ),
        ),
      );

      expect(find.text('SSH host key mismatch'), findsOneWidget);
      expect(
        find.textContaining(
          'The pinned fingerprint for example.com:22 does not match the key presented by this server.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expected_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('observed_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders the auth failure SSH surface with settings only', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptSshAuthenticationFailedBlock(
            id: 'ssh_auth_1',
            createdAt: DateTime(2026, 3, 14, 12),
            host: 'example.com',
            port: 22,
            username: 'vince',
            authMode: AuthMode.privateKey,
            message: 'Permission denied',
          ),
          onConfigure: () {},
        ),
      ),
    );

    expect(find.text('SSH authentication failed'), findsOneWidget);
    expect(find.textContaining('private key'), findsWidgets);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
    expect(
      find.byKey(const ValueKey('open_connection_settings')),
      findsOneWidget,
    );
  });
}
