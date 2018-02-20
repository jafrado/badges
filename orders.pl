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


my @multiregistrationlist;
my @orderlist;

# Order hashes, for each order, we use 3 associative arrays indexed by order #
# tshirts, registrations, banquets, stickers
# This way we can group all orders together
my %tshirtorders = ();
my %registrations = ();
my %banquetdinners = ();
my %stickerorders = ();
my %ordertonames = ();
my %discountamounts = ();
my %totalitemcounts = ();
my %totalpaid = ();

# Top-level directory where images will be dumped
my $TOPDIR = "orders/";

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

# Process each CSV line record
for my $r (@rows) {
    # gather row
    $csv->combine(@$r);

    if ($r->[ORDER_STATUS] ne "Refunded") {    
	# push up order # into list of orders, don't add the order if it's in there already ...
	push (@orderlist, $r->[ORDER_NUMBER]) unless grep{$_ == $r->[ORDER_NUMBER]} @orderlist;

	# add up the cost of each item ordered
	$total_funds = $total_funds + $r->[ITEM_COST];

	# People may have # in their street name, escape for Latex
	my $str1_pat = quotemeta('#');
	my $str1_rep = '\#';
	$r->[B_ADDR12] =~ s/$str1_pat/$str1_rep/g;

	$ordertonames{$r->[ORDER_NUMBER]} = "\n\n".$r->[B_FIRSTNAME]." ".$r->[B_LASTNAME]."\\newline\n".$r->[B_ADDR12]."\\newline\n".$r->[B_CITY].",".$r->[B_STATE]." ".$r->[B_ZIPCODE]."\\newline\n".$r->[B_CC]."\\newline\n";
	
	$discountamounts{$r->[ORDER_NUMBER]} = $r->[CART_DISCOUNT_AMOUNT];
	$totalitemcounts{$r->[ORDER_NUMBER]} = $r->[TOTAL_ITEMS];
	$totalpaid{$r->[ORDER_NUMBER]} = $r->[ORDER_TOTAL_AMOUNT];
    }

    # Banquet Dinner
    if ($r->[NAME] eq "Banquet Dinner") { 
    
	# Show each record field
	print "Order: #", $r->[ORDER_NUMBER]," ", $r->[ORDER_STATUS], " on ", $r->[ORDER_DATE], "\n";
	print "\t", $r->[B_FIRSTNAME]," ", $r->[B_LASTNAME],"\n";
	print "\t", $r->[SKU], " ", $r->[NAME],"\n\t";
#, $r->[VARIATION],"\n";
	print "\tQty:", $r->[QUANTITY], ", total price:", $r->[ITEM_COST], "\n";;

	my $x = $r->[VARIATION];
	$x =~ s/\x{00E9}/e/g; # Remove special character e apostrophe


	my @dinneritem = split  '|', $x;
	print @dinneritem;

	my $str2_pat = quotemeta('|');
	my $str2_rep = '\item';
	$x =~ s/$str2_pat/$str2_rep/g;
	
#	for my $menuitem ( @dinneritem ) {
#	    print "$menuitem\n";
#	}
	
	
	if ($r->[ORDER_STATUS] ne "Refunded") {
	    $dinner_count = $dinner_count +1;
	    $dinner_funds = $dinner_funds + $r->[ITEM_COST];
	    $banquetdinners{$r->[ORDER_NUMBER]} .= " \\item Quantity ".$r->[QUANTITY]." Banquet Dinners (\\\$".$r->[ITEM_COST]." each) \n\\begin{itemize}\n \\item ".$x ."\n\\end{itemize}\n";
	}
	else {

	    $total_funds = $total_funds - $r->[ITEM_COST];
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
	
	if ($r->[ORDER_STATUS] ne "Refunded") {
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

	if ($r->[ORDER_STATUS] ne "Refunded") {
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
	if ($r->[ORDER_STATUS] ne "Refunded") {
	    $sticker_count = $sticker_count +1;
	    $sticker_funds = $sticker_funds + $r->[ITEM_COST];
	    $stickerorders{$r->[ORDER_NUMBER]} = "Quantity ".$r->[QUANTITY]." Stickers (\\\$".$r->[ITEM_COST]." each) - Theme: LDRS-1".$r->[VARIATION];
	}
    }
    
}

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

print $registration_count, "  registrations\n";
print "\t\$", $registration_funds, " funded\n";
print "\t\$", $discounted_registrations, " total discounts (", $n_discounted_registrations, ")\n";
$registration_funds = $registration_funds - $discounted_registrations;
print "\t\$", $registration_funds, " available\n";


print $tshirt_count, "  T-Shirts - S(", $tshirt_sm, "), M(", $tshirt_m, "), L(", $tshirt_l, "), XL(", $tshirt_xl, "), 2XL(", $tshirt_2xl, "), 3XL(", $tshirt_3xl, "), 4XL(", $tshirt_4xl, ")\n";

print "\t\$", $tshirt_funds, " funded \n";
#print "", ($tshirt_sm + $tshirt_m + $tshirt_l + $tshirt_xl + $tshirt_2xl + $tshirt_3xl + $tshirt_4xl), " total\n";




print $sticker_count, "  Stickers\n";
print "\t\$", $sticker_funds, " funded\n";



my $harris_fees = 0;
$harris_fees = 775 + $dinner_funds * 0.18 + $dinner_funds * 0.07975;

print "\$", $harris_fees, " Harris cost\n";

print "Total meal obligations: \$3000\n";

if ($dinner_funds < 3000) { 
    print "\t\$", (3000 - $dinner_funds), " more needed (", (3000 - $dinner_funds)/40, " meals)\n";
}


print "\$", ($net_funds - ($harris_fees + 3000 - $dinner_funds)), " TOTAL PROFIT (TCC Covers remaining Meal obligations)\n";


print "\n\nDuplicate Registrations: @multiregistrationlist\n"; 

# Print all dinners by ID
# Now generate a PDF file with each order, one per page, with data listing

open(TEXFILE, ">./$TOPDIR/orders.tex") or die $!;

# Document setup
print TEXFILE "\\documentclass[letterpaper, 11pt]{article}\n";
print TEXFILE "\\usepackage{amsmath}\n";
print TEXFILE "\\usepackage{graphicx}\n";
print TEXFILE "\\usepackage[scaled]{helvet}\n";
print TEXFILE "\\renewcommand\\familydefault{\\sfdefault}\n";
print TEXFILE "\\usepackage[T1]{fontenc}\n";
print TEXFILE "\\pagenumbering{gobble}\n\n";
print TEXFILE "\\begin{document}\n";

foreach my $id(sort keys %registrations) {
    my $dinner = $banquetdinners{$id};
    my $reg = $registrations{$id};
    my $shirts = $tshirtorders{$id};
    my $stickers = $stickerorders{$id};
    my $name = $ordertonames{$id};
    my $discounts = $discountamounts{$id};
    my $items = $totalitemcounts{$id};
    my $total = $totalpaid{$id};

    # Image header
    print TEXFILE "\\begin{center}\n";
    print TEXFILE "\\makebox[\\textwidth]{\\includegraphics[width=\\textwidth]{images/LDRS37-c.png}}\n";
    print TEXFILE "\\end{center}\n";

    print TEXFILE "\\section\* {Order $id} \\label{sec:Order $id}\n";

    print TEXFILE "$name\n";

    print " Order# $id\n";
    print TEXFILE "\\begin{itemize}\n";
    
    if ($dinner) { 
	print TEXFILE "$dinner\n";
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
    print TEXFILE "\\newline Total:\\\$", $total, "\n";

    print TEXFILE "\\pagebreak\n";
}
print TEXFILE "\\end{document}\n";

close TEXFILE;


