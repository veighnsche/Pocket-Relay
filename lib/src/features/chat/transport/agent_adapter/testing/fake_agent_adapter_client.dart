import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

/// Generic test entrypoint for the current agent-adapter fake.
///
/// The implementation still reuses the Codex app-server fake underneath, but
/// shared test harnesses can depend on this app-owned name instead of reaching
/// into the Codex transport package directly.
class FakeAgentAdapterClient extends FakeCodexAppServerClient {}
