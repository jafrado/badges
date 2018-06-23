#!/usr/bin/perl
# 
# badges.pl - generate badges from CSV input data
# Usage: badges.pl <csv_file>
# 
# Copyright (C) 2017 James F Dougherty <jfd@realflightsystems.com>
# 

# Dep libs
use strict;
use warnings;
use Text::CSV;
use LWP::Simple;
use File::stat;
use Time::localtime;
use Image::Magick;
use CGI qw(escapeHTML);
use URI::Find;
use Scalar::Util qw(looks_like_number);
use GD::Barcode;
use GD::Barcode::UPCA;
use Data::GUID;
use File::Slurp   qw(read_file);
use MIME::Base64  qw(encode_base64);    
use Crypt::OpenSSL::RSA;
use Digest::SHA qw(sha512_hex sha256_hex);

# Format of Datafile
#
# ID,Email,First Name,Last Name,Organization,ID#,Cert-Level,Signature Line
#
# Offsets into CSV file for each row of data below
use constant ID => 0;
use constant DATE=>1;
use constant EMAIL => 2;
use constant FNAME => 3;
use constant LNAME => 4;
use constant ORG => 5;
use constant IDNUM => 6;
use constant CLEVEL  => 7;
use constant SIGNATURE => 8;

# Top-level directory where images will be dumped
my $TOPDIR = "badges-duracard/";

# CSV Parser instance
my $csv = Text::CSV->new ({
    binary    => 1, # Allow special character. Always set this
    auto_diag => 1, # Report irregularities immediately
});

# Need filename on command line
my $file = $ARGV[0] or die "usage: [file] Class\nerror:no CSV filename provided on the command line\n";

print "Input file[$file]\n";
print "TOP DIR=$TOPDIR\n";

# create output directory if it does not exist
system "mkdir -p $TOPDIR";

# Array for entire table and one row of the table
my @rows;
my @row;
open(my $data, "<:encoding(utf8)", $file) or die "Could not open '$file' $!\n";

# Skip past headers (first line), load CSV file into rows of data
my $header = $csv->getline($data);
while (my $row = $csv->getline($data)) {
	push @rows, $row;
}

# Print Layout
# Ticketprinting.com has 3 types of badges
# For this program, we are using the SMALL VIP EVENT BADGE: 4.1" X 2.7"

# Duracard Hanger Template - 2100 x 3375 includes
# Hanger: 3 3/8" x 3 3/8" (3 1/2" x 3 7/16" Total with 1/8" bleed area)
# Credit Card Size (CR80): 3 3/8" x 2 1/8" (3 1/2" x 2 1/4" total with bleed)

# Input inches for bwi (badge width in inches)
my $bwi = 3.5;

# Input inches for bhi (badge height in inches)
my $bhi = 2.25; 

# Specify printable dpi
# Duracard wants 600 DPI
my $dpi = 600;

# Compute badge width/height in Centimeters
# NOTE: 1 dpi = 0.393701 pixel/cm; 1 pixel/cm = 2.54 dpi
my $bwc = $bwi * 2.54;
my $bhc = $bhi * 2.54;


# PNG works in dots/cm *not* dots/inch & 1 inch = 2.54cm so we have 
# 300dpi = 300/2.54 = 118.1 dots/cm
# The size of the badge is also 10.414cm x 6.858cm so if we want the pixel 
# density to have 300 dpi x 300 dpi, the PNG resolution would be 
# (10.414 * 118) x (6.858 x 118) = 1230x810

# Note: we keep all fractional numbers natively to make sure minimal 
# truncation errors are present and when printing any of these numbers, 
# we use int(x) to print the integer value of x

# compute dpc - dots per centimeter from DPI
my $dpc = $dpi / 2.54 ;

# Calculate pixel resolution: width (cm) * dots/cm x height (cm) * dots/cm
my $xa = int($bwc * $dpc);
my $ya = int($bhc * $dpc);

# Show status
print "Badge Dimensions: ", $bwi, "x", $bhi, "\"", " ", $bwc, "x", $bhc, "cm\n";
print "Print Resolution: ", $dpi," Dots per inch, ", int($dpc), " Dots Per centimeter\n";
print "Image Resolution: ", $xa, "x", $ya, " pixels\n";

# --- Main --- #

# Vars for calcs
# Geometry of badge itself
my $geometry = $xa."x".$ya;

# Density in dots/cm
my $density = int($dpc)."x".int($dpc);
my $filename = "";
my $text ="";

# ID for Badge, initially zero - note - badge #'s should start at 4 (see below)
my $idcode = 0;

# font point size and pitch (pixel offset for line of text rendered @ ps
my $ps = 42;
my $font_step = 42;


