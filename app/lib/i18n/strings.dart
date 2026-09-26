/// The two languages the app ships in.
enum AppLanguage {
  bn('বাংলা', 'Bangla', '🇧🇩'),
  en('English', 'English', '🌐');

  const AppLanguage(this.nativeName, this.englishName, this.flag);

  /// Name written in the language itself — what the picker shows.
  final String nativeName;
  final String englishName;
  final String flag;

  static AppLanguage fromCode(String? code) =>
      code == 'bn' ? AppLanguage.bn : AppLanguage.en;

  String get code => name;
}

/// Every user-facing string, both languages side by side.
///
/// A plain class rather than ARB files and code generation: two languages and
/// one app, where keeping the Bangla and the English on the same line makes a
/// missing or drifting translation obvious at a glance. If a third language is
/// ever added, this is the point to switch to `flutter gen-l10n`.
class Strings {
  const Strings(this.lang);

  final AppLanguage lang;

  String _t(String bn, String en) => lang == AppLanguage.bn ? bn : en;

  bool get isBangla => lang == AppLanguage.bn;

  // --- Navigation ---------------------------------------------------------

  String get navPortfolio => _t('পোর্টফোলিও', 'Portfolio');
  String get navTrade => _t('ট্রেড', 'Trade');
  String get navJournal => _t('জার্নাল', 'Journal');
  String get navCommunity => _t('কমিউনিটি', 'Community');
  String get navMessages => _t('মেসেজ', 'Messages');

  // --- Auth: shared -------------------------------------------------------

  String get appName => _t('ফরেক্স সোশ্যাল', 'Forex Social');
  String get appTagline => _t(
    'ডেমো টাকায় শিখুন। আসল ঝুঁকি ছাড়া।',
    'Learn on demo money. Without the real risk.',
  );
  String get username => _t('ইউজারনেম', 'Username');
  String get password => _t('পাসওয়ার্ড', 'Password');
  String get fullName => _t('পুরো নাম', 'Full name');
  String get next => _t('পরের ধাপ', 'Next');
  String get back => _t('পেছনে', 'Back');
  String get finish => _t('শুরু করুন', 'Get started');

  // --- Auth: login --------------------------------------------------------

  String get login => _t('লগইন', 'Log in');
  String get logOut => _t('লগআউট', 'Log out');
  String get chartLoading => _t('চার্ট লোড হচ্ছে…', 'Loading chart…');

  /// Under the chart. [date] is the ECB's, `2026-09-25`; null before any
  /// rates have been fetched.
  String practicePrices(String? date) {
    final day = date == null ? null : DateTime.tryParse(date);
    return day == null
        ? _t(
            'প্র্যাকটিস দাম — আসল রেটের কাছাকাছি, লাইভ নয়',
            'Practice prices — near real rates, not live',
          )
        : _t(
            'প্র্যাকটিস দাম — ${shortDate(day)}-এর ECB রেট থেকে, লাইভ নয়',
            'Practice prices — from ECB rates of ${shortDate(day)}, not live',
          );
  }

  String get loginTitle => _t('ফিরে এসেছেন', 'Welcome back');
  String get loginSubtitle =>
      _t('ইউজারনেম আর পাসওয়ার্ড দিন।', 'Enter your username and password.');
  String get noAccount => _t('অ্যাকাউন্ট নেই?', 'No account?');
  String get createAccount => _t('নতুন অ্যাকাউন্ট', 'Create one');
  String get haveAccount => _t('অ্যাকাউন্ট আছে?', 'Already have one?');
  String get wrongLogin =>
      _t('ইউজারনেম বা পাসওয়ার্ড ভুল।', 'Wrong username or password.');

  /// Shown instead of a password-reset flow, because there isn't one.

  // --- Auth: signup steps -------------------------------------------------

  String get chooseLanguage => _t('ভাষা বেছে নিন', 'Choose your language');
  String get chooseLanguageHint => _t(
    'পুরো অ্যাপ এই ভাষায় চলবে। পরেও বদলাতে পারবেন।',
    'The whole app will use this. You can change it later.',
  );

  String get yourDetails => _t('আপনার পরিচয়', 'About you');
  String get usernameHint => _t(
    'ছোট হাতের অক্ষর, সংখ্যা আর _ — ৩ থেকে ২০ অক্ষর',
    'Lowercase letters, numbers and _ — 3 to 20 characters',
  );
  String get usernameTaken =>
      _t('এই নামটা নেওয়া হয়ে গেছে', 'That one is taken');
  String get usernameAvailable => _t('পাওয়া যাবে', 'Available');
  String get usernameChecking => _t('দেখছি…', 'Checking…');
  String get usernameSuggestions => _t('এগুলো খালি আছে:', 'These are free:');
  String get usernameTooShort =>
      _t('অন্তত ৩ অক্ষর লাগবে', 'At least 3 characters');
  String get usernameBadChars => _t(
    'শুধু ছোট হাতের অক্ষর, সংখ্যা আর _ চলবে',
    'Only lowercase letters, numbers and _',
  );
  String get passwordTooShort =>
      _t('অন্তত ৬ অক্ষর লাগবে', 'At least 6 characters');
  String get nameRequired => _t('নাম লিখুন', 'Enter your name');
  String get usernameIsPermanent => _t(
    'ইউজারনেম পরে বদলানো যাবে না — একবারই।',
    'Your username is permanent. Choose well.',
  );

  String get chooseGender => _t('আপনি', 'You are');
  String get genderMale => _t('ছেলে', 'Male');
  String get genderFemale => _t('মেয়ে', 'Female');
  String get genderOther => _t('অন্য', 'Other');
  String get genderPrivate => _t('বলতে চাই না', 'Prefer not to say');

  String get chooseAvatar => _t('অ্যাভাটার বেছে নিন', 'Pick your avatar');
  String get chooseAvatarHint => _t(
    'লিডারবোর্ড আর ফিডে এটাই দেখা যাবে।',
    'This is what the leaderboard and feed will show.',
  );

  // Split so the two document names can be links inside the sentence.
  String get agreePrefix => _t(
    'আমার বয়স ১৮ বা তার বেশি, আর আমি ',
    'I am 18 or older, and I agree to the ',
  );
  String get agreeTerms => _t('শর্তাবলি', 'Terms & Conditions');
  String get agreeAnd => _t(' ও ', ' and ');
  String get agreePrivacy => _t('প্রাইভেসি পলিসি', 'Privacy Policy');
  String get agreeSuffix => _t('তে রাজি।', '.');

  String get creatingAccount =>
      _t('অ্যাকাউন্ট তৈরি হচ্ছে…', 'Creating your account…');

  String welcomeUser(String name) => _t('স্বাগতম, $name!', 'Welcome, $name!');

  String get startingBalanceNote => _t(
    'আপনি \$১০০ ডেমো ব্যালেন্স পেয়েছেন — \$১,০০,০০০ না। কারণ আসল '
        'শিক্ষাটা ছোট অ্যাকাউন্টেই হয়।',
    'You start with \$100 in demo money — not \$100,000. The real lesson '
        'only shows up on a small account.',
  );

  // --- Portfolio ----------------------------------------------------------

