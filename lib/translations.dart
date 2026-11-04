// Korean is the authoring language. Add matching translations for each new quest.
const translations = <String, Map<String, String>>{
  'en': {
    '작은 모험 길드': 'Little Adventure Guild',
    '길드주인': 'Guildkeeper',
    '길드 메뉴': 'Guild menu',
    '닫기': 'Close',
    '돌아가기': 'Back',
    '다시 시도': 'Try again',
    '오픈소스 라이선스': 'Open-source licenses',
    '길드 꾸미기': 'Decorate the guild',
    '길드 지원하기': 'Support the guild',
    '의뢰 제안하기': 'Suggest a quest',
    '설정': 'Settings',
    '언어': 'Language',
    '기기 설정 따르기': 'Use device language',
    '작은 화분': 'Small plant',
    '길드 깃발': 'Guild banner',
    '따뜻한 등불': 'Warm lantern',
    '치우기': 'Put away',
    '놓기': 'Place',
    '보유 골드': 'Gold',
    '모험으로 모은 골드로 길드를 꾸며 보세요. 장식은 하나씩 놓을 수 있어요.':
        'Decorate with gold earned on adventures. Place one decoration at a time.',
    '이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.':
        'If you wish, send supplies to help these little adventures continue tomorrow.',
    '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.':
        'Is there a small experience you would like to share? Your suggestion may become a future quest.',
    '작은 보급품': 'Small supplies',
    '든든한 보급품': 'Generous supplies',
    '특별 보급품': 'Special supplies',
    '후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.':
        'Support is coming soon. Every quest is always free.',
    '의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.':
        'Suggestions are coming soon. Supporting the guild does not affect selection.',
    '모험 시작하기': 'Begin the adventure',
    '다음 이야기': 'Continue',
    '길드주인의 이야기를 듣고 있어요…': 'Listening to the guildkeeper…',
    '오늘의 의뢰가 도착했어요': 'Today’s quest has arrived',
    '양피지 열기': 'Open the scroll',
    '봉인을 눌러 의뢰를 확인하세요': 'Tap the seal to read your quest',
    '오늘의 사이드퀘스트': 'Today’s side quest',
    '완료 보상 · 10 G': 'Completion reward · 10 G',
    '퀘스트 완료': 'Quest complete',
    '퀘스트 실패': 'Quest incomplete',
    '작은 모험의 보상으로 10 G를 받았어요.': 'You received 10 G for your little adventure.',
    '괜찮아요. 내일 또 다른 모험이 기다려요.':
        'That’s all right. Another adventure awaits tomorrow.',
    '완료 여부는 스스로 선택해 주세요. 하지 않아도 괜찮아요.':
        'Report the result yourself. It’s okay to leave it for today.',
    '평범한 하루에도 모험은 숨어 있으니까요.':
        'Even an ordinary day can hold a little adventure.',
    '오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.':
        'Could not load today’s quest. Please try again.',
    '안내 진행 상태를 저장하지 못했어요. 다시 시도해 주세요.':
        'Could not save your progress. Please try again.',
    '기록을 저장하지 못했어요. 다시 시도해 주세요.':
        'Could not save your progress. Please try again.',
    '꾸미기 기록을 저장하지 못했어요.': 'Could not save your decorations.',
    '왔구나, 모험가!': 'Welcome, adventurer.',
    '잠시 하늘을 올려다보기': 'Look up at the sky',
    '잠시 걸음을 멈추고 구름이나 별이 떠 있는 하늘을 바라봐.':
        'Take a moment to watch the clouds or stars.',
    '오래된 사진 꺼내 보기': 'Revisit an old photo',
    '마음에 남은 오래된 사진 한 장을 꺼내 천천히 들여다봐.':
        'Spend a moment with a photo that means something to you.',
    '안부 한 줄 보내기': 'Send a little hello',
    '문득 떠오르는 사람에게 가볍게 안부를 전해 봐.': 'Send a short hello to someone on your mind.',
    '오, 새로운 모험가로구나! 어서 와. 여긴 바쁜 하루 속 작은 모험을 찾는 길드야.':
        'Ah, a new adventurer! Welcome. This guild seeks little adventures in busy days.',
    '매일 양피지 하나를 건네줄게. 그 안에는 네가 오늘 만날 수 있는 작은 의뢰가 적혀 있어.':
        'Each day I’ll offer one scroll, holding one small quest for you to discover.',
    '의뢰를 마쳤다면 퀘스트 완료를, 오늘은 못 했다면 퀘스트 실패를 눌러 줘. 못 해도 괜찮아. 길드는 언제나 열려 있으니까.':
        'Report your quest as complete or incomplete. If today is not the day, that’s fine. The guild is always open.',
    '정말 마쳤는지 어떻게 아냐고? 허허, 우리 길드에는 감시 마법이 없어. 네 보고를 믿는 게 이곳의 오래된 규칙이지.':
        'How do we know you finished? Ha! We have no watching spells. Trusting your word is an old guild tradition.',
    '의뢰를 완료하면 골드를 줄게. 길드 메뉴의 꾸미기에서 모은 골드로 장식을 사고, 이곳에 놓을 수 있어.':
        'Complete a quest to earn gold. Use it in the guild menu to buy decorations and make this place your own.',
    '자, 서두를 필요 없어. 양피지를 열고 오늘의 작은 모험을 만나 봐!':
        'Now, no need to hurry. Open the scroll and meet today’s little adventure!',
  },
  'ja': {
    '작은 모험 길드': '小さな冒険ギルド',
    '길드주인': 'ギルドの主人',
    '길드 메뉴': 'ギルドメニュー',
    '닫기': '閉じる',
    '돌아가기': '戻る',
    '다시 시도': 'もう一度',
    '오픈소스 라이선스': 'オープンソースライセンス',
    '길드 꾸미기': 'ギルドを飾る',
    '길드 지원하기': 'ギルドを支援する',
    '의뢰 제안하기': '依頼を提案する',
    '설정': '設定',
    '언어': '言語',
    '기기 설정 따르기': '端末の設定に従う',
    '작은 화분': '小さな鉢植え',
    '길드 깃발': 'ギルドの旗',
    '따뜻한 등불': 'あたたかな灯り',
    '치우기': '片づける',
    '놓기': '飾る',
    '보유 골드': '所持ゴールド',
    '모험으로 모은 골드로 길드를 꾸며 보세요. 장식은 하나씩 놓을 수 있어요.':
        '冒険で集めたゴールドでギルドを飾ろう。飾りは一つずつ置けます。',
    '이 작은 모험들이 내일도 이어질 수 있도록, 원한다면 길드에 보급품을 보내주세요.':
        '小さな冒険が明日も続くように、よければギルドに物資を送ってください。',
    '다른 모험가들과 나누고 싶은 작은 경험이 있나요? 당신의 의뢰가 언젠가 오늘의 퀘스트가 될지도 모릅니다.':
        'ほかの冒険者と分かち合いたい小さな体験はありますか？いつか今日の依頼になるかもしれません。',
    '작은 보급품': '小さな物資',
    '든든한 보급품': 'たっぷりの物資',
    '특별 보급품': '特別な物資',
    '후원 기능은 준비 중이에요. 모든 퀘스트는 언제나 무료입니다.': '支援機能は準備中です。クエストはいつでも無料です。',
    '의뢰 접수는 준비 중이에요. 후원 여부는 의뢰 채택에 영향을 주지 않습니다.':
        '依頼の受付は準備中です。支援の有無は採用に影響しません。',
    '모험 시작하기': '冒険を始める',
    '다음 이야기': '次の話へ',
    '길드주인의 이야기를 듣고 있어요…': 'ギルドの主人の話を聞いています…',
    '오늘의 의뢰가 도착했어요': '今日の依頼が届きました',
    '양피지 열기': '巻物を開く',
    '봉인을 눌러 의뢰를 확인하세요': '封印を押して依頼を確認しよう',
    '오늘의 사이드퀘스트': '今日のサイドクエスト',
    '완료 보상 · 10 G': '達成報酬 · 10 G',
    '퀘스트 완료': 'クエスト達成',
    '퀘스트 실패': 'クエスト未達成',
    '작은 모험의 보상으로 10 G를 받았어요.': '小さな冒険の報酬として10 Gを受け取りました。',
    '괜찮아요. 내일 또 다른 모험이 기다려요.': '大丈夫。明日また別の冒険が待っています。',
    '완료 여부는 스스로 선택해 주세요. 하지 않아도 괜찮아요.': '結果は自分で報告してください。できなくても大丈夫です。',
    '평범한 하루에도 모험은 숨어 있으니까요.': 'いつもの一日にも、小さな冒険が隠れています。',
    '오늘의 의뢰를 불러오지 못했어요. 다시 시도해 주세요.': '今日の依頼を読み込めませんでした。もう一度お試しください。',
    '안내 진행 상태를 저장하지 못했어요. 다시 시도해 주세요.': '進行状況を保存できませんでした。もう一度お試しください。',
    '기록을 저장하지 못했어요. 다시 시도해 주세요.': '記録を保存できませんでした。もう一度お試しください。',
    '꾸미기 기록을 저장하지 못했어요.': '飾りの記録を保存できませんでした。',
    '왔구나, 모험가!': 'ようこそ、冒険者！',
    '잠시 하늘을 올려다보기': '空を見上げてみる',
    '잠시 걸음을 멈추고 구름이나 별이 떠 있는 하늘을 바라봐.': '少し立ち止まって、雲や星の浮かぶ空を眺めてみよう。',
    '오래된 사진 꺼내 보기': '昔の写真を見てみる',
    '마음에 남은 오래된 사진 한 장을 꺼내 천천히 들여다봐.': '心に残る古い写真を一枚、ゆっくり眺めてみよう。',
    '안부 한 줄 보내기': 'ひとこと挨拶を送る',
    '문득 떠오르는 사람에게 가볍게 안부를 전해 봐.': 'ふと思い浮かんだ人に、気軽に挨拶を送ってみよう。',
    '오, 새로운 모험가로구나! 어서 와. 여긴 바쁜 하루 속 작은 모험을 찾는 길드야.':
        'おお、新しい冒険者じゃな！ようこそ。ここは忙しい日々に小さな冒険を探すギルドじゃ。',
    '매일 양피지 하나를 건네줄게. 그 안에는 네가 오늘 만날 수 있는 작은 의뢰가 적혀 있어.':
        '毎日、巻物を一つ渡そう。そこには今日出会える小さな依頼が書かれておる。',
    '의뢰를 마쳤다면 퀘스트 완료를, 오늘은 못 했다면 퀘스트 실패를 눌러 줘. 못 해도 괜찮아. 길드는 언제나 열려 있으니까.':
        '依頼を終えたら達成を、できなかったら未達成を押してくれ。できなくても大丈夫。ギルドはいつでも開いておる。',
    '정말 마쳤는지 어떻게 아냐고? 허허, 우리 길드에는 감시 마법이 없어. 네 보고를 믿는 게 이곳의 오래된 규칙이지.':
        '本当に終えたかどうやって知るのかって？ほっほ、監視の魔法はない。報告を信じるのがこのギルドの古い決まりじゃ。',
    '의뢰를 완료하면 골드를 줄게. 길드 메뉴의 꾸미기에서 모은 골드로 장식을 사고, 이곳에 놓을 수 있어.':
        '依頼を達成すればゴールドを渡そう。メニューの「ギルドを飾る」で飾りを買い、ここに置けるぞ。',
    '자, 서두를 필요 없어. 양피지를 열고 오늘의 작은 모험을 만나 봐!':
        'さあ、急ぐことはない。巻物を開いて、今日の小さな冒険に出会っておいで！',
  }
};
String translate(String language, String key) => language == 'ko'
    ? key
    : (translations[language]?[key] ?? translations['en']?[key] ?? key);
