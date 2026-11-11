/// Fixed texts of the condition pages (Round 15), from the owner's demo
/// ("Abba's Medi-Bela") in English and Bengali. These are fixed safety and
/// self-care texts, never AI output: no diagnosis, no medicine names, no
/// doses. The cancer texts and the low-sugar crisis sheet are Claude's
/// drafts (the demo has none), for the owner's review.
library;

/// One text in both languages.
typedef Bi = (String en, String bn);

String tr(Bi t, bool bn) => bn ? t.$2 : t.$1;

class CareItem {
  const CareItem(this.key, this.text, {this.urgent = false});

  final String key;
  final Bi text;

  /// Symptoms: an emergency sign (shown in red; picking one shows "call 999").
  final bool urgent;
}

class CareCard {
  const CareCard(this.title, this.items, {this.openByDefault = false});

  final Bi title;
  final List<Bi> items;
  final bool openByDefault;
}

class ConditionContent {
  const ConditionContent({
    this.habits = const [],
    this.symptoms = const [],
    this.tests = const [],
    this.danger,
    this.learn,
  });

  /// Daily habits suggested for this condition (the user may add or remove).
  final List<CareItem> habits;

  /// "How do you feel today?" choices.
  final List<CareItem> symptoms;

  /// Regular tests suggested (test kind codes).
  final List<String> tests;
  final CareCard? danger;
  final CareCard? learn;
}

/// The 8 condition codes (the conditions table's `code`) in the demo's order.
const conditionCodes = ['diabetes', 'bp', 'heart', 'kidney', 'cancer', 'asthma', 'thyroid', 'pregnancy'];

/// Names if the lookup is not loaded yet (the table's own text wins).
const conditionFallbackNames = <String, Bi>{
  'diabetes': ('Diabetes', 'ডায়াবেটিস'),
  'bp': ('High blood pressure', 'উচ্চ রক্তচাপ'),
  'heart': ('Heart disease', 'হৃদরোগ'),
  'kidney': ('Kidney disease', 'কিডনি রোগ'),
  'cancer': ('Cancer treatment', 'ক্যান্সার চিকিৎসা'),
  'asthma': ('Asthma', 'শ্বাসকষ্ট, অ্যাজমা'),
  'thyroid': ('Thyroid', 'থাইরয়েড'),
  'pregnancy': ('Pregnancy', 'গর্ভাবস্থা'),
};

/// Habits anyone may add, on top of a condition's own.
const habitPool = [
  CareItem('veg', ('Ate vegetables and fruit', 'শাকসবজি ও ফল খেয়েছি')),
  CareItem('sweet', ('No sweets or soft drinks', 'মিষ্টি ও কোমল পানীয় খাইনি')),
  CareItem('oil', ('Less fried and fatty food', 'ভাজাপোড়া ও তেল-চর্বি কম খেয়েছি')),
  CareItem('sleep', ('Slept 7–8 hours', '৭-৮ ঘণ্টা ঘুমিয়েছি')),
  CareItem('calm', ('10 minutes of quiet rest', '১০ মিনিট নিরিবিলি বিশ্রাম নিয়েছি')),
  CareItem('smoke', ('Did not smoke', 'ধূমপান করিনি')),
  CareItem('bpam', ('Measured BP in the morning', 'সকালে প্রেসার মেপেছি')),
  CareItem('foot', ('Checked my feet', 'পায়ের তলা পরীক্ষা করেছি')),
  CareItem('exer', ('Exercised as my doctor advised', 'ডাক্তারের বলা মতো ব্যায়াম করেছি')),
];

const asthmaTriggers = <String, Bi>{
  'dust': ('Dust', 'ধুলা'),
  'smoke': ('Smoke', 'ধোঁয়া'),
  'cook': ('Cooking smoke', 'রান্নার ধোঁয়া'),
  'coil': ('Mosquito coil', 'মশার কয়েল'),
  'cold': ('Cold air', 'ঠান্ডা বাতাস'),
  'pollen': ('Pollen', 'ফুলের রেণু'),
  'pet': ('Animal hair', 'পশুর লোম'),
};

const sugarContextNames = <String, Bi>{
  'FASTING': ('Fasting', 'খালি পেটে'),
  'AFTER_FOOD': ('2 hrs after food', 'খাবারের ২ ঘণ্টা পর'),
  'BEFORE_BED': ('Before bed', 'ঘুমের আগে'),
  'RANDOM': ('Random', 'যেকোনো সময়'),
};