  String get equityDemo => _t('ইকুইটি (ডেমো)', 'Equity (demo)');
  String get balance => _t('ব্যালেন্স', 'Balance');
  String get openPnl => _t('চলমান লাভ/লস', 'Open P&L');
  String get totalR => _t('মোট R', 'Total R');
  String get disciplineScore => _t('ডিসিপ্লিন স্কোর', 'Discipline score');
  String get rankedOnThis =>
      _t('লিডারবোর্ড এটা দিয়েই', 'Leaderboard ranks on this');
  String get noRulesBroken => _t(
    'এখন পর্যন্ত কোনো নিয়ম ভাঙেননি। লাভ-লস যাই হোক, এভাবে চললে আপনি '
        'টিকে থাকবেন।',
    'No rules broken yet. Win or lose, keep this up and you will survive.',
  );
  String get rulesYouBreak =>
      _t('যে নিয়মগুলো ভাঙছেন:', 'Rules you are breaking:');
  String timesCount(int n) => _t('$n বার', '$n×');

  String get trades => _t('ট্রেড', 'Trades');
  String get discipline => _t('ডিসিপ্লিন', 'Discipline');

  // --- Daily points and badges --------------------------------------------

  String get todaysPoints => _t('আজকের পয়েন্ট', "Today's points");
  String get todaysResult => _t('আজকের ফল', "Today's result");
  String get points => _t('পয়েন্ট', 'points');

  String resetsIn(String time) => _t('$time পরে রিসেট', 'resets in $time');

  String get dailyResetNote => _t(
    'প্রতিদিন রাত ১২টায় সবাই আবার ১০,০০০ পয়েন্ট পায়। আগের দিনের লাভ বা '
        'লস জমা থাকে না — সবাই সমান জায়গা থেকে শুরু করে। শুধু ব্যাজ থেকে যায়।',
    'Everyone is handed 10,000 points again at midnight. Yesterday does not '
        'carry over, so nobody starts ahead. Only the badge survives.',
  );

  String get badge => _t('ব্যাজ', 'Badge');
  String get badgePoints => _t('ব্যাজ পয়েন্ট', 'Badge points');

  String pointsToNext(int n, String tier) =>
      _t('$tier-এ যেতে আরও $n', '$n more to reach $tier');

  String get atTopTier => _t('সর্বোচ্চ ধাপ', 'Top tier');

  String get badgeRule => _t(
    'জেতা প্রতি ট্রেডে +১, হারা প্রতি ট্রেডে −১। ব্যাজ নামতেও পারে — '
        'না নামলে ওটার কোনো মানে থাকত না।',
    'Every winning trade is +1, every loser −1. The badge can fall — if it '
        'could not, it would mean nothing.',
  );

  String winsLosses(int wins, int losses) =>
      _t('$wins জয় · $losses পরাজয়', '$wins won · $losses lost');

  String get stats => _t('পরিসংখ্যান', 'Stats');
  String get expectancy => _t('এক্সপেক্টেন্সি', 'Expectancy');
  String get perTradeAvg => _t('প্রতি ট্রেডে গড়', 'avg per trade');
  String get winRate => _t('উইন রেট', 'Win rate');
  String tradesOf(int a, int b) => _t('$a/$b ট্রেড', '$a of $b');
  String get maxDrawdown => _t('ম্যাক্স ড্রডাউন', 'Max drawdown');
  String recoverNeeds(String pct) => _t('ফিরতে $pct', 'needs $pct back');

  String winRateInsight(String pct) => _t(
    '$pct ট্রেডে জিতেও আপনি লাভে আছেন — কারণ জেতার সময় বড় জিতছেন। '
        'উইন রেট না, এক্সপেক্টেন্সিই আসল।',
    'You win only $pct of trades and still make money — because the wins '
        'are bigger. Expectancy matters, win rate does not.',
  );

  String get openPositions => _t('খোলা পজিশন', 'Open positions');
  String countItems(int n) => _t('$nটি', '$n');
  String get noOpenPositions => _t(
    'এখন কোনো ট্রেড খোলা নেই।\nসেটআপের জন্য অপেক্ষা করাও একটা সিদ্ধান্ত।',
    'Nothing open right now.\nWaiting for a setup is also a decision.',
  );
  String get closePosition => _t('বন্ধ করুন', 'Close');
  String get lots => _t('লট', 'lots');

  // --- Trade --------------------------------------------------------------

  String get spread => _t('স্প্রেড', 'Spread');
  String get pips => _t('পিপ', 'pips');
  String get buy => _t('বাই', 'Buy');
  String get sell => _t('সেল', 'Sell');
  String get plan => _t('প্ল্যান', 'Plan');

  // --- Risk presets --------------------------------------------------------

  String get presetCareful => _t('নিরাপদ', 'Careful');
  String get presetStandard => _t('সাধারণ', 'Standard');
  String get presetBold => _t('সাহসী', 'Bold');
  String get customPlan => _t('নিজের হিসাব', 'Custom');
  String get setItMyself => _t('নিজে ঠিক করুন', 'Set it myself');

  /// What the chosen risk actually costs, in the only terms that matter.
  String survivalNote(int losses, String left) => _t(
    'টানা $losses বার হারলে অ্যাকাউন্টের $left বাকি থাকবে।',
    '$left of the account is left after $losses losses in a row.',
  );

  String planSummary(String stop, String target, String risk) => _t(
    'স্টপ $stop · টার্গেট $target · রিস্ক $risk',
    'Stop $stop · target $target · risk $risk',
  );

  String get stopLoss => _t('স্টপ লস', 'Stop loss');
  String get target => _t('টার্গেট', 'Target');
  String get entry => _t('এন্ট্রি', 'Entry');
  String get risk => _t('রিস্ক', 'Risk');
  String get calculation => _t('হিসাব', 'The maths');
  String get sizeFromRisk => _t('রিস্ক থেকে সাইজ', 'Size from risk');
  String get positionSize => _t('পজিশন সাইজ', 'Position size');
  String get units => _t('ইউনিট', 'units');
  String get ifYouLose => _t('হারলে', 'If wrong');
  String get ifYouWin => _t('জিতলে', 'If right');

  String riskWarning(String pct, String lostPct) => _t(
    'ট্রেডে $pct রিস্ক নিলে টানা ১০টা হারলে অ্যাকাউন্টের $lostPct চলে '
        'যাবে। পেশাদাররা ১%-এর নিচে রাখেন।',
    'Risking $pct a trade means ten losses in a row costs you $lostPct of '
        'the account. Professionals stay under 1%.',
  );

  String belowMinimumLot(String pct, String exact, String minPct) => _t(
    'এই অ্যাকাউন্টে $pct রিস্কে সাইজ হয় $exact লট — কিন্তু ব্রোকারের '
        'সর্বনিম্ন সাইজ ০.০১ লট। সেটা নিলে রিস্ক দাঁড়াবে $minPct।\n\n'
        'এটাই ছোট অ্যাকাউন্টের আসল সমস্যা — বেশিরভাগ অ্যাপ এটা লুকায়। '
        'সমাধান: স্টপ কাছে আনুন, নয়তো ব্যালেন্স বাড়ান।',
    'At $pct risk this account sizes to $exact lots — but the smallest a '
        'broker accepts is 0.01. Taking that means risking $minPct instead.\n\n'
        'This is the real problem with a small account, and most apps hide it. '
        'Either bring the stop closer, or grow the balance first.',
  );

