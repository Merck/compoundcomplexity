#!/usr/bin/env perl
#-------------------------------------------------------------------------------
#  MIX process input option library
#
#  Authors:
#		Joe Shpungin
#-------------------------------------------------------------------------------

package MIX_opt;
BEGIN{
    die "Must have MIX environment" unless $ENV{'MIXSCLIB'} ;
}
use Shell;
use Env;
use POSIX;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION) ;
require Exporter;
@ISA = qw(Exporter);

# Export everything for now...
@EXPORT = qw(
    process_xml_options
    full_path
    canonic_L_A
    fail
    quit
    ListOptions
    Usage
    GetHeader
    print_number
    commas
    elap_time
    sec_to_string
    DEBUG
    holler
    info
    mail_it
    make_tmp_dir
);

@EXPORT_OK = qw (
);

# export variables needed for processing options
use vars      qw ( %Opt_value %Opt_value_cmd %Default %Opt_present %Opt_keyword %Opt_level $Options $Synopsis $Examples ) ;
push @EXPORT, qw ( %Opt_value %Opt_value_cmd %Default %Opt_present %Opt_keyword %Opt_level $Options $Synopsis $Examples ) ;
# and some others 
use vars      qw ( $Mix_session $Prog $MIX_opt_Revision $Rev_string ) ;
push @EXPORT, qw ( $Mix_session $Prog $MIX_opt_Revision $Rev_string ) ;

$MIX_opt_Revision = '$Revision: 1.63 $Date: 2014/05/13 13:36:52 $' ; # This will be updated by CVS
$MIX_opt_Revision = (split " ",$MIX_opt_Revision)[1] ; # Get only the revision NUMBER

# This variable is set by process_xml_options and used there and in ListOptions as well
# one cannot therefore call ListOptions before process_xml_options.
my $max_len = 0;

my $To_list = "shpungij" ;
my $BeGiNtIme = time ;
my %Flag = () ;

