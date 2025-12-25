import 'dart:convert' show json;
import 'dart:developer';

/// Exception thrown when CallEvent validation fails
class CallEventValidationException implements Exception {
  final String message;
  final String field;
  final dynamic value;

  CallEventValidationException(this.message, {required this.field, this.value});

  @override
  String toString() =>
      'CallEventValidationException: $message (field: $field, value: $value)';
}

/// Validator for CallEvent data
class CallEventValidator {
  static const String _tag = 'CallEventValidator';

  /// Validates and extracts a required string field from the map
  static String validateRequiredString(
    Map<String, dynamic> map,
    String field, {
    int? maxLength,
    bool allowEmpty = false,
  }) {
    if (!map.containsKey(field)) {
      log('[$_tag] Missing required field: $field', name: _tag, level: 900);
      throw CallEventValidationException(
        'Missing required field',
        field: field,
        value: null,
      );
    }

    final value = map[field];

    if (value == null) {
      log('[$_tag] Null value for field: $field', name: _tag, level: 900);
      throw CallEventValidationException(
        'Field cannot be null',
        field: field,
        value: null,
      );
    }

    if (value is! String) {
      log('[$_tag] Invalid type for field $field: expected String, got ${value.runtimeType}',
          name: _tag, level: 900);
      throw CallEventValidationException(
        'Field must be a String',
        field: field,
        value: value,
      );
    }

    if (!allowEmpty && value.isEmpty) {
      log('[$_tag] Empty value for field: $field', name: _tag, level: 900);
      throw CallEventValidationException(
        'Field cannot be empty',
        field: field,
        value: value,
      );
    }

    if (maxLength != null && value.length > maxLength) {
      log('[$_tag] Value too long for field $field: ${value.length} > $maxLength',
          name: _tag, level: 900);
      throw CallEventValidationException(
        'Field value exceeds maximum length of $maxLength',
        field: field,
        value: value,
      );
    }

    return value;
  }

  /// Validates and extracts a required integer field from the map
  static int validateRequiredInt(
    Map<String, dynamic> map,
    String field, {
    int? min,
    int? max,
  }) {
    if (!map.containsKey(field)) {
      log('[$_tag] Missing required field: $field', name: _tag, level: 900);
      throw CallEventValidationException(
        'Missing required field',
        field: field,
        value: null,
      );
    }

    final value = map[field];

    if (value == null) {
      log('[$_tag] Null value for field: $field', name: _tag, level: 900);
      throw CallEventValidationException(
        'Field cannot be null',
        field: field,
        value: null,
      );
    }

    int intValue;

    if (value is int) {
      intValue = value;
    } else if (value is num) {
      intValue = value.toInt();
    } else if (value is String) {
      try {
        intValue = int.parse(value);
      } catch (e) {
        log('[$_tag] Failed to parse int from string for field $field: $value',
            name: _tag, level: 900);
        throw CallEventValidationException(
          'Field must be a valid integer',
          field: field,
          value: value,
        );
      }
    } else {
      log('[$_tag] Invalid type for field $field: expected int, got ${value.runtimeType}',
          name: _tag, level: 900);
      throw CallEventValidationException(
        'Field must be an integer',
        field: field,
        value: value,
      );
    }

    if (min != null && intValue < min) {
      log('[$_tag] Value too small for field $field: $intValue < $min',
          name: _tag, level: 900);
      throw CallEventValidationException(
        'Field value must be at least $min',
        field: field,
        value: intValue,
      );
    }

    if (max != null && intValue > max) {
      log('[$_tag] Value too large for field $field: $intValue > $max',
          name: _tag, level: 900);
      throw CallEventValidationException(
        'Field value must be at most $max',
        field: field,
        value: intValue,
      );
    }

    return intValue;
  }

  /// Validates and extracts an optional string field from the map
  static String? validateOptionalString(
    Map<String, dynamic> map,
    String field, {
    int? maxLength,
  }) {
    if (!map.containsKey(field)) {
      return null;
    }

    final value = map[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      log('[$_tag] Invalid type for optional field $field: expected String, got ${value.runtimeType}',
          name: _tag, level: 800);
      return null; // Gracefully handle invalid optional fields
    }

    if (maxLength != null && value.length > maxLength) {
      log('[$_tag] Value too long for field $field: ${value.length} > $maxLength',
          name: _tag, level: 800);
      return null; // Gracefully handle invalid optional fields
    }

    return value;
  }

  /// Validates and parses opponent IDs from a comma-separated string
  static Set<int> validateOpponentIds(
    Map<String, dynamic> map,
    String field,
  ) {
    final opponentsString = validateRequiredString(map, field, allowEmpty: true);

    if (opponentsString.isEmpty) {
      log('[$_tag] Empty opponents list', name: _tag, level: 800);
      return {};
    }

    try {
      final opponents = opponentsString
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) {
            final trimmed = s.trim();
            final id = int.tryParse(trimmed);
            if (id == null) {
              log('[$_tag] Failed to parse opponent ID: $trimmed',
                  name: _tag, level: 900);
              throw CallEventValidationException(
                'Invalid opponent ID format',
                field: field,
                value: trimmed,
              );
            }
            return id;
          })
          .toSet();

      if (opponents.isEmpty) {
        log('[$_tag] No valid opponent IDs found in: $opponentsString',
            name: _tag, level: 900);
        throw CallEventValidationException(
          'At least one valid opponent ID required',
          field: field,
          value: opponentsString,
        );
      }

      return opponents;
    } catch (e) {
      if (e is CallEventValidationException) {
        rethrow;
      }
      log('[$_tag] Unexpected error parsing opponents: $e', name: _tag, level: 1000);
      throw CallEventValidationException(
        'Failed to parse opponent IDs: $e',
        field: field,
        value: opponentsString,
      );
    }
  }

  /// Validates and parses user info JSON
  static Map<String, String>? validateUserInfo(
    Map<String, dynamic> map,
    String field,
  ) {
    if (!map.containsKey(field)) {
      return null;
    }

    final value = map[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      log('[$_tag] Invalid type for field $field: expected JSON string, got ${value.runtimeType}',
          name: _tag, level: 800);
      return null;
    }

    if (value.isEmpty) {
      return null;
    }

    try {
      final decoded = json.decode(value);
      if (decoded is! Map) {
        log('[$_tag] User info JSON is not a map: $value', name: _tag, level: 800);
        return null;
      }

      return Map<String, String>.from(decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ));
    } catch (e) {
      log('[$_tag] Failed to parse user info JSON: $value, error: $e',
          name: _tag, level: 800);
      return null; // Gracefully handle invalid JSON in optional field
    }
  }
}