const injectionSiteNames = <String, Bi>{
  'LEFT_THIGH': ('Left thigh', 'বাম ঊরু'),
  'RIGHT_THIGH': ('Right thigh', 'ডান ঊরু'),
  'LEFT_ABDOMEN': ('Left abdomen', 'বাম পেট'),
  'RIGHT_ABDOMEN': ('Right abdomen', 'ডান পেট'),
  'LEFT_ARM': ('Left arm', 'বাম বাহু'),
  'RIGHT_ARM': ('Right arm', 'ডান বাহু'),
};

const injectionGiverNames = <String, Bi>{
  'SELF': ('Self', 'নিজে'),
  'FAMILY': ('Family member', 'পরিবারের কেউ'),
  'NURSE': ('Nurse', 'নার্স'),
};

/// Regular tests: how often (months; 0 = as the doctor advises).
const testEveryChoices = [0, 1, 3, 6, 12];

const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// The BP crisis sheet (demo SH.crisis).
const bpCrisisTitle = ('Blood pressure is very high', 'প্রেসার অনেক বেশি');
const bpCrisisStep1 = ('1. Sit quietly for 5 minutes, then measure again', '১. ৫ মিনিট চুপচাপ বসে আবার মাপুন');
const bpCrisisStep1Sub = ('If it is still {level} or higher, contact your doctor now.', 'তখনও {level} বা বেশি থাকলে এখনই ডাক্তারকে জানান।');
const bpCrisisStep2 = ('2. Call 999 now if you have any of these', '২. এগুলোর কোনোটা থাকলে এখনই ৯৯৯');
const bpCrisisStep2Sub = (
  'Chest pain, shortness of breath, back pain, numbness or weakness, trouble seeing or speaking',
  'বুকে ব্যথা, শ্বাসকষ্ট, পিঠে ব্যথা, শরীর অবশ বা দুর্বল, চোখে দেখতে বা কথা বলতে সমস্যা',
);
const crisisNoExtraMedicine = ('Do not take extra medicine on your own.', 'নিজে থেকে বাড়তি ওষুধ খাবেন না।');

/// The low-sugar crisis sheet (Claude's draft from the demo's diabetes texts).
const sugarCrisisTitle = ('Sugar is very low', 'সুগার অনেক কমে গেছে');
const sugarCrisisStep1 = ('1. Do what your doctor told you to do for low sugar, now', '১. সুগার কমে গেলে ডাক্তার যা করতে বলেছেন, এখনই তা করুন');
const sugarCrisisStep1Sub = ('Then check your sugar again after 15 minutes.', 'তারপর ১৫ মিনিট পর আবার সুগার মাপুন।');
const sugarCrisisStep2 = ('2. Call 999 now if the person faints or has a fit', '২. অজ্ঞান হলে বা খিঁচুনি হলে এখনই ৯৯৯');
const sugarCrisisStep2Sub = ('Give nothing by mouth to someone who is not awake.', 'যিনি জেগে নেই, তাঁর মুখে কিছু দেবেন না।');

const helpline16263 = (
  '16263 Shasthya Batayon: government helpline, free doctor advice 24 hours.',
  '১৬২৬৩ স্বাস্থ্য বাতায়ন: সরকারি হেল্পলাইন, ২৪ ঘণ্টা বিনা মূল্যে ডাক্তারের পরামর্শ।',
);
const urgentSignNote = (
  'This can be an emergency sign. Do not wait: call 999 or go to the nearest hospital.',
  'এটি জরুরি লক্ষণ হতে পারে। দেরি না করে ৯৯৯ এ কল করুন বা কাছের হাসপাতালে যান।',
);

const whyRotateSites = (
  'Injecting in the same spot again and again can cause hard lumps under the skin, and insulin then works less well. Change the site each time, at least a finger-width from the last one. Inject the way your doctor or nurse showed you.',
  'একই জায়গায় বারবার ইনজেকশন দিলে চামড়ার নিচে শক্ত চাকা হতে পারে, তখন ইনসুলিন ঠিকমতো কাজ করে না। প্রতিবার জায়গা বদলান, আগের জায়গা থেকে অন্তত এক আঙুল দূরে। ডাক্তার বা নার্স যেভাবে দেখিয়েছেন, সেভাবেই দিন।',
);

