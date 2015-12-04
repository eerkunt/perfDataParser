#!/usr/bin/perl
#
# perfDataParser    - This script reads Performance XML data files generated from Ericsson devices
#                     and converts them based on <measData> tags into CSV files. CSV files to be used
#                     by Optima.
#
# Author              Emre Erkunt   <emre.erkunt at gmail.com>
# History :
# -----------------------------------------------------------------------------------------------
# Version               Contributer     Date            Description
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# 0.0.1 Beta            eerkunt         20151204        Initial Beta Release
#
# Dependencies :
# - Getopt::Std Perl module ( if you don't have this module already, you have serious problems )
#
use strict;
no warnings 'deprecated';
use Getopt::Std;
use UNIVERSAL 'isa';

$| = 1;
my $version     = "0.0.1 Beta";
my $progName    = "perfDataParser";
my $arguments   = "i:o:d:vhs";
my %opt;
getopts( $arguments, \%opt) or usage();
print $progName." v".$version."\n" unless ($opt{s});
usage() unless ($opt{i});
usage() if ($opt{h});
$opt{d} = ";" unless ($opt{d});
$opt{o} = $opt{i}.".csv" unless ($opt{o} and $opt{s});
$opt{d} .= " ";

print "< Opening file ".$opt{i}." as read-only." if ($opt{v});
open(INPUT, $opt{i}) or die ("Can not read ".$opt{i});
print "Ok!\n" if ($opt{v});

my %myData;

my $startTag      = "measData";
my $firstColumn   = "\s*<managedElement localDn=\"(.*)\"\/>";
my $endTime       = "<granPeriod duration=\".*\" endTime=\"(.*)\"\/>";
                    #      <measType p="0">AverageSipDialogLifetime.actual</measType>
my $headerRegex   = '\s*<measType p="(\d*)">(.*)</measType>';
my $dataStart     = "measValue";
my $dataRegex     = '<r p="(\d*)">(.*)</r>';

my $followHeader = 0;
my $followData = 0;
my $currentIndex = 0;

while(<INPUT>) {
      print "DEBUG :".$_ if ( $opt{v});
      if ( $_ =~ /<$startTag>/ && $followHeader eq 0 ) {
      # Start parsing the headers
          $followHeader = 1;
          print "> (".$currentIndex.") Started parsing..\n" if ( $opt{v} );
      } elsif ( $_ =~ /<\/$startTag>/ && $followHeader eq 1 ) {
      # End parsing the headers
          $followHeader = 0;
          $currentIndex = "";
          print "> (".$currentIndex.") Finished parsing..\n" if ($opt{v});
      } elsif ( $_ =~ /$firstColumn/ && $followHeader eq 1 ) {
      # Find the first column of the CSV, this should be the identifier
          if ( !isa($myData{"0##Managed_Element"}, 'ARRAY') ) {
              print "Creating Managed_Element array." if ($opt{v});
              $myData{"0##Managed_Element"} = [];
          }
          push(@{$myData{"0##Managed_Element"}}, "\"".$1."\"");
          $currentIndex++;
          print "> (".$currentIndex.") Found first Column : ".$1."\n" if ($opt{v});
      } elsif ( $_ =~ /$endTime/ && $followHeader eq 1) {
      # Find the datetime column of the CSV
          if ( !isa($myData{"1##Date"}, 'ARRAY') ) {
              print "Creating date array." if ($opt{v});
              $myData{"1##Date"} = [];
          }
          push(@{$myData{"1##Date"}}, "\"".$1."\"");
          print "> (".$currentIndex.") Found datetime Column : ".$1."\n" if ( $opt{v});
      } elsif ( $_ =~ /$headerRegex/ && $followHeader eq 1) {
      # Append the headers into header array
          if ( !isa($myData{"D".$1."##".$2}, 'ARRAY') ) {
              print "Creating $1 array." if ($opt{v});
              $myData{"D".$1."##".$2} = [];
          }
          # push(@{$myData{$2}}, $2);
          print "> (".$currentIndex.") Added new header : [".$1."] = ".$2."\n" if ($opt{v});
      } elsif ( $_ =~ /<$dataStart.*>/ && $followHeader eq 1) {
      # Follow up the data part
          $followData = 1;
          print "> (".$currentIndex.") Started data parsing..\n" if ($opt{v});
      } elsif ( $_ =~ /<\/$dataStart>/ && $followData eq 1) {
      # Finish parsing of data part
          $followData = 0;
          print "> (".$currentIndex.") Finished data parsing..\n" if ( $opt{v} );
      } elsif ( $_ =~ /$dataRegex/ && $followData eq 1) {
      # Parse the data, match it with headers IDs and add into data array
          print "> (".$currentIndex.") Adding new data : [".$1."] = ".$2."\n" if ($opt{v});
          my $id = $1;
          my $value = $2;
          my $matchedKey = "";
        	foreach my $key (sort keys %myData) {
              if ( $key =~ /^D$id##.*$/) {
                $matchedKey = $key;
                print "> Matched with key : ".$matchedKey."\n" if ($opt{v});
              }
          }
          if ( $matchedKey ) {
              push(@{$myData{$matchedKey}}, $value);
          } else {
              print "XML Error! Can not match Data Value with any Header Key!\n";
          }
      }
}
print "Reading file done. Creating output." if ($opt{v});
# First create an array of CSV file ( line in each element )
# Output that file to STDOUT or given file based on arguments
my @output;
my @headerArray;
my $elementCount = 0;
foreach my $headerElement ( sort keys %myData ) {
    my ($id, $header) = split("##", $headerElement);
    push(@headerArray, $header);
    $elementCount = scalar ( @{$myData{$headerElement}} );
}
$output[0] = join($opt{d}, @headerArray );
print "Total number of ".$elementCount." rows.\n" unless ($opt{s});
for(my $i=0; $i<$elementCount; $i++) {
    my @dataOutput;
    foreach my $headerElement ( sort keys %myData ) {
        push(@dataOutput, $myData{$headerElement}[$i]);
    }
    push(@output, join($opt{d}, @dataOutput));
}
# print Dumper(@data);
if ( $opt{o} ) {
  open(OUTPUT, "> ".$opt{o}) or die("Can not open $opt{o} for writing.");
}
foreach my $row ( @output ) {
    print $row."\n" if ($opt{s});
    print OUTPUT $row."\n" if ( $opt{o});
}
close(OUTPUT) if ($opt{o});

sub usage {
		my $usageText = << 'EOF';

This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

Author            Emre Erkunt
                  (emre.erkunt et gmail.com)

Usage : perfDataParser [-i INPUT FILE] [-o OUTPUT FILE] [-d DELIMETER] [-s] [-v] [-h]

 Parameter Descriptions :
 -i [INPUT FILE]        Ericsson Devices' Performance XML File             ** MANDATORY **
 -o [OUTPUT FILE]       Output file about results.
 -s                     Outputs to STDOUT instead of writing into CSV file
 -d [DELIMETER]         Delimeter that will be used in CSV file.           ( Default is ; )
 -v                     Disable verbose                                    ( Default OFF )
 -h                     Shows this help

EOF
		print $usageText;
		exit;
}   # usage()