# Process each CSV line record
for my $r (@rows) {
    $csv->combine(@$r);

   # Default colors for badge boarder
    my $fg_color = 'chartreuse';	
#    my $fg_color = 'LightSteelBlue';	      
    my $font_color = 'black';
    my $cert_level = "";

    # Compute Cert Level (e.g. 0, 1, 2, 3)
    # Setup Font/Fill Colors to Draw bottom half of badge
    if (length $r->[CLEVEL] >= 7 ) {
	
	$cert_level = substr($r->[CLEVEL], 6, 6);
	if (($cert_level eq "1") || ($cert_level eq "0")) {  
#	    $fg_color = 'LightSteelBlue';
	    $font_color = 'black';
	} 
	if ($cert_level eq "2") { 
#	    $fg_color = 'yellow';
	    $font_color = 'black';
	}
	if ($cert_level eq "3") { 
#	    $fg_color = 'chartreuse';
	    $font_color = 'black';
	}
	if ( ($cert_level eq "0")) {
	    $fg_color = 'red';	    
	}
	
    } else {
	if ( ($r->[CLEVEL] eq "None") || ($r->[CLEVEL] eq "0") || ($r->[CLEVEL] eq "TMP") ) { 
	    $cert_level = 0;
	    $fg_color = 'red';
	}
    }
    if ( ($cert_level eq "")) {
	$fg_color = 'red';	    
    }
    # Show each record field
    print "ID: ", $r->[ID]," ", $r->[FNAME]," ", $r->[LNAME], " ", $r->[ORG], " #", $r->[IDNUM], " ", $cert_level, "\n";


   # Make new image (32bpp) with correct density/resolution, fill with white
    my $image = Image::Magick->new(layer=>0, size=>$geometry, 
				   depth=>int($dpc), 
				   units=>'pixelspercentimeter', 
				   density=>$density);
    my $x = $image->ReadImage('canvas:white');
    warn "$x" if "$x";

    # Composite first Image - Website banner on top of badge
    $image->Read('images/LDRS37-8.png');

    # Scale Banner Image to width of badge
    $image->Resize(width=>$xa);
    my $badge = $image->[0];
    my $banner = $image->[1];

    # Composite Banner on main badge
    $badge->Composite(image=>$banner, x=>0, y=>0);#, x=>0, y=>0, geometry=>$geometry, opacity=>50);

    # Set initial step size
    $font_step = 50;
    my $img_offset = 432;


#    $image->Annotate(font=>'fonts/Sonicxb.ttf', 
#		     x=>280, y=>300,
#                     pointsize=>72, fill=>'black', text=>"LDRS XXXVII");
    
    # Draw border area
    $badge->Draw(stroke=>'black', fill=>$fg_color, 
		 primitive=>'rectangle', points=>'0,400,2100,2156');

    # LDRS ID is the Wordpress User ID minus 3 (to remove admin users)
    # NOTE: This implies all users start at 4 in your datafile ID field
    $idcode = int($r->[ID]) - 3;

    # But, we only put out an ID# on the Badge if there is a 
    # non-null name (to handle blank badge prints for onsite reg)
    if ($r->[FNAME] ne "") { 
	# ID 
	$text = "LDRS37-ID#". $idcode;
    } else { 
	$text = "LDRS37-ID#";
    }
    $image->Annotate(font=>'fonts/Sonicxb.ttf', 
		     x=>220, y=>520,
                     pointsize=>38, fill=>'black', text=>$text);

   # Generate UUID
    my $guid = Data::GUID->new;
    my $uniqueIdString = $guid->as_string;
    print "UUID:", $uniqueIdString, "\n";

    # Digital signature assets
    # Load Key and generate signature over email and ID
    # We sign the email address wih an RSA key for a digital signature
    # If email address is null, all keys will be the same for empties
    # which is unpersonalized and what we want!
    # To generate the RSA Key used for all badges:
    #  openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -out cert.pem

    my $keystring = read_file( 'key.pem' );
    my $privatekey = Crypt::OpenSSL::RSA->new_private_key($keystring);
    $privatekey->use_pkcs1_padding();
    my $signature = $privatekey->sign($r->[EMAIL]);
    $signature = encode_base64($signature, ' ');
    $signature = sha256_hex($signature);
    print "KEY:", $r->[EMAIL], "\n";
    print "SIGNATURE:", $signature, "\n";

    # Name: First Last
    $text = $r->[FNAME]." ".$r->[LNAME];
    $image->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>200, y=>(5*$font_step + $img_offset), pointsize=>$ps, 
                     fill=>$font_color, text=>$text);

    #  Organization and Membership number, Cert Level
    $text = $r->[ORG]." ".$r->[IDNUM];
    $image->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>200, y=>(8*$font_step + $img_offset), pointsize=>$ps, 
                     fill=>$font_color, text=>$text);

    #$text = $." ".substr($r->[CLEVEL], 0, 1).substr($r->[CLEVEL], 6, 6);
    $text = $r->[CLEVEL];

    if ($text eq "None") {
	$text  = "Level 0";
    }
    
    $image->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>200, y=>(11*$font_step+6 + $img_offset), 
                     pointsize=>$ps, fill=>$font_color, text=>$text);


    # Border on image
    # $image->Border(width=>1, height=>1, bordercolor=>'black');


    # Make QR-Code from Email address
    # Use VCARD RFC - https://tools.ietf.org/html/rfc6350
    # Use VCARD as described here: 
    #        http://outer-rim.florath.net/?p=62 with a few mods
    # 
    # BEGIN:VCARD
    # VERSION:4.0
    # FN:James Dougherty
    # URL:http://ldrs37.org/
    # EMAIL:jfd@realflightsystems.com
    # UID: $Id
    # NOTE: TRA 11425, Level 3
    # END:VCARD

    # See also: http://www.evenx.com/vcard-3-0-format-specification

    my $vcard = "BEGIN:VCARD\n";
    $vcard .="VERSION 4.0\n";
    $vcard .= "N:".$r->[LNAME].";".$r->[FNAME]."\n";
    $vcard .= "FN:".$r->[FNAME]." ".$r->[LNAME]."\n";
    $vcard .= "ADR;TYPE=dom,home,postal,parcel:;;;;;; ";
    # Todo: put link to users page on ldrs37.org
    $vcard .= "URL:http://ldrs37.org/\n";
    $vcard .= "ORG: LDRS37\n";
    $vcard .= "EMAIL:".$r->[EMAIL]."\n";
    if ($cert_level ne "") { 
	$vcard .= "NOTE: ".$r->[ORG]." ".$r->[IDNUM]." ".$cert_level." ".$r->[SIGNATURE]."\n";
    }
    $vcard .= "END:VCARD\n";
    my $qrf = $TOPDIR."QR".$idcode.".png";
    print "-----------------------\n",$vcard;

    # Flier unless Signature has additional field of Vendor/Staff indicator 
    # Flier Lettering
    print "FLIER\n----\n";
    $badge->Draw(stroke=>'black', fill=>'chartreuse', 
		 primitive=>'rectangle', points=>'0,1030,2100,2156');
    
    $text = '        FLIER';
    $badge->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>850, y=>(8*$font_step-30 + 810), 
                     pointsize=>'120', fill=>'black', text=>$text);

    # Signature not empty, match keywords for Vendor Lettering
    if ($r->[SIGNATURE] ne "") { 
	if (($r->[SIGNATURE] =~ m/Bay Area Rocketry/)||
	    ($r->[SIGNATURE] =~ m/Aerotech/)||
	    ($r->[SIGNATURE] =~ m/Vendor/)||
	    ($r->[SIGNATURE] =~ m/Discount/)||	    	    
	    ($r->[SIGNATURE] =~ m/Fruity/)||
	    ($r->[SIGNATURE] =~ m/Rockets Magazine/)||
	    ($r->[SIGNATURE] =~ m/Wildman/)||
	    ($r->[SIGNATURE] =~ m/M2/)||
	    ($r->[SIGNATURE] =~ m/Madcow/)||
	    ($r->[SIGNATURE] =~ m/Real/)||
	    ($r->[SIGNATURE] =~ m/Eggtimer/)||
	    ($r->[SIGNATURE] =~ m/WILD/)||
	    ($r->[SIGNATURE] =~ m/APE/)||
	    ($r->[SIGNATURE] =~ m/UMERG/)||
	    ($r->[SIGNATURE] =~ m/Fusion/)||
	    ($r->[SIGNATURE] =~ m/Feather/)||
	    ($r->[SIGNATURE] =~ m/Black/)||
	    ($r->[SIGNATURE] =~ m/Photos/)||
	    ($r->[SIGNATURE] =~ m/Rocketman/)||
	    ($r->[SIGNATURE] =~ m/Wilson/)||	    	    	    
	    ($r->[SIGNATURE] =~ m/RAF/)||
	    ($r->[SIGNATURE] =~ m/AMW/)) {
	    print "VENDOR\n----\n";
	    $badge->Draw(stroke=>'black', fill=>'orange', 
			 primitive=>'rectangle', points=>'0,1030,2100,2156');

	    $text = '       VENDOR';
	    $badge->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>850, y=>(8*$font_step-30 + 810), 
                     pointsize=>'120', fill=>'black', text=>$text);
	    
	}  
	# Staff Lettering
	if (($r->[SIGNATURE] =~ m/TCC/)||
	    ($r->[SIGNATURE] =~ m/LDRS/)||
	    ($r->[SIGNATURE] =~ m/TRA/)||	    
	    ($r->[SIGNATURE] =~ m/AeroPAC/)||	    
	    ($r->[SIGNATURE] =~ m/Tripoli Central California/)||
	    ($r->[SIGNATURE] =~ m/ANYTHING/)) {
	    print "STAFF\n----\n";
	    $badge->Draw(stroke=>'black', fill=>'OrangeRed', 
                         primitive=>'rectangle', points=>'0,1030,2100,2156');

	    $text = '        STAFF';
	    $badge->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>850, y=>(8*$font_step-30 + 810), 
                     pointsize=>'120', fill=>'black', text=>$text);
	}

	# Special Spectator 
	if (($r->[SIGNATURE] =~ m/Spectator/)||
	    ($r->[SIGNATURE] =~ m/Visitor/)) {

	    print "SPECTATOR\n----\n";
	    $badge->Draw(stroke=>'black', fill=>'Red', 
                         primitive=>'rectangle', points=>'0,1030,2100,2156');
	    $text = '     SPECTATOR';
 	    $badge->Annotate(font=>'fonts/Helvetica-BlackItalic.ttf', 
		     x=>850, y=>(8*$font_step-30 + 810), 
                     pointsize=>'120', fill=>'black', text=>$text);
	}
    }

    # Adorn badge with stars based on Level
    my $star_image = "";
    my $star_count = 0;
    if ($cert_level eq "1") { 
	$star_image = 'images/802px-Silver_star.png';
	$star_count = 1;
    } 
    if ($cert_level eq "2") { 
	$star_image = 'images/802px-Silver_star.png';
	$star_count = 2;
    }
    if ($cert_level eq "3") { 
	$star_image = 'images/802px-Golden_star.png';
	$star_count = 3;
    }
    # Star Pattern		 
    # This is a tricky corner-case, set the image definition to the 
    # next one in the array as the index will change if the 
    # Organization is not set ...
    my $star_icon;
    if ($star_count > 0) { 
	$image->Read($star_image);
	$star_icon = $image->[ (scalar @$image - 1)];
	$star_icon->Resize(width=>140, height=>140);
	for (my $i=0; $i < $star_count; $i++) {
	    $badge->Composite(image=>$star_icon, 
			      x=>(900 + 140*$i), y=>(8*$font_step +28 + $img_offset));
        }
    }

    # Add Barcode in middle bottom and key/serial 

    # Info on 1D/2D Barcodes - start here:
    # https://www.scandit.com/types-barcode-upc-ean-code128-vs-qr-datamatrix/
    # See also: 
    # https://www.pma.com/Content/Articles/2014/05/Universal-Product-Codes

    # Generate Barcode from UUID (UPCA in the USA; EAN8, EAN13 elsewhere)
    # Code the Generic UPC GS1 Prefix ('033383')
    # Code the ID as the last digits

    $text = '33383';
    $text .= sprintf "%05d", $idcode;

    # if < 11 digits, add a 0 to the front
    $text = "0".$text if (length($text) == 10); 
    # truncate barcodes > 11 chars
    chop $text if (length($text) == 12); 
    print "UPCA: $text\n";

    my $upc_barcode = GD::Barcode::UPCA->new($text);
   # Check for invalid len
    die $GD::Barcode::UPCA::errStr unless($upc_barcode); 

    open(IMG, ">./$TOPDIR/$idcode-upc.png") or die $!;
    binmode(IMG);
    print IMG GD::Barcode::UPCA->new($text)->plot->png;
    close(IMG);

    # Resulting barcode is 109x50 Pixels, place it on the bottom in the middle
    $image->Read("$TOPDIR/$idcode-upc.png");
    my $barcode = $image->[ (scalar @$image - 1)];
    # Image is 810x1230, barcode 109x50, put towards bottom left
    $badge->Composite(image=>$barcode, x=>1820, y=>1120);
    system "rm -f $TOPDIR/$idcode-upc.png";

    # Signature text on bottom of badge
    $text = "    Badge#".$idcode."        Serial:".$signature."\n";
    $badge->Annotate(font=>'system', x=>1400, y=>1200,fill=>'black', text=>$text);
    my $tcc_logo; 			      
    $image->Read('images/TCC_Logo.png');
    $tcc_logo = $image->[ ((scalar @$image) - 1)];
    $tcc_logo->Resize(width=>300, height=>300);
    $badge->Composite(image=>$tcc_logo, x=>1658, y=>550);

    # Make unique Filename from Badge ID and Org ID
    $filename = "png24:".$TOPDIR."LDRS37-Badge-00".$idcode."-".$r->[ORG]."-".$r->[IDNUM]."-cr80.png";

    print "Write ...";
    $x = $badge->Write($filename);
    warn "$x" if "$x";

    $filename = $TOPDIR."LDRS37-Badge-00".$idcode."-".$r->[ORG]."-".$r->[IDNUM]."-cr80.png";
    print "Wrote Badge: [".$filename."]\n";

}


