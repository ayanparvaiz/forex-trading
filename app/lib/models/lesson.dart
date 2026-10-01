/// A short lesson on one habit, and three questions on it. Passing all the
/// questions passes the lesson; passing every lesson earns "scholar"
/// (worker/src/achievements.js, LESSONS — the ids must match, and so must
/// the rules' list in firestore.rules).
class Lesson {
  const Lesson({
    required this.id,
    required this.emoji,
    required this.titleBn,
    required this.titleEn,
    required this.paragraphsBn,
    required this.paragraphsEn,
    required this.questions,
  });

  final String id;
  final String emoji;
  final String titleBn;
  final String titleEn;
  final List<String> paragraphsBn;
  final List<String> paragraphsEn;
  final List<Question> questions;

  String title(bool bangla) => bangla ? titleBn : titleEn;
  List<String> paragraphs(bool bangla) => bangla ? paragraphsBn : paragraphsEn;

  static Lesson? byId(String id) {
    for (final l in all) {
      if (l.id == id) return l;
    }
    return null;
  }

  static const all = <Lesson>[
    Lesson(
      id: 'risk',
      emoji: '🛡️',
      titleBn: 'প্রতি ট্রেডে ১% রিস্ক',
      titleEn: 'Risk 1% a trade',
      paragraphsBn: [
        'রিস্ক মানে ট্রেড ভুল হলে কত হারাবেন — এটা ঢোকার আগেই ঠিক করতে হয়, পরে না।',
        'প্রতি ট্রেডে ১% রিস্কে টানা ১০টা হারলেও অ্যাকাউন্টের প্রায় ৯০% থাকে। ১০% রিস্কে ওই ১০টা হারে থাকে প্রায় ৩৫% — আর শুধু আগের জায়গায় ফিরতেই প্রায় তিন গুণ লাভ লাগে।',
        'সাইজ আসে রিস্ক আর স্টপ থেকে: আগে রিস্ক, পরে সাইজ। ট্রেড স্ক্রিনের রিস্ক ক্যালকুলেটর হিসাবটা করে দেয়।',
      ],
      paragraphsEn: [
        'Risk is how much you lose if the trade is wrong — decided before you '
            'enter, not after.',
        'At 1% a trade, ten losses in a row leave about 90% of the account. At '
            '10% a trade, the same ten losses leave about 35% — and you need '
            'almost three times that back just to get level.',
        'Your size comes from your risk and your stop: risk first, size second. '
            'The risk calculator on the Trade screen does the maths.',
      ],
      questions: [
        Question(
          promptBn: 'রিস্ক কখন ঠিক করবেন?',
          promptEn: 'When do you decide your risk?',
          optionsBn: ['ঢোকার আগে', 'ট্রেড নড়ার পরে', 'লস হতে থাকলে'],
          optionsEn: [
            'Before entering',
            'After the trade moves',
            "When it's losing",
          ],
          whyBn: 'আগে ঠিক করলে সেটা প্ল্যান; পরে করলে আশা।',
          whyEn: 'Decided before, it is a plan; decided after, it is a hope.',
        ),
        Question(
          promptBn: 'প্রতি ট্রেডে ১% রিস্কে টানা ১০টা হারলে মোটামুটি কত থাকে?',
          promptEn: 'Ten losses in a row at 1% a trade leave roughly…',
          optionsBn: ['অ্যাকাউন্টের ৯০%', '৫০%', '১০%'],
          optionsEn: ['90% of the account', '50%', '10%'],
          whyBn: '০.৯৯-কে দশবার গুণ করলে প্রায় ০.৯০ — ছোট রিস্ক টিকিয়ে রাখে।',
          whyEn:
              '0.99 multiplied ten times is about 0.90 — small risk keeps you in.',
        ),
        Question(
          promptBn: 'লট সাইজ কী দিয়ে ঠিক হয়?',
          promptEn: 'What sets your lot size?',
          optionsBn: [
            'রিস্ক আর স্টপ দিয়ে',
            'কতটা নিশ্চিত লাগছে',
            'আগের ট্রেডের ফল',
          ],
          optionsEn: [
            'Your risk and your stop',
            'How sure you feel',
            "The last trade's result",
          ],
          whyBn: 'রিস্ক ÷ (স্টপের পিপ × পিপের দাম) = সাইজ।',
          whyEn: 'Risk ÷ (stop in pips × pip value) = size.',
        ),
      ],
    ),
    Lesson(
      id: 'stop',
      emoji: '🛑',
      titleBn: 'স্টপ কখনো সরাবেন না',
      titleEn: 'Never move your stop',
      paragraphsBn: [
        'স্টপ লস হলো সেই জায়গা যেখানে আপনার আইডিয়া ভুল প্রমাণ হয়। ঢোকার আগেই সেখানে বসান।',
        'দাম কাছে এলে স্টপ দূরে সরালে প্ল্যানের −১R হয়ে যায় −২R, −৩R বা আরও খারাপ। ট্রেডিংয়ে এটাই সবচেয়ে দামি অভ্যাস — আর এখানে এতে ডিসিপ্লিনের ৩৫ পয়েন্ট কাটে।',
        'স্টপ লাগলে প্ল্যান কাজ করেছে: লস ঠিক ততটাই যতটা আপনি বেছেছিলেন। কী হলো লিখে রাখুন, পরের সেটআপের অপেক্ষা করুন।',
      ],
      paragraphsEn: [
        'A stop loss is where your idea is proven wrong. Put it there before '
            'you enter.',
        'Moving it away when price comes near turns a planned −1R into −2R, −3R '
            'or worse. It is the most expensive habit in trading — and here it '
            'costs 35 discipline points.',
        'If the stop is hit, the plan worked: the loss was the size you chose. '
            'Write down what happened, and wait for the next setup.',
      ],
      questions: [
        Question(
          promptBn: 'দাম স্টপের কাছে। কী করবেন?',
          promptEn: 'Price is near your stop. What do you do?',
          optionsBn: ['যেখানে আছে রাখবেন', 'আরও দূরে সরাবেন', 'তুলে দেবেন'],
          optionsEn: [
            'Leave it where it is',
            'Move it further away',
            'Remove it',
          ],
          whyBn: 'স্টপটাই প্ল্যান। সরানো মানে প্ল্যান ভাঙা।',
          whyEn: 'The stop is the plan. Moving it is breaking the plan.',
        ),
        Question(
          promptBn: 'স্টপ লাগা মানে…',
          promptEn: 'A stop that was hit means…',
          optionsBn: [
            'লস ঠিক পরিকল্পনামতো হয়েছে',
            'আপনি ট্রেডিংয়ে খারাপ',
            'মার্কেট কারসাজি করছে',
          ],
          optionsEn: [
            'The loss was the size you planned',
            'You are bad at trading',
            'The market is rigged',
          ],
          whyBn: 'ছোট, পরিকল্পিত লস টিকে থাকার অংশ।',
          whyEn: 'Small, planned losses are part of staying in the game.',
        ),
        Question(
          promptBn: 'স্টপ কোথায় বসানো উচিত?',
          promptEn: 'Where does a stop belong?',
          optionsBn: [
            'যেখানে আইডিয়া ভুল প্রমাণ হয়',
            'গোল সংখ্যার পিপে',
            'যেখানে নিরাপদ লাগে',
          ],
          optionsEn: [
            'Where your idea is proven wrong',
            'A round number of pips',
            'Wherever feels safe',
          ],
          whyBn: 'স্টপ বাজারের কাঠামো থেকে আসে, অনুভূতি থেকে না।',
          whyEn: "A stop comes from the chart's structure, not from a feeling.",
        ),
      ],
    ),
    Lesson(
      id: 'reward',
      emoji: '⚖️',
      titleBn: 'রিস্কের যোগ্য রিওয়ার্ড',
      titleEn: 'A reward worth the risk',
      paragraphsBn: [
        'R হলো আপনার রিস্কের এক একক। যে ট্রেড রিস্কের দ্বিগুণ লাভ করে, সেটা +২R।',
        'জয় ২R আর হার ১R হলে বেশিরভাগ সময় ভুল হয়েও বাড়া যায়: ১০টার ৪টা জিতলেও +২R।',
        'এখানে ১.৫R-এর কম টার্গেটের ট্রেডকে খারাপ রিস্ক-রিওয়ার্ড ধরা হয়। এমন সেটআপ খুঁজুন যেখানে টার্গেট রিস্কের অনেক বেশি।',
      ],
      paragraphsEn: [
        'R is one unit of your risk. A trade that makes twice what it risked '
            'is +2R.',
        'With winners of 2R and losers of 1R, you can be wrong more often than '
            'right and still grow: win 4 out of 10 and you are up 2R.',
        'Here a trade aiming for less than 1.5R counts as poor risk-reward. '
            'Look for setups where the target is well beyond the risk.',
      ],
      questions: [
        Question(
          promptBn: '১০০ রিস্কে ৩০০ লাভ — এটা…',
          promptEn: 'You risk 100 and make 300. That is…',
          optionsBn: ['+৩R', '+১R', '+৩০০R'],
          optionsEn: ['+3R', '+1R', '+300R'],
          whyBn: 'লাভ ÷ রিস্ক = ৩০০ ÷ ১০০ = ৩R।',
          whyEn: 'Gain ÷ risk = 300 ÷ 100 = 3R.',
        ),
        Question(
          promptBn: '২R জয়ে ১০টার ৪টা জিতে, ১R হারে ৬টা হেরে আপনি…',
          promptEn: 'Winning 4 of 10 at 2R and losing 6 at 1R, you are…',
          optionsBn: ['২R লাভে', '২R লসে', 'সমানে সমান'],
          optionsEn: ['Up 2R', 'Down 2R', 'Even'],
          whyBn: '৪ × ২ − ৬ × ১ = +২R।',
          whyEn: '4 × 2 − 6 × 1 = +2R.',
        ),
        Question(
          promptBn: '১০০ ট্রেডে কোনটা বেশি গুরুত্বপূর্ণ?',
          promptEn: 'Over a hundred trades, what matters more?',
          optionsBn: [
            'এক্সপেক্টেন্সি — ট্রেডপ্রতি গড় R',
            'শুধু উইন রেট',
            'সবচেয়ে বড় একটা জয়',
          ],
          optionsEn: [
            'Expectancy — the average R per trade',
            'Win rate alone',
            'The biggest single win',
          ],
          whyBn: 'উইন রেট আর জয়-হারের আকার মিলেই এক্সপেক্টেন্সি।',
          whyEn:
              'Expectancy is win rate and the size of wins and losses together.',
        ),
      ],
    ),
    Lesson(
      id: 'revenge',
      emoji: '🧊',
      titleBn: 'প্রতিশোধ নয়, অতি-ট্রেড নয়',
      titleEn: 'No revenge, no overtrading',
      paragraphsBn: [
        'লসের পর ইচ্ছা হয় এখনই ফেরত আনতে — প্রায়ই বড় সাইজে। এটাই রিভেঞ্জ ট্রেড, আর এভাবেই একটা খারাপ দিন খারাপ মাস হয়ে যায়।',
        'ওভারট্রেডিং তার নিঃশব্দ রূপ: সেটআপ থাকায় না, বিরক্তি থেকে ট্রেড নেওয়া।',
        'একটা সীমা ঠিক করুন — ধরুন দিনে তিনটা ট্রেড — তারপর থামুন। লস একটা তথ্য, আজকেই শোধ করার দেনা না।',
      ],
      paragraphsEn: [
        'After a loss the urge is to win it straight back — often with a bigger '
            'size. That is a revenge trade, and it is how one bad day becomes a '
            'bad month.',
        'Overtrading is the quieter version: taking trades out of boredom, not '
            'because the setup is there.',
        'Set a limit — say three trades a day — and stop after it. A loss is '
            'information, not a debt to repay today.',
      ],
      questions: [
        Question(
          promptBn: 'এইমাত্র দুইটা ট্রেড হারলেন। সবচেয়ে ভালো পরের কাজ?',
          promptEn: 'You just lost two trades. The best next step?',
          optionsBn: [
            'সরে গিয়ে রিভিউ করা',
            'সাইজ দ্বিগুণ করে ফেরত আনা',
            'তাড়াতাড়ি পাঁচটা ট্রেড নেওয়া',
          ],
          optionsEn: [
            'Step away and review',
            'Double the size to win it back',
            'Take five quick trades',
          ],
          whyBn: 'রাগ নিয়ে নেওয়া ট্রেড প্ল্যানের ট্রেড না।',
          whyEn: 'A trade taken in anger is not a trade from the plan.',
        ),
        Question(
          promptBn: 'ওভারট্রেডিং মানে…',
          promptEn: 'Overtrading means…',
          optionsBn: [
            'সেটআপ ছাড়া, বিরক্তি থেকে ট্রেড',
            'বড় সাইজে ট্রেড',
            'অনেক পেয়ারে ট্রেড',
          ],
          optionsEn: [
            'Trading without a setup, out of boredom',
            'Trading big sizes',
            'Trading many pairs',
          ],
          whyBn: 'সংখ্যা না, কারণটাই আসল — সেটআপ ছিল কি না।',
          whyEn: 'It is not the number but the reason — was there a setup?',
        ),
        Question(
          promptBn: 'লস হলো…',
          promptEn: 'A loss is…',
          optionsBn: [
            'প্ল্যান নিয়ে একটা তথ্য',
            'আজই শোধ করার দেনা',
            'মার্কেট আপনার বিরুদ্ধে তার প্রমাণ',
          ],
          optionsEn: [
            'Information about the plan',
            'A debt to repay today',
            'Proof the market is against you',
          ],
          whyBn: 'লস থেকে শেখা যায়; তাড়া করলে আরও বাড়ে।',
          whyEn: 'You learn from a loss; chase it and it grows.',
        ),
      ],
    ),
    Lesson(
      id: 'journal',
      emoji: '📓',
      titleBn: 'কেন জার্নাল লিখবেন',
      titleEn: 'Why keep a journal',
      paragraphsBn: [
        'স্মৃতি তোষামোদ করে: বুদ্ধিমান জয়গুলো মনে থাকে, অসাবধান লসগুলো ভুলে যাই। জার্নাল দুটোই মনে রাখে।',
        'ঢোকার আগে লিখুন কেন ঢুকলেন, পরে লিখুন কী শিখলেন। এক মাসে প্যাটার্ন বেরিয়ে আসে — কোন নিয়ম বেশি ভাঙেন, কোন সেটআপ সত্যিই কাজ করে।',
        'এখানে সেদিনই লেসন লিখলে স্ট্রিক থাকে, আর মাসের রিপোর্ট দেখায় পরের মাসে কী ঠিক করতে হবে।',
      ],
      paragraphsEn: [
        'Memory flatters: we remember the clever wins and forget the careless '
            'losses. A journal remembers both.',
        'Write why you entered before, and what you learned after. Over a month '
            'patterns show — the rule you break most, the setup that actually '
            'pays.',
        'Here, a lesson written on the day keeps your streak alive, and the '
            'monthly report shows what to fix next.',
      ],
      questions: [
        Question(
          promptBn: 'ট্রেডের কারণ কখন লিখবেন?',
          promptEn: 'When do you write down why you took a trade?',
          optionsBn: ['ঢোকার আগে', 'শুধু জিতলে', 'মাস শেষে'],
          optionsEn: [
            'Before entering',
            'Only if it wins',
            'At the end of the month',
          ],
          whyBn: 'আগে লেখা কারণ পরে বদলানো যায় না — সেটাই এর মূল্য।',
          whyEn:
              'A reason written before cannot be rewritten after — that is its value.',
        ),
        Question(
          promptBn: 'এক মাসে জার্নাল কী দেখায়?',
          promptEn: 'What does a month of journal show?',
          optionsBn: [
            'কোন নিয়ম বেশি ভাঙেন',
            'আগামীকালের দাম',
            'অন্যদের ট্রেড',
          ],
          optionsEn: [
            'The rules you break most',
            "Tomorrow's price",
            "Other people's trades",
          ],
          whyBn: 'নিজের প্যাটার্নই সবচেয়ে কাজের তথ্য।',
          whyEn: 'Your own patterns are the most useful thing it holds.',
        ),
        Question(
          promptBn: 'লসও কেন লিখবেন?',
          promptEn: 'Why write the losses down too?',
          optionsBn: [
            'এগুলো থেকেই সবচেয়ে বেশি শেখা যায়',
            'খারাপ লাগার জন্য',
            'এগুলোর কোনো দাম নেই',
          ],
          optionsEn: [
            'They teach the most',
            'To feel bad',
            "They don't matter",
          ],
          whyBn: 'জয় আত্মবিশ্বাস দেয়; লস দেখায় কোথায় বদলাতে হবে।',
          whyEn: 'Wins give confidence; losses show what to change.',
        ),
      ],
    ),
  ];
}

/// A question with three answers, the first of them right. They are shown
/// in [order], so the right one is not always first.
class Question {
  const Question({
    required this.promptBn,
    required this.promptEn,
    required this.optionsBn,
    required this.optionsEn,
    required this.whyBn,
    required this.whyEn,
  });

  final String promptBn;
  final String promptEn;
  final List<String> optionsBn;
  final List<String> optionsEn;

  /// Why the right answer is right, shown once answered.
  final String whyBn;
  final String whyEn;

  String prompt(bool bangla) => bangla ? promptBn : promptEn;
  List<String> options(bool bangla) => bangla ? optionsBn : optionsEn;
  String why(bool bangla) => bangla ? whyBn : whyEn;

  /// The order to show the answers in: the same every time for the same
  /// [seed], and the right answer (index 0) not always first.
  static List<int> order(int seed) => switch (seed % 3) {
    0 => const [1, 0, 2],
    1 => const [2, 1, 0],
    _ => const [0, 2, 1],
  };
}
