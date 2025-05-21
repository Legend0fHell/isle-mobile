import 'package:mongo_dart/mongo_dart.dart';

class Lesson {
  final ObjectId? objId; // Changed to ObjectId for MongoDB compatibility
  final int lessonId;
  final String title;
  final String description;
  final List<LessonContent> content;
  final bool open;
  final String? category; // Added for category filtering
  final String? level;    // Added for difficulty level filtering

  Lesson({
    required this.objId,
    required this.lessonId,
    required this.title,
    required this.description,
    required this.content,
    required this.open,
    this.category,
    this.level,
  });

  // Convert from MongoDB map to Lesson object
  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      objId: map['_id'] as ObjectId,
      lessonId: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String?,
      level: map['level'] as String?,
      open: map['open'] as bool,
      content: (map['content'] as List<dynamic>?)
          ?.map((contentMap) => LessonContent.fromMap(contentMap as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  // Convert to MongoDB map
  Map<String, dynamic> toMap() {
    return {
      '_id': objId,
      'id': lessonId,
      'title': title,
      'description': description,
      if (category != null) 'category': category,
      if (level != null) 'level': level,
      'content': content.map((content) => content.toMap()).toList(),
    };
  }

  // Create a copy of this lesson with optional new values
  Lesson copyWith({
    ObjectId? objId,
    int? lessonId,
    String? title,
    String? description,
    double? progress,
    List<LessonContent>? content,
    bool? open,
    String? category,
    String? level,
  }) {
    return Lesson(
      objId: objId ?? this.objId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      open: open ?? this.open,
      category: category ?? this.category,
      level: level ?? this.level,
    );
  }

  double getProgress() {
    int total_finished = 0;
    for (var eachLessonContent in content) {
      if (eachLessonContent.status == LessonContentStatus.finished) {
        total_finished += 1;
      }
    };

    return total_finished.toDouble() / content.length.toDouble();
  }
}

enum LessonContentType {
  video,
  practice,
  interactive,
  quiz,
}

class LessonContent {
  final ObjectId objId;
  final String title;
  final LessonContentType type;
  final String? resourceUrl;
  final String instructions;
  final List<String>? dialogueSteps;
  final List<String>? wordExamples;
  final List<Question>? questions;
  var status;

  LessonContent({
    required this.objId,
    required this.title,
    required this.type,
    this.resourceUrl,
    required this.instructions,
    this.dialogueSteps,
    this.wordExamples,
    this.questions,
    required this.status
  });

  // Convert from MongoDB map to LessonContent object
  factory LessonContent.fromMap(Map<String, dynamic> map) {
    for (var key in map.keys) {
      print("map[$key] = ${map[key]}");
    }
    final typeStr = map['type'] as String;
    LessonContentType contentType;

    switch (typeStr) {
      case 'video':
        contentType = LessonContentType.video;
        break;
      case 'practice':
        contentType = LessonContentType.practice;
        break;
      case 'interactive':
        contentType = LessonContentType.interactive;
        break;
      case 'quiz':
        contentType = LessonContentType.quiz;
        break;
      default:
        contentType = LessonContentType.video;
    }

    return LessonContent(
      objId: map['_id'] as ObjectId,
      title: map['title'] as String,
      type: contentType,
      resourceUrl: map['videoUrl'] as String?,
      instructions: map['instructions'] as String,
      dialogueSteps: (map['dialogueSteps'] as List<dynamic>?)?.map((step) => step as String).toList(),
      wordExamples: (map['wordExamples'] as List<dynamic>?)?.map((word) => word as String).toList(),
      questions: (map['questions'] as List<dynamic>?)
          ?.map((questionMap) => Question.fromMap(questionMap as Map<String, dynamic>))
          .toList(),
      status: map['status'] as LessonContentStatus
    );
  }

  // Convert to MongoDB map
  Map<String, dynamic> toMap() {
    String typeStr;

    switch (type) {
      case LessonContentType.video:
        typeStr = 'video';
        break;
      case LessonContentType.practice:
        typeStr = 'practice';
        break;
      case LessonContentType.interactive:
        typeStr = 'interactive';
        break;
      case LessonContentType.quiz:
        typeStr = 'quiz';
        break;
    }

    return {
      '_id': objId,
      'title': title,
      'type': typeStr,
      if (resourceUrl != null) 'resourceUrl': resourceUrl,
      'instructions': instructions,
      if (dialogueSteps != null) 'dialogueSteps': dialogueSteps,
      if (wordExamples != null) 'wordExamples': wordExamples,
      if (questions != null) 'questions': questions!.map((question) => question.toMap()).toList(),
      'status': status
    };
  }
}

enum LessonContentStatus {
  finished,
  incomplete
}


class Question {
  final String text;
  final String? imageUrl;
  final List<String> options;
  final int correctOptionIndex;

  Question({
    required this.text,
    this.imageUrl,
    required this.options,
    required this.correctOptionIndex,
  });

  // Convert from MongoDB map to Question object
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['text'] as String,
      imageUrl: map['imageUrl'] as String?,
      options: (map['options'] as List<dynamic>).map((option) => option as String).toList(),
      correctOptionIndex: map['correctOptionIndex'] as int,
    );
  }

  // Convert to MongoDB map
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }
}