import '../i18n/strings.dart';

/// When these documents last changed. Shown at the top of each, and stored
/// on a new account as the version it agreed to.
const legalUpdated = '26 September 2026';
const legalUpdatedBn = '২৬ সেপ্টেম্বর ২০২৬';
const termsVersion = '2026-09-26';

/// A document is a title, an introduction and numbered sections. A line
/// starting with "• " is drawn as a bullet; anything else as a paragraph.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updated;
  final String intro;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection(this.heading, this.lines);

  final String heading;
  final List<String> lines;
}

// These say what the app actually does. If the app changes what it collects,
// who can see it, or what deleting an account removes, this text has to
// change with it — and termsVersion with it.

LegalDocument privacyPolicy(AppLanguage lang) =>
    lang == AppLanguage.bn ? _privacyBn : _privacyEn;

LegalDocument termsOfUse(AppLanguage lang) =>
    lang == AppLanguage.bn ? _termsBn : _termsEn;

// --- Privacy policy -----------------------------------------------------------

const _privacyEn = LegalDocument(
  title: 'Privacy Policy',
  updated: 'Last updated $legalUpdated',
  intro:
      'This policy explains what Forex Social ("the app", "we") collects, why, '
      'who can see it, and how to delete it. The app is a practice simulator: '
      'it uses demo points and never real money.',
  sections: [
    LegalSection('1. What we collect', [
      'Account details you give us: your username, display name, password, '
          'gender (or "prefer not to say"), language and the avatar you pick.',
      'We do not ask for your email address, phone number, date of birth, '
          'location, contacts or photos. Your password is handled by Firebase '
          'Authentication and stored only as a secure hash — we never see it.',
      'What you do in the app:',
      '• Demo trades — the pair, direction, size, prices, times, your reason '
          'and your lesson — and the rule checks recorded on them.',
      '• Scores worked out from those trades: discipline score, badge points, '
          'trade count, total R, win rate and journal streak.',
      '• What you share: posts, comments, likes, connection requests and '
          'connections, messages, reports and blocks.',
      '• Activity: when you were last active, whether you are typing in a '
          'conversation, when you last opened a conversation (for read '
          'ticks), and whose profiles you viewed.',
      'Some preferences — which posts you have already seen, notices you have '
          'dismissed — stay on your phone and are never sent to us.',
      'The app contains no advertising, analytics or tracking tools, and we do '
          'not sell or rent your data. Our service providers may process '
          'technical data such as IP addresses in order to deliver the service '
          'and keep it secure.',
    ]),
    LegalSection('2. How we use it', [
      '• To run your account and the features you use: the journal, scores, '
          'leaderboard, feed, connections, messages and notifications.',
      '• To keep the community safe: to review reports and act on them.',
      'We do not use your data for advertising or build profiles of you.',
    ]),
    LegalSection('3. Who can see what', [
      '• Anyone signed in: your username, display name, avatar, scores, rank, '
          'number of connections, posts and comments.',
      '• Only you: your trades and journal, requests you have not answered, '
          'who viewed your profile, who you have blocked, and what you have '
          'muted or deleted for yourself.',
      '• Messages: the two people in the conversation. Messages are stored on '
          'our servers so they can be delivered; they are not end-to-end '
          'encrypted.',
      '• The Global chat: anyone signed in can read it, and what you write '
          'there shows your display name and username. Only members can '
          'write in it.',
      "• Communities: anyone signed in can see a community's name, "
          'description, members and points, and which community you are in. '
          "Its feed and its chat can be read only by its members.",
      '• Reports: the people who moderate the app.',
    ]),
    LegalSection('4. Where it is stored', [
      'Your data is stored with Google Firebase (Authentication and Cloud '
          'Firestore) in its Mumbai, India region. Leaderboard scores are '
          'calculated by a Cloudflare Workers service from your trades. These '
          'providers process data on our behalf under their own security and '
          'privacy commitments.',
    ]),
    LegalSection('5. How long we keep it', [
      '• As long as your account exists, unless noted below.',
      '• Notifications disappear from the app after 48 hours, and are deleted '
          'with your account.',
      '• Feed posts are shown for 7 days.',
      '• When you delete your account, everything in section 7 is deleted.',
    ]),
    LegalSection('6. Security', [
      'Access rules limit who can read or change each piece of data, data is '
          'encrypted in transit, and Google encrypts it at rest. No system is '
          'perfectly secure, so please use a password you do not use anywhere '
          'else.',
    ]),
    LegalSection('7. Your choices', [
      '• Change your name, avatar and password in Settings.',
      '• Block people, and report people, posts, comments or messages.',
      '• Delete your account in Settings → Delete account. This permanently '
          'deletes your profile, trades and scores, posts, comments and likes, '
          'connections, notifications, profile-view records, your '
          'conversations — for both people in them — your messages in the '
          'Global chat and in community chats, and your place in your '
          'community. A community you started stays, for its members. It '
          'cannot be undone. Your '
          'username is retired: it is linked to nothing any more, and nobody, '
          'you included, can register it again. Reports made by you or about '
          'you may be kept for moderation records, and views you added to '
          "other people's posts stay in their view counts.",
    ]),
    LegalSection('8. Age', ['The app is not intended for anyone under 18.']),
    LegalSection('9. Changes', [
      'If this policy changes, we will update this page and its date, and '
          'show significant changes in the app.',
    ]),
    LegalSection('10. Contact', [
      'For questions or requests about your data, write to the support email '
          "address shown on this app's App Store or Google Play page.",
    ]),
  ],
);

