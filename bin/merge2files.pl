#!/usr/bin/env perl
#------------------------------------------------------------------------------
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#  Author: ................
#  Last Modified: $Date: 2014/03/05 16:36:27 $
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

BEGIN{
    die "Must have MIX environment" unless $ENV{'MIXBIN'} ;
    push    @INC, $ENV{'MIXSCLIB'} ; # Put $ENV{'MIXSCLIB'} at the end of the @INC
}
use strict;
use Env;
use MIX_opt ;

# Make a copy of the command line for logging purposes
my @argv = @ARGV;

# Get the prog and header variables
my ($prog,$header) = GetHeader ('$Revision: 1.1 $Date: 2014/03/05 16:36:27 $', \@argv) ;

####################### SYNOPSIS #######################
my $synopsis ="
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
This script merges two files with the same number of lines.
The merged lines are output to STDOUT
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
$0 [options] file1 file2
        Arguments:
file1             Name of the first file
file2             Name of the second file
";
####################### EXAMPLES #######################
my $examples = "
$0 one two > result_file
";
########################################################

# Read the description of options and set all the defaults for them.
# Only parameters will be left in @ARGV after this call.
my $opt_help = process_xml_options($0, $synopsis, $examples ) ;

@ARGV == 2       or Usage("Wrong number of arguments") ;
my $file1 = shift ;
my $file2 = shift ;

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
if( $Opt_value{'log_file'}) {
    open STDOUT, ">$Opt_value{'log_file'}"    or die "Can't redirect STDOUT <$!>\n";
    open STDERR, ">&STDOUT" or die "Can't dup STDOUT\n";
}
#=-=-=-=-=-=-=-=-=-=-=-=-=- M A I N -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
open(ONE,"$file1") or fail("Failed to open ONE [$file1] ($!)");
open(TWO,"$file2") or fail("Failed to open RWO [$file2] ($!)");
my ($line1, $line2);
while(<ONE>) {
    chomp($line1 = $_);
    $line2 = <TWO> ;
    last unless $line2; #If the seconf file has fewer lines than the first
    print "$line1 $line2";
}
