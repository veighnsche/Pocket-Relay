enum ChatChangedFileDiffLineKind { meta, hunk, addition, deletion, context }

enum ChatChangedFileOperationKind { created, modified, renamed, deleted }

enum ChatChangedFileDiffReviewSectionKind { hunk, collapsedGap, binaryMessage }

enum ChatChangedFileDiffReviewRowKind { context, addition, deletion }

class ChatChangedFilePresentationContract {
  const ChatChangedFilePresentationContract({
    required this.currentPath,
    required this.fileName,
    this.directoryLabel,
    this.previousPath,
    this.languageLabel,
    this.syntaxLanguage,
    this.isBinary = false,
  });

  factory ChatChangedFilePresentationContract.fromPaths({
    required String path,
    String? movePath,
    bool isBinary = false,
  }) {
    final normalizedPath = _normalizePath(path);
    final normalizedMovePath = _normalizePathOrNull(movePath);
    final hasMovePath =
        normalizedMovePath != null && normalizedMovePath != normalizedPath;
    final currentPath = hasMovePath ? normalizedMovePath : normalizedPath;
    final previousPath = hasMovePath ? normalizedPath : null;
    final syntax = isBinary ? null : _inferChangedFileSyntax(currentPath);

    return ChatChangedFilePresentationContract(
      currentPath: currentPath,
      fileName: _basename(currentPath),
      directoryLabel: _directoryName(currentPath),
      previousPath: previousPath,
      languageLabel: isBinary ? 'Binary' : syntax?.label,
      syntaxLanguage: isBinary ? null : syntax?.highlightLanguage,
      isBinary: isBinary,
    );
  }

  final String currentPath;
  final String fileName;
  final String? directoryLabel;
  final String? previousPath;
  final String? languageLabel;
  final String? syntaxLanguage;
  final bool isBinary;

  bool get isRenamed => previousPath != null && previousPath != currentPath;

  String get displayPathLabel =>
      isRenamed ? '$previousPath -> $currentPath' : currentPath;

  String? get renameSummary => isRenamed ? 'Renamed from $previousPath' : null;
}

class ChatChangedFileStatsContract {
  const ChatChangedFileStatsContract({
    required this.additions,
    required this.deletions,
  });

  final int additions;
  final int deletions;

  bool get hasChanges => additions > 0 || deletions > 0;
}

