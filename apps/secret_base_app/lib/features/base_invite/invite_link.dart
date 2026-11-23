/// 기지 초대장 링크 규약. 링크는 상대의 UserCode를 앱에 전달할 뿐이고,
/// 연결 요청은 사용자가 확인 화면에서 직접 보내야 한다.
const inviteHost = 'secretbase.cloud';
const inviteScheme = 'secretbase';

final _codePattern = RegExp(r'^[A-Za-z0-9]{6}$');

/// `https://secretbase.cloud/i/<code>` 또는 `secretbase://invite/<code>`에서
/// 대문자 6자리 코드를 뽑는다. 그 밖의 주소는 null.
String? parseInviteCode(Uri uri) {
  String? candidate;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (uri.scheme == 'https' && uri.host == inviteHost) {
    if (segments.length == 2 && segments[0] == 'i') candidate = segments[1];
  } else if (uri.scheme == inviteScheme && uri.host == 'invite') {
    if (segments.length == 1) candidate = segments[0];
  }
  if (candidate == null || !_codePattern.hasMatch(candidate)) return null;
  return candidate.toUpperCase();
}

Uri inviteWebLink(String code) => Uri.https(inviteHost, '/i/$code');

/// 시스템 공유 시트에 실리는 문구. 연결이 이미 된 것처럼 말하지 않는다.
String buildInviteShareText({required String nickname, required String code}) {
  final who = nickname.trim().isEmpty ? '누군가' : '$nickname님';
  return '$who이 비밀기지 기지 초대장을 보냈어요 💌\n'
      '링크를 열어 확인하고, 원하면 연결을 시작해 보세요.\n'
      '${inviteWebLink(code)}';
}

enum InviteRoute { none, confirm, discard }

/// 보존된 초대 코드를 지금 어떻게 다룰지 정한다.
/// 로그인·가입 마무리 전에는 코드를 그대로 두고(none), 이미 연결된 사용자는 버린다.
InviteRoute resolveInviteRoute({
  required String? pendingCode,
  required bool loggedIn,
  required bool signupRequired,
  required bool paired,
}) {
  if (pendingCode == null) return InviteRoute.none;
  if (!loggedIn || signupRequired) return InviteRoute.none;
  if (paired) return InviteRoute.discard;
  return InviteRoute.confirm;
}