  String get whyThisTrade => _t('কেন এই ট্রেড?', 'Why this trade?');
  String get whyHint => _t(
    'যেমন: H4 সাপোর্টে বুলিশ এনগাল্ফিং, ভলিউম কনফার্ম করেছে',
    'e.g. Bullish engulfing at H4 support, volume confirmed',
  );
  String get whyFootnote => _t(
    'ছয় মাস পর এই লেখাটাই বলে দেবে আপনি ট্রেডার নাকি জুয়াড়ি ছিলেন।',
    'Six months from now this sentence tells you whether you were trading '
        'or gambling.',
  );

  String get breakingRules => _t('নিয়ম ভাঙছেন', 'Breaking rules');
  String pointsPenalty(int n) => _t('−$n পয়েন্ট', '−$n points');
  String get violationsAllowed => _t(
    'ট্রেডটা আটকানো হবে না — কিন্তু ডিসিপ্লিন স্কোরে যোগ হবে।',
    'The trade still goes through — it just costs discipline points.',
  );

  String get blockedBelowMinLot => _t(
    'এই রিস্কে সাইজ সর্বনিম্ন লটের চেয়ে ছোট',
    'Size is below the minimum lot at this risk',
  );
  String get blockedZeroSize => _t('পজিশন সাইজ শূন্য', 'Position size is zero');
  String get blockedNoReason => _t(
    'কেন ট্রেডটা নিচ্ছেন লিখুন (অন্তত ১০ অক্ষর)',
    'Write why you are taking it (at least 10 characters)',
  );

  String tradeOpened(String symbol, String dir, String stop) => _t(
    '$symbol $dir খোলা হয়েছে · স্টপ $stop পিপ',
    '$symbol $dir opened · $stop pip stop',
  );

  // --- Journal ------------------------------------------------------------

  String get emptyJournal => _t(
    'এখনো কোনো ট্রেড বন্ধ হয়নি।\n\n'
        'জার্নাল ছাড়া ট্রেডিং হলো অন্ধকারে গুলি ছোড়া —\n'
        'কোনটা লাগল আর কোনটা লাগল না, কিছুই জানবেন না।',
    'No closed trades yet.\n\n'
        'Trading without a journal is shooting in the dark —\n'
        'you never learn which shots landed.',
  );
  String get performance => _t('পারফরম্যান্স', 'Performance');
  String get profitFactor => _t('প্রফিট ফ্যাক্টর', 'Profit factor');
  String get aboveOneGood => _t('১.০ এর উপরে ভালো', 'above 1.0 is good');
  String get total => _t('মোট', 'Total');
  String get avgWin => _t('গড় জয়', 'Avg win');
  String get avgLoss => _t('গড় পরাজয়', 'Avg loss');
  String get lowIsFine => _t('কম হলেও চলে', 'low is fine');
  String get drawdownAndRecovery =>
      _t('ড্রডাউন ও ফেরার অঙ্ক', 'Drawdown and recovery');
  String get maxDrawdownLong => _t('সর্বোচ্চ ড্রডাউন', 'Max drawdown');
  String get recoveryNeeded => _t('ফিরতে লাগবে', 'Needed to recover');
  String get lossAndGainAsymmetry =>
      _t('লস আর লাভের অঙ্ক সমান না:', 'Losses and gains are not symmetric:');
  String ifYouLosePct(String pct) => _t('$pct হারালে', 'Lose $pct');
  String needsGainPct(String pct) =>
      _t('ফিরতে লাগবে $pct', 'need $pct to get back');

  String get closedTrades => _t('বন্ধ হওয়া ট্রেড', 'Closed trades');
  String get size => _t('সাইজ', 'Size');
  String get cost => _t('খরচ', 'Cost');
  String get swap => _t('সোয়াপ', 'Swap');
  String get whyITookIt => _t('কেন নিয়েছিলাম', 'Why I took it');
  String get whatILearned => _t('কী শিখলাম', 'What I learned');
  String get writeLesson => _t('কী শিখলেন লিখুন', 'Write what you learned');
  String get whatDidYouLearn => _t('কী শিখলেন?', 'What did you learn?');
  String get lessonHint => _t(
    'যেমন: সেটআপ ঠিক ছিল, কিন্তু স্টপ খুব কাছে দিয়েছিলাম।',
    'e.g. The setup was right, but my stop was too tight.',
  );
  String get lessonPrompt => _t(
    'জিতেছেন না হেরেছেন সেটা না — কোন সিদ্ধান্তটা ঠিক ছিল, কোনটা ভুল।',
    'Not whether you won — which decisions were right and which were not.',
  );
  String get save => _t('সেভ করুন', 'Save');

  // --- Community ----------------------------------------------------------

  String get leaderboard => _t('লিডারবোর্ড', 'Leaderboard');
  String get feed => _t('ফিড', 'Feed');
  String get leaderboardExplainer => _t(
    'এই তালিকা লাভ দিয়ে সাজানো না — ডিসিপ্লিন দিয়ে সাজানো।\n'
        'কে নিয়ম মেনেছে সেটাই র‍্যাংক ঠিক করে। লাভ দিয়ে র‍্যাংক করলে এই '
        'অ্যাপটা ক্যাসিনো হয়ে যেত।',
    'This list is not ranked by profit — it is ranked by discipline.\n'
        'Who followed their own rules decides the order. Ranking by profit '
        'would turn this app into a casino.',
  );
  String tradesToRank(int n) => _t(
    'র‍্যাংকে আসতে আরও $nটা ট্রেড বন্ধ করুন',
    'Close $n more ${n == 1 ? 'trade' : 'trades'} to be ranked',
  );
  String get rankedByDiscipline => _t(
    'লাভ নয় — ডিসিপ্লিন দিয়ে র‍্যাংক',
    'Ranked by discipline, not profit',
  );
  String get gotIt => _t('বুঝেছি', 'Got it');
  String get hide => _t('লুকান', 'Hide');
  String tradeCount(int n) => _t('$n ট্রেড', '$n trades');
  String get followedRules => _t('নিয়ম মেনেছে', 'Followed the rules');
  String get brokeRules => _t('নিয়ম ভেঙেছে', 'Broke the rules');
  String get you => _t('আপনি', 'You');

  // --- Reactions ----------------------------------------------------------

  String get comments => _t('মন্তব্য', 'Comments');
  String get newPost => _t('নতুন পোস্ট', 'New post');
  String get shareToFeed => _t('ফিডে শেয়ার', 'Share to feed');
  String get publish => _t('পোস্ট করুন', 'Post');
  String get posted => _t('ফিডে পোস্ট হয়েছে', 'Posted to the feed');

  /// The live count is capped at 20, so anything at the cap reads as "20+".
  String newPostsCount(int n) {
    final shown = n >= 20 ? '20+' : '$n';
    return _t('$shownটা নতুন পোস্ট', '$shown new ${n == 1 ? 'post' : 'posts'}');
  }

  String get result => _t('ফল', 'Result');
  String get pair => _t('পেয়ার', 'Pair');
  String get lessonRequiredToPost => _t(
    'কী শিখলেন সেটা ছাড়া পোস্ট করা যাবে না — অন্তত ১০ অক্ষর।',
    'A post needs what you learned — at least 10 characters.',
  );
  String get postGuideline => _t(
    'ফল যাই হোক লিখুন। হারা ট্রেডের পোস্টই সবচেয়ে কাজের — সিগন্যাল না।',
    'Post either result. The losing ones teach the most. No signals.',
  );
  String get alreadyShared => _t('শেয়ার করা হয়েছে', 'Shared');

