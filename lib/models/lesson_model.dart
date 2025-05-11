class Lesson {
  final int id;
  final String title;
  final String description;
  final double progress;
  final List<LessonContent> content;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    this.progress = 0.0,
    required this.content,
  });

  // Factory method to create Lesson 1
  factory Lesson.commonWords() {
    return Lesson(
      id: 1,
      title: 'Lesson 1',
      description: 'The common words: Hello, How are you?, What\'s your name?',
      progress: 1.0,
      content: [
        // Introduction video
        LessonContent(
          title: 'Introduction',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/lesson1_intro.mp4',
          instructions: 'Watch this introduction to learn the basic greetings in sign language.',
        ),

        // Hello demonstration
        LessonContent(
          title: 'Hello',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/hello_sign.mp4',
          instructions: 'Watch how to sign "Hello".',
        ),

        // Hello practice
        LessonContent(
          title: 'Practice: Hello',
          type: LessonContentType.practice,
          resourceUrl: 'assets/videos/hello_sign.mp4',
          instructions: 'Practice signing "Hello" and record yourself to compare.',
        ),

        // How are you demonstration
        LessonContent(
          title: 'How are you?',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/how_are_you_sign.mp4',
          instructions: 'Watch how to sign "How are you?"',
        ),

        // How are you practice
        LessonContent(
          title: 'Practice: How are you?',
          type: LessonContentType.practice,
          resourceUrl: 'assets/videos/how_are_you_sign.mp4',
          instructions: 'Practice signing "How are you?" and record yourself to compare.',
        ),

        // What's your name demonstration
        LessonContent(
          title: 'What\'s your name?',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/whats_your_name_sign.mp4',
          instructions: 'Watch how to sign "What\'s your name?"',
        ),

        // What's your name practice
        LessonContent(
          title: 'Practice: What\'s your name?',
          type: LessonContentType.practice,
          resourceUrl: 'assets/videos/whats_your_name_sign.mp4',
          instructions: 'Practice signing "What\'s your name?" and record yourself to compare.',
        ),

        // Interactive dialogue
        LessonContent(
          title: 'Interactive Dialogue',
          type: LessonContentType.interactive,
          instructions: 'Practice a conversation using the signs you\'ve learned.',
          dialogueSteps: [
            'Hello',
            'How are you?',
            'What\'s your name?',
          ],
        ),

        // Quiz
        LessonContent(
          title: 'Review Quiz',
          type: LessonContentType.quiz,
          instructions: 'Test your knowledge of the signs you\'ve learned.',
          questions: [
            Question(
              text: 'Which sign represents "Hello"?',
              options: [
                'assets/images/hello_sign.jpg',
                'assets/images/how_are_you_sign.jpg',
                'assets/images/whats_your_name_sign.jpg',
                'assets/images/thank_you_sign.jpg',
              ],
              correctOptionIndex: 0,
            ),
            Question(
              text: 'Which phrase does this sign represent?',
              imageUrl: 'assets/images/how_are_you_sign.jpg',
              options: [
                'Hello',
                'How are you?',
                'What\'s your name?',
                'Thank you',
              ],
              correctOptionIndex: 1,
            ),
            Question(
              text: 'Which phrase does this sign represent?',
              imageUrl: 'assets/images/whats_your_name_sign.jpg',
              options: [
                'Hello',
                'How are you?',
                'What\'s your name?',
                'Thank you',
              ],
              correctOptionIndex: 2,
            ),
          ],
        ),
      ],
    );
  }

  // Factory method to create Lesson 2
  factory Lesson.vowels() {
    return Lesson(
      id: 2,
      title: 'Lesson 2',
      description: 'The vowels: A, E, I, O, U',
      progress: 0.5,
      content: [
        // Introduction video
        LessonContent(
          title: 'Introduction to Vowels',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/vowels_intro.mp4',
          instructions: 'Watch this introduction to learn vowels in sign language.',
        ),

        // A demonstration
        LessonContent(
          title: 'Letter A',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/a_sign.mp4',
          instructions: 'Watch how to sign the letter "A".',
        ),

        // A practice
        LessonContent(
          title: 'Practice: Letter A',
          type: LessonContentType.practice,
          resourceUrl: 'assets/videos/a_sign.mp4',
          instructions: 'Practice signing the letter "A" and record yourself to compare.',
        ),

        // Similar pattern for other vowels: E, I, O, U
        // ... (abbreviated for brevity) ...

        // Vowel sequence practice
        LessonContent(
          title: 'Vowel Sequence',
          type: LessonContentType.interactive,
          instructions: 'Practice signing all vowels in sequence: A, E, I, O, U',
        ),

        // Words with vowels
        LessonContent(
          title: 'Words with Vowels',
          type: LessonContentType.interactive,
          instructions: 'Practice signing simple words that prominently feature each vowel.',
          wordExamples: [
            'APE', 'EAT', 'ICE', 'OAT', 'USE'
          ],
        ),

        // Quiz
        LessonContent(
          title: 'Vowels Quiz',
          type: LessonContentType.quiz,
          instructions: 'Test your knowledge of the vowels in sign language.',
          questions: [
            Question(
              text: 'Which sign represents the letter "A"?',
              options: [
                'assets/images/a_sign.jpg',
                'assets/images/e_sign.jpg',
                'assets/images/i_sign.jpg',
                'assets/images/o_sign.jpg',
              ],
              correctOptionIndex: 0,
            ),
            // More quiz questions...
          ],
        ),
      ],
    );
  }

  // Factory method to create Lesson 3
  factory Lesson.consonants() {
    return Lesson(
      id: 3,
      title: 'Lesson 3',
      description: 'The common consonants: A, E, I, O, U',
      progress: 0.0,
      content: [
        // Introduction video
        LessonContent(
          title: 'Introduction to Consonants',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/consonants_intro.mp4',
          instructions: 'Watch this introduction to learn common consonants in sign language.',
        ),

        // Consonant groups
        LessonContent(
          title: 'Similar Hand Shape Group 1: B, C, D',
          type: LessonContentType.video,
          resourceUrl: 'assets/videos/bcd_signs.mp4',
          instructions: 'Watch how to sign the letters B, C, and D which have similar hand shapes.',
        ),

        // Practice for group 1
        LessonContent(
          title: 'Practice: B, C, D',
          type: LessonContentType.practice,
          resourceUrl: 'assets/videos/bcd_signs.mp4',
          instructions: 'Practice signing the letters B, C, and D and record yourself to compare.',
        ),

        // More consonant groups and practice sessions
        // ... (abbreviated for brevity) ...

        // Combining vowels and consonants
        LessonContent(
          title: 'Combining Letters',
          type: LessonContentType.interactive,
          instructions: 'Practice combining consonants and vowels to form simple syllables and words.',
          wordExamples: [
            'BAT', 'CAT', 'DOG', 'PEN', 'SIT'
          ],
        ),

        // Quiz
        LessonContent(
          title: 'Consonants Quiz',
          type: LessonContentType.quiz,
          instructions: 'Test your knowledge of the consonants in sign language.',
          questions: [
            Question(
              text: 'Which sign represents the letter "B"?',
              options: [
                'assets/images/b_sign.jpg',
                'assets/images/p_sign.jpg',
                'assets/images/d_sign.jpg',
                'assets/images/t_sign.jpg',
              ],
              correctOptionIndex: 0,
            ),
            // More quiz questions...
          ],
        ),
      ],
    );
  }
}

enum LessonContentType {
  video,
  practice,
  interactive,
  quiz,
}

class LessonContent {
  final String title;
  final LessonContentType type;
  final String? resourceUrl;
  final String instructions;
  final List<String>? dialogueSteps;
  final List<String>? wordExamples;
  final List<Question>? questions;

  LessonContent({
    required this.title,
    required this.type,
    this.resourceUrl,
    required this.instructions,
    this.dialogueSteps,
    this.wordExamples,
    this.questions,
  });
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
}