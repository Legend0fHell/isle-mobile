import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/recognition_model.dart';
import '../utils/logger.dart';

/// TrieNode class for efficient prefix matching
class TrieNode {
  Map<String, TrieNode> children = {};
  TrieNode? parent;
  String character = '';
  bool isEndOfWord = false;
  int frequency = 0;

  TrieNode({this.parent, this.character = ''});
}

/// Trie data structure for efficient word lookup
class Trie {
  final TrieNode root = TrieNode();
  bool _isInitialized = false;
  
  // Current position in the trie for continuous searches
  TrieNode _currentNode;
  String _currentPrefix = '';

  // Singleton instance
  static final Trie _instance = Trie._internal();
  
  // Factory constructor that returns the singleton instance
  factory Trie() {
    return _instance;
  }
  
  // Private constructor
  Trie._internal() : _currentNode = TrieNode();

  // Insert a word into the trie with its frequency
  void insert(String word, int frequency) {
    TrieNode currentNode = root;
    
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      if (!currentNode.children.containsKey(char)) {
        TrieNode newNode = TrieNode(parent: currentNode, character: char);
        currentNode.children[char] = newNode;
      }
      currentNode = currentNode.children[char]!;
    }
    
    currentNode.isEndOfWord = true;
    currentNode.frequency = frequency;
  }
  
  // Continue searching from the current node or start a new search
  void setContinuationPoint(String prefix) {
    // Always store the full user prefix regardless of trie matches
    // This ensures UI displays what user types even when no suggestions match
    
    // If current prefix is a substring of the new prefix, continue from there
    if (prefix.startsWith(_currentPrefix) && _currentPrefix.isNotEmpty) {
      // Continue from current node, just process the new characters
      String newPart = prefix.substring(_currentPrefix.length);
      _continueSearch(newPart);
    } else {
      // Try to find a matching node for the new prefix
      _findMatchingNode(prefix);
    }
  }
  
  // Continue search from current node with additional characters
  void _continueSearch(String additionalChars) {
    for (int i = 0; i < additionalChars.length; i++) {
      String char = additionalChars[i];
      if (_currentNode.children.containsKey(char)) {
        _currentNode = _currentNode.children[char]!;
        _currentPrefix += char;
      } else {
        // If can't continue, reset to root but still keep track of the full prefix
        // This allows suggestions to disappear but typing to continue
        _currentNode = root;
        _currentPrefix = _currentPrefix; // Keep track of what the user has typed
        break;
      }
    }
  }
  
  // Try to find a node that matches the given prefix
  void _findMatchingNode(String prefix) {
    _currentNode = root;
    _currentPrefix = '';
    
    for (int i = 0; i < prefix.length; i++) {
      String char = prefix[i];
      if (_currentNode.children.containsKey(char)) {
        _currentNode = _currentNode.children[char]!;
        _currentPrefix += char;
      } else {
        // If no match, stop matching but keep the prefix for display
        _currentPrefix = prefix;
        break;
      }
    }
  }
  
  // Handle backspace by moving to parent node
  void handleBackspace() {
    if (_currentPrefix.isNotEmpty) {
      _currentPrefix = _currentPrefix.substring(0, _currentPrefix.length - 1);
      if (_currentNode.parent != null) {
        _currentNode = _currentNode.parent!;
      } else {
        // If somehow the parent is null, reset to root
        _currentNode = root;
        _currentPrefix = '';
      }
    }
  }
  
  // Reset the search state
  void resetSearch() {
    _currentNode = root;
    _currentPrefix = '';
  }
  
  // Find all words from the current position in the trie
  List<Map<String, dynamic>> findSuggestionsFromCurrentNode() {
    List<Map<String, dynamic>> result = [];
    
    // If we're at root with no prefix, return empty list
    if (_currentNode == root && _currentPrefix.isEmpty) {
      return result;
    }
    
    // Collect all words starting from current node
    _findAllWords(_currentNode, _currentPrefix, result);
    
    // Sort by frequency (highest first)
    result.sort((a, b) => b['frequency'].compareTo(a['frequency']));
    
    return result;
  }
  
  // Find all words in the trie that start with the given prefix
  List<Map<String, dynamic>> findWordsWithPrefix(String prefix) {
    // Set the continuation point first
    setContinuationPoint(prefix);
    
    // Then find suggestions from current node
    return findSuggestionsFromCurrentNode();
  }
  
  // Helper method to find all words from a given node
  void _findAllWords(TrieNode node, String prefix, List<Map<String, dynamic>> result) {
    if (node.isEndOfWord) {
      result.add({
        'word': prefix,
        'frequency': node.frequency
      });
    }
    
    node.children.forEach((char, childNode) {
      _findAllWords(childNode, prefix + char, result);
    });
  }
  
  bool get isInitialized => _isInitialized;
  set isInitialized(bool value) => _isInitialized = value;
  
  String get currentPrefix => _currentPrefix;
}

