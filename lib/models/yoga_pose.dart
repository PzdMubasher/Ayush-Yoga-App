import 'package:flutter/material.dart';

enum PoseType {
  tree,
  warrior,
  plank,
  mountain,
}

class YogaPose {
  final String name;
  final String description;
  final PoseType type;
  final String instruction;
  final String imageUrl;

  YogaPose({
    required this.name,
    required this.description,
    required this.type,
    required this.instruction,
    required this.imageUrl,
  });

  static List<YogaPose> get poses => [
        YogaPose(
          name: 'Tree Pose',
          description: 'Vrikshasana - Improves balance and stability.',
          type: PoseType.tree,
          instruction: 'Place your foot on your inner thigh. Reach your arms to the sky.',
          imageUrl: 'assets/images/tree_pose.png',
        ),
        YogaPose(
          name: 'Warrior Pose',
          description: 'Virabhadrasana - Strengthens legs and opens hips.',
          type: PoseType.warrior,
          instruction: 'Extend your arms at shoulder height. Bend your front knee.',
          imageUrl: 'assets/images/warrior_pose.png',
        ),
        YogaPose(
          name: 'Plank Pose',
          description: 'Phalakasana - Strengthens the core.',
          type: PoseType.plank,
          instruction: 'Hold your body in a straight line from head to heels.',
          imageUrl: 'assets/images/plank_pose.png',
        ),
        YogaPose(
          name: 'Mountain Pose',
          description: 'Tadasana - Improves posture and focus.',
          type: PoseType.mountain,
          instruction: 'Stand tall and lengthen your spine. Keep arms by your side.',
          imageUrl: 'assets/images/mountain_pose.png',
        ),
      ];
}
