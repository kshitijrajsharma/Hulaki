/// A group invite. The group id routes on the server; the key decrypts the
/// content and travels only in the URL fragment, which is never sent to a
/// server in a normal request.
class InviteLink {
  const InviteLink({required this.groupId, required this.key});

  /// Parses an invite from any of its forms: the shareable https landing link
  /// (group id in the `g` query, key in the fragment), the `fieldchat://`
  /// app-scheme link the landing page redirects to, or the legacy path form.
  factory InviteLink.parse(String link) {
    final invite = tryParse(link);
    if (invite == null) {
      throw const FormatException('Not a FieldChat invite link');
    }
    return invite;
  }

  /// Like [InviteLink.parse] but returns null instead of throwing, for incoming
  /// links that may not be invites at all.
  static InviteLink? tryParse(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final key = uri.fragment;
    if (key.isEmpty) return null;
    final id =
        uri.queryParameters['g'] ??
        (uri.pathSegments.isEmpty ? null : uri.pathSegments.last);
    if (id == null || id.isEmpty) return null;
    return InviteLink(groupId: id, key: key);
  }

  static const _landingBase =
      'https://kshitijrajsharma.github.io/FieldChat/join.html';

  final String groupId;
  final String key;

  /// The shareable link. The key stays in the fragment so it never reaches a
  /// server; only the group id travels in the query.
  String get url => '$_landingBase?g=$groupId#$key';

  /// The direct app-scheme form the landing page redirects into.
  String get appLink => 'fieldchat://join?g=$groupId#$key';
}
