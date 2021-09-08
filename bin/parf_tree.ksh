#!/bin/ksh
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#  Author: Joseph Shpungin
#  Last Modified: $Date: 2014/04/22 13:38:25 $
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# This script generates an ffd file to be used by GLIDE
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
[ -z "$MIXSC" ] &&  { print "\$MIXSC is not defined. EXITING"; exit 1; }
. $MIXSC/functions.ksh

#==============================================================
#Defaults
header="FALSE"
resource="cerius2"
queue="huge"
ntrees=100
scdir=$MIXSC
bindir=$MIXBIN
#==============================================================
function Usage {
die " $1
SYNOPSIS:
$Progname [options] arff_file
        Arguments:
arff_file      The input .arff file.
        Options:
-H             This help
-S             Print header {$header}
-L <log_fl>    Log is directed to a log file, not to STDOUT
-w <wdir>      REQUIRED. Directory where the trees will be located
-s <scdir>     Execute directory where all scripts located {$scdir}
-b <bindir>    Execute directory where all binaries are located {$bindir}
-n <int>       Number of trees to generate {$ntrees}
-R <string>    The PBS resource {$resource}
-q <string>    The PBS queue {$queue}
\n           E X A M P L E S
Example: $Progname -w \$PWD/tmp_ptrees TEST_AP/train_input.arff
"
}
#==============================================================
#Process input
while getopts HSL:w:R:q:n:s:b: option
do
    case "$option" in
	S)  header=TRUE;;
	L)  log_fl=$OPTARG;;
	w)  wdir=$OPTARG;;
	e)  scdir=$OPTARG;;
	b)  bindir=$OPTARG;;
	n)  ntrees=$OPTARG;;
        R)  resource=$OPTARG;;
	q)  queue=$OPTARG;;
	H)  Usage ;;
	\?) Usage "Wrong option"
    esac
done
(( shiftcount = OPTIND - 1 ))
shift $shiftcount

[ $# -eq 1 ] || Usage "Wrong number of arguments"
in_file=$1

#We will need to copy $in_file to all execution hosts.  We better compress it first
DATE=$(/bin/date '+%Y.%m%d.%H%M%S') # 2011.1201.083833
tm_dir="$STMP/$LOGNAME.$DATE"
mkdir -p $tm_dir
compressed="$tm_dir/arff_file.gz"
gzip --stdout $in_file > $compressed
ls -l $in_file $compressed

if [ -z "$wdir" ];then
    print -u2 "ERROR: Must have -w <wdir> option"
    exit
fi

#==============================================================
if [ "$log_fl" ];then
    exec 1>$log_fl
    exec 2>&1
fi
#=====
#this is a dentification message:
if [ "$header" == "TRUE" ] ; then
    print -u2 "\$Revision: 10.1 $Date: 2014/04/22 13:38:25 $\n";
    print_header $0 $*
fi
#==============================================================
# Main
#==============================================================

tmp_dir="$LTMP/Parf.$LDate.$$"
mkdir $tmp_dir
list="$tmp_dir/INPUT.lst" 
(( nn = 1 ))
while (( nn <= ntrees )); do
    print "$nn" >> $list
    (( nn = nn + 1 ))
done
file=$list

# The parf_tree_one.ksh is in the same directory as the $0
#full_command=$(full_path $0)
scdir=$(full_path $scdir)
bindir=$(full_path $bindir)
wdir=$(full_path $wdir)

ONE="\"$scdir/parf_tree_one.ksh $wdir $bindir\""

parallel=$( which parallel.pl )
print -u2 "    Running $parallel"
command="$parallel -debug"
command="$command -remove_remote"   #With this option the debugging is not possible
command="$command -ffd          $file"
command="$command -n_per_cpu    1"
command="$command -que          $queue"
#command="$command -mem          ${req_memory}GB"
command="$command -mem          12GB"
command="$command -job_name     PARFF"
command="$command -resource     '$resource'" 
command="$command -push         $compressed"
command="$command -input2thread list"
command="$command -get          TREE"
command="$command -work_dir     $wdir"
command="$command -num_cpu_requested 4"
#command="$command -count_string Elapsed"
command="$command -submit       $ONE $list OUT"
print "$command\n" | sed 's/  */ /g'
eval $command

cd $wdir
count=$(ls *.TREE|wc -l)
print "Found $count trees"
if (( count > 99 )) ; then
    format="%.3d"
else
    format="%.2d"
fi
(( nn = 1 ))
for fl in $(ls *.TREE); do
   new=$(printf $format $nn)
   mv $fl Tree.$new.tree
   (( nn = nn + 1 ))
done

forest=$(ls *.forest | head -1)
mv $forest $forest.back
rm -f *.forest

print "        $count" > Tree.forest
tail  -n +2 $forest.back >> Tree.forest
