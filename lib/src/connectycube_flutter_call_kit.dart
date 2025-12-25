import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_io/io.dart';

import 'call_event.dart';

/// Function type for handling accepted and rejected call events
typedef CallEventHandler = Future<dynamic> Function(CallEvent event);

/// {@template connectycube_flutter_call_kit}
/// Plugin to manage call events and notifications
/// {@endtemplate}
class ConnectycubeFlutterCallKit {
  static const MethodChannel _methodChannel =
      const MethodChannel('connectycube_flutter_call_kit.methodChannel');
  static const EventChannel _eventChannel =
      const EventChannel('connectycube_flutter_call_kit.callEventChannel');

  /// {@macro connectycube_flutter_call_kit}
  factory ConnectycubeFlutterCallKit() => _getInstance();

  const ConnectycubeFlutterCallKit._internal();

  static ConnectycubeFlutterCallKit get instance => _getInstance();
  static ConnectycubeFlutterCallKit? _instance;
  static String TAG = "ConnectycubeFlutterCallKit";

  static ConnectycubeFlutterCallKit _getInstance() {
    if (_instance == null) {
      _instance = ConnectycubeFlutterCallKit._internal();
    }
    return _instance!;
  }

  static int _bgHandler = -1;

  static Function(String newToken)? onTokenRefreshed;

  /// iOS only callbacks
  static Function(bool isMuted, String sessionId)? onCallMuted;

  /// end iOS only callbacks

  static CallEventHandler? _onCallRejectedWhenTerminated;
  static CallEventHandler? _onCallAcceptedWhenTerminated;
  static CallEventHandler? _onCallIncomingWhenTerminated;

  static CallEventHandler? _onCallAccepted;
  static CallEventHandler? _onCallRejected;

  static CallEventHandler? _onCallIncoming;

  /// Notification tap callback (when notification is tapped, not accept/reject buttons)
  static CallEventHandler? _onNotificationTap;

  /// Stream subscription for event channel (to prevent memory leaks)
  static StreamSubscription? _eventSubscription;

  /// Initialization flag to prevent duplicate initialization
  static bool _isInitialized = false;

  /// Initialize the plugin and provided user callbacks.
  ///
  /// - This function should only be called once at the beginning of
  /// your application.
  /// - Calling init() multiple times will throw a StateError.
  /// - To re-initialize, call dispose() first, then call init() again.
  void init(
      {CallEventHandler? onCallAccepted,
      CallEventHandler? onCallRejected,
      CallEventHandler? onCallIncoming,
      CallEventHandler? onNotificationTap,
      String? ringtone,
      String? icon,
      @Deprecated('Use `AndroidManifest.xml` meta-data instead')
      String? notificationIcon,
      String? color}) {
    // Prevent duplicate initialization
    if (_isInitialized) {
      throw StateError(
          'ConnectycubeFlutterCallKit is already initialized. '
          'Call dispose() before re-initializing.');
    }

    _onCallAccepted = onCallAccepted;
    _onCallRejected = onCallRejected;
    _onCallIncoming = onCallIncoming;
    _onNotificationTap = onNotificationTap;

    updateConfig(
        ringtone: ringtone,
        icon: icon,
        notificationIcon: notificationIcon,
        color: color);

    initEventsHandler();

    // Mark as initialized
    _isInitialized = true;
  }

  /// Dispose of the plugin and clean up resources.
  ///
  /// This method should be called when the plugin is no longer needed,
  /// typically in the dispose() method of your widget or app.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   ConnectycubeFlutterCallKit.instance.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    // Cancel event stream subscription
    _eventSubscription?.cancel();
    _eventSubscription = null;

    // Clear all callbacks to prevent memory leaks
    _onCallAccepted = null;
    _onCallRejected = null;
    _onCallIncoming = null;
    _onNotificationTap = null;
    _onCallRejectedWhenTerminated = null;
    _onCallAcceptedWhenTerminated = null;
    _onCallIncomingWhenTerminated = null;
    onTokenRefreshed = null;
    onCallMuted = null;

