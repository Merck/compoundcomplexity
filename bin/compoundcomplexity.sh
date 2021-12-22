#!/bin/bash
##############################################################################
# Program: Compound Complexity
# 
# History
#   Essam Metwally	2021-08-17 Sandboxed from Original Version
#
# COPYRIGHT (C) 2021 MERCK SHARP & DOHME CORP. A SUBSIDIARY OF MERCK & CO., 
# INC., KENILWORTH, NJ, USA. ALL RIGHTS RESERVED.
#
# PERMISSION TO USE, COPY, MODIFY AND DISTRIBUTE THIS SOFTWARE IS HEREBY
# GRANTED PROVIDED THAT: (1) UNMODIFIED OR FUNCTIONALLY EQUIVALENT CODE
# DERIVED FROM THIS SOFTWARE MUST CONTAIN THIS NOTICE; (2) ALL CODE DERIVED
# FROM THIS SOFTWARE MUST ACKNOWLEDGE THE AUTHOR(S) AND INSTITUTION(S); (3)
# THE NAMES OF THE AUTHOR(S) AND INSTITUTION(S) NOT BE USED IN ADVERTISING
# OR PUBLICITY PERTAINING TO THE DISTRIBUTION OF THE SOFTWARE WITHOUT
# SPECIFIC, WRITTEN PRIOR PERMISSION
#
# MERCK RESEARCH LABORATORIES DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
# AND IN NO EVENT SHALL CHEMICAL COMPUTING GROUP INC. BE LIABLE FOR ANY
# SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
###
CMD=$(realpath -e -z $0)
SWD=${CMD%/bin/*}
BIN=${CMD%/*}
DATA=$SWD/data
LDLIB=$SWD/lib
TEMPDIR=$SWD/tmp

export MIXBIN=$BIN
export MIXSC=$BIN
export MIXDAT=$DATA
export MIXSCLIB=$BIN/lib
export MIXTMP=$TEMPDIR

export STMP=$MIXTMP

export PATH=$BIN:$PATH
export LD_LIBRARY_PATH=${LDLIB}:${LD_LIBRARY_PATH}

HELPMSG="USAGE: $0 [ -sdf <sdfile> | -smi <smilefile> ]"

while [ ! -z "$1" ]; do
    case $1 in
        -sdf)
            CONVERTER="$BIN/fromsd $2"
	    shift
	    ;;
        -smi)
            CONVERTER="$BIN/fromsmi $2"
	    shift
            ;;
        *)
    	    echo $HELPMSG
	    exit 1
	    ;;
    esac
    shift
done

if [ -z "$CONVERTER" ]; then
    echo $HELPMSG
    exit 2
fi

if [ ! -d "$MOE" ]; then 
    echo "ERROR: MOE Environment must be set"
    exit 3
fi

mkdir -p $TEMPDIR

data_filter="egrep -e '^MOLECULE ' -e '^End_Of_Molecule' -e '^DATA'"
TEMP_FFD=$TEMPDIR/temp.$USER.ffd.$USER.$$
CHARGESTATE="PH74"

DATARECORDSPIPE="$CONVERTER | $BIN/perlegrep.pl -v '^DATA'" 

eval $DATARECORDSPIPE  > $TEMP_FFD

####
  DESCRIPTOR="SP3CARBONS"
  result="$TEMPDIR/temp.$USER.$DESCRIPTOR.$$.ffd"
  cat $TEMP_FFD | $BIN/delete atom '*:/hyd' | $BIN/delete atom '*:/dummy' | $BIN/pcp -f $DATA/sp3_carbons.pcp | $BIN/sp3_carbons_count.pl | $BIN/table_to_descriptors.pl  -C -w SP3CARBONS -t numeric4 > $result
  LIST="$LIST $result"

####
  DESCRIPTOR="DESCRIPTORCOMPLEXITY"
  result="$TEMPDIR/temp.$USER.$DESCRIPTOR.$$.ffd"
  cat $TEMP_FFD | $BIN/topogen -w AP,TT > $TEMPDIR/temp.des.$$

  (echo "MOLECULE UNIQUEAP APCOMPLEX UNIQUETT TTCOMPLEX" ; cat $TEMPDIR/temp.des.$$ | awk '{if($1=="MOLECULE"){name=$2};if($1=="DATA" && $6=="TT" && $8 > 0){tt=$10/$8; utt=$10};if($1=="DATA" && $6=="AP" && $8 > 0){ap=$10/$8; uap=$10}; if($1=="End_Of_Molecule"){printf "%s %.2f %.2f %.2f %.2f\n",name,uap,ap,utt,tt}}' )| \
  $BIN/table_to_descriptors.pl -w  $DESCRIPTOR  -t numeric4 -U > $result

   LIST="$LIST $result"
   rm -f $TEMPDIR/temp.sdf.$$ $TEMPDIR/out.sdf.$$ $TEMPDIR/temp.des.$$
####
  DESCRIPTOR="MOE_2D"
 
   result="$TEMPDIR/temp.$USER.$DESCRIPTOR.$$.ffd"
   echo "Calculating $DESCRIPTOR" >&2

   CPU_COUNT=1
 
   cat $TEMP_FFD  | \
   eval $BIN/ligand_formal_charge_pipe -c $CHARGESTATE  | \
   $BIN/perlegrep.pl '^MOLECULE|^End_Of_Molecule|^ATOM|^RESIDUE|^BOND'  | \
   $BIN/generate_moe_descriptors.pl -t $TEMPDIR -m $CPU_COUNT | \
   $BIN/table_to_descriptors.pl -e -C -w MOE_2D -d comma -t numeric4 -s MOE_2D_${CHARGESTATE} | \
   eval $data_filter >$result

   LIST="$LIST $result"

   rm -f $TEMPDIR/temp.$USER.$$.sdf

echo "\n==== $(date) Combining descriptors ..." >&2
cat $LIST | merge_ffd.pl  > $$.desc

$BIN/parallelRF_new predict none $$.desc $DATA/Compound_complexity/Compound_complexity_V001
