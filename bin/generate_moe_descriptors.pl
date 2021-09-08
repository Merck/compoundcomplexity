#!/usr/bin/env perl
use Getopt::Std;
use List::Util qw[min max];
#
# get the command line options
#
$save=0;
$SD=0;
$mpu=min (`lscpu --parse=CORE| grep -c -v ^#`,24);
$MOLNAME="MIX_MOLNAME";
$INPUTFILE="-";
chomp $mpu;

#
# set default for temp file directory
my $TEMPDIR = "/dev/shm";

if ( getopts('d:HSt:si:m:M:') == 0) { $usage = 2 };
if ( defined( $opt_d )) { $descriptor_type = $opt_d };
if ( defined( $opt_S )) { $save = "1" };
if ( defined ($opt_t )) { $TEMPDIR = $opt_t };
if ( defined ($opt_i )) { $INPUTFILE = $opt_i };
if ( defined ($opt_s )) { $SD = "1" };
if ( defined ($opt_m )) { $mpu = $opt_m };
if ( defined ($opt_M )) { $MOLNAME = $opt_M };
if ( defined ($opt_H )) { $usage = 2 };
$descriptor_type = '2D' if (!defined($descriptor_type));
#
# if $usage print out usage
#
if ($usage) {
   print "generate_moe_descriptors.pl [options] < input_ffd_file > output_csv_file\n";
   print " -d <descriptor_type> : [2D|i3D|x3D]\n";
   print " -H help\n";
   print " -t <temp_directory> : $TEMPDIR\n";
   print " -s SDF input\n";
   print " -i <input file>: $INPUTFILE\n";
   print " -m <ncpus> : $mpu\n";
   print " -M <Molecule column name> : $MOLNAME\n";

   print "\n";
   exit ( $usage );
}
#
# loop over input stream and convert it to sd file
#
if ($INPUTFILE eq "-") {
    $INPUTFILE="$TEMPDIR/MOE_$$.sdf";
    if ($SD) {
        open (SD_FILE," > $INPUTFILE");
    } else {
        open (SD_FILE,"| tosd -T $MOLNAME > $INPUTFILE");
    }
    while (<>) {
        print SD_FILE "$_";
    }
    close(SD_FILE);
}
#
# write the svl file
#
open (SVL_FILE,">$TEMPDIR/MOE_$$.svl");
print SVL_FILE <<END_OF_SVL;
//
// user parameters
//

mdb_name = '$TEMPDIR/MOE_$$.mdb';
input_sdf = '$INPUTFILE';
output_csv = '$TEMPDIR/MOE_$$.csv';

descriptor_type = '2D';
//
// open a temp mdb file
//
mdb_key = db_Open [ mdb_name, 'create' ];

//
// input sdf file with structures
//
db_ImportSD [ mdb_name, input_sdf, 'mol' , [] , [] , [], [] ];

// Essam Metwally 11/18/2020 -- Rewrote using masks, code kept just in case
//
[ all_codes, all_descriptors, all_classes] = QuaSAR_Descriptor_List[];

IGNOREDESC = ['rsynth', 'ast_fraglike', 'ast_fraglike_ext', 'ast_violation', 'ast_violation_ext'];
msk = andE [all_classes == descriptor_type, m_diff [all_codes, IGNOREDESC]];
codes = all_codes | msk;

//
// generate the descriptors
//
t=clock[];
QuaSAR_DescriptorMDB [ mdb_name, 'mol', codes ];
fwrite [STDERR, 'Descriptor Calculation time: {}s\\n', clock[]-t];

//
// output the csv
//
t=clock[];
entries = db_Entries mdb_key;
data=apt db_ReadFields [mdb_name, entries, [codes]];
mols=app first db_ReadColumn [mdb_name, 'mol'];
data=apt cat [mols, data];
apt fwrite [STDOUT, '{|,}\\n', cat [[cat ['$MOLNAME', codes]], data]];
fwrite [STDERR, 'Output time: {}s\\n', clock[]-t];
END_OF_SVL
close(SVL_FILE);
#
# fire up moe
#
$MOE=$ENV{'MOE'};

# Essam Metwally, 18 Nov 2020 - Leverage MPU and site license
$CMD="$MOE/bin-lnx64s/moebatch -mpu $mpu -script $TEMPDIR/MOE_$$.svl -exit";

open (CSV_FILE,"$CMD|");
while (<CSV_FILE>) {
   print "$_";
}
close(CSV_FILE);
#
# clean up temp files
#
if( $save eq "0"){
    unlink("$TEMPDIR/MOE_$$.*");
}
# exit
#
exit;
#
# subs
#

