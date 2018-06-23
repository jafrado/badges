#!/usr/bin/perl
# 
# orders.pl - generate PDF Order receipts from WooCommerce orders
# We generate a LaTeX file and use pdflatex to output a PDF of all orders
# this way we just print for registration package preparation
#
# Usage: orders.pl <csv_file>
# 
# Copyright (C) 2018 James F Dougherty <jfd@realflightsystems.com>
# 

# Dep libs
use strict;
use warnings;
use Text::CSV;
use LWP::Simple;
use utf8;

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# Format of Datafile
#
#"Order Number","Order Status","Order Date","Customer Note","First Name (Billing)","Last Name (Billing)","Company (Billing)","Address 1&2 (Billing)","City (Billing)","State Code (Billing)","Postcode (Billing)","Country Code (Billing)","Email (Billing)","Phone (Billing)","First Name (Shipping)","Last Name (Shipping)","Address 1&2 (Shipping)","City (Shipping)","State Code (Shipping)","Postcode (Shipping)","Country Code (Shipping)","Item #",SKU,Name,"Product Variation",Quantity,"Quantity (- Refund)","Item Cost","Order Line (w/o tax)","Order Line Tax","Order Line Total","Order Line Total Refunded","Order Line Total (- Refund)","Image URL","Coupon Code","Discount Amount","Discount Amount Tax","Payment Method Title","Coupons Used","Cart Discount Amount","Order Subtotal Amount","Order Tax Amount","Order Shipping Amount","Order Refund Amount","Order Total Amount","Order Total Tax Amount","Total items","Total products"

# Offsets into CSV file for each row of data below
use constant ORDER_NUMBER => 0;
use constant ORDER_STATUS =>1;
use constant ORDER_DATE => 2;
use constant CUSTOMER_NOTE => 3;
use constant B_FIRSTNAME => 4;
use constant B_LASTNAME  => 5;
use constant B_COMPANY => 6;
use constant B_ADDR12  => 7;
use constant B_CITY => 8;
use constant B_STATE => 9;
use constant B_ZIPCODE => 10;
use constant B_CC => 11;
use constant B_EMAIL => 12;
use constant B_PHONE => 13;
use constant S_FIRSTNAME => 14;
use constant S_LASTNAME  => 15;
use constant S_ADDR12  => 16;
use constant S_CITY => 17;
use constant S_STATE => 18;
use constant S_ZIPCODE => 19;
use constant S_CC => 20;
use constant ITEM => 21;
use constant SKU => 22;

use constant NAME => 23;
use constant VARIATION => 24;
use constant QUANTITY => 25;
use constant QUANTITY_REFUND => 26;
use constant ITEM_COST => 27;
use constant ORDERLINE_NOTAX => 28;
use constant ORDERLINE_TAXED => 29;
use constant ORDERLINE_TOTAL => 30;
use constant ORDERLINE_TOTAL_REFUNDED => 31;
use constant ORDERLINE_TOTAL_WITHOUT_REFUND => 32;
use constant IMAGE_URL => 33;
use constant COUPON_CODE => 34;
use constant DISCOUNT_AMOUNT => 35;
use constant DISCOUNT_AMOUNT_TAX => 36;
use constant PAYMENT_METHOD => 37;
use constant COUPONS_USED => 38;
use constant CART_DISCOUNT_AMOUNT => 39;
use constant ORDER_SUBTOTAL_AMOUNT => 40;
use constant ORDER_TAX_AMOUNT => 41;
use constant ORDER_SHIPPING_AMOUNT => 42;
use constant ORDER_REFUND_AMOUNT => 43;
use constant ORDER_TOTAL_AMOUNT => 44;
use constant ORDER_TOTAL_TAX_AMOUNT => 45;
use constant TOTAL_ITEMS => 46;
use constant TOTAL_PRODUCTS => 47;

my $dinner_count = 0;
my $bb_dinner_count = 0;
my $bb_dinner_funds = 0;
my $dinner_funds = 0;
my $registration_count = 0;
my $registration_funds = 0;
my $tshirt_count = 0;
my $tshirt_funds = 0;
my $sticker_count = 0;
my $sticker_funds = 0;
my $net_funds = 0;
my $total_funds = 0;
my $paypal_fees = 0;
my $n_orders = 0;
my $discounted_registrations = 0;
my $n_discounted_registrations = 0;
my $dual_registrations = 0;

