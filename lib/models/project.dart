class Project {
  final String name;
  final String html;
  final String css;
  final String js;

  const Project({
    required this.name,
    required this.html,
    required this.css,
    required this.js,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'html': html,
      'css': css,
      'js': js,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] ?? 'Untitled',
      html: json['html'] ?? '',
      css: json['css'] ?? '',
      js: json['js'] ?? '',
    );
  }
}
