import 'package:flutter/foundation.dart';

/// Displays how a scene should modify the base gameplay.
enum SceneMode {
  classic,
  hiddenClues,
  timed,
}

@immutable
class SceneDefinition {
  const SceneDefinition({
    required this.index,
    required this.title,
    required this.mode,
    this.timeLimit,
  });

  final int index;
  final String title;
  final SceneMode mode;
  final Duration? timeLimit;
}

@immutable
class StageDefinition {
  const StageDefinition({
    required this.index,
    required this.name,
    required this.themeName,
    required this.scenes,
  });

  final int index;
  final String name;
  final String themeName;
  final List<SceneDefinition> scenes;
}

class StagePlaybook {
  const StagePlaybook._();

  static List<StageDefinition> getAllStages() => [
        stageOne(),
        stageTwo(),
        stageThree(),
        stageFour(),
    stageFive(),
    stageSix(),
    stageSeven(),
    stageEight(),
    stageNine(),
    stageTen(),
      ];

  static StageDefinition stageOne() => const StageDefinition(
    index: 1,
  name: 'GenZ Stars',
    themeName: 'GenZ Stars',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageTwo() => const StageDefinition(
    index: 2,
  name: 'Millenial Stars',
    themeName: 'Millenial Stars',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageThree() => const StageDefinition(
    index: 3,
  name: 'South Heroes',
    themeName: 'South Heroes',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageFour() => const StageDefinition(
    index: 4,
  name: 'Golden Voices',
    themeName: 'Golden Voices',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageFive() => const StageDefinition(
    index: 5,
  name: '80s and 90s',
    themeName: '80s and 90s',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageSix() => const StageDefinition(
    index: 6,
  name: 'Filmy Family',
    themeName: 'Filmy Family',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageSeven() => const StageDefinition(
    index: 7,
  name: 'Beyond India',
    themeName: 'Beyond India',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageEight() => const StageDefinition(
    index: 8,
  name: 'Dance Dance',
    themeName: 'Dance Dance',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageNine() => const StageDefinition(
    index: 9,
  name: 'Bad Men',
    themeName: 'Bad Men',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );

  static StageDefinition stageTen() => const StageDefinition(
    index: 10,
  name: 'B&W era',
    themeName: 'B&W era',
        scenes: [
          SceneDefinition(
            index: 1,
            title: 'Spotlight Search',
            mode: SceneMode.classic,
          ),
          SceneDefinition(
            index: 2,
            title: 'Hidden Names',
            mode: SceneMode.hiddenClues,
          ),
          SceneDefinition(
            index: 3,
            title: 'Lightning Round',
            mode: SceneMode.timed,
            timeLimit: Duration(seconds: 90),
          ),
        ],
      );
}
