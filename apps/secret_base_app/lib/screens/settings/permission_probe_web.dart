import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `Notification.permission` in the browser: `granted`, `denied`, `default`,
/// or null when the browser has no Notification API.
String? webNotificationPermission() {
  try {
    if (!globalContext.has('Notification')) return null;
    final notification = globalContext['Notification'];
    if (notification == null) return null;
    final value = (notification as JSObject)['permission']?.dartify();
    return value?.toString();
  } catch (_) {
    return null;
  }
}
