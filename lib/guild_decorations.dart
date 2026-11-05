import 'dart:ui';

class GuildDecoration {
  const GuildDecoration(this.id, this.name, this.slot, this.region);
  final String id;
  final String name;
  final String slot;
  // Coordinates in the 1199 x 1312 guild artwork.
  final Rect region;
  String get asset => 'assets/decorations/$id.png';
}

const guildDecorations = <GuildDecoration>[
  GuildDecoration(
      'sword', '별의 수호검', 'left_pillar', Rect.fromLTRB(0, 220, 130, 645)),
  GuildDecoration(
      'shield', '금빛 수호 방패', 'counter_front', Rect.fromLTRB(78, 650, 359, 930)),
  GuildDecoration(
      'sigil', '황금 마법진', 'centre_wall', Rect.fromLTRB(472, 140, 735, 340)),
  GuildDecoration('crystal', '푸른 마법수정', 'right_counter',
      Rect.fromLTRB(775, 435, 1010, 655)),
  GuildDecoration(
      'helm', '붉은 용의 투구', 'left_counter', Rect.fromLTRB(115, 420, 330, 655)),
  GuildDecoration(
      'staff', '별자리 지팡이', 'right_pillar', Rect.fromLTRB(1072, 170, 1199, 650)),
  GuildDecoration('banner_dragon', '용의 날개 깃발', 'centre_wall',
      Rect.fromLTRB(405, 128, 790, 383)),
  GuildDecoration(
      'spellbook', '비밀의 마법서', 'left_counter', Rect.fromLTRB(65, 420, 425, 655)),
  GuildDecoration('treasure', '황금 보물상자', 'right_counter',
      Rect.fromLTRB(770, 425, 1015, 655)),
  GuildDecoration(
      'armor', '별빛 갑옷', 'right_counter', Rect.fromLTRB(775, 330, 1020, 655)),
];

const decorationPrice = 150;

const decorationTranslations = <String, List<String>>{
  'en': [
    'Star Guardian Sword',
    'Golden Guardian Shield',
    'Golden Magic Circle',
    'Blue Magic Crystal',
    'Red Dragon Helm',
    'Constellation Staff',
    'Dragon Wing Banner',
    'Secret Spellbook',
    'Golden Treasure Chest',
    'Starlight Armor'
  ],
  'ja': [
    '星の守護剣',
    '黄金の守護盾',
    '黄金の魔法陣',
    '青い魔法水晶',
    '赤竜の兜',
    '星座の杖',
    '竜の翼の旗',
    '秘密の魔導書',
    '黄金の宝箱',
    '星明かりの鎧'
  ],
  'zh': [
    '星之守护剑',
    '黄金守护盾',
    '黄金魔法阵',
    '蓝色魔法水晶',
    '红龙头盔',
    '星座法杖',
    '龙翼旗帜',
    '秘密魔法书',
    '黄金宝箱',
    '星光盔甲'
  ],
  'hi': [
    'तारों की रक्षक तलवार',
    'सुनहरी रक्षक ढाल',
    'सुनहरा जादुई चक्र',
    'नीला जादुई क्रिस्टल',
    'लाल ड्रैगन का मुकुट',
    'तारामंडल की छड़ी',
    'ड्रैगन पंख ध्वज',
    'गुप्त जादुई पुस्तक',
    'सुनहरा खजाना',
    'तारों का कवच'
  ],
  'es': [
    'Espada guardiana estelar',
    'Escudo guardián dorado',
    'Círculo mágico dorado',
    'Cristal mágico azul',
    'Yelmo del dragón rojo',
    'Bastón de constelaciones',
    'Estandarte de alas de dragón',
    'Libro secreto de magia',
    'Cofre del tesoro dorado',
    'Armadura estelar'
  ],
};

String decorationName(String language, GuildDecoration decoration) {
  if (language == 'ko') return decoration.name;
  final index = guildDecorations.indexOf(decoration);
  final names =
      decorationTranslations[language] ?? decorationTranslations['en']!;
  return names[index];
}