const _privacyBn = LegalDocument(
  title: 'প্রাইভেসি পলিসি',
  updated: 'সর্বশেষ হালনাগাদ $legalUpdatedBn',
  intro:
      'Forex Social ("অ্যাপ", "আমরা") কী তথ্য নেয়, কেন নেয়, কে দেখতে পায় '
      'আর কীভাবে মুছে ফেলা যায় — এই পলিসিতে তা বলা আছে। এটা একটা প্র্যাকটিস '
      'সিমুলেটর: এখানে ডেমো পয়েন্ট চলে, আসল টাকা কখনো না।',
  sections: [
    LegalSection('১. আমরা কী নিই', [
      'আপনার দেওয়া অ্যাকাউন্টের তথ্য: ইউজারনেম, নাম, পাসওয়ার্ড, জেন্ডার (অথবা '
          '"বলতে চাই না"), ভাষা আর আপনার বেছে নেওয়া অ্যাভাটার।',
      'আমরা ইমেইল, ফোন নম্বর, জন্মতারিখ, লোকেশন, কন্টাক্ট বা ছবি চাই না। '
          'পাসওয়ার্ড Firebase Authentication সামলায় এবং শুধু নিরাপদ হ্যাশ '
          'হিসেবে রাখে — আমরা কখনো সেটা দেখি না।',
      'অ্যাপে আপনি যা করেন:',
      '• ডেমো ট্রেড — পেয়ার, দিক, সাইজ, দাম, সময়, আপনার কারণ আর শিক্ষা — '
          'এবং সেগুলোর ওপর নিয়ম-ভাঙার হিসাব।',
      '• সেই ট্রেড থেকে হিসাব করা স্কোর: ডিসিপ্লিন স্কোর, ব্যাজ পয়েন্ট, '
          'ট্রেডের সংখ্যা, মোট R, জেতার হার আর জার্নাল স্ট্রিক।',
      '• আপনি যা শেয়ার করেন: পোস্ট, কমেন্ট, লাইক, কানেকশন রিকোয়েস্ট ও '
          'কানেকশন, মেসেজ, রিপোর্ট আর ব্লক।',
      '• অ্যাক্টিভিটি: শেষ কখন অ্যাক্টিভ ছিলেন, চ্যাটে লিখছেন কি না, শেষ কখন '
          'চ্যাট খুলেছেন (রিড টিকের জন্য), আর কার প্রোফাইল দেখেছেন।',
      'কিছু পছন্দ — কোন পোস্ট আগে দেখেছেন, কোন নোটিশ বন্ধ করেছেন — আপনার '
          'ফোনেই থাকে, আমাদের কাছে কখনো আসে না।',
      'অ্যাপে কোনো বিজ্ঞাপন, অ্যানালিটিক্স বা ট্র্যাকিং টুল নেই, আর আমরা '
          'আপনার তথ্য বিক্রি বা ভাড়া দিই না। সার্ভিস চালাতে আর নিরাপদ রাখতে '
          'আমাদের সার্ভিস প্রোভাইডাররা আইপি অ্যাড্রেসের মতো টেকনিক্যাল তথ্য '
          'ব্যবহার করতে পারে।',
    ]),
    LegalSection('২. আমরা কেন ব্যবহার করি', [
      '• আপনার অ্যাকাউন্ট আর আপনি যে ফিচার ব্যবহার করেন সেগুলো চালাতে: '
          'জার্নাল, স্কোর, লিডারবোর্ড, ফিড, কানেকশন, মেসেজ আর নোটিফিকেশন।',
      '• কমিউনিটি নিরাপদ রাখতে: রিপোর্ট দেখে ব্যবস্থা নিতে।',
      'আমরা বিজ্ঞাপনের জন্য আপনার তথ্য ব্যবহার করি না, আপনার প্রোফাইলও বানাই '
          'না।',
    ]),
    LegalSection('৩. কে কী দেখতে পায়', [
      '• যে কেউ যিনি লগইন করেছেন: আপনার ইউজারনেম, নাম, অ্যাভাটার, স্কোর, '
          'র‍্যাংক, কানেকশনের সংখ্যা, পোস্ট আর কমেন্ট।',
      '• শুধু আপনি: আপনার ট্রেড আর জার্নাল, যে রিকোয়েস্টের উত্তর দেননি, কে '
          'আপনার প্রোফাইল দেখেছে, আপনি কাকে ব্লক করেছেন, আর কী মিউট বা নিজের '
          'দিক থেকে ডিলিট করেছেন।',
      '• মেসেজ: চ্যাটের দুজন মানুষ। পৌঁছে দেওয়ার জন্য মেসেজ আমাদের সার্ভারে '
          'রাখা থাকে; এগুলো এন্ড-টু-এন্ড এনক্রিপ্টেড নয়।',
      '• গ্লোবাল চ্যাট: লগইন করা যে কেউ পড়তে পারেন, আর সেখানে আপনার লেখার '
          'সাথে আপনার নাম আর ইউজারনেম দেখা যায়। শুধু সদস্যরা লিখতে পারেন।',
      '• কমিউনিটি: লগইন করা যে কেউ কমিউনিটির নাম, বর্ণনা, সদস্য আর পয়েন্ট, '
          'আর আপনি কোন কমিউনিটিতে আছেন তা দেখতে পারেন। এর ফিড আর চ্যাট শুধু '
          'সদস্যরাই পড়তে পারেন।',
      '• রিপোর্ট: যাঁরা অ্যাপটা মডারেট করেন।',
    ]),
    LegalSection('৪. কোথায় রাখা হয়', [
      'আপনার তথ্য Google Firebase-এ (Authentication আর Cloud Firestore) '
          'ভারতের মুম্বাই রিজিয়নে রাখা হয়। লিডারবোর্ডের স্কোর আপনার ট্রেড থেকে '
          'একটা Cloudflare Workers সার্ভিস হিসাব করে। এই প্রোভাইডাররা নিজেদের '
          'নিরাপত্তা আর প্রাইভেসি নীতি মেনে আমাদের হয়ে তথ্য প্রসেস করে।',
    ]),
    LegalSection('৫. কতদিন রাখি', [
      '• আপনার অ্যাকাউন্ট যতদিন আছে, নিচের ব্যতিক্রম ছাড়া।',
      '• নোটিফিকেশন ৪৮ ঘণ্টা পর অ্যাপ থেকে সরে যায়, আর অ্যাকাউন্ট ডিলিট '
          'করলে মুছে যায়।',
      '• ফিডের পোস্ট ৭ দিন দেখানো হয়।',
      '• অ্যাকাউন্ট ডিলিট করলে ৭ নম্বর অংশে যা আছে সব মুছে যায়।',
    ]),
    LegalSection('৬. নিরাপত্তা', [
      'অ্যাক্সেস রুল ঠিক করে দেয় কে কোন তথ্য পড়তে বা বদলাতে পারবে, আসা-যাওয়ার '
          'পথে তথ্য এনক্রিপ্টেড থাকে, আর Google সেটা সংরক্ষিত অবস্থায়ও '
          'এনক্রিপ্ট করে রাখে। কোনো সিস্টেমই পুরোপুরি নিরাপদ নয় — তাই এমন '
          'পাসওয়ার্ড দিন যা অন্য কোথাও ব্যবহার করেন না।',
    ]),
    LegalSection('৭. আপনার হাতে যা আছে', [
      '• সেটিংসে নাম, অ্যাভাটার আর পাসওয়ার্ড বদলাতে পারেন।',
      '• কাউকে ব্লক করতে পারেন, আর মানুষ, পোস্ট, কমেন্ট বা মেসেজ রিপোর্ট করতে '
          'পারেন।',
      '• সেটিংস → অ্যাকাউন্ট ডিলিট থেকে অ্যাকাউন্ট মুছতে পারেন। এতে আপনার '
          'প্রোফাইল, ট্রেড ও স্কোর, পোস্ট, কমেন্ট ও লাইক, কানেকশন, '
          'নোটিফিকেশন, প্রোফাইল-ভিজিটের রেকর্ড, আপনার চ্যাটগুলো — দুজনের '
          'জন্যই — গ্লোবাল চ্যাট আর কমিউনিটি চ্যাটে আপনার মেসেজ, আর আপনার '
          'কমিউনিটির সদস্যপদ চিরতরে মুছে যায়। আপনার খোলা কমিউনিটি এর সদস্যদের '
          'জন্য থেকে যায়। এটা আর ফেরানো যায় না। আপনার ইউজারনেম '
          'অবসরে যায়: এটা আর কিছুর সাথে যুক্ত থাকে না, আর আপনিসহ কেউ এটা আবার '
          'নিতে পারে না। আপনার করা বা আপনাকে নিয়ে করা রিপোর্ট মডারেশনের রেকর্ড '
          'হিসেবে রাখা হতে পারে, আর অন্যের পোস্টে আপনার দেখা ভিউ কাউন্টে থেকে '
          'যায়।',
    ]),
    LegalSection('৮. বয়স', ['১৮ বছরের কম বয়সীদের জন্য এই অ্যাপ নয়।']),
    LegalSection('৯. পরিবর্তন', [
      'এই পলিসি বদলালে আমরা এই পাতা আর তারিখ হালনাগাদ করব, আর বড় পরিবর্তন '
          'অ্যাপে জানাব।',
    ]),
    LegalSection('১০. যোগাযোগ', [
      'আপনার তথ্য নিয়ে প্রশ্ন বা অনুরোধ থাকলে এই অ্যাপের App Store বা '
          'Google Play পাতায় দেওয়া সাপোর্ট ইমেইলে লিখুন।',
    ]),
  ],
);

