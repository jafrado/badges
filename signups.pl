#!/usr/bin/perl
# 
# signups.pl - generate PDF summary of Range duty sign-ups from SignupSheets 
# https://www.dlssoftwarestudios.com/downloads/sign-up-sheets-wordpress-plugin/
# 
# Usage: signups.pl <csv_file>
# 
# Copyright (C) 2018 James F Dougherty <jfd@realflightsystems.com>
# 

# Dep libs
use strict;
use warnings;
use Text::CSV;
use LWP::Simple;
use utf8;
use DateTime::Format::ISO8601;

#
# Format of Datafile
#

#"Sheet ID","Sheet Title","Sheet Date","Task ID","Task Title","Sign-up ID","Sign-up First Name","Sign-up Last Name","Sign-up Phone","Sign-up Email"
    
# Offsets into CSV file for each row of data below
use constant SHEET_ID => 0;
use constant SHEET_TITLE =>1;
use constant SHEET_DATE => 2;
use constant TASK_ID => 3;
use constant TASK_TITLE => 4;
use constant SIGNUP_ID  => 5;
use constant SIGNUP_FN => 6;
use constant SIGNUP_LN  => 7;
use constant SIGNUP_PN => 8;
use constant SIGNUP_EM => 9;

# Top-level directory where images will be dumped
my $TOPDIR = "signups/";

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

# Variables
my @sheetlist;

my %signups = ();

# Skip past headers (first line), load CSV file into rows of data
my $header = $csv->getline($data);
while (my $row = $csv->getline($data)) {
	push @rows, $row;
}

# Sort by sheet ID
@rows = sort { $a->[SHEET_ID] <=> $b->[SHEET_ID] } @rows;
# Sort by tasks
@rows = sort { $a->[TASK_ID] <=> $b->[TASK_ID] } @rows;
# Sort by date
@rows = sort { DateTime::Format::ISO8601->parse_datetime($a->[SHEET_DATE]) <=> DateTime::Format::ISO8601->parse_datetime($b->[SHEET_DATE]) } @rows;

# Sort by title
#@rows = sort { $a->[SHEET_TITLE] lt $b->[SHEET_TITLE] } @rows;
#@rows = sort { $a->[TASK_TITLE] lt $b->[TASK_TITLE] } @rows;

open(TEXFILE, ">./$TOPDIR/range-duty.tex") or die $!;

print TEXFILE "\\documentclass[letterpaper, 8pt]{article}\n";
print TEXFILE "\\usepackage[english]{babel}\n";
print TEXFILE "\\usepackage{amsmath}\n";
print TEXFILE "\\usepackage{graphicx}\n";
print TEXFILE "\\usepackage[scaled]{helvet}\n";
print TEXFILE "\\renewcommand\\familydefault{\\sfdefault}\n";
print TEXFILE "\\usepackage[T1]{fontenc}\n";
print TEXFILE "\\usepackage{color}\n";
print TEXFILE "\\pagenumbering{gobble}\n";
print TEXFILE "\\begin{document}\n";

my $startdate ="";
my $pagecounter = 0;
my $linecounter = 0;

# For each entry, print out table
for my $r (@rows) {
    # gather row
    $csv->combine(@$r);

    # push up order # into list of orders, don't add the order if it's in there already ...
    push (@sheetlist, $r->[SHEET_ID]) unless grep{$_ == $r->[SHEET_ID]} @sheetlist;

    my $k = $r->[TASK_ID];
    if (($startdate ne $r->[SHEET_DATE])) { # || ($linecounter >= 30)) {
	$linecounter = 0;
	if ($pagecounter > 0) {
	    print TEXFILE "\\end{tabular}\n";
	    print TEXFILE "\\end{center}\n";
	}
	
	print TEXFILE "\\pagebreak\n";
	print TEXFILE "\\begin{center}\n";
	print TEXFILE "\\makebox[\\textwidth]{\\includegraphics[width=\\textwidth]{images/LDRS37-c.png}}\n";
	print TEXFILE "\\end{center}\n";
	print TEXFILE "\\begin{center}\n";
	print TEXFILE "\\section\* {$r->[SHEET_TITLE] $r->[SHEET_DATE]} \\label{sec:$r->[SHEET_TITLE] $r->[SHEET_DATE]}\n";    	
	print $r->[SHEET_TITLE]." ".$r->[SHEET_DATE]."\n";
	print "-------------------------------------------------------\n";
	print TEXFILE "\\begin{tabular}{ | l | l | l |}\n";
	print TEXFILE "\\hline\n";
	print TEXFILE "Range Duty & Name & Phone \\\\ \\hline\n";

	$pagecounter++;
    }
    if (($r->[SIGNUP_FN]) && ($r->[SIGNUP_PN])) { 
	# First Name Convert upper case to lower
	my $fullname = lc($r->[SIGNUP_FN]." ".$r->[SIGNUP_LN]);
	# Capitalize first letter of each word
	$fullname =~ s/(\w+)/\u$1/g;

	# Normalize US Phone numbers to (408) 867-5309 , else leave sequence as-is ...
	my $phone = $r->[SIGNUP_PN];
	# Thanks Zaxo - http://www.perlmonks.org/bare/?node_id=259986
	# convert alpha mnemonics
	$phone =~ tr/A-PR-Z/222333444555666777888999/;
	$phone =~ tr/a-pr-z/222333444555666777888999/;    
	# get rid of any nondigits
	$phone =~ s/\D//g;    
	# format
	$phone =~ s/^(\d{3})(\d{3})(\d{4})$/($1) $2-$3/;
	$phone =~ s/^(\d{3})(\d{4})$/$1-$2/; # no AC

	$signups{$k} = $r->[TASK_TITLE]." - ".$fullname.":".$phone;
	print TEXFILE "$r->[TASK_TITLE] & $fullname & $phone\\\\ \\hline\n";
    }
    else { 
	$signups{$k} = $r->[TASK_TITLE];
	print TEXFILE "$r->[TASK_TITLE] &  & \\\\ \\hline\n";	
    }
    $startdate = $r->[SHEET_DATE];
    $linecounter++;
    
    #    print $fullname,":",$phone,"\n";
    print $signups{$r->[TASK_ID]}, "\n";

}
      

#foreach my $i (reverse sort { $b <=> $a } keys %signups) {

#    print $signups{$i}, "\n";
#}

print TEXFILE "\\end{tabular}\n";
print TEXFILE "\\end{center}\n";

print TEXFILE "\\end{document}\n";
close TEXFILE;