my $tshirt_sm = 0;
my $tshirt_m = 0;
my $tshirt_l = 0;
my $tshirt_xl = 0;
my $tshirt_2xl = 0;
my $tshirt_3xl = 0;
my $tshirt_4xl = 0;

my $dc_steak = 0;
my $dc_chicken = 0;
my $dc_vegetarian = 0;
my $dc_d_shortcake = 0;
my $dc_d_mousse = 0;
my $dc_t_mushrooms = 0;
my $dc_t_bearnaise = 0;
my $dc_t_barbeque = 0;
my $dc_t_merlot = 0;
my $dc_t_picatta = 0;
my $dc_t_lemon_herb = 0;
my $dc_t_marsala = 0;
my $dc_t_bleu_glaciage = 0;
my $dc_t_butter = 0;
my $dc_t_alfredo = 0;
my $dc_t_none = 0;
my $dc_t_port_wine = 0;
my $dc_sd_ranch = 0;
my $dc_sd_vinaigrette = 0;

my @multiregistrationlist;
my @orderlist;
my @emailinfo;

# Order hashes, for each order, we use associative arrays indexed by order #
# tshirts, registrations, banquets, stickers
# This way we can group all orders together
my %tshirtorders = ();
my %registrations = ();
my %banquetdinners = ();
my %stickerorders = ();
my %ordertonames = ();
my %orderdetails = ();
my %discountamounts = ();
my %totalitemcounts = ();
my %totalpaid = ();
my %phonecontacts = ();
my %shortnames = ();
my %blackrockbistroitems = ();

# Top-level directory where images will be dumped
my $TOPDIR = "orders/";

# CSV Parser instance
my $csv = Text::CSV->new ({
    binary    => 1, # Allow special character. Always set this
    auto_diag => 1, # Report irregularities immediately
});

# Output CSV file of all dinners and their selection
open(BANQUETDINNERFILE, ">./$TOPDIR/banquetdinners.csv") or die $!;
print BANQUETDINNERFILE "OrderID, First-Name,Last-Name,Email,Phone,Quantity,Main-Course,Sauce,Salad-Dressing,Dessert\n";
open(BANQUETDINNERFILE2, ">./$TOPDIR/harrisdinners.csv") or die $!;
print BANQUETDINNERFILE2 "OrderID,Quantity,Main-Course,Sauce,Salad-Dressing,Dessert\n";

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

