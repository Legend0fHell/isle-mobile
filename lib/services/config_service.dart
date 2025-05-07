import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  bool _isEmulatorMode = false;
  final MethodChannel _channel = const MethodChannel('com.uet.isle/hand_landmark');
  
  bool get isEmulatorMode => _isEmulatorMode;

  Future<void> initialize() async {
    await dotenv.load();
    
    // Read configuration from .env file
    _isEmulatorMode = dotenv.env['EMU_SUPPORT'] == 'true';
    
    // Log configuration for debugging
    debugPrint('ConfigService initialized:');
    debugPrint('- EMU_SUPPORT: $_isEmulatorMode');
    
    // If on mobile platform, pass emulator mode to native code
    if (!kIsWeb) {
      try {
        await _channel.invokeMethod('setEmulatorMode', {'enabled': _isEmulatorMode});
        debugPrint('Set native EMU_SUPPORT to $_isEmulatorMode');
      } catch (e) {
        debugPrint('Error setting native EMU_SUPPORT: $e');
      }
    }
  }
} 