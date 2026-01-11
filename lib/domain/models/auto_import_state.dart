import 'package:spend_mate/domain/models/auto_import_draft.dart';

class AutoImportState {
  const AutoImportState({
    required this.enabled,
    required this.folderPaths,
    required this.assetAccountByFolder,
    required this.drafts,
    required this.processedFiles,
    required this.lastScanAt,
  });

  final bool enabled;
  final List<String> folderPaths;
  final Map<String, String> assetAccountByFolder;
  final List<AutoImportDraft> drafts;
  final List<String> processedFiles;
  final DateTime? lastScanAt;

  factory AutoImportState.empty() {
    return const AutoImportState(
      enabled: false,
      folderPaths: [],
      assetAccountByFolder: {},
      drafts: [],
      processedFiles: [],
      lastScanAt: null,
    );
  }

  AutoImportState copyWith({
    bool? enabled,
    List<String>? folderPaths,
    Map<String, String>? assetAccountByFolder,
    List<AutoImportDraft>? drafts,
    List<String>? processedFiles,
    DateTime? lastScanAt,
  }) {
    return AutoImportState(
      enabled: enabled ?? this.enabled,
      folderPaths: folderPaths ?? this.folderPaths,
      assetAccountByFolder: assetAccountByFolder ?? this.assetAccountByFolder,
      drafts: drafts ?? this.drafts,
      processedFiles: processedFiles ?? this.processedFiles,
      lastScanAt: lastScanAt ?? this.lastScanAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'folderPaths': folderPaths,
      'folderPath': folderPaths.isEmpty ? null : folderPaths.first,
      'assetAccountByFolder': assetAccountByFolder,
      'drafts': drafts.map((d) => d.toJson()).toList(),
      'processedFiles': processedFiles,
      'lastScanAt': lastScanAt?.toIso8601String(),
    };
  }

  factory AutoImportState.fromJson(Map<String, dynamic> json) {
    final parsedFolders = _parseStringList(json['folderPaths']);
    final legacyFolder = json['folderPath']?.toString();
    final folderPaths = parsedFolders.isNotEmpty
        ? parsedFolders
        : (legacyFolder == null || legacyFolder.trim().isEmpty)
            ? const <String>[]
            : <String>[legacyFolder];
    return AutoImportState(
      enabled: json['enabled'] == true,
      folderPaths: folderPaths,
      assetAccountByFolder: _parseStringMap(json['assetAccountByFolder']),
      drafts: _parseDrafts(json['drafts']),
      processedFiles: _parseStringList(json['processedFiles']),
      lastScanAt: DateTime.tryParse(json['lastScanAt']?.toString() ?? ''),
    );
  }
}

List<AutoImportDraft> _parseDrafts(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(AutoImportDraft.fromJson)
      .toList();
}

List<String> _parseStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

Map<String, String> _parseStringMap(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  for (final entry in value.entries) {
    final rawKey = entry.key;
    if (rawKey == null) continue;
    final key = rawKey.toString();
    if (key.isEmpty) continue;
    final rawValue = entry.value;
    if (rawValue == null) continue;
    final valueText = rawValue.toString().trim();
    if (valueText.isEmpty) continue;
    result[key] = valueText;
  }
  return result;
}