# Process each CSV line record
for my $r (@rows) {
    # gather row
    $csv->combine(@$r);

    if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	
	# push up order # into list of orders, don't add the order if it's in there already ...
	push (@orderlist, $r->[ORDER_NUMBER]) unless grep{$_ == $r->[ORDER_NUMBER]} @orderlist;

	# add up the cost of each item ordered
	$total_funds = $total_funds + $r->[ITEM_COST];

	# People may have # in their street name, escape for Latex
	my $str1_pat = quotemeta('#');
	my $str1_rep = '\#';
	$r->[B_ADDR12] =~ s/$str1_pat/$str1_rep/g;

	# First Name Convert upper case to lower
	my $fullname = lc($r->[B_FIRSTNAME]." ".$r->[B_LASTNAME]);
	# Capitalize first letter of each word
	$fullname =~ s/(\w+)/\u$1/g;


	# Normalize US Phone numbers to (408) 867-5309 , else leave sequence as-is ...
	my $phone = $r->[B_PHONE];
	# Thanks Zaxo - http://www.perlmonks.org/bare/?node_id=259986
	# convert alpha mnemonics
	$phone =~ tr/A-PR-Z/222333444555666777888999/;
	$phone =~ tr/a-pr-z/222333444555666777888999/;    
	# get rid of any nondigits
	$phone =~ s/\D//g;    
	# format
	$phone =~ s/^(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;
	$phone =~ s/^(\d{3})(\d{4})$/$1-$2/; # no AC

	# Country code extension
	my $cc = $r->[B_CC];
	if ($cc eq "US") {
	    $cc = "USA";
	}
	if ($cc eq "AU") {
	    $cc = "Australia";
	}

	print "Phone:$phone\n";
	$ordertonames{$r->[ORDER_NUMBER]} = "\n\n".$fullname."\\newline\n".$r->[B_ADDR12]."\\newline\n".$r->[B_CITY].",".$r->[B_STATE]." ".$r->[B_ZIPCODE]."\\newline\n".$phone."\\newline\n".$cc."\\newline\n";

	$orderdetails{$r->[ORDER_NUMBER]} = " received on ".$r->[ORDER_DATE];
	$discountamounts{$r->[ORDER_NUMBER]} = $r->[CART_DISCOUNT_AMOUNT];
	$totalitemcounts{$r->[ORDER_NUMBER]} = $r->[TOTAL_ITEMS];
	$totalpaid{$r->[ORDER_NUMBER]} = $r->[ORDER_TOTAL_AMOUNT];
	$phonecontacts{$r->[ORDER_NUMBER]} = $phone;
	$shortnames{$r->[ORDER_NUMBER]} = $fullname;
       
	push (@emailinfo, $r->[B_EMAIL].",".$fullname) unless grep{$_ eq $r->[B_EMAIL].",".$fullname } @emailinfo;	

    }

    # Banquet Dinner
    if ($r->[NAME] eq "Banquet Dinner") { 
    
	# Show each record field
	print "Order: #", $r->[ORDER_NUMBER]," ", $r->[ORDER_STATUS], " on ", $r->[ORDER_DATE], "\n";
	print "\t", $r->[B_FIRSTNAME]," ", $r->[B_LASTNAME],"\n";
	print "\t", $r->[SKU], " ", $r->[NAME],"\n\t";
#, $r->[VARIATION],"\n";
	print "\tQty:", $r->[QUANTITY], ", total price:", $r->[ITEM_COST], "\n";

	my $x = $r->[VARIATION];
	$x =~ s/\x{00E9}/e/g; # Remove special character e apostrophe
	my $yy = $x;
	my $str3_pat = quotemeta('|');
	my $str3_rep = ',';
	$yy =~ s/$str3_pat/$str3_rep/g;

	my @dinneritem = split  '|', $x;
	print @dinneritem;

	my $str2_pat = quotemeta('|');
	my $str2_rep = '\item';
	$x =~ s/$str2_pat/$str2_rep/g;

#	for my $menuitem ( @dinneritem ) {
#	    print "$menuitem\n";
#	}

	# Make a Csv file with all orders
	my $n;
	my $v;
	# For internal use
	my $ph = $r->[B_PHONE];
	my $fn = lc($r->[B_FIRSTNAME]);
	my $ln = lc($r->[B_LASTNAME]);
	$fn =~ s/(\w+)/\u$1/g;	
	$ln =~ s/(\w+)/\u$1/g;

	# Thanks Zaxo - http://www.perlmonks.org/bare/?node_id=259986
	# convert alpha mnemonics
	$ph =~ tr/A-PR-Z/222333444555666777888999/;
	$ph =~ tr/a-pr-z/222333444555666777888999/;    
	# get rid of any nondigits
	$ph =~ s/\D//g;    
	# format
	$ph =~ s/^(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;
	$ph =~ s/^(\d{3})(\d{4})$/$1-$2/; # no AC

	
	my $din_string = $r->[ORDER_NUMBER].",".$fn.",". $ln.",".$r->[B_EMAIL].",".$ph.",".$r->[QUANTITY];
	# For harris use
	my $din_string2 = $r->[ORDER_NUMBER].",".$r->[QUANTITY];
	
	my @dinneritem2 = split ',',$yy;	
	foreach my $k (@dinneritem2) {
	    ($n, $v) = split (':', $k);
	    $v =~ s/^\s+|\s+$//g;
	    if ( $v !~ /\s/ ) {
	    }
	    else {
		$v = "\"".$v."\"";
	    }
	    $din_string .= ",".$v;
	    $din_string2 .= ",".$v;	    
	}
	# Count up Totals
	my $dinner_selection = $r->[VARIATION];
	if ($dinner_selection ne "") {
	    
	    if ($dinner_selection =~ / Steak/) {
		$dc_steak += $r->[QUANTITY];		
	    }
	    if ($dinner_selection =~ / Chicken/) {
		$dc_chicken += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Vegetarian/) {
		$dc_vegetarian += $r->[QUANTITY];
	    }

	    if ($dinner_selection =~ / Strawberry/) {
		$dc_d_shortcake += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Chocolate/) {
		$dc_d_mousse += $r->[QUANTITY];
	    }

	    if ($dinner_selection =~ / Mushrooms/) {
		$dc_t_mushrooms += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ /naise/) {
		$dc_t_bearnaise += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Barbecue/) {
		$dc_t_barbeque += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Merlot/) {
		$dc_t_merlot += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Picatta/) {
		$dc_t_picatta += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Lemon/) {
		$dc_t_lemon_herb += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Marsala/) {
		$dc_t_marsala += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Glaciage/) {
		$dc_t_bleu_glaciage += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Butter/) {
		$dc_t_butter += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Alfredo/) {
		$dc_t_alfredo += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Marsala/) {
		$dc_t_marsala += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / None/) {
		$dc_t_none += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Port/) {
		$dc_t_port_wine += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Vinaigrette/) {
		$dc_sd_vinaigrette += $r->[QUANTITY];
	    }
	    if ($dinner_selection =~ / Ranch/) {
		$dc_sd_ranch += $r->[QUANTITY];
	    }
	
	}
	#	print "\n$v";
	#	print "Dinner:", $din_string, "\n";
	print BANQUETDINNERFILE $din_string,"\n";
	print BANQUETDINNERFILE2 $din_string2,"\n";	
	
	if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	    $dinner_count = $dinner_count +$r->[QUANTITY];
	    $dinner_funds = $dinner_funds + $r->[ITEM_COST];
	    $banquetdinners{$r->[ORDER_NUMBER]} .= " \\item Quantity ".$r->[QUANTITY]." Banquet Dinners (\\\$".$r->[ITEM_COST]." each) \n\\begin{itemize}\n \\item ".$x ."\n\\end{itemize}\n";
	}
	else {

	    $total_funds = $total_funds - $r->[ITEM_COST];
	}

    }
    # Blackrock Bistro Dinner
    if ($r->[NAME] =~ /Black Rock Bistro/) {
	if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	    $bb_dinner_count += $r->[QUANTITY];
	    $bb_dinner_funds += $r->[QUANTITY] * (15.00 - 0.74);
	    $blackrockbistroitems{$r->[ORDER_NUMBER]} = "Quantity ".$r->[QUANTITY]." Italian Dinners (\\\$".$r->[ITEM_COST]." each) - ".$r->[B_FIRSTNAME]." ".$r->[B_LASTNAME];

	}
    }
    
    # Registration
    if ($r->[NAME] eq "LDRS37 Registration") { 
    
	# Show each record field
	print "Order: #", $r->[ORDER_NUMBER]," ", $r->[ORDER_STATUS], " on ", $r->[ORDER_DATE], "\n";
	print "\t", $r->[B_FIRSTNAME]," ", $r->[B_LASTNAME],"\n";
	print "\t", $r->[SKU], " ", $r->[NAME],"\n\t", $r->[VARIATION],"\n";
	print "\tQty:", $r->[QUANTITY], ", total price:", $r->[ITEM_COST], "\n";;

	if ($r->[QUANTITY] > 1) {
	    push (@multiregistrationlist, $r->[B_EMAIL]."=[".$r->[QUANTITY]."]");
# unless grep{$_ == $r->[B_EMAIL]} @multiregistrationlist;
	}
	
	if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	    $registration_count = $registration_count +1;
	    $registration_funds = $registration_funds + $r->[ITEM_COST];
	    if ($r->[DISCOUNT_AMOUNT] ne "") { 
		$discounted_registrations = $discounted_registrations + $r->[DISCOUNT_AMOUNT];
		print "DISCOUNT: ", $r->[DISCOUNT_AMOUNT], "\n";
		$n_discounted_registrations = $n_discounted_registrations + 1;
	    }
	    $registrations{$r->[ORDER_NUMBER]} = "Quantity ".$r->[QUANTITY]." Registrations (\\\$".$r->[ITEM_COST]." each) - ".$r->[B_FIRSTNAME]." ".$r->[B_LASTNAME];
	}
	else {
	    $total_funds = $total_funds - $r->[ITEM_COST];
	}
    }
	
    # Shirt
    if ($r->[NAME] =~ /shirt/) { 
    
	# Show each record field
	print "Order: #", $r->[ORDER_NUMBER]," ", $r->[ORDER_STATUS], " on ", $r->[ORDER_DATE], "\n";
	print "\t", $r->[B_FIRSTNAME]," ", $r->[B_LASTNAME],"\n";
	print "\t", $r->[SKU], " ", $r->[NAME],"\n\t", $r->[VARIATION],"\n";
	print "\tQty:", $r->[QUANTITY], ", total price:", $r->[ITEM_COST], "\n";;

	if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	    $tshirt_count = $tshirt_count + $r->[QUANTITY];
	    $tshirt_funds = $tshirt_funds + $r->[ITEM_COST];

	    if ($r->[VARIATION] =~ / Small/) {
		$tshirt_sm = $tshirt_sm + $r->[QUANTITY];	    	    
	    }
	    if ($r->[VARIATION] =~ / Medum/) {
		$tshirt_m = $tshirt_m + $r->[QUANTITY];	    
	    }	
	    if ($r->[VARIATION] =~ / Medium/) {
		$tshirt_m = $tshirt_m + $r->[QUANTITY];	    	    
	    }
	    if ($r->[VARIATION] =~ / Large/) {
		$tshirt_l = $tshirt_l + $r->[QUANTITY];	    	    		
	    }
	    if ($r->[VARIATION] =~ / X-Large/) {
		$tshirt_xl = $tshirt_xl + $r->[QUANTITY];	    
	    }
	    if ($r->[VARIATION] =~ / 2X-Large/) {
		$tshirt_2xl = $tshirt_2xl + $r->[QUANTITY];	    
	    }
	    if ($r->[VARIATION] =~ / 3X-Large/) {
		$tshirt_3xl = $tshirt_3xl + $r->[QUANTITY];	    
	    }
	    if ($r->[VARIATION] =~ / 4X-Large/) {
		$tshirt_4xl = $tshirt_4xl + $r->[QUANTITY];	    
	    }
	    $tshirtorders{$r->[ORDER_NUMBER]} = "Quantity ".$r->[QUANTITY]." T-Shirt(s) (\\\$".$r->[ITEM_COST]." each) - ".$r->[VARIATION];
	}
    }

    # Sticker
    if ($r->[NAME] =~ /ticker/) { 
	# Show each record field
	print "Order: #", $r->[ORDER_NUMBER]," ", $r->[ORDER_STATUS], " on ", $r->[ORDER_DATE], "\n";
	print "\t", $r->[B_FIRSTNAME]," ", $r->[B_LASTNAME],"\n";
	print "\t", $r->[SKU], " ", $r->[NAME],"\n\t", $r->[VARIATION],"\n";
	print "\tQty:", $r->[QUANTITY], ", total price:", $r->[ITEM_COST], "\n";;
    if (($r->[ORDER_STATUS] ne "Refunded") && ($r->[ORDER_STATUS] ne "Cancelled")) {
	    $sticker_count = $sticker_count +$r->[QUANTITY];
	    $sticker_funds = $sticker_funds + $r->[ITEM_COST] * $r->[QUANTITY];
	    $stickerorders{$r->[ORDER_NUMBER]} = "Quantity ".$r->[QUANTITY]." Stickers (\\\$".$r->[ITEM_COST]." each) - Theme: LDRS-1".$r->[VARIATION];
	}
    }
    
}
close BANQUETDINNERFILE;
close BANQUETDINNERFILE2;

