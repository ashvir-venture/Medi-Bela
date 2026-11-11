part of 'app_strings.dart';

/// Round 15-16 strings (my care, readings, limits, crisis sheets, condition
/// pages, insulin log, doctor visits, tests and results, record-only
/// prescriptions, the doctor's PDF). Part of app_strings.dart, same rule:
/// English and Bengali for every line (mostly the owner's demo wording).
/// Screens read them as `strings.r15`. Fixed medical texts per condition are
/// in features/care/domain/care_content.dart.
class Round15Strings {
  const Round15Strings(this.bn);

  final bool bn;

  String _(String en, String b) => bn ? b : en;

  /// Bengali digits for numbers shown in Bengali.
  String n(Object v) {
    final s = v.toString();
    if (!bn) return s;
    const digits = '০১২৩৪৫৬৭৮৯';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => digits[int.parse(m[0]!)]);
  }

  // --- My care ---
  String get myCare => _('My care', 'আমার যত্ন');
  String get lastStep => _('Last step', 'শেষ ধাপ');
  String get later => _('Later', 'পরে করব');
  String get whatCare => _('What care do you need?', 'কোন যত্ন দরকার?');
  String get whatCareSub => _('Each one you pick gets its own card on Home. You can change this any time.', 'যা বাছবেন, হোমে তার আলাদা কার্ড আসবে। পরে যেকোনো সময় বদলানো যাবে।');
  String get noneForNow => _('None for now', 'এখন কোনোটি নয়');
  String get homeWillShow => _('Your Home will show', 'আপনার হোমে আসবে');
  String get homeWillShowNone => _('Today’s medicine, services and an “add a care plan” card', 'আজকের ওষুধ, সেবা আর একটি “যত্ন যোগ করুন” কার্ড');
  String get carePrivate => _('This stays private. Your caregiver sees it unless you hide from family.', 'এই তথ্য শুধু আপনার। “পরিবার থেকে লুকান” চালু না থাকলে আপনার পরিচর্যাকারী দেখতে পাবেন।');
  String get getStarted => _('Get started', 'শুরু করুন');
  String get save => _('Save', 'সেভ করুন');
  String get saved => _('Saved', 'সেভ হয়েছে');
  String get customize => _('Customize', 'সাজান');
  String get editConditions => _('Edit conditions', 'রোগ বদলান');
  String get addCarePlan => _('Add a care plan', 'যত্ন যোগ করুন');
  String get addAnotherCarePlan => _('Add another care plan', 'আরেকটি যত্ন যোগ করুন');
  String get haveCondition => _('Have a long-term condition?', 'দীর্ঘমেয়াদি রোগ আছে?');
  String get haveConditionSub => _('Add diabetes, blood pressure or another condition and it gets its own card here.', 'ডায়াবেটিস, প্রেসার বা অন্য রোগ যোগ করুন, হোমে তার আলাদা কার্ড আসবে।');
  String get open => _('Open', 'খুলুন');
  String get details => _('Details', 'বিস্তারিত');
  String get add => _('Add', 'যোগ');
  String get edit => _('Edit', 'সাজান');
  String get done => _('Done', 'হয়েছে');
  String get remove => _('Remove', 'সরান');
  String get delete => _('Delete', 'মুছুন');
  String get optional => _(' (optional)', ' (ঐচ্ছিক)');
  String get noneYet => _('None yet', 'এখনো নেই');
  String get today => _('Today', 'আজ');
  String get yesterday => _('Yesterday', 'গতকাল');
  String get tomorrow => _('Tomorrow', 'আগামীকাল');
  String inDays(int d) => d == 0 ? today : d == 1 ? tomorrow : d == -1 ? yesterday : d > 0 ? _('in ${n(d)} days', '${n(d)} দিন পর') : _('${n(-d)} days ago', '${n(-d)} দিন আগে');
  String get last7Days => _('Last 7 days', 'গত ৭ দিন');
  String get needsInternet => _('This needs the internet. Try again when you are online.', 'এর জন্য ইন্টারনেট লাগবে। অনলাইনে থাকলে আবার চেষ্টা করুন।');
  String get byCaregiver => _('by caregiver', 'পরিচর্যাকারী');

  // --- Health tab ---
  String get healthSub => _('Readings, reports and reminders in one place', 'মাপ, রিপোর্ট আর রিমাইন্ডার এক জায়গায়');
  String get measureAndLog => _('Measure and log', 'মাপুন ও লিখুন');
  String get targetsLimits => _('Targets and limits', 'লক্ষ্য ও সীমা');
  String get limitsNotSet => _('Your doctor’s numbers are not set yet', 'ডাক্তারের দেওয়া সংখ্যা এখনো সেট করা হয়নি');
  String get set => _('Set', 'সেট করুন');
  String get recordsSub => _('Reports, tests, PDF for your doctor', 'রিপোর্ট, টেস্ট, ডাক্তারের জন্য PDF');
  String get insulinSub => _('Doses and injection sites', 'ডোজ ও ইনজেকশনের জায়গা');
  String get addIfUsed => _('Add if used', 'লাগলে যোগ');
  String get heightOptional => _('Height in cm (optional, for BMI)', 'উচ্চতা, সে.মি. (ঐচ্ছিক, BMI-র জন্য)');
  String get heightRange => _('Between 50 and 250 cm', '৫০ থেকে ২৫০ সে.মি. এর মধ্যে');
  String get allReadings => _('All readings', 'সব রিডিং');

  // --- Readings ---
  String get logReading => _('Log a reading', 'রিডিং লিখুন');
  String get whatMeasured => _('What you measured', 'কী মাপলেন');
  String get tSugar => _('Sugar', 'সুগার');
  String get tBp => _('Blood pressure', 'প্রেসার');
  String get tWeight => _('Weight', 'ওজন');
  String get tTemp => _('Temperature', 'তাপমাত্রা');
  String get tInsulin => _('Insulin', 'ইনসুলিন');
  String get tSleep => _('Sleep', 'ঘুম');
  String get tWater => _('Water', 'পানি');
  String get tPeakFlow => _('Peak flow', 'পিক ফ্লো');
  String get whenChecked => _('When did you check?', 'কখন মাপলেন?');
  String sugarField(String unit) => _('Sugar ($unit)', 'সুগার ($unit)');
  String get upper => _('Upper (systolic)', 'উপরের (সিস্টোলিক)');
  String get lower => _('Lower (diastolic)', 'নিচের (ডায়াস্টোলিক)');
  String get upperShort => _('Upper', 'উপরের');
  String get lowerShort => _('Lower', 'নিচের');
  String get pulseOptional => _('Pulse per minute (optional)', 'নাড়ি (প্রতি মিনিটে, ঐচ্ছিক)');
  String get measureAgain => _('Measure again after 1 minute', '১ মিনিট পর ২য় বার মাপুন');
  String get averageNote => _('If you give both, we save the average, as doctors prefer.', 'দুটো দিলে গড় লেখা হবে, যেমন ডাক্তাররা চান।');
  String get whichArm => _('Which arm', 'কোন হাতে মাপলেন');
  String get leftArm => _('Left', 'বাম');
  String get rightArm => _('Right', 'ডান');
  String get howToMeasure => _('How to measure correctly', 'সঠিকভাবে মাপার নিয়ম');
  String get doctorsRange => _('Doctor’s range: ', 'ডাক্তারের সীমা: ');
  String get noLimitYet => _('No limit from your doctor saved yet.', 'ডাক্তারের দেওয়া সীমা এখনো লেখা হয়নি।');
  String get change => _('Change', 'বদলান');
  String get weightKg => _('Weight (kg)', 'ওজন (কেজি)');
  String bmiLine(String bmi, int h) => _('BMI $bmi (height $h cm)', 'BMI ${n(bmi)} (উচ্চতা ${n(h)} সে.মি. ধরে)');
  String get heightAsk => _('Your height in cm (asked once, for BMI)', 'আপনার উচ্চতা, সে.মি. (একবারই, BMI-র জন্য)');
  String get bmiNoHeight => _('Add your height once and BMI is worked out.', 'উচ্চতা একবার দিলে BMI নিজে থেকে বের হবে।');
  String targetWeight(String kg) => _('Target weight: $kg kg. ', 'লক্ষ্য ওজন: ${n(kg)} কেজি। ');
  String get tempF => _('Temperature (°F)', 'তাপমাত্রা (°F)');
  String feverLimit(String f) => _('Doctor’s fever limit: we alert you above $f°F. ', 'ডাক্তারের দেওয়া জ্বরের সীমা: ${n(f)}°F এর বেশি হলে সতর্ক করবো। ');
  String get howManyUnits => _('How many units?', 'কত ইউনিট?');
  String get whereInjected => _('Where did you inject?', 'কোথায় দিলেন?');
  String get onlyPrescribedUnits => _('Only the units your doctor prescribed.', 'ডাক্তার যত ইউনিট লিখেছেন, ঠিক ততটুকুই।');
  String get sleepHoursQ => _('How many hours did you sleep last night?', 'কাল রাতে কত ঘণ্টা ঘুমিয়েছেন?');
  String hoursValue(Object h) => _('$h hrs', '${n(h)} ঘণ্টা');
  String goalHours(Object h) => _('Goal: $h hrs', 'লক্ষ্য: ${n(h)} ঘণ্টা');
  String get waterQ => _('Glasses of water today', 'আজ কত গ্লাস পানি খেয়েছেন?');
  String glasses(Object g) => _('$g glasses', '${n(g)} গ্লাস');
  String goalGlasses(Object g) => _('Goal: $g glasses', 'লক্ষ্য: ${n(g)} গ্লাস');
  String get peakFlowField => _('Peak flow (L/min)', 'পিক ফ্লো (লিটার/মিনিট)');
  String get time => _('Time', 'কখন');
  String get enterNumber => _('Enter a number', 'একটি সংখ্যা লিখুন');
  String get enterBoth => _('Enter both numbers correctly', 'দুটো সংখ্যাই ঠিকমতো লিখুন');
  String get numberOutOfRange => _('That number is not possible. Check and type it again.', 'এই সংখ্যা সম্ভব নয়। দেখে আবার লিখুন।');
  String get savedInRange => _('Saved, within your doctor’s range', 'সেভ হয়েছে, ডাক্তারের সীমার মধ্যে');
  String get savedAbove => _('Saved, above your doctor’s limit. Follow your doctor’s advice.', 'সেভ হয়েছে, ডাক্তারের দেওয়া সীমার উপরে। ডাক্তারের পরামর্শ মানুন।');
  String get savedBelowBp => _('Saved. BP is below your doctor’s limit. Follow your doctor’s advice.', 'সেভ হয়েছে। প্রেসার ডাক্তারের দেওয়া সীমার নিচে। ডাক্তারের পরামর্শ মানুন।');
  String get savedBelowSugar => _('Sugar is below your doctor’s limit. Do what your doctor told you to do now. If you feel unwell, call 999.', 'সুগার ডাক্তারের দেওয়া সীমার নিচে। ডাক্তার যা করতে বলেছেন, এখনই তা করুন। খারাপ লাগলে ৯৯৯।');
  String get savedFever => _('Fever is above your doctor’s limit. Follow your doctor’s instructions.', 'জ্বর ডাক্তারের দেওয়া সীমার বেশি। ডাক্তারের দেওয়া নির্দেশ মানুন।');
  String get familyTold => _(' Your family will be told.', ' পরিবারকে জানানো হবে।');
  String get inRange => _('In range', 'সীমার মধ্যে');
  String get aboveRange => _('Above range', 'সীমার উপরে');
  String get belowRange => _('Below range', 'সীমার নিচে');
  String get veryHigh => _('Very high', 'অনেক বেশি');
  String get veryLow => _('Very low', 'অনেক কম');
  String get pulse => _('pulse', 'নাড়ি');

  // --- Crisis ---
  String get call999 => _('Call 999', '৯৯৯ এ কল');
  String get call16263 => _('16263 doctor', '১৬২৬৩ ডাক্তার');
  String get alertFamily => _('Alert family', 'পরিবারকে জানান');
  String get alertSent => _('Urgent alert sent to your caregiver', 'পরিচর্যাকারীকে জরুরি খবর পাঠানো হয়েছে');
  String get alertNobody => _('No caregiver to tell. Call 999 or someone near you.', 'জানানোর মতো পরিচর্যাকারী নেই। ৯৯৯ বা কাছের কাউকে ফোন করুন।');
  String get measureAgainNow => _('Measure again', 'আবার মাপুন');
  String get checkAgain => _('Check again', 'আবার মাপুন');

  // --- Limits ---
  String get limitsIntroTitle => _('Enter the numbers your doctor gave you', 'ডাক্তার যে সংখ্যা দিয়েছেন, সেটাই লিখুন');
  String get limitsIntro => _('The app uses these numbers to tell you if a reading is in range and when to alert you. Leave a box empty if your doctor did not give it; empty means no alert.', 'এই সংখ্যা দিয়েই অ্যাপ বলবে রিডিং সীমার মধ্যে কি না, আর কখন সতর্ক করবে। ডাক্তার না দিলে ঘর খালি রাখুন; খালি মানে কোনো সতর্কতা নেই।');
  String get limSugar => _('Sugar', 'সুগার');
  String get limBp => _('Blood pressure', 'রক্তচাপ');
  String get limOther => _('Other targets', 'অন্যান্য লক্ষ্য');
  String get limFastLo => _('Fasting, lowest', 'খালি পেটে, সর্বনিম্ন');
  String get limFastHi => _('Fasting, highest', 'খালি পেটে, সর্বোচ্চ');
  String get limAfterHi => _('2 hours after food, highest', 'খাবারের ২ ঘণ্টা পর, সর্বোচ্চ');
  String get limLow => _('Low sugar alert, below', 'কম সুগারের সতর্কতা, এর নিচে');
  String get limHba1c => _('HbA1c target, below', 'HbA1c লক্ষ্য, এর নিচে');
  String get limBpSys => _('Upper number, stay below', 'উপরের সংখ্যা, এর নিচে থাকবে');
  String get limBpDia => _('Lower number, stay below', 'নিচের সংখ্যা, এর নিচে থাকবে');
  String get limBpLow => _('Low BP alert, upper number below', 'কম প্রেসারের সতর্কতা, উপরের সংখ্যা এর নিচে');
  String get limCritS => _('Emergency level, upper number', 'জরুরি সীমা, উপরের সংখ্যা');
  String get limCritD => _('Emergency level, lower number', 'জরুরি সীমা, নিচের সংখ্যা');
  String get limCritHint => _('Empty = 180/120 (160/110 in pregnancy). The very-low-sugar level (below 3.0 mmol/L) is fixed.', 'খালি = ১৮০/১২০ (গর্ভাবস্থায় ১৬০/১১০)। খুব কম সুগারের সীমা (৩.০ mmol/L এর নিচে) বদলানো যায় না।');
  String get limPf => _('Best peak flow (from your doctor)', 'সেরা পিক ফ্লো (ডাক্তারের দেওয়া)');
  String get limWGain => _('Weight gain limit in 3 days', '৩ দিনে ওজন বাড়ার সীমা');
  String get limTshLo => _('TSH, lowest', 'TSH, সর্বনিম্ন');
  String get limTshHi => _('TSH, highest', 'TSH, সর্বোচ্চ');
  String get limFluid => _('Daily fluid limit (0 = none)', 'দিনে পানির সীমা (০ = নেই)');
  String get limFever => _('Fever alert, above', 'জ্বরের সতর্কতা, এর বেশি');
  String get limWGoal => _('Target weight', 'লক্ষ্য ওজন');
  String get limWater => _('Water a day', 'দিনে পানি');
  String get limSleep => _('Sleep a night', 'রাতে ঘুম');
  String get kg => _('kg', 'কেজি');
  String get ml => _('ml', 'মি.লি.');
  String get glassesUnit => _('glasses', 'গ্লাস');
  String get hoursUnit => _('hours', 'ঘণ্টা');
  String get tellFamily => _('Tell my family when a reading is out of range', 'সীমার বাইরে হলে পরিবারকে জানাবো');
  String get tellFamilySub => _('Your caregiver is told right away (no numbers on their lock screen)', 'যিনি খেয়াল রাখেন, উনি সাথে সাথে খবর পাবেন (লক স্ক্রিনে সংখ্যা দেখাবে না)');
  String get whichDoctorGave => _('Which doctor gave these', 'কোন ডাক্তার দিয়েছেন');
  String get doctorNameDate => _('Doctor’s name, date', 'ডাক্তারের নাম, তারিখ');
  String get clearAll => _('Clear all numbers', 'সব সংখ্যা মুছুন');
  String limitOutOfRange(String lo, String hi) => _('Between $lo and $hi', '${n(lo)} থেকে ${n(hi)} এর মধ্যে');
  String get lowAboveHigh => _('The lowest must be below the highest', 'সর্বনিম্ন সংখ্যা সর্বোচ্চের চেয়ে কম হতে হবে');
  String setBy(String who) => _('Set by: $who', 'দিয়েছেন: $who');
  String rangeFasting(String lo, String hi) => _('fasting $lo–$hi', 'খালি পেটে ${n(lo)}–${n(hi)}');
  String rangeBp(int s, int d) => _('below $s/$d', '${n(s)}/${n(d)} এর নিচে');

  // --- Condition pages ---
  String get careOf => _('care', 'কেয়ার');
  String get logBp => _('Log BP', 'প্রেসার লিখুন');
  String get logSugar => _('Log sugar', 'সুগার লিখুন');
  String get logWeight => _('Log weight', 'ওজন লিখুন');
  String get logPeakFlow => _('Log peak flow', 'পিক ফ্লো লিখুন');
  String get lastReading => _('Last reading', 'শেষ রিডিং');
  String get morningAvg => _('Morning avg', 'সকালের গড়');
  String get eveningAvg => _('Evening avg', 'সন্ধ্যার গড়');
  String get sevenDays => _('7 days', '৭ দিন');
  String get readings14 => _('readings, 14 days', '১৪ দিনের রিডিং');
  String get sevenDayAvg => _('7-day average', '৭ দিনের গড়');
  String get measureTwiceToday => _('Measure twice today', 'আজ দুইবার মাপুন');
  String get morningBeforeMed => _('Morning, before medicine', 'সকাল, ওষুধের আগে');
  String get evening => _('Evening', 'সন্ধ্যা');
  String get due => _('due', 'বাকি');
  String get fastingSeven => _('Fasting sugar, 7 days', 'খালি পেটের সুগার, ৭ দিন');
  String get noSugarYet => _('No readings yet. Log your first sugar reading.', 'এখনো কোনো রিডিং নেই। প্রথম সুগার রিডিং লিখুন।');
  String get chartNote => _('The green band is your doctor’s range. An orange dot means out of range.', 'সবুজ ঘর ডাক্তারের সীমা। কমলা বিন্দু মানে সীমার বাইরে।');
  String get yourLimits => _('Your doctor’s limits', 'ডাক্তারের দেওয়া সীমা');
  String get sugarTab => _('Sugar', 'সুগার');
  String get insulinTab => _('Insulin and sites', 'ইনসুলিন ও জায়গা');
  String get doctorPdf => _('Doctor PDF', 'ডাক্তারের PDF');
  String get whenToAct => _('Tap to see', 'দেখতে ট্যাপ করুন');
  String get rememberShare => _('Remember these and share them with family', 'মনে রাখুন, পরিবারকেও জানিয়ে রাখুন');
  String get howFeel => _('How do you feel today?', 'আজ কেমন লাগছে?');
  String get howFeelSub => _('Pick what you have; it helps at your doctor visit. Ones marked red are urgent.', 'যা হচ্ছে বাছুন। ডাক্তার দেখানোর সময় কাজে লাগবে। লাল দাগের গুলো জরুরি।');
  String get feelFine => _('I feel fine', 'ভালো আছি');
  String lastOn(String day) => _('Last: $day', 'শেষ লেখা: $day');
  String get todaysHabits => _('Today’s habits', 'আজকের অভ্যাস');
  String get noHabits => _('No habits yet. Tap “Edit” to add some.', 'কোনো অভ্যাস নেই। “সাজান” চেপে যোগ করুন।');
  String get ownHabit => _('Type what your doctor advised', 'ডাক্তার যা বলেছেন, নিজে লিখুন');
  String get regularTests => _('Regular tests', 'নিয়মিত টেস্ট');
  String get regularTestsSub => _('Keep dates and results for the tests your doctor ordered', 'ডাক্তার যেগুলো দিয়েছেন, সেগুলোর তারিখ ও ফল রাখুন');
  String get regularTestsEdit => _('Remove or add tests, and choose how often your doctor wants each', 'টেস্ট সরান বা যোগ করুন, আর ডাক্তার কত দিন পর পর বলেছেন তা বাছুন');
  String get noTests => _('No tests yet. Tap “Edit” to add some.', 'কোনো টেস্ট নেই। “সাজান” চেপে যোগ করুন।');
  String get allRecords => _('All records', 'সব রেকর্ড');
  String everyMonths(int m) => m == 0 ? _('as advised', 'ডাক্তার যখন বলেন') : _('every $m mo', 'প্রতি ${n(m)} মাসে');
  String lastResult(String date) => _('Last: $date', 'শেষ: $date');
  String get notRecorded => _('Not done or not recorded', 'করা হয়নি বা লেখা নেই');
  String get schedule => _('Schedule', 'তারিখ রাখুন');
  String get addDate => _('Add date', 'তারিখ যোগ');
  String dueOn(String date) => _('Due $date', 'হওয়ার কথা $date');
  String wasDue(String date) => _('Was due $date', 'হওয়ার কথা ছিল $date');
  String get otherTestName => _('Type another test name', 'অন্য টেস্টের নাম লিখুন');
  String get nextVisit => _('Next doctor visit', 'পরের বার ডাক্তার দেখানো');
  String get nextVisitSub => _('Add the date and we will remind you the day before and have your readings report ready.', 'তারিখ রাখলে আগের দিন মনে করাবো, আর রিডিংয়ের রিপোর্ট তৈরি রাখবো।');
  String get doctorVisit => _('Doctor visit', 'ডাক্তার দেখানো');
  String get doctorNotAdded => _('Doctor not added', 'ডাক্তারের নাম লেখা হয়নি');
  String get takeReport => _('Take the report', 'রিপোর্ট সাথে নিন');
  String get checkLimits => _('Check your limits', 'সীমা মিলিয়ে নিন');
  String get seeRecords => _('See records', 'রেকর্ড দেখুন');
  String get questions => _('Questions for my doctor', 'ডাক্তারকে যা জিজ্ঞেস করব');
  String get noQuestions => _('Nothing written yet', 'এখনো কিছু লেখা হয়নি');
  String get writeQuestion => _('Write a question', 'প্রশ্ন লিখুন');
  String get medicinesForThis => _('Medicines for this', 'এই রোগের ওষুধ');
  String get medicineTile => _('Medicine', 'ওষুধ');
  String get takeRegularly => _('Taking them regularly matters most. Last 7 days:', 'নিয়মিত খাওয়াই সবচেয়ে জরুরি। গত ৭ দিন:');
  String allDosesDays(int ok, int known) => _('All doses on $ok of $known days', '${n(known)} দিনে ${n(ok)} দিন সব ডোজ');
  String get noMedsForThis => _('No medicine tagged for this. Open a medicine and choose this condition under “For which condition”.', 'এই রোগের জন্য কোনো ওষুধ চিহ্নিত নেই। ওষুধ খুলে “কোন রোগের জন্য” থেকে এই রোগ বাছুন।');
  String get medicineForCondition => _('For which condition', 'কোন রোগের জন্য');
  String get medicineTagNote => _('Only a label for your own list; the app never suggests a medicine.', 'শুধু আপনার নিজের তালিকার জন্য; অ্যাপ কখনো ওষুধ বলে দেয় না।');
  String get none => _('None', 'কোনোটি নয়');
  String get allMedicines => _('All', 'সব ওষুধ');

  // diabetes / insulin
  String get insulinLog => _('Insulin log', 'ইনসুলিন লগ');
  String get noInsulin => _('No insulin added', 'কোনো ইনসুলিন যোগ করা নেই');
  String get noInsulinSub => _('If you use insulin, add it as a medicine (form: Insulin). Logging where you inject helps you rotate sites.', 'ইনসুলিন নিলে ওষুধ হিসেবে যোগ করুন (ধরন: ইনসুলিন)। প্রতিবার কোথায় দিলেন লিখে রাখলে জায়গা বদলাতে সুবিধা হবে।');
  String get addInsulin => _('Add insulin', 'ইনসুলিন যোগ করুন');
  String get whereNext => _('Where to inject next?', 'পরের বার কোথায় দেবেন?');
  String get whereNextSub => _('Tap a site to log it. Suggested: the site used longest ago.', 'জায়গায় ট্যাপ করে লগ করুন। পরামর্শ: যেখানে সবচেয়ে আগে দিয়েছিলেন।');
  String get suggestedNext => _('Suggested next', 'পরের জন্য পরামর্শ');
  String get usedToday => _('Used today', 'আজ দেওয়া হয়েছে');
  String get usedEarlier => _('Used earlier', 'আগে দেওয়া হয়েছে');
  String get bodyFacesYou => _('The body faces you: its left side is on your right.', 'শরীর আপনার দিকে মুখ করে দেখানো: এর বাম দিক আপনার ডানে।');
  String get notUsedYet => _('not used yet', 'এখনো দেওয়া হয়নি');
  String usedOn(String when) => _('last: $when', 'শেষ: $when');
  String get whoGave => _('Who gave the injection?', 'কে ইনজেকশন দিলেন?');
  String get unitsGiven => _('Units given', 'কত ইউনিট দিলেন');
  String prescribedUnits(String u) => _('Prescribed: $u', 'প্রেসক্রিপশনে: $u');
  String logInsulinAt(String site) => _('Log this dose, $site', 'এই ডোজ লগ করুন, $site');
  String get allInsulinDone => _('All of today’s insulin is done', 'আজকের সব ইনসুলিন দেওয়া হয়েছে');
  String insulinGiven(String time, String site) => _('Given $time, $site', 'দেওয়া হয়েছে $time, $site');
  String insulinDue(String time) => _('Due $time', 'দিতে হবে $time');
  String get insulinLogged => _('Insulin logged and marked taken', 'ইনসুলিন লগ হয়েছে, খাওয়া হিসেবে চিহ্নিত');
  String get whyRotate => _('Why rotate sites?', 'কেন জায়গা বদলাবেন?');
  String penInUse(String date) => _('Pen in use, opened $date', 'পেন ব্যবহার হচ্ছে, খোলা $date');
  String penUseBy(String date, int remind) => _('Use by after opening: $date (from the leaflet you entered). We remind you $remind days before.', 'খোলার পর মেয়াদ: $date (লিফলেট থেকে আপনার দেওয়া তথ্য)। ${n(remind)} দিন আগে মনে করাবো।');
  String get penExpired => _('Expired, open a new pen', 'মেয়াদ শেষ, নতুন পেন খুলুন');
  String penExpires(String when) => _('Expires $when', '$when মেয়াদ শেষ');
  String get penNew => _('Opened a new pen', 'নতুন পেন খুলেছি');
  String get penAdd => _('Add the pen opening date', 'পেন খোলার তারিখ লিখুন');
  String get penAddSub => _('We remind you before it expires', 'মেয়াদ শেষ হওয়ার আগে মনে করাবো');
  String get penOpenedOn => _('Opened on', 'খোলার তারিখ');
  String get penLifeDays => _('Days it lasts after opening (leaflet)', 'খোলার পর কত দিন চলে (লিফলেট)');
  String get penRemindBefore => _('Remind me this many days before', 'কত দিন আগে মনে করাবো');
  String get daysUnit => _('days', 'দিন');

  // bp
  String get bpCare => _('Blood pressure care', 'রক্তচাপ কেয়ার');
  String get diabetesCare => _('Diabetes care', 'ডায়াবেটিস কেয়ার');

  // pregnancy
  String get pregnancy => _('Pregnancy', 'গর্ভকাল');
  String weeksDays(int w, int d) => _('$w weeks $d days', '${n(w)} সপ্তাহ ${n(d)} দিন');
  String trimester(int t) => [_('First', 'প্রথম'), _('Second', 'দ্বিতীয়'), _('Third', 'তৃতীয়')][t - 1] + _(' trimester', ' ত্রৈমাসিক');
  String get dueDate => _('Due date', 'সম্ভাব্য তারিখ');
  String weeksToGo(int w) => _('$w weeks to go', 'আর ${n(w)} সপ্তাহ');
  String get addDueDate => _('Add your due date', 'সম্ভাব্য প্রসবের তারিখ দিন');
  String get addDueDateSub => _('The date from your doctor or scan. Weeks, check-ups and movement counting start from it.', 'ডাক্তার বা আল্ট্রাসনোগ্রামে যে তারিখ দিয়েছে। এটা দিলেই সপ্তাহ, চেকআপ আর নড়াচড়া গোনা চালু হবে।');
  String get changeDueDate => _('Change date (from your doctor)', 'তারিখ বদলান (ডাক্তার যা বলেছেন)');
  String get ancTitle => _('Pregnancy check-ups (ANC)', 'গর্ভকালীন চেকআপ (ANC)');
  String doneOf(int a, int b) => _('$a of $b done', '${n(a)}/${n(b)} হয়েছে');
  String checkupN(int k) => _('Check-up $k', '${n(k)} নং চেকআপ');
  String get markDone => _('Mark done', 'হয়েছে');
  String get addCheckup => _('Add another check-up', 'আরেকটি চেকআপ যোগ');
  String get checkedEachVisit => _('Checked at each visit', 'প্রতিবার যা দেখা হয়');
  String get kicksTitle => _('Baby’s movements', 'বাচ্চার নড়াচড়া');
  String kicksFrom28(int w) => _('Starts at 28 weeks, $w weeks to go', '২৮ সপ্তাহ থেকে চালু হবে, আর ${n(w)} সপ্তাহ');
  String get countingMovements => _('Counting baby’s movements', 'বাচ্চার নড়াচড়া গোনা');
  String get startCounting => _('Start counting', 'নড়াচড়া গোনা শুরু');
  String get babyMoved => _('Baby moved', 'বাচ্চা নড়লো');
  String get finishSave => _('Finish and save', 'শেষ করুন ও লিখে রাখুন');
  String kicksStarted(String t) => _('Started $t. Tap the big button each time baby moves.', 'শুরু $t। প্রতিবার নড়লে বড় বোতাম চাপুন।');
  String kicksIn(int c, int m) => _('$c in $m min', '${n(c)} বার, ${n(m)} মিনিটে');
  String get times => _('times', 'বার');
  String get bpAndWeight => _('Blood pressure and weight', 'প্রেসার ও ওজন');
  String get lastBp => _('Last BP', 'শেষ প্রেসার');
  String sinceStart(String kg) => _('$kg kg since start', 'শুরু থেকে ${n(kg)} কেজি');
  String get startWeight => _('Weight at the start (kg)', 'শুরুর ওজন (কেজি)');
  String get tdVaccine => _('Td (tetanus) vaccine', 'টিডি (টিটেনাস) টিকা');
  String tdDoses(int c, String last) => _('$c dose${c > 1 ? 's' : ''} taken, last $last', '${n(c)}টি ডোজ নেওয়া, শেষ $last');
  String get tdNone => _('No doses recorded', 'কোনো ডোজ লেখা নেই');
  String get addDose => _('Add dose', 'ডোজ যোগ');
  String get birthPlan => _('Birth plan', 'প্রসবের প্রস্তুতি');
  String birthPlanReady(int k) => _('$k of 6 ready', '${n(k)}/৬ ঠিক করা হয়েছে');
  String get bpHospital => _('Where you will give birth', 'কোথায় প্রসব হবে');
  String get bpHospitalHint => _('Hospital or clinic', 'হাসপাতাল বা ক্লিনিকের নাম');
  String get bpTransport => _('Transport', 'যাতায়াতের ব্যবস্থা');
  String get bpTransportHint => _('e.g. a driver’s number', 'যেমন: সিএনজি চালকের নম্বর');
  String get bpBlood => _('Your blood group', 'আপনার রক্তের গ্রুপ');
  String get bpDonor => _('Blood donor', 'রক্তদাতা');
  String get bpDonorHint => _('Name and phone', 'নাম ও ফোন নম্বর');
  String get bpCompanion => _('Who will go with you', 'সাথে কে যাবেন');
  String get bpName => _('Name', 'নাম');
  String get bpMoney => _('Money set aside for costs', 'খরচের টাকা আলাদা করে রাখা আছে');
  String get dangerSigns => _('Danger signs', 'বিপদচিহ্ন');
  String get countMovements => _('Count movements', 'নড়াচড়া গুনুন');

  // heart
  String get heartCare => _('Heart care', 'হৃদরোগ কেয়ার');
  String get weightToday => _('Weight', 'আজকের ওজন');
  String get in3Days => _('In 3 days', '৩ দিনে');
  String get bpPulse => _('BP, pulse', 'প্রেসার, নাড়ি');
  String weightRose(String g, String lim) => _('Weight rose $g kg in 3 days; your doctor’s limit is $lim kg. Tell your doctor today.', '৩ দিনে ওজন ${n(g)} কেজি বেড়েছে, ডাক্তারের দেওয়া সীমা ${n(lim)} কেজি। আজই ডাক্তারকে জানান।');
  String weightAlertNote(String lim) => _('We alert you if weight rises more than $lim kg in 3 days (your doctor’s number, can be changed).', '৩ দিনে ${n(lim)} কেজির বেশি বাড়লে সতর্ক করবো (ডাক্তারের দেওয়া সংখ্যা, বদলানো যায়)।');
  String get weightNoLimit => _('Add your doctor’s 3-day weight gain limit to get an alert.', 'সতর্কতা পেতে ডাক্তারের দেওয়া ৩ দিনের ওজন বাড়ার সীমা লিখুন।');
  String get bpAndPulse => _('BP and pulse', 'প্রেসার ও নাড়ি');

  // kidney
  String get creatinineResults => _('Creatinine results', 'ক্রিয়েটিনিনের ফল');
  String get noResults => _('No results yet', 'এখনো কোনো ফল লেখা নেই');
  String get addResult => _('Add a result', 'নতুন ফল লিখুন');
  String get fluidLimit => _('Fluid limit', 'পানির সীমা');
  String get notSet => _('Not set', 'সেট নেই');
  String get onDialysis => _('On dialysis', 'ডায়ালাইসিস চলছে');
  String get dialysisOff => _('Turn on for session reminders', 'চালু করলে দিন মনে করাবো');
  String dialysisDays(String days) => _('Days: $days', 'দিন: $days');
  String get sessionTime => _('Session time', 'সেশনের সময়');
  List<String> get weekdaysShort => bn ? const ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি'] : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // asthma
  String get reliever => _('Reliever', 'উপশমকারী');
  String daysCount(int d) => _('$d days', '${n(d)} দিন');
  String nightsCount(int d) => _('$d nights', '${n(d)} রাত');
  String get thisWeek => _('this week', 'এই সপ্তাহে');
  String get nightWaking => _('Night waking', 'রাতে ঘুম ভাঙা');
  String get peakFlow => _('Peak flow', 'পিক ফ্লো');
  String ofBest(int p) => _('$p% of best', 'সেরার ${n(p)}%');
  String get relieverWarn => _('You needed your reliever on more than 2 days this week. Tell your doctor.', 'এই সপ্তাহে ২ দিনের বেশি উপশমকারী লেগেছে। ডাক্তারকে জানান।');
  String get relieverNote => _('We will alert you if you need your reliever on more than 2 days a week.', 'উপশমকারী ইনহেলার সপ্তাহে ২ দিনের বেশি লাগলে সতর্ক করবো।');
  String get greenZone => _('Green zone', 'সবুজ অঞ্চল');
  String get yellowZone => _('Yellow zone', 'হলুদ অঞ্চল');
  String get redZone => _('Red zone', 'লাল অঞ্চল');
  String basedOnBest(int b) => _('Based on your best peak flow of $b', 'ডাক্তারের দেওয়া সেরা পিক ফ্লো ${n(b)} ধরে');
  String get usedReliever => _('Used reliever', 'পাফ নিলাম');
  String get relieverLogged => _('Reliever use logged', 'উপশমকারী লেখা হয়েছে');
  String get myTriggers => _('My triggers', 'আমার যেগুলোতে সমস্যা হয়');
  String get wokeLastNight => _('Woke up last night with asthma', 'কাল রাতে শ্বাসকষ্টে ঘুম ভেঙেছে');

  // thyroid
  String get tshResults => _('TSH results', 'TSH-এর ফল');
  String nextTest(String when) => _('Next test $when', 'পরের টেস্ট $when');
  String get nextTestDate => _('Next test date', 'পরের টেস্টের তারিখ');
  String doctorRangeTsh(String lo, String hi) => _('Doctor’s range $lo–$hi', 'ডাক্তারের সীমা ${n(lo)}–${n(hi)}');

  // cancer
  String get cancerCare => _('Cancer care', 'ক্যান্সার কেয়ার');
  String get chemoCycles => _('Chemo cycles', 'কেমো চক্র');
  String chemoOf(int a, int b) => _('$a of $b done', '${n(a)}/${n(b)} শেষ');
  String get chemoPlan => _('How many cycles in the plan?', 'পরিকল্পনায় কয়টি চক্র?');
  String get chemoDoneOne => _('One cycle done', 'একটি চক্র শেষ');
  String get comingUp => _('Coming up', 'সামনে');
  String get addChemoDate => _('Add a chemo date', 'কেমোর তারিখ যোগ');
  String get chemoSession => _('Chemo session', 'কেমো সেশন');
  String get reminderOn => _('Reminder on', 'মনে করাবো');
  String get addReport => _('Add report', 'রিপোর্ট দিন');
  String get questionsShort => _('Questions', 'ডাক্তারকে প্রশ্ন');

  // --- Records (Round 16) ---
  String get healthRecords => _('Health records', 'স্বাস্থ্য রেকর্ড');
  String get pdfCardTitle => _('One-page report for your doctor', 'ডাক্তারের জন্য এক পাতার রিপোর্ট');
  String get pdfCardSub => _('Doses split into on time, late and missed. Test numbers, sugar, BP and report photos', 'ওষুধ: সময়মতো, দেরিতে আর মিস আলাদা করে। টেস্টের সংখ্যা, সুগার, প্রেসার, রিপোর্টের ছবিসহ');
  String missingNumbers(int k) => _('$k report${k > 1 ? 's are' : ' is'} missing numbers or a photo. Both make the doctor’s report complete.', '${n(k)}টি রিপোর্টে সংখ্যা বা ছবি বাকি। দুটোই থাকলে ডাক্তারের রিপোর্ট পুরো হবে।');
  String get doctorVisits => _('Doctor visits', 'ডাক্তার দেখানো');
  String get upcomingTests => _('Upcoming tests', 'সামনের টেস্ট');
  String get remindMe => _('Remind', 'মনে করাবো');
  String get doneAddResult => _('Have result', 'ফলাফল আছে');
  String get testReports => _('Test reports', 'টেস্ট রিপোর্ট');
  String get prescriptions => _('Prescriptions', 'প্রেসক্রিপশন');
  String get keepRecord => _('Keep a record', 'রেকর্ডে রাখুন');
  String get sendToPharmacist => _('Send to a pharmacist to set up medicines', 'ফার্মাসিস্টকে পাঠান, ওষুধ সাজিয়ে দেবেন');
  String get recordsNote => _('You can keep old or new prescriptions just for your records. To have your medicines set up, send it to a pharmacist from the + button.', 'পুরোনো বা নতুন প্রেসক্রিপশন শুধু রেকর্ডের জন্য রাখতে পারেন। ওষুধ সাজাতে চাইলে + থেকে ফার্মাসিস্টকে পাঠান।');
  String get whatToAdd => _('What would you like to add?', 'কী যোগ করবেন?');
  String get addTestReport => _('Test report', 'টেস্ট রিপোর্ট');
  String get addTestReportSub => _('Result numbers and a photo of the report', 'ফলের সংখ্যা আর রিপোর্টের ছবি');
  String get addUpcomingTest => _('Upcoming test date', 'সামনের টেস্টের তারিখ');
  String get remindDayBefore => _('We remind you the day before', 'আগের দিন মনে করাবো');
  String get addRecordRx => _('Prescription, record only', 'প্রেসক্রিপশন, শুধু রেকর্ডে');
  String get addRecordRxSub => _('Old or new; not sent to a pharmacist', 'পুরোনো বা নতুন, ফার্মাসিস্টের কাছে যাবে না');
  String get addVisit => _('Doctor visit date', 'ডাক্তার দেখানোর তারিখ');

  // test form
  String get testOrReport => _('Test or report', 'টেস্ট ও রিপোর্ট');
  String get testResult => _('Test result', 'টেস্টের ফলাফল');
  String get whichTest => _('Which test?', 'কোন টেস্ট?');
  String get otherTest => _('Other', 'অন্য');
  String get testName => _('Test name', 'টেস্টের নাম');
  String get comingUpMode => _('Coming up', 'সামনে হবে');
  String get doneMode => _('Have result', 'ফলাফল আছে');
  String get whenWasIt => _('When was it?', 'কবে হয়েছে?');
  String get when => _('When?', 'কবে?');
  String get enterResults => _('Enter the results', 'ফলাফল লিখুন');
  String get exactlyAsPrinted => _('Type the numbers exactly as printed on the report', 'রিপোর্টে যে সংখ্যা ছাপা, ঠিক সেটাই লিখুন');
  String get addValue => _('Add another value', 'আরও একটি মান যোগ');
  String get valueName => _('Name', 'নাম');
  String get value => _('Value', 'মান');
  String get unit => _('Unit', 'একক');
  String get findings => _('Findings written on the report', 'রিপোর্টে লেখা মন্তব্য');
  String get findingsHint => _('e.g. Normal', 'যেমন: স্বাভাবিক');
  String get whichLab => _('Which lab', 'কোন ল্যাব');
  String get labName => _('Lab name', 'ল্যাবের নাম');
  String get reportPhoto => _('Photo of the report', 'রিপোর্টের ছবি');
  String get reportPhotoSub => _('Kept as proof, so your doctor can check the original', 'প্রমাণ হিসেবে রাখা হবে, ডাক্তার চাইলে আসল কাগজ মিলিয়ে দেখবেন');
  String get takePhoto => _('Take a photo', 'ছবি তুলুন');
  String get addPage => _('Add a page', 'আরও পাতা');
  String get fromGallery => _('From gallery', 'গ্যালারি থেকে');
  String get numbersNote => _('The numbers build your doctor’s report and graphs. The photo stays as proof of the original.', 'সংখ্যাগুলো দিয়ে ডাক্তারের জন্য রিপোর্ট আর গ্রাফ তৈরি হবে। ছবি থাকবে আসল কাগজের প্রমাণ হিসেবে।');
  String get remindTestDayBefore => _('Remind me the day before', 'আগের দিন মনে করাবো');
  String get remindTestSub => _('At 9 AM', 'সকাল ৯টায়');
  String get fastingNeeded => _('I need to fast for this test', 'এই টেস্টে খালি পেটে যেতে হবে');
  String get pickTest => _('Pick a test or type its name', 'টেস্ট বাছুন বা নাম লিখুন');
  String get results => _('Results', 'ফলাফল');
  String get noNumbers => _('No numbers yet. Add them so they appear in the doctor’s report and graphs.', 'সংখ্যা লেখা হয়নি। লিখে দিলে ডাক্তারের রিপোর্ট আর গ্রাফে আসবে।');
  String get earlierResults => _('Earlier results', 'আগের ফলাফল');
  String get reportPhotos => _('Report photos', 'রিপোর্টের ছবি');
  String get noPhoto => _('No photo yet. Your doctor may want to check the original.', 'ছবি নেই। ডাক্তার আসল কাগজ মিলিয়ে দেখতে চাইলে ছবি লাগবে।');
  String get editNumbers => _('Edit numbers', 'সংখ্যা বদলান');
  String get pdfGetsNumbers => _('These numbers go into the PDF for your doctor, with the photos attached.', 'ডাক্তারের জন্য PDF-এ এই সংখ্যাগুলো যাবে, সাথে ছবিও।');
  String get noLab => _('No lab name', 'ল্যাবের নাম লেখা নেই');
  String doctorsTarget(String t) => _('Doctor’s target: $t', 'ডাক্তারের লক্ষ্য: $t');
  String get bloodGroup => _('Blood group', 'রক্তের গ্রুপ');
  String get deleteRecordQ => _('Delete this record and its photos?', 'এই রেকর্ড আর এর ছবি মুছবেন?');
  String get fasting => _('fasting', 'খালি পেটে');

  // visit form
  String get visitTitle => _('Doctor visit', 'ডাক্তার দেখানোর তারিখ');
  String get date => _('Date', 'তারিখ');
  String get whichDoctor => _('Which doctor', 'কোন ডাক্তার');
  String get searchDoctor => _('Search by name', 'নাম দিয়ে খুঁজুন');
  String get newDoctor => _('New doctor', 'নতুন ডাক্তার');
  String get doctorName => _('Doctor’s name', 'ডাক্তারের নাম');
  String get chamber => _('Hospital or chamber', 'হাসপাতাল বা চেম্বার');
  String get area => _('Area', 'এলাকা');
  String get myDoctors => _('My doctors', 'আমার ডাক্তার');
  String get fromList => _('From the list', 'তালিকা থেকে');
  String get noDoctor => _('No doctor', 'ডাক্তার নেই');
  String get forWhichCondition => _('For which condition', 'কোন রোগের জন্য');
  String get remindVisitSub => _('At 7 PM, with a nudge to take your reports', 'সন্ধ্যা ৭টায়, রিপোর্ট সাথে নিতে বলবো');
  String get note => _('Note', 'নোট');
  String get removeDate => _('Remove date', 'তারিখ মুছুন');
  String get privateDoctorNote => _('A doctor you type stays in your own list; it is never added to the pharmacy’s doctor list.', 'নিজে লেখা ডাক্তার শুধু আপনার তালিকায় থাকে, ফার্মেসির ডাক্তারের তালিকায় যোগ হয় না।');

  // record prescription
  String get keepRxTitle => _('Keep a prescription', 'প্রেসক্রিপশন রেকর্ডে রাখুন');
  String get keepRxNote => _('Just for your records. It is not sent to a pharmacist and does not change your medicine list.', 'শুধু আপনার রেকর্ডের জন্য। ফার্মাসিস্টের কাছে যাবে না, ওষুধের তালিকাও বদলাবে না।');
  String get rxPhoto => _('Prescription photo', 'প্রেসক্রিপশনের ছবি');
  String get rxDate => _('Prescription date', 'প্রেসক্রিপশনের তারিখ');
  String get saveToRecords => _('Save to records', 'রেকর্ডে রাখুন');
  String get addPhotoFirst => _('Add at least one photo', 'অন্তত একটি ছবি দিন');
  String get recordOnly => _('Record only', 'শুধু রেকর্ড');
  String pages(int p) => _('$p page${p > 1 ? 's' : ''}', '${n(p)} পাতা');
  String get photoFailed => _('A photo could not be uploaded. Open the record and add it again.', 'একটি ছবি আপলোড হয়নি। রেকর্ড খুলে আবার দিন।');

  // PDF
  String get makingPdf => _('Making the report…', 'রিপোর্ট তৈরি হচ্ছে…');
  String get pdfFailed => _('The report could not be made. Try again.', 'রিপোর্ট তৈরি করা যায়নি। আবার চেষ্টা করুন।');

  // reminders (lock screen: neutral, no names)
  String get remVisitTitle => _('Doctor visit tomorrow', 'আগামীকাল ডাক্তার দেখানো');
  String remVisitBody(String? time) => time == null ? _('Take your reports along.', 'রিপোর্টগুলো সাথে নিন।') : _('At $time. Take your reports along.', '$time টায়। রিপোর্টগুলো সাথে নিন।');
  String get remCheckupTitle => _('Check-up tomorrow', 'আগামীকাল চেকআপ');
  String get remSessionTitle => _('Treatment session tomorrow', 'আগামীকাল চিকিৎসার সেশন');
  String get remTestTitle => _('A test tomorrow', 'আগামীকাল একটি টেস্ট');
  String remTestBody(bool fasting) => fasting ? _('Remember: go with an empty stomach.', 'মনে রাখুন: খালি পেটে যেতে হবে।') : _('Open the app for the details.', 'বিস্তারিত দেখতে অ্যাপ খুলুন।');
  String remDialysisTitle(String time) => _('Your session is at $time', 'আপনার সেশন $time টায়');
  String get remDialysisBody => _('Leave in good time.', 'সময় হাতে রেখে রওনা দিন।');
  String get remPenTitle => _('A medicine pen expires soon', 'একটি ওষুধের পেনের মেয়াদ শেষ হচ্ছে');
  String get remPenBody => _('Open the app to see when.', 'কবে, দেখতে অ্যাপ খুলুন।');
}

extension Round15StringsOf on AppStrings {
  Round15Strings get r15 => identical(this, bnStrings) ? const Round15Strings(true) : const Round15Strings(false);
}
