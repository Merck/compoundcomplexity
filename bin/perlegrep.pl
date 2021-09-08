#!/usr/bin/env perl 
#
#
# require some utility subroutines
#

require "importenv.pl";
require "getopts.pl";
#
# include vs exclude
$MIXSC=$ENV{'MIXSC'};
$MIXBIN=$ENV{'MIXBIN'};
$MIXDAT=$ENV{'MIXDAT'};
$MIXVER=$ENV{'MIXVER'};
#
#
$exclude=0;
$case_insensitive=0;
#
  if ( &Getopts('Hvi') == 0) { $usage = 2 };
  
  if ( defined( $opt_v )) { $exclude = 1 };
  if ( defined( $opt_i )) { $case_insensitive = 1 };

# print usage if wanted
if ( $usage ) {
   print "peregrep.pl [options]  \n";
   print "Valid options are:\n";
   print " -H         help\n";
   print " -i         case-insensitive {case-sensitive}\n";
   print " -v string  exclude { include }\n";
   exit ( $usage );
}
#
if( !defined $ARGV[0] ){
	print STDERR "You must have a string or pipe-separated strings\n";
}
$ARGV[0]=~s/"//g;
$ARGV[0]=~s/\|/#/g;
if($case_insensitive==1){$ARGV[0]=~y/[a-z]/[A-Z]/;}

(@strings)=split("#",$ARGV[0]);
#
#print STDERR "ARGV $ARGV[0] strings @strings\n";
while(<STDIN>){
#
$line=$_;
#       
if($case_insensitive==1){$line=~y/[a-z]/[A-Z]/;}

$hits=0;
foreach $myvar (@strings){if($line=~/$myvar/){$hits++;}}
if($hits==0 && $exclude==1){print $_;}
if($hits==1 && $exclude==0){print $_;}
  
}# end while

exit;
