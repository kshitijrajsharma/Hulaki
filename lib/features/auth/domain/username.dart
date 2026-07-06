/// Returns a user-facing error for [username], or null when it is valid.
/// Rules: 3 to 20 characters, starts with a letter, then lowercase letters,
/// digits, or underscores.
String? usernameError(String username) {
  if (username.length < 3) return 'Use at least 3 characters.';
  if (username.length > 20) return 'Keep it under 20 characters.';
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(username)) {
    return 'Lowercase letters, digits, and underscores. Start with a letter.';
  }
  return null;
}
