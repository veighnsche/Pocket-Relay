class AgentAdapterCapabilities {
  const AgentAdapterCapabilities({
    this.supportsConversationHistory = false,
    this.supportsConversationRollback = false,
    this.supportsConversationForking = false,
    this.supportsLocalConnections = false,
    this.supportsModelCatalog = false,
    this.supportsModelCatalogRefresh = false,
    this.supportsReasoningEffort = false,
    this.supportsImageInput = false,
    this.supportsApprovals = false,
    this.supportsUserInput = false,
    this.supportsDynamicToolCalls = false,
    this.supportsRemoteConnections = false,
    this.supportsRemoteContinuity = false,
    this.supportsDangerouslyBypassSandbox = false,
    this.supportsEphemeralSessions = false,
  });

  final bool supportsConversationHistory;
  final bool supportsConversationRollback;
  final bool supportsConversationForking;
  final bool supportsLocalConnections;
  final bool supportsModelCatalog;
  final bool supportsModelCatalogRefresh;
  final bool supportsReasoningEffort;
  final bool supportsImageInput;
  final bool supportsApprovals;
  final bool supportsUserInput;
  final bool supportsDynamicToolCalls;
  final bool supportsRemoteConnections;
  final bool supportsRemoteContinuity;
  final bool supportsDangerouslyBypassSandbox;
  final bool supportsEphemeralSessions;
}
