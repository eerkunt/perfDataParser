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
# 0.0.2                 eerkunt         20151210        Configuration file support
#                                                       Removed single file processing
#                                                       Added InputDir config directive
#                                                       Added OutputDir config directive
#                                                       Added config sanity check
#                                                       Added InputFileMask directive
#                                                       Added Delimeter directive
# 0.0.3                 eerkunt         20150215        Added logging capability
#                                                       Added PID file support
#                                                       Added TruncateHeaders directive
#                                                       Added InputFileNameAsColumn directive
#                                                       Added BackupAfterParse directive
#
# Dependencies :
# - Getopt::Std Perl module ( if you don't have this module already, you have serious problems )
# - Log::Log4perl           ( you can install this module via cpan )
# - File::Copy              ( Same problem with Getopt::Std )
#

use strict;
use warnings;
no warnings 'deprecated';
use Getopt::Std;
use UNIVERSAL 'isa';
use Log::Log4perl qw(:easy);
use POSIX qw(strftime);
use File::Copy;

$| = 1;
my $version     = "0.0.3";
my $progName    = "perfDataParser";
my $arguments   = "c:h";
my %opt;
getopts( $arguments, \%opt) or usage();
print $progName." v".$version."\n" unless ($opt{s});
usage() unless ($opt{c});
usage() if ($opt{h});

