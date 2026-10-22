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

export const messages = {
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

  /** Notices are public, admin-authored text — safe to show as written. */
  notice(title: string, content: string): MessageCopy {
    return { title: clip(title, 80), body: clip(content.replace(/\s+/g, ' ').trim(), 120) };
  },
};