#=================================================================================
# This function reads the xml file describing command options and fills
# all arrays needed to process command options and print the Usage.
# It performs some checks as well
#
sub process_xml_options{
    my ($prog, $synopsis, $examples) = @_ ;

    #Make $synopsys and $examples global variables
    $Synopsis = $synopsis ;
    $Examples = $examples ;

    use Getopt::Long;
    Getopt::Long::Configure ("no_ignore_case");
    use XML::Simple;

    my $xml_file = "" ;
    if( -f "$prog.xml" ) {
        $xml_file = "$prog.xml" ;
    } else {
        chomp ($prog = Shell::basename($prog) ) ;
        $xml_file = "$MIXDAT/$prog.xml" ;
        fail("Failed to find XML file <$xml_file> ($!)") unless -f $xml_file ;
    }

    my $ref = XMLin($xml_file) ;
    my $ref1 = $ref->{'mdbedit:command'}->{'mdbedit:options'} ;

    my @options = ();
    %Flag = () ;
    my %help1 = () ;
    my %help2 = () ;

    my $opt_ref ;
    #####################
    # Translate xml file into options and
    # build the help message
    for $opt_ref ( @{$ref1->{'mdbedit:parameter'}} ) {
	my $opt = $opt_ref->{'cmdopt'} ;
	$opt =~ s/^\-+// ;   # Remove the dashes from beginning if the option name
        if( $opt_ref->{'type'} eq "string" or
	    $opt_ref->{'type'} eq "sl_mol" or
	    $opt_ref->{'type'} eq "sl_atom"   ) { 
            push @options, "$opt=s" ;
            $help1{$opt} = "$opt <$opt_ref->{'type'}>";
            $help2{$opt} = sprintf "%s ", ucfirst $opt_ref->{'comment'} ;
        } elsif ( $opt_ref->{'type'} eq "file_name" or
	          $opt_ref->{'type'} eq "dir_name" or
		  $opt_ref->{'type'} eq "constraints_file") {
	    push @options, "$opt=s" ;
            $help1{$opt} = "$opt <file>";
            $help2{$opt} = sprintf "%s ", ucfirst $opt_ref->{'comment'} ;
        } elsif ( $opt_ref->{'type'} eq "int" ) {
            push @options, "$opt=i" ;
            $help1{$opt} = "$opt <integer>";
            $help2{$opt} = sprintf "%s ", ucfirst $opt_ref->{'comment'} ;
            if( exists $opt_ref->{'low'} and exists $opt_ref->{'high'} ) {
                $help2{$opt} .= "($opt_ref->{'low'} to $opt_ref->{'high'}) " ;
            } elsif (exists $opt_ref->{'low'}) {
                $help2{$opt} .= "(>=$opt_ref->{'low'}) " ;
            } elsif (exists $opt_ref->{'high'}) {
                $help2{$opt} .= "(<=opt_ref->{'high'}) " ;
            }
        } elsif ( $opt_ref->{'type'} eq "float" ) {
            push @options, "$opt=f" ;
            $help1{$opt} = "$opt <float>";
            $help2{$opt} = sprintf "%s ", ucfirst $opt_ref->{'comment'} ;
            if( exists $opt_ref->{'low'} and exists $opt_ref->{'high'} ) {
                $help2{$opt} .= "($opt_ref->{'low'} to $opt_ref->{'high'}) " ;
            } elsif (exists $opt_ref->{'low'}) {
                $help2{$opt} .= "(>$opt_ref->{'low'}) " ;
            } elsif (exists $opt_ref->{'high'}) {
                $help2{$opt} .= "(>$opt_ref->{'high'}) " ;
            }
        } elsif ( $opt_ref->{'type'} eq "flag" ) {
            push @options, "$opt!" ;
            $help1{$opt} = "$opt ";
            $help2{$opt} = sprintf "%s ", ucfirst $opt_ref->{'comment'} ;
            $Flag{$opt}=1;
        } elsif ( $opt_ref->{'type'} eq "combo" ) {
            push @options, "$opt=s" ;
            $help1{$opt} = "$opt <choice>";
            $help2{$opt} = sprintf "%s [%s] ", ucfirst $opt_ref->{'comment'}, $opt_ref->{'choice'} ;
        } else {
            die "Invalid type [$opt_ref->{'type'}] of option $opt.  Fix the $xml_file\n";
        }
	$max_len = length($help1{$opt}) if length($help1{$opt}) > $max_len ;

        #####################
        # Get the defaults
	die "$opt must have the default= field.  Fix the $xml_file\n" unless exists $opt_ref->{'default'} ;
        if( $opt_ref->{'default_descr'} ) {
            $help2{$opt} .= sprintf "{%s}", $opt_ref->{'default_descr'} ;
	    $opt =~ s/\|.+$// ;  # Leave only the first version of the option if "|" is used
            $Default{$opt} = '' ;
        } else {
            $help2{$opt} .= sprintf "{%s}", $opt_ref->{'default'} ;
	    $opt =~ s/\|.+$// ;  # Leave only the first version of the option if "|" is used
            $Default{$opt} = $opt_ref->{'default'} ;
        }
    }


    #####################
    # Call the GetOptions routine.  We save @ARGV in order to use it after 'command_file' option
    my @argv_save = @ARGV ;
    my $ok = GetOptions (\%Opt_value_cmd, @options ) or exit 1;

    # Set only the first option if more then one is present ("|" delimeter)
    # Example cmdopt="-H|help"
    for my $opt ( keys %Opt_value ) {
	if( $opt =~ /(.+)\|/ ) {
	    $Opt_value{$1} = $Opt_value{$opt} ;
	    delete $Opt_value{$opt} ;
	}
    }


    #####################
    # Get the options from file if one is given.  They will override the XML options
    my @file_options = () ;
    if( my $fl = $Opt_value_cmd{'command_file'} ) {
        my($opt_name, $opt_value) = (' ',' ') ;
        open(CMD,"$fl") or fail("Failed to open $fl ($!)");
        while(<CMD>) {
            next if /^#/ ;   # Ignore comment lines
            s/#.*$// ;       # Ignore inline comments
            next if /^\s*$/; # Ignore emty lines
            s/\s+$// ;       # Remove trailing spaces
            chomp;
	    my ($key,$val) = split " ", $_, 2 ;
	    push @file_options, $key ;
	    if( defined $val and $val ne "" ) {
		push @file_options, $val ;
	    }
        }
        close CMD ;
    }

    # The options entered on the command line override everything
    @ARGV = ( @file_options, @argv_save ) ;
    $ok = GetOptions (\%Opt_value, @options ) or exit 1;

    #####################
    # Need to check validity of options
    my $problems = "" ;
    for $opt_ref ( @{$ref1->{'mdbedit:parameter'}} ) {
	my $opt = $opt_ref->{'cmdopt'} ;
	my $keyword = $opt_ref->{'keyword'} ;
	my $level = $opt_ref->{'level'} ;
	$opt =~ s/^\-+// ;   # Remove the dashes from beginning if the option name
	$Opt_level{$opt} = $opt_ref->{'level'} ;
	$Opt_keyword{$keyword} =  $opt ;
	$opt =~ s/\|.+$// ;  # Leave only the first version of the option if "|" is used
	if( exists $Opt_value{$opt} ) {
	    $Opt_present{$opt} = 1 ;
	} else {
	    $Opt_value{$opt} = $Default{$opt} ;
	}
	
        if( $opt_ref->{'type'} eq "int" and $Opt_present{$opt} ) {
            $problems .= "    Value for $opt < $opt_ref->{'low'}\n" if
                exists $opt_ref->{'low'} and $Opt_value{$opt} < $opt_ref->{'low'} ;
            $problems .= "    Value for $opt > $opt_ref->{'high'}\n" if
                exists $opt_ref->{'high'} and $Opt_value{$opt} > $opt_ref->{'high'} ;
        } elsif( $opt_ref->{'type'} eq "float" and $Opt_present{$opt} ) {
            $problems .= "    Value for $opt < $opt_ref->{'low'}\n" if
                exists $opt_ref->{'low'} and $Opt_value{$opt} < $opt_ref->{'low'} ;
            $problems .= "    Value for $opt > $opt_ref->{'high'}\n" if
                exists $opt_ref->{'high'} and $Opt_value{$opt} > $opt_ref->{'high'} ;
        } elsif( $opt_ref->{'type'} eq "combo" and $Opt_present{$opt} ) {
            my @possible = split /\|/,  $opt_ref->{'choice'} ;
            my @full = grep {$_ =~ /^$Opt_value{$opt}/} @possible ;
            if( @full == 1 ) {
                $Opt_value{$opt} = $full[0] ;
            } elsif (@full > 1 ) {
                $problems .= "    Value for $opt is ambiguous (@full)\n";
            } else {
                $problems .= "    Value for $opt is invalid\n";
            }
        }
    }

    if( $problems ) {
        print STDERR "Problem with some options:\n" ;
        print STDERR "$problems\n";
        exit 1;
    }

    if ( $Opt_value{'list_options'} ) {
        ListOptions('all');
    }

    if( $Opt_value{H} || $Opt_value{help}) {
        if( $Opt_value{debug} ) {
	#<dt>-bin_number &lt;int&gt;</dt>
        #<dd>
        #Explanation
        #</dd>
            for my $opt (sort { lc($a) cmp lc($b) } keys %help1) {
	        next if $Opt_level{$opt} eq "hidden" ;
		$help1{$opt} =~ s/</&lt;/ ;
		$help1{$opt} =~ s/>/&gt;/ ;
                print "\n<dt>-$help1{$opt}</dt>\n"; 
		print "<dd>\n$help2{$opt}\n</dd>\n";
	    }
	    exit;
	} else {
            $Options = "\n" ;
            my $screen_length = 80 ;
            for my $opt (sort { lc($a) cmp lc($b) } keys %help1) {
	        my $one_help = sprintf "-%-${max_len}s %s", $help1{$opt}, $help2{$opt} ;
                my @tmp = split / /, $one_help ;
	        my $out = "" ;
	        for my $tok ( @tmp ) {
	            $out .= "$tok " ;
	            if ( length($out) > $screen_length ) {
		        $Options .= "$out\n";
		        $out = " " x ${max_len} . "  ";
	            }
	        }
	        $Options .= "$out\n" unless $out =~ /^\s+$/ ;
            }
	    Usage("H E L P") ;
	}
    }
}