// --- Terms and conditions -------------------------------------------------------

const _termsEn = LegalDocument(
  title: 'Terms & Conditions',
  updated: 'Last updated $legalUpdated',
  intro:
      'These terms are the agreement between you and Forex Social. By '
      'creating an account or using the app, you agree to them and to the '
      'Privacy Policy.',
  sections: [
    LegalSection('1. A practice app, not a broker', [
      '• The app uses demo points only. There are no deposits, withdrawals or '
          'real trades.',
      '• Points have no monetary value and cannot be bought, sold, '
          'transferred or exchanged for money or anything else.',
      '• Prices in the app are practice prices: they start from the European '
          "Central Bank's daily reference rates and then move on their own. "
          'They are not live and can differ from real markets.',
      '• Nothing in the app — including other people\'s posts and messages — '
          'is financial advice. Real trading carries a high risk of losing '
          'money.',
    ]),
    LegalSection('2. Who can use it', [
      'You must be at least 18. One account per person, and your account is '
          'for you alone.',
    ]),
    LegalSection('3. Your account', [
      'Keep your password safe and do not share it. The app does not collect '
          'an email address or phone number, so there is no password '
          'recovery: if you forget your password, the account cannot be '
          'recovered. Your username cannot be changed.',
    ]),
    LegalSection('4. Community rules', [
      'There is no tolerance for objectionable content or abusive users. Do '
          'not post, comment or send anything that is:',
      '• harassment, bullying, threats or hate towards anyone;',
      '• sexual, violent or graphic;',
      '• spam, a scam, or promotion of paid signals, "guaranteed profit" '
          'schemes or pump groups;',
      '• impersonation of another person, or someone else\'s personal '
          'information;',
      '• illegal, or encouraging anything illegal.',
      'You can report people, posts and messages, and block anyone. We review '
          'reports — aiming to within 24 hours — and may remove content and '
          'suspend or delete accounts that break these rules, without notice.',
    ]),
    LegalSection('5. Your content', [
      'You keep ownership of what you post. You allow us to store it and show '
          'it in the app so the service can work. You are responsible for '
          'what you post and send.',
    ]),
    LegalSection('6. Scores and the leaderboard', [
      'Scores are calculated automatically from your trades. We may '
          'recalculate, correct or reset them — for example after an error or '
          'abuse. Ranks carry no prize and no value.',
    ]),
    LegalSection('7. Ending your use', [
      'You can delete your account at any time in Settings. We may suspend or '
          'end accounts that break these terms.',
    ]),
    LegalSection('8. No warranties', [
      'The app is provided "as is", without any promise that it will always '
          'be available, accurate or free of errors. To the fullest extent '
          'the law allows, we are not liable for any loss arising from using '
          'the app, including decisions you make about real trading.',
    ]),
    LegalSection('9. Changes', [
      'We may update these terms. We will show significant changes in the '
          'app; continuing to use it afterwards means you accept them.',
    ]),
    LegalSection('10. Law', [
      'These terms are governed by the laws of Bangladesh.',
    ]),
    LegalSection('11. Contact', [
      "Write to the support email address shown on this app's App Store or "
          'Google Play page.',
    ]),
  ],
);

