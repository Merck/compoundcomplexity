#!/usr/bin/env perl 
#
#
# require some utility subroutines
#
require "importenv.pl";
require "getopts.pl";
#

#
  if ( &Getopts('ATHmS:') == 0) { $usage = 2 };
  
  if ( defined( $opt_H )) { $usage = 1 };
 

# print usage if wanted
if ( $usage ) {
   print STDERR "sp3_carbons_count.pl [options] \n";
   print STDERR "Valid options are:\n";
   print STDERR " -A             Always print even if proper ffc does not occur\n";
   print STDERR " -m             Write number of occurances\n";
   print STDERR " -H             Help\n";
   print STDERR " -S splitoption What to do if there is symmetry; allowed options are {split},nosplit,first\n";
   print STDERR "                Do not add _1, _2 etc. to duplicated molecules\n";
   exit ( $usage );
}
#
print STDOUT "MOLECULE TOTALATOM_COUNT TOTALCARBON_COUNT CSP3_COUNT CSP2_COUNT CSP_COUNT CAR_COUNT CHIRAL_COUNT CSP3_ALLATOM_RATIO CSP2_ALLATOM_RATIO CSP_ALLATOM_RATIO  CAR_ALLATOM_RATIO CSP3_ALLCARBON_RATIO CSP2_ALLCARBON_RATIO CSP_ALLCARBON_RATIO  CAR_ALLCARBON_RATIO CHIRAL_ALLATOM_RATIO CHIRAL_ALLCARBON_RATIO\n";


 #loop over freqfile
 #now loop over standard in
 while (<STDIN>){
  (@fields)=split(' ',$_);

 # extract molecules
#

  if($fields[0] eq 'MOLECULE'){
	$Csp3_count=0;
	$Csp2_count=0;
	$Csp_count=0;
	$Car_count=0;
	$chiral_count=0;
	$totalatom_count=0;
	$totalcarbon_count=0;
	$name=$fields[1];

	next;
 }  # end over molecule
#
  if($fields[0] eq 'ATOM'){
	if($fields[2] ne "1"){$totalatom_count++;}
	if($fields[2] eq "6"){$totalcarbon_count++;}
	if($fields[10] eq "R" || $fields[10] eq "S" || $fields[10] eq "1" || $fields[10] eq "2"){$chiral_count++;}
	if($fields[11] eq "sp3C"){$Csp3_count++;}
	if($fields[11] eq "sp2C"){$Csp2_count++;}
	if($fields[11] eq "spC"){$Csp_count++;}
	if($fields[11] eq "arC"){$Car_count++;}
	next;
 }  # end over molecule

#
 if($fields[0] eq 'End_Of_Molecule'){
  

	if($totalcarbon_count==0){next;}

	$Csp3_allatom_ratio=$Csp3_count/$totalatom_count;
	$Csp3_allcarbon_ratio=$Csp3_count/$totalcarbon_count;

	$Csp2_allatom_ratio=$Csp2_count/$totalatom_count;
	$Csp2_allcarbon_ratio=$Csp2_count/$totalcarbon_count;

	$Csp_allatom_ratio=$Csp_count/$totalatom_count;
	$Csp_allcarbon_ratio=$Csp_count/$totalcarbon_count;

	$Car_allatom_ratio=$Car_count/$totalatom_count;
	$Car_allcarbon_ratio=$Car_count/$totalcarbon_count;

	$chiral_allatom_ratio=$chiral_count/$totalatom_count;
	$chiral_allcarbon_ratio=$chiral_count/$totalcarbon_count;



	printf STDOUT "%s %d %d %d %d %d %d %d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n",$name,$totalatom_count,$totalcarbon_count,$Csp3_count,$Csp2_count,$Csp_count,$Car_count,$chiral_count,$Csp3_allatom_ratio,$Csp2_allatom_ratio,$Csp_allatom_ratio,$Car_allatom_ratio,$Csp3_allcarbon_ratio,$Csp2_allcarbon_ratio,$Csp_allcarbon_ratio,$Car_allcarbon_ratio,$chiral_allatom_ratio,$chiral_allcarbon_ratio;

#	print STDOUT "$name $totalatom_count $totalcarbon_count $Csp3_count $Csp2_count $Csp_count $Car_count $chiral_count $Csp3_allatom_ratio $Csp2_allatom_ratio $Csp_allatom_ratio $Car_allatom_ratio $Csp3_allcarbon_ratio $Csp2_allcarbon_ratio $Csp_allcarbon_ratio $Car_allcarbon_ratio $chiral_allatom_ratio $chiral_allcarbon_ratio\n";
	next;
 }
 } # end loop over STDIN
#
#

 #

exit (0);

