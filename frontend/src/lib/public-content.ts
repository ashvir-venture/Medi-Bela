// Generated from docs/content/public-pages.json by docs/content/build_public_content.py. Do not edit.

export type PublicLang = 'en' | 'bn';

export interface PublicContent {
  privacyTitle: string;
  privacySections: { heading: string; lines: string[] }[];
  supportTitle: string;
  howToHeading: string;
  howTo: { title: string; steps: string[] }[];
  faqHeading: string;
  faq: { q: string; a: string }[];
  contactHeading: string;
  callLabel: string;
  whatsappLabel: string;
  copyLabel: string;
  copiedLabel: string;
  aboutTitle: string;
  missionLabel: string;
  mission: string;
  visionLabel: string;
  vision: string;
  goalsHeading: string;
  goals: string[];
  teamHeading: string;
  facebookLabel: string;
  team: { photo: string; name: string; field: string; university: string; facebook: string }[];
}

export const PUBLIC_CONTENT: Record<PublicLang, PublicContent> = {
  "en": {
    "privacyTitle": "Privacy & terms",
    "privacySections": [
      {
        "heading": "Your data and privacy",
        "lines": [
          "Your data is stored under strong monitoring and a strict access policy.",
          "Your data is used for medical purposes only.",
          "No third party gets access to your health data for promotion or research.",
          "Only you, the family members you allow, and the Medi-Bela pharmacists who check your prescription can see your medicine information.",
          "Trusted service providers that run parts of the app (photo storage, notifications, AI answers, SMS) process data only to provide those services.",
          "Your password is stored encrypted; no one at Medi-Bela can see it.",
          "You can hide yourself from family, deactivate, or delete your account at any time from Settings. Deleting erases your personal details."
        ]
      },
      {
        "heading": "Terms of use and medical note",
        "lines": [
          "Medi-Bela is not a replacement for your regular doctor or health service.",
          "The AI assistant gives general health information only. It does not diagnose or prescribe.",
          "Always take medicines as your doctor advised. If something looks wrong, ask your doctor or pharmacist first.",
          "In an emergency, call 999 or go to the nearest hospital."
        ]
      }
    ],
    "supportTitle": "Support",
    "howToHeading": "How to use the app",
    "howTo": [
      {
        "title": "Upload a prescription and confirm it",
        "steps": [
          "On Home, tap Upload Prescription and take a clear photo of the whole page.",
          "A pharmacist checks it. When it shows Review and confirm, open it.",
          "Check the dose times, then tap Confirm and start reminders."
        ]
      },
      {
        "title": "Take or snooze a dose",
        "steps": [
          "When the reminder rings, tap Done after taking the medicines.",
          "Not now? Tap Later (30 min). It reminds you again, twice at most.",
          "You can also mark doses in Medicines → Today."
        ]
      },
      {
        "title": "Add your own medicine",
        "steps": [
          "Open Medicines → My medicines.",
          "Tap Add a medicine, fill in the name and times, and save."
        ]
      },
      {
        "title": "Create a family and invite",
        "steps": [
          "Open Family and tap Create a family.",
          "Tap Invite a member and enter their phone number.",
          "The person who invites becomes the family's caregiver."
        ]
      },
      {
        "title": "Hide from family",
        "steps": [
          "Open Profile → Settings → Privacy & family.",
          "Turn on Hide from family."
        ]
      },
      {
        "title": "Reminder check",
        "steps": [
          "Open Profile → Settings → Reminder check.",
          "Fix every item that needs attention: notifications, Alarms & reminders, Battery optimization."
        ]
      },
      {
        "title": "Change language and theme",
        "steps": [
          "Open Profile → Settings → Appearance & language.",
          "Choose English or বাংলা, and System, Light or Dark."
        ]
      }
    ],
    "faqHeading": "Questions",
    "faq": [
      {
        "q": "My reminders don't ring.",
        "a": "Open Profile → Settings → Reminder check. Allow notifications and Alarms & reminders, and set Battery optimization to not restrict Medi-Bela. On some phones also allow Autostart."
      },
      {
        "q": "My prescription was rejected.",
        "a": "Open it to read the pharmacist's note, then tap Re-upload and send a clearer photo."
      },
      {
        "q": "A dose time is wrong.",
        "a": "Open Medicines → My medicines, tap the medicine and change its times."
      },
      {
        "q": "My family can't see me.",
        "a": "Hide from family is on. Turn it off in Profile → Settings → Privacy & family."
      },
      {
        "q": "I forgot my password.",
        "a": "On the sign-in screen tap Forgot password? and enter the code we send to your phone by SMS."
      },
      {
        "q": "Deactivate or delete?",
        "a": "Deactivate pauses your account: reminders stop, and you come back any time by signing in. Delete erases your personal details for good."
      },
      {
        "q": "Is my data safe?",
        "a": "Yes. Read Privacy & terms to see who can see what."
      }
    ],
    "contactHeading": "Contact us",
    "callLabel": "Call",
    "whatsappLabel": "WhatsApp",
    "copyLabel": "Copy",
    "copiedLabel": "Number copied",
    "aboutTitle": "About us",
    "missionLabel": "Mission",
    "mission": "Care for your family, even from far away.",
    "visionLabel": "Vision",
    "vision": "Health, On Time",
    "goalsHeading": "What we work for",
    "goals": [
      "Turn every pharmacist-checked prescription into reminders that ring on time.",
      "Let families know when a dose is missed, so no one has to worry alone.",
      "Keep health records, notices and trusted health information in one simple app, in Bangla and English."
    ],
    "teamHeading": "Team",
    "facebookLabel": "Facebook",
    "team": [
      {
        "photo": "ashraful.jpg",
        "name": "Ashraful Alam",
        "field": "Software Engineering",
        "university": "Shahjalal University of Science and Technology, Sylhet",
        "facebook": "https://www.facebook.com/ashraful.alam.931253"
      },
      {
        "photo": "tanvir.jpg",
        "name": "Tanvir Hossain",
        "field": "Chemical Engineering",
        "university": "Rajshahi University of Engineering and Technology, Rajshahi",
        "facebook": "https://www.facebook.com/aztanvirhossain"
      }
    ]
  },
  "bn": {
    "privacyTitle": "গোপনীয়তা ও শর্তাবলি",
    "privacySections": [
      {
        "heading": "আপনার তথ্য ও গোপনীয়তা",
        "lines": [
          "আপনার তথ্য কঠোর নজরদারি ও কড়া প্রবেশাধিকার নীতির অধীনে সংরক্ষিত থাকে।",
          "আপনার তথ্য শুধু চিকিৎসা-সংক্রান্ত কাজে ব্যবহার করা হয়।",
          "কোনো তৃতীয় পক্ষকে প্রচার বা গবেষণার জন্য আপনার স্বাস্থ্য-তথ্য দেওয়া হয় না।",
          "শুধু আপনি, আপনার অনুমতি দেওয়া পরিবারের সদস্যরা এবং প্রেসক্রিপশন যাচাইকারী মেডি-বেলা ফার্মাসিস্টরাই আপনার ওষুধের তথ্য দেখতে পারেন।",
          "অ্যাপের কিছু অংশ চালাতে বিশ্বস্ত সেবাদাতারা (ছবি সংরক্ষণ, নোটিফিকেশন, এআই উত্তর, এসএমএস) শুধু সেই সেবা দিতেই তথ্য ব্যবহার করে।",
          "আপনার পাসওয়ার্ড এনক্রিপ্ট করে রাখা হয়; মেডি-বেলার কেউ তা দেখতে পারে না।",
          "সেটিংস থেকে যেকোনো সময় পরিবার থেকে লুকাতে, অ্যাকাউন্ট সাময়িক বন্ধ বা মুছে ফেলতে পারেন। মুছে ফেললে আপনার ব্যক্তিগত তথ্য মুছে যায়।"
        ]
      },
      {
        "heading": "ব্যবহারের শর্ত ও চিকিৎসা-সংক্রান্ত নোট",
        "lines": [
          "মেডি-বেলা আপনার নিয়মিত ডাক্তার বা স্বাস্থ্যসেবার বিকল্প নয়।",
          "এআই সহকারী শুধু সাধারণ স্বাস্থ্য-তথ্য দেয়; এটি রোগ নির্ণয় বা ওষুধ নির্ধারণ করে না।",
          "সবসময় ডাক্তারের পরামর্শ অনুযায়ী ওষুধ খান। কিছু ভুল মনে হলে আগে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।",
          "জরুরি অবস্থায় ৯৯৯-এ কল করুন বা নিকটস্থ হাসপাতালে যান।"
        ]
      }
    ],
    "supportTitle": "সাহায্য",
    "howToHeading": "অ্যাপ যেভাবে ব্যবহার করবেন",
    "howTo": [
      {
        "title": "প্রেসক্রিপশন আপলোড ও নিশ্চিত করা",
        "steps": [
          "হোমে প্রেসক্রিপশন আপলোড চাপুন এবং পুরো পাতার পরিষ্কার ছবি তুলুন।",
          "একজন ফার্মাসিস্ট এটি যাচাই করবেন। যখন দেখে নিশ্চিত করুন দেখাবে, সেটি খুলুন।",
          "ওষুধ খাওয়ার সময়গুলো দেখে নিন, তারপর নিশ্চিত করুন ও রিমাইন্ডার শুরু করুন চাপুন।"
        ]
      },
      {
        "title": "ডোজ নেওয়া বা পরে মনে করানো",
        "steps": [
          "রিমাইন্ডার বাজলে ওষুধ খাওয়ার পর নিয়েছি চাপুন।",
          "এখন নয়? পরে (৩০ মিনিট) চাপুন। আবার মনে করানো হবে, সর্বোচ্চ দুইবার।",
          "ওষুধ → আজ থেকেও ডোজ চিহ্নিত করতে পারেন।"
        ]
      },
      {
        "title": "নিজের ওষুধ যোগ করা",
        "steps": [
          "ওষুধ → আমার ওষুধ খুলুন।",
          "ওষুধ যোগ করুন চাপুন, নাম ও সময় দিয়ে সংরক্ষণ করুন।"
        ]
      },
      {
        "title": "পরিবার তৈরি ও আমন্ত্রণ",
        "steps": [
          "পরিবার খুলে পরিবার তৈরি করুন চাপুন।",
          "সদস্য আমন্ত্রণ করুন চাপুন এবং তাঁর ফোন নম্বর দিন।",
          "যিনি আমন্ত্রণ জানান তিনি পরিবারের পরিচর্যাকারী হন।"
        ]
      },
      {
        "title": "পরিবার থেকে লুকানো",
        "steps": [
          "প্রোফাইল → সেটিংস → গোপনীয়তা ও পরিবার খুলুন।",
          "পরিবার থেকে লুকান চালু করুন।"
        ]
      },
      {
        "title": "রিমাইন্ডার পরীক্ষা",
        "steps": [
          "প্রোফাইল → সেটিংস → রিমাইন্ডার পরীক্ষা খুলুন।",
          "যেগুলোতে মনোযোগ প্রয়োজন সেগুলো ঠিক করুন: নোটিফিকেশন, অ্যালার্ম ও রিমাইন্ডার, ব্যাটারি অপ্টিমাইজেশন।"
        ]
      },
      {
        "title": "ভাষা ও রঙের ধরন বদলানো",
        "steps": [
          "প্রোফাইল → সেটিংস → ভাষা ও রঙের ধরন খুলুন।",
          "English বা বাংলা, এবং সিস্টেম, হালকা বা গাঢ় বেছে নিন।"
        ]
      }
    ],
    "faqHeading": "প্রশ্ন ও উত্তর",
    "faq": [
      {
        "q": "রিমাইন্ডার বাজে না।",
        "a": "প্রোফাইল → সেটিংস → রিমাইন্ডার পরীক্ষা খুলুন। নোটিফিকেশন ও অ্যালার্ম ও রিমাইন্ডারের অনুমতি দিন, এবং ব্যাটারি অপ্টিমাইজেশনে মেডি-বেলাকে সীমাবদ্ধ করবেন না। কিছু ফোনে অটোস্টার্টও চালু করুন।"
      },
      {
        "q": "আমার প্রেসক্রিপশন বাতিল হয়েছে।",
        "a": "সেটি খুলে ফার্মাসিস্টের নোট পড়ুন, তারপর আবার আপলোড করুন চেপে আরও পরিষ্কার ছবি পাঠান।"
      },
      {
        "q": "ডোজের সময় ভুল।",
        "a": "ওষুধ → আমার ওষুধ খুলুন, ওষুধটিতে চাপুন এবং সময় বদলান।"
      },
      {
        "q": "পরিবার আমাকে দেখতে পাচ্ছে না।",
        "a": "পরিবার থেকে লুকান চালু আছে। প্রোফাইল → সেটিংস → গোপনীয়তা ও পরিবার থেকে এটি বন্ধ করুন।"
      },
      {
        "q": "পাসওয়ার্ড ভুলে গেছি।",
        "a": "সাইন-ইন পাতায় পাসওয়ার্ড ভুলে গেছেন? চাপুন এবং এসএমএসে পাঠানো কোডটি দিন।"
      },
      {
        "q": "সাময়িক বন্ধ করব, নাকি মুছে ফেলব?",
        "a": "সাময়িক বন্ধ করলে অ্যাকাউন্ট থেমে থাকে: রিমাইন্ডার বন্ধ হয়, আর সাইন ইন করলেই যেকোনো সময় ফিরে আসতে পারেন। মুছে ফেললে আপনার ব্যক্তিগত তথ্য চিরতরে মুছে যায়।"
      },
      {
        "q": "আমার তথ্য কি নিরাপদ?",
        "a": "হ্যাঁ। কে কী দেখতে পারে জানতে গোপনীয়তা ও শর্তাবলি পড়ুন।"
      }
    ],
    "contactHeading": "যোগাযোগ",
    "callLabel": "কল",
    "whatsappLabel": "হোয়াটসঅ্যাপ",
    "copyLabel": "কপি",
    "copiedLabel": "নম্বর কপি হয়েছে",
    "aboutTitle": "আমাদের সম্পর্কে",
    "missionLabel": "লক্ষ্য",
    "mission": "দূরে থেকেও পরিবারের যত্ন নিন।",
    "visionLabel": "স্বপ্ন",
    "vision": "ঠিক সময়ে, সুস্থ জীবন",
    "goalsHeading": "আমরা যা চাই",
    "goals": [
      "ফার্মাসিস্টের যাচাই করা প্রতিটি প্রেসক্রিপশনকে সময়মতো বাজা রিমাইন্ডারে রূপ দেওয়া।",
      "ডোজ বাদ পড়লে পরিবার যেন জানতে পারে, যাতে কাউকে একা দুশ্চিন্তা করতে না হয়।",
      "স্বাস্থ্যের রেকর্ড, বিজ্ঞপ্তি আর নির্ভরযোগ্য স্বাস্থ্য-তথ্য এক সহজ অ্যাপে, বাংলা ও ইংরেজিতে।"
    ],
    "teamHeading": "দল",
    "facebookLabel": "ফেসবুক",
    "team": [
      {
        "photo": "ashraful.jpg",
        "name": "আশরাফুল আলম",
        "field": "সফটওয়্যার ইঞ্জিনিয়ারিং",
        "university": "শাহজালাল বিজ্ঞান ও প্রযুক্তি বিশ্ববিদ্যালয়, সিলেট",
        "facebook": "https://www.facebook.com/ashraful.alam.931253"
      },
      {
        "photo": "tanvir.jpg",
        "name": "তানভীর হোসেন",
        "field": "কেমিক্যাল ইঞ্জিনিয়ারিং",
        "university": "রাজশাহী প্রকৌশল ও প্রযুক্তি বিশ্ববিদ্যালয়, রাজশাহী",
        "facebook": "https://www.facebook.com/aztanvirhossain"
      }
    ]
  }
};

export const SUPPORT_CONTACTS: { display: string; tel: string; whatsapp: string }[] = [
  {
    "display": "+8801810314801",
    "tel": "tel:+8801810314801",
    "whatsapp": "https://wa.me/8801810314801"
  },
  {
    "display": "+8801763740720",
    "tel": "tel:+8801763740720",
    "whatsapp": "https://wa.me/8801763740720"
  }
];
