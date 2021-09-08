#!/usr/local/bin/perl
#
#
# require some utility subroutines
#
require "importenv.pl";
require "getopts.pl";
#
$destype=AP;
#

 if ( &Getopts('Hw:') == 0) { $usage = 2 };
  
 
  if ( defined( $opt_H )) { $usage = 1};
  if ( defined( $opt_w )) { $destype = $opt_w};
#
#

# print usage if wanted
if ( $usage ) {
   print "descriptor_checking.pl; [options]  \n";
   print "Valid options are:\n";
   print " -H         help\n";
   print " -w string  descriptors, e.g. AP,TT,DP {$destype}  \n";
   exit ( $usage );
}
#
if ( $destype ne "all"){
###############################################################################
(@descriptors)=split(",",$destype);
#
$nmol=0;
# read first descriptor file
while(<STDIN>){
#
        $_=~s/"/ /g;
	@line=split(' ',$_);
# 
	if( $line[0] eq "MOLECULE"){ $nmol++; if($nmol > 10){last;}}
	if( $line[0] eq "DATA"){
	   foreach $d (@descriptors){
#		take into account that d might incorporate @ for files
		($d,$dummy)=split("@",$d);
                ($dd,$which)=split("_",$d); 
#               substructure record
		if(($line[&which_field("type")+1] eq $d && $line[2] eq "des" && $line[3] eq "mol") ||
                   ($line[&which_field("type")+1] eq $d && $line[&which_field("class")+1] eq "ss")){
			$substrcount{$d}++;
                        next;		
		}
#               numeric1
		if( index($line[2],"$d") == 0 && $line[8] ne "countD"){
			$numericcount{$d}++;
                        next;
		}
#              numeric3 generic name
#               print STDERR "d $d line2 $line[2] line5 $line[&which_field("type")+1]\n";
		if( $line[&which_field("type")+1] eq $d && $line[2] eq "num"){
                      $numericcount{$d}++;
                      next;
		}
#              numeric4 generic name
#               print STDERR "d $d line2 $line[2] line5 $line[&which_field("type")+1]\n";
		if( $line[&which_field("type")+1] eq $d && $line[&which_field("class")+1] eq "mol"){
                      $numericcount{$d}++;
                      next;
		}
#               numeric3 or numeric4 full name
		if( $line[&which_field("type")+1] eq $dd && ($line[2] eq "num" || $line[&which_field("class")+1] eq "mol" )){
		  for($k=&which_field("des")+1;$k<=$#line;$k=$k+2){
		    if($line[$k] eq $which){$numericcount{$d}++;last;}
                  }
                }   
#               numeric 3 or numeric4 USR
	        if( $line[&which_field("type")+1] eq "FILE" && ($line[2] eq "num" || $line[&which_field("class")+1] eq "mol" )){
		  for($k=&which_field("des")+1;$k<=$#line;$k=$k+2){
		    if($line[$k] eq $d){$numericcount{$d}++;last;}
                  }
                }
	   }# loop over descriptors
	}# end if DATA 

#

} # end while over STDIN
#
$missing=0;
foreach $d (@descriptors){
#	print STDERR "d $d substrcount $substrcount{$d} numeric $numericcount{$d}\n";
	if($substrcount{$d}==0 && $numericcount{$d}==0){
		print STDOUT "$d missing\n";
		$missing=0;
        }elsif($substrcount{$d} > $numericcount{$d}){
		print STDOUT "$d substructure\n";
	}else{
		print STDOUT "$d numeric\n";
	}
	
}

#
endit:
############################################################################
}else{

#
$nmol=0;
# read first descriptor file
while(<STDIN>){
#
        $_=~s/"/ /g;
	@line=split(' ',$_);
# 
	if( $line[0] eq "MOLECULE"){ $nmol++; if($nmol > 10){last;}}
	if( $line[0] eq "DATA"){
		#       substructure record
		if( ($line[2] eq "des" && $line[3] eq "mol") ||
                    ($line[&which_field("class")+1] eq "ss")){
			$d=$line[&which_field("type")+1];
			$substrcount{$d}++;
                        next;		
		}
#              numeric4 generic name
		if( $line[&which_field("class")+1] eq "mol" && $line[&which_field("type")+1] ne "FILE" ){
                      $d=$line[&which_field("type")+1];
                      $numericcount{$d}++;
                      next;
		}
#               numeric 3 or numeric4 USR
	        if( $line[&which_field("type")+1] eq "FILE" && $line[&which_field("class")+1] eq "mol" ){
#			print STDERR "hit\n";
		  	$d=join("_",FILE,$line[&which_field("des")+1]);
                        $numericcount{$d}++; 
			next;
                }



	}# end if DATA 

#

} # end while over STDIN

   foreach $d ( sort keys  %substrcount){
		print STDOUT "$d substructure\n";
   }
   foreach $d ( sort keys %numericcount){
		print STDOUT "$d numeric\n";
   }



}# end if block
#
exit(0);

sub which_field{
my($i);
my($thisone);
my($string)=$_[0];
 for($i=0;$i<=$#line;$i++){
	if($line[$i] eq $string){
		$thisone=$i;
		return $thisone;
        }
 }
}# end subroutine