# Output Order file for printing
open(TEXFILE, ">./$TOPDIR/orders.tex") or die $!;
# Document setup
print TEXFILE "\\documentclass[letterpaper, 11pt]{article}\n";
print TEXFILE "\\usepackage{amsmath}\n";
print TEXFILE "\\usepackage{graphicx}\n";
print TEXFILE "\\usepackage[scaled]{helvet}\n";
#print TEXFILE "\\usepackage{showframe}\n";
print TEXFILE "\\renewcommand\\familydefault{\\sfdefault}\n";
print TEXFILE "\\usepackage[T1]{fontenc}\n";
print TEXFILE "\\usepackage{color}\n";
print TEXFILE "\\pagenumbering{gobble}\n\n";
print TEXFILE "\\begin{document}\n";

# Output Banquet tickets when we process orders where a dinner order was made
open(TEXFILE2, ">./$TOPDIR/banquet-tickets.tex") or die $!;
# Document setup
print TEXFILE2 "\\documentclass[letterpaper, 11pt]{article}\n";
print TEXFILE2 "\\usepackage{amsmath}\n";
print TEXFILE2 "\\usepackage{graphicx}\n";
print TEXFILE2 "\\usepackage[scaled]{helvet}\n";
print TEXFILE2 "\\renewcommand\\familydefault{\\sfdefault}\n";
print TEXFILE2 "\\usepackage[T1]{fontenc}\n";
print TEXFILE2 "\\usepackage{color}\n";
print TEXFILE2 "\\pagenumbering{gobble}\n\n";
print TEXFILE2 "\\begin{document}\n";


