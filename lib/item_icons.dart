class ItemIconChoice {
  const ItemIconChoice(this.key, this.label);
  final String key;
  final String label;
}

class ItemIconCategory {
  const ItemIconCategory(this.key, this.label, this.choices);
  final String key;
  final String label;
  final List<ItemIconChoice> choices;
  String get defaultIconKey => choices.first.key;
  bool contains(String iconKey) => choices.any((icon) => icon.key == iconKey);
}

class ItemIcons {
  const ItemIcons._();

  static const categories = [
    ItemIconCategory('medication', '用药', [
      ItemIconChoice('medication', '药片'),
      ItemIconChoice('pill-bottle', '药瓶'),
      ItemIconChoice('syringe', '注射'),
      ItemIconChoice('droplet', '滴剂'),
    ]),
    ItemIconCategory('vitamin', '营养', [
      ItemIconChoice('vitamin', '叶片'),
      ItemIconChoice('apple', '苹果'),
      ItemIconChoice('cherry', '果实'),
      ItemIconChoice('sprout', '嫩芽'),
    ]),
    ItemIconCategory('eye', '护理', [
      ItemIconChoice('heart', '心形'),
      ItemIconChoice('hand-heart', '呵护'),
      ItemIconChoice('eye', '眼部'),
      ItemIconChoice('shield-plus', '防护'),
    ]),
    ItemIconCategory('water', '饮水', [
      ItemIconChoice('water', '水杯'),
      ItemIconChoice('droplets', '水滴'),
      ItemIconChoice('cup-soda', '饮品'),
      ItemIconChoice('coffee', '热饮'),
    ]),
    ItemIconCategory('exercise', '运动', [
      ItemIconChoice('exercise', '步行'),
      ItemIconChoice('dumbbell', '力量'),
      ItemIconChoice('bike', '骑行'),
      ItemIconChoice('activity', '活动'),
    ]),
    ItemIconCategory('sleep', '作息', [
      ItemIconChoice('moon', '月亮'),
      ItemIconChoice('bed-double', '睡眠'),
      ItemIconChoice('sunrise', '起床'),
      ItemIconChoice('alarm-clock', '闹钟'),
    ]),
    ItemIconCategory('study', '学习', [
      ItemIconChoice('book-open', '阅读'),
      ItemIconChoice('notebook-pen', '记录'),
      ItemIconChoice('graduation-cap', '学习'),
      ItemIconChoice('timer', '专注'),
    ]),
    ItemIconCategory('other', '其他', [
      ItemIconChoice('list-todo', '清单'),
      ItemIconChoice('circle-check-big', '待办'),
      ItemIconChoice('calendar-days', '日程'),
      ItemIconChoice('bell', '提醒'),
    ]),
  ];

  // Retain the five existing keys so saved reminders need no data migration.
  static String glyphFor(String key) => switch (key) {
    'medication' => 'pill',
    'vitamin' => 'leaf',
    'water' => 'glass-water',
    'exercise' => 'footprints',
    _ => key,
  };

  static ItemIconCategory categoryFor(String iconKey) => categories.firstWhere(
    (category) => category.contains(iconKey),
    orElse: () => categories.first,
  );

  static ItemIconChoice choiceFor(String iconKey) =>
      categoryFor(iconKey).choices.firstWhere(
        (choice) => choice.key == iconKey,
        orElse: () => categories.first.choices.first,
      );

  static bool showsDose(String iconKey) =>
      iconKey == 'eye' ||
      const {
        'medication',
        'vitamin',
        'water',
      }.contains(categoryFor(iconKey).key);
}