const ancGuideline = (
  'Bangladesh’s guideline is at least 4 check-ups; WHO recommends at least 8 contacts. Follow your doctor’s dates.',
  'বাংলাদেশের নির্দেশনায় কমপক্ষে ৪ বার, WHO বলে কমপক্ষে ৮ বার চেকআপ। আপনার ডাক্তারের দেওয়া তারিখ মানুন।',
);
const ancChecked = (
  'Blood pressure, weight, anaemia, urine, baby’s heartbeat and growth',
  'প্রেসার, ওজন, রক্তস্বল্পতা, প্রস্রাব, বাচ্চার হৃৎস্পন্দন ও বৃদ্ধি',
);
const kickNote = (
  'Count at the time your baby is usually active. If movements feel less than usual, tell your doctor now, do not wait until tomorrow.',
  'প্রতিদিন যখন বাচ্চা সাধারণত নড়ে, সে সময় গুনুন। নড়াচড়া স্বাভাবিকের চেয়ে কম মনে হলে পরদিনের অপেক্ষা না করে এখনই ডাক্তারকে জানান।',
);
const pregnancyBpNote = (
  'In pregnancy, tell your doctor if BP is 140/90 or higher, and right away if it is 160/110 or higher. Ask your doctor how much weight gain is right for you.',
  'গর্ভাবস্থায় প্রেসার ১৪০/৯০ বা বেশি হলে ডাক্তারকে জানান। ১৬০/১১০ বা বেশি হলে এখনই। কতটা ওজন বাড়া ঠিক, ডাক্তারের কাছে জেনে নিন।',
);
const tdNote = ('Ask your health worker if you need more.', 'আর লাগবে কিনা স্বাস্থ্যকর্মীকে জিজ্ঞেস করুন।');
const birthPlanNote = (
  'Planning ahead avoids delays in an emergency. Share it with your family.',
  'আগে থেকে ঠিক রাখলে জরুরি সময়ে দেরি হয় না। পরিবারের সাথে শেয়ার করুন।',
);
const thyroidRecheckNote = (
  'After a dose change, doctors usually recheck TSH a few weeks later. Follow your doctor’s date.',
  'ডোজ বদলানোর পর ডাক্তার সাধারণত কয়েক সপ্তাহ পরে আবার TSH দেখেন। ডাক্তারের দেওয়া তারিখ মানুন।',
);

const _bpSymptoms = [
  CareItem('headache', ('Headache', 'মাথাব্যথা')),
  CareItem('dizzy', ('Dizziness', 'মাথা ঘোরা')),
  CareItem('nose', ('Nosebleed', 'নাক দিয়ে রক্ত')),
  CareItem('swell', ('Swollen feet', 'পা ফোলা')),
  CareItem('tired', ('Very tired', 'খুব ক্লান্তি')),
  CareItem('chest', ('Chest pain', 'বুকে ব্যথা'), urgent: true),
  CareItem('breath', ('Shortness of breath', 'শ্বাসকষ্ট'), urgent: true),
  CareItem('weak', ('Weakness or numbness on one side', 'শরীরের এক পাশ দুর্বল বা অবশ'), urgent: true),
  CareItem('speech', ('Trouble speaking', 'কথা জড়িয়ে যাওয়া'), urgent: true),
  CareItem('vision', ('Sudden change in vision', 'হঠাৎ চোখে ঝাপসা দেখা'), urgent: true),
];