# Output Black Rock Bistro Italian Dinner tickets
open(TEXFILE3, ">./$TOPDIR/bistro-dinners.tex") or die $!;
# Document setup
print TEXFILE3 "\\documentclass[letterpaper, 11pt]{article}\n";
print TEXFILE3 "\\usepackage{amsmath}\n";
print TEXFILE3 "\\usepackage{graphicx}\n";
print TEXFILE3 "\\usepackage[scaled]{helvet}\n";
print TEXFILE3 "\\renewcommand\\familydefault{\\sfdefault}\n";
print TEXFILE3 "\\usepackage[T1]{fontenc}\n";
print TEXFILE3 "\\usepackage{color}\n";
print TEXFILE3 "\\pagenumbering{gobble}\n\n";
print TEXFILE3 "\\begin{document}\n";



# Now go through each logged order ID and generate
# the output .tex files
#foreach my $id(sort keys %registrations) {
foreach my $id(@orderlist) {
    my $dinner = $banquetdinners{$id};
    my $reg = $registrations{$id};
    my $shirts = $tshirtorders{$id};
    my $stickers = $stickerorders{$id};
    my $name = $ordertonames{$id};
    my $discounts = $discountamounts{$id};
    my $items = $totalitemcounts{$id};
    my $total = $totalpaid{$id};
    my $details = $orderdetails{$id};
    my $phone = $phonecontacts{$id};
    my $shortname = $shortnames{$id};
    my $bb_dinner = $blackrockbistroitems{$id};
    
    # Image header
#    print TEXFILE "\\makebox[\\textwidth]{\\includegraphics{images/tcc_tra_1.png}}\n";
    print TEXFILE "\\begin{center}\n";
    print TEXFILE "\\makebox[\\textwidth]{\\includegraphics[width=\\textwidth]{images/LDRS37-c.png}}\n";
    print TEXFILE "\\end{center}\n";
    print TEXFILE "\\section\* {Order $id $details} \\label{sec:Order $id $details}\n";
    print TEXFILE "$name\n";

    print " Order# $id\n";

    print TEXFILE "\\section\* {Itemized Listing} \\label{sec:Itemized Listing}\n";    
    print TEXFILE "\\begin{itemize}\n";
    
    if ($dinner) { 
	print TEXFILE "$dinner\n";
    	# Dinners - Only output dinner information if there is an order for one
#	print TEXFILE2 "\\pagecolor{green}\n\\color{white}\n";
	print TEXFILE2 "\\begin{center}\n";
	print TEXFILE2 "\\makebox[\\textwidth]{\\includegraphics[width=\\textwidth]{images/harris_1937.png}}\n";
	print TEXFILE2 "\\end{center}\n";
	print TEXFILE2 "\\section\* {LDRS37 Banquet Dinner Ticket $id } \\label{sec:LDRS37 Banquet Dinner Ticket $id }\n";

	print TEXFILE2 "\\#$id $shortname \\: $phone\n";
	print TEXFILE2 "\\begin{itemize}\n";
	print TEXFILE2 "$dinner\n";	
	print TEXFILE2 "\\end{itemize}\n";
	print TEXFILE2 "\\pagebreak\n";	
    }
    if ($bb_dinner) {
	print TEXFILE "\\item $bb_dinner\n";	

	# Italian Dinners - only output dinner info if there is an order for one
	print TEXFILE3 "\\begin{center}\n";
	print TEXFILE3 "\\makebox[\\textwidth]{\\includegraphics[width=\\textwidth]{images/Blackrock-bistro-1080p.png}}\n";
	print TEXFILE3 "\\end{center}\n";
	print TEXFILE3 "\\section\* {Black Rock Bistro Italian Dinner Ticket $id } \\label{sec:Black Rock Bistro Italian Dinner Ticket $id }\n";

	print TEXFILE3 "\\#$id $shortname \\: $phone\n";
	print TEXFILE3 "\\begin{itemize}\n";
	print TEXFILE3 "\\item $bb_dinner\n";	
	print TEXFILE3 "\\end{itemize}\n";
	print TEXFILE3 "\\pagebreak\n";	
    }
    if ($reg) { 
	print TEXFILE "\\item $reg\n";
    }
    if ($shirts) { 
	print TEXFILE "\\item $shirts\n";
    }
    if ($stickers) { 
	print TEXFILE "\\item $stickers\n";
    }

    print TEXFILE "\\end{itemize}\n";    

    print TEXFILE "$items items ordered\n";
    if ($discounts ne "0") {
	print TEXFILE "\\newline Discounts:\\\$",$discounts,"\n";
    }
    print TEXFILE "\\newline Total: \\\$", $total, " - Paid online via PayPal\n";

    print TEXFILE "\\pagebreak\n";
}
print TEXFILE "\\end{document}\n";
print TEXFILE2 "\\end{document}\n";