  // --- Communities ------------------------------------------------------------

  String get communities => _t('কমিউনিটি', 'Communities');
  String get joinOrStart =>
      _t('জয়েন করুন বা নতুন খুলুন', 'Join one, or start your own');
  String get yourCommunity => _t('আপনার কমিউনিটি', 'Your community');
  String get noCommunityYet => _t(
    'এখনো কোনো কমিউনিটিতে নেই। একটায় জয়েন করুন, বা নিজে খুলুন।',
    "You're not in a community yet. Join one, or start your own.",
  );
  String get startCommunity => _t('নতুন কমিউনিটি খুলুন', 'Start a community');
  String get allCommunities => _t('সব কমিউনিটি', 'All communities');
  String get noCommunities => _t(
    'এখনো কোনো কমিউনিটি নেই — প্রথমটা আপনিই খুলুন!',
    'No communities yet — start the first one!',
  );
  String communityPoints(int n) =>
      _t('$n পয়েন্ট', n == 1 ? '1 point' : '$n points');
  String get pointsExplain => _t(
    'পয়েন্ট আসে লিডারবোর্ড থেকে: টপ ৫০-এ সদস্য যত উপরে, কমিউনিটি তত বেশি পয়েন্ট পায় (#১ = ৫০, #৫০ = ১)।',
    'Points come from the leaderboard: the higher a member stands in the top '
        '50, the more their community gets (#1 = 50, #50 = 1).',
  );
  String joinedCommunity(String name) =>
      _t('$name-এ জয়েন করেছেন', 'You joined $name');
  String get switchCommunityTitle =>
      _t('কমিউনিটি বদলাবেন?', 'Switch community?');
  String switchCommunityBody(String from, String to) => _t(
    'একবারে একটা কমিউনিটিতেই থাকা যায়। $from ছেড়ে $to-তে জয়েন করবেন?',
    'You can be in one community at a time. Leave $from and join $to?',
  );
  String get switchAction => _t('বদলান', 'Switch');
  String get leaveCommunity => _t('কমিউনিটি ছাড়ুন', 'Leave community');
  String leaveCommunityTitle(String name) =>
      _t('$name ছাড়বেন?', 'Leave $name?');
  String get leaveCommunityBody => _t(
    'এর ফিড আর চ্যাট আর দেখতে পাবেন না। আপনার পোস্ট থেকে যাবে। যেকোনো সময় আবার জয়েন করতে পারবেন।',
    "You won't see its feed or chat any more. Your posts stay. You can join "
        'again any time.',
  );
  String leftCommunity(String name) => _t('$name ছেড়েছেন', 'You left $name');
  String get communityAdmin => _t('অ্যাডমিন', 'Admin');
  String get openChat => _t('চ্যাট খুলুন', 'Open chat');
  String get viewCommunity => _t('কমিউনিটি দেখুন', 'View community');
  String get communityChatEmpty => _t(
    'এখানে শুধু সদস্যরা কথা বলে। প্রথম কথাটা আপনিই বলুন!',
    'Only members talk here. Say the first word!',
  );
  String communityRank(int rank) =>
      _t('কমিউনিটি র‍্যাংক #$rank', 'Community rank #$rank');
  String get membersHeading => _t('সদস্য', 'Members');
  String get pointsHeading => _t('পয়েন্ট', 'Points');
  String get communityGone =>
      _t('এই কমিউনিটি আর নেই', "This community isn't here any more");
  String get editDescription => _t('বর্ণনা বদলান', 'Edit description');
  String get communityName => _t('কমিউনিটির নাম', 'Community name');
  String get communityDescriptionHint => _t(
    'কমিউনিটি নিয়ে কয়েক কথা (ঐচ্ছিক)',
    'A few words about it (optional)',
  );
  String get communityNameRule => _t('৩–৪০ অক্ষর', '3–40 characters');
  String get communityNameTaken =>
      _t('এই নামে আগেই একটা কমিউনিটি আছে', 'A community already has this name');
  String communityCreated(String name) => _t(
    '$name খোলা হয়েছে — আপনি অ্যাডমিন',
    "$name is open — you're its admin",
  );
  String get startCommunityBody => _t(
    'আপনি এর অ্যাডমিন হবেন, আর এর নিজের একটা চ্যাট রুম নিজে থেকেই খুলবে। যে কেউ জয়েন করতে পারবে।',
    "You'll be its admin, and it gets its own chat room. Anyone can join.",
  );
  String startLeaves(String name) => _t(
    'খুললে $name ছেড়ে দেবেন — একবারে একটাই।',
    'Starting one leaves $name — one at a time.',
  );
  String get startAction => _t('খুলুন', 'Start');

  // The feed, Global or a community's.
  String get whichFeed => _t('কোন ফিড দেখবেন?', 'Which feed?');
  String get everyonesPosts => _t('সবার পোস্ট', "Everyone's posts");
  String get membersOnly => _t('শুধু সদস্যদের পোস্ট', 'Members only');
  String get joinACommunity =>
      _t('একটা কমিউনিটিতে জয়েন করুন', 'Join a community');
  String postingTo(String where) =>
      _t('$where-এ পোস্ট হবে', 'Posting to $where');

  // --- Search ---------------------------------------------------------------

  String get search => _t('সার্চ', 'Search');
  String get searchHint =>
      _t('নাম বা @ইউজারনেম দিয়ে খুঁজুন', 'Search by name or @username');
  String get recentSearches => _t('সাম্প্রতিক', 'Recent');
  String get clearAll => _t('সব মুছুন', 'Clear all');
  String get suggestedForYou => _t('আপনার জন্য', 'Suggested for you');
  String get people => _t('মানুষ', 'People');
  String get posts => _t('পোস্ট', 'Posts');
  String get connectedLabel => _t('কানেক্টেড', 'Connected');
  String mutualConnections(int n) => _t(
    '$n জন মিউচুয়াল কানেকশন',
    n == 1 ? '1 mutual connection' : '$n mutual connections',
  );
  String newMessages(int n) =>
      _t('$nটা নতুন মেসেজ', n == 1 ? '1 new message' : '$n new messages');
  String noOneFound(String q) =>
      _t('"$q" নামে কাউকে পাওয়া যায়নি', 'No one found for "$q"');
  String get noSuggestionsYet => _t(
    'কারো সাথে কানেক্ট করলে বা লিডারবোর্ডে কেউ থাকলে এখানে দেখাবে।',
    'People you connect with, and people on the leaderboard, show up here.',
  );

  // --- Deleting and sharing posts ------------------------------------------

  String get deletePost => _t('পোস্ট ডিলিট', 'Delete post');
  String get deletePostTitle => _t('পোস্টটি ডিলিট করবেন?', 'Delete this post?');
  String get deletePostBody => _t(
    'লাইক আর কমেন্টসহ পোস্টটা সবার কাছ থেকে মুছে যাবে। এটা আর ফেরানো যাবে না।',
    "It goes for everyone, with its likes and comments. This can't be "
        'undone.',
  );
  String get postDeleted => _t('পোস্ট ডিলিট হয়েছে', 'Post deleted');
  String get couldNotDeletePost => _t(
    'ডিলিট হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন।',
    'Not deleted — check your connection and try again.',
  );
  String get sendInChat => _t('চ্যাটে পাঠান', 'Send in a chat');
  String get postToFeed => _t('ফিডে পোস্ট করুন', 'Post to the feed');
  String get sendTo => _t('কাকে পাঠাবেন?', 'Send to…');
  String sentTo(int n) => _t(
    n == 1 ? 'পাঠানো হয়েছে' : '$nটা চ্যাটে পাঠানো হয়েছে',
    n == 1 ? 'Sent' : 'Sent to $n chats',
  );

