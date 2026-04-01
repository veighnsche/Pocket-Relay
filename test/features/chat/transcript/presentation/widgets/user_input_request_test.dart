import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders user-input fields and submits answers', (tester) async {
    String? submittedRequestId;
    Map<String, List<String>>? submittedAnswers;

    await tester.pumpWidget(
      buildTestApp(
        activeRequestIds: const <String>{'input_1'},
        child: entrySurface(
          block: TranscriptUserInputRequestBlock(
            id: 'input_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'input_1',
            requestType: TranscriptCanonicalRequestType.toolUserInput,
            title: 'Input required',
            body: 'Codex needs clarification.',
            questions: const <TranscriptRuntimeUserInputQuestion>[
              TranscriptRuntimeUserInputQuestion(
                id: 'q1',
                header: 'Project',
                question: 'Which project should I use?',
              ),
            ],
          ),
          onSubmitUserInput: (requestId, answers) async {
            submittedRequestId = requestId;
            submittedAnswers = answers;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Pocket Relay');
    await tester.tap(find.text('Submit response'));
    await tester.pump();

    expect(submittedRequestId, 'input_1');
    expect(submittedAnswers, <String, List<String>>{
      'q1': <String>['Pocket Relay'],
    });
  });

  testWidgets(
    'routes user-input option chips through the shared request draft state',
    (tester) async {
      Map<String, List<String>>? submittedAnswers;

      await tester.pumpWidget(
        buildTestApp(
          activeRequestIds: const <String>{'input_1'},
          child: entrySurface(
            block: TranscriptUserInputRequestBlock(
              id: 'input_1',
              createdAt: DateTime(2026, 3, 14, 12),
              requestId: 'input_1',
              requestType: TranscriptCanonicalRequestType.toolUserInput,
              title: 'Input required',
              body: 'Codex needs clarification.',
              questions: const <TranscriptRuntimeUserInputQuestion>[
                TranscriptRuntimeUserInputQuestion(
                  id: 'q1',
                  header: 'Project',
                  question: 'Which project should I use?',
                  options: <TranscriptRuntimeUserInputOption>[
                    TranscriptRuntimeUserInputOption(
                      label: 'Pocket Relay',
                      description: 'Use the mobile app project.',
                    ),
                  ],
                ),
              ],
            ),
            onSubmitUserInput: (_, answers) async {
              submittedAnswers = answers;
            },
          ),
        ),
      );

      await tester.tap(find.text('Pocket Relay'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Pocket Relay');

      await tester.tap(find.text('Submit response'));
      await tester.pump();

      expect(submittedAnswers, <String, List<String>>{
        'q1': <String>['Pocket Relay'],
      });
    },
  );

  testWidgets('resyncs user-input fields when the backing request changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        activeRequestIds: const <String>{'input_1'},
        child: entrySurface(
          block: TranscriptUserInputRequestBlock(
            id: 'input_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'input_1',
            requestType: TranscriptCanonicalRequestType.toolUserInput,
            title: 'Input required',
            body: 'First request.',
            questions: const <TranscriptRuntimeUserInputQuestion>[
              TranscriptRuntimeUserInputQuestion(
                id: 'q1',
                header: 'Project',
                question: 'Which project should I use?',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Local draft');
    await tester.pump();

    await tester.pumpWidget(
      buildTestApp(
        activeRequestIds: const <String>{'input_2'},
        child: entrySurface(
          block: TranscriptUserInputRequestBlock(
            id: 'input_2',
            createdAt: DateTime(2026, 3, 14, 12, 0, 5),
            requestId: 'input_2',
            requestType: TranscriptCanonicalRequestType.toolUserInput,
            title: 'Input submitted',
            body: 'Second request.',
            isResolved: true,
            questions: const <TranscriptRuntimeUserInputQuestion>[
              TranscriptRuntimeUserInputQuestion(
                id: 'q2',
                header: 'Workspace',
                question: 'Which workspace should I use?',
              ),
            ],
            answers: <String, List<String>>{
              'q2': <String>['/workspace/mobile'],
            },
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Project'), findsNothing);
  });

  testWidgets(
    'routes resolved user-input requests through the result surface',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptUserInputRequestBlock(
              id: 'input_resolved_1',
              createdAt: DateTime(2026, 3, 14, 12),
              requestId: 'input_resolved_1',
              requestType: TranscriptCanonicalRequestType.toolUserInput,
              title: 'Input submitted',
              body: 'Project: Pocket Relay',
              isResolved: true,
              answers: <String, List<String>>{
                'project': <String>['Pocket Relay'],
              },
            ),
          ),
        ),
      );

      expect(find.byType(UserInputResultSurface), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('submitted'), findsOneWidget);
    },
  );

  testWidgets(
    'preserves user-input drafts when a request moves within the transcript surface',
    (tester) async {
      final block = TranscriptUserInputRequestBlock(
        id: 'input_1',
        createdAt: DateTime(2026, 3, 14, 12),
        requestId: 'input_1',
        requestType: TranscriptCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Codex needs clarification.',
        questions: const <TranscriptRuntimeUserInputQuestion>[
          TranscriptRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which project should I use?',
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(mainItems: <TranscriptUiBlock>[block]),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'main',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pocket Relay');
      await tester.pump();

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(pinnedItems: <TranscriptUiBlock>[block]),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'pinned',
          ),
        ),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Pocket Relay');
    },
  );

  testWidgets(
    'does not leak pending-user-input drafts when visibility promotes to the next request',
    (tester) async {
      final firstBlock = TranscriptUserInputRequestBlock(
        id: 'input_1',
        createdAt: DateTime(2026, 3, 14, 12),
        requestId: 'input_1',
        requestType: TranscriptCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'First request',
        questions: const <TranscriptRuntimeUserInputQuestion>[
          TranscriptRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which first project should I use?',
          ),
        ],
      );
      final secondBlock = TranscriptUserInputRequestBlock(
        id: 'input_2',
        createdAt: DateTime(2026, 3, 14, 12, 0, 1),
        requestId: 'input_2',
        requestType: TranscriptCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Second request',
        questions: const <TranscriptRuntimeUserInputQuestion>[
          TranscriptRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which second project should I use?',
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(
              pinnedItems: <TranscriptUiBlock>[firstBlock],
            ),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'first',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pocket Relay');
      await tester.pump();

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(
              pinnedItems: <TranscriptUiBlock>[secondBlock],
            ),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'second',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Which first project should I use?'), findsNothing);
      expect(find.text('Which second project should I use?'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'routes active pending user-input ids through the surface contract',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(
              emptyState: const ChatEmptyStateContract(isConfigured: true),
              activePendingUserInputRequestIds: <String>{'input_explicit'},
            ),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
          ),
        ),
      );

      final scope = tester
          .widgetList<PendingUserInputFormScope>(
            find.byType(PendingUserInputFormScope),
          )
          .last;
      expect(scope.activeRequestIds, <String>{'input_explicit'});
    },
  );
}
