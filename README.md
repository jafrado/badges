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
   - Print out LDRS37 Badge ID
   - Generate QRCode with VCARD Info for Contact (Email and TRA/NAR #, Signature only)
   - Show TRA or NAR badge based on Organization ID
   - Generate FLIER, STAFF, VENDOR based on keywords in Signature

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