#
# Reading Configuration File
my %conf;
open(CONFIG, $opt{c}) or die("Can not read ".$opt{c});
while(<CONFIG>) {
    if ( $_ =~ /^#/ ) {
        next;
    } elsif ( $_ =~ /^InputDir=(.*)/i ) {
        $conf{input}{dir} = $1;
    } elsif ( $_ =~ /^OutputDir=(.*)/i ) {
        $conf{output}{dir} = $1;
    } elsif ( $_ =~ /^BackupDir=(.*)/i ) {
        $conf{backup}{dir} = $1;
    } elsif ( $_ =~ /^LogDir=(.*)/i ) {
        $conf{log}{dir} = $1;
    } elsif ( $_ =~ /^PRID=(.*)/i ) {
        $conf{main}{prid} = $1;
    } elsif ( $_ =~ /^InputFileMask=(.*)/i ) {
        $conf{input}{mask} = $1;
    } elsif ( $_ =~ /^TruncateHeader=([01])/i ) {
        $conf{output}{truncateHeader} = $1;
    } elsif ( $_ =~ /^BackupAfterParse=([01])/i ) {
        $conf{backup}{backupAfterParse} = $1;
    } elsif ( $_ =~ /^LogSeverity=(.*)/i ) {
        $conf{log}{severity} = $1;
    } elsif ( $_ =~ /^Delimeter=['"](.*)['"]/i ) {
        $conf{output}{delimeter} = $1;
    } elsif ( $_ =~ /^InputFileNameAsColumn=([01])/i ) {
        $conf{output}{fileAsColumn} = $1;
    } elsif ( $_ =~ /^PIDFilePath=(.*)/i ) {
        $conf{main}{pidPath} = $1;
    }
}
close(CONFIG);

#
# Configuration consistency check
die("Can not find InputDir configuration directive in $opt{c}.") unless ($conf{input}{dir});
die("Can not find OutputDir configuration directive in $opt{c}.") unless ($conf{output}{dir});
die("Can not find BackupDir configuration directive in $opt{c}.") unless ($conf{backup}{dir});
die("Can not find LogDir configuration directive in $opt{c}.") unless ($conf{log}{dir});
die("Can not find PRID configuration directive in $opt{c}.") unless ($conf{main}{prid});
die("Can not find PIDFilePath configuration directive in $opt{c}.") unless ($conf{main}{pidPath});
unless ( $conf{log}{severity} ) {
    $conf{log}{severity} = "INFO";
    # print "Can not find LogSeverity configuration directive in $opt{c}. Using ".$conf{log}{severity}." level severity in logging as default.\n";
}

#
# Create related directories if they doesn't exist
if ( ! -d $conf{output}{dir}) { mkdir($conf{output}{dir}); }
if ( ! -d $conf{backup}{dir} and $conf{backup}{backupAfterParse} ) { mkdir($conf{backup}{dir}); }
if ( ! -d $conf{log}{dir}) { mkdir($conf{log}{dir}); }

#
# Init PID file
my $pidFile = $conf{main}{pidPath}."/".$conf{main}{prid}.".pid";
die "Already running!" if ( -e $pidFile );
open(PID, ">".$pidFile) or die "Can not create PID file on $pidFile";
close(PID);

#
# Initialize logging facility
my $now = strftime "%Y%m%d-%H:%M:%S", localtime;
my $logFilename = $conf{log}{dir}."/".$progName."_".$now."_".$conf{main}{prid}.".log";
my $logger = Log::Log4perl->easy_init( {   level   => $conf{log}{severity},
                                        file    => $logFilename },
                                        layout  => '[%d] (%P) %p %m{chomp}%n');
INFO "$progName v".$version." has been initiated.";
unless ( $conf{input}{mask} ) {
    $conf{input}{mask} = ".*";
    WARN "Can not find InputFileMask configuration directive in $opt{c}. Using ".$conf{input}{mask}." as default mask.";
}
unless ( $conf{output}{truncateHeader} ) {
    $conf{output}{truncateHeader} = 0;
    WARN "Can not find TruncateHeader configuration directive in $opt{c}. Will NOT truncate headers as default.";
}
unless ( $conf{backup}{backupAfterParse} ) {
    $conf{backup}{backupAfterParse} = 0;
    WARN "Can not find BackupAfterParse configuration directive in $opt{c}. Will NOT backup original files after parse process.";
}

unless ( $conf{output}{delimeter} ) {
    $conf{output}{delimeter} = ";";
    WARN "Can not find Delimeter configuration directive in $opt{c}. Using '".$conf{output}{delimeter}."' delimeter in output files as default.";
}
unless ( $conf{output}{fileAsColumn} ) {
    $conf{output}{fileAsColumn} = 0;
    WARN "Can not find InputFileNameAsColumn configuration directive in $opt{c}. Input files will not exist as a column in output files as default.";
}

opendir(INPUTDIR, $conf{input}{dir}) or die("Can not open directory ".$conf{input}{dir});
my $inputFileMask = $conf{input}{mask};
my @inputFiles = grep { /$inputFileMask/ && -f $conf{input}{dir}."/$_" } readdir(INPUTDIR);
close(INPUTDIR);

INFO "Total number of ".scalar @inputFiles." files will be processed.";
for (@inputFiles) {
    chomp($_);
    DEBUG "-> $_ will be processed";
}

for (@inputFiles) {
    print ".";
    chomp($_);
    my $currentFilename = $_;
    INFO "Processing ".$currentFilename;
    DEBUG "Opening file ".$currentFilename." as read-only.";
    open(INPUT, $conf{input}{dir}."/".$currentFilename) or die ("Can not read ".$currentFilename);
    DEBUG "Successfuly opened file ".$currentFilename." as read-only.";

    my %myData;

    my $startTag      = "measData";
    my $firstColumn   = '\s*<managedElement localDn=\"(.*)\"\/>';
    my $endTime       = "<granPeriod duration=\".*\" endTime=\"(.*)\"\/>";
                        #      <measType p="0">AverageSipDialogLifetime.actual</measType>
    my $headerRegex   = '\s*<measType p="(\d*)">(.*)</measType>';
    my $dataStart     = "measValue";
    my $dataRegex     = '<r p="(\d*)">(.*)</r>';

    my $followHeader = 0;
    my $followData = 0;
    my $currentIndex = 0;

    while(<INPUT>) {
          TRACE $_;
          if ( $_ =~ /<$startTag>/ && $followHeader eq 0 ) {
          # Start parsing the headers
              $followHeader = 1;
              DEBUG "(".$currentIndex.") Started parsing..";
          } elsif ( $_ =~ /<\/$startTag>/ && $followHeader eq 1 ) {
          # End parsing the headers
              $followHeader = 0;
              $currentIndex = "";
              DEBUG "(".$currentIndex.") Finished parsing..";
          } elsif ( $_ =~ /$firstColumn/ && $followHeader eq 1 ) {
          # Find the first column of the CSV, this should be the identifier
              if ( !isa($myData{"0##Managed_Element"}, 'ARRAY') ) {
                  DEBUG "Creating Managed_Element array.";
                  $myData{"0##Managed_Element"} = [];
              }
              push(@{$myData{"0##Managed_Element"}}, "\"".$1."\"");
              $currentIndex++;
              DEBUG "(".$currentIndex.") Found first Column : ".$1;
          } elsif ( $_ =~ /$endTime/ && $followHeader eq 1) {
          # Find the datetime column of the CSV
              if ( !isa($myData{"1##Date"}, 'ARRAY') ) {
                  DEBUG "Creating date array.";
                  $myData{"1##Date"} = [];
              }
              push(@{$myData{"1##Date"}}, "\"".$1."\"");
              DEBUG "(".$currentIndex.") Found datetime Column : ".$1;
          } elsif ( $_ =~ /$headerRegex/ && $followHeader eq 1) {
          # Append the headers into header array
              if ( !isa($myData{"D".$1."##".$2}, 'ARRAY') ) {
                  DEBUG "Creating $1 array.";
                  $myData{"D".$1."##".$2} = [];
              }
              DEBUG "(".$currentIndex.") Added new header : [".$1."] = ".$2;
          } elsif ( $_ =~ /<$dataStart.*>/ && $followHeader eq 1) {
          # Follow up the data part
              $followData = 1;
              DEBUG "(".$currentIndex.") Started data parsing..";
          } elsif ( $_ =~ /<\/$dataStart>/ && $followData eq 1) {
          # Finish parsing of data part
              $followData = 0;
              DEBUG "(".$currentIndex.") Finished data parsing..";
          } elsif ( $_ =~ /$dataRegex/ && $followData eq 1) {
          # Parse the data, match it with headers IDs and add into data array
              DEBUG "(".$currentIndex.") Adding new data : [".$1."] = ".$2;
              my $id = $1;
              my $value = $2;
              my $matchedKey = "";
                foreach my $key (sort keys %myData) {
                  if ( $key =~ /^D$id##.*$/) {
                    $matchedKey = $key;
                    DEBUG "> Matched with key : ".$matchedKey;
                  }
              }
              if ( $matchedKey ) {
                  push(@{$myData{$matchedKey}}, $value);
              } else {
                  ERROR "XML Error! Can not match Data Value with any Header Key!";
              }
          }
    }
    my $backupFilename = $now."_".$currentFilename.".backup";
    INFO "Backing up $currentFilename into $conf{backup}{dir} as $backupFilename";
    copy($conf{input}{dir}."/".$currentFilename, $conf{backup}{dir}."/".$backupFilename) or die "$currentFilename can not be backed up ! Check if ".$conf{backup}{dir}." exists.";

    INFO "$currentFilename processed. Creating output.";
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
    unshift @headerArray, "FileName" if ( $conf{output}{fileAsColumn} );
    $output[0] = join($conf{output}{delimeter}, @headerArray ) unless ($conf{output}{truncateHeader});


    DEBUG "Total number of ".$elementCount." rows.";
    for(@headerArray) {
        chomp($_);
        DEBUG "-> Header : $_";
    }
    for(my $i=0; $i<$elementCount; $i++) {
        my @dataOutput;
        foreach my $headerElement ( sort keys %myData ) {
            push(@dataOutput, $myData{$headerElement}[$i]);
        }
        unshift @dataOutput, $currentFilename if ( $conf{output}{fileAsColumn} );
        push(@output, join($conf{output}{delimeter}, @dataOutput));
    }

    my $outputFileName = $currentFilename.".csv";
    DEBUG "Opening file ".$outputFileName." as read-write.";
    open(OUTPUT, "> ".$conf{output}{dir}."/".$outputFileName) or die("Can not open $outputFileName for writing.");
    DEBUG "Successfuly opened file ".$outputFileName." as read-write.";
    foreach my $row ( @output ) {
        print OUTPUT $row."\n";
        DEBUG "Written into $outputFileName : $row";
    }
    close(OUTPUT);
}

unlink($pidFile);

sub usage {
		my $usageText = << 'EOF';

This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

Author            Emre Erkunt
                  (emre.erkunt et gmail.com)

Usage : perfDataParser [-c CONFIG FILE] [-h]

 Parameter Descriptions :
 -c [CONFIG FILE]       Configuration file that defines directives         ** MANDATORY **
 -h                     Shows this help

EOF
		print $usageText;
		exit;
}   # usage()
