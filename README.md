#perfDataParser

This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

__NOTE THAT__ : You should not used this Parser to convert any kind of XML to a CSV file. 

##Dependencies

- Perl
- GetOpts::Std Perl module *( you should already have this module, if you don't you have serious problems )*
 
### Usage 

```
This script reads Performance XML data files generated from Ericsson devices
and converts them based on <measData> tags into CSV files. CSV files to be used
by Optima.

Usage : perfDataParser [-i INPUT FILE] [-o OUTPUT FILE] [-d DELIMETER] [-s] [-v] [-h]

 Parameter Descriptions :
 -i [INPUT FILE]        Ericsson Devices' Performance XML File             ** MANDATORY **
 -o [OUTPUT FILE]       Output file about results.
 -s                     Outputs to STDOUT instead of writing into CSV file
 -d [DELIMETER]         Delimeter that will be used in CSV file.           ( Default is ; )
 -v                     Disable verbose                                    ( Default OFF )
 -h                     Shows this help

```

You can either use -o for a CSV output, or -s to be used in automated jobs.

### Tested XML Performance Files 

- EMe 
- PGM
- AFG