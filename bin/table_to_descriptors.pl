#!/usr/bin/env perl
#
#
# require some utility subroutines
#
require "importenv.pl";
require "getopts.pl";
#
#
$outstring=TABLE;
$debug=0;
$string="--";
$log=0;
$delimiter="whitespace";
$type="numeric4";
$namesin="";
$capitalize="0";
$underscore_columns="0";
$underscore_molecules="0";
$includestring="";
$excludestring="";
$sourcestring="";
$exponent=0;
$check=0;
$truncate=0;
$act_remove=0;
#

  if ( &Getopts('HDACcTleMUus:p:w:d:t:n:I:E:') == 0) { $usage = 2 };
#  
   if ( defined( $opt_c )) { $check = 1}; 
   if ( defined( $opt_C )) { $capitalize = 1}; 
   if ( defined( $opt_s )) { $sourcestring = $opt_s };
   if ( defined( $opt_d )) { $delimiter = $opt_d };
   if ( defined( $opt_D )) { $debug = 1 };
   if ( defined( $opt_E )) { $excludestringin = $opt_E};
   if ( defined( $opt_I )) { $includestringin = $opt_I};
   if ( defined( $opt_H )) { $usage = 1 };
   if ( defined( $opt_l )) { $log = 1 };
   if ( defined( $opt_M )) { $missing_mol_header = 1};
   if ( defined( $opt_w )) { $outstring=$opt_w };
   if ( defined( $opt_t )) { $type=$opt_t };
   if ( defined( $opt_n )) { $namesin=$opt_n};
   if ( defined( $opt_u )) { $underscore_columns=1};
   if ( defined( $opt_U )) { $underscore_molecules=1};
   if ( defined( $opt_e )) { $exponent=1};
   if ( defined( $opt_T )) { $truncate=1};
   if ( defined( $opt_A )) { $act_remove=1};


if($delimiter ne "whitespace" && $delimiter ne "comma" && $delimiter ne "tab"){
	print STDERR "Incorrect delimiter for -d\n";
	$usage=1;
	exit;
}
#
 # print usage if wanted
if ( $usage ) {
   print STDERR "table_to_descriptors.pl";
   print STDERR "-H        help\n"; 
   print STDERR "-A        Do not include Act as a column\n";
   print STDERR "-c	   Stops on non-float values\n";
   print STDERR "-C        Capitalize column names\n";
   print STDERR "-d string Delimiter for reading tables: whitespace,comma,tab { $delimiter } \n";
   print STDERR "-e        Converts exponential notation to decimal\n";
   print STDERR "-D        debug\n";
   print STDERR "-E string Substrings to exclude in columnanes (|-separated) e.g. '^R|^S_|^FILE' {Default: exclude none}\n";
   print STDERR "          If string is in both lists, exclusion overrides\n";
   print STDERR "-I string Substrings to include in columnanes (|-separated) e.g. '^R|^S_|^FILE' {Default: include all}\n"; 
   print STDERR "-M        Column name 'molecule' is missing \n";
   print STDERR "-n string Comma separated column names to replace those from table {default use column headings}\n";
   print STDERR "-s string Source for output. If missing,use 'type' as set by -w\n";
   print STDERR "-t string Type: substructure, numeric1, numeric2, numeric3 numeric4 { $type }\n";
   print STDERR "-T 	   Truncate the columname before '@' {default is to use the entire column name\n";
   print STDERR "-U        Change '-' to '_' in molecule names \n";
   print STDERR "-u        Change '-' to '_' in columnames \n";
   print STDERR "-w string Descriptor type for output { $outstring }\n";
   exit ( $usage );
}
#
#print STDERR "truncate $truncate\n";
#parse names
@names=split(",",$namesin);
$outstringcaps=$outstring;
$outstringcaps=~y/[a-z]/[A-Z]/;
if($sourcestring eq ""){$sourcestring=$outstring;}
#
if($type ne "substructure" && $type ne "numeric1" && $type ne "numeric2" && $type ne "numeric3" && $type ne "numeric4"){
  print STDERR "$type is not a valid type\n";
 exit;
}
print STDERR "type $type\n";
#
# read in the inclusion and exclusion strings

