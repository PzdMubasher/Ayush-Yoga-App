import 'package:flutter/material.dart';

enum PoseType { beginner, weightLoss, meditation, strength, morning, sleep, therapy, women, office, heart, breathing, energy, kids, surya, power, other }

class YogaCategory {
  final String name;
  final String description;
  final String icon;
  final Color color;
  final List<YogaPose> poses;

  YogaCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.poses,
  });

  static List<YogaCategory> get categories => [
    YogaCategory(name: 'Beginner Yoga', description: 'Basic foundation poses', icon: '🧘', color: Colors.teal, 
      poses: YogaPose.poses.where((p) => p.tags.contains('beginner')).toList()),
    YogaCategory(name: 'Weight Loss', description: 'Burn calories fast', icon: '🔥', color: Colors.orange, 
      poses: YogaPose.poses.where((p) => p.tags.contains('weightLoss')).toList()),
    YogaCategory(name: 'Meditation', description: 'Find your inner peace', icon: '😌', color: Colors.purple, 
      poses: YogaPose.poses.where((p) => p.tags.contains('meditation')).toList()),
    YogaCategory(name: 'Strength', description: 'Build muscle & power', icon: '💪', color: Colors.red, 
      poses: YogaPose.poses.where((p) => p.tags.contains('strength')).toList()),
    YogaCategory(name: 'Morning Yoga', description: 'Start your day fresh', icon: '☀️', color: Colors.amber, 
      poses: YogaPose.poses.where((p) => p.tags.contains('morning')).toList()),
    YogaCategory(name: 'Sleep Yoga', description: 'Relax for deep rest', icon: '🌙', color: Colors.indigo, 
      poses: YogaPose.poses.where((p) => p.tags.contains('sleep')).toList()),
    YogaCategory(name: 'Therapy Yoga', description: 'Healing & pain relief', icon: '🩺', color: Colors.blue, 
      poses: YogaPose.poses.where((p) => p.tags.contains('therapy')).toList()),
    YogaCategory(name: 'Women’s Yoga', description: 'Female health focus', icon: '👩', color: Colors.pink, 
      poses: YogaPose.poses.where((p) => p.tags.contains('women')).toList()),
    YogaCategory(name: 'Office Stretch', description: 'Relieve desk stress', icon: '🧍', color: Colors.brown, 
      poses: YogaPose.poses.where((p) => p.tags.contains('office')).toList()),
    YogaCategory(name: 'Breathing', description: 'Pranayama exercises', icon: '🫁', color: Colors.lightBlue, 
      poses: YogaPose.poses.where((p) => p.tags.contains('breathing')).toList()),
    YogaCategory(name: 'Energy Boost', description: 'Wake up your body', icon: '⚡', color: Colors.yellow, 
      poses: YogaPose.poses.where((p) => p.tags.contains('energy')).toList()),
    YogaCategory(name: 'Kids Yoga', description: 'Fun yoga for children', icon: '🧒', color: Colors.pinkAccent, 
      poses: YogaPose.poses.where((p) => p.tags.contains('kids')).toList()),
    YogaCategory(name: 'Surya Namaskar', description: 'Sun Salutation sequence', icon: '🧎', color: Colors.orangeAccent, 
      poses: YogaPose.poses.where((p) => p.tags.contains('surya')).toList()),
    YogaCategory(name: 'Power Yoga', description: 'High intensity flow', icon: '🔥', color: Colors.redAccent, 
      poses: YogaPose.poses.where((p) => p.tags.contains('power')).toList()),
  ];
}

class YogaPose {
  final String name;
  final String description;
  final List<String> benefits;
  final List<String> tags;
  final String imageUrl;

  YogaPose({
    required this.name,
    required this.description,
    required this.benefits,
    required this.tags,
    required this.imageUrl,
  });

