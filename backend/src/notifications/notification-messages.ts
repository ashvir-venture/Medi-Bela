import { Language } from '@prisma/client';

/**
 * Server-generated notification copy, localized per RECIPIENT.
 *
 * Privacy rule for everything here: push text transits Google's FCM and
 * shows on lock screens, so it never contains medicine names, doses,
 * rejection reasons or any other health detail. It says WHO and WHAT KIND
 * of event; the details live behind authenticated, family-scoped API calls.
 *
 * NOTE: the Bengali strings should be reviewed by a native speaker.
 */
export interface MessageCopy {
  title: string;
  body: string;
}

const clip = (value: string, max: number) =>
  value.length <= max ? value : `${value.slice(0, max - 1).trimEnd()}…`;

/** Things a caregiver can do for a member (see CaregiverAccessService). */
export type CaregiverAction =
  | 'prescription_uploaded'
  | 'prescription_confirmed'
  | 'prescription_edit_requested'
  | 'routine_added'
  | 'routine_updated'
  | 'routine_removed'
  | 'reminder_added'
  | 'reminder_updated'
  | 'reminder_removed'
  | 'medicine_box_updated'
  | 'dose_given'
  | 'easy_mode_on'
  | 'easy_mode_off'
  | 'health_updated';

const CAREGIVER_BODY: Record<CaregiverAction, { en: string; bn: string }> = {
  prescription_uploaded: {
    en: 'Your caregiver uploaded a prescription for you.',
    bn: 'আপনার পরিচর্যাকারী আপনার জন্য একটি প্রেসক্রিপশন আপলোড করেছেন।',
  },
  prescription_confirmed: {
    en: 'Your caregiver confirmed your prescription. Your reminders have started.',
    bn: 'আপনার পরিচর্যাকারী আপনার প্রেসক্রিপশন নিশ্চিত করেছেন। আপনার রিমাইন্ডার শুরু হয়েছে।',
  },
  prescription_edit_requested: {
    en: 'Your caregiver asked the pharmacist to change your prescription.',
    bn: 'আপনার পরিচর্যাকারী ফার্মাসিস্টকে আপনার প্রেসক্রিপশন পরিবর্তন করতে বলেছেন।',
  },
  reminder_added: {
    en: 'Your caregiver set up a reminder for you.',
    bn: 'আপনার পরিচর্যাকারী আপনার জন্য একটি রিমাইন্ডার যোগ করেছেন।',
  },
  reminder_updated: {
    en: 'Your caregiver changed one of your reminders.',
    bn: 'আপনার পরিচর্যাকারী আপনার একটি রিমাইন্ডার বদলেছেন।',
  },
  reminder_removed: {
    en: 'Your caregiver removed one of your reminders.',
    bn: 'আপনার পরিচর্যাকারী আপনার একটি রিমাইন্ডার সরিয়েছেন।',
  },
  medicine_box_updated: {
    en: 'Your caregiver updated your medicine box.',
    bn: 'আপনার পরিচর্যাকারী আপনার ওষুধের বাক্স হালনাগাদ করেছেন।',
  },
  dose_given: {
    en: 'Your caregiver marked your medicine as taken.',
    bn: 'আপনার পরিচর্যাকারী আপনার ওষুধ খাওয়া হয়েছে বলে চিহ্নিত করেছেন।',
  },
  easy_mode_on: {
    en: 'Your caregiver turned on easy mode. You can turn it off in Profile.',
    bn: 'আপনার পরিচর্যাকারী সহজ মোড চালু করেছেন। প্রোফাইল থেকে বন্ধ করতে পারেন।',
  },
  easy_mode_off: {
    en: 'Your caregiver turned off easy mode.',
    bn: 'আপনার পরিচর্যাকারী সহজ মোড বন্ধ করেছেন।',
  },
  health_updated: {
    en: 'Your caregiver updated your health records.',
    bn: 'আপনার পরিচর্যাকারী আপনার স্বাস্থ্যের রেকর্ড হালনাগাদ করেছেন।',
  },
  routine_added: {
    en: 'Your caregiver added a medicine to your routine.',
    bn: 'আপনার পরিচর্যাকারী আপনার রুটিনে একটি ওষুধ যোগ করেছেন।',
  },
  routine_updated: {
    en: 'Your caregiver changed one of your medicines.',
    bn: 'আপনার পরিচর্যাকারী আপনার একটি ওষুধ পরিবর্তন করেছেন।',
  },
  routine_removed: {
    en: 'Your caregiver removed a medicine from your routine.',
    bn: 'আপনার পরিচর্যাকারী আপনার রুটিন থেকে একটি ওষুধ সরিয়েছেন।',
  },
};

