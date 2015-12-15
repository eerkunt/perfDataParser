#perfDataParser

This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

__NOTE THAT__ : You should not used this Parser to convert any kind of XML to a CSV file. 

##Dependencies

- Perl
- GetOpts::Std Perl module *( you should already have this module, if you don't you have serious problems )*
- Log::Log4Perl	*( you can easily install this module via CPAN )*
- File::Copy	*( if you don't have this, then you have same problem with GetOpts::Std )*
 
### Usage 

```
This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

Usage : perfDataParser [-i CONFIG FILE] [-h]

 Parameter Descriptions :
 -c [CONFIG FILE]		Configuration file that defines directives         ** MANDATORY **
 -h                     Shows this help

```

### Sample Configuration File
```
#
# perfDataParser Configuration File
#
# Directory that consist of XML files that will be parsed
InputDir=data

# Directory that will consist CSV files as output files
OutputDir=output

# This directory will have Backup XML/INPUT files. Only works if BackupAfterParse=1
BackupDir=backup

# This directory will have log files. Log file format will have PRID and Datetime
LogDir=logs

# Process ID. This will be included in log and output files
PRID=100302001

# Input File Masking as regular expression in order to filter INPUT files
InputFileMask=PGM_PGM_AUID.*\.xml

# If this is 0, then headers will not be written into output.
# Headers will be written into output if this is 1
TruncateHeader=0

# If this is 1, then parsed INPUT file will be copied into BackupDir
BackupAfterParse=1

# Log severity will be defined here
# Among these levels FATAL is the lowest, TRACE is the highest log level
# FATAL     : Only fatal errors will be dumped
# ERROR     : Also dump errors
# WARN      : Also dump warnings
# INFO      : Dump also informative logs
# DEBUG     : This is useful for troubleshooting if you are able to modify code, otherwise not recommended.
# TRACE     : This logs extensive output about code internals. Don't use this if you're not going to hack the script.
LogSeverity=INFO

# Delimeter will be defined between quotes
# Examples;
# For Comma                 -> ','
# For Semicolons            -> ';'
# For Space                 -> ' '
# For Colons                -> ':'
# For a custom delimeter    -> 'myCustom|||Delimeter'
# You can use as whatever you like.
Delimeter=';'

# PID file path that will be used for lock mechanism in order to prevent duplicate runs. PID will include PRID instead of Process ID
PIDFilePath=pids

# If this is 1, then INPUT file name will also include in the first column of output CSVs
InputFileNameAsColumn=1
```

### Tested XML Performance Files 

- EMe 
- PGM
- AFG