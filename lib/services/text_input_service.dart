import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recognition_model.dart';
import '../utils/logger.dart';

// Parameters for compute function
class _SuggestionParams {
  final String currentWord;
  final List<String> commonWords;
  
  _SuggestionParams(this.currentWord, this.commonWords);
}

// Function to run in isolate
List<String> _generateSuggestionsInIsolate(_SuggestionParams params) {
  if (params.currentWord.isEmpty) {
    return [];
  }
  
  return params.commonWords
      .where((word) => word.startsWith(params.currentWord.toLowerCase()))
      .take(5)
      .toList();
}

class TextInputService with ChangeNotifier {
  String _text = '';
  String _currentWord = '';
  List<String> _suggestions = [];
  bool _isProcessingSuggestions = false;
  
  // Common words for auto-completion
  final List<String> _commonWords = [
    'hello', 'world', 'sign', 'language', 'recognition',
    'thank', 'you', 'please', 'help', 'need', 'want',
    'good', 'morning', 'afternoon', 'evening', 'night',
    'today', 'tomorrow', 'yesterday', 'now', 'later', 
    'yes', 'no', 'maybe', 'okay', 'fine', 'great',
    'sorry', 'excuse', 'me', 'welcome', 'goodbye',
    'name', 'is', 'my', 'what', 'where', 'when', 'how',
    'why', 'who', 'which', 'can', 'could', 'would', 'should',
    'will', 'shall', 'may', 'might', 'must', 'have', 'has',
    'had', 'do', 'does', 'did', 'am', 'is', 'are', 'was', 'were',
    'be', 'been', 'being'
  ];
  
  String get text => _text;
  String get currentWord => _currentWord;
  List<String> get suggestions => _suggestions;
  
  void addCharacter(RecognitionResult result) {
    // Process the character input
    _processCharacterInput(result);
    
    // Update suggestions asynchronously
    _updateSuggestionsAsync();
    
    // Notify listeners immediately after input
    notifyListeners();
  }
  
  void _processCharacterInput(RecognitionResult result) {
    try {
      if (result.isDelete) {
        if (_currentWord.isNotEmpty) {
          _currentWord = _currentWord.substring(0, _currentWord.length - 1);
        } else if (_text.isNotEmpty) {
          _text = _text.substring(0, _text.length - 1);
        }
      } else if (result.isSpace) {
        if (_currentWord.isNotEmpty) {
          _text = '$_text $_currentWord';
          _currentWord = '';
        } else if (_text.isNotEmpty) {
          _text = '$_text ';
        }
      } else {
        _currentWord += result.character;
      }
    } catch (e) {
      AppLogger.error('Error processing character input', e);
    }
  }
  
  Future<void> selectSuggestion(String suggestion) async {
    _text = '$_text $suggestion';
    _currentWord = '';
    _suggestions = [];
    notifyListeners();
  }
  
  void clearText() {
    _text = '';
    _currentWord = '';
    _suggestions = [];
    notifyListeners();
  }
  
  Future<void> _updateSuggestionsAsync() async {
    if (_isProcessingSuggestions) return;
    
    _isProcessingSuggestions = true;
    
    try {
      // Generate suggestions in a separate isolate
      final newSuggestions = await compute(
        _generateSuggestionsInIsolate,
        _SuggestionParams(_currentWord, _commonWords)
      );
      
      // Only update if the results are different
      if (!_areListsEqual(_suggestions, newSuggestions)) {
        _suggestions = newSuggestions;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error generating suggestions', e);
    } finally {
      _isProcessingSuggestions = false;
    }
  }
  
  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    
    return true;
  }
} 