  /// [where] is "@username", or the room's name.
  String sendFailed(String where) => _t(
    '$where-এ পাঠানো যায়নি — হয়তো কানেকশন নেই।',
    "Couldn't send to $where — you may not be connected.",
  );
  String get sharedPost => _t('পোস্ট', 'Post');
  String get sharedRank => _t('লিডারবোর্ড র‍্যাংক', 'Leaderboard rank');

  /// What an inbox row or a banner shows for a message: its words, or what
  /// was shared with it, or both.
  String messagePreview(String text, String? attachmentType) {
    final label = switch (attachmentType) {
      'post' => '📊 $sharedPost',
      'rank' => '🏅 $sharedRank',
      _ => null,
    };
    if (label == null) return text;
    return text.isEmpty ? label : '$label · $text';
  }

  String get postUnavailable =>
      _t('পোস্টটি আর নেই', 'This post is no longer available');
  String get viewPost => _t('পোস্ট দেখুন', 'View post');

  // --- Sharing your rank --------------------------------------------------

  String get shareYourRank => _t('র‍্যাংক শেয়ার', 'Share your rank');
  String get howYouGotHere => _t('কীভাবে এখানে এলেন', 'How you got here');
  String get howYouGotHereHint => _t(
    'যেমন: তিন সপ্তাহ ধরে একবারও স্টপ সরাইনি।',
    'e.g. Three weeks without moving a stop once.',
  );
  String get rankPostGuideline => _t(
    'র‍্যাংক আর স্কোর এই মুহূর্তের — পরে বদলালেও পোস্টে যা আছে তাই থাকবে।',
    'The rank and score are this moment\'s. They stay as posted even after '
        'the board moves.',
  );
  String rankOnBoard(int rank) =>
      _t('লিডারবোর্ডে #$rank', '#$rank on the board');
  String get noRankYet => _t(
    'র‍্যাংক এখনো আসেনি — কয়েকটা ট্রেড বন্ধ করে আবার দেখুন।',
    'No rank yet — close a few trades and check back.',
  );
  String get writeComment => _t('কিছু লিখুন…', 'Write something…');
  String get send => _t('পাঠান', 'Send');
  String get noComments => _t('এখনো কোনো মন্তব্য নেই।', 'No comments yet.');
  String get commentGuideline => _t(
    'সিগন্যাল চাইবেন না, দেবেন না। কী শিখলেন সেটা নিয়ে লিখুন।',
    'No signals asked for or given. Write about what was learned.',
  );

  // --- Profile and connections --------------------------------------------

  String get profile => _t('প্রোফাইল', 'Profile');

  // --- Messaging ----------------------------------------------------------

  String get messages => _t('মেসেজ', 'Messages');
  String get message => _t('মেসেজ', 'Message');
  String get noChatsTitle => _t('এখনো কোনো মেসেজ নেই', 'No messages yet');
  String get noChatsHint => _t(
    'কেউ আপনার কানেকশন রিকোয়েস্ট অ্যাকসেপ্ট করলে — বা আপনি কারোটা করলে — তার সাথে চ্যাট এখানে চলে আসবে।',
    'When someone accepts your connection request — or you accept theirs — '
        'your chat with them appears here.',
  );
  String get messagingNeedsServer => _t(
    'মেসেজের জন্য সার্ভার লাগে — এই বিল্ডে Firebase সেট করা নেই।',
    'Messaging needs the server, and this build has no Firebase set up.',
  );
  String get typeMessage => _t('মেসেজ লিখুন…', 'Message…');
  String get youPrefix => _t('আপনি: ', 'You: ');
  String get youUnsent =>
      _t('আপনি একটি মেসেজ আনসেন্ড করেছেন', 'You unsent a message');
  String get theyUnsent =>
      _t('মেসেজটি আনসেন্ড করা হয়েছে', 'This message was unsent');
  String get unsend => _t('আনসেন্ড', 'Unsend');
  String get unsendTitle =>
      _t('মেসেজটি আনসেন্ড করবেন?', 'Unsend this message?');
  String get unsendBody => _t(
    'দুজনের কাছ থেকেই সরে যাবে। "আনসেন্ড করা হয়েছে" লেখা থাকবে।',
    'It will be removed for both of you, leaving a note that it was unsent.',
  );
  String get cancel => _t('বাতিল', 'Cancel');
  String get copy => _t('কপি', 'Copy');
  String get copied => _t('কপি হয়েছে', 'Copied');
  String get markUnread => _t('আনরিড করুন', 'Mark as unread');
  String get markRead => _t('রিড করুন', 'Mark as read');
  String get viewProfile => _t('প্রোফাইল দেখুন', 'View profile');
  String get sayHi =>
      _t('আপনারা কানেক্টেড। হাই বলুন 👋', "You're connected. Say hi 👋");
  String get notConnectedToMessage => _t(
    'কানেকশন নেই — মেসেজ পাঠাতে আবার কানেক্ট করুন।',
    "You're not connected — connect again to send messages.",
  );
  String get messageNotSent =>
      _t('মেসেজ যায়নি — আবার চেষ্টা করুন।', 'Message not sent — try again.');
  String get loadingOlder => _t('আগের মেসেজ…', 'Earlier messages…');

  // Replying and forwarding.
  String get reply => _t('রিপ্লাই', 'Reply');
  String get forward => _t('ফরোয়ার্ড', 'Forward');
  String get forwarded => _t('ফরোয়ার্ড করা', 'Forwarded');
  String get forwardTo => _t('কাকে পাঠাবেন?', 'Forward to…');
  String get forwardLimit =>
      _t('একবারে ৫টা চ্যাট পর্যন্ত', 'Up to 5 chats at a time');
  String get noChatsToForward =>
      _t('পাঠানোর মতো কোনো চ্যাট নেই', 'No conversations to forward to');
  String forwardedTo(int n) => _t(
    n == 1 ? 'ফরোয়ার্ড হয়েছে' : '$nটা চ্যাটে ফরোয়ার্ড হয়েছে',
    n == 1 ? 'Forwarded' : 'Forwarded to $n chats',
  );

  /// [where] is "@username", or the room's name.
  String forwardFailed(String where) => _t(
    '$where-এ পাঠানো যায়নি — হয়তো কানেকশন নেই।',
    "Couldn't forward to $where — you may not be connected.",
  );
  String get originalMissing =>
      _t('মূল মেসেজটি পাওয়া যাচ্ছে না', 'Original message not found');

