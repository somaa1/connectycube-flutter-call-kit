# ConnectyCube Flutter Call Kit - Complete Usage Guide

**Version 2.11.0+ - Production-Ready with Enhanced Stability**

This comprehensive guide covers the fully improved ConnectyCube Flutter Call Kit package including all critical bug fixes, custom features, performance enhancements, and best practices for production use.

---

## 📋 Table of Contents

1. [What's New in v2.11.0+](#whats-new-in-v2110)
2. [Quick Start Guide](#quick-start-guide)
3. [Installation & Setup](#installation--setup)
4. [Basic Usage](#basic-usage)
5. [Enhanced Custom Features](#enhanced-custom-features)
6. [Advanced Features](#advanced-features)
7. [Permission Management](#permission-management)
8. [Platform-Specific Configuration](#platform-specific-configuration)
9. [Best Practices](#best-practices)
10. [Complete API Reference](#complete-api-reference)
11. [Migration Guide](#migration-guide)
12. [Troubleshooting](#troubleshooting)
13. [Examples & Use Cases](#examples--use-cases)

---

## What's New in v2.11.0+

### 🔴 **Critical Bug Fixes** (TIER 1)

✅ **Memory Leak Fixed** - Dart event stream properly disposed
✅ **ANR (App Not Responding) Fixed** - Android SharedPreferences no longer blocks UI thread
✅ **Handler Memory Leak Fixed** - Android Handler properly cleaned up in activity lifecycle
✅ **iOS Audio Session Fixed** - Audio properly cleaned up after calls end

### 🟠 **High-Priority Stability** (TIER 2)

✅ **Thread Safety** - iOS dictionaries now use serial dispatch queues (no more race conditions)
✅ **Init Protection** - Multiple init() calls prevented with proper StateError
✅ **Permission Checks** - Android 13+ POST_NOTIFICATIONS runtime permission support
✅ **Force Unwrap Removal** - All iOS force unwraps replaced with safe optional casting

### 🟡 **Code Quality Improvements** (TIER 3)

✅ **CallEvent Equality Fixed** - Complete field coverage in operator== and hashCode
✅ **Error Handling Enhanced** - Comprehensive try-catch in event processing
✅ **Better Logging** - Replaced print() with dart:developer log()

### 🎨 **Enhanced Custom Features** (Previous Release)

✅ **Custom Body Text** - Replace default "Incoming Video call" messages
✅ **Dynamic Background Colors** - Perfect for call filter apps
✅ **Custom Notification Routes** - Navigate to specific screens
✅ **Caller Photo Support** - Display avatar images with caching
✅ **"Unknown Caller" Fix** - Caller names now persist throughout call
✅ **Remote Termination Fix** - Notifications properly clear when caller ends call

### 📚 **Comprehensive Documentation**

✅ **Troubleshooting Guide** - Common issues and solutions ([TROUBLESHOOTING.md](TROUBLESHOOTING.md))
✅ **Compatibility Matrix** - Tested devices and OS versions ([COMPATIBILITY.md](COMPATIBILITY.md))
✅ **This Complete Guide** - Everything you need to know

---

## Quick Start Guide

### 1. Add Package

```yaml
dependencies:
  connectycube_flutter_call_kit: ^2.11.0
```

### 2. Configure Permissions

**Android** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/> <!-- Android 13+ -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" /> <!-- Android 12+ -->
```

**iOS** - Add capabilities in Xcode:
- Push Notifications
- Background Modes → Voice over IP

### 3. Initialize Once at Startup

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ConnectycubeFlutterCallKit.instance.init(
    onCallAccepted: _onCallAccepted,
    onCallRejected: _onCallRejected,
    onCallIncoming: _onCallIncoming,
    onNotificationTap: _onNotificationTap, // NEW
  );

  runApp(MyApp());
}

void _onCallAccepted(CallEvent event) {
  print('Accepted: ${event.sessionId}');
}

void _onCallRejected(CallEvent event) {
  print('Rejected: ${event.sessionId}');
}

void _onCallIncoming(CallEvent event) {
  print('Incoming: ${event.sessionId}');
}

void _onNotificationTap(CallEvent event) {
  // NEW: Handle notification tap
  if (event.customNotificationRoute != null) {
    Navigator.pushNamed(context, event.customNotificationRoute!);
  }
}
```

### 4. Show Call Notification

```dart
import 'package:uuid/uuid.dart';

final callEvent = CallEvent(
  sessionId: Uuid().v4(), // Must be valid UUID
  callType: 1, // 1=video, 0=audio
  callerId: 123,
  callerName: 'Alice Smith',
  opponentsIds: {456},
  callPhoto: 'https://example.com/avatar.jpg', // Optional
  userInfo: {'room_id': 'abc123'}, // Optional
  customBodyText: 'Dr. Smith is calling', // NEW
  backgroundColor: '#4285F4', // NEW
  customNotificationRoute: '/call-screen', // NEW
);

await ConnectycubeFlutterCallKit.showCallNotification(callEvent);
```

### 5. Always Dispose When Done

```dart
@override
void dispose() {
  ConnectycubeFlutterCallKit.instance.dispose(); // NEW - Required!
  super.dispose();
}
```

---

## Installation & Setup

### Complete Android Configuration

#### build.gradle (Project-level)
```gradle
buildscript {
    ext.kotlin_version = '1.9.20'
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### build.gradle (App-level)
```gradle
android {
    compileSdk 34
    defaultConfig {
        minSdk 23
        targetSdk 34
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
}

apply plugin: 'com.google.gms.google-services'
```

#### AndroidManifest.xml
```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application>
        <meta-data
            android:name="com.connectycube.flutter.connectycube_flutter_call_kit.notification_icon"
            android:resource="@drawable/ic_notification" />
    </application>
</manifest>
```

### Complete iOS Configuration

#### Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>remote-notification</string>
</array>
```

#### Xcode Capabilities
1. Push Notifications
2. Background Modes → Voice over IP

---

## Basic Usage

### Initialization (NEW - Improved)

**Important Changes in v2.10.0+:**
- ✅ Can only init() once
- ✅ Must call dispose() before re-initializing
- ✅ StateError thrown on duplicate init()

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ONCE at app startup
  ConnectycubeFlutterCallKit.instance.init(
    onCallAccepted: handleCallAccepted,
    onCallRejected: handleCallRejected,
    onCallIncoming: handleCallIncoming,
    onNotificationTap: handleNotificationTap,
    ringtone: 'custom_ringtone',
    icon: 'app_icon',
    color: '#FF6B6B',
  );

  // Background handlers (Android)
  ConnectycubeFlutterCallKit.onCallAcceptedWhenTerminated = handleAcceptedBG;
  ConnectycubeFlutterCallKit.onCallRejectedWhenTerminated = handleRejectedBG;
  ConnectycubeFlutterCallKit.onCallIncomingWhenTerminated = handleIncomingBG;

  // Token refresh listener
  ConnectycubeFlutterCallKit.instance.onTokenRefreshed = (token) {
    print('Push token: $token');
    // Send to your server
  };

  runApp(MyApp());
}

// Background callbacks must be top-level
@pragma('vm:entry-point')
void handleAcceptedBG(CallEvent event) {
  print('[BG] Accepted: ${event.sessionId}');
}

@pragma('vm:entry-point')
void handleRejectedBG(CallEvent event) {
  print('[BG] Rejected: ${event.sessionId}');
}

@pragma('vm:entry-point')
void handleIncomingBG(CallEvent event) {
  print('[BG] Incoming: ${event.sessionId}');
}
```

### Disposal (NEW - Required)

```dart
// MUST call dispose() to prevent memory leaks
@override
void dispose() {
  ConnectycubeFlutterCallKit.instance.dispose();
  super.dispose();
}
```

### Show Call Notifications

```dart
import 'package:uuid/uuid.dart';

Future<void> showIncomingCall() async {
  final callEvent = CallEvent(
    sessionId: Uuid().v4(), // Must be valid UUID
    callType: 1, // 0=audio, 1=video
    callerId: 12345,
    callerName: 'Bob Johnson',
    opponentsIds: {67890, 11111},
    callPhoto: 'https://example.com/avatar.jpg',
    userInfo: {'room_id': 'meeting-123'},
  );

  await ConnectycubeFlutterCallKit.showCallNotification(callEvent);
}
```

### Report Call States

```dart
// Accept call
await ConnectycubeFlutterCallKit.reportCallAccepted(sessionId: callId);

// End call
await ConnectycubeFlutterCallKit.reportCallEnded(
  sessionId: callId,
  reason: 'remoteEnded', // 'remoteEnded', 'unanswered', 'failed'
);
```

---

## Enhanced Custom Features

### Custom Body Text

Replace default "Incoming Video call" with custom messages:

```dart
// Medical appointment
CallEvent callEvent = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 123,
  callerName: 'Dr. Wilson',
  opponentsIds: {456},
  customBodyText: 'Your appointment with Dr. Wilson',
);

// Emergency call
CallEvent emergencyCall = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 999,
  callerName: 'Emergency Services',
  opponentsIds: {456},
  customBodyText: '🚨 Emergency Call - URGENT',
);
```

### Dynamic Background Colors (Perfect for Call Filter Apps!)

```dart
// Call filter app - user chooses color
final Map<String, String> colors = {
  'red': '#FF6B6B',
  'blue': '#4285F4',
  'green': '#4CAF50',
  'purple': '#9C27B0',
};

CallEvent filterCall = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 123,
  callerName: 'Mom',
  opponentsIds: {456},
  backgroundColor: colors[userSelectedColor], // Dynamic!
  customBodyText: 'Mom is calling',
);

// Medical app - professional blue
CallEvent medicalCall = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 789,
  callerName: 'Dr. Smith',
  opponentsIds: {456},
  backgroundColor: '#4285F4',
  customBodyText: 'Medical consultation call',
);
```

### Custom Notification Routes

Navigate to specific screens when notification is tapped:

```dart
CallEvent callEvent = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 123,
  callerName: 'Alice',
  opponentsIds: {456},
  customNotificationRoute: '/call-waiting-screen', // Custom route
);

// Handle in callback
void handleNotificationTap(CallEvent event) {
  if (event.customNotificationRoute != null) {
    Navigator.pushNamed(
      context,
      event.customNotificationRoute!,
      arguments: event,
    );
  }
}
```

### Caller Photo with Caching

```dart
// Configure image handling
await ConnectycubeFlutterCallKit.instance.updateConfig(
  imageLoadingTimeout: 8000, // 8 seconds
  enableImageCaching: true, // Enable caching
  maxImageSize: 200, // 200x200 pixels
);

// Show call with photo
CallEvent callEvent = CallEvent(
  sessionId: uuid,
  callType: 1,
  callerId: 123,
  callerName: 'Alice',
  opponentsIds: {456},
  callPhoto: 'https://api.example.com/avatars/alice.jpg',
);
```

---

## Advanced Features

### Permission Checking (NEW in v2.10.0+)

#### Android 13+ Notification Permission

```dart
Future<void> checkNotificationPermission() async {
  final status = await ConnectycubeFlutterCallKit.instance
      .checkNotificationPermission();

  print('Granted: ${status['granted']}');
  print('API Level: ${status['apiLevel']}');
  print('Requires Permission: ${status['requiresPermission']}');

  if (status['granted'] == false && status['requiresPermission'] == true) {
    // Use permission_handler package
    await Permission.notification.request();
  }
}
```

#### Android 12+ Lock Screen Permission

```dart
Future<void> checkLockScreenPermissions() async {
  final perms = await ConnectycubeFlutterCallKit.instance
      .checkLockScreenPermissions();

  print('Can use full screen intent: ${perms['canUseFullScreenIntent']}');
  print('Notifications enabled: ${perms['notificationsEnabled']}');
  print('Device locked: ${perms['isDeviceLocked']}');
  print('Keyguard secure: ${perms['isKeyguardSecure']}');

  if (perms['canUseFullScreenIntent'] == false) {
    await ConnectycubeFlutterCallKit.provideFullScreenIntentAccess();
  }
}
```

### Call State Management

```dart
// Get call state
final state = await ConnectycubeFlutterCallKit.getCallState(
  sessionId: callId,
);
// Returns: 'pending', 'accepted', 'rejected', 'unknown'

// Set call state
await ConnectycubeFlutterCallKit.setCallState(
  sessionId: callId,
  callState: 'accepted',
);

// Get call data
final data = await ConnectycubeFlutterCallKit.getCallData(
  sessionId: callId,
);

// Clear call data
await ConnectycubeFlutterCallKit.clearCallData(
  sessionId: callId,
);

// Get last call ID
final lastId = await ConnectycubeFlutterCallKit.getLastCallId();
```

### Mute Handling (iOS)

```dart
// Listen for mute changes
ConnectycubeFlutterCallKit.instance.onCallMuted = (isMuted, sessionId) {
  print('Call $sessionId muted: $isMuted');
};

// Report mute state
await ConnectycubeFlutterCallKit.reportCallMuted(
  sessionId: callId,
  muted: true,
);
```

---

## Permission Management

### Proactive Permission Checking

```dart
Future<void> ensurePermissions() async {
  if (Platform.isAndroid) {
    // Check notification permission (Android 13+)
    final notifStatus = await ConnectycubeFlutterCallKit.instance
        .checkNotificationPermission();

    if (notifStatus['requiresPermission'] == true &&
        notifStatus['granted'] == false) {
      await Permission.notification.request();
    }

    // Check lock screen permission (Android 12+)
    final lockStatus = await ConnectycubeFlutterCallKit.instance
        .checkLockScreenPermissions();

    if (lockStatus['canUseFullScreenIntent'] == false) {
      await ConnectycubeFlutterCallKit.provideFullScreenIntentAccess();
    }
  }
}
```

---

## Platform-Specific Configuration

### Android

#### Custom Notification Icon
```xml
<!-- AndroidManifest.xml -->
<meta-data
    android:name="com.connectycube.flutter.connectycube_flutter_call_kit.notification_icon"
    android:resource="@drawable/ic_call_notification" />
```

#### Custom Ringtone
```dart
await ConnectycubeFlutterCallKit.instance.updateConfig(
  ringtone: 'custom_ringtone', // In res/raw/custom_ringtone.mp3
);
```

### iOS

#### VoIP Push Payload
```json
{
  "aps": {"content-available": 1},
  "session_id": "call-uuid",
  "signal_type": "startCall",
  "call_type": 1,
  "caller_id": 123,
  "caller_name": "Alice",
  "call_opponents": "456",
  "user_info": "{}",
  "custom_body_text": "Custom message",
  "background_color": "#4285F4"
}
```

---

## Best Practices

### ✅ DO

```dart
// Initialize once at startup
void main() {
  ConnectycubeFlutterCallKit.instance.init(/* ... */);
  runApp(MyApp());
}

// Always dispose
@override
void dispose() {
  ConnectycubeFlutterCallKit.instance.dispose();
  super.dispose();
}

// Use valid UUIDs
import 'package:uuid/uuid.dart';
final uuid = Uuid().v4();

// Top-level background callbacks
@pragma('vm:entry-point')
void onCallAccepted(CallEvent event) { }

// Check permissions proactively
await checkNotificationPermission();
await checkLockScreenPermissions();
```

### ❌ DON'T

```dart
// Don't init() multiple times
ConnectycubeFlutterCallKit.instance.init(/* ... */);
ConnectycubeFlutterCallKit.instance.init(/* ... */); // StateError!

// Don't use invalid UUIDs
final uuid = '12345'; // Not a UUID!

// Don't use class methods for background
class MyClass {
  void onCallAccepted(CallEvent event) { } // Won't work!
}

// Don't forget to dispose
// Missing dispose() = memory leaks!
```

---

## Complete API Reference

### Initialization
```dart
void init({
  CallEventHandler? onCallAccepted,
  CallEventHandler? onCallRejected,
  CallEventHandler? onCallIncoming,
  CallEventHandler? onNotificationTap,
  String? ringtone,
  String? icon,
  String? color,
})

void dispose() // NEW - Required!
```

### Notifications
```dart
static Future<void> showCallNotification(CallEvent callEvent)
```

### Call State Reporting
```dart
static Future<void> reportCallAccepted({required String? sessionId})

static Future<void> reportCallEnded({
  required String? sessionId,
  String? reason,
})

static Future<void> reportCallMuted(String sessionId, bool muted)
```

### State Management
```dart
static Future<String> getCallState({required String? sessionId})
static Future<void> setCallState({required String? sessionId, required String? callState})
static Future<Map<String, dynamic>?> getCallData({required String? sessionId})
static Future<void> clearCallData({required String? sessionId})
static Future<String?> getLastCallId()
```

### Permissions (NEW)
```dart
static Future<Map<String, dynamic>> checkNotificationPermission()
static Future<Map<String, dynamic>> checkLockScreenPermissions()
static Future<void> provideFullScreenIntentAccess()
static Future<bool> canUseFullScreenIntent()
```

### Configuration
```dart
Future<void> updateConfig({
  String? ringtone,
  String? icon,
  String? color,
  int? imageLoadingTimeout,
  bool? enableImageCaching,
  int? maxImageSize,
})
```

### Background Handlers
```dart
static set onCallAcceptedWhenTerminated(CallEventHandler? handler)
static set onCallRejectedWhenTerminated(CallEventHandler? handler)
static set onCallIncomingWhenTerminated(CallEventHandler? handler)
```

### Callbacks
```dart
static Function(String newToken)? onTokenRefreshed
static Function(bool isMuted, String sessionId)? onCallMuted
```

---

## Migration Guide

### From v2.8.x to v2.9.0+

#### 1. Add dispose() - REQUIRED

```dart
// NEW REQUIREMENT
@override
void dispose() {
  ConnectycubeFlutterCallKit.instance.dispose();
  super.dispose();
}
```

#### 2. Handle Multiple init() - BREAKING CHANGE

```dart
// OLD - Multiple init() worked but leaked memory
ConnectycubeFlutterCallKit.instance.init(/* ... */);
ConnectycubeFlutterCallKit.instance.init(/* ... */); // Leaked!

// NEW - Throws StateError
ConnectycubeFlutterCallKit.instance.init(/* ... */);
ConnectycubeFlutterCallKit.instance.init(/* ... */); // StateError!

// Solution: dispose() first
ConnectycubeFlutterCallKit.instance.dispose();
ConnectycubeFlutterCallKit.instance.init(/* ... */); // OK
```

### From v2.9.x to v2.10.0+

#### 1. Request Permissions on Android 13+

```dart
// NEW - Required for Android 13+
final status = await ConnectycubeFlutterCallKit.instance
    .checkNotificationPermission();

if (!status['granted']) {
  await Permission.notification.request();
}
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive troubleshooting guide.

### Quick Fixes

| Issue | Solution |
|-------|----------|
| Lock screen not showing (Android 12+) | Request USE_FULL_SCREEN_INTENT permission |
| Notifications missing (Android 13+) | Request POST_NOTIFICATIONS permission |
| "Unknown Caller" | Update to v2.9.0+ (fixed) |
| Memory leaks | Update to v2.9.0+ and call dispose() |
| StateError on init() | Call dispose() before re-init |
| Background callbacks not firing | Use top-level functions with @pragma |

---

## Examples & Use Cases

### Medical Consultation App

```dart
CallEvent medicalCall = CallEvent(
  sessionId: Uuid().v4(),
  callType: 1,
  callerId: doctorId,
  callerName: 'Dr. Sarah Wilson',
  opponentsIds: {patientId},
  callPhoto: doctorAvatarUrl,
  backgroundColor: '#4285F4',
  customBodyText: 'Your appointment with Dr. Wilson',
  customNotificationRoute: '/medical-call-screen',
);

await ConnectycubeFlutterCallKit.showCallNotification(medicalCall);
```

### Call Filter App with Dynamic Colors

```dart
final colors = {
  'red': '#FF6B6B',
  'blue': '#4285F4',
  'green': '#4CAF50',
};

CallEvent filterCall = CallEvent(
  sessionId: Uuid().v4(),
  callType: 1,
  callerId: callerId,
  callerName: callerName,
  opponentsIds: {recipientId},
  backgroundColor: colors[userSelectedColor], // User chooses!
  customBodyText: userCustomMessage,
);

await ConnectycubeFlutterCallKit.showCallNotification(filterCall);
```

### Emergency Call

```dart
CallEvent emergencyCall = CallEvent(
  sessionId: Uuid().v4(),
  callType: 1,
  callerId: 911,
  callerName: 'Emergency Services',
  opponentsIds: {userId},
  backgroundColor: '#F44336',
  customBodyText: '🚨 Emergency Call - URGENT',
  customNotificationRoute: '/emergency-screen',
);

await ConnectycubeFlutterCallKit.showCallNotification(emergencyCall);
```

---

## Additional Resources

- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Compatibility**: [COMPATIBILITY.md](COMPATIBILITY.md)
- **GitHub**: https://github.com/ConnectyCube/connectycube-flutter-call-kit
- **Issues**: https://github.com/ConnectyCube/connectycube-flutter-call-kit/issues

---

## Version History & Fixes

| Version | Improvements |
|---------|-------------|
| **v2.11.0** | Complete quality overhaul |
| **v2.10.0** | Thread safety, permission checks, force unwrap removal |
| **v2.9.0** | Memory leak fixes, ANR fixes, disposal support |
| **v2.8.2** | Custom features, bug fixes (previous release) |

### All Improvements Summary

- ✅ Memory leaks eliminated (Dart, Android Handler, iOS)
- ✅ ANR issues resolved (SharedPreferences async)
- ✅ Thread safety added (iOS dispatch queues)
- ✅ Permission checking (Android 13+, Android 12+)
- ✅ Force unwraps removed (iOS crash prevention)
- ✅ Error handling enhanced (comprehensive try-catch)
- ✅ Custom features (body text, colors, routes, photos)
- ✅ Caller name persistence fixed
- ✅ Remote termination cleanup fixed
- ✅ Comprehensive documentation

---

*Last updated: December 2025*
*Package version: 2.11.0+*
*Status: Production-Ready & Fully Tested*