// Parameters for compute function
class _SuggestionParams {
  final String currentWord;
  final Trie trie;
  final int limit;
  
  _SuggestionParams(this.currentWord, this.trie, this.limit);
}

// Function to run in isolate
List<String> _generateSuggestionsInIsolate(_SuggestionParams params) {
  if (params.currentWord.isEmpty || !params.trie.isInitialized) {
    return [];
  }
  
  // Find words with the given prefix
  final suggestions = params.trie.findWordsWithPrefix(params.currentWord.toLowerCase());
  
  // Extract just the words (frequencies were already used for sorting)
  return suggestions
      .map((suggestion) => suggestion['word'] as String)
      .take(params.limit)
      .toList();
}

class TextInputService with ChangeNotifier {
  String _text = '';
  String _currentWord = '';
  List<String> _suggestions = [];
  bool _isProcessingSuggestions = false;
  
  // Trie for efficient prefix matching
  final Trie _trie = Trie();
  bool _isTrieLoaded = false;
  
  String get text => _text;
  String get currentWord => _currentWord;
  List<String> get suggestions => _suggestions;
  
  // Constructor to load the dictionary
  TextInputService() {
    _loadDictionary();
  }
  
  // Load words from CSV file
  Future<void> _loadDictionary() async {
    if (_isTrieLoaded) return;
    
    try {
      final String data = await rootBundle.loadString('assets/models/most_common_words.csv');
      final List<String> lines = const LineSplitter().convert(data);
      
      // Skip header line
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length >= 2) {
          final word = parts[0].trim().toLowerCase();
          final frequency = int.tryParse(parts[1].trim()) ?? 0;
          
          _trie.insert(word, frequency);
        }
      }
      
