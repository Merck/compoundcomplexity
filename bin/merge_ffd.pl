#!/usr/bin/env perl
#------------------------------------------------------------------------------
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#  Author: ................
#  Last Modified: $Date: 2014/02/06 15:30:26 $
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

BEGIN{
    die "Must have MIX environment" unless $ENV{'MIXBIN'} ;
    push    @INC, $ENV{'MIXSCLIB'} ; # Put $ENV{'MIXSCLIB'} at the end of the @INC
}
use strict;
use Env;
use MIX_opt ;

####################### SYNOPSIS #######################
my $synopsis ="
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
This script merges molecules from different files into the stream
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
$0 [options] 
        Arguments:
NONE
";
####################### EXAMPLES #######################
my $examples = "
cat *.ffd | $0 -o > result.ffd
";
########################################################

# Make a copy of the command line for logging purposes
my @argv = @ARGV;

# Get the prog and header variables
my ($prog,$header) = GetHeader ('$Revision: 1.4 $Date: 2014/02/06 15:30:26 $', \@argv) ;

# Read the description of options and set all the defaults for them.
# Only parameters will be left in @ARGV after this call.
my $opt_help = process_xml_options($0, $synopsis, $examples ) ;

@ARGV == 0       or Usage("Wrong number of arguments") ;

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
if( $Opt_value{'log_file'}) {
    open STDOUT, ">$Opt_value{'log_file'}"    or die "Can't redirect STDOUT <$!>\n";
    open STDERR, ">&STDOUT" or die "Can't dup STDOUT\n";
}
#=-=-=-=-=-=-=-=-=-=-=-=-=- M A I N -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# All options are available as values of the %Opt_value.  For example
my $Debug = $Opt_value{debug};
    my %all_molecules = ();
    my $one_mol = "" ;
    my $mol_name = "" ;
    my @mols = () ;
    while(<STDIN>) {
        if(/^MOLECULE/) {
	    $mol_name = (split)[1];
	    push @mols, $mol_name unless exists $all_molecules{$mol_name};
	} elsif(/^End_Of_Molecule/) {
	    $all_molecules{$mol_name} .= $one_mol ;
	    $one_mol = "" ;
	} else {
	    $one_mol .= $_;
	}
    }
    for my $mol (@mols) {
	print "MOLECULE $mol\n" ;
        print "$all_molecules{$mol}" ;
	print "End_Of_Molecule\n";
    }