const _termsBn = LegalDocument(
  title: 'শর্তাবলি',
  updated: 'সর্বশেষ হালনাগাদ $legalUpdatedBn',
  intro:
      'এই শর্তগুলো আপনার আর Forex Social-এর মধ্যে চুক্তি। অ্যাকাউন্ট খুলে '
      'বা অ্যাপ ব্যবহার করে আপনি এই শর্ত আর প্রাইভেসি পলিসিতে রাজি হচ্ছেন।',
  sections: [
    LegalSection('১. এটা প্র্যাকটিসের অ্যাপ, ব্রোকার নয়', [
      '• অ্যাপে শুধু ডেমো পয়েন্ট চলে। কোনো ডিপোজিট, উইথড্র বা আসল ট্রেড নেই।',
      '• পয়েন্টের কোনো টাকার মূল্য নেই; কেনা, বেচা, হস্তান্তর বা টাকা বা '
          'অন্য কিছুর সাথে বদল করা যায় না।',
      '• অ্যাপের দাম প্র্যাকটিসের জন্য: ইউরোপিয়ান সেন্ট্রাল ব্যাংকের প্রতিদিনের '
          'রেফারেন্স রেট থেকে শুরু হয়ে নিজে থেকে ওঠানামা করে। এগুলো লাইভ নয়, '
          'আসল মার্কেটের সাথে না-ও মিলতে পারে।',
      '• অ্যাপের কোনো কিছুই — অন্যদের পোস্ট আর মেসেজসহ — আর্থিক পরামর্শ নয়। '
          'আসল ট্রেডিংয়ে টাকা হারানোর ঝুঁকি অনেক বেশি।',
    ]),
    LegalSection('২. কে ব্যবহার করতে পারবেন', [
      'বয়স অন্তত ১৮ হতে হবে। একজনের একটাই অ্যাকাউন্ট, আর অ্যাকাউন্টটা শুধু '
          'আপনার।',
    ]),
    LegalSection('৩. আপনার অ্যাকাউন্ট', [
      'পাসওয়ার্ড নিরাপদে রাখুন, কাউকে দেবেন না। অ্যাপ কোনো ইমেইল বা ফোন '
          'নম্বর নেয় না, তাই পাসওয়ার্ড রিকভারির উপায় নেই: পাসওয়ার্ড ভুলে গেলে '
          'অ্যাকাউন্ট আর ফেরানো যাবে না। ইউজারনেম বদলানো যায় না।',
    ]),
    LegalSection('৪. কমিউনিটির নিয়ম', [
      'আপত্তিকর কনটেন্ট বা হয়রানিকারী ইউজারের প্রতি কোনো ছাড় নেই। এমন কিছু '
          'পোস্ট, কমেন্ট বা মেসেজ করবেন না যা:',
      '• কাউকে হয়রানি, বুলিং, হুমকি বা ঘৃণা ছড়ায়;',
      '• যৌন, সহিংস বা বীভৎস;',
      '• স্প্যাম, প্রতারণা, অথবা টাকার বিনিময়ে সিগন্যাল, "নিশ্চিত লাভ" স্কিম '
          'বা পাম্প গ্রুপের প্রচার;',
      '• অন্য কারো ছদ্মবেশ, বা অন্য কারো ব্যক্তিগত তথ্য;',
      '• বেআইনি, বা বেআইনি কিছুতে উৎসাহ দেয়।',
      'আপনি মানুষ, পোস্ট আর মেসেজ রিপোর্ট করতে পারেন, আর যে কাউকে ব্লক '
          'করতে পারেন। আমরা রিপোর্ট দেখি — ২৪ ঘণ্টার মধ্যে দেখার চেষ্টা করি — '
          'আর নিয়ম ভাঙলে আগে না জানিয়েই কনটেন্ট সরাতে এবং অ্যাকাউন্ট স্থগিত '
          'বা মুছে দিতে পারি।',
    ]),
    LegalSection('৫. আপনার কনটেন্ট', [
      'আপনি যা পোস্ট করেন তার মালিক আপনিই। সার্ভিস চালানোর জন্য সেটা রাখা আর '
          'অ্যাপে দেখানোর অনুমতি আপনি আমাদের দিচ্ছেন। আপনি যা পোস্ট আর '
          'মেসেজ করেন তার দায় আপনার।',
    ]),
    LegalSection('৬. স্কোর আর লিডারবোর্ড', [
      'স্কোর আপনার ট্রেড থেকে নিজে নিজে হিসাব হয়। কোনো ভুল বা অপব্যবহার হলে '
          'আমরা স্কোর আবার হিসাব, ঠিক বা রিসেট করতে পারি। র‍্যাংকের কোনো '
          'পুরস্কার বা মূল্য নেই।',
    ]),
    LegalSection('৭. ব্যবহার বন্ধ করা', [
      'সেটিংস থেকে যেকোনো সময় অ্যাকাউন্ট ডিলিট করতে পারেন। শর্ত ভাঙলে আমরা '
          'অ্যাকাউন্ট স্থগিত বা বন্ধ করতে পারি।',
    ]),
    LegalSection('৮. কোনো নিশ্চয়তা নেই', [
      'অ্যাপটা "যেমন আছে তেমন" দেওয়া হচ্ছে — সবসময় চালু, নির্ভুল বা '
          'ত্রুটিমুক্ত থাকার কোনো প্রতিশ্রুতি নেই। আইন যতটা অনুমতি দেয়, অ্যাপ '
          'ব্যবহার থেকে হওয়া কোনো ক্ষতির — আসল ট্রেডিং নিয়ে আপনার নেওয়া '
          'সিদ্ধান্তসহ — দায় আমাদের নয়।',
    ]),
    LegalSection('৯. পরিবর্তন', [
      'আমরা এই শর্ত হালনাগাদ করতে পারি। বড় পরিবর্তন অ্যাপে জানাব; এরপরও '
          'ব্যবহার চালিয়ে গেলে আপনি সেগুলো মেনে নিচ্ছেন।',
    ]),
    LegalSection('১০. আইন', ['এই শর্তাবলি বাংলাদেশের আইন অনুযায়ী চলবে।']),
    LegalSection('১১. যোগাযোগ', [
      'এই অ্যাপের App Store বা Google Play পাতায় দেওয়া সাপোর্ট ইমেইলে লিখুন।',
    ]),
  ],
);