    // Reset initialization flag to allow re-initialization
    _isInitialized = false;
  }

  /// Set a reject call handler function which is called when the app is in the
  /// background or terminated.
  ///
  /// This provided handler must be a top-level function and cannot be
  /// anonymous otherwise an [ArgumentError] will be thrown.
  static set onCallRejectedWhenTerminated(CallEventHandler? handler) {
    _onCallRejectedWhenTerminated = handler;

    if (handler != null) {
      instance._registerBackgroundCallEventHandler(
          handler, BackgroundCallbackName.REJECTED_IN_BACKGROUND);
    }
  }

  /// Set a accept call handler function which is called when the app is in the
  /// background or terminated.
  ///
  /// This provided handler must be a top-level function and cannot be
  /// anonymous otherwise an [ArgumentError] will be thrown.
  static set onCallAcceptedWhenTerminated(CallEventHandler? handler) {
    _onCallAcceptedWhenTerminated = handler;

    if (handler != null) {
      instance._registerBackgroundCallEventHandler(
          handler, BackgroundCallbackName.ACCEPTED_IN_BACKGROUND);
    }
  }

  /// Set an incoming call handler function which is called when the app is in the
  /// background or terminated.
  ///
  /// This provided handler must be a top-level function and cannot be
  /// anonymous otherwise an [ArgumentError] will be thrown.
  static set onCallIncomingWhenTerminated(CallEventHandler? handler) {
    _onCallIncomingWhenTerminated = handler;

    if (handler != null) {
      instance._registerBackgroundCallEventHandler(
          handler, BackgroundCallbackName.INCOMING_IN_BACKGROUND);
    }
  }

  Future<void> _registerBackgroundCallEventHandler(
      CallEventHandler handler, String callbackName) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (_bgHandler == -1) {
      final CallbackHandle bgHandle = PluginUtilities.getCallbackHandle(
          _backgroundEventsCallbackDispatcher)!;

      _bgHandler = bgHandle.toRawHandle();
    }

    final CallbackHandle userHandle =
        PluginUtilities.getCallbackHandle(handler)!;

    await _methodChannel.invokeMapMethod('startBackgroundIsolate', {
      'pluginCallbackHandle': _bgHandler,
      'userCallbackHandleName': callbackName,
      'userCallbackHandle': userHandle.toRawHandle(),
    });
  }

  static void initEventsHandler() {
    // Cancel existing subscription to prevent memory leaks
    _eventSubscription?.cancel();

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (rawData) {
        print('[initEventsHandler] rawData: $rawData');
        final eventData = Map<String, dynamic>.from(rawData);

        _processEvent(eventData);
      },
      onError: (error) {
        log('[initEventsHandler] Error receiving event: $error',
            name: TAG, error: error);
      },
      cancelOnError: false,
    );
  }

  /// Sets the additional configs for the Call notification
  /// [ringtone] - the name of the ringtone source (for Android it should be placed by path 'res/raw', for iOS it is a name of ringtone)
  /// [icon] - the name of image in the `drawable` folder for Android and the name of Assets set for iOS
  /// [notificationIcon] - the name of the image in the `drawable` folder, uses as Notification Small Icon for Android, ignored for iOS
  /// [color] - the color in the format '#RRGGBB', uses as an Android Notification accent color, ignored for iOS
  /// [imageLoadingTimeout] - timeout in milliseconds for loading caller images (Android only, default: 10000)
  /// [enableImageCaching] - enable disk caching for caller images (Android only, default: true)
  /// [maxImageSize] - maximum size in pixels for caller images (Android only, default: 300)
  Future<void> updateConfig(
      {String? ringtone,
      String? icon,
      @Deprecated('Use `AndroidManifest.xml` meta-data instead')
      String? notificationIcon,
      String? color,
      int? imageLoadingTimeout,
      bool? enableImageCaching,
      int? maxImageSize}) {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod('updateConfig', {
      'ringtone': ringtone,
      'icon': icon,
      'notification_icon': notificationIcon,
      'color': color,
      'image_loading_timeout': imageLoadingTimeout,
      'enable_image_caching': enableImageCaching,
      'max_image_size': maxImageSize,
    });
  }

  /// Returns VoIP token for iOS plaform.
  /// Returns FCM token for Android platform
  static Future<String?> getToken() {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(null);

    return _methodChannel.invokeMethod('getVoipToken', {}).then((result) {
      return result?.toString();
    });
  }

  /// Show incoming call notification
  static Future<void> showCallNotification(CallEvent callEvent) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod(
        "showCallNotification", callEvent.toMap());
  }

  /// Report that the current active call has been accepted by your application
  ///
  static Future<void> reportCallAccepted({required String? sessionId}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel
        .invokeMethod("reportCallAccepted", {'session_id': sessionId});
  }

  /// Report that the current active call has been ended by your application
  static Future<void> reportCallEnded({
    required String? sessionId,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod("reportCallEnded", {
      'session_id': sessionId,
    });
  }

  /// Get the current call state
  ///
  /// Other platforms than Android and iOS will receive [CallState.UNKNOWN]
  static Future<String> getCallState({
    required String? sessionId,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS)
      return Future.value(CallState.UNKNOWN);

    return _methodChannel.invokeMethod("getCallState", {
      'session_id': sessionId,
    }).then((state) {
      return state.toString();
    });
  }

  /// Updates the current call state
  static Future<void> setCallState({
    required String? sessionId,
    required String? callState,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod("setCallState", {
      'session_id': sessionId,
      'call_state': callState,
    });
  }

  /// Retrieves call information about the call
  static Future<Map<String, dynamic>?> getCallData({
    required String? sessionId,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(null);

    return _methodChannel.invokeMethod("getCallData", {
      'session_id': sessionId,
    }).then((data) {
      if (data == null) {
        log('[ConnectycubeFlutterCallKit][getCallData] No call data found for session: $sessionId');
        return Future.value(null);
      }
      
      final callData = Map<String, dynamic>.from(data);
      log('[ConnectycubeFlutterCallKit][getCallData] Retrieved call data for session: $sessionId, caller: ${callData["caller_name"] ?? "Unknown"}');
      return Future.value(callData);
    });
  }

  /// Cleans all data related to the call
  static Future<void> clearCallData({
    required String? sessionId,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod("clearCallData", {
      'session_id': sessionId,
    });
  }

  /// Returns the id of the last displayed call.
  /// It is useful on starting app step for navigation to the call screen if the call was accepted
  static Future<String?> getLastCallId() async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(null);

    return _methodChannel.invokeMethod("getLastCallId");
  }

  static Future<void> setOnLockScreenVisibility({
    required bool? isVisible,
  }) async {
    if (!Platform.isAndroid) return;

    return _methodChannel.invokeMethod("setOnLockScreenVisibility", {
      'is_visible': isVisible,
    });
  }

  /// Report that the current active call has been ended by your application
  static Future<void> reportCallMuted(
      {required String? sessionId, required bool? muted}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value();

    return _methodChannel.invokeMethod("muteCall", {
      'session_id': sessionId,
      'muted': muted,
    });
  }

  /// Returns whether the app can send fullscreen intents (required for showing
  /// the Incoming call screen on the Lockscreen)
  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return Future.value(true);

    return _methodChannel.invokeMethod("canUseFullScreenIntent").then((result) {
      if (result == null) {
        return false;
      }

      return result;
    });
  }

  /// Helper method to get caller name for debugging/testing purposes
  static Future<String?> getCallerName({required String? sessionId}) async {
    if (sessionId == null) return null;
    
    final callData = await getCallData(sessionId: sessionId);
    return callData?["caller_name"] as String?;
  }

  /// Opens the Setting to grant/deny permission for running the fullscreen Intents
  static Future<void> provideFullScreenIntentAccess() async {
    if (!Platform.isAndroid) return Future.value();

    return _methodChannel.invokeMethod("provideFullScreenIntentAccess");
  }

  /// Verifies all required lock screen permissions are granted (Android 12+ only)
  ///
  /// Returns a map with permission states:
  /// - `canUseFullScreenIntent`: Whether full-screen intent permission is granted
  /// - `notificationsEnabled`: Whether notifications are enabled for the app
  /// - `isKeyguardLocked`: Whether the device is currently locked
  /// - `supported`: false if not Android or below Android 12
  ///
  /// Example usage:
  /// ```dart
  /// final permissions = await ConnectycubeFlutterCallKit.checkLockScreenPermissions();
  /// if (permissions['canUseFullScreenIntent'] == false) {
  ///   // Request permission
  ///   await ConnectycubeFlutterCallKit.provideFullScreenIntentAccess();
  /// }
  /// ```
  static Future<Map<String, dynamic>> checkLockScreenPermissions() async {
    if (!Platform.isAndroid) {
      return {'supported': false};
    }

    try {
      final result = await _methodChannel.invokeMethod('checkLockScreenPermissions');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      log('[ConnectycubeFlutterCallKit][checkLockScreenPermissions] Error: $e');
      return {'error': true, 'message': e.toString()};
    }
  }

  /// Check if the app has notification permission (Android 13+ / API 33+).
  ///
  /// Returns a map containing:
  /// - `granted` (bool): Whether notification permission is granted
  /// - `apiLevel` (int): Current Android API level
  /// - `requiresPermission` (bool): Whether runtime permission is required (API 33+)
  ///
  /// For Android versions below 13 (API 33), this will return `granted: true`
  /// since POST_NOTIFICATIONS permission is not required.
  ///
  /// Returns `{'granted': true}` on iOS as notification permissions work differently.
  ///
  /// Example:
  /// ```dart
  /// final status = await ConnectycubeFlutterCallKit.instance.checkNotificationPermission();
  /// if (status['granted'] == false && status['requiresPermission'] == true) {
  ///   // Request POST_NOTIFICATIONS permission using permission_handler or similar
  /// }
  /// ```
  static Future<Map<String, dynamic>> checkNotificationPermission() async {
    if (!Platform.isAndroid) {
      // iOS notification permissions work differently
      return {'granted': true};
    }

    try {
      final result = await _methodChannel.invokeMethod('checkNotificationPermission');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      log('[ConnectycubeFlutterCallKit][checkNotificationPermission] Error: $e',
          name: TAG, error: e);
      return {'error': true, 'message': e.toString()};
    }
  }

  static void _processEvent(Map<String, dynamic> eventData) {
    try {
      log('[ConnectycubeFlutterCallKit][_processEvent] eventData: $eventData',
          name: TAG);

      // Validate event data structure
      if (!eventData.containsKey("event") || !eventData.containsKey('args')) {
        log('[ConnectycubeFlutterCallKit][_processEvent] Invalid event data structure: missing "event" or "args" key',
            name: TAG, level: 900); // WARNING level
        return;
      }

      final event = eventData["event"];
      if (event is! String) {
        log('[ConnectycubeFlutterCallKit][_processEvent] Invalid event type: expected String, got ${event.runtimeType}',
            name: TAG, level: 900);
        return;
      }

      final arguments = Map<String, dynamic>.from(eventData['args']);

      switch (event) {
        case 'voipToken':
          final voipToken = arguments['voipToken'];
          if (voipToken != null) {
            onTokenRefreshed?.call(voipToken);
          }
          break;

        case 'answerCall':
          final callEvent = CallEvent.fromMap(arguments);
          _onCallAccepted?.call(callEvent);
          break;

        case 'endCall':
          final callEvent = CallEvent.fromMap(arguments);
          _onCallRejected?.call(callEvent);
          break;

        case 'startCall':
          break;

        case 'setMuted':
          final sessionId = arguments["session_id"];
          if (sessionId != null) {
            onCallMuted?.call(true, sessionId);
          }
          break;

        case 'setUnMuted':
          final sessionId = arguments["session_id"];
          if (sessionId != null) {
            onCallMuted?.call(false, sessionId);
          }
          break;

        case 'incomingCall':
          final callEvent = CallEvent.fromMap(arguments);
          _onCallIncoming?.call(callEvent);
          break;

        case 'notificationTap':
          final callEvent = CallEvent.fromMap(arguments);
          _onNotificationTap?.call(callEvent);
          break;

        case '':
          // Empty event, ignore
          break;

        default:
          log('[ConnectycubeFlutterCallKit][_processEvent] Unrecognized event: $event',
              name: TAG, level: 900);
      }
    } catch (e, stackTrace) {
      log('[ConnectycubeFlutterCallKit][_processEvent] Error processing event: $e',
          name: TAG, error: e, stackTrace: stackTrace, level: 1000); // SEVERE level
    }
  }
}

// This is the entrypoint for the background isolate. Since we can only enter
// an isolate once, we setup a MethodChannel to listen for method invocations
// from the native portion of the plugin. This allows for the plugin to perform
// any necessary processing in Dart (e.g., populating a custom object) before
// invoking the provided callback.
@pragma('vm:entry-point')
void _backgroundEventsCallbackDispatcher() {
  // Initialize state necessary for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel _channel = MethodChannel(
    'connectycube_flutter_call_kit.methodChannel.background',
  );

  // This is where we handle background events from the native portion of the plugin.
  _channel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'onBackgroundEvent') {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments['userCallbackHandle']);

      // PluginUtilities.getCallbackFromHandle performs a lookup based on the
      // callback handle and returns a tear-off of the original callback.
      final callback = PluginUtilities.getCallbackFromHandle(handle)!
          as Future<void> Function(CallEvent);

      try {
        Map<String, dynamic> callEventMap =
            Map<String, dynamic>.from(call.arguments['args']);
        final CallEvent callEvent = CallEvent.fromMap(callEventMap);
        await callback(callEvent);
      } catch (e) {
        // ignore: avoid_print
        log('[ConnectycubeFlutterCallKit][_backgroundEventsCallbackDispatcher] An error occurred in your background event handler: $e');
        // ignore: avoid_print
      }
    } else {
      throw UnimplementedError('${call.method} has not been implemented');
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling alarms.
  _channel.invokeMethod<void>('onBackgroundHandlerInitialized');
}

class CallState {
  static const String PENDING = "pending";
  static const String ACCEPTED = "accepted";
  static const String REJECTED = "rejected";
  static const String UNKNOWN = "unknown";
}

class BackgroundCallbackName {
  static const String REJECTED_IN_BACKGROUND = "rejected_in_background";
  static const String ACCEPTED_IN_BACKGROUND = "accepted_in_background";
  static const String INCOMING_IN_BACKGROUND = "incoming_in_background";
}
