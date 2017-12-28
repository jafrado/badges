# badges
Event Badge Generator

# We Don't Need no Stinking Badges!

  Is a widely quoted paraphrase of a line of dialogue from the 1948 film 
  The Treasure of the Sierra Madre.[1] That line was in turn derived from dialogue in the 
  1927 novel, The Treasure of the Sierra Madre, which was the basis for the film.

  The original version of the line appeared in B. Traven's novel
  The Treasure of the Sierra Madre (1927):

  "All right," Curtin shouted back. "If you are the police, where are your badges? Let's see them."
  "Badges, to god-damned hell with badges! We have no badges. In fact, we don't need badges. 
   I don't have to show you any stinking badges, you god-damned cabrón and chinga tu madre!"

   The line was popularized by John Huston's 1948 film adaptation of the novel, which was altered 
   from its content in the novel to meet the Motion Picture Production Code regulations severely 
   limiting profanity in film.[3] In one scene, a Mexican bandit leader named "Gold Hat"[4] 
   (portrayed by Alfonso Bedoya) tries to convince Fred C. Dobbs (Humphrey Bogart)[5] that he 
   and his company are Federales:

      Dobbs: "If you're the police, then where are your badges?"

     Gold Hat: "Badges? We ain't got no badges. We don't need no badges. I don't have to show 
               you any stinkin' badges!

- See also - https://en.wikipedia.org/wiki/Stinking_badges

   The point was that without a badge, Dobbs had no way to validate Gold Hat was a Federale when
   in fact he was actually a bandit.

# What Makes a Good Badge

  - Stylish - yes, you too can have one and wear it proudly
  - Informative - name, rank, title
  - Color Coded for Info at a Glance
  - Personalization - unique info about the holder
  - Globally Unique ID - no two badges can be the same
  - Ability to transfer assets digitally via machine vision (e.g. a QR-Code)
  - Ability to revoke access on badge - e.g. de-authorize

The intention of this script is to perform the required data mining on a minimal set of 
unique labeled attributes information to hit the above goals


# LDRS37 Badge Generator

- LDRS37 is a large HPR Event which will happen in 2018 in Helm, CA - in order to facilitate
  registration validation and user access it is desirable to automatically generate Badges
  based on Web form submissions
- We would also like to keep the Database small and with minimal info (e.g. email only) and
  not rely on full database info (e.g. WPUsers information)
- Generates 300 Dpi Badge Images (PNG) for ticketprinting.com based on ldrs37.org web submissions
- Computes DPI for PNG based on input DPI and Ticket Width/Height
  - Note: only Tested with SMALL VIP EVENT BADGE: 4.1" X 2.7 in Portrait mode
- Uses input CSV file of submissions from LDRS37.org
    - Fields of CSV file are:
      [ID,Email, "First Name","Last Name",Organization,"Membership Number","Cert Level",Signature]
- Logic is as follows:
   - Install Graphic logo for event
   - Add Badge ID-Code (WPUsers user->ID)
   - Add User Name, Membership Organization and Number, Level Certification
   - Generate QRCode with VCARD Info for Contact (Email and TRA/NAR #, Signature only)
   - Show TRA or NAR badge based on Organization ID
   - Generate FLIER, STAFF, VENDOR based on keywords in Signature
   - Add Additional Glamour ..

# Prerequisites

  Install Perl on a Modern Debian distribution, install packages below:

	- cpan install Text::CSV
	- cpan install Image::Magick
	- cpan install Imager::QRCode

NOTE: cpan -l will list installed packages.

# Operation

- Run as below:
  - ./badges.pl <csvfile>
  - Output will be in the "badges" subdirectory of this folder
  - Resulting PNG files ready for printing

# Future Directions

  - XML Schema for Layout
  - More layout/print options
  - Link database CSV with more information for QRCode
  - <ore VCARD Fields for QR-Code
  - Trackback link for hits (Scans)

# Software

  - The software is a Perl Script, leverages Image::Magic, Text::CSV, and Imager::QRCode
  - You may modify or use software as needed, provided you inlude the Copyright text below

# Copyright

  - Copyright (C) 2017 Real Flight Systems <jfd@realflightsystems.com>

# Author

  - James F Dougherty <jfd@realflightsystems.com>