#output total for vendor
print TEXFILE3 "\\pagebreak\n";
print TEXFILE3 "Total dinners:", $bb_dinner_count, "\n";
print TEXFILE3 "\\newline Total funds (Minus \\\$0.74\/each Paypal fees): \\\$", $bb_dinner_funds, " - Paid online via PayPal\n";
print TEXFILE3 "\\end{document}\n";
close TEXFILE;
close TEXFILE2;
close TEXFILE3;



# Output Email Address list for Email Users plugin (to import)
print "Outputting Email database ...\n";
open(EMAILFILE, ">./$TOPDIR/emailusers.csv") or die $!;
print EMAILFILE "Email,Name\n";
foreach my $user (@emailinfo) {
    print EMAILFILE $user."\n";
}
close EMAILFILE;





$n_orders = scalar @orderlist;

# Do financial health check
#
# Paypal, the fee for each sale is 2.9% plus $0.30 USD

# Harris - the BOD fee is $775
# Harris - Deposit of $1000 required (applied to master account and used as a credit) - Mike Smith did end of 2017
# Harris - An 18% service charge and current sales tax will be added to all food and beverage charges. 
# California law requires that the service charge be subject to sales tax.
# Total meal obligation $3000
# Coalinga Tax Rate: 7.975% - 0.07975

