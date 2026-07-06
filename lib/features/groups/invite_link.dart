/// A group invite. The group id routes on the server; the key decrypts the
/// content and travels only in the URL fragment, which is never sent to a
/// server in a normal request.
class InviteLink {
  const InviteLink({required this.groupId, required this.key});

  factory InviteLink.parse(String link) {
    final uri = Uri.parse(link);
    if (uri.pathSegments.isEmpty || uri.fragment.isEmpty) {
      throw const FormatException('Not a FieldChat invite link');
    }
    return InviteLink(groupId: uri.pathSegments.last, key: uri.fragment);
  }

  final String groupId;
  final String key;

  String get url => 'https://fieldchat.app/g/$groupId#$key';
}