export const messages = {
  /** Neutral: never names the medicine (lock screens, shared phones). */
  caregiverAction(lang: Language, action: CaregiverAction): MessageCopy {
    const body = CAREGIVER_BODY[action];
    return lang === Language.BN
      ? { title: 'পরিচর্যাকারীর আপডেট', body: body.bn }
      : { title: 'Update from your caregiver', body: body.en };
  },

  missedDoseFamily(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? {
          title: 'ওষুধ মিস হয়েছে',
          body: `${name} নির্ধারিত সময়ে একটি ওষুধ খাননি। অনুগ্রহ করে খোঁজ নিন।`,
        }
      : {
          title: 'Missed medicine',
          body: `${name} missed a scheduled medicine. Please check in with them.`,
        };
  },

  /** To the caregiver on a test reminder's third day. Names the member, not the test. */
  testPendingCaregiver(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? {
          title: 'পরীক্ষা বাকি',
          body: `${name} দুই দিন ধরে একটি পরীক্ষা করাননি। অনুগ্রহ করে খোঁজ নিন।`,
        }
      : {
          title: 'Test not done',
          body: `${name} has not done a test for two days. Please check in with them.`,
        };
  },

  /** To the caregiver who set up a reminder, when the member pressed Later on it. */
  personalReminderLater(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? { title: 'রিমাইন্ডার পিছিয়েছে', body: `${name} আপনার দেওয়া একটি রিমাইন্ডার "পরে" করেছেন।` }
      : { title: 'Reminder put off', body: `${name} pressed Later on a reminder you set up.` };
  },

  /** To the caregiver: a member ran out of a medicine and pressed Ignore. No medicine name. */
  medicineBoxEmptyCaregiver(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? { title: 'ওষুধ শেষ', body: `${name}-এর একটি ওষুধ শেষ হয়ে গেছে। অনুগ্রহ করে খোঁজ নিন।` }
      : { title: 'Medicine ran out', body: `${name} has run out of a medicine. Please check in with them.` };
  },

  /** To the caregiver: a reading is outside the doctor's limits. Never the value. */
  readingOutOfRangeCaregiver(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? { title: 'স্বাস্থ্যের রিডিং', body: `${name}-এর একটি রিডিং ডাক্তারের দেওয়া সীমার বাইরে। অনুগ্রহ করে খোঁজ নিন।` }
      : { title: 'Health reading', body: `A reading of ${name}'s is outside the doctor's limits. Please check in with them.` };
  },

  /** To the caregiver: the member pressed "Alert family" on an emergency sheet. */
  helpAlertCaregiver(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? { title: 'জরুরি: খোঁজ নিন', body: `${name} অ্যাপ থেকে জরুরি খবর পাঠিয়েছেন। এখনই ফোন করুন।` }
      : { title: 'Urgent: please call', body: `${name} sent an urgent alert from the app. Please call them now.` };
  },

  /** To the caregiver: a member's prescription is ready to confirm. */
  memberPrescriptionReady(lang: Language, memberName: string): MessageCopy {
    const name = clip(memberName, 40);
    return lang === Language.BN
      ? { title: 'প্রেসক্রিপশন প্রস্তুত', body: `${name}-এর একটি প্রেসক্রিপশন নিশ্চিত করার জন্য প্রস্তুত।` }
      : { title: 'Prescription ready', body: `A prescription for ${name} is ready to confirm.` };
  },

  /** Backstop for the app's own second reminder. Neutral: shared phones and lock screens. */
  medicineReminderBackstop(lang: Language): MessageCopy {
    return lang === Language.BN
      ? {
          title: 'ওষুধ খাওয়ার সময়',
          body: 'আপনার একটি ওষুধ খাওয়ার সময় হয়েছে। নেওয়া হলে অ্যাপে চিহ্নিত করুন।',
        }
      : {
          title: 'Time for your medicine',
          body: 'A medicine is due. Open the app to mark it taken.',
        };
  },

  prescriptionCompleted(lang: Language): MessageCopy {
    return lang === Language.BN
      ? {
          title: 'প্রেসক্রিপশন প্রস্তুত',
          body: 'আপনার প্রেসক্রিপশনের পর্যালোচনা সম্পন্ন হয়েছে। আপনার ওষুধের রুটিন এখন প্রস্তুত।',
        }
      : {
          title: 'Prescription reviewed',
          body: 'Your prescription has been reviewed and your medicine routine is ready.',
        };
  },

  /** The pharmacist prepared the routine; reminders start once the user confirms it. */
  prescriptionReadyToConfirm(lang: Language): MessageCopy {
    return lang === Language.BN
      ? {
          title: 'প্রেসক্রিপশন প্রস্তুত',
          body: 'ফার্মাসিস্ট আপনার ওষুধের রুটিন তৈরি করেছেন। রিমাইন্ডার শুরু করতে অ্যাপে নিশ্চিত করুন।',
        }
      : {
          title: 'Prescription ready',
          body: 'Your pharmacist prepared your medicine routine. Open the app to confirm it and start reminders.',
        };
  },

  prescriptionRejected(lang: Language): MessageCopy {
    return lang === Language.BN
      ? {
          title: 'প্রেসক্রিপশনের হালনাগাদ',
          body: 'আপনার প্রেসক্রিপশনটি প্রক্রিয়া করা যায়নি। বিস্তারিত দেখতে অ্যাপ খুলুন।',
        }
      : {
          title: 'Prescription update',
          body: 'Your prescription could not be processed. Open the app for details.',
        };
  },

  familyInvitation(lang: Language, inviterName: string): MessageCopy {
    const name = clip(inviterName, 40);
    return lang === Language.BN
      ? {
          title: 'পরিবারে যোগদানের আমন্ত্রণ',
          body: `${name} আপনাকে তাঁর পরিবারে যোগ দিতে আমন্ত্রণ জানিয়েছেন।`,
        }
      : {
          title: 'Family invitation',
          body: `${name} invited you to join their family.`,
        };
  },

  /** To the member a caregiver removed. Neutral: no names. */
  familyRemoved(lang: Language): MessageCopy {
    return lang === Language.BN
      ? { title: 'পরিবারের আপডেট', body: 'আপনাকে পরিবার থেকে সরিয়ে দেওয়া হয়েছে।' }
      : { title: 'Family update', body: 'You were removed from the family.' };
  },

  /** To every remaining member after a caregiver handover (the role decides who gets the caregiver tools). */
  caregiverChanged(lang: Language, caregiverName: string): MessageCopy {
    const name = clip(caregiverName, 40);
    return lang === Language.BN
      ? { title: 'পরিবারের আপডেট', body: `${name} এখন পরিবারের পরিচর্যাকারী।` }
      : { title: 'Family update', body: `${name} is now the family caregiver.` };
  },

  /** Round 17: a family member shared a notice. Notice titles are public text. */
  noticeShared(lang: Language, sharerName: string, noticeTitle: string): MessageCopy {
    const name = clip(sharerName, 40);
    const title = clip(noticeTitle, 80);
    return lang === Language.BN
      ? { title: `${name} একটি নোটিশ শেয়ার করেছেন`, body: title }
      : { title: `${name} shared a notice`, body: title };
  },

  /** Notices are public, admin-authored text — safe to show as written. */
  notice(title: string, content: string): MessageCopy {
    return { title: clip(title, 80), body: clip(content.replace(/\s+/g, ' ').trim(), 120) };
  },
};
