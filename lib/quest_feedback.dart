const questSuccessMessages = <String, List<String>>{
  'ko': [
    '오, 하고 왔구만! 자네 이야기를 들으니 나도 기쁘네.',
    '오늘의 의뢰를 해 봤구먼! 잠깐이라도 즐거웠으면 좋겠어.',
    '의뢰 완료로군! 오늘의 작은 모험은 어땠나?',
    '다녀왔나? 작은 의뢰였지만 자네에게 좋은 시간이었길 바라.',
    '퀘스트를 완료해 줘서 고마워! 자, 약속한 골드야.'
  ],
  'en': [
    'Oh, you did it! Hearing about it makes me happy too.',
    'You tried today’s quest! I hope you enjoyed the moment.',
    'Quest complete! How was your little adventure today?',
    'You’re back! I hope that little quest was a pleasant moment for you.',
    'Thanks for completing the quest! Here’s the gold I promised.'
  ],
  'ja': [
    'おお、やってきたんじゃな！ おぬしの話を聞けて、わしも嬉しいぞ。',
    '今日の依頼をやってみたんじゃな！ 少しでも楽しかったなら何よりじゃ。',
    '依頼完了じゃな！ 今日の小さな冒険はどうじゃった？',
    'おかえり。小さな依頼じゃったが、いい時間になっていたら嬉しいぞ。',
    'クエストを終えてくれてありがとう！ ほれ、約束のゴールドじゃ。'
  ],
  'zh': [
    '哦，你完成啦！听到你的故事，我也很开心。',
    '你体验了今天的委托呀！希望你有片刻的开心。',
    '委托完成！今天的小冒险怎么样？',
    '回来啦？希望这个小委托给你带来了一段美好的时光。',
    '谢谢你完成任务！来，这是说好的金币。'
  ],
  'hi': [
    'ओह, कर आए! तुम्हारे बारे में सुनकर मुझे भी खुशी हुई।',
    'आज की छोटी खोज कर आए! उम्मीद है कुछ पल अच्छे लगे होंगे।',
    'खोज पूरी हुई! आज का छोटा सा रोमांच कैसा रहा?',
    'वापस आ गए? उम्मीद है इस छोटे से काम में तुम्हारा अच्छा समय बीता होगा।',
    'खोज पूरी करने के लिए धन्यवाद! लो, वादे के सोने के सिक्के।'
  ],
  'es': [
    '¡Oh, lo hiciste! Me alegra saber de tu pequeña aventura.',
    '¡Probaste la misión de hoy! Espero que hayas disfrutado el momento.',
    '¡Misión completada! ¿Qué tal tu pequeña aventura de hoy?',
    '¿Ya volviste? Espero que esta pequeña misión te haya dado un buen momento.',
    '¡Gracias por completar la misión! Aquí tienes el oro prometido.'
  ],
};

const questFailureMessages = <String, List<String>>{
  'ko': [
    '이번 의뢰는 여기까지로군! 다음 의뢰도 준비해 둘게.',
    '오늘은 의뢰서를 살짝 접어 둘까? 차 한 잔 하고 가게.',
    '괜찮아, 괜찮아! 오늘은 길드에 들른 것만으로도 좋아.',
    '이번 의뢰는 여기까지! 편히 쉬었다 가게.',
    '이번 의뢰서는 내가 정리해 둘게. 자네는 편히 쉬게!'
  ],
  'en': [
    'That’s all for this quest! I’ll have another one ready for you.',
    'Shall we set today’s quest aside? Stay for a cup of tea.',
    'It’s all right! I’m happy you stopped by the guild today.',
    'That’s all for this quest! Rest here a while.',
    'I’ll put this quest scroll away. You take it easy!'
  ],
  'ja': [
    '今回の依頼はここまでじゃな！ 次の依頼も用意しておくぞ。',
    '今日の依頼書はそっとしまおうか。お茶でも飲んでいきなさい。',
    '大丈夫、大丈夫！ 今日はギルドに寄ってくれただけで嬉しいぞ。',
    '今回の依頼はここまで！ ゆっくり休んでいきなさい。',
    'この依頼書はわしが片づけておく。おぬしはゆっくり休みなさい！'
  ],
  'zh': [
    '这次委托就到这里吧！下次的委托我也会准备好的。',
    '今天的委托书先收起来吧？喝杯茶再走。',
    '没关系，没关系！今天你能来公会坐坐，我就很高兴。',
    '这次委托就到这里！好好休息一下吧。',
    '这份委托书我来收拾，你安心休息吧！'
  ],
  'hi': [
    'इस खोज को यहीं छोड़ते हैं! अगली खोज भी तैयार रखूँगा।',
    'आज की खोज को थोड़ी देर के लिए रख दें? एक कप चाय पीकर जाना।',
    'कोई बात नहीं! आज तुम्हारा गिल्ड में आना ही अच्छा लगा।',
    'इस खोज को यहीं छोड़ते हैं! आराम करके जाना।',
    'इस खोज का पर्चा मैं संभाल लूँगा। तुम आराम करो!'
  ],
  'es': [
    '¡Hasta aquí llega esta misión! Te prepararé otra para la próxima.',
    '¿Guardamos la misión de hoy? Quédate a tomar una taza de té.',
    '¡Está bien, está bien! Me alegra que hayas pasado por el gremio hoy.',
    '¡Hasta aquí llega esta misión! Descansa un rato.',
    'Yo guardaré este pergamino. ¡Tú descansa!'
  ],
};
