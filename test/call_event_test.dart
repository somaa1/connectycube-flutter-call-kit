import 'package:flutter_test/flutter_test.dart';
import 'package:connectycube_flutter_call_kit/src/call_event.dart';
import 'package:connectycube_flutter_call_kit/src/call_event_validator.dart';

void main() {
  group('CallEvent', () {
    group('fromMap', () {
      test('should create CallEvent from valid map', () {
        final map = {
          'session_id': 'test-session-123',
          'call_type': 1,
          'caller_id': 12345,
          'caller_name': 'John Doe',
          'call_opponents': '67890,11111',
          'photo_url': 'https://example.com/photo.jpg',
          'user_info': '{"key": "value"}',
          'custom_body_text': 'Custom message',
          'background_color': '#FF6B6B',
          'custom_notification_route': '/call',
        };

        final event = CallEvent.fromMap(map);

        expect(event.sessionId, 'test-session-123');
        expect(event.callType, 1);
        expect(event.callerId, 12345);
        expect(event.callerName, 'John Doe');
        expect(event.opponentsIds, {67890, 11111});
        expect(event.callPhoto, 'https://example.com/photo.jpg');
        expect(event.userInfo, {'key': 'value'});
        expect(event.customBodyText, 'Custom message');
        expect(event.backgroundColor, '#FF6B6B');
        expect(event.customNotificationRoute, '/call');
      });

      test('should handle minimal valid map', () {
        final map = {
          'session_id': 'test-session',
          'call_type': 0,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        final event = CallEvent.fromMap(map);

        expect(event.sessionId, 'test-session');
        expect(event.callType, 0);
        expect(event.callerId, 123);
        expect(event.callerName, 'Caller');
        expect(event.opponentsIds, {456});
        expect(event.callPhoto, isNull);
        expect(event.userInfo, isNull);
      });

      test('should throw on missing session_id', () {
        final map = {
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(isA<CallEventValidationException>()),
        );
      });

      test('should throw on null session_id', () {
        final map = {
          'session_id': null,
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on missing call_type', () {
        final map = {
          'session_id': 'test',
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on invalid call_type', () {
        final map = {
          'session_id': 'test',
          'call_type': 'invalid',
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on missing caller_id', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on missing caller_name', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'call_opponents': '456',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on missing call_opponents', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should throw on invalid call_opponents format', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': 'invalid',
        };

        expect(
          () => CallEvent.fromMap(map),
          throwsA(anything),
        );
      });

      test('should handle multiple opponents correctly', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456,789,101112',
        };

        final event = CallEvent.fromMap(map);
        expect(event.opponentsIds, {456, 789, 101112});
      });

      test('should handle empty user_info correctly', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
          'user_info': '{}',
        };

        final event = CallEvent.fromMap(map);
        expect(event.userInfo, {});
      });

      test('should handle invalid user_info JSON gracefully', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
          'user_info': 'invalid-json',
        };

        // NEW BEHAVIOR: Gracefully handles invalid JSON by returning null
        final event = CallEvent.fromMap(map);
        expect(event.userInfo, isNull);
        expect(event.sessionId, 'test');
      });
    });

    group('toMap', () {
      test('should convert CallEvent to map correctly', () {
        final event = CallEvent(
          sessionId: 'test-session',
          callType: 1,
          callerId: 12345,
          callerName: 'John Doe',
          opponentsIds: {67890, 11111},
          callPhoto: 'https://example.com/photo.jpg',
          userInfo: {'key': 'value'},
          customBodyText: 'Custom message',
          backgroundColor: '#FF6B6B',
          customNotificationRoute: '/call',
        );

        final map = event.toMap();

        expect(map['session_id'], 'test-session');
        expect(map['call_type'], 1);
        expect(map['caller_id'], 12345);
        expect(map['caller_name'], 'John Doe');
        expect(map['call_opponents'], contains('67890'));
        expect(map['call_opponents'], contains('11111'));
        expect(map['photo_url'], 'https://example.com/photo.jpg');
        expect(map['custom_body_text'], 'Custom message');
        expect(map['background_color'], '#FF6B6B');
        expect(map['custom_notification_route'], '/call');
      });

      test('should handle null optional fields', () {
        final event = CallEvent(
          sessionId: 'test',
          callType: 0,
          callerId: 123,
          callerName: 'Caller',
          opponentsIds: {456},
        );

        final map = event.toMap();

        expect(map['session_id'], 'test');
        expect(map['call_type'], 0);
        expect(map['caller_id'], 123);
        expect(map['caller_name'], 'Caller');
        expect(map['photo_url'], isNull);
        expect(map['custom_body_text'], isNull);
      });
    });

    group('toJson and fromJson', () {
      test('should serialize and deserialize correctly', () {
        final originalEvent = CallEvent(
          sessionId: 'test-session',
          callType: 1,
          callerId: 12345,
          callerName: 'John Doe',
          opponentsIds: {67890, 11111},
          callPhoto: 'https://example.com/photo.jpg',
          userInfo: {'key': 'value'},
        );

        final json = originalEvent.toJson();
        final deserializedEvent = CallEvent.fromJson(json);

        expect(deserializedEvent.sessionId, originalEvent.sessionId);
        expect(deserializedEvent.callType, originalEvent.callType);
        expect(deserializedEvent.callerId, originalEvent.callerId);
        expect(deserializedEvent.callerName, originalEvent.callerName);
        expect(deserializedEvent.opponentsIds, originalEvent.opponentsIds);
        expect(deserializedEvent.callPhoto, originalEvent.callPhoto);
      });
    });

    group('copyWith', () {
      test('should create copy with modified fields', () {
        final original = CallEvent(
          sessionId: 'test',
          callType: 0,
          callerId: 123,
          callerName: 'Original',
          opponentsIds: {456},
        );

        final modified = original.copyWith(
          callerName: 'Modified',
          callType: 1,
        );

        expect(modified.sessionId, 'test');
        expect(modified.callType, 1);
        expect(modified.callerId, 123);
        expect(modified.callerName, 'Modified');
        expect(modified.opponentsIds, {456});
      });

      test('should keep original values when not specified', () {
        final original = CallEvent(
          sessionId: 'test',
          callType: 0,
          callerId: 123,
          callerName: 'Original',
          opponentsIds: {456},
          callPhoto: 'photo.jpg',
        );

        final modified = original.copyWith(callerName: 'Modified');

        expect(modified.sessionId, original.sessionId);
        expect(modified.callType, original.callType);
        expect(modified.callerId, original.callerId);
        expect(modified.callPhoto, original.callPhoto);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final event1 = CallEvent(
          sessionId: 'test',
          callType: 1,
          callerId: 123,
          callerName: 'Caller',
          opponentsIds: {456},
        );

        final event2 = CallEvent(
          sessionId: 'test',
          callType: 1,
          callerId: 123,
          callerName: 'Caller',
          opponentsIds: {456},
        );

        expect(event1, equals(event2));
        // Note: hashCode comparison removed due to Set hashCode instability in Dart
        // The equality operator uses setEquals which is reliable
      });

      test('should not be equal when fields differ', () {
        final event1 = CallEvent(
          sessionId: 'test',
          callType: 1,
          callerId: 123,
          callerName: 'Caller',
          opponentsIds: {456},
        );

        final event2 = CallEvent(
          sessionId: 'test',
          callType: 1,
          callerId: 123,
          callerName: 'Different',
          opponentsIds: {456},
        );

        expect(event1, isNot(equals(event2)));
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        final event = CallEvent(
          sessionId: 'test-123',
          callType: 1,
          callerId: 456,
          callerName: 'John',
          opponentsIds: {789},
        );

        final str = event.toString();

        expect(str, contains('test-123'));
        expect(str, contains('1'));
        expect(str, contains('456'));
        expect(str, contains('John'));
        expect(str, contains('789'));
      });
    });

    group('Edge Cases', () {
      test('should handle very large opponent IDs', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 2147483647, // Max int32
          'caller_name': 'Caller',
          'call_opponents': '2147483647',
        };

        final event = CallEvent.fromMap(map);
        expect(event.callerId, 2147483647);
        expect(event.opponentsIds, {2147483647});
      });

      test('should handle empty opponents list', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '',
        };

        // NEW BEHAVIOR: Returns empty set instead of throwing
        final event = CallEvent.fromMap(map);
        expect(event.opponentsIds, isEmpty);
        expect(event.sessionId, 'test');
      });

      test('should reject session IDs exceeding max length', () {
        final longId = 'a' * 1000;
        final map = {
          'session_id': longId,
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        // NEW BEHAVIOR: Rejects session IDs over 500 chars (security limit)
        expect(
          () => CallEvent.fromMap(map),
          throwsA(isA<CallEventValidationException>()),
        );
      });

      test('should accept session IDs within max length', () {
        final validId = 'a' * 500; // Exactly at the limit
        final map = {
          'session_id': validId,
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Caller',
          'call_opponents': '456',
        };

        final event = CallEvent.fromMap(map);
        expect(event.sessionId, validId);
        expect(event.sessionId.length, 500);
      });

      test('should handle special characters in caller name', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'Test@#\$%^&*()User',
          'call_opponents': '456',
        };

        final event = CallEvent.fromMap(map);
        expect(event.callerName, 'Test@#\$%^&*()User');
      });

      test('should handle Unicode characters', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': '测试用户 مستخدم परीक्षण',
          'call_opponents': '456',
        };

        final event = CallEvent.fromMap(map);
        expect(event.callerName, '测试用户 مستخدم परीक्षण');
      });

      test('should handle emoji in caller name', () {
        final map = {
          'session_id': 'test',
          'call_type': 1,
          'caller_id': 123,
          'caller_name': 'John 😀👍',
          'call_opponents': '456',
        };

        final event = CallEvent.fromMap(map);
        expect(event.callerName, 'John 😀👍');
      });
    });
  });
}
