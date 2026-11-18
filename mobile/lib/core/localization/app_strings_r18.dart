part of 'app_strings.dart';

/// Round 18 strings (client revision note 2026-11-17). Part of
/// app_strings.dart, same rule: English and Bengali for every line. Screens
/// read them as `strings.r18`.
class Round18Strings {
  const Round18Strings(this.bn);

  final bool bn;

  String _(String en, String b) => bn ? b : en;

  /// Bengali digits for numbers shown in Bengali.
  String n(Object v) {
    final s = v.toString();
    if (!bn) return s;
    const digits = '০১২৩৪৫৬৭৮৯';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => digits[int.parse(m[0]!)]);
  }

  static const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _monthsBn = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];

  /// A clock time the way people say it: "8:30 AM" / "সকাল ৮:৩০"
  /// (client note point 12: Bengali had no AM / PM). Bengali names the part
  /// of the day, as the demo does: রাত (before 4), ভোর (4-6), সকাল (6-12),
  /// দুপুর (12-3), বিকাল (3-6), সন্ধ্যা (6-8), রাত (8 on).
  String time(int hour, int minute) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    if (!bn) return '$h12:$mm ${hour < 12 ? 'AM' : 'PM'}';
    final part = hour < 4
        ? 'রাত'
        : hour < 6
            ? 'ভোর'
            : hour < 12
                ? 'সকাল'
                : hour < 15
                    ? 'দুপুর'
                    : hour < 18
                        ? 'বিকাল'
                        : hour < 20
                            ? 'সন্ধ্যা'
                            : 'রাত';
    return '$part ${n('$h12:$mm')}';
  }

  /// "12 Nov 2026" / "১২ নভে ২০২৬".
  String dateOf(DateTime d) => bn ? '${n(d.day)} ${_monthsBn[d.month - 1]} ${n(d.year)}' : '${d.day} ${_monthsEn[d.month - 1]} ${d.year}';

  /// "12 Nov 2026, 8:30 AM".
  String dateTime(DateTime d) => '${dateOf(d)}, ${time(d.hour, d.minute)}';

  /// A reading's unit as stored by the app ("units", "hours"...) in the app language.
  String unit(String unit) {
    if (!bn) return unit;
    return switch (unit) {
      'units' => 'ইউনিট',
      'hours' => 'ঘণ্টা',
      'glasses' => 'গ্লাস',
      'kg' => 'কেজি',
      _ => unit,
    };
  }

  // --- Readings list (was "Other: 6.0 units" for insulin) ---
  String get allReadings => _('All readings', 'সব রিডিং');
  String get logReading => _('Log a reading', 'রিডিং লিখুন');
  String get notSynced => _('Not synced yet', 'এখনো সিঙ্ক হয়নি');

  // --- Log a reading: a date as well as a time (point 3) ---
  String get date => _('Date', 'তারিখ');
  String get today => _('Today', 'আজ');
  String get yesterday => _('Yesterday', 'গতকাল');
  String get readingInFuture => _('The date and time can’t be later than now.', 'তারিখ ও সময় এখনকার পরে হতে পারে না।');

  // --- Fingerprint lock (point 10) ---
  String get fingerprintLock => _('Unlock with fingerprint', 'ফিঙ্গারপ্রিন্ট দিয়ে খুলুন');
  String get fingerprintLockSub => _('Asks for your fingerprint or screen lock when you open the app', 'অ্যাপ খুললে ফিঙ্গারপ্রিন্ট বা ফোনের স্ক্রিন লক চাইবে');
  String get fingerprintUnavailable => _('This phone has no fingerprint set up (Android 9 or newer needed)', 'এই ফোনে ফিঙ্গারপ্রিন্ট সেট করা নেই (অ্যান্ড্রয়েড ৯ বা নতুন লাগবে)');
  String get unlockReason => _('Unlock Medi-Bela', 'মেডি-বেলা খুলুন');
  String get lockedTitle => _('Medi-Bela is locked', 'মেডি-বেলা লক করা');
  String get lockedSub => _('Use your fingerprint to open it', 'খুলতে ফিঙ্গারপ্রিন্ট দিন');
  String get unlock => _('Unlock', 'খুলুন');
  String get usePasswordInstead => _('Sign in with password instead', 'বরং পাসওয়ার্ড দিয়ে সাইন ইন করুন');
  String get fingerprintNotTurnedOn => _('Fingerprint was not confirmed, so the lock stays off.', 'ফিঙ্গারপ্রিন্ট নিশ্চিত হয়নি, তাই লক বন্ধ থাকল।');

  // --- Caregiver permissions (point 14) ---
  String get yourCaregiver => _('Your caregiver', 'আপনার পরিচর্যাকারী');
  String permTitle(String name) => _('What can $name do?', '$name কী করতে পারবেন?');
  String permIntro(String name) => _(
      'You decide. You can change this any time in Settings → Privacy & family.',
      'আপনিই ঠিক করবেন। সেটিংস → গোপনীয়তা ও পরিবার থেকে যেকোনো সময় বদলাতে পারবেন।');
  String get permView => _('See my medicines and records', 'আমার ওষুধ ও রেকর্ড দেখতে পারবেন');
  String get permViewSub => _('Medicines, doses, readings, tests and prescriptions', 'ওষুধ, ডোজ, রিডিং, টেস্ট ও প্রেসক্রিপশন');
  String get permManage => _('Change them for me', 'আমার হয়ে বদলাতে পারবেন');
  String get permManageSub => _('Add or change medicines and reminders, mark a dose given, change my reminder settings', 'ওষুধ ও রিমাইন্ডার যোগ বা বদল, ডোজ খাইয়ে দেওয়া, রিমাইন্ডারের সেটিংস বদল');
  String permAlwaysAlerts(String name) => _('$name is always told if you miss a dose.', 'ডোজ মিস হলে $name সবসময় জানতে পারবেন।');
  String get permSave => _('Save', 'সেভ করুন');
  String get permSettingsTitle => _('What my caregiver can do', 'পরিচর্যাকারী কী করতে পারবেন');
  String permSettingsNow(bool view, bool manage) => manage
      ? _('See and change', 'দেখতে ও বদলাতে পারবেন')
      : view
          ? _('See only', 'শুধু দেখতে পারবেন')
          : _('Alerts only', 'শুধু সতর্কবার্তা');
  String memberTimings(String name) => _('Reminder timings: $name', 'রিমাইন্ডারের সময়: $name');
  String get memberTimingsButton => _('Reminder timings', 'রিমাইন্ডারের সময়');
  String get noPermission => _('This family member hasn’t allowed this. They can change it in their Settings.', 'পরিবারের এই সদস্য এটির অনুমতি দেননি। তিনি তাঁর সেটিংস থেকে বদলাতে পারবেন।');
  String memberNoView(String name) => _('$name hasn’t allowed you to see their medicines. You are still told if they miss a dose.', '$name তাঁর ওষুধ দেখার অনুমতি দেননি। ডোজ মিস হলে আপনি তবুও জানবেন।');
  String memberViewOnly(String name) => _('View only: $name hasn’t allowed changes.', 'শুধু দেখা: $name বদলানোর অনুমতি দেননি।');


  // --- Add medicine 2.0 (point 1) ---
  String get form => _('Form', 'ধরন');
  String get more => _('More', 'আরও');
  String get whenToTake => _('When to take it', 'কখন খাবেন');
  String get everyDay => _('Every day', 'প্রতিদিন');
  String get certainDays => _('Certain days', 'নির্দিষ্ট দিনে');
  String get everyFewDays => _('Every few days', 'কয়েক দিন পরপর');
  String get onlyWhenNeeded => _('Only when needed', 'শুধু দরকার হলে');
  List<String> get weekdayShort => bn ? const ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি'] : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String get pickDays => _('Pick at least one day', 'অন্তত একটি দিন বাছুন');
  String onceEvery(int d) => _('Once every $d days', '${n(d)} দিনে একবার');
  String get howManyTimes => _('How many times a day?', 'দিনে কতবার?');
  String get orAsWritten => _('Or as written on the prescription (morning + noon + night):', 'বা প্রেসক্রিপশনে যেমন লেখা (সকাল + দুপুর + রাত):');
  String get doseTimesTitle => _('Dose times', 'ডোজের সময়');
  String get amountEachTime => _('How much each time', 'প্রতিবার কতটুকু');
  String get mostPerDay => _('Most times a day', 'দিনে সর্বোচ্চ কতবার');
  String get minGap => _('Hours between', 'মাঝে কত ঘণ্টা');
  String get asDoctorSaid => _('As your doctor said (optional)', 'ডাক্তার যেমন বলেছেন (ঐচ্ছিক)');
  String get notSet => _('Not set', 'ঠিক করা নেই');
  String hoursN(int h) => _('$h h', '${n(h)} ঘণ্টা');
  String get withFood => _('With food', 'খাবারের সাথে');
  String get forHowLong => _('For how long?', 'কতদিন?');
  String daysN(int d) => _('$d days', '${n(d)} দিন');
  String get oneMonth => _('1 month', '১ মাস');
  String get ongoing => _('Ongoing', 'চলবে');
  String get other => _('Other', 'অন্যান্য');
  String get typeDays => _('Type the number of days', 'দিনের সংখ্যা লিখুন');
  String get starts => _('Starts', 'শুরু');
  String endsOn(String d) => _('Ends $d', 'শেষ $d');
  String get untilDoctorStops => _('Until your doctor says to stop', 'ডাক্তার বন্ধ করতে না বলা পর্যন্ত');
  String get howMuchHave => _('How much do you have?', 'কতটুকু আছে?');
  String get howMuchHaveSub => _('We remind you before it runs out', 'শেষ হওয়ার আগে মনে করিয়ে দেব');
  String get remindWhenLeft => _('Remind me when left:', 'বাকি থাকলে মনে করাবো:');
  String lastsDays(int d) => _('lasts $d days', '${n(d)} দিন চলবে');
  String get moreDetails => _('More details', 'আরও তথ্য');
  String get moreDetailsSubPill => _('Tablet colour and shape, what it is for, pack photo, note', 'ট্যাবলেটের রং ও আকার, কিসের জন্য, প্যাকেটের ছবি, নোট');
  String get moreDetailsSub => _('What it is for, pack photo, note', 'কিসের জন্য, প্যাকেটের ছবি, নোট');
  String get optional => _(' (optional)', ' (ঐচ্ছিক)');
  String get realLook => _('Real tablet colour and shape', 'ট্যাবলেটের আসল রং ও আকার');
  String get realLookSub => _('Pick only what matches the tablet in the strip. Reminders show this picture.', 'স্ট্রিপের ট্যাবলেটের সাথে মিললে তবেই বাছুন। রিমাইন্ডারে এই ছবি দেখাবে।');
  String get colour => _('Colour', 'রং');
  String get shape => _('Shape', 'আকার');
  String get none => _('None', 'কোনোটি না');
  String get neverByColour => _('Never identify a medicine by colour alone. Always read the name on the strip.', 'শুধু রং দেখে ওষুধ চিনবেন না। সবসময় স্ট্রিপে নাম পড়ে নিন।');
  String get packPhoto => _('Photo of the pack', 'প্যাকেটের ছবি');
  String get packPhotoSub => _('Shown on the reminder so it is easy to recognise', 'রিমাইন্ডারে দেখাবে, যাতে সহজে চেনা যায়');
  String get packPhotoAdded => _('Pack photo added', 'প্যাকেটের ছবি যোগ হয়েছে');
  String get note => _('Note', 'নোট');
  String get noteHint => _('e.g. Swallow with water', 'যেমন: পানি দিয়ে গিলে খাবেন');
  String get nameRequiredOnly => _('Only the name is required. Everything else can be changed later.', 'শুধু নাম দরকার। বাকি সব পরে বদলানো যাবে।');
  String summaryTimes(int times, String amount, int? days) {
    final each = amount.isEmpty ? '' : _(', $amount each', ', প্রতিবার $amount');
    return days == null
        ? _('$times× a day$each, ongoing', 'দিনে ${n(times)} বার$each, চলবে')
        : _('$times× a day$each, $days days', 'দিনে ${n(times)} বার$each, ${n(days)} দিন');
  }
  String summaryAsNeeded(String amount, int? most) {
    final each = amount.isEmpty ? '' : _(', $amount each time', ', প্রতিবার $amount');
    final cap = most == null ? '' : _(', up to $most× a day', ', দিনে সর্বোচ্চ ${n(most)} বার');
    return _('As needed$each$cap', 'দরকার হলে$each$cap');
  }
  String get saveChanges => _('Save changes', 'পরিবর্তন সেভ করুন');
  String get pickTimesDifferent => _('Each dose needs a different time', 'প্রতিটি ডোজের সময় আলাদা হতে হবে');
  String get morning => _('Morning', 'সকাল');
  String get afternoon => _('Afternoon', 'দুপুর');
  String get night => _('Night', 'রাত');
  String get doseAmountHintTablet => _('e.g. 1 tablet', 'যেমন: ১টি ট্যাবলেট');
  String get doseAmountHintSyrup => _('e.g. 2 tsp or 10 ml', 'যেমন: ২ চামচ বা ১০ মি.লি.');
  String get doseAmountHintUnits => _('e.g. 10 units', 'যেমন: ১০ ইউনিট');
  String unitName(String unit) => switch (unit) {
        'tablet' => _('tablets', 'টি ট্যাবলেট'),
        'capsule' => _('capsules', 'টি ক্যাপসুল'),
        'ml' => _('ml', 'মি.লি.'),
        'spoon' => _('spoons', 'চামচ'),
        'drop' => _('drops', 'ফোঁটা'),
        'puff' => _('puffs', 'পাফ'),
        'unit' => _('units', 'ইউনিট'),
        'dose' => _('doses', 'ডোজ'),
        'piece' => _('pieces', 'টি'),
        'strip' => _('strips', 'স্ট্রিপ'),
        'pen' => _('pens', 'পেন'),
        'vial' => _('vials', 'ভায়াল'),
        'sachet' => _('sachets', 'স্যাশে'),
        _ => unit,
      };
  List<(String, String)> get pillColours => [
        ('w', _('White', 'সাদা')),
        ('y', _('Yellow', 'হলুদ')),
        ('o', _('Orange', 'কমলা')),
        ('r', _('Red', 'লাল')),
        ('p', _('Pink', 'গোলাপি')),
        ('b', _('Blue', 'নীল')),
        ('g', _('Green', 'সবুজ')),
        ('n', _('Brown', 'বাদামি')),
        ('k', _('Black', 'কালো')),
        ('c', _('Two colours', 'দুই রং')),
      ];
  List<(String, String)> get pillShapes => [
        ('round', _('Round', 'গোল')),
        ('oval', _('Oval', 'ডিম্বাকার')),
        ('capsule', _('Capsule', 'ক্যাপসুল')),
        ('oblong', _('Long', 'লম্বা')),
        ('half', _('Half', 'অর্ধেক')),
        ('square', _('Square', 'চারকোনা')),
      ];

  // --- My medicine tab and the medicine page (points 6, 7) ---
  String get myMedicineTab => _('My medicine', 'আমার ওষুধ');
  String get prevDay => _('Previous day', 'আগের দিন');
  String get nextDay => _('Next day', 'পরের দিন');
  String get noDosesThisDay => _('No medicine on this day', 'এই দিনে কোনো ওষুধ নেই');
  String dosesOfDay(int done, int total) => _('$done of $total doses', '${n(total)}টির মধ্যে ${n(done)}টি ডোজ');
  String get whenNeededTitle => _('When needed', 'দরকার হলে');
  String get tookOneNow => _('Took one now', 'এখন একটি নিলাম');
  String get notTakenToday => _('Not taken today', 'আজ নেওয়া হয়নি');
  String takenAtTimes(String times) => _('Taken today at $times', 'আজ নেওয়া হয়েছে: $times');
  String get overMaxWarn => _('That is more than the most your doctor allowed today. Talk to your doctor before taking more.', 'এটি আজ ডাক্তারের দেওয়া সর্বোচ্চ সীমার বেশি। আর নেওয়ার আগে ডাক্তারের সাথে কথা বলুন।');
  String get tooSoonWarn => _('That was soon after the last one. Check the gap your doctor gave.', 'আগেরটির খুব তাড়াতাড়ি পরে নেওয়া হলো। ডাক্তারের দেওয়া বিরতি দেখে নিন।');
  String get logged => _('Saved', 'সেভ হয়েছে');
  String get myMedicines => _('My medicines', 'আমার ওষুধগুলো');
  String takenDaysOf(int x, int y) => _('Taken $x of $y days', '${n(y)} দিনের ${n(x)} দিন খাওয়া হয়েছে');
  String get asNeededTag => _('As needed', 'দরকার হলে');
  String get ongoingTag => _('Ongoing', 'চলবে');
  String daysLeftTag(int d) => _('$d days left', '${n(d)} দিন বাকি');
  String get howOften => _('How often', 'কতবার');
  String get whenRow => _('When', 'কখন');
  String get foodRow => _('Food', 'খাবার');
  String get howLongRow => _('How long', 'কতদিন');
  String get forRow => _('For', 'কিসের জন্য');
  String get noteRow => _('Note', 'নোট');
  String get lookRow => _('Looks like', 'দেখতে');
  String everyDayTimes(int t) => _('$t× a day', 'দিনে ${n(t)} বার');
  String onDays(String days) => _('On $days', '$days');
  String everyNDays(int d) => _('Every $d days', '${n(d)} দিন পরপর');
  String upToPerDay(int m) => _('up to $m× a day', 'দিনে সর্বোচ্চ ${n(m)} বার');
  String inStock(String amount) => _('$amount in stock', '$amount আছে');
  String get notCounted => _('Not counted yet', 'এখনো গোনা হয়নি');
  String get countIt => _('Count it', 'গুনে লিখুন');
  String get todayTitle => _('Today', 'আজ');
  String get removeAtBottomNote => _('Talk to your doctor before changing or stopping a medicine.', 'ওষুধ বদলানো বা বন্ধ করার আগে ডাক্তারের সাথে কথা বলুন।');
  String get medicineNotFound => _('This medicine was not found. It may have been removed.', 'ওষুধটি পাওয়া যায়নি। হয়তো সরানো হয়েছে।');

  // --- Medicine box 2.0 (points 5, 6) ---
  String get boxMedicines => _('Medicines', 'ওষুধ');
  String get careSupplies => _('Care supplies and other items', 'যত্নের জিনিস ও অন্যান্য');
  String get careSuppliesSub => _('Insulin, test strips, needles, or a medicine with no reminder', 'ইনসুলিন, টেস্ট স্ট্রিপ, সুই, বা রিমাইন্ডার ছাড়া কোনো ওষুধ');
  String get addItem => _('Add an item', 'জিনিস যোগ করুন');
  String get kindMedicine => _('Medicine', 'ওষুধ');
  String get kindSupply => _('Care supply', 'যত্নের জিনিস');
  String get suggested => _('Suggested', 'সাজেশন');
  List<(String, String)> get supplySuggestions => [
        (_('Insulin pen', 'ইনসুলিন পেন'), 'pen'),
        (_('Test strips', 'টেস্ট স্ট্রিপ'), 'piece'),
        (_('Pen needles', 'পেনের সুই'), 'piece'),
        (_('Lancets', 'ল্যানসেট'), 'piece'),
        (_('Alcohol swabs', 'অ্যালকোহল প্যাড'), 'piece'),
        (_('Glucometer batteries', 'গ্লুকোমিটারের ব্যাটারি'), 'piece'),
      ];
  String get itemName => _('Name', 'নাম');
  String get itemNameHint => _('e.g. Test strips', 'যেমন: টেস্ট স্ট্রিপ');
  String get howManyNow => _('How many you have now', 'এখন কতগুলো আছে');
  String get usedPerDay => _('Used a day (optional)', 'দিনে কতগুলো লাগে (ঐচ্ছিক)');
  String get usedPerDayHelp => _('Lets us work out how long it lasts', 'কতদিন চলবে তা হিসাব করতে কাজে লাগে');
  String get bought => _('Bought', 'কিনেছি');
  String get newCount => _('How many do you have now?', 'এখন কতগুলো আছে?');
  String get removeItem => _('Remove from the box', 'বাক্স থেকে সরান');
  String leftAmount(String amount) => _('$amount left', '$amount বাকি');
  String get noReminder => _('No reminder', 'রিমাইন্ডার নেই');
  // --- Prescription photos (point 2) ---
  String get uploadFailedTitle => _('Upload failed', 'আপলোড হয়নি');
  String get uploadFailedBody => _('A prescription photo could not be sent. Tap to try again.', 'প্রেসক্রিপশনের ছবি পাঠানো যায়নি। আবার চেষ্টা করতে চাপুন।');
  String get uploading => _('Uploading…', 'আপলোড হচ্ছে…');
  String get waitingForInternet => _('Waiting for internet', 'ইন্টারনেটের অপেক্ষায়');
  String get uploadFailedTap => _('Upload failed. Tap to retry', 'আপলোড হয়নি। আবার চেষ্টা করতে চাপুন');
  String get takePhoto => _('Take a photo', 'ছবি তুলুন');
  String get fromGallery => _('From gallery', 'গ্যালারি থেকে');
  String get retake => _('Retake', 'আবার তুলুন');
  String get addPage => _('Add a page', 'আরেক পাতা যোগ করুন');
  String pagesN(int n, int max) => _('$n of $max pages', '${this.n(max)} পাতার ${this.n(n)}টি');
  String get twoAtATime => _('Up to 2 photos at a time from the gallery', 'গ্যালারি থেকে একবারে সর্বোচ্চ ২টি ছবি');
  String get sendToPharmacist => _('Send to pharmacist', 'ফার্মাসিস্টের কাছে পাঠান');
  String get sentInBackground => _('Saved. It uploads in the background; you can leave this screen.', 'সেভ হয়েছে। পেছনে আপলোড হবে; আপনি এই পাতা ছেড়ে যেতে পারেন।');


  // --- Notifications (points 9, 13, 15) ---
  String get yourChoices => _('Your choices', 'আপনার পছন্দ');
  String get reminderPhoto => _('A photo on your reminders', 'রিমাইন্ডারে একটি ছবি');
  String get reminderPhotoSub => _('A small round photo, for example of your family', 'ছোট গোল ছবি, যেমন পরিবারের কারো');
  String get choosePhoto => _('Choose a photo', 'ছবি বাছুন');
  String get removePhoto => _('Remove', 'সরান');
  String get vibrate => _('Vibrate with the alarm', 'অ্যালার্মের সাথে কাঁপবে');
  String get showNamesLock => _('Show medicine names on the lock screen', 'লক স্ক্রিনে ওষুধের নাম দেখাবে');
  String get showNamesLockSub => _('Off: only "1 medicine at 8:00 PM", so others can’t read it', 'বন্ধ থাকলে শুধু "রাত ৮টায় ১টি ওষুধ" দেখাবে, যাতে অন্যরা না পড়তে পারে');
  String get urgentTitle => _('Urgent reading', 'জরুরি রিডিং');
  String get urgentBody => _('Very high BP or very low sugar: a red full page with 999 and the family alert.', 'খুব বেশি প্রেসার বা খুব কম সুগার: লাল পুরো পাতা, ৯৯৯ ও পরিবারকে জানানোর বোতাম।');
  String get changesTitle => _('Changes made for you', 'আপনার জন্য পরিবর্তন');
  String get changesBody => _('Your caregiver changed a medicine or setting: a normal notification and the Family inbox.', 'পরিচর্যাকারী কোনো ওষুধ বা সেটিং বদলালে: সাধারণ নোটিফিকেশন ও পরিবার ইনবক্স।');
  String get alarmIconNote => _('Medicine reminders use the phone’s alarm clock, so an alarm icon shows in the status bar while one is coming up. This keeps them on time even in battery saver.', 'ওষুধের রিমাইন্ডার ফোনের অ্যালার্ম ঘড়ি ব্যবহার করে, তাই রিমাইন্ডার আসার আগে স্ট্যাটাস বারে অ্যালার্মের চিহ্ন দেখাবে। এতে ব্যাটারি সেভারেও সময়মতো বাজবে।');
  // --- Research consent (point 17) ---
  String get researchConsent => _(
      'I agree that my health data, without my name or phone number, may be used to improve Medi-Bela.',
      'আমি রাজি যে আমার নাম বা ফোন নম্বর ছাড়া আমার স্বাস্থ্য-তথ্য মেডি-বেলা উন্নত করতে ব্যবহার করা যাবে।');

  /// "Today" / "Yesterday" / "12 Nov 2026".
  String dayLabel(DateTime day, DateTime now) {
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(now.year, now.month, now.day);
    final diff = t.difference(d).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    return dateOf(d);
  }
}

extension Round18StringsOf on AppStrings {
  Round18Strings get r18 => identical(this, bnStrings) ? const Round18Strings(true) : const Round18Strings(false);
}
