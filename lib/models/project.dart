import 'dart:convert';

class ProjectAsset {
  final String path;
  final String mimeType;
  final String base64Data;

  const ProjectAsset({
    required this.path,
    required this.mimeType,
    required this.base64Data,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'mimeType': mimeType,
      'base64Data': base64Data,
    };
  }

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    return ProjectAsset(
      path: json['path']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      base64Data: json['base64Data']?.toString() ?? '',
    );
  }
}

class Project {
  final String name;
  final String html;
  final String css;
  final String js;
  final Map<String, String> files;
  final List<String> folders;
  final Map<String, ProjectAsset> assets;

  const Project({
    required this.name,
    required this.html,
    required this.css,
    required this.js,
    this.files = const {},
    this.folders = const [],
    this.assets = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'html': html,
      'css': css,
      'js': js,
      'files': files,
      'folders': folders,
      'assets': assets.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final oldFiles = <String, String>{};

    final rawFiles = json['files'];

    if (rawFiles is Map) {
      rawFiles.forEach((key, value) {
        oldFiles[key.toString()] = value?.toString() ?? '';
      });
    }

    if (oldFiles.isEmpty) {
      oldFiles['index.html'] =
          json['html']?.toString() ?? '';
      oldFiles['style.css'] =
          json['css']?.toString() ?? '';
      oldFiles['game.js'] =
          json['js']?.toString() ?? '';
    }

    final parsedFolders = <String>[];

    final rawFolders = json['folders'];

    if (rawFolders is List) {
      for (final folder in rawFolders) {
        final value = folder.toString().trim();

        if (value.isNotEmpty) {
          parsedFolders.add(value);
        }
      }
    }

    final parsedAssets = <String, ProjectAsset>{};

    final rawAssets = json['assets'];

    if (rawAssets is Map) {
      rawAssets.forEach((key, value) {
        if (value is Map) {
          final asset = ProjectAsset.fromJson(
            Map<String, dynamic>.from(value),
          );

          if (asset.path.isNotEmpty) {
            parsedAssets[key.toString()] = asset;
          }
        }
      });
    }

    return Project(
      name: json['name']?.toString() ?? 'Untitled',
      html: json['html']?.toString() ?? oldFiles['index.html'] ?? '',
      css: json['css']?.toString() ?? oldFiles['style.css'] ?? '',
      js: json['js']?.toString() ?? oldFiles['game.js'] ?? '',
      files: oldFiles,
      folders: parsedFolders,
      assets: parsedAssets,
    );
  }

  Project copyWith({
    String? name,
    String? html,
    String? css,
    String? js,
    Map<String, String>? files,
    List<String>? folders,
    Map<String, ProjectAsset>? assets,
  }) {
    return Project(
      name: name ?? this.name,
      html: html ?? this.html,
      css: css ?? this.css,
      js: js ?? this.js,
      files: files ?? this.files,
      folders: folders ?? this.folders,
      assets: assets ?? this.assets,
    );
  }

  String encode() {
    return jsonEncode(toJson());
  }
}
