import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'rentpulse_pin_hash';
  static const _pinEnabledKey = 'rentpulse_pin_enabled';

  /// Hashes a 4-digit PIN with a fixed salt using SHA-256
  static String _hashPin(String pin) {
    const salt = 'rentpulse_offline_salt_2026';
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  /// Sets or updates the 4-digit PIN
  static Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: 'true');
  }

  /// Verifies entered PIN against stored hash
  static Future<bool> verifyPin(String enteredPin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return true; // No PIN configured
    return storedHash == _hashPin(enteredPin);
  }

  /// Checks if PIN lock is currently enabled
  static Future<bool> isPinEnabled() async {
    final enabled = await _storage.read(key: _pinEnabledKey);
    final hash = await _storage.read(key: _pinKey);
    return enabled == 'true' && hash != null && hash.isNotEmpty;
  }

  /// Disables PIN lock
  static Future<void> disablePin() async {
    await _storage.write(key: _pinEnabledKey, value: 'false');
    await _storage.delete(key: _pinKey);
  }
}