class ChatChangedFileDiffLineContract {
  const ChatChangedFileDiffLineContract({
    required this.text,
    required this.kind,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final String text;
  final ChatChangedFileDiffLineKind kind;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class ChatChangedFileDiffReviewRowContract {
  const ChatChangedFileDiffReviewRowContract({
    required this.kind,
    required this.content,
    required this.lineToken,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final ChatChangedFileDiffReviewRowKind kind;
  final String content;
  final String lineToken;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class ChatChangedFileDiffReviewSectionContract {
  const ChatChangedFileDiffReviewSectionContract({
    required this.kind,
    this.label,
    this.rows = const <ChatChangedFileDiffReviewRowContract>[],
    this.message,
    this.hiddenLineCount,
  });

  final ChatChangedFileDiffReviewSectionKind kind;
  final String? label;
  final List<ChatChangedFileDiffReviewRowContract> rows;
  final String? message;
  final int? hiddenLineCount;
}

class ChatChangedFileDiffReviewContract {
  const ChatChangedFileDiffReviewContract({
    this.metadataLines = const <String>[],
    this.sections = const <ChatChangedFileDiffReviewSectionContract>[],
  });

  final List<String> metadataLines;
  final List<ChatChangedFileDiffReviewSectionContract> sections;

  bool get hasMetadata => metadataLines.isNotEmpty;
  bool get hasSections => sections.isNotEmpty;
  bool get isEmpty => metadataLines.isEmpty && sections.isEmpty;
}

class ChatChangedFileDiffContract {
  const ChatChangedFileDiffContract({
    required this.id,
    required this.file,
    required this.operationKind,
    required this.operationLabel,
    required this.stats,
    required this.lines,
    this.review = const ChatChangedFileDiffReviewContract(),
    ChatChangedFileDiffReviewContract? previewReview,
    this.statusLabel,
    this.previewLineLimit = 320,
  }) : previewReview = previewReview ?? review;

  final String id;
  final ChatChangedFilePresentationContract file;
  final ChatChangedFileOperationKind operationKind;
  final String operationLabel;
  final ChatChangedFileStatsContract stats;
  final List<ChatChangedFileDiffLineContract> lines;
  final ChatChangedFileDiffReviewContract review;
  final ChatChangedFileDiffReviewContract previewReview;
  final String? statusLabel;
  final int previewLineLimit;

  String get displayPathLabel => file.displayPathLabel;
  String get currentPath => file.currentPath;
  String get fileName => file.fileName;
  String? get directoryLabel => file.directoryLabel;
  String? get previousPath => file.previousPath;
  String? get languageLabel => file.languageLabel;
  String? get syntaxLanguage => file.syntaxLanguage;
  String? get renameSummary => file.renameSummary;
  bool get isBinary => file.isBinary;

  int get lineCount => lines.length;
  bool get hasPreviewLimit => lines.length > previewLineLimit;
}

class ChatChangedFileRowContract {
  const ChatChangedFileRowContract({
    required this.id,
    required this.file,
    required this.operationKind,
    required this.operationLabel,
    required this.stats,
    this.diff,
  });

  final String id;
  final ChatChangedFilePresentationContract file;
  final ChatChangedFileOperationKind operationKind;
  final String operationLabel;
  final ChatChangedFileStatsContract stats;
  final ChatChangedFileDiffContract? diff;

  String get displayPathLabel => file.displayPathLabel;
  String get currentPath => file.currentPath;
  String get fileName => file.fileName;
  String? get directoryLabel => file.directoryLabel;
  String? get previousPath => file.previousPath;
  String? get languageLabel => file.languageLabel;
  String? get syntaxLanguage => file.syntaxLanguage;
  String? get renameSummary => file.renameSummary;
  bool get isBinary => file.isBinary;

  bool get canOpenDiff => diff != null;
}

class _ChangedFileSyntaxDescriptor {
  const _ChangedFileSyntaxDescriptor({
    required this.label,
    required this.highlightLanguage,
  });

  final String label;
  final String highlightLanguage;
}

const Map<String, _ChangedFileSyntaxDescriptor>
_extensionSyntaxMap = <String, _ChangedFileSyntaxDescriptor>{
  '.c': _ChangedFileSyntaxDescriptor(label: 'C', highlightLanguage: 'cpp'),
  '.cc': _ChangedFileSyntaxDescriptor(label: 'C++', highlightLanguage: 'cpp'),
  '.cmake': _ChangedFileSyntaxDescriptor(
    label: 'CMake',
    highlightLanguage: 'cmake',
  ),
  '.cpp': _ChangedFileSyntaxDescriptor(label: 'C++', highlightLanguage: 'cpp'),
  '.cs': _ChangedFileSyntaxDescriptor(label: 'C#', highlightLanguage: 'cs'),
  '.css': _ChangedFileSyntaxDescriptor(label: 'CSS', highlightLanguage: 'css'),
  '.dart': _ChangedFileSyntaxDescriptor(
    label: 'Dart',
    highlightLanguage: 'dart',
  ),
  '.go': _ChangedFileSyntaxDescriptor(label: 'Go', highlightLanguage: 'go'),
  '.gradle': _ChangedFileSyntaxDescriptor(
    label: 'Gradle',
    highlightLanguage: 'gradle',
  ),
  '.groovy': _ChangedFileSyntaxDescriptor(
    label: 'Groovy',
    highlightLanguage: 'groovy',
  ),
  '.h': _ChangedFileSyntaxDescriptor(label: 'C', highlightLanguage: 'cpp'),
  '.hpp': _ChangedFileSyntaxDescriptor(label: 'C++', highlightLanguage: 'cpp'),
  '.html': _ChangedFileSyntaxDescriptor(
    label: 'HTML',
    highlightLanguage: 'xml',
  ),
  '.htm': _ChangedFileSyntaxDescriptor(label: 'HTML', highlightLanguage: 'xml'),
  '.ini': _ChangedFileSyntaxDescriptor(label: 'INI', highlightLanguage: 'ini'),
  '.java': _ChangedFileSyntaxDescriptor(
    label: 'Java',
    highlightLanguage: 'java',
  ),
  '.js': _ChangedFileSyntaxDescriptor(
    label: 'JavaScript',
    highlightLanguage: 'javascript',
  ),
  '.json': _ChangedFileSyntaxDescriptor(
    label: 'JSON',
    highlightLanguage: 'json',
  ),
  '.jsx': _ChangedFileSyntaxDescriptor(
    label: 'JavaScript',
    highlightLanguage: 'javascript',
  ),
  '.kt': _ChangedFileSyntaxDescriptor(
    label: 'Kotlin',
    highlightLanguage: 'kotlin',
  ),
  '.kts': _ChangedFileSyntaxDescriptor(
    label: 'Kotlin',
    highlightLanguage: 'kotlin',
  ),
  '.less': _ChangedFileSyntaxDescriptor(
    label: 'Less',
    highlightLanguage: 'less',
  ),
  '.lua': _ChangedFileSyntaxDescriptor(label: 'Lua', highlightLanguage: 'lua'),
  '.m': _ChangedFileSyntaxDescriptor(
    label: 'Objective-C',
    highlightLanguage: 'objectivec',
  ),
  '.md': _ChangedFileSyntaxDescriptor(
    label: 'Markdown',
    highlightLanguage: 'markdown',
  ),
  '.mm': _ChangedFileSyntaxDescriptor(
    label: 'Objective-C',
    highlightLanguage: 'objectivec',
  ),
  '.php': _ChangedFileSyntaxDescriptor(label: 'PHP', highlightLanguage: 'php'),
  '.plist': _ChangedFileSyntaxDescriptor(
    label: 'XML',
    highlightLanguage: 'xml',
  ),
  '.proto': _ChangedFileSyntaxDescriptor(
    label: 'Protocol Buffer',
    highlightLanguage: 'protobuf',
  ),
  '.py': _ChangedFileSyntaxDescriptor(
    label: 'Python',
    highlightLanguage: 'python',
  ),
  '.rb': _ChangedFileSyntaxDescriptor(label: 'Ruby', highlightLanguage: 'ruby'),
  '.rs': _ChangedFileSyntaxDescriptor(label: 'Rust', highlightLanguage: 'rust'),
  '.scss': _ChangedFileSyntaxDescriptor(
    label: 'SCSS',
    highlightLanguage: 'scss',
  ),
  '.sh': _ChangedFileSyntaxDescriptor(
    label: 'Shell',
    highlightLanguage: 'bash',
  ),
  '.sql': _ChangedFileSyntaxDescriptor(label: 'SQL', highlightLanguage: 'sql'),
  '.swift': _ChangedFileSyntaxDescriptor(
    label: 'Swift',
    highlightLanguage: 'swift',
  ),
  '.toml': _ChangedFileSyntaxDescriptor(
    label: 'TOML',
    highlightLanguage: 'ini',
  ),
  '.ts': _ChangedFileSyntaxDescriptor(
    label: 'TypeScript',
    highlightLanguage: 'typescript',
  ),
  '.tsx': _ChangedFileSyntaxDescriptor(
    label: 'TypeScript',
    highlightLanguage: 'typescript',
  ),
  '.vue': _ChangedFileSyntaxDescriptor(label: 'Vue', highlightLanguage: 'vue'),
  '.xml': _ChangedFileSyntaxDescriptor(label: 'XML', highlightLanguage: 'xml'),
  '.yaml': _ChangedFileSyntaxDescriptor(
    label: 'YAML',
    highlightLanguage: 'yaml',
  ),
  '.yml': _ChangedFileSyntaxDescriptor(
    label: 'YAML',
    highlightLanguage: 'yaml',
  ),
  '.zsh': _ChangedFileSyntaxDescriptor(
    label: 'Shell',
    highlightLanguage: 'bash',
  ),
};

_ChangedFileSyntaxDescriptor? _inferChangedFileSyntax(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return null;
  }

  final lowercasePath = normalizedPath.toLowerCase();
  final basename = _basename(lowercasePath);

  switch (basename) {
    case 'dockerfile':
      return const _ChangedFileSyntaxDescriptor(
        label: 'Dockerfile',
        highlightLanguage: 'dockerfile',
      );
    case 'makefile':
    case 'gnumakefile':
      return const _ChangedFileSyntaxDescriptor(
        label: 'Makefile',
        highlightLanguage: 'makefile',
      );
    case 'cmakelists.txt':
      return const _ChangedFileSyntaxDescriptor(
        label: 'CMake',
        highlightLanguage: 'cmake',
      );
    case 'gemfile':
    case 'podfile':
    case 'rakefile':
    case 'fastfile':
      return const _ChangedFileSyntaxDescriptor(
        label: 'Ruby',
        highlightLanguage: 'ruby',
      );
  }

  final extensionIndex = basename.lastIndexOf('.');
  if (extensionIndex < 0) {
    return null;
  }

  return _extensionSyntaxMap[basename.substring(extensionIndex)];
}

String _normalizePath(String? value) {
  return value?.trim().replaceAll('\\', '/') ?? '';
}

String? _normalizePathOrNull(String? value) {
  final normalized = _normalizePath(value);
  return normalized.isEmpty ? null : normalized;
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? path : segments.last;
}

String? _directoryName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final separatorIndex = normalized.lastIndexOf('/');
  if (separatorIndex <= 0) {
    return null;
  }

  return normalized.substring(0, separatorIndex);
}
