/// An authenticated user on this device. The id is a stable per-device
/// identifier; the username is the public handle shown to others in chat.
class Session {
  const Session({required this.userId, required this.username});

  final String userId;
  final String username;
}