#=================================================================================
sub full_path {
    my $src_file = shift ;

    chomp(my $old_dir = Shell::pwd()); # Remember where we came from

    chomp( my $dirname = `dirname $src_file` ) ;
    chomp( my $basename = `basename $src_file` ) ;
    chdir $dirname or fail("Can't chdir to [$dirname] ($!)") ;
    chomp(my $pwd = Shell::pwd()); # This is a directory where the file is from as returned by the OS

    chdir $old_dir or fail("Can't chdir to [$old_dir] ($!)") ;   # Go back where we started

    $src_file = "$pwd/$basename" ;
}
#==============================================================================
#
# This function prints error message and dies.
#
# This function should be called for an error that should cause immediate
# termination of the entire process
#
sub fail {
    my($message) = @_;
    my($package,$filename,$line,$subr,$email_body) ;

    $email_body = "\n" . "%"x70 . "\nFAIL: $message\n"  ;

    my $i = 0;
    while ( ($package,$filename,$line,$subr) = caller($i++) ) {
        $email_body .= "Filename<$filename> Line<$line> Routine<$subr>\n" ;
    }
    $email_body .= "\n" . "%"x70 . "\n" ;
    print STDERR $email_body ;
    exit 1;
}
#==============================================================================
#
# This function prints error message and dies.  It is different from fail in that
# it does not print all debug information
#
sub quit {
    my($message) = @_;

    my $delim = "\n" . "%"x70 . "\n" ;

    print STDERR "$delim$message\n    QUITTING...\n$delim";
    exit 1;
}
#==============================================================================
#
sub ListOptions {
	my $type = shift ;

	die "Cannot call MIX_opt::ListOptions before MIX_Opt::process_xml_options!"
		unless($max_len);
        print STDERR "    ==== OPTIONS: ====\n    ";
        for my $opt (sort { lc($a) cmp lc($b) } keys %Opt_value ) {
	    my $comment = $Opt_present{$opt} ? "ENTERED" : "DEFAULT" ;
	    if( $type eq 'entered' ) {
		next if $comment eq "DEFAULT" ;
		if( $Flag{$opt} ) {
		    $opt = "no$opt" if $Opt_value{$opt} == 0 ;
		    printf STDERR "-%-s ", $opt ;
		} else {
		    if( $Opt_value{$opt} =~ /\(/ or
			$Opt_value{$opt} =~ /\*/         ) {
			printf STDERR "-%-s '%s' ", $opt, $Opt_value{$opt} ;
		    } else {
		        printf STDERR "-%-s %s ", $opt, $Opt_value{$opt} ;
		    }
		}
	    } else {
                printf STDERR "    %-${max_len}s <%s> %s\n", $opt, $Opt_value{$opt}, $comment ;
	    }
        }
	print STDERR "\n    ==================\n";
}
#==============================================================================
# This subroutine prints the usage message.  It can be called after a call to
#       process_options
#
sub Usage {
    my($message) = @_;
    my $delim = "%" x 30;
    # Sanity
    $message = $message || " U S A G E ";
    $Synopsis = $Synopsis || "\n";
    $Options = $Options || "\n";
    $Examples = $Examples || "\n";

    print STDERR "
$delim $message $delim
	S Y N O P S I S:$Synopsis
        O P T I O N S:$Options
        E X A M P L E S:$Examples
$delim $message $delim
" ;
    print STDERR "\n$Rev_string\n" if $Rev_string;

    exit 1;
}

#=================================================================================
# This gets information about the execution environment and returns it
# to the caller
#
sub GetHeader {
        my ($r, $argv_ref) = @_;
	#'$Revision: 1.63 $Date: 2014/05/13 13:36:52 $'
        my ($lab, $revision, $lab1, $cvs_date ) = split " ", $r ;
	$cvs_date = "UNKN" unless $cvs_date;

        my $hostname = Shell::uname("-n");
        my $pwd = Shell::pwd();
        my $date = localtime(time);
        my $dt   = `/bin/date '+%Y%m.%d.%H%M%S'` ;
        my $uptime = qx#w | head -1# ;
        my $prog = Shell::basename($0);
        $Prog = full_path($0);
	my $mixver = $ENV{MIXVER} ? $ENV{MIXVER} : '' ;
	   $Mix_session = $ENV{MIX_SESSION} ? $ENV{MIX_SESSION} : '' ;

        # Chomps can be done all at once:
        chomp( $hostname, $pwd, $date, $uptime, $prog, $dt );

    my $header = "
    ============================================================
    $date
    PROGRAM:  <$Prog>
    REVISION: <$prog Release:$revision; Last modified:$cvs_date; MIX_opt:$MIX_opt_Revision>
    DIRECTORY:<$pwd>
    ARGUMENTS:<@{$argv_ref}>
    SERVER:   <$hostname> USER:<$LOGNAME>
    UPTIME:   <$uptime>
    ===
    MIX:          <$mixver>
    MIX session:  <$Mix_session>
    ============================================================
    \n";
    $Rev_string = "$prog Release:$revision\nLast modified:$cvs_date\nMIX_opt:$MIX_opt_Revision" ;

    return ($prog,$header,$hostname) ;
}
#=================================================================================
sub commas {
    local($_) = @_;
    $_ = 0 unless $_;
    1 while s/(.*\d)(\d\d\d)/$1,$2/;
# The 1 itself is just a no-op expression used as a place holder. a 0
# or a "" would have worked as well.
    $_;
}
#=================================================================================
sub print_number {
    my ($string,$number) = @_;
    my $format = "    %-31s %10s\n";

    printf STDERR $format, $string, commas($number);
}
#=================================================================================
# Call it: my $time_string = elap_time() ;
sub elap_time {
    my $t1 = time ;
    my $abstr = sec_to_string( $t1-$BeGiNtIme );
}
#=================================================================================
sub sec_to_string {
    use strict ;
    my $sec = shift;

    my ($days,$hour,$min,$str) ;

    $days = int $sec / 86400 ;
    $hour = int $sec/3600 -$days*24 ;
    $min  = int $sec/60 - $days*1440 - $hour*60 ;
    $sec  = $sec % 60 ;

    if( $days > 0 ) {
        $str = sprintf("%2d %.2d:%.2d:%.2d", $days,$hour, $min, $sec) ;
    } else {
        $str = sprintf("%.2d:%.2d:%.2d", $hour, $min, $sec) ;
    }
    return $str ;
}
#=================================================================================
sub DEBUG {
    my $string = shift ;

    my $tm = elap_time();
    print STDERR "DEBUG <$string> $tm\n";
}
#==============================================================================
# This function is for printing of messages with a data stamp
#
sub holler {
    my($msg) = @_;
    my $date = localtime(time);

    $msg =~ s/\|/\n|/g ;   # If the message has the "pope" character insert \n after it
    warn "---$date-- $msg\n";
}
#==============================================================================
# This function is for printing of info messages.
#
sub info {
    my($msg) = @_;

    my $date = localtime(time);
    #warn "+++info ($date): $msg\n";
    my ($package,$filename,$line,$subr) = caller(0) ; # We will display only the the first call
    warn "+++info(line $line) $msg\n";

}
#==============================================================================
# This function is for printing of messages with a data stamp
#
sub mail_it {
    my $message = shift ;
    my $subject = shift ;
    my $mail_list = shift ;

    system("echo \"$message\" | mailx -s \"$subject\" $mail_list" ) ;
}
#=================================================================================
# expand all truncated names for A_ and L_ numbers
# Usage:
#         my @mols = canonic_L_A( $db_name, \@mols ) ;
# Where
#         $db_name is either "mcidb" or "anumbers"
#         @mols contains all names to be canonized
# Returns
#         An array of canonized names
sub canonic_L_A {
}
#=================================================================================
sub uniq_list {
    #Input: any @ array
    #Returns: an @ array with unique elements of the input
    #Example: my @new = uniq_list(@old) ;
    return keys %{{ map { $_ => 1 } @_ }};
}
#=================================================================================
sub make_tmp_dir {
    #Input: a directory where the unique subdirectory will be created
    #Returns:  The name of the directory just created
    #Example: my $tmp_dir = make_tmp_dir($STMP);
    my $root_dir = shift;
    chomp(my $dt=qx#/bin/date '+%Y%m.%d.%H%M%S'#);
    my $tmp_dir = "$root_dir/$LOGNAME.$dt.$$";
    while ( -d $tmp_dir ) {
        sleep 2;
        #chomp($dt=qx#/bin/date '+%Y%m.%d.%H%M%S'#);
        chomp($dt=qx#/bin/date '+%d-%b-%Y_%H:%M:%S'#);
        $tmp_dir = "$root_dir/$LOGNAME.$dt.$$";
    }
    qx#mkdir -p $tmp_dir# ;
    qx#chmod 755  $tmp_dir# ;
    return $tmp_dir;
}
#=================================================================================
1;
