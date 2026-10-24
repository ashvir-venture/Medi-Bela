import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';

/// All text for the Diabetes Tracker (English + Bangla).
///
/// Kept in its own file on purpose so the shared `AppStrings` table is not
/// touched. Reads the same language setting as the rest of the app.
class DiabetesStrings {
  const DiabetesStrings({
    required this.title,
    required this.homeSubtitle,
    required this.whatToLog,
    required this.disclaimer,
    required this.bloodSugar,
    required this.bloodSugarSub,
    required this.bloodPressure,
    required this.bloodPressureSub,
    required this.insulin,
    required this.insulinSub,
    required this.weight,
    required this.weightSub,
    required this.hba1c,
    required this.hba1cSub,
    required this.reading,
    required this.whenMeasured,
    required this.fasting,
    required this.beforeMeal,
    required this.afterMeal,
    required this.bedtime,
    required this.random,
    required this.systolic,
    required this.diastolic,
    required this.pulseOptional,
    required this.dose,
    required this.insulinType,
    required this.rapidActing,
    required this.shortActing,
    required this.intermediate,
    required this.longActing,
    required this.mixed,
    required this.takenAt,
    required this.beforeBreakfast,
    required this.beforeLunch,
    required this.beforeDinner,
    required this.other,
    required this.weightKg,
    required this.hba1cPercent,
    required this.dateTime,
    required this.notesOptional,
    required this.submit,
    required this.cancel,
    required this.errEnterValue,
    required this.errValidNumber,
    required this.errUnusual,
    required this.errChooseOption,
    required this.comingSoonTitle,
    required this.comingSoonBody,
    required this.ok,
    required this.am,
    required this.pm,
  });

  final String title;
  final String homeSubtitle;
  final String whatToLog;
  final String disclaimer;

  final String bloodSugar;
  final String bloodSugarSub;
  final String bloodPressure;
  final String bloodPressureSub;
  final String insulin;
  final String insulinSub;
  final String weight;
  final String weightSub;
  final String hba1c;
  final String hba1cSub;

  final String reading;
  final String whenMeasured;
  final String fasting;
  final String beforeMeal;
  final String afterMeal;
  final String bedtime;
  final String random;
  final String systolic;
  final String diastolic;
  final String pulseOptional;
  final String dose;
  final String insulinType;
  final String rapidActing;
  final String shortActing;
  final String intermediate;
  final String longActing;
  final String mixed;
  final String takenAt;
  final String beforeBreakfast;
  final String beforeLunch;
  final String beforeDinner;
  final String other;
  final String weightKg;
  final String hba1cPercent;
  final String dateTime;
  final String notesOptional;
  final String submit;
  final String cancel;

  final String errEnterValue;
  final String errValidNumber;
  final String errUnusual;
  final String errChooseOption;

  final String comingSoonTitle;
  final String comingSoonBody;
  final String ok;
  final String am;
  final String pm;
}

const DiabetesStrings diabetesEn = DiabetesStrings(
  title: 'Diabetes Tracker',
  homeSubtitle: 'Log sugar, blood pressure & insulin',
  whatToLog: 'What would you like to log?',
  disclaimer:
      'For record keeping only. This does not replace advice from your doctor.',
  bloodSugar: 'Blood Sugar',
  bloodSugarSub: 'Fasting, after meal, random',
  bloodPressure: 'Blood Pressure',
  bloodPressureSub: 'Systolic, diastolic, pulse',
  insulin: 'Insulin',
  insulinSub: 'Dose and type',
  weight: 'Weight',
  weightSub: 'Body weight in kg',
  hba1c: 'HbA1c',
  hba1cSub: '3-month average sugar test',
  reading: 'Reading',
  whenMeasured: 'When measured',
  fasting: 'Fasting',
  beforeMeal: 'Before meal',
  afterMeal: '2 hours after meal',
  bedtime: 'Bedtime',
  random: 'Random',
  systolic: 'Systolic (mmHg)',
  diastolic: 'Diastolic (mmHg)',
  pulseOptional: 'Pulse (bpm) - optional',
  dose: 'Dose (units)',
  insulinType: 'Insulin type',
  rapidActing: 'Rapid-acting',
  shortActing: 'Short-acting',
  intermediate: 'Intermediate',
  longActing: 'Long-acting',
  mixed: 'Mixed',
  takenAt: 'Taken at',
  beforeBreakfast: 'Before breakfast',
  beforeLunch: 'Before lunch',
  beforeDinner: 'Before dinner',
  other: 'Other',
  weightKg: 'Weight (kg)',
  hba1cPercent: 'HbA1c (%)',
  dateTime: 'Date & time',
  notesOptional: 'Notes - optional',
  submit: 'Submit',
  cancel: 'Cancel',
  errEnterValue: 'Please enter a value',
  errValidNumber: 'Enter a valid number',
  errUnusual: 'This value looks unusual. Please check it.',
  errChooseOption: 'Please choose an option',
  comingSoonTitle: 'Coming soon',
  comingSoonBody:
      'Thanks for your interest! Diabetes tracking is still in progress and will be available soon. The details you entered were not saved.',
  ok: 'OK',
  am: 'AM',
  pm: 'PM',
);

