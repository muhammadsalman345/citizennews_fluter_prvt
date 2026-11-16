class LegalSection {
  const LegalSection({required this.title, required this.text});

  final String title;
  final String text;
}

class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.title,
    required this.sections,
  });

  final String slug;
  final String title;
  final List<LegalSection> sections;
}

const legalDocuments = <String, LegalDocument>{
  'about': LegalDocument(
    slug: 'about',
    title: 'About CitizenNews',
    sections: [
      LegalSection(
        title: 'Our purpose',
        text:
            'CitizenNews is a community reporting platform for local news, accident reports and job listings. Readers can explore stories, follow reporters and locations, save articles and join conversations. Users who want to submit posts apply for reporter access through identity verification.',
      ),
      LegalSection(
        title: 'Our approach',
        text:
            'Approved reporters submit photos and a detected posting location. Editors review submissions before publication. Reporter verification confirms access to reporting features; it does not guarantee that every claim is accurate. Identity documents and exact posting coordinates are not shown on public article pages.',
      ),
    ],
  ),
  'privacy': LegalDocument(
    slug: 'privacy',
    title: 'Privacy policy',
    sections: [
      LegalSection(
        title: 'Advertising on Android',
        text:
            'Our Android app uses Google AdMob to show banner, native, interstitial, rewarded and app-open ads. Google and its advertising partners may process device identifiers, IP addresses, ad interactions and diagnostic data to serve ads, prevent fraud and measure performance. Where required, we ask for consent before requesting ads. You can review your choices using Ad privacy choices. Rewarded ads are optional and only pause ads temporarily; they do not earn money or wallet credit. Google privacy information: https://policies.google.com/technologies/ads',
      ),
      LegalSection(
        title: 'What other users can see',
        text:
            'Published stories, their public photos, your public reporter profile and public comments or reactions may be visible to other users. Your name, username and chosen profile photo can appear with your activity. Exact posting coordinates, identity-verification documents and payout details are not included on public article pages.',
      ),
      LegalSection(
        title: 'Camera, photos and location',
        text:
            "Reporter submissions require detected location to resolve the posting area and support evidence checks. Camera access is used when taking photos, and Android's system photo picker lets you share only the gallery photos you select. Photos are optional except for accident reports, which require a fresh camera photo. Location is requested during reporting and capture; the app does not run continuous background location tracking.",
      ),
      LegalSection(
        title: 'Services used to operate CitizenNews',
        text:
            'Supabase provides account authentication, database and uploaded-file storage. Location resolution uses server-side reverse-geocoding services to identify the posting area. Google AdMob provides Android advertising. These services receive the information needed for their respective functions.',
      ),
      LegalSection(
        title: 'Information we process',
        text:
            'CitizenNews processes account and profile details, including the phone number supplied at signup, identity documents and selfies submitted for reporter verification, post photos, detected posting coordinates and accuracy, capture time, device information, posts, comments, reactions, follows, bookmarks, reports and support messages. Withdrawal requests can include bank details and a phone number. These records support authentication, reporter verification, editorial review, account security, community features and payment administration.',
      ),
      LegalSection(
        title: 'Access and retention',
        text:
            'Authorized reviewers can access verification documents and reporting evidence through expiring links. Restricted records may also be accessed by authorized platform administrators. Removing a post from public view does not automatically erase its evidence, moderation history or associated points and financial records. The app currently has no automatic retention-expiry schedule. Contact the team with privacy or data-access questions; do not include unnecessary sensitive information in posts.',
      ),
      LegalSection(
        title: 'Cookies and local storage',
        text:
            'Local storage supports login sessions, language preferences and advertising controls. Unfinished post recovery data, including attached photos and location evidence, can remain on your device until you submit it. The Android app uses Google AdMob; see the advertising section for its data use and privacy choices. Clearing local recovery data or uninstalling the app does not delete your server account.',
      ),
    ],
  ),
  'terms': LegalDocument(
    slug: 'terms',
    title: 'Terms & conditions',
    sections: [
      LegalSection(
        title: 'Responsible use',
        text:
            'Use accurate account information. Do not impersonate people, manipulate engagement, submit fabricated evidence or infringe privacy or copyright. Editorial review may reject, remove or request changes to content.',
      ),
      LegalSection(
        title: 'Earnings',
        text:
            'Points reflect eligible editorial activity and do not guarantee earnings. Wallet credits, eligibility, minimum withdrawal amounts and available balances determine whether a withdrawal can be requested. Administrators review requests and process approved payments manually. Watching a rewarded advertisement does not earn points, cash or wallet credit.',
      ),
      LegalSection(
        title: 'Accounts and submissions',
        text:
            'Keep your login details secure and use documents you are authorized to submit. Reporter access requires approval. Editors may request changes, reject or remove submissions, and suspend accounts for abuse. Reporters can submit supported corrections and appeals through the available account features.',
      ),
    ],
  ),
  'community-guidelines': LegalDocument(
    slug: 'community-guidelines',
    title: 'Community guidelines',
    sections: [
      LegalSection(
        title: 'Job listings and personal safety',
        text:
            'Job listings are community submissions reviewed for publication; publication is not a guarantee that an employer or offer is genuine. Check employer details independently. Do not send money, banking passwords or identity documents to an unknown recruiter. Report suspicious listings through the article report action.',
      ),
      LegalSection(
        title: 'Report responsibly',
        text:
            'Be accurate, distinguish observation from opinion, identify sources and disclose uncertainty. Use only photos you own or have permission to share. Accident reports require a fresh camera photo; photos are optional for other categories. Never endanger yourself or others to obtain a story. Do not use CitizenNews to request urgent emergency assistance.',
      ),
      LegalSection(
        title: 'Respect people',
        text:
            'No harassment, hate, spam, unnecessary personal information or exploitation of minors. Graphic material needs editorial assessment and appropriate public presentation. Do not publish identity documents or exact private addresses.',
      ),
      LegalSection(
        title: 'Join the conversation',
        text:
            'Keep comments relevant and respectful. Report harmful content and give editors enough context to investigate.',
      ),
    ],
  ),
  'editorial-policy': LegalDocument(
    slug: 'editorial-policy',
    title: 'Editorial policy',
    sections: [
      LegalSection(
        title: 'Review before publication',
        text:
            'Editors assess evidence, context, location consistency, sources, duplicate warnings and reporter history. They may publish, reject or request changes. Reporter verification and editorial review are separate processes.',
      ),
      LegalSection(
        title: 'Accountability',
        text:
            'Important factual changes use reviewed revisions. Published versions remain live while proposed changes are pending. Decisions and sensitive administrative actions are audited.',
      ),
    ],
  ),
  'corrections-policy': LegalDocument(
    slug: 'corrections-policy',
    title: 'Corrections policy',
    sections: [
      LegalSection(
        title: 'Correct the record',
        text:
            'Report factual errors using the article report action. Reporters propose revisions with a correction note. Approved factual corrections display a public correction badge, note and updated time.',
      ),
      LegalSection(
        title: 'Preserve history',
        text:
            'Original evidence location, capture time and moderation history remain immutable. Editors do not silently replace important factual claims.',
      ),
    ],
  ),
  'content-removal': LegalDocument(
    slug: 'content-removal',
    title: 'Content removal policy',
    sections: [
      LegalSection(
        title: 'Removal and stored records',
        text:
            'Removing a story hides it from readers. Evidence, editorial decisions, appeals and associated points or payment records may remain available to authorized administrators. Content removal and account-data deletion are different requests; contact the team with questions about your information.',
      ),
      LegalSection(
        title: 'When removal is appropriate',
        text:
            'Editors may remove misinformation, privacy violations, illegal material, harassment, copyright infringement or content that presents a credible safety risk. Report concerns using an article or comment report.',
      ),
      LegalSection(
        title: 'Appeals',
        text:
            'Reporters can appeal rejected or removed stories. The newsroom records the appeal, review status and response. Accepting an appeal does not automatically republish content without an editorial decision.',
      ),
    ],
  ),
  'copyright': LegalDocument(
    slug: 'copyright',
    title: 'Copyright & content rights',
    sections: [
      LegalSection(
        title: 'Respect creators',
        text:
            'Submit media you created or have permission to use. Credit sources, and do not reproduce copyrighted articles in full. Rights complaints require identification of the work and relevant article.',
      ),
      LegalSection(
        title: 'Submit a rights complaint',
        text:
            'Use Contact us to identify the copyrighted work, the CitizenNews article URL, your relationship to the rights holder and how the team can contact you. Provide enough detail for review. Do not submit another person’s private documents or make misleading ownership claims.',
      ),
    ],
  ),
};
