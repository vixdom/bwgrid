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
      ];

  static StageDefinition stageOne() => const StageDefinition(
        index: 1,
        name: 'Screen 1',
        themeName: 'Nostalgia',
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
        name: 'Screen 2',
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

  static StageDefinition stageThree() => const StageDefinition(
        index: 3,
        name: 'Screen 3',
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

  static StageDefinition stageFour() => const StageDefinition(
        index: 4,
        name: 'Screen 4',
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

  static StageDefinition stageFive() => const StageDefinition(
        index: 5,
        name: 'Screen 5',
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
}