print"\n\n====== LDRS37 ==========\n";
print $n_orders, " total orders\n";
print $n_discounted_registrations, " discounted registrations (\$", $discounted_registrations, " lost in discounted registrations)\n";

print "\$", $total_funds, " total monies received\n";

$paypal_fees = $total_funds * 0.029 + 0.30 * $n_orders;

print "\$", $paypal_fees, " Paypal fees\n";

$net_funds = $total_funds - $paypal_fees;
    
print "\$", $net_funds, " available (minus Paypal costs)\n";

print $dinner_count, " Banquet dinners\n";
print "\t\$", $dinner_funds, " funded\n";

print $bb_dinner_count, " Black Rock Bistro Saturday Night Italian dinners\n";
print "\t\$", $bb_dinner_funds, " funded\n";

print $registration_count, "  registrations\n";
print "\t\$", $registration_funds, " funded\n";
print "\t(\$", $discounted_registrations, ") total discounts (", $n_discounted_registrations, ")\n";
#$registration_funds = $registration_funds - $discounted_registrations;
print "\t\$", $registration_funds, " available\n";


print $tshirt_count, "  T-Shirts - S(", $tshirt_sm, "), M(", $tshirt_m, "), L(", $tshirt_l, "), XL(", $tshirt_xl, "), 2XL(", $tshirt_2xl, "), 3XL(", $tshirt_3xl, "), 4XL(", $tshirt_4xl, ")\n";

print "\t\$", $tshirt_funds, " funded \n";
#print "", ($tshirt_sm + $tshirt_m + $tshirt_l + $tshirt_xl + $tshirt_2xl + $tshirt_3xl + $tshirt_4xl), " total\n";

print $sticker_count, "  Stickers\n";
print "\t\$", $sticker_funds, " funded\n";