  // The Global room.
  String get globalChat => _t('গ্লোবাল', 'Global');
  String get joinNow => _t('এখনই জয়েন করুন', 'Join now');
  String get join => _t('জয়েন', 'Join');
  String get leave => _t('লিভ', 'Leave');
  String members(int n) =>
      _t('$n জন সদস্য', n == 1 ? '1 member' : '$n members');
  String get globalAbout =>
      _t('সব ট্রেডারের জন্য একটা চ্যাট।', 'One chat for every trader here.');
  String get joinToWrite => _t(
    'মেসেজ পাঠাতে জয়েন করুন। জয়েন করলে নতুন মেসেজের নোটিফিকেশন আর আনরিড '
        'সংখ্যা পাবেন।',
    "Join to send messages. Members get notified of new messages and see "
        'what they have not read.',
  );
  String get globalEmpty => _t(
    'এখনো কেউ কিছু লেখেনি। প্রথম মেসেজটা আপনিই দিন 👋',
    'Nobody has written yet. Say the first hello 👋',
  );
  String get deleteRoomBody => _t(
    'মেসেজগুলো শুধু আপনার দিক থেকে মুছে যাবে — অন্যদের কাছে সব থেকে যাবে।',
    'The messages go from your side only — everyone else keeps them.',
  );
  String get joinedGlobal =>
      _t('গ্লোবাল চ্যাটে জয়েন করেছেন', 'You joined Global');
  String get leftGlobal =>
      _t('গ্লোবাল চ্যাট থেকে বের হয়েছেন', 'You left Global');
  String get couldNotJoin => _t(
    'হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন।',
    "Didn't work — check your connection and try again.",
  );
  String get leaveGlobalTitle =>
      _t('গ্লোবাল চ্যাট থেকে বের হবেন?', 'Leave Global?');
  String get leaveGlobalBody => _t(
    'আর নোটিফিকেশন বা আনরিড সংখ্যা আসবে না, আর মেসেজ পাঠাতে পারবেন না। '
        'পড়তে পারবেন, আর যেকোনো সময় আবার জয়েন করতে পারবেন। আপনার আগের '
        'মেসেজগুলো থেকে যাবে।',
    "You won't be notified or see unread counts, and you can't send "
        'messages. You can still read it and join again any time. What you '
        'have written stays.',
  );

  // Muting.
  String get mute => _t('মিউট', 'Mute');
  String get unmute => _t('আনমিউট', 'Unmute');
  String get muteNotifications => _t('নোটিফিকেশন মিউট', 'Mute notifications');
  String get muteExplain => _t(
    'মিউট থাকলে নতুন মেসেজের ব্যানার আসবে না, আর মেসেজ ট্যাবের সংখ্যায় এই '
        'চ্যাট গোনা হবে না। চ্যাটে ঢুকলে সব মেসেজ আগের মতোই দেখবেন। কেউ '
        'জানবে না যে আপনি মিউট করেছেন।',
    "While muted, new messages won't pop up a banner or count on the "
        "Messages tab. You'll still see everything in the chat, and nobody "
        'is told you muted it.',
  );
  String get mute8Hours => _t('৮ ঘণ্টা', '8 hours');
  String get mute1Week => _t('১ সপ্তাহ', '1 week');
  String get muteAlways => _t('সবসময়', 'Always');

  /// How long a mute lasts, as the chat and the inbox show it.
  String mutedUntil(DateTime until, DateTime now) {
    if (until.year >= 9999) return _t('সবসময়ের জন্য মিউট', 'Muted always');
    final l = until.toLocal();
    final sameDay =
        l.year == now.year && l.month == now.month && l.day == now.day;
    final when = sameDay ? clock(l) : '${shortDate(l)}, ${clock(l)}';
    return _t('$when পর্যন্ত মিউট', 'Muted until $when');
  }

  // Deleting for yourself.
  String get deleteForMe => _t('আমার দিক থেকে ডিলিট', 'Delete for me');
  String get messageDeleted => _t('মেসেজ ডিলিট হয়েছে', 'Message deleted');
  String get undo => _t('ফেরান', 'Undo');
  String get youDeletedMessage =>
      _t('আপনি মেসেজটি ডিলিট করেছেন', 'You deleted this message');
  String get deleteChat => _t('চ্যাট ডিলিট', 'Delete chat');
  String get deleteChatTitle => _t('চ্যাটটি ডিলিট করবেন?', 'Delete this chat?');
  String deleteChatBody(String name) => _t(
    'মেসেজগুলো শুধু আপনার দিক থেকে মুছে যাবে — $name-এর কাছে সব থেকে যাবে। '
        'নতুন মেসেজ এলে চ্যাটটা আবার দেখাবে।',
    'The messages go from your side only — $name keeps them all. The chat '
        'comes back when a new message arrives.',
  );
  String get chatDeleted => _t('চ্যাট ডিলিট হয়েছে', 'Chat deleted');
  String get couldNotDeleteChat => _t(
    'ডিলিট হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন।',
    'Not deleted — check your connection and try again.',
  );

  String get activeNow => _t('এখন অ্যাক্টিভ', 'Active now');
  String get typing => _t('লিখছে…', 'typing…');

  /// "Active 5m ago", from the time someone was last seen.
  String activeAgo(DateTime last, DateTime now) {
    final d = now.difference(last);
    if (d.inMinutes < 60) {
      final m = d.inMinutes.clamp(1, 59);
      return _t('$m মিনিট আগে অ্যাক্টিভ', 'Active ${m}m ago');
    }
    if (d.inHours < 24) {
      return _t('${d.inHours} ঘণ্টা আগে অ্যাক্টিভ', 'Active ${d.inHours}h ago');
    }
    if (d.inDays == 1) return _t('গতকাল অ্যাক্টিভ', 'Active yesterday');
    if (d.inDays < 7) {
      return _t('${d.inDays} দিন আগে অ্যাক্টিভ', 'Active ${d.inDays}d ago');
    }
    return _t('${shortDate(last)}-এ অ্যাক্টিভ', 'Active ${shortDate(last)}');
  }

  String get today => _t('আজ', 'Today');
  String get yesterday => _t('গতকাল', 'Yesterday');

  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _monthsBn = [
    'জানু',
    'ফেব্রু',
    'মার্চ',
    'এপ্রি',
    'মে',
    'জুন',
    'জুলা',
    'আগ',
    'সেপ্টে',
    'অক্টো',
    'নভে',
    'ডিসে',
  ];
  static const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _daysBn = [
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহস্পতি',
    'শুক্র',
    'শনি',
    'রবি',
  ];

  /// "25 Sep".
  String shortDate(DateTime t) {
    final l = t.toLocal();
    return '${l.day} ${isBangla ? _monthsBn[l.month - 1] : _monthsEn[l.month - 1]}';
  }

  /// "10:24 PM". Twelve-hour, which is how time is read here.
  String clock(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  /// The separator between days in a conversation.
  String dayLabel(DateTime day, DateTime now) {
    final d = DateTime(day.year, day.month, day.day);
    final today0 = DateTime(now.year, now.month, now.day);
    final diff = today0.difference(d).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    if (diff < 7) {
      return isBangla ? _daysBn[d.weekday - 1] : _daysEn[d.weekday - 1];
    }
    return shortDate(d);
  }

  /// The time on an inbox row: a clock today, then "Yesterday", a weekday,
  /// or a date — the way every messaging app does it.
  String threadTime(DateTime t, DateTime now) {
    final l = t.toLocal();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(l.year, l.month, l.day)).inDays;
    if (diff == 0) return clock(l);
    return dayLabel(l, now);
  }

  // --- Blocking -----------------------------------------------------------