const DiabetesStrings diabetesBn = DiabetesStrings(
  title: 'ডায়াবেটিস ট্র্যাকার',
  homeSubtitle: 'সুগার, ব্লাড প্রেশার ও ইনসুলিন লগ করুন',
  whatToLog: 'আপনি কী লগ করতে চান?',
  disclaimer: 'শুধু রেকর্ড রাখার জন্য। এটি ডাক্তারের পরামর্শের বিকল্প নয়।',
  bloodSugar: 'ব্লাড সুগার',
  bloodSugarSub: 'খালি পেটে, খাবারের পরে, যেকোনো সময়',
  bloodPressure: 'ব্লাড প্রেশার',
  bloodPressureSub: 'সিস্টোলিক, ডায়াস্টোলিক, পালস',
  insulin: 'ইনসুলিন',
  insulinSub: 'ডোজ ও ধরন',
  weight: 'ওজন',
  weightSub: 'শরীরের ওজন (কেজি)',
  hba1c: 'এইচবিএওয়ানসি (HbA1c)',
  hba1cSub: '৩ মাসের গড় সুগার পরীক্ষা',
  reading: 'রিডিং',
  whenMeasured: 'কখন মাপা হয়েছে',
  fasting: 'খালি পেটে',
  beforeMeal: 'খাবারের আগে',
  afterMeal: 'খাবারের ২ ঘণ্টা পরে',
  bedtime: 'ঘুমানোর আগে',
  random: 'যেকোনো সময়',
  systolic: 'সিস্টোলিক (mmHg)',
  diastolic: 'ডায়াস্টোলিক (mmHg)',
  pulseOptional: 'পালস (bpm) - ঐচ্ছিক',
  dose: 'ডোজ (ইউনিট)',
  insulinType: 'ইনসুলিনের ধরন',
  rapidActing: 'র‍্যাপিড-অ্যাক্টিং',
  shortActing: 'শর্ট-অ্যাক্টিং',
  intermediate: 'ইন্টারমিডিয়েট',
  longActing: 'লং-অ্যাক্টিং',
  mixed: 'মিক্সড',
  takenAt: 'কখন নেওয়া হয়েছে',
  beforeBreakfast: 'সকালের নাস্তার আগে',
  beforeLunch: 'দুপুরের খাবারের আগে',
  beforeDinner: 'রাতের খাবারের আগে',
  other: 'অন্যান্য',
  weightKg: 'ওজন (কেজি)',
  hba1cPercent: 'HbA1c (%)',
  dateTime: 'তারিখ ও সময়',
  notesOptional: 'নোট - ঐচ্ছিক',
  submit: 'জমা দিন',
  cancel: 'বাতিল',
  errEnterValue: 'একটি মান লিখুন',
  errValidNumber: 'সঠিক সংখ্যা লিখুন',
  errUnusual: 'মানটি অস্বাভাবিক মনে হচ্ছে। অনুগ্রহ করে যাচাই করুন।',
  errChooseOption: 'একটি অপশন বাছাই করুন',
  comingSoonTitle: 'শীঘ্রই আসছে',
  comingSoonBody:
      'আপনার আগ্রহের জন্য ধন্যবাদ! ডায়াবেটিস ট্র্যাকিং ফিচারটি এখনো তৈরি হচ্ছে, শীঘ্রই আসছে। আপনার দেওয়া তথ্য সংরক্ষণ করা হয়নি।',
  ok: 'ঠিক আছে',
  am: 'AM',
  pm: 'PM',
);

final diabetesStringsProvider = Provider<DiabetesStrings>((ref) {
  final locale = ref.watch(localeControllerProvider);
  return locale.languageCode == 'bn' ? diabetesBn : diabetesEn;
});
