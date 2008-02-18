#!/usr/bin/perl -w
#
#############################################################################
#
# File: gpgdir_test.pl
#
# Purpose: This program provides a testing infrastructure for the gpgdir
#          Single Packet Authorization client and server.
#
# Author: Michael Rash (mbr@cipherdyne.org)
#
# Copyright (C) 2007 Michael Rash (mbr@cipherdyne.org)
#
# License (GNU Public License):
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
#    USA
#
#############################################################################
#
# $Id: gpgdir_test.pl 1004 2008-02-10 04:49:04Z mbr $
#

use File::Find;
use Getopt::Long;
use strict;

#=================== config defaults ==============
my $gpgdirCmd = '../gpgdir';

my $conf_dir   = 'conf';
my $output_dir = 'output';
my $logfile    = 'test.log';
my $tarfile    = 'gpgdir_test.tar.gz';

my $cmd_stdout = "$output_dir/cmd.stdout";
my $cmd_stderr = "$output_dir/cmd.stderr";
#==================== end config ==================

my $help = 0;
my $test_num  = 0;
my $PRINT_LEN = 68;
my $failed_tests = 0;
my $prepare_results = 0;
my $successful_tests = 0;

exit 1 unless GetOptions(
    'Prepare-results' => \$prepare_results,
    'help'            => \$help
);

exit &prepare_results() if $prepare_results;

### execute the tests
&test_driver('(Setup) gpgdir program compilation', \&perl_compilation);
&test_driver('(Setup) Command line argument processing', \&getopt_test);

exit 0;
#======================== end main =========================

sub test_driver() {
    my ($msg, $func_ref) = @_;

    &dots_print($msg);
    if (&{$func_ref}) {
        &pass();
    } else {
        $failed_tests++;
    }
    $test_num++;
    return;
}

sub perl_compilation() {
    unless (&run_cmd("perl -c $gpgdirCmd")) {
        return &print_errors("fail ($test_num)\n[*] " .
            "$gpgdirCmd does not compile");
    }
    return 1;
}

sub getopt_test() {
    if (&run_cmd("$gpgdirCmd --no-such-argument")) {
        return &print_errors("fail ($test_num)\n[*] $gpgdirCmd " .
                "allowed --no-such-argument on the command line");
    }
    return 1;
}

sub dots_print() {
    my $msg = shift;
    &logr($msg);
    my $dots = '';
    for (my $i=length($msg); $i < $PRINT_LEN; $i++) {
        $dots .= '.';
    }
    &logr($dots);
    return;
}

sub run_cmd() {
    my $cmd = shift;
    my $rv = ((system "$cmd > ${cmd_stdout}.$test_num " .
            "2> ${cmd_stderr}.$test_num") >> 8);
    if ($rv == 0) {
        return 1;
    }
    return 0;
}

sub prepare_results() {
    my $rv = 0;
    die "[*] $output_dir does not exist" unless -d $output_dir;
    die "[*] $logfile does not exist, has fwknop_test.pl been executed?"
        unless -e $logfile;
    if (-e $tarfile) {
        unlink $tarfile or die "[*] Could not unlink $tarfile: $!";
    }

    ### create tarball
    system "tar cvfz $tarfile $logfile $output_dir";
    print "[+] Test results file: $tarfile\n";
    if (-e $tarfile) {
        $rv = 1;
    }
    return $rv;
}

sub setup() {

    $|++; ### turn off buffering

    die "[*] $conf_dir directory does not exist." unless -d $conf_dir;
    unless (-d $output_dir) {
        mkdir $output_dir or die "[*] Could not mkdir $output_dir: $!";
    }

    for my $file (glob("$output_dir/cmd*")) {
        unlink $file or die "[*] Could not unlink($file)";
    }

    for my $file (glob("$output_dir/*.warn")) {
        unlink $file or die "[*] Could not unlink($file)";
    }

    for my $file (glob("$output_dir/*.die")) {
        unlink $file or die "[*] Could not unlink($file)";
    }

    die "[*] $gpgdirCmd does not exist" unless -e $gpgdirCmd;
    die "[*] $gpgdirCmd not executable" unless -x $gpgdirCmd;

    if (-e $logfile) {
        unlink $logfile or die $!;
    }
    return;
}

sub pass() {
    &logr("pass ($test_num)\n");
    $successful_tests++;
    return;
}

sub logr() {
    my $msg = shift;

    print STDOUT $msg;
    open F, ">> $logfile" or die $!;
    print F $msg;
    close F;
    return;
}