  String get block => _t('ব্লক', 'Block');
  String get unblock => _t('আনব্লক', 'Unblock');
  String blockTitle(String username) =>
      _t('@$username-কে ব্লক করবেন?', 'Block @$username?');
  String get blockBody => _t(
    'সে আপনাকে মেসেজ বা কানেকশন রিকোয়েস্ট পাঠাতে পারবে না, আর আপনাদের '
        'কানেকশনও থাকবে না। তাকে জানানো হবে না।',
    "They won't be able to message you or send you a connection request, "
        "and you'll no longer be connected. They won't be told.",
  );
  String blocked(String username) =>
      _t('@$username ব্লক করা হয়েছে', 'Blocked @$username');
  String unblocked(String username) =>
      _t('@$username আনব্লক করা হয়েছে', 'Unblocked @$username');
  String get youBlockedThem =>
      _t('আপনি এই অ্যাকাউন্টটি ব্লক করেছেন।', 'You blocked this account.');
  String get blockedChatNote => _t(
    'আপনি ব্লক করেছেন — মেসেজ দিতে আনব্লক করুন।',
    'You blocked this person — unblock to send messages.',
  );
  String get blockedAccounts => _t('ব্লক করা অ্যাকাউন্ট', 'Blocked accounts');
  String get noBlocked =>
      _t('কাউকে ব্লক করা নেই।', "You haven't blocked anyone.");
  String blockedOn(DateTime t) =>
      _t('${shortDate(t)} তারিখে ব্লক', 'Blocked ${shortDate(t)}');

  // --- Reporting ----------------------------------------------------------

  String get report => _t('রিপোর্ট', 'Report');
  String reportUserTitle(String username) =>
      _t('@$username-কে রিপোর্ট', 'Report @$username');
  String get reportMessageTitle => _t('মেসেজ রিপোর্ট', 'Report message');
  String get reportPostTitle => _t('পোস্ট রিপোর্ট', 'Report post');
  String get reportCommentTitle => _t('কমেন্ট রিপোর্ট', 'Report comment');
  String get reportWhy => _t('সমস্যাটা কী?', "What's wrong?");
  String get reportPrivate => _t(
    'রিপোর্ট শুধু মডারেটররা দেখেন। যাকে রিপোর্ট করছেন তাকে জানানো হয় না।',
    'Only moderators see reports. The person you report is not told.',
  );
  String get reportNoteHint =>
      _t('আরও কিছু বলতে চাইলে লিখুন (ঐচ্ছিক)', 'Anything else? (optional)');
  String get sendReport => _t('রিপোর্ট পাঠান', 'Send report');
  String get reportThanks =>
      _t('ধন্যবাদ, রিপোর্ট পেয়েছি', 'Thanks — report received');
  String get reportThanksBody => _t(
    'আমরা দেখে ব্যবস্থা নেব। চাইলে তাকে ব্লকও করতে পারেন।',
    'We will look into it. You can also block this person.',
  );
  String get done => _t('ঠিক আছে', 'Done');

  String reportReason(String reason) => switch (reason) {
    'spam' => _t('স্প্যাম', 'Spam'),
    'harassment' => _t('হয়রানি বা বুলিং', 'Harassment or bullying'),
    'hate' => _t('ঘৃণা ছড়ানো', 'Hate speech'),
    'sexual' => _t('যৌন কনটেন্ট', 'Sexual content'),
    'violence' => _t('সহিংসতা বা হুমকি', 'Violence or threats'),
    'scam' => _t(
      'প্রতারণা বা টাকার সিগন্যাল বিক্রি',
      'Scam, or selling paid signals',
    ),
    'impersonation' => _t('অন্য কারো ছদ্মবেশ', 'Pretending to be someone else'),
    _ => _t('অন্য কিছু', 'Something else'),
  };

  // --- Settings -----------------------------------------------------------

  String get settings => _t('সেটিংস', 'Settings');
  String get sectionAccount => _t('অ্যাকাউন্ট', 'Account');
  String get sectionPrivacy => _t('প্রাইভেসি ও নিরাপত্তা', 'Privacy & safety');
  String get sectionAbout => _t('সম্পর্কে', 'About');
  String get language => _t('ভাষা', 'Language');
  String get logOutTitle => _t('লগআউট করবেন?', 'Log out?');
  String get logOutBody => _t(
    'আবার ঢুকতে ইউজারনেম আর পাসওয়ার্ড লাগবে — পাসওয়ার্ড রিসেটের কোনো উপায় নেই।',
    'You will need your username and password to get back in — there is no '
        'password reset.',
  );

  String get pushNotifications => _t('পুশ নোটিফিকেশন', 'Push notifications');
  String get pushNotificationsHint => _t(
    'মেসেজ, কানেকশন, পোস্ট, প্রতিদিনের পয়েন্ট',
    'Messages, connections, posts, daily points',
  );
  String get pushBlockedByPhone => _t(
    'ফোনের সেটিংসে এই অ্যাপের নোটিফিকেশন চালু করুন, তারপর আবার চেষ্টা করুন।',
    "Allow notifications for this app in your phone's Settings, then try "
        'again.',
  );

  // --- Editing your profile ------------------------------------------------

  String get avatar => _t('অ্যাভাটার', 'Avatar');
  String get changePassword => _t('পাসওয়ার্ড বদলান', 'Change password');
  String get currentPassword => _t('বর্তমান পাসওয়ার্ড', 'Current password');
  String get newPassword => _t('নতুন পাসওয়ার্ড', 'New password');
  String get confirmNewPassword =>
      _t('নতুন পাসওয়ার্ড আবার লিখুন', 'Confirm new password');
  String get passwordsDontMatch =>
      _t('দুটো পাসওয়ার্ড মিলছে না', 'The two passwords do not match');
  String get sameAsCurrent =>
      _t('এটা তো বর্তমান পাসওয়ার্ডই', 'That is your current password');
  String get wrongCurrentPassword =>
      _t('বর্তমান পাসওয়ার্ড ভুল', 'Current password is wrong');
  String get tooManyAttempts => _t(
    'অনেকবার ভুল হয়েছে — কিছুক্ষণ পরে আবার চেষ্টা করুন।',
    'Too many attempts — try again in a little while.',
  );
  String get passwordChanged =>
      _t('পাসওয়ার্ড বদলানো হয়েছে', 'Password changed');
  String get rememberPassword => _t(
    'নতুন পাসওয়ার্ড মনে রাখুন — এই অ্যাপে পাসওয়ার্ড রিসেটের কোনো উপায় নেই।',
    'Remember the new one — this app has no password reset.',
  );
  String get nameVisibleTo => _t(
    'লিডারবোর্ড, ফিড আর মেসেজে সবাই এই নামটাই দেখবে।',
    'This is the name people see on the leaderboard, in the feed and in '
        'messages.',
  );
  String get displayName => _t('নাম', 'Name');
  String get usernameFixed =>
      _t('ইউজারনেম বদলানো যায় না', 'Usernames cannot be changed');
  String get avatarAnimals => _t('প্রাণী', 'Animals');
  String get avatarCharacters => _t('ক্যারেক্টার', 'Characters');
  String get profileSaved => _t('প্রোফাইল সেভ হয়েছে', 'Profile saved');
  String get couldNotSave => _t(
    'সেভ হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন।',
    'Not saved — check your connection and try again.',
  );

