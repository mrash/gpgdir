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
# Copyright (C) 2008 Michael Rash (mbr@cipherdyne.org)
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
# $Id$
#

use Digest::MD5 'md5_base64';
use File::Find;
use Getopt::Long;
use strict;

#=================== config defaults ==============
my $gpgdirCmd = '../gpgdir';

my $conf_dir   = 'conf';
my $output_dir = 'output';
my $logfile    = 'test.log';
my $tarfile    = 'gpgdir_test.tar.gz';
my $data_dir   = 'data-dir';

my $gpg_dir = "$conf_dir/test-gpg";
my $pw_file = "$conf_dir/test.pw";
my $key_id  = '375D7DB9';

my $cmd_stdout = "$output_dir/cmd.stdout";
my $cmd_stderr = "$output_dir/cmd.stderr";
#==================== end config ==================

my $help = 0;
my $test_num  = 0;
my $PRINT_LEN = 68;
my $failed_tests = 0;
my $prepare_results = 0;
my $successful_tests = 0;
my @data_dir_files = ();
my %md5sums = ();

die "[*] Use --help" unless GetOptions(
    'Prepare-results' => \$prepare_results,
    'help'            => \$help
);

exit &prepare_results() if $prepare_results;

&setup();

&collect_md5sums();

&logr("\n[+] ==> Running gpgdir test suite <==\n\n");

### execute the tests
&test_driver('(Setup) gpgdir program compilation', \&perl_compilation);
&test_driver('(Setup) Command line argument processing', \&getopt_test);
&test_driver('(Test mode) gpgdir basic test mode', \&test_mode);

### encrypt/decrypt
&test_driver('(Encrypt dir) gpgdir directory encryption', \&encrypt);
&test_driver('(Encrypt dir) Files recursively encrypted',
    \&recursively_encrypted);
&test_driver('(Encrypt dir) Excluded hidden files/dirs',
    \&skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption', \&decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&recursively_decrypted);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### ascii encrypt/decrypt
&test_driver('(Ascii-armor dir) gpgdir directory encryption',
    \&ascii_encrypt);
&test_driver('(Ascii-armor dir) Files recursively encrypted',
    \&ascii_recursively_encrypted);
&test_driver('(Ascii-armor dir) Excluded hidden files/dirs',
    \&skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption', \&decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&ascii_recursively_decrypted);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### obfuscate filenames encrypt/decrypt cycle
&test_driver('(Obfuscate filenames) gpgdir directory encryption',
    \&obf_encrypt);
&test_driver('(Obfuscate filenames) Files recursively encrypted',
    \&obf_recursively_encrypted);
&test_driver('(Obfuscate filenames) Excluded hidden files/dirs',
    \&obf_skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption',
    \&obf_decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&obf_recursively_decrypted);  ### same as ascii_recursively_decrypted()
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

&logr("\n");
if ($successful_tests) {
    &logr("[+] ==> Passed $successful_tests/$test_num tests " .
        "against gpgdir. <==\n");
}
if ($failed_tests) {
    &logr("[+] ==> Failed $failed_tests/$test_num tests " .
        "against gpgdir. <==\n");
}
&logr("[+] This console output has been stored in: $logfile\n\n");

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

sub encrypt() {
    if (&run_cmd("$gpgdirCmd --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id -e $data_dir")) {
        return 1;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Directory encryption");
}

sub ascii_encrypt() {
    if (&run_cmd("$gpgdirCmd --Plain-ascii --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id -e $data_dir")) {
        return 1;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Directory encryption");
}

sub obf_encrypt() {
    if (&run_cmd("$gpgdirCmd -O --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id -e $data_dir")) {
        return 1;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Directory encryption");
}

sub decrypt() {
    if (&run_cmd("$gpgdirCmd --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id -d $data_dir")) {
        return 1;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Directory decryption");
}

sub obf_decrypt() {
    if (&run_cmd("$gpgdirCmd -O --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id -d $data_dir")) {
        return 1;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Directory decryption");
}

sub recursively_encrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            unless ($file =~ m|\.gpg$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted");
            }
        }
    }
    return 1;
}

sub recursively_decrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            if ($file =~ m|\.gpg$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted");
            }
        }
    }
    return 1;
}

sub ascii_recursively_encrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            unless ($file =~ m|\.asc$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted");
            }
        }
    }
    return 1;
}

sub obf_recursively_encrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            ### gpgdir_20089_1.gpg
            unless ($file =~ m|gpgdir_\d+_\d+\.gpg$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted and obfuscated");
            }
        }
    }
    return 1;
}

sub ascii_recursively_decrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            if ($file =~ m|\.asc$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted");
            }
        }
    }
    return 1;
}

sub obf_recursively_decrypted() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            if ($file =~ m|\.asc$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "File $file not encrypted");
            }
        }
    }
    return 1;
}

sub skipped_hidden_files_dirs() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if ($file =~ m|^\.| or $file =~ m|/\.|) {
            ### check for any .gpg or .asc extensions except
            ### for the gpgdir_map_file
            if ($file =~ m|\.gpg$| or $file =~ m|\.asc$|) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "Encrypted hidden file");
            }
        }
    }
    return 1;
}

sub obf_skipped_hidden_files_dirs() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if ($file =~ m|^\.| or $file =~ m|/\.|) {
            ### check for any .gpg or .asc extensions except
            ### for the gpgdir_map_file
            if ($file !~ m|gpgdir_map_file| and ($file =~ m|\.gpg$|
                    or $file =~ m|\.asc$|)) {
                return &print_errors("fail ($test_num)\n[*] " .
                    "Encrypted hidden file");
            }
        }
    }
    return 1;
}


sub find_files() {
    my $file = $File::Find::name;
    push @data_dir_files, $file;
    return;
}

sub collect_md5sums() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file) {
            $md5sums{$file} = md5_base64($file);
        }
    }
    return 1;
}

sub md5sum_validation() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file) {
            if (not defined $md5sums{$file}
                    or $md5sums{$file} ne md5_base64($file)) {
                return &print_errors("fail ($test_num)\n[*] " .
                        "MD5 sum mis-match for $file");
            }
        }
    }
    return 1;
}

sub test_mode() {
    if (&run_cmd("$gpgdirCmd --test --gnupg-dir $gpg_dir " .
            " --pw-file $pw_file --Key-id $key_id")) {
        my $found = 0;
        open F, "< ${cmd_stdout}.$test_num"
            or die "[*] Could not open ${cmd_stderr}.$test_num: $!";
        while (<F>) {
            if (/Decrypted\s+content\s+matches\s+original/i) {
                $found = 1;
                last;
            }
        }
        close F;
        return 1 if $found;
    }
    return &print_errors("fail ($test_num)\n[*] " .
        "Encrypt/decrypt basic --test mode");
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

sub print_errors() {
    my $msg = shift;
    &logr("$msg\n");
    if (-e "${cmd_stderr}.$test_num") {
        &logr("    STDOUT available in: " .
            "${cmd_stdout}.$test_num file.\n");
    }
    if (-e "${cmd_stderr}.$test_num") {
        &logr("    STDERR available in: " .
            "${cmd_stderr}.$test_num file.\n");
    }
    return 0;
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
    die "[*] $logfile does not exist, has gpgdir_test.pl been executed?"
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