if($capitalize==1){$excludestringin=~y/[a-z]/[A-Z]/; $includestringin=~y/[a-z]/[A-Z]/;}
if($underscore_columns==1){$excludestringin=~s/-/_/g; $includestringin=~s/-/_/g;}
$excludestringin=~s/\|/#/g;
$includestringin=~s/\|/#/g;
(@excludestrings)=split("#",$excludestringin);
(@includestrings)=split("#",$includestringin);
#print STDERR "includestrings @includestrings \n";
#print STDERR "excludestrings @excludestrings \n";

#
#now loop over standard in
  while (<STDIN>){
#
  $_=~s/"/#/g;
#
  $lines++;
  if($delimiter eq "whitespace"){(@fields)=split(' ',$_);}
  if($delimiter eq "comma"){(@fields)=split(",",$_);}
  if($delimiter eq "tab"){(@fields)=split("\t",$_);}

  if( $lines % 1000 == 0) { print STDERR "working on row $lines \n"; }
  if($lines==1){
#	if the header contains quotes, fill in blanks between the # and remove the #, then
#	reparse
	if(index($_,"#") > -1){&reparse_fields;}# end reparse field
#
#	if you are missing the molecule header, unshift
	if($missing_mol_header==1){unshift @fields,"molecule";}
	$ncolumns=$#fields;
#	print STDERR "ncolumns $ncolumns\n";
	for($icol=1;$icol<=$ncolumns;$icol++){
	      $columnnames[$icol]=$fields[$icol];
#		truncate at "@" if wanted
	      if($truncate==1){($columnnames[$icol],$junk)=split('@',$columnnames[$icol]);}
	      chomp($columnnames[$icol]);
#             change columnname to the list names if a list was provided
              if($namesin ne ""){$columnnames[$icol]=$names[$icol-1];}
#              $columnames[$icol]=~s/ /_/g;  
              if($capitalize==1){$columnnames[$icol]=~y/[a-z]/[A-Z]/;}
              if($underscore_columns==1){$columnnames[$icol]=~s/-/_/g;}
	      $column_array{$columnnames[$icol]}=1
	} # loop over columns

  } # end first line
  if($lines>=2) {
       if(index($_,"#") > -1){&reparse_fields;}# end reparse field
       $irow=$lines-1;
       $rownames[$irow]=$fields[0];
       if($underscore_molecules==1){$rownames[$irow]=~s/-/_/g;}
       $row_array{$rownames[$irow]}=1;
	for($icol=1;$icol<=$ncolumns;$icol++){
		$value{$rownames[$irow]}{$columnnames[$icol]}=$fields[$icol];
		chomp($value{$rownames[$irow]}{$columnnames[$icol]});
		$vv=$value{$rownames[$irow]}{$columnnames[$icol]};
		if($exponent==1 && (index($vv,"E-") > -1 || index($vv,"e-") > -1)){
#			print STDERR "vv $vv before\n";
			$vv=sprintf("%.10f",$vv);
#			print STDERR "vv $vv after\n";
			$value{$rownames[$irow]}{$columnnames[$icol]}=$vv;
			
		}      
		if($check==1){
			$vv=~y/eE.0123456789\-/             /;
       			$vv=~s/ +//g;
			if($vv ne ""){
				print STDERR "The value of row $rownames[$irow] column $columnnames[$icol] is $value{$rownames[$irow]}{$columnnames[$icol]}...not a number stop.\n";
				exit;
			}
		}
        }
    } # end if block for lines >=2

 } # end loop over STDIN
$nrows=$irow;
#
print STDERR "rows: $nrows columns: $ncolumns\n";

