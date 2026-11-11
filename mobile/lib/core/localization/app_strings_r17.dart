part of 'app_strings.dart';

/// Round 17 strings (voice question, share a notice with family, change
/// history, first-use tips). Part of app_strings.dart, same rule: English
/// and Bengali for every line. Screens read them as `strings.r17`. The tips'
/// texts are Claude's drafts for the owner's review.
class Round17Strings {
  const Round17Strings(this.bn);

  final bool bn;

  String _(String en, String b) => bn ? b : en;

  String n(Object v) {
    final s = v.toString();
    if (!bn) return s;
    const digits = '০১২৩৪৫৬৭৮৯';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => digits[int.parse(m[0]!)]);
  }

  // --- Voice question (B) ---
  String get askByVoice => _('Ask by voice', 'কথা বলে জিজ্ঞেস করুন');
  String get stopListening => _('Stop listening', 'শোনা বন্ধ করুন');
  String get listening => _('Listening… speak now', 'শুনছি… এখন বলুন');
  String get voiceCheck => _('Check the words, then tap Send.', 'লেখাটি দেখে নিন, তারপর পাঠান চাপুন।');
  String get voiceUnavailable => _(
        'Voice typing is not available on this phone. Please type your question.',
        'এই ফোনে কথা বলে লেখা যায় না। অনুগ্রহ করে প্রশ্নটি লিখুন।',
      );
  String get voiceNoPermission => _(
        'Allow the microphone to ask by voice (phone Settings → Apps → Medi-Bela → Permissions).',
        'কথা বলে জিজ্ঞেস করতে মাইক্রোফোনের অনুমতি দিন (ফোনের সেটিংস → অ্যাপ → Medi-Bela → অনুমতি)।',
      );
  String get voiceNotHeard => _('Didn’t catch that. Tap the mic and try again.', 'বুঝতে পারিনি। মাইকে চেপে আবার বলুন।');

  // --- Share a notice (C) ---
  String get shareWithFamily => _('Share with family', 'পরিবারকে পাঠান');
  String sharedWith(int count) => count == 0
      ? _('No one else in your family can get it right now.', 'এই মুহূর্তে পরিবারের আর কেউ এটি পাবেন না।')
      : _('Sent to ${n(count)} family member${count == 1 ? '' : 's'}.', 'পরিবারের ${n(count)} জনকে পাঠানো হয়েছে।');
  String get alreadyShared => _('You already shared this notice with your family.', 'এই নোটিশটি আগেই পরিবারকে পাঠিয়েছেন।');
  String get shareNeedsFamily => _(
        'Join or create a family on the Family tab to share notices.',
        'নোটিশ পাঠাতে পরিবার ট্যাবে একটি পরিবার তৈরি করুন বা যোগ দিন।',
      );
  String get sharedNoticeGone => _('This notice is no longer available.', 'এই নোটিশটি আর নেই।');

  // --- Change history (D) ---
  String get changeHistory => _('Change history', 'পরিবর্তনের তালিকা');
  String get changeHistorySub => _(
        'What a caregiver changed for this member. Newest first.',
        'পরিচর্যাকারী এই সদস্যের জন্য যা বদলেছেন। নতুনগুলো আগে।',
      );
  String get changesForMe => _('Changes made for you', 'আপনার জন্য করা পরিবর্তন');
  String get changesForMeSub => _(
        'What your caregiver changed in your medicines, reminders and health records.',
        'আপনার ওষুধ, রিমাইন্ডার ও স্বাস্থ্য তথ্যে পরিচর্যাকারী যা বদলেছেন।',
      );
  String get noChanges => _('No changes by a caregiver yet.', 'পরিচর্যাকারী এখনো কিছু বদলাননি।');
  String byWhom(String name) => _('by $name', '$name করেছেন');

  /// One line per audit action; unknown ones get a plain "Made a change".
  String changeLabel(String action) => switch (action) {
        'prescription.upload' => _('Uploaded a prescription', 'একটি প্রেসক্রিপশন আপলোড করেছেন'),
        'prescription.confirm' => _('Confirmed a prescription', 'একটি প্রেসক্রিপশন নিশ্চিত করেছেন'),
        'prescription.request_edit' => _('Asked the pharmacist to change a prescription', 'ফার্মাসিস্টকে প্রেসক্রিপশন বদলাতে বলেছেন'),
        'routine.create' => _('Added a medicine', 'একটি ওষুধ যোগ করেছেন'),
        'routine.update' => _('Changed a medicine', 'একটি ওষুধ বদলেছেন'),
        'routine.remove' => _('Removed a medicine', 'একটি ওষুধ সরিয়েছেন'),
        'routine.condition' => _('Set which condition a medicine is for', 'ওষুধটি কোন রোগের জন্য তা ঠিক করেছেন'),
        'dose.give' => _('Marked a dose as given', 'একটি ডোজ খাইয়ে দেওয়া হয়েছে বলে চিহ্নিত করেছেন'),
        'user.easy_mode' => _('Changed easy mode', 'সহজ মোড বদলেছেন'),
        'personal_reminder.create' => _('Set up a reminder', 'একটি রিমাইন্ডার তৈরি করেছেন'),
        'personal_reminder.update' => _('Changed a reminder', 'একটি রিমাইন্ডার বদলেছেন'),
        'personal_reminder.remove' => _('Removed a reminder', 'একটি রিমাইন্ডার সরিয়েছেন'),
        'medicine_box.save' => _('Updated the medicine box', 'ওষুধের বাক্স হালনাগাদ করেছেন'),
        'health_record.create' => _('Added a reading', 'একটি রিডিং যোগ করেছেন'),
        'care.conditions' => _('Changed the care conditions', 'যত্নের রোগগুলো বদলেছেন'),
        'care.limits' => _('Changed the targets and limits', 'লক্ষ্য ও সীমা বদলেছেন'),
        'care.settings' => _('Changed a care plan', 'একটি যত্নের পরিকল্পনা বদলেছেন'),
        'care.log' => _('Added a health log entry', 'স্বাস্থ্য খাতায় একটি তথ্য যোগ করেছেন'),
        'care.log_delete' => _('Removed a health log entry', 'স্বাস্থ্য খাতা থেকে একটি তথ্য সরিয়েছেন'),
        'record.appointment_create' => _('Added a doctor visit', 'একটি ডাক্তার দেখানোর দিন যোগ করেছেন'),
        'record.appointment_update' => _('Changed a doctor visit', 'একটি ডাক্তার দেখানোর দিন বদলেছেন'),
        'record.appointment_delete' => _('Removed a doctor visit', 'একটি ডাক্তার দেখানোর দিন সরিয়েছেন'),
        'record.test_create' => _('Added a test', 'একটি পরীক্ষা যোগ করেছেন'),
        'record.test_update' => _('Changed a test', 'একটি পরীক্ষা বদলেছেন'),
        'record.test_delete' => _('Removed a test', 'একটি পরীক্ষা সরিয়েছেন'),
        'record.prescription_create' => _('Added a prescription to the records', 'রেকর্ডে একটি প্রেসক্রিপশন যোগ করেছেন'),
        'record.prescription_update' => _('Changed a prescription in the records', 'রেকর্ডের একটি প্রেসক্রিপশন বদলেছেন'),
        'record.prescription_delete' => _('Removed a prescription from the records', 'রেকর্ড থেকে একটি প্রেসক্রিপশন সরিয়েছেন'),
        'record.photo_add' => _('Added a report photo', 'একটি রিপোর্টের ছবি যোগ করেছেন'),
        _ => _('Made a change', 'একটি পরিবর্তন করেছেন'),
      };

  // --- First-use tips (E) ---
  String get tipNext => _('Next', 'পরেরটি');
  String get tipSkip => _('Skip', 'বাদ দিন');
  String get tipDone => _('Got it', 'বুঝেছি');
  String tipStep(int i, int of) => _('${n(i)} of ${n(of)}', '${n(of)}-এর ${n(i)}');
  String get showTipsAgain => _('Show tips again', 'টিপস আবার দেখান');
  String get showTipsAgainSub => _('The short tips on the main screens', 'প্রধান পাতাগুলোর ছোট টিপস');
  String get tipsWillShow => _('Tips will show again on each screen.', 'প্রতিটি পাতায় টিপস আবার দেখাবে।');

  List<(String, String)> get tipsHome => [
        (_('Today’s medicine', 'আজকের ওষুধ'),
            _('This card shows the medicine to take now. Tap Taken when you take it, or Later to be reminded again.',
                'এই কার্ডে এখন খাওয়ার ওষুধ দেখাবে। খেলে “খেয়েছি” চাপুন, পরে মনে করাতে “পরে” চাপুন।')),
        (_('Your profile and settings', 'আপনার প্রোফাইল ও সেটিংস'),
            _('Tap your picture at the top for Profile, reminders, language and text size.',
                'উপরে আপনার ছবিতে চাপুন: প্রোফাইল, রিমাইন্ডার, ভাষা ও লেখার আকার।')),
        (_('Add anything with +', '+ দিয়ে সব যোগ করুন'),
            _('The + button at the bottom adds a medicine, a prescription photo, a reading or a reminder.',
                'নিচের + বোতাম দিয়ে ওষুধ, প্রেসক্রিপশনের ছবি, রিডিং বা রিমাইন্ডার যোগ করুন।')),
      ];
  List<(String, String)> get tipsMedicines => [
        (_('Today, My medicines, Prescriptions', 'আজ, আমার ওষুধ, প্রেসক্রিপশন'),
            _('Switch at the top: today’s doses, all your medicines, and your prescriptions.',
                'উপরে বদলান: আজকের ডোজ, আপনার সব ওষুধ আর প্রেসক্রিপশন।')),
        (_('Change a medicine', 'ওষুধ বদলান'),
            _('Open a medicine to change its times or meal timing, or to remove it.',
                'সময় বা খাবারের আগে-পরে বদলাতে, অথবা সরাতে একটি ওষুধ খুলুন।')),
      ];
  List<(String, String)> get tipsFamily => [
        (_('Your family', 'আপনার পরিবার'),
            _('Invite family members to see each other’s medicine status. The family is told when a dose is missed.',
                'একে অন্যের ওষুধের খবর দেখতে পরিবারের সদস্যদের আমন্ত্রণ জানান। ডোজ বাদ গেলে পরিবার খবর পায়।')),
        (_('The caregiver', 'পরিচর্যাকারী'),
            _('The caregiver can add medicines and prescriptions for a member. Every change is listed in the change history.',
                'পরিচর্যাকারী সদস্যের জন্য ওষুধ ও প্রেসক্রিপশন যোগ করতে পারেন। প্রতিটি পরিবর্তন তালিকায় থাকে।')),
      ];
  List<(String, String)> get tipsHealth => [
        (_('Readings and records', 'রিডিং ও রেকর্ড'),
            _('Log your sugar, blood pressure or weight, and keep visits, tests and reports in one place.',
                'সুগার, প্রেসার বা ওজন লিখে রাখুন; ডাক্তার দেখানো, পরীক্ষা আর রিপোর্ট এক জায়গায় রাখুন।')),
        (_('My care', 'আমার যত্ন'),
            _('Each condition you add gets its own page with habits, tests and when to act.',
                'প্রতিটি রোগের আলাদা পাতা থাকে: অভ্যাস, পরীক্ষা আর কখন দ্রুত ব্যবস্থা নিতে হবে।')),
      ];
  List<(String, String)> get tipsReminder => [
        (_('When the reminder rings', 'রিমাইন্ডার বাজলে'),
            _('Tap Taken after you take the medicine. Later rings again in a few minutes; the last ring has only Taken.',
                'ওষুধ খাওয়ার পর “খেয়েছি” চাপুন। “পরে” চাপলে কয়েক মিনিট পর আবার বাজবে; শেষবার শুধু “খেয়েছি” থাকে।')),
      ];
  List<(String, String)> get tipsQuickAdd => [
        (_('What to add', 'কী যোগ করবেন'),
            _('Pick what you want to add. A prescription photo goes to the pharmacist, who turns it into reminders.',
                'যা যোগ করতে চান তা বাছুন। প্রেসক্রিপশনের ছবি ফার্মাসিস্টের কাছে যায়, তিনি রিমাইন্ডার তৈরি করে দেন।')),
      ];
}

extension Round17StringsOf on AppStrings {
  Round17Strings get r17 => identical(this, bnStrings) ? const Round17Strings(true) : const Round17Strings(false);
}
