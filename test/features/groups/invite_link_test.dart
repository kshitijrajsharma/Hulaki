import 'package:fieldchat/features/groups/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const groupId = '642ffd5e-b7bc-416f-8173-cf1c5a428823';
  const key = '861WcfskzdFWFmekCxIdrok869Q+i/Wr+7DRYtxNo4U=';

  group('InviteLink', () {
    test('round-trips through the shareable url', () {
      const invite = InviteLink(groupId: groupId, key: key);
      final parsed = InviteLink.parse(invite.url);
      expect(parsed.groupId, groupId);
      expect(parsed.key, key);
    });

    test('the key rides in the fragment, id in the query', () {
      const invite = InviteLink(groupId: groupId, key: key);
      final uri = Uri.parse(invite.url);
      expect(uri.queryParameters['g'], groupId);
      expect(uri.fragment, key);
      // The secret key must not appear in the part sent to the server.
      expect('${uri.path}?${uri.query}', isNot(contains(key)));
    });

    test('parses the fieldchat:// app-scheme form', () {
      final parsed = InviteLink.parse('fieldchat://join?g=$groupId#$key');
      expect(parsed.groupId, groupId);
      expect(parsed.key, key);
    });

    test('still parses the legacy path form', () {
      final parsed = InviteLink.parse('https://fieldchat.app/g/$groupId#$key');
      expect(parsed.groupId, groupId);
      expect(parsed.key, key);
    });

    test('tryParse returns null for a link with no key fragment', () {
      expect(InviteLink.tryParse('https://example.com/g/$groupId'), isNull);
    });

    test('tryParse returns null for a non-invite url', () {
      expect(InviteLink.tryParse('https://example.com'), isNull);
    });

    test('parse throws on an invalid invite', () {
      expect(
        () => InviteLink.parse('not a url with no fragment'),
        throwsFormatException,
      );
    });
  });
}