      _trie.isInitialized = true;
      _isTrieLoaded = true;
      AppLogger.info('Dictionary loaded successfully with ${lines.length - 1} words');
    } catch (e) {
      AppLogger.error('Error loading dictionary', e);
    }
  }
  
  void addCharacter(RecognitionResult result) {
    // Process the character input
    _processCharacterInput(result);
    
    // Always notify listeners to update UI regardless of suggestions
    notifyListeners();
    
    // Update suggestions only if we're not ending with a space
    if (_currentWord.isNotEmpty && !_currentWord.endsWith(' ')) {
      _updateSuggestionsAsync();
    } else {
      // Reset search if word ended
      _trie.resetSearch();
      // Clear suggestions if we're at a word boundary
      if (_suggestions.isNotEmpty) {
        _suggestions = [];
        notifyListeners();
      }
    }
  }

  void backspace() {
    try {
      if (_currentWord.isNotEmpty) {
        // Handle backspace in trie
        _trie.handleBackspace();
        
        _currentWord = _currentWord.substring(0, _currentWord.length - 1);
        
        // Update suggestions if we still have text
        if (_currentWord.isNotEmpty) {
          _updateSuggestionsAsync();
        } else {
          // Clear suggestions if word is empty
          if (_suggestions.isNotEmpty) {
            _suggestions = [];
            notifyListeners();
          }
        }
      } else if (_text.isNotEmpty) {
        // Remove trailing space if exists
        _text = _text.trimRight();
        int lastSpace = _text.lastIndexOf(' ');
        if (lastSpace != -1) {
          _currentWord = _text.substring(lastSpace + 1);
          _text = _text.substring(0, lastSpace);
        } else {
          _currentWord = _text;
          _text = '';
        }
        
        // Reset trie search position to match the new current word
        _trie.setContinuationPoint(_currentWord.toLowerCase());
        
        // Update suggestions for the "new" current word
        if (_currentWord.isNotEmpty) {
          _updateSuggestionsAsync();
        }
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('Error handling backspace', e);
    }
  }

  void _processCharacterInput(RecognitionResult result) {
    try {
      if (result.isDelete) {
        // Handle deletion with backspace method
        backspace();
        return;
      } else if (result.isSpace) {
        if (_currentWord.isNotEmpty) {
          // Prevent double spaces when adding a space after a word
          if (_text.isNotEmpty && _text.endsWith(' ')) {
            _text = '${_text.trimRight()} $_currentWord';
          } else {
            _text = '$_text $_currentWord';
          }
          _currentWord = '';
          // Reset trie search when word is completed
          _trie.resetSearch();
        } else if (_text.isNotEmpty) {
          // Prevent double spaces when adding a space without a word
          if (!_text.endsWith(' ')) {
            _text = '$_text ';
          }
        }
      } else if (result.character.toLowerCase() == "autocmp") {
        // Auto-complete with the first suggestion if available
        if (_suggestions.isNotEmpty) {
          selectSuggestion(_suggestions[0]);
        }
        return;
      } else {
        // Always add the character regardless of trie matching
        _currentWord += result.character;
        // No need to update trie here as it will be updated in addCharacter
      }
    } catch (e) {
      AppLogger.error('Error processing character input', e);
    }
  }
  
  Future<void> selectSuggestion(String suggestion) async {
    if (suggestion == " ") {
      // Special case for space
      if (_currentWord.isNotEmpty) {
        // Prevent double spaces
        if (_text.isNotEmpty && _text.endsWith(' ')) {
          _text = '${_text.trimRight()} $_currentWord';
        } else {
          _text = '$_text $_currentWord';
        }
        _currentWord = '';
      } else if (_text.isNotEmpty) {
        // Prevent double spaces
        if (!_text.endsWith(' ')) {
          _text = '$_text ';
        }
      }
      // Reset trie search when adding a space
      _trie.resetSearch();
    } else {
      // For selecting a suggestion word
      // Prevent double spaces
      if (_text.isNotEmpty && _text.endsWith(' ')) {
        _text = '${_text.trimRight()} $suggestion';
      } else {
        _text = '$_text $suggestion';
      }
      _currentWord = '';
      // Reset trie search when selecting a suggestion
      _trie.resetSearch();
    }
    
    // Fix any remaining multiple spaces
    _fixMultipleSpaces();
    
    _suggestions = [];
    notifyListeners();
  }
  
  // Function to fix multiple consecutive spaces
  void _fixMultipleSpaces() {
    // Use regex to replace multiple spaces with a single space
    while (_text.contains('  ')) {
      _text = _text.replaceAll('  ', ' ');
    }
  }
  
  void clearText() {
    _text = '';
    _currentWord = '';
    _suggestions = [];
    // Reset trie search when clearing text
    _trie.resetSearch();
    notifyListeners();
  }
  
  Future<void> _updateSuggestionsAsync() async {
    if (_isProcessingSuggestions || !_isTrieLoaded || _currentWord.isEmpty) return;
    
    _isProcessingSuggestions = true;
    
    try {
      // Generate suggestions in a separate isolate
      final newSuggestions = await compute(
        _generateSuggestionsInIsolate,
        _SuggestionParams(_currentWord, _trie, 4) // Limit to top 4 suggestions
      );
      
      // Always update suggestions list, even if empty
      // This ensures UI consistency with the typed characters
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