my $harris_fees = 0;
$harris_fees = 775 + $dinner_funds * 0.18 + $dinner_funds * 0.07975;
print "\n======= Harris Banquet =========\n";
print "Total meal obligations: \$", $dinner_funds, " (", $dinner_count, " total meals)\n";
print "(\$", $harris_fees, ") Harris costs (Taxes and Board room)\n";
$harris_fees = $harris_fees + $dinner_funds;
print "(\$", $harris_fees, ") Total Harris costs\n";
$harris_fees = $harris_fees - 1000;
print "\$1000 Deposit - Mike Smith, Jan 2018 - TCC Credit/Reservation\n";
print "(\$", $harris_fees, ") Total Harris costs\n";


if ($dinner_funds < 3000) { 
    print "\t\$", (3000 - $dinner_funds), " more needed (", (3000 - $dinner_funds)/40, " meals)\n";
}
print "\n======= Launch Costs  =========\n";
print "(\$191.50) - Range setup supplies (Paint, Yellow Tape)\n";
$net_funds = $net_funds - 191.50;

print "(\$378.00) - Stickers (LDRS, TCC, LDRS/TCC, Custom Wristbands)\n";
$net_funds = $net_funds - 378.00;

print "(\$223.88) - LDRS37 Rocket (Avalanche) x2 - Raffle Prizes\n";
$net_funds = $net_funds - 223.88;
print "(\$931.40)  - 80/20 Rails for all pads\n";
$net_funds = $net_funds - 931.40;
print "(\$307.80)  - New EZ-Up for TCC\n";
$net_funds = $net_funds - 307.80 ;
print "(\$307.80)  - 2nd New EZ-Up for TCC\n";
$net_funds = $net_funds - 307.80 ;
print "(\$3076.79) - T-Shirts & Hats - 200:14S,16M,54L,72XL,28XL2,12XL3,4XL4,50Caps\n";
$net_funds = $net_funds - 3096.79;
print "(\$120.51)  - EZ-Up Banners\n";
$net_funds = $net_funds - 120.51;
print "(\$323.01)  - Badges\n";
$net_funds = $net_funds - 323.01;
print "(\$500.00)  - Bags and Lanyards\n";
$net_funds = $net_funds - 500.00;
print "(\$268.90)  - Lapel Pins - Certification (x100)\n";
$net_funds = $net_funds - 268.90;

print "(\$143.97)  - ABC Fire Extinguishers (x3)\n";
$net_funds = $net_funds - 143.97;

print "(\$627.44)  - Black Rock Bistro Funds\n";
$net_funds = $net_funds - 627.44;


print "\+\$700.00  - TRA Pays for Conference rooms\n";
$net_funds = $net_funds + 700.00;

print "\n=======================\n";

print "\$", ($net_funds - $harris_fees), " TOTAL PROFIT (TCC Covers Taxes/Setup & Board Rooms at Harris)\n";


print "\n\nDuplicate Registrations: @multiregistrationlist\n"; 

print "\nHarris Ranch Dinners\n";
print   "====================\n";
print "\tMain courses: Steak\(",$dc_steak,"\) Chicken\(",$dc_chicken,"\) Vegetarian\(",$dc_vegetarian,"\)\n";
print "\tDesserts: Strawberry Shortcake\(", $dc_d_shortcake, "\) Chocolate Mousse\(", $dc_d_mousse, "\)\n";
print "\tSauces\n";
print "\t======\n";
print "\tSauteed Mushrooms:", $dc_t_mushrooms,"\n";
print "\tBearnaise Sauce:", $dc_t_bearnaise,"\n";
print "\tBarbeque Sauce:", $dc_t_barbeque,"\n";
print "\tMerlot Sauce:", $dc_t_merlot,"\n";
print "\tPicatta Sauce:", $dc_t_picatta,"\n";
print "\tLemon Herb:", $dc_t_picatta,"\n";
print "\tMarsala Sauce:", $dc_t_marsala,"\n";
print "\tBleu Cheese Glaciage:", $dc_t_bleu_glaciage,"\n";
print "\tButter:", $dc_t_butter,"\n";
print "\tAlfredo:", $dc_t_alfredo,"\n";
print "\tMarsala:", $dc_t_marsala,"\n";
print "\tPort Wine:", $dc_t_port_wine,"\n";
print "\tNone:", $dc_t_none,"\n";
print "Salad Dressings: Ranch\(", $dc_sd_ranch, "\) Basil Vinaigrette\(", $dc_sd_vinaigrette, "\)\n";