#
for($i=1;$i<=$nrows;$i++){
#print STDERR "row $i $rownames[$i]\n";
      $nunique=0;
       $ntotal=0;
       $desstring="";
#	loop over columns
       foreach $desno (sort keys %column_array){
#
	if($act_remove==1 && $desno eq "Act"){next;}
#
#	skip over columns that are excluded
	if($includestringin ne "" || $excludestringin ne ""){
	  $includehits=0;
          $excludehits=0;
	  foreach $myvar (@includestrings){if($desno=~/$myvar/){$includehits++;}}
          foreach $myvar (@excludestrings){if($desno=~/$myvar/){$excludehits++;}}
#	  if there is no exclusion, skip anything not on the inclusion list
	  if($includestringin ne "" && $includehits == 0){next;}
	  if($excludestringin ne "" && $excludehits > 0){next;}
	}# end block to check inclusion or exclusion
#
	    $ff=$value{$rownames[$i]}{$desno};
	    if($ff eq ""){next;}
#	    if this is a substructure descriptor, skip zero values
            if($ff == 0 && $type eq "substructure"){next;}
            $nunique++;
            $ntotal=$ntotal+$ff;
            if($type eq "substructure"){
                      $desnomod=$desno;
	    }elsif($type eq "numeric1"){
	              $desnomod=join("",$outstring,"_",$desno);
            }elsif($type eq "numeric2"){
	              $desnomod=join("",$outstring,"_",$desno);
            }elsif($type eq "numeric3"){
                      $desnomod=$desno
            }elsif($type eq "numeric4"){
                      $desnomod=$desno
	    }else{
	      print STDERR "table_to_descriptors: No type $type\n";
            }
           $desstring=join("",$desstring,$desnomod," ",$ff," ");     
       }
#        if($nunique==0){
#         $nunique=1;
#         $ntotal=1;
#         $desstring="X 1 ";
#        }
       print STDOUT "MOLECULE $rownames[$i]\n";
      if($type eq "substructure"){
       print STDOUT "DATA $sourcestring class ss type $outstringcaps sumV $ntotal countD $nunique des \"$desstring\"\n";
      }elsif($type eq "numeric1"){
       print STDOUT "DATA subdes num mol type $outstring sumV $ntotal countD $nunique des \"$desstring\"\n";
      }elsif($type eq "numeric2"){
	    foreach $desno (sort keys %column_array){
	    $ff=$value{$rownames[$i]}{$desno};
                print STDOUT "DATA $sourcestring ${outstring}_${desno} mol ${outstring}_${desno} $ff \n";
	    }
      }elsif($type eq "numeric3"){
        print STDOUT "DATA $sourcestring num mol type $outstringcaps sumV 0 countD $nunique des \"$desstring\"\n";            
      }elsif($type eq "numeric4"){
        print STDOUT "DATA $sourcestring class mol type $outstringcaps countD $nunique des \"$desstring\"\n";            
      }else{
	 print STDERR "No type $type \n";
      }# end if block for type 
       print STDOUT "End_Of_Molecule\n";

}# end loop over molecules

sub reparse_fields{
#		print STDERR "Header contains quotes\n";
		(@chars)=split('',$_);
#                print STDERR "**nchars $#chars\n";
		 $on=0;
                 for($k=0;$k<=$#chars;$k++){
#                print STDERR "k $k chars $chars[$k]";
                  if($chars[$k] eq "#" && $on==0){$on=1; next;}
                  if($chars[$k] eq "#" && $on==1){$on=0; next}             
                  if($chars[$k] eq " " && $on==1){$chars[$k]="_"; next;}
                 } # end loop over characters
#		print STDERR "Chars @chars\n";
        	$tempstring=join('',@chars);
		$tempstring=~s/#//g;
        	chomp($tempstring);
#                print STDERR "tempstring $tempstring\n";
		  if($delimiter eq "whitespace"){(@fields)=split(' ',$tempstring);}
                  if($delimiter eq "comma"){(@fields)=split(",",$tempstring);}
                  if($delimiter eq "tab"){(@fields)=split("\t",$tempstring);}
return;
}
