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
      code == 'en' ? AppLanguage.en : AppLanguage.bn;

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

  // --- Auth: shared -------------------------------------------------------

  String get appName => _t('ফরেক্স ট্রেডিং', 'Forex Trading');
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
  String get loginTitle => _t('ফিরে এসেছেন', 'Welcome back');
  String get loginSubtitle => _t(
        'ইউজারনেম আর পাসওয়ার্ড দিন।',
        'Enter your username and password.',
      );
  String get noAccount => _t('অ্যাকাউন্ট নেই?', 'No account?');
  String get createAccount => _t('নতুন অ্যাকাউন্ট', 'Create one');
  String get haveAccount => _t('অ্যাকাউন্ট আছে?', 'Already have one?');
  String get wrongLogin => _t(
        'ইউজারনেম বা পাসওয়ার্ড ভুল।',
        'Wrong username or password.',
      );

  /// Shown instead of a password-reset flow, because there isn't one.
  String get noPasswordReset => _t(
        'পাসওয়ার্ড ভুলে গেলে রিসেট করার উপায় নেই — এখানে কোনো ইমেইল বা ফোন '
        'নম্বর নেওয়া হয় না। নতুন একটা অ্যাকাউন্ট খুলে নিন, কিছু হারাবে না।',
        'There is no password reset — this app never asks for your email or '
        'phone. Just make a new account; you lose nothing but demo trades.',
      );

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
  String get usernameTaken => _t('এই নামটা নেওয়া হয়ে গেছে', 'That one is taken');
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

  String get creatingAccount => _t('অ্যাকাউন্ট তৈরি হচ্ছে…', 'Creating your account…');

  String welcomeUser(String name) =>
      _t('স্বাগতম, $name!', 'Welcome, $name!');

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
  String get rulesYouBreak => _t('যে নিয়মগুলো ভাঙছেন:', 'Rules you are breaking:');
  String timesCount(int n) => _t('$n বার', '$n×');

  String get trades => _t('ট্রেড', 'Trades');
  String get discipline => _t('ডিসিপ্লিন', 'Discipline');

  // --- Daily points and badges --------------------------------------------

  String get todaysPoints => _t('আজকের পয়েন্ট', "Today's points");
  String get todaysResult => _t('আজকের ফল', "Today's result");
  String get points => _t('পয়েন্ট', 'points');

  String resetsIn(String time) =>
      _t('$time পরে রিসেট', 'resets in $time');

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
  String get lossAndGainAsymmetry => _t(
        'লস আর লাভের অঙ্ক সমান না:',
        'Losses and gains are not symmetric:',
      );
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
  String tradeCount(int n) => _t('$n ট্রেড', '$n trades');
  String get followedRules => _t('নিয়ম মেনেছে', 'Followed the rules');
  String get brokeRules => _t('নিয়ম ভেঙেছে', 'Broke the rules');
  String get you => _t('আপনি', 'You');

  // --- Profile and connections --------------------------------------------

  String get profile => _t('প্রোফাইল', 'Profile');
  String get journalStreakLabel => _t('জার্নাল স্ট্রিক', 'Journal streak');
  String get rank => _t('র‍্যাংক', 'Rank');
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

  String get pendingRequests =>
      _t('অপেক্ষমাণ রিকোয়েস্ট', 'Pending requests');
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
  String get viewersArePrivate => _t(
        'শুধু আপনি এই তালিকা দেখতে পান।',
        'Only you can see this list.',
      );

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
