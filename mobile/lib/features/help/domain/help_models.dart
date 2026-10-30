/// Privacy & terms, Support and About us text. The text itself is generated
/// into help_content.dart from docs/content/public-pages.json (the web pages
/// use the same file), and ships with the app, so these pages work offline.
class HelpContent {
  const HelpContent({
    required this.privacyTitle,
    required this.privacySections,
    required this.supportTitle,
    required this.howToHeading,
    required this.howTo,
    required this.faqHeading,
    required this.faq,
    required this.contactHeading,
    required this.callLabel,
    required this.whatsappLabel,
    required this.copyLabel,
    required this.copiedLabel,
    required this.aboutTitle,
    required this.missionLabel,
    required this.mission,
    required this.visionLabel,
    required this.vision,
    required this.goalsHeading,
    required this.goals,
    required this.teamHeading,
    required this.facebookLabel,
    required this.team,
  });

  final String privacyTitle;
  final List<HelpSection> privacySections;
  final String supportTitle;
  final String howToHeading;
  final List<HelpSection> howTo;
  final String faqHeading;
  final List<HelpFaq> faq;
  final String contactHeading;
  final String callLabel;
  final String whatsappLabel;
  final String copyLabel;
  final String copiedLabel;
  final String aboutTitle;
  final String missionLabel;
  final String mission;
  final String visionLabel;
  final String vision;
  final String goalsHeading;
  final List<String> goals;
  final String teamHeading;
  final String facebookLabel;
  final List<HelpTeamMember> team;
}

/// A heading with lines (privacy) or steps (how-to).
class HelpSection {
  const HelpSection(this.heading, this.lines);

  final String heading;
  final List<String> lines;
}

class HelpFaq {
  const HelpFaq(this.question, this.answer);

  final String question;
  final String answer;
}

class HelpTeamMember {
  const HelpTeamMember({
    required this.photo,
    required this.name,
    required this.field,
    required this.university,
    required this.facebook,
  });

  /// File name in assets/images/.
  final String photo;
  final String name;
  final String field;
  final String university;
  final String facebook;
}

class SupportContact {
  const SupportContact({required this.display, required this.tel, required this.whatsapp});

  final String display;
  final String tel;
  final String whatsapp;
}
