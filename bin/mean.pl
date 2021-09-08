#!/usr/bin/env perl
#
#
# require some utility subroutines
#
require "importenv.pl";
require "getopts.pl";
#
$indelimiter="whitespace";
$type="mean";
$meantype="Mean";
$skewtype="";
$rmsdeviationtype="";
$MADtype="";
#
  if ( &Getopts('HAMRKi:') == 0) { $usage = 2 };
  
  if ( defined( $opt_K )) { $skewtype = "skew" };
  if ( defined( $opt_M )) { $type = "median" };
  if ( defined( $opt_A )) { $MADtype = "MAD" };
  if ( defined( $opt_H )) { $usage=2};
  if ( defined( $opt_i )) { $indelimiter=$opt_i};
  if ( defined( $opt_R )) { $rmsdeviationtype="rmsdev"};


# print usage if wanted
if ( $usage ) {
   print STDERR "mean.pl column_number\n";
   print " -H         help\n";
   print " -M         include median\n";
   print " -K         include skewness and kurtosis\n";
   print " -A         include mean pairwise absolute deviation\n";
   print " -R         include RMS deviation from mean\n";
   print " -i string  delimiter for input files whitespace | tab | comma { $indelimiter }\n";

   exit ( $usage );
}
#
# parse the remaining arguments
#
if ( !defined($ARGV[0]) ) {
   print "A column number must be written\n";
   exit ($usage);
}
$column=$ARGV[0];
print STDERR "column $column\n";
$column2=$ARGV[1];

##
#print STDERR "indelimiter $indelimiter\n";
#exit;

 #
 $nmol=0;
 #loop over freqfile
  $rms=0;
  $mean=0;
  $sd=0;
  $max=-9999999999.;
  $min=99999999999.;
  $b[0]=-99999999999;
 #now loop over standard in
$totweight=0;
$nline=0;
  while (<STDIN>){if($indelimiter eq"whitespace"){
     @a=split(' ',$_);
  }elsif($indelimiter eq "tab"){
     @a=split("\t",$_);
  }elsif($indelimiter eq "comma"){
     @a=split(",",$_);
  }else{
        print STDERR "Delimiter $indelimiter not properly defined--exit\n";
        exit;
    }

$nline++;  

 if( ! isNumber($a[$column-1])){print STDERR "From mean.pl: Skipping $a[$column-1] in line $nline which is not a number\n"; next;}
 if($column2 eq ""){ $weight=1}else{$weight=$a[$column2-1]; $meantype="Weighted_mean";}
 if($a[$column-1] > $max) { $max=$a[$column-1];}
 if($a[$column-1] < $min) { $min=$a[$column-1];} 
  $rms=$rms+$weight*$a[$column-1]**2;
  $mean=$mean+$weight*$a[$column-1];
  $sd=$sd+$weight*$a[$column-1]*$a[$column-1];
  $nmol++;
  $totweight=$totweight+$weight;
  $b[$nmol]=$a[$column-1];
#	printf STDERR "column $column $a[$column-1]\n";
 } # end loop over STDIN
#
print STDERR "nmol $nmol\n";
if($nmol==0) { die "No real numbers\n";}
$rms=sqrt($rms/$totweight);
$mean=$mean/$totweight;
$z=$sd/$totweight - $mean*$mean;
if($z > 0){
	$sd=sqrt($z);
}else{
	$sd=0;
}

printf STDERR "$meantype of $nmol numbers is %.4f +/- %.4f min %.4f max %.4f rms %.4f ",$mean,$sd,$min,$max,$rms; 
printf STDOUT "$meantype of $nmol numbers is %.4f +/- %.4f min %.4f max %.4f rms %.4f ",$mean,$sd,$min,$max,$rms; 

#
if( $type eq "median"){
  @bsorted= sort bynumber @b;
  $half=int($nmol/2);
  $firstquarter=int($nmol*0.25);
  $thirdquarter=int($nmol*0.75);
  if( $nmol % 2 == 0){
     $median=($bsorted[$half]+$bsorted[$half+1])/2;
  }else{
 
     $median=$bsorted[$half+1];
  } 
 $firstquartile=($bsorted[$firstquarter]);
 $thirdquartile=($bsorted[$thirdquarter]);
    printf STDERR "median %.4f firstquartile %.4f thirdquartile %.4f",$median,$firstquartile,$thirdquartile;
    printf STDOUT "median %.4f firstquartile %.4f thirdquartile %.4f",$median,$firstquartile,$thirdquartile;


}# end of median

if( $skewtype eq "skew"){

$skewness=0;
$kurtosis=0;
for ($i=1; $i<=$nmol; $i++){
 $skewness=$skewness+($b[$i]-$mean)**3;
 $kurtosis=$kurtosis+($b[$i]-$mean)**4;
}
$skewness=$skewness/(($nmol-1)*$sd**3);
$kurtosis=-3+$kurtosis/(($nmol-1)*$sd**4);

    printf STDERR "skewness %.4f kurtosis %.4f",$skewness,$kurtosis;
    printf STDOUT "skewness %.4f kurtosis %.4f",$skewness,$kurtosis;




}# end of skewness

if( $rmsdeviationtype eq "rmsdev"){
	$rmsdev=0;

for ($i=1; $i<=$nmol; $i++){
 $xx=($b[$i]-$mean)**2;
 $yy=abs($b[$i]-$mean);
 $meandev=$meandev+$yy;
 $rmsdev=$rmsdev+$xx;
# print STDERR "\ni $i b $b[$i] xx $xx";
}
#print STDERR "sumrmsdev $rmsdev nmol $nmol\n";
$meandev=$meandev/$nmol;
$rmsdev=sqrt($rmsdev/$nmol);

    printf STDERR "meanabsdevmean %.4f rmsdevmean %.4f ",$meandev,$rmsdev;
    printf STDOUT "meanabsdevmean %.4f rmsdevmean %.4f ",$meandev,$rmsdev;

}

if( $MADtype eq "MAD"){
	$MAD=0;
	$nn=0;

for ($i=1; $i<=$nmol-1; $i++){
for ($j=$i+1; $j<=$nmol; $j++){
$MAD=$MAD+abs($b[$i]-$b[$j]);
$nn++;
}
}
#print STDERR "sumrmsdev $rmsdev nmol $nmol\n";
$MAD=$MAD/$nn;

    printf STDOUT "nMAD %d pairwiseMAD %.4f ",$nn,$MAD;
    printf STDERR "nMAD %d pairwiseMAD %.4f ",$nn,$MAD;

}# end MAD

print STDERR "\n";
print STDOUT "\n";
 #

exit (0);

sub bynumber { $a <=> $b;}

sub isNumber{
my $ss=shift;
#if it contains punctuation other than . - or + it cant be a number
return 0 if $ss =~/[,()<>=_]/;
#if it contains any letter other than E/e it cant be a number
return 0 if $ss =~/[A-DF-Z]/i;
#look for floating point numbers or integers
return 1 if $ss =~ /^[+\-]?\d*.?\d+$/;
#look for scientific notation
return 1 if $ss =~ /^[+\-]?\d*.?\d+e[+\-]?\d+$/i;
return 0;


}

