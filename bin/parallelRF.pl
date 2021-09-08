#!/usr/bin/env perl
#------------------------------------------------------------------------------
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#  Author: Joe Shpungin
#  Last Modified: $Date: 2016/07/08 18:26:41 $
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
my ($prog,$header,$Host) = GetHeader ('$Revision: 1.12 $Date: 2016/07/08 18:26:41 $', \@argv) ;

####################### SYNOPSIS #######################
my $synopsis ="
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
This script runs the random tree executable for training or prediction
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
$0 [options] action act_file des_file problem_dir
        Arguments:
action            model|predict|self-fit|analyze
act_file          Activities file 
des_file          Descriptor file
problem_dir       Directory where all files for the problem will be generated
";
####################### EXAMPLES #######################
my $examples = "
$0 model TEST.act TEST.des RF_test
";
########################################################

# Read the description of options and set all the defaults for them.
# Only parameters will be left in @ARGV after this call.
my $opt_help = process_xml_options($0, $synopsis, $examples ) ;

@ARGV == 4       or Usage("Wrong number of arguments") ;
my $action   = shift;
   $action = lc $action ;
my $act_file = shift ;
my $des_file = shift ;
my $problem_dir = shift ;
my $descriptors = $Opt_value{w} ;
my $Req_memory = 0;
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
if( $Opt_value{'log_file'}) {
    open STDOUT, ">$Opt_value{'log_file'}"    or die "Can't redirect STDOUT <$!>\n";
    open STDERR, ">&STDOUT" or die "Can't dup STDOUT\n";
}
# Print the header;
print STDERR "$header";
#=-=-=-=-=-=-=-=-=-=-=-=-=- M A I N -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

if( $act_file eq "" or $act_file eq "none" ) {
    $act_file = "NO_ACTIVITIES";
} else {
    $act_file = full_path("$act_file") ;
}
if( $act_file eq "NO_ACTIVITIES" and $action eq "model" ) {
     print "Must hace activities to build a model.  EXITING.\n";   
     exit;
}
$des_file = full_path("$des_file") ;

if( $action eq 'analyze' ) {
    build_input( $des_file, $act_file );
    exit;
}

( -d $problem_dir ) or mkdir $problem_dir, 0766 or fail("Can not create directory [$problem_dir] ($!)");


my $By_tree_file = $Opt_value{by_tree_file} eq "NO" ? "NO" : full_path($Opt_value{by_tree_file}) ;
my $Pred_file = full_path($Opt_value{pred_file}) if $Opt_value{pred_file} ;