  static List<YogaPose> get poses => [
    // --- BEGINNER ---
    YogaPose(name: 'Mountain Pose', description: 'Tadasana - Basic standing', benefits: ['Fixes posture', 'Improves balance'], tags: ['beginner', 'morning', 'therapy'], imageUrl: 'assets/images/mountain_pose.png'),
    YogaPose(name: 'Child Pose', description: 'Balasana - Relaxation', benefits: ['Calms mind', 'Stretches back'], tags: ['beginner', 'sleep', 'therapy'], imageUrl: 'assets/images/child_pose.png'),
    YogaPose(name: 'Cat-Cow Pose', description: 'Spinal flexibility', benefits: ['Relieves back pain', 'Stretches spine'], tags: ['beginner', 'therapy', 'women', 'office'], imageUrl: 'assets/images/cat_cow.png'),
    YogaPose(name: 'Cobra Pose', description: 'Bhujangasana', benefits: ['Back flexibility', 'Opens chest'], tags: ['beginner', 'strength', 'morning', 'therapy'], imageUrl: 'assets/images/cobra_pose.png'),
    YogaPose(name: 'Downward Dog', description: 'Adho Mukha Svanasana', benefits: ['Stretches body', 'Improves circulation'], tags: ['beginner', 'strength', 'energy'], imageUrl: 'assets/images/downward_dog.png'),
    YogaPose(name: 'Tree Pose', description: 'Vrikshasana - Balance', benefits: ['Balance', 'Leg strength'], tags: ['beginner', 'kids', 'energy'], imageUrl: 'assets/images/tree_pose.png'),

    // --- WEIGHT LOSS & POWER ---
    YogaPose(name: 'Surya Namaskar', description: '12-step Sun Salutation', benefits: ['Full body detox', 'Weight loss'], tags: ['surya', 'weightLoss', 'energy', 'morning'], imageUrl: 'assets/images/category_surya.png'),
    YogaPose(name: 'Boat Pose', description: 'Navasana - Core power', benefits: ['Strengthens abs', 'Improves digestion'], tags: ['weightLoss', 'strength'], imageUrl: 'assets/images/boat_pose.png'),
    YogaPose(name: 'Plank Pose', description: 'Phalakasana', benefits: ['Core strength', 'Tones arms'], tags: ['strength', 'weightLoss', 'power', 'energy'], imageUrl: 'assets/images/plank_pose.png'),
    YogaPose(name: 'Warrior II', description: 'Virabhadrasana II', benefits: ['Leg strength', 'Stamina'], tags: ['strength', 'weightLoss', 'power', 'energy', 'morning'], imageUrl: 'assets/images/warrior_pose.png'),
    YogaPose(name: 'Warrior I', description: 'Virabhadrasana I', benefits: ['Focus', 'Lower body strength'], tags: ['strength', 'energy'], imageUrl: 'assets/images/warrior1_step2.png'),
    YogaPose(name: 'Warrior III', description: 'Virabhadrasana III', benefits: ['Balance', 'Core strength'], tags: ['strength', 'power', 'energy'], imageUrl: 'assets/images/warrior3_pose.png'),
    YogaPose(name: 'Extended Side Angle', description: 'Utthita Parsvakonasana', benefits: ['Stretches legs', 'Opens chest'], tags: ['strength', 'morning'], imageUrl: 'assets/images/extended_side_angle.png'),
    YogaPose(name: 'Triangle Pose', description: 'Trikonasana', benefits: ['Stretches hips', 'Improves digestion'], tags: ['strength', 'morning'], imageUrl: 'assets/images/triangle_pose.png'),
    YogaPose(name: 'Chair Pose', description: 'Utkatasana', benefits: ['Strengthens thighs', 'Improves posture'], tags: ['beginner', 'strength', 'morning'], imageUrl: 'assets/images/chair_pose.png'),
    YogaPose(name: 'Half Moon Pose', description: 'Ardha Chandrasana', benefits: ['Coordination', 'Core power'], tags: ['strength', 'power', 'energy'], imageUrl: 'assets/images/half_moon.png'),
    YogaPose(name: 'Bridge Pose', description: 'Setu Bandhasana', benefits: ['Thyroid health', 'Back strength'], tags: ['weightLoss', 'women', 'therapy', 'strength'], imageUrl: 'assets/images/bridge_pose.png'),

    // --- MEDITATION & BREATHING ---
    YogaPose(name: 'Deep Breathing', description: 'Calm your system', benefits: ['Reduces anxiety', 'Lowers heart rate'], tags: ['meditation', 'breathing'], imageUrl: 'assets/images/meditation.png'),
    YogaPose(name: 'Lotus Pose', description: 'Padmasana - Classic meditation', benefits: ['Improves focus', 'Calms mind'], tags: ['meditation'], imageUrl: 'assets/images/lotus_pose.png'),
    YogaPose(name: 'Anulom Vilom', description: 'Alternate Nostril Breathing', benefits: ['Stress relief', 'Mental clarity'], tags: ['breathing', 'meditation', 'sleep'], imageUrl: 'assets/images/meditation.png'),
    YogaPose(name: 'Kapalbhati', description: 'Skull Shining Breath', benefits: ['Digestive health', 'Energizes body'], tags: ['breathing', 'energy'], imageUrl: 'assets/images/meditation.png'),
    YogaPose(name: 'Bhramari', description: 'Bee Breath', benefits: ['Calms nervous system', 'Focus'], tags: ['breathing', 'meditation'], imageUrl: 'assets/images/meditation.png'),
    YogaPose(name: 'Savasana', description: 'Corpse Pose', benefits: ['Deep relaxation', 'Reduces BP'], tags: ['meditation', 'sleep'], imageUrl: 'assets/images/savasana.png'),

    // --- STRENGTH & FLEXIBILITY ---
    YogaPose(name: 'Side Plank', description: 'Vasisthasana', benefits: ['Oblique strength', 'Balance'], tags: ['strength', 'power'], imageUrl: 'assets/images/side_plank.png'),
    YogaPose(name: 'Dolphin Pose', description: 'Shoulder opener', benefits: ['Strengthens arms', 'Calms brain'], tags: ['strength'], imageUrl: 'assets/images/dolphin_pose.png'),
    YogaPose(name: 'Camel Pose', description: 'Ustrasana', benefits: ['Opens heart', 'Improves posture'], tags: ['strength', 'energy'], imageUrl: 'assets/images/camel_pose.png'),
    YogaPose(name: 'Bow Pose', description: 'Dhanurasana', benefits: ['Stretches front body', 'Strong back'], tags: ['strength', 'power'], imageUrl: 'assets/images/bow_pose.png'),

    // --- THERAPY & WOMEN ---
    YogaPose(name: 'Butterfly Pose', description: 'Baddha Konasana', benefits: ['Pelvic health', 'Stress relief'], tags: ['women', 'therapy', 'kids'], imageUrl: 'assets/images/butterfly_pose.png'),
    YogaPose(name: 'Pigeon Pose', description: 'Eka Pada Rajakapotasana', benefits: ['Deep hip stretch', 'Relieves tension'], tags: ['therapy', 'women', 'strength'], imageUrl: 'assets/images/pigeon_pose.png'),
    YogaPose(name: 'Garland Pose', description: 'Malasana', benefits: ['Hip mobility', 'Strengthens ankles'], tags: ['beginner', 'women', 'therapy'], imageUrl: 'assets/images/garland_pose.png'),
    YogaPose(name: 'Eagle Pose', description: 'Garudasana', benefits: ['Joint health', 'Balance'], tags: ['strength', 'energy', 'power'], imageUrl: 'assets/images/eagle_pose.png'),
    YogaPose(name: 'Fish Pose', description: 'Matsyasana', benefits: ['Opens chest', 'Improves breathing'], tags: ['therapy', 'breathing', 'meditation'], imageUrl: 'assets/images/fish_pose.png'),
    YogaPose(name: 'Goddess Pose', description: 'Utkata Konasana', benefits: ['Hip strength', 'Female wellness'], tags: ['women'], imageUrl: 'assets/images/goddess_pose.png'),
    YogaPose(name: 'Neck Stretch', description: 'Relieve neck tension', benefits: ['Fixes neck pain'], tags: ['office', 'therapy'], imageUrl: 'assets/images/neck_stretch.png'),
    YogaPose(name: 'Shoulder Rolls', description: 'Open shoulders', benefits: ['Relieves tension'], tags: ['office', 'therapy'], imageUrl: 'assets/images/shoulder_rolls.png'),
    
    // --- OFFICE ---
    YogaPose(name: 'Chair Twist', description: 'Seated spinal twist', benefits: ['Relieves back pain', 'Digestive health'], tags: ['office', 'therapy'], imageUrl: 'assets/images/chair_twist.png'),
    YogaPose(name: 'Wrist Stretch', description: 'Relieve typing stress', benefits: ['Carpal tunnel relief'], tags: ['office'], imageUrl: 'assets/images/wrist_stretch.png'),

    // --- POWER YOGA ---
    YogaPose(name: 'Crow Pose', description: 'Bakasana - Arm balance', benefits: ['Arm strength', 'Balance'], tags: ['power', 'strength'], imageUrl: 'assets/images/crow_pose.png'),
    YogaPose(name: 'Chaturanga', description: 'Low Plank', benefits: ['Full body strength', 'Tones arms'], tags: ['power', 'strength'], imageUrl: 'assets/images/chaturanga.png'),
    
    // --- KIDS ---
    YogaPose(name: 'Frog Pose', description: 'Fun leg stretch', benefits: ['Hip opening', 'Fun for kids'], tags: ['kids'], imageUrl: 'assets/images/frog_pose.png'),
    YogaPose(name: 'Lion Breath', description: 'Relieve tension', benefits: ['Face muscle relaxation'], tags: ['kids', 'energy'], imageUrl: 'assets/images/lion_breath.png'),

    // --- NEW POSES ---
    YogaPose(name: 'Reverse Warrior', description: 'Side stretch lunge', benefits: ['Stretches side waist', 'Improves balance'], tags: ['strength', 'morning', 'energy'], imageUrl: 'assets/images/reverse_warrior.png'),
    YogaPose(name: 'Dancer Pose', description: 'Natarajasana - Balancing backbend', benefits: ['Improves balance', 'Stretches shoulders'], tags: ['strength', 'power', 'energy'], imageUrl: 'assets/images/dancer_pose.png'),
    YogaPose(name: 'Handstand', description: 'Adho Mukha Vrksasana', benefits: ['Upper body strength', 'Balance'], tags: ['strength', 'power'], imageUrl: 'assets/images/handstand.png'),
    YogaPose(name: 'Headstand', description: 'Sirsasana - King of poses', benefits: ['Improves focus', 'Core strength'], tags: ['strength', 'power', 'energy'], imageUrl: 'assets/images/headstand.png'),
    YogaPose(name: 'Wheel Pose', description: 'Urdhva Dhanurasana', benefits: ['Back flexibility', 'Strengthens arms'], tags: ['strength', 'power', 'morning'], imageUrl: 'assets/images/wheel_pose.png'),
    YogaPose(name: 'Hero Pose', description: 'Virasana - Kneeling posture', benefits: ['Stretches thighs', 'Improves posture'], tags: ['beginner', 'therapy', 'sleep'], imageUrl: 'assets/images/hero_pose.png'),
    YogaPose(name: 'Seated Forward Bend', description: 'Paschimottanasana', benefits: ['Stretches spine', 'Calms mind'], tags: ['beginner', 'therapy', 'sleep'], imageUrl: 'assets/images/forward_bend.png'),
    YogaPose(name: 'Happy Baby Pose', description: 'Ananda Balasana', benefits: ['Opens inner hips', 'Relieves back tension'], tags: ['beginner', 'women', 'sleep', 'kids'], imageUrl: 'assets/images/happy_baby_pose.png'),
    YogaPose(name: 'Locust Pose', description: 'Salabhasana - Core backbend', benefits: ['Strengthens spine', 'Improves posture'], tags: ['strength', 'weightLoss'], imageUrl: 'assets/images/locust_pose.png'),
    YogaPose(name: 'Puppy Pose', description: 'Uttana Shishosana - Heart opener', benefits: ['Stretches spine', 'Opens shoulders'], tags: ['beginner', 'therapy', 'sleep'], imageUrl: 'assets/images/puppy_pose.png'),

    // --- 11 MORE NEW POSES ---
    YogaPose(name: 'Firefly Pose', description: 'Tittibhasana - Arm balance stretch', benefits: ['Strengthens wrists', 'Stretches inner groins'], tags: ['strength', 'power'], imageUrl: 'assets/images/firefly_pose.png'),
    YogaPose(name: 'Peacock Pose', description: 'Mayurasana - Advanced arm balance', benefits: ['Detoxifies body', 'Core strength'], tags: ['strength', 'power'], imageUrl: 'assets/images/peacock_pose.png'),
    YogaPose(name: 'Eight Angle Pose', description: 'Astavakrasana - Hand balance twist', benefits: ['Strengthens arms', 'Improves digestion'], tags: ['strength', 'power'], imageUrl: 'assets/images/eight_angle_pose.png'),
    YogaPose(name: 'Side Crow Pose', description: 'Parsva Bakasana - Lateral arm balance', benefits: ['Strengthens wrists', 'Improves balance'], tags: ['strength', 'power'], imageUrl: 'assets/images/side_crow_pose.png'),
    YogaPose(name: 'Flying Pigeon Pose', description: 'Eka Pada Galavasana - Flying arm balance', benefits: ['Hip opening', 'Upper body strength'], tags: ['strength', 'power'], imageUrl: 'assets/images/flying_pigeon_pose.png'),
    YogaPose(name: 'Scorpion Pose', description: 'Vrischikasana - Deep inverted backbend', benefits: ['Strengthens shoulders', 'Improves balance'], tags: ['strength', 'power'], imageUrl: 'assets/images/scorpion_pose.png'),
    YogaPose(name: 'Forearm Stand', description: 'Pincha Mayurasana - Inverted forearm balance', benefits: ['Shoulder strength', 'Calms brain'], tags: ['strength', 'power', 'energy'], imageUrl: 'assets/images/forearm_stand.png'),
    YogaPose(name: 'Lizard Pose', description: 'Utthan Pristhasana - Deep hip opener', benefits: ['Hip flexibility', 'Stretches groin'], tags: ['beginner', 'therapy', 'morning'], imageUrl: 'assets/images/lizard_pose.png'),
    YogaPose(name: 'Dragon Pose', description: 'Deep hamstring and hip stretch', benefits: ['Deep hip stretch', 'Joint mobility'], tags: ['beginner', 'therapy', 'sleep'], imageUrl: 'assets/images/dragon_pose.png'),
    YogaPose(name: 'Compass Pose', description: 'Seated side stretch and hip opener', benefits: ['Hamstring flexibility', 'Opens shoulders'], tags: ['strength', 'power'], imageUrl: 'assets/images/compass_pose.png'),
    YogaPose(name: 'Split Pose', description: 'Hanumanasana - Front split', benefits: ['Deep hamstring stretch', 'Stretches thighs'], tags: ['strength', 'power', 'morning'], imageUrl: 'assets/images/split_pose.png'),
  ];
}