  // Shown to someone the other person has blocked. Deliberately the same
  // words an account that is simply gone would get: nobody is told they were
  // blocked.
  String get accountUnavailable =>
      _t('এই অ্যাকাউন্টটা দেখা যাচ্ছে না', "This account isn't available");
  String get cantReplyHere => _t(
    'এই কথোপকথনে আর উত্তর দেওয়া যাবে না।',
    "You can't reply to this conversation.",
  );

  // --- Deleting your account ----------------------------------------------

  // Named as the privacy policy names it: "Settings → Delete account".
  String get deleteAccount => _t('অ্যাকাউন্ট ডিলিট', 'Delete account');
  String get deleteAccountHeading => _t(
    'এটা আপনার অ্যাকাউন্ট চিরতরে মুছে দেবে',
    'This deletes your account for good',
  );
  String get deleteWhatProfile => _t(
    'প্রোফাইল, ট্রেড, স্কোর আর র‍্যাঙ্ক',
    'Your profile, trades, scores and rank',
  );
  String get deleteWhatPosts =>
      _t('আপনার পোস্ট, কমেন্ট আর লাইক', 'Your posts, comments and likes');
  String get deleteWhatChats => _t(
    'কানেকশন আর মেসেজ — যার সাথে কথা হয়েছে, তার দিক থেকেও',
    'Your connections and conversations — for the other person too',
  );
  String get deleteWhatNotifications =>
      _t('নোটিফিকেশন আর প্রোফাইল ভিউ', 'Your notifications and profile views');
  String deleteUsernameRetired(String username) => _t(
    '@$username নামটা আর কেউ নিতে পারবে না — আপনিও এই নামে আবার অ্যাকাউন্ট '
        'খুলতে পারবেন না।',
    'Nobody can take @$username after you — you cannot sign up with it '
        'again either.',
  );
  String get deleteReportsKept => _t(
    'আপনার করা রিপোর্ট মডারেশনের জন্য থেকে যেতে পারে। বিস্তারিত প্রাইভেসি '
        'পলিসিতে।',
    'Reports you have made may be kept for moderation. The privacy policy '
        'has the details.',
  );
  String get deleteEnterPassword =>
      _t('নিশ্চিত করতে পাসওয়ার্ড দিন', 'Enter your password to confirm');
  String get wrongPassword => _t('পাসওয়ার্ড ভুল', 'Wrong password');
  String get deleteMyAccount =>
      _t('আমার অ্যাকাউন্ট ডিলিট করুন', 'Delete my account');
  String get deleteConfirmTitle =>
      _t('সত্যিই ডিলিট করবেন?', 'Delete for good?');
  String deleteConfirmBody(String username) => _t(
    '@$username আর এর সবকিছু মুছে যাবে। এটা আর ফেরানো যাবে না।',
    '@$username and everything in it will be deleted. There is no undo.',
  );
  String get deleting => _t('ডিলিট হচ্ছে…', 'Deleting…');
  String get accountDeleted =>
      _t('আপনার অ্যাকাউন্ট ডিলিট হয়েছে।', 'Your account has been deleted.');
  String get couldNotDelete => _t(
    'শেষ করা যায়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন।',
    'Could not finish — check your connection and try again.',
  );

  // --- Notifications ------------------------------------------------------

  String get notifications => _t('নোটিফিকেশন', 'Notifications');
  String get noNotifications => _t('নতুন কিছু নেই।', 'Nothing new.');
  String get markAllRead => _t('সব পড়া হয়েছে', 'Mark all read');
  String get notificationsExpire => _t(
    '৪৮ ঘণ্টা পর নিজে থেকে মুছে যায়।',
    'These clear themselves after 48 hours.',
  );
  String get journalStreakLabel => _t('জার্নাল স্ট্রিক', 'Journal streak');
  String get rank => _t('র‍্যাংক', 'Rank');
  String get yourPosition => _t('আপনার অবস্থান', 'Your position');
  String topN(int n) => _t('শীর্ষ $n', 'Top $n');
  String get unranked => _t('এখনো র‍্যাংক হয়নি', 'Not ranked yet');
  String get outsideTop => _t(
    'আপনি তালিকার বাইরে — উপরে উঠতে নিয়ম মেনে ট্রেড করুন।',
    'You are outside the list. Follow your rules to climb.',
  );
  String get cohort => _t('ব্যাচ', 'Batch');

  String get connections => _t('কানেকশন', 'Connections');
  String get connect => _t('কানেক্ট', 'Connect');
  String get requestSent => _t('রিকোয়েস্ট পাঠানো', 'Request sent');
  String get connected => _t('কানেক্টেড', 'Connected');
  String get accept => _t('অ্যাকসেপ্ট', 'Accept');
  String get decline => _t('বাতিল', 'Decline');
  String get withdraw => _t('ফিরিয়ে নিন', 'Withdraw');
  String get disconnect => _t('সরিয়ে দিন', 'Remove');
  String get wantsToConnect =>
      _t('আপনার সাথে কানেক্ট হতে চায়', 'wants to connect with you');

  String get pendingRequests => _t('অপেক্ষমাণ রিকোয়েস্ট', 'Pending requests');
  String get noPendingRequests =>
      _t('নতুন কোনো রিকোয়েস্ট নেই।', 'No new requests.');
  String get noConnectionsYet => _t(
    'এখনো কেউ কানেক্টেড না।\nলিডারবোর্ড থেকে কারো প্রোফাইলে গিয়ে রিকোয়েস্ট পাঠান।',
    'No connections yet.\nOpen someone from the leaderboard and send a request.',
  );

  String get couldNotLoad => _t('আনা গেল না।', 'Could not load.');
  String get retry => _t('আবার', 'Retry');
  String get showAll => _t('সব দেখুন', 'See all');

  String get profileViewers => _t('কে দেখেছে', 'Who viewed you');
  String get viewedYourProfile =>
      _t('আপনার প্রোফাইল দেখেছে', 'viewed your profile');
  String get noViewersYet => _t(
    'এখনো কেউ আপনার প্রোফাইল দেখেনি।',
    'Nobody has opened your profile yet.',
  );

  /// Only the owner sees their visitor list.
  String get viewersArePrivate =>
      _t('শুধু আপনি এই তালিকা দেখতে পান।', 'Only you can see this list.');

  // --- Grades -------------------------------------------------------------

  String get gradeExcellent => _t('চমৎকার', 'Excellent');
  String get gradeGood => _t('ভালো', 'Good');
  String get gradeOkay => _t('মোটামুটি', 'Okay');
  String get gradeWeak => _t('দুর্বল', 'Weak');
  String get gradeDangerous => _t('বিপজ্জনক', 'Dangerous');

  String gradeFor(double score) {
    if (score >= 90) return gradeExcellent;
    if (score >= 75) return gradeGood;
    if (score >= 60) return gradeOkay;
    if (score >= 40) return gradeWeak;
    return gradeDangerous;
  }

  // --- Time ---------------------------------------------------------------

  String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return _t('এইমাত্র', 'just now');
    if (diff.inMinutes < 60) {
      return _t('${diff.inMinutes} মিনিট আগে', '${diff.inMinutes}m ago');
    }
    if (diff.inHours < 24) {
      return _t('${diff.inHours} ঘণ্টা আগে', '${diff.inHours}h ago');
    }
    if (diff.inDays < 30) {
      return _t('${diff.inDays} দিন আগে', '${diff.inDays}d ago');
    }
    final months = (diff.inDays / 30).floor();
    return _t('$months মাস আগে', '${months}mo ago');
  }
}