chdir $problem_dir or fail("failed to chdir $problem_dir ($!)");
chomp (my $pwd = qx#pwd#);
my $N_trees ;
if ( $action eq "model" ) {
    $N_trees = $Opt_value{trees} ;
    print STDERR "    Working from $pwd\n" ;
    open(DESCRINFO,">DESCRIPTORS_INFO") or fail("Failed to open DESCRINFO [>DESCRIPTORS_INFO] $!");
    print DESCRINFO "$descriptors\n";
    close DESCRINFO;
} elsif( $action eq "predict" or $action eq "self-fit" ) {
    open(DESCRINFO,"DESCRIPTORS_INFO") or fail("Failed to open DESCRINFO [DESCRIPTORS_INFO] $!");
    chomp( $descriptors = <DESCRINFO> ) ;
    close DESCRINFO;
    open(OPT,"train.option") or fail("Failed to open OPT [train.option] ($!)");
    while(<OPT>) {
        if( /^trees\s+(.+)$/ ) {
	    $N_trees = $1 ;
	    last;
	}
    }
    close OPT;
}else{
    fail("The action must be one of the 'model' or 'predict' or 'self-fit'");
}
print STDERR "
    Input parameters:
Action              $action
Activity file       $act_file
Descriptors file    $des_file
Problem directory   $pwd
Number of trees     $N_trees

" ;

# Create a subdirectory where data for individual trees will be located
my $data_dir = "TREES" ;
( -d $data_dir ) or mkdir $data_dir, 0766 or fail("Can not create directory [$data_dir] ($!)");

my ($bin_dir, $script_dir);
$bin_dir = "$MIXBIN" ;
$script_dir = "$MIXSC" ;
my $bexe = "$bin_dir/rf.exe" ;

chop (my $Now = `/bin/date '+%Y%m%d_%H%M'`) ;
my $Format = "%-20s%-20s\n";
my $Tmp_dir = "$STMP/RF.$Now.$$" ;
mkdir $Tmp_dir, 0766 or fail("Can not create directory [$Tmp_dir] ($!)");


my $Train_opt_file = "train.option" ;
my ($Input_file,$List_file, $Opt_file);

# Create an input file for the RandomForrest run
my $Mol_cnt = 0;

if( $action eq "model" ) {
    $Input_file = "train.input";
    $List_file  = "train.mol_list" ;
    build_input( $des_file, $act_file );
    build_opt_file();
    my $log = "rsync.log" ;
    open(LOG,">$log") or fail("Failed to open LOG [>$log] $!");
    my $wdir = "$STMP/Ptree.$Now.$$" ;
    my $comm = "$script_dir/ptree.ksh -w $wdir -k $Train_opt_file -R $Opt_value{R} -q $Opt_value{q} $Input_file $Req_memory" ;
    print STDERR "    === $comm\n";
    print LOG "#HOST: $Host\n";
    print LOG "#$comm\n";
    #### print LOG "#$script_dir/collect_random_trees.ksh $wdir\n";
    system("$comm");
    print STDERR "Collect all TREE files ...\n" ;
    opendir(DIR,"$wdir") or fail("Failed to opendir DIR [$wdir] ($!)") ;
    my @files =  grep /\.TREE$/, readdir DIR;
    closedir DIR ;
    my $cnt = 0;
    for my $fl (@files) {
        $cnt++;
        my $command = "rsync $wdir/$fl TREES/TREE.$cnt" ;
        print LOG "$command\n";
        system("$command");
        while( -s "$wdir/$fl" ne -s "TREES/TREE.$cnt" ) {
	    sleep 1;
            print LOG "    $command\n";
            system("$command");
        }
    }
    close LOG;
    print STDERR "Number of files moved: $cnt\n";
    # In some cases some of the trees are not returned.  Let's regenerate the option file just in case
    $N_trees = $cnt ;
    build_opt_file();
} elsif( $action eq "predict" or $action eq "self-fit" ) {
    my $calculated = "$Tmp_dir/predictions" ;
    if( $action eq "predict" and $Opt_value{pred_file} ) {
        $calculated = $Pred_file;
    } elsif( $action eq "predict" and not $Opt_value{pred_file} ) {
        fail("Must have -pred_file when predict");
    }
    $Opt_file = "$Tmp_dir/predict.option" ;
    $Input_file = "$Tmp_dir/predict.input";
    $List_file = $action eq "predict" ? "$Tmp_dir/predict.mol_list" : "train.mol_list" ;
    build_input( $des_file, $act_file ) unless $action eq "self-fit";
    build_opt_file();
    my $comm = "$bexe $Opt_file";
    print STDERR "    === $comm\n";
    system("$comm");
    # The run above generated a file with predictions, predict.input.act
    # We now should merge this file with the moilecule list in $List_file
    chomp( my $base_act = `basename $act_file` ) ;
    print STDERR "Creating the $calculated file ...\n" ;
    open(PREDICT,">$calculated") or fail("Failed to open PREDICT [>$calculated] $!");
    print PREDICT "Mol_name  Predic   Act\n";
    close PREDICT;
    my($labl,$fl) = split " ", qx#grep predict_file $Opt_file#;
    $comm = "$MIXSC/merge2files.pl $List_file $fl.act >> $calculated" ;
    #DEBUG("$comm");
    system("$comm");
    #The tree_predictions has data.  We will need to convert it to the correct array
    if( $Opt_value{by_tree_file} ne "NO" ) {
        my (@arr,@predictions) ;
	#my $fl = full_path($Opt_value{by_tree_file}) ;
	open(TREES,$By_tree_file) or fail("Failed to open TREES [$By_tree_file] $!");
	while(<TREES>) {
	    @arr = split;
	    my $indx = 0;
	    for my $pred (@arr) {
	        $predictions[$indx++] .= "$pred ";
	    }
	}
	close TREES;
	open(TEMP,">$By_tree_file.temp") or fail("Failed to open TEMP [$By_tree_file.temp] $!");
	for my $line (@predictions) {
	    print TEMP "$line\n";
	}
        $comm = "$MIXSC/merge2files.pl $List_file $By_tree_file.temp > $By_tree_file.new";
	system("$comm");
	rename "$By_tree_file.new", "$By_tree_file" ;
	unlink "$By_tree_file.temp" ;
    }
    calculate_R2("$calculated") unless $act_file eq "NO_ACTIVITIES" ;
}
##########################################################################################################
sub build_input {
# The following files will be created:
#if -train
#    train.mol_list
#    train.input
#    train.option

    my $des_file = shift ;
    my $act_file = shift ;

    my %act = ();
    my %act_list = () ;
    my @act_list = () ;
    my ($mol) ;

    my %all_des = ();
    my %mol_des = () ;
    my %hash = ();
    my @des_list = ();
    my ($n_des, $nact);
    my $nmolecules = 0;

    # Construct the egrep command
    my @descriptors = split /,/, $descriptors ;
    my $egrep = "egrep -e '^MOLECULE' -e '^End_Of_Molecule'" ;
    for my $one_descr (@descriptors) {
        $egrep .= " -e \'type $one_descr \'";
    }
    print STDERR "Filter: $egrep\n";

    if( $action eq "model" or $action eq 'analyze' ) {
        open(DES,"$egrep < $des_file|") or fail("Failed to open DES [$des_file] $!");
        while(<DES>) {
            if(/^MOLECULE/) {
                $mol = (split)[1] ;
	        $nmolecules++;
            }elsif(/^DATA /) {
                my($data,$string) = split /"/;
		#$string = lc $string;
	        %hash = split " ", $string ;
                for my $des (keys %hash) {
	            $all_des{$des}=1;
	        }
            }
        }
        close DES;
        print_number("Number of molecules:",$nmolecules);
    
        @des_list = sort keys %all_des ;
        $n_des = @des_list ;
        print_number("Number of unique descriptors:",$n_des);
        open(DES_LIST,">DES_LIST") or fail("Failed to open DES_LIST [>DES_LIST] $!");
	for my $descriptor (@des_list) {
	    print DES_LIST "$descriptor\n";
	}
        close DES_LIST;
	return if $action eq 'analyze' ;
    } else {
	if( $act_file eq "NO_ACTIVITIES" ) {
            open(DES2,"$des_file") or fail("Failed to open DES2 [$des_file] $!");
            while(<DES2>) {
                if(/^MOLECULE/) {
		    my $molname = (split)[1] ;
                    $act{$molname} = 999.999 ;
	        }
	    }
	}

        open(DES_LIST,"DES_LIST") or fail("Failed to open DES_LIST [DES_LIST] $!");
	$n_des = 0;
	@des_list = () ;
	while(<DES_LIST>) {
	    chomp;
	    $n_des++;
	    $hash{$_}=1;
	    push @des_list, $_;
	}
        print_number("Number of unique descriptors:",$n_des);
        close DES_LIST;
    }

    if( $act_file ne "NO_ACTIVITIES" ) {
        open(ACT,"$act_file") or fail("Failed to open ACT [$act_file] $!");
        $nact = 0;
        while(<ACT>){
            my ($mol,$act) = split;
            $nact++ ;
            $act{$mol} = $act ;
        }
        close ACT;
        print_number("Number of activity records:",$nact);
    }

    my $no_act_file = "$Tmp_dir/no_activity.lst" ;
    open(DES,"$egrep < $des_file|") or fail("Failed to open DES [$des_file] $!");
    info("Creating $Input_file - might take a while ...");
    open(RESULT,">$Input_file") or fail("Failed to open RESULT [$Input_file] $!");
    open(MOL,">$List_file") or fail("Failed to open MOL,[>$List_file] $!");
    open(NOACT,">$no_act_file") or fail("Failed to open MOL,[>$no_act_file] $!");
    my $skip ;
    my %one_hash;
    my $no_act = 0 ;
    %hash = ();
    while(<DES>) {
        if(/^MOLECULE/) {
            $skip = 0;
            $mol = (split)[1] ;
	    if( exists $act{$mol} ) {
	        print RESULT "$act{$mol} " ;
	        $act_list{$act{$mol}}++;
                print MOL "$mol\n";
	        $Mol_cnt++;
	    }else{
		print NOACT "$mol\n" ;
		$skip = 1;
		$no_act++;
	    }
        }elsif(/^DATA /) {
	    next if $skip ;
            my($data,$string) = split /"/;
	    next unless $string ;
	    my %one_hash = split " ", $string ;
            for my $des (keys %one_hash) {
	        $hash{$des}=$one_hash{$des};
	    }
        }elsif(/^End_Of_Molecule/) {
	    if( $Mol_cnt > 0 and $skip == 0) { # Write previous molecule if it had activity
                for my $des ( @des_list ) {
	            if ( exists $hash{$des} ) {
                        print RESULT "$hash{$des} ";
	            }else{
	                print RESULT "0 ";
	            }
                }
	        print RESULT "\n";
		%hash = ();
	    }
	}
    }
    close RESULT ;
    close DES;
    close MOL ;
    close NOACT ;
    print_number("Molecules with activity:", $Mol_cnt) ;
    print_number("Molecules without activity:", $no_act) ;
    my $prev_size = 0;
    my $sz = 1;
    while ( $sz != $prev_size ) {
	$prev_size = $sz ;
        $sz = -s $Input_file ;
        #print "$Input_file size $sz bytes\n" ;
	sleep 1;
    }
    print "$Input_file size " ;
    if( $sz > 10**9 ) {
	$sz = $sz / 10**9 ;
	printf "%5.1f GB\n", $sz ;
    } elsif( $sz > 10**6 ) {
	$sz = $sz / 10**6 ;
	printf "%5.1f MB\n", $sz ;
    } elsif( $sz > 10**3 ) {
	$sz = $sz / 10**3 ;
	printf "%5.1f KB\n", $sz ;
    } else {
	printf "%5.1f B\n", $sz ;
    }
    @act_list = sort keys %act_list ;
    $nact = @act_list ;
    print_number("Number of unique activities:",$nact);
    my $nrnodes = 2*($Mol_cnt/5)+1 ;
    $Req_memory = (4*($Mol_cnt*12 + $n_des*3 + $nrnodes*11 + 2*$Mol_cnt*$n_des))/1_000_000_000 ;
    $Req_memory = int($Req_memory) ;
    printf STDERR "Allocatable space(GB) %5.1f", $Req_memory ;
    $Req_memory = $Req_memory > 5 ? $Req_memory : 5 ;
    printf STDERR "-->%d\n", $Req_memory ;
}
##########################################################################################################
sub build_opt_file {
    my ($n_des, $fl) = split " ", qx#wc -l DES_LIST#;
    if( $action eq "model" ) {
        my $mtry = 1500 ;
        if( $Opt_value{mtry} ) {
            $mtry = $Opt_value{mtry} ;
        } else {
            $mtry = int($n_des/3) if $mtry > $n_des/3;
        }
        open(OPT,">$Train_opt_file") or fail("Failed to open OPT,[>$Train_opt_file] $!");
	printf OPT $Format,"train_file", $Input_file ;
	printf OPT $Format,"predict_file", "tHePlAcEhOlDeR"  ;
        printf OPT $Format,"molecules", "$Mol_cnt";
        printf OPT $Format,"mdim", "$n_des";
        printf OPT $Format,"tests", "0";
        printf OPT $Format,"trees", "$N_trees";
        printf OPT $Format,"ntree", "2BeChAnGeD";
        printf OPT $Format,"random", "1";
        printf OPT $Format,"read", "0";
        printf OPT $Format,"delta", "10";
        printf OPT $Format,"mtry", "$mtry";
        printf OPT $Format,"by_tree_file", "NO";
        close OPT;
	if( $Opt_value{debug} ) {
	    open(OPT,"$Train_opt_file") or fail("Failed to open OPT,[$Train_opt_file] $!");
	    while(<OPT>) {
	        print;
	    }
	    close OPT;
	}
    } elsif( $action eq "predict" ) {
	my $seen_by_tree_file = 0;
        open(OPTR,"$Train_opt_file") or fail("Failed to open OPTR,[$Train_opt_file] $!");
        open(OPT,">$Opt_file ") or fail("Failed to open OPT,[>$Opt_file ] $!");
        my ($key,$value) ;
        while(<OPTR>) {
	    ($key,$value) = split;
	    if( $key eq "predict_file" ) {
	        $value = $Input_file ;
	    } elsif( $key eq "read" ) {
	        $value = "1";
	    } elsif( $key eq "ntree" ) {
	        $value = "0";
	    } elsif( $key eq "random" ) {
	        $value = "0";
	    } elsif( $key eq "tests" ) {
	        $value = "$Mol_cnt" ;
	    } elsif( $key eq "by_tree_file" or $key eq "tree_predict" ) {
		$seen_by_tree_file = 1;
	        $key = "by_tree_file";
	        $value = $By_tree_file ;
            }
	    printf OPT $Format,$key,$value;
        }
	if( not $seen_by_tree_file ) {
	    $key = "by_tree_file";
	    $value = $By_tree_file ;
	    printf OPT $Format,$key,$value;
	}
        close OPTR;
        close OPT;
    } elsif( $action eq "self-fit" ) {
	my $seen_by_tree_file = 0;
        open(OPTR,"$Train_opt_file") or fail("Failed to open OPTR,[$Train_opt_file] $!");
        open(OPT,">$Opt_file ") or fail("Failed to open OPT,[>$Opt_file ] $!");
        my ($key,$value) ;
	my $train_input;
        while(<OPTR>) {
	    ($key,$value) = split;
	    if( $key eq "train_file" ) {
	        $train_input = $value;
		$value = "SeLf-TrAin";
	    }elsif( $key eq "molecules" ) {
	        $Mol_cnt = $value
	    }elsif( $key eq "predict_file" ) {
	        $value = $train_input ;
	    } elsif( $key eq "read" ) {
	        $value = "1";
	    } elsif( $key eq "ntree" ) {
	        $value = "0";
	    } elsif( $key eq "tests" ) {
	        $value = "$Mol_cnt" ;
	    } elsif( $key eq "by_tree_file" or $key eq "tree_predict" ) {
		$seen_by_tree_file = 1;
	        $key = "by_tree_file";
	        $value = $By_tree_file ;
            }
	    printf OPT $Format,$key,$value;
        }
	if( not $seen_by_tree_file ) {
	    $key = "by_tree_file";
	    $value = $By_tree_file ;
	    printf OPT $Format,$key,$value;
	}
        close OPTR;
        close OPT;
    }
}
##########################################################################################################
sub calculate_R2 {
    my $fl = shift;
    open(IN,"$fl") or fail("Failed to open IN [$fl] ($!)");
    #MOLECULE Prediction Observed
    my ($X,$Y,$XY,$X2,$Y2) = (0,0,0,0,0,0);
    my $cnt = 0;
    while(<IN>) {
        next if /Mol_name/;
        $cnt++;
        my($mol,$pred,$obs) = split;
        $X += $pred ;
        $Y += $obs  ;
        $X2 += $pred * $pred ;
        $Y2 += $obs  * $obs  ;
        $XY += $pred * $obs  ;
    }

    my $xbar=$X/$cnt;
    my $ybar=$Y/$cnt;
    my $z1=$XY - $cnt*$xbar*$ybar;
    my $z2=$X2 - $cnt*$xbar*$xbar;
    my $z3=$Y2 - $cnt*$ybar*$ybar;
    my $r=$z1/sqrt($z2*$z3);
    my $rsq=$r**2;
    printf "Number of lines= %d;  R2= %5.3f\n",$cnt,$rsq;
}
##########################################################################################################