const conditionContent = <String, ConditionContent>{
  'bp': ConditionContent(
    habits: [
      CareItem('salt', ('No extra salt at the table', 'পাতে কাঁচা লবণ নিইনি')),
      CareItem('walk', ('Walked 30 minutes', '৩০ মিনিট হেঁটেছি')),
      CareItem('tob', ('No tobacco, jorda, gul or betel nut', 'তামাক, জর্দা, গুল বা পান-সুপারি খাইনি')),
    ],
    symptoms: _bpSymptoms,
    tests: ['kidney', 'potassium', 'urine', 'lipid', 'ecg', 'eye'],
    danger: CareCard(('When to act right away', 'কখন এখনই ব্যবস্থা নেবেন'), [
      ('If BP is 180/120 or higher, rest 5 minutes and measure again. If it is still that high, contact your doctor now.', 'প্রেসার ১৮০/১২০ বা তার বেশি হলে ৫ মিনিট বিশ্রাম নিয়ে আবার মাপুন। তখনও বেশি থাকলে এখনই ডাক্তারকে জানান।'),
      ('If you also have chest pain, shortness of breath, back pain, numbness or weakness, or trouble seeing or speaking, do not wait: call 999.', 'সাথে বুকে ব্যথা, শ্বাসকষ্ট, পিঠে ব্যথা, শরীর অবশ বা দুর্বল, চোখে দেখতে বা কথা বলতে সমস্যা হলে অপেক্ষা না করে ৯৯৯ এ কল করুন।'),
      ('Do not stop your medicine without asking your doctor, even when readings are normal.', 'প্রেসার স্বাভাবিক থাকলেও ডাক্তারকে না জিজ্ঞেস করে ওষুধ বন্ধ করবেন না।'),
    ]),
    learn: CareCard(('How to measure BP correctly', 'সঠিকভাবে প্রেসার মাপার নিয়ম'), [
      ('No tea, coffee, smoking or exercise for 30 minutes before', 'মাপার ৩০ মিনিট আগে চা-কফি, ধূমপান বা ব্যায়াম নয়'),
      ('Empty your bladder, then sit quietly for 5 minutes', 'প্রস্রাব করে নিন, তারপর ৫ মিনিট চুপচাপ বসে থাকুন'),
      ('Sit with your back supported, feet flat, legs uncrossed', 'পিঠ হেলান দিয়ে বসুন, দুই পা মাটিতে, পা ক্রস করবেন না'),
      ('Rest your arm on a table at heart level', 'হাত টেবিলে রাখুন, বুকের সমান উচ্চতায়'),
      ('Put the cuff on bare skin just above the elbow, not over clothes', 'কাপড়ের উপর নয়, খালি হাতে কনুইয়ের একটু উপরে কাফ বাঁধুন'),
      ('Do not talk while measuring', 'মাপার সময় কথা বলবেন না'),
      ('Measure again after 1 minute and log both. Measure in the morning before medicine and in the evening.', '১ মিনিট পর আবার মাপুন, দুটোই লিখুন। সকালে ওষুধের আগে আর সন্ধ্যায় মাপুন।'),
      ('An upper-arm machine is better than a wrist machine', 'কবজির মেশিনের চেয়ে বাহুর (আপার আর্ম) মেশিন ভালো'),
    ]),
  ),
  'pregnancy': ConditionContent(
    habits: [
      CareItem('ifa', ('Took iron-folic acid', 'আয়রন-ফলিক অ্যাসিড খেয়েছি')),
      CareItem('ca', ('Took calcium', 'ক্যালসিয়াম খেয়েছি')),
      CareItem('food', ('Ate one extra meal', 'বাড়তি একবেলা খাবার খেয়েছি')),
      CareItem('rest', ('Rested during the day', 'দিনে কিছুক্ষণ বিশ্রাম নিয়েছি')),
    ],
    symptoms: [
      CareItem('nausea', ('Nausea', 'বমি বমি ভাব')),
      CareItem('back', ('Back pain', 'কোমরে ব্যথা')),
      CareItem('heartburn', ('Heartburn', 'বুক জ্বালা')),
      CareItem('feet', ('Mild swelling of feet', 'পায়ে হালকা ফোলা')),
      CareItem('bleed', ('Vaginal bleeding', 'যোনিপথে রক্তপাত'), urgent: true),
      CareItem('headv', ('Severe headache and blurred vision', 'তীব্র মাথাব্যথা ও ঝাপসা দেখা'), urgent: true),
      CareItem('fits', ('Fits or fainting', 'খিঁচুনি বা অজ্ঞান হওয়া'), urgent: true),
      CareItem('belly', ('Severe belly pain', 'পেটে তীব্র ব্যথা'), urgent: true),
      CareItem('water', ('Waters breaking early', 'প্রসবের আগেই পানি ভাঙা'), urgent: true),
      CareItem('move', ('Baby moving less', 'বাচ্চার নড়াচড়া কমে যাওয়া'), urgent: true),
      CareItem('fever', ('High fever', 'বেশি জ্বর'), urgent: true),
      CareItem('face', ('Sudden swelling of face or hands', 'মুখ বা হাত হঠাৎ ফুলে যাওয়া'), urgent: true),
      CareItem('breath', ('Difficulty breathing', 'শ্বাসকষ্ট'), urgent: true),
    ],
    tests: ['hb', 'urine', 'ogtt', 'usg', 'bgroup'],
    danger: CareCard(('Danger signs: go to hospital without delay', 'বিপদচিহ্ন: দেরি না করে হাসপাতালে যান'), [
      ('Vaginal bleeding', 'যোনিপথে রক্তপাত'),
      ('Fits or fainting', 'খিঁচুনি বা অজ্ঞান হওয়া'),
      ('Severe headache or blurred vision', 'তীব্র মাথাব্যথা, চোখে ঝাপসা দেখা'),
      ('High fever', 'বেশি জ্বর'),
      ('Severe belly pain', 'পেটে তীব্র ব্যথা'),
      ('Difficulty breathing', 'শ্বাসকষ্ট'),
      ('Sudden swelling of face, hands or feet', 'মুখ, হাত বা পা হঠাৎ ফুলে যাওয়া'),
      ('Waters breaking before labour', 'প্রসবের আগেই পানি ভাঙা'),
      ('Baby moving less or not at all', 'বাচ্চার নড়াচড়া কমে যাওয়া বা বন্ধ হওয়া'),
    ], openByDefault: true),
    learn: CareCard(('Why count baby’s movements', 'বাচ্চার নড়াচড়া কেন গুনবেন'), [
      ('From about 28 weeks your baby has its own pattern of movements. Get to know it.', 'প্রায় ২৮ সপ্তাহ থেকে বাচ্চার নড়াচড়ার একটা নিজস্ব ধরন তৈরি হয়। নিজের বাচ্চার ধরন চিনে রাখুন।'),
      ('If movements feel less, do not wait until the next day; contact your doctor or hospital now.', 'নড়াচড়া কম মনে হলে পরদিনের অপেক্ষা করবেন না, এখনই ডাক্তার বা হাসপাতালে জানান।'),
      ('Tell your doctor if BP is 140/90 or higher. If it is 160/110 or higher, do it now.', 'প্রেসার ১৪০/৯০ বা বেশি হলে ডাক্তারকে জানান। ১৬০/১১০ বা বেশি হলে এখনই।'),
    ]),
  ),
  'heart': ConditionContent(
    habits: [
      CareItem('walk', ('Walked as my doctor advised', 'ডাক্তারের বলা মতো হেঁটেছি')),
      CareItem('salt', ('Ate less salt', 'লবণ কম খেয়েছি')),
      CareItem('tob', ('No tobacco or jorda', 'তামাক বা জর্দা খাইনি')),
      CareItem('wt', ('Weighed myself this morning', 'সকালে ওজন মেপেছি')),
    ],
    symptoms: [
      CareItem('tired', ('Tiredness', 'ক্লান্তি')),
      CareItem('swell', ('Swollen feet', 'পা ফোলা')),
      CareItem('palp', ('Racing heartbeat', 'বুক ধড়ফড়')),
      CareItem('flat', ('Breathless lying flat', 'শুয়ে থাকলে শ্বাসকষ্ট')),
      CareItem('chest', ('Chest pain or pressure', 'বুকে ব্যথা বা চাপ'), urgent: true),
      CareItem('breath', ('Sudden severe breathlessness', 'হঠাৎ তীব্র শ্বাসকষ্ট'), urgent: true),
      CareItem('faint', ('Fainting', 'অজ্ঞান হয়ে যাওয়া'), urgent: true),
      CareItem('sweat', ('Sweating with chest pain', 'বুকে ব্যথার সাথে ঘাম'), urgent: true),
    ],
    tests: ['lipid', 'ecg', 'echo', 'kidney'],
    danger: CareCard(('When to call 999 now', 'কখন এখনই ৯৯৯'), [
      ('Chest pain or pressure lasting more than 5 minutes', 'বুকে ব্যথা বা চাপ ৫ মিনিটের বেশি থাকলে'),
      ('Pain spreading to the arm, jaw, neck or back', 'ব্যথা হাত, চোয়াল, ঘাড় বা পিঠে ছড়িয়ে গেলে'),
      ('With cold sweat, vomiting or dizziness', 'সাথে ঠান্ডা ঘাম, বমি বা মাথা ঘোরা'),
      ('Sudden severe breathlessness or fainting', 'হঠাৎ তীব্র শ্বাসকষ্ট বা অজ্ঞান হওয়া'),
    ]),
    learn: CareCard(('Why weigh yourself daily', 'রোজ ওজন কেন মাপবেন'), [
      ('If your doctor asks, weigh yourself at the same time daily: in the morning after using the toilet, before breakfast.', 'ডাক্তার বললে প্রতিদিন একই সময়ে ওজন মাপুন: সকালে প্রস্রাবের পর, নাস্তার আগে।'),
      ('Sudden weight gain can mean fluid build-up. Tell your doctor if it rises more than the limit they gave.', 'হঠাৎ ওজন বাড়া শরীরে পানি জমার লক্ষণ হতে পারে। ডাক্তারের দেওয়া সীমার বেশি বাড়লে জানান।'),
    ]),
  ),
  'kidney': ConditionContent(
    habits: [
      CareItem('nsaid', ('No painkillers without asking my doctor', 'ডাক্তারকে না জিজ্ঞেস করে ব্যথার ওষুধ খাইনি')),
      CareItem('salt', ('Ate less salt', 'লবণ কম খেয়েছি')),
      CareItem('fluid', ('Drank the amount my doctor said', 'ডাক্তারের বলা মাপে পানি খেয়েছি')),
    ],
    symptoms: [
      CareItem('swell', ('Swollen feet or face', 'পা বা মুখ ফোলা')),
      CareItem('urine', ('Passing less urine', 'প্রস্রাব কম হচ্ছে')),
      CareItem('foam', ('Foamy urine', 'প্রস্রাবে ফেনা')),
      CareItem('itch', ('Itching', 'চুলকানি')),
      CareItem('tired', ('Tiredness', 'ক্লান্তি')),
      CareItem('appetite', ('Poor appetite', 'খেতে ইচ্ছা করে না')),
      CareItem('breath', ('Shortness of breath', 'শ্বাসকষ্ট'), urgent: true),
      CareItem('confuse', ('Feeling confused', 'বিভ্রান্ত লাগা'), urgent: true),
      CareItem('nourine', ('Hardly passing urine', 'প্রায় প্রস্রাব হচ্ছে না'), urgent: true),
    ],
    tests: ['kidney', 'egfr', 'potassium', 'urine', 'hb'],
    danger: CareCard(('When to go to hospital', 'কখন হাসপাতালে যাবেন'), [
      ('Urine suddenly drops a lot or stops', 'প্রস্রাব হঠাৎ অনেক কমে গেলে বা বন্ধ হলে'),
      ('Heavy swelling or shortness of breath', 'শরীর খুব ফুলে গেলে বা শ্বাসকষ্ট হলে'),
      ('Confusion, severe drowsiness or chest pain', 'বিভ্রান্তি, খুব ঝিমুনি বা বুকে ব্যথা হলে'),
    ]),
    learn: CareCard(('Protecting your kidneys', 'কিডনি বাঁচাতে'), [
      ('Painkillers such as ibuprofen or diclofenac can harm the kidneys. Ask your doctor first.', 'আইবুপ্রোফেন, ডাইক্লোফেনাকের মতো ব্যথার ওষুধ কিডনির ক্ষতি করতে পারে। ডাক্তারকে না জিজ্ঞেস করে খাবেন না।'),
      ('Keeping BP and sugar under control protects the kidneys.', 'প্রেসার ও সুগার নিয়ন্ত্রণে রাখলে কিডনি ভালো থাকে।'),
      ('Follow your doctor on how much fluid to drink.', 'কতটুকু পানি খাবেন, ডাক্তারের কথা মানুন।'),
    ]),
  ),
  'asthma': ConditionContent(
    habits: [
      CareItem('prev', ('Used my preventer inhaler', 'প্রতিরোধক ইনহেলার নিয়েছি')),
      CareItem('dust', ('Avoided dust and smoke', 'ধুলা ও ধোঁয়া এড়িয়েছি')),
    ],
    symptoms: [
      CareItem('cough', ('Cough', 'কাশি')),
      CareItem('wheeze', ('Wheezing', 'বুকে শাঁ শাঁ শব্দ')),
      CareItem('tight', ('Chest tightness', 'বুকে চাপ')),
      CareItem('night', ('Woke up at night', 'রাতে ঘুম ভেঙেছে')),
      CareItem('speak', ('Cannot finish a sentence', 'পুরো বাক্য বলতে পারছি না'), urgent: true),
      CareItem('blue', ('Blue or grey lips or nails', 'ঠোঁট বা নখ নীল বা ধূসর'), urgent: true),
      CareItem('relief', ('Reliever inhaler not helping', 'উপশমকারী ইনহেলারে কাজ হচ্ছে না'), urgent: true),
    ],
    tests: ['spiro'],
    danger: CareCard(('When to call 999 now', 'কখন এখনই ৯৯৯'), [
      ('Your reliever inhaler is not helping', 'উপশমকারী ইনহেলার নিয়েও কাজ না হলে'),
      ('Too breathless to talk, eat or sleep', 'শ্বাসকষ্টে কথা বলতে, খেতে বা ঘুমাতে না পারলে'),
      ('Lips or nails turn blue or grey', 'ঠোঁট বা নখ নীল বা ধূসর হয়ে গেলে'),
    ]),
    learn: CareCard(('Signs of good control', 'ভালো নিয়ন্ত্রণের লক্ষণ'), [
      ('If you need your reliever on more than 2 days a week, tell your doctor; treatment may need changing.', 'উপশমকারী ইনহেলার সপ্তাহে ২ দিনের বেশি লাগলে ডাক্তারকে জানান, চিকিৎসা বদলানো লাগতে পারে।'),
      ('Keep using your preventer as prescribed, even when you feel well.', 'ভালো লাগলেও প্রতিরোধক ইনহেলার ডাক্তারের কথামতো চালিয়ে যান।'),
      ('Ask your doctor or pharmacist to check your inhaler technique once.', 'ইনহেলার ঠিকমতো নিচ্ছেন কিনা ডাক্তার বা ফার্মাসিস্টকে একবার দেখিয়ে নিন।'),
    ]),
  ),
  'thyroid': ConditionContent(
    habits: [
      CareItem('empty', ('Took my medicine on an empty stomach as advised', 'ডাক্তার যেভাবে বলেছেন, খালি পেটে ওষুধ খেয়েছি')),
    ],
    symptoms: [
      CareItem('tired', ('Tiredness', 'ক্লান্তি')),
      CareItem('weight', ('Sudden weight change', 'ওজন হঠাৎ বাড়া বা কমা')),
      CareItem('palp', ('Racing heartbeat', 'বুক ধড়ফড়')),
      CareItem('cold', ('Feeling very cold', 'খুব শীত লাগা')),
      CareItem('hot', ('Feeling hot, sweating', 'খুব গরম লাগা, ঘাম')),
      CareItem('hair', ('Hair loss', 'চুল পড়া')),
      CareItem('neck', ('Neck swelling', 'গলা ফোলা')),
      CareItem('faint', ('Fainting', 'অজ্ঞান হওয়া'), urgent: true),
      CareItem('chestp', ('Racing heart with chest pain', 'বুক ধড়ফড়ের সাথে বুকে ব্যথা'), urgent: true),
    ],
    tests: ['tsh'],
    danger: CareCard(('When to go to hospital', 'কখন হাসপাতালে যাবেন'), [
      ('Racing heart with chest pain or breathlessness', 'বুক ধড়ফড়ের সাথে বুকে ব্যথা বা শ্বাসকষ্ট'),
      ('Fainting or severe confusion', 'অজ্ঞান হওয়া বা খুব বিভ্রান্ত লাগা'),
    ]),
    learn: CareCard(('Thyroid medicine', 'থাইরয়েডের ওষুধ'), [
      ('Keep the gap between medicine and breakfast that your doctor advised.', 'ওষুধ আর নাস্তার মাঝে ডাক্তার যে বিরতি বলেছেন, তা মানুন।'),
      ('Iron, calcium or antacids taken together can reduce its effect. Ask your doctor how far apart to take them.', 'আয়রন, ক্যালসিয়াম বা গ্যাসের ওষুধ একসাথে খেলে কাজ কমতে পারে। সময়ের ফারাক ডাক্তারকে জিজ্ঞেস করুন।'),
      ('If you plan a pregnancy, tell your doctor early.', 'গর্ভধারণের পরিকল্পনা থাকলে আগেই ডাক্তারকে জানান।'),
    ]),
  ),
  'diabetes': ConditionContent(
    habits: [
      CareItem('walk', ('Walked 30 minutes', '৩০ মিনিট হেঁটেছি')),
      CareItem('sweet', ('No sweets or soft drinks', 'মিষ্টি ও কোমল পানীয় খাইনি')),
      CareItem('foot', ('Checked my feet', 'পায়ের তলা পরীক্ষা করেছি')),
    ],
    // The demo has no diabetes symptom list; low-sugar signs are in the danger card.
    tests: ['hba1c', 'kidney', 'urine', 'lipid', 'eye'],
    danger: CareCard(('If sugar goes too low or too high', 'সুগার কমে বা খুব বেড়ে গেলে'), [
      ('Shaking, sweating, racing heart, sudden hunger or confusion can mean low sugar. Check it and do what your doctor told you now.', 'কাঁপুনি, ঘাম, বুক ধড়ফড়, হঠাৎ খুব ক্ষুধা বা বিভ্রান্তি কম সুগারের লক্ষণ হতে পারে। মেপে দেখুন, ডাক্তার যা করতে বলেছেন এখনই করুন।'),
      ('If the person faints or has a fit, give nothing by mouth and call 999.', 'অজ্ঞান হলে বা খিঁচুনি হলে মুখে কিছু দেবেন না, ৯৯৯ এ কল করুন।'),
      ('Very high sugar with vomiting, great thirst or drowsiness: go to hospital.', 'খুব বেশি সুগারের সাথে বমি, খুব পিপাসা বা ঝিমুনি হলে হাসপাতালে যান।'),
    ]),
  ),
  // Claude's draft for the owner's review (the demo has no cancer texts).
  'cancer': ConditionContent(
    habits: [
      CareItem('water', ('Drank enough water', 'যথেষ্ট পানি খেয়েছি')),
      CareItem('hands', ('Washed hands before eating', 'খাওয়ার আগে হাত ধুয়েছি')),
      CareItem('meal', ('Ate small meals through the day', 'সারা দিনে অল্প অল্প করে খেয়েছি')),
      CareItem('temp', ('Checked my temperature', 'জ্বর মেপেছি')),
    ],
    symptoms: [
      CareItem('nausea', ('Nausea or vomiting', 'বমি বা বমি বমি ভাব')),
      CareItem('tired', ('Very tired', 'খুব ক্লান্তি')),
      CareItem('mouth', ('Mouth sores', 'মুখে ঘা')),
      CareItem('appetite', ('Poor appetite', 'খেতে ইচ্ছা করে না')),
      CareItem('loose', ('Loose motions', 'পাতলা পায়খানা')),
      CareItem('fever', ('Fever or shivering', 'জ্বর বা কাঁপুনি'), urgent: true),
      CareItem('bleed', ('Bleeding or many bruises', 'রক্তপাত বা অনেক কালশিটে'), urgent: true),
      CareItem('breath', ('Shortness of breath', 'শ্বাসকষ্ট'), urgent: true),
      CareItem('drink', ('Cannot keep water down', 'পানিও পেটে থাকছে না'), urgent: true),
    ],
    tests: ['cbc', 'kidney'],
    danger: CareCard(('When to contact the hospital now', 'কখন এখনই হাসপাতালে জানাবেন'), [
      ('Fever of 100.4°F or more, or shivering, during treatment: contact your treatment team or go to hospital now.', 'চিকিৎসা চলার সময় ১০০.৪°F বা বেশি জ্বর বা কাঁপুনি হলে এখনই চিকিৎসা দলকে জানান বা হাসপাতালে যান।'),
      ('Bleeding that does not stop, or many new bruises.', 'রক্তপাত না থামলে বা নতুন অনেক কালশিটে দেখা দিলে।'),
      ('Shortness of breath, chest pain, or vomiting so that you cannot keep water down.', 'শ্বাসকষ্ট, বুকে ব্যথা, বা এমন বমি যে পানিও পেটে থাকছে না।'),
    ], openByDefault: true),
    learn: CareCard(('During chemo', 'কেমো চলার সময়'), [
      ('Keep your treatment team’s phone number with you and share it with family.', 'চিকিৎসা দলের ফোন নম্বর সাথে রাখুন, পরিবারকেও দিন।'),
      ('Ask your doctor before taking any other medicine, including painkillers or herbal remedies.', 'ব্যথার ওষুধ বা কবিরাজি ওষুধসহ অন্য যেকোনো ওষুধের আগে ডাক্তারকে জিজ্ঞেস করুন।'),
      ('Stay away from people with a cough or fever when you can.', 'যতটা পারেন কাশি বা জ্বর আছে এমন মানুষ থেকে দূরে থাকুন।'),
    ]),
  ),
};

ConditionContent contentOf(String code) => conditionContent[code] ?? const ConditionContent();

/// The label of a habit key (a condition's own, the pool, another
/// condition's, or one the user typed).
Bi? habitLabel(String key, String condition, Map<String, String> custom) {
  if (custom.containsKey(key)) return (custom[key]!, custom[key]!);
  for (final h in contentOf(condition).habits) {
    if (h.key == key) return h.text;
  }
  for (final h in habitPool) {
    if (h.key == key) return h.text;
  }
  for (final c in conditionContent.values) {
    for (final h in c.habits) {
      if (h.key == key) return h.text;
    }
  }
  return null;
}
