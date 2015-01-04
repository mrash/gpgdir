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
# Version: 1.9.6
#
# Copyright (C) 2008-2010 Michael Rash (mbr@cipherdyne.org)
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

use Digest::MD5 'md5_base64';
use File::Find;
use File::Copy;
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
my $broken_pw_file = "$conf_dir/broken.pw";
my $key_id  = '375D7DB9';
#==================== end config ==================

my $help = 0;
my $test_num  = 0;
my $PRINT_LEN = 68;
my $APPEND    = 1;
my $NO_APPEND = 0;
my $failed_tests = 0;
my $prepare_results = 0;
my $successful_tests = 0;
my $current_test_file = "$output_dir/$test_num.test";
my $cmd_out = 'cmd.out';
my $previous_test_file = '';
my @data_dir_files  = ();
my @initial_files   = ();
my %initial_md5sums = ();

my $default_args = "--gnupg-dir $gpg_dir " .
    "--Key-id $key_id --pw-file $pw_file";

die "[*] Use --help" unless GetOptions(
    'Prepare-results' => \$prepare_results,
    'help'            => \$help
);

exit &prepare_results() if $prepare_results;

&setup();

&collect_paths_and_md5sums();

&logr("\n[+] ==> Running gpgdir test suite <==\n\n");

### execute the tests
&test_driver('(Setup) gpgdir program compilation', \&perl_compilation);
&test_driver('(Setup) Command line argument processing', \&getopt_test);
&test_driver('(Test mode) gpgdir basic test mode', \&test_mode);

### encrypt/decrypt
&test_driver('(Encrypt dir) gpgdir directory encryption', \&encrypt);
&test_driver('(Encrypt dir) Files recursively encrypted',
    \&recursively_encrypted);
&test_driver('(Encrypt dir) Exclude hidden files/dirs',
    \&skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption', \&decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&recursively_decrypted);
&test_driver('(Paths) match paths across encrypt/decrypt cycle',
    \&paths_validation);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### multi-encryption test
&test_driver('(Multi-encrypt) gpgdir directory encryption', \&encrypt);
&test_driver('(Multi-encrypt) Files recursively encrypted',
    \&recursively_encrypted);
&test_driver('(Multi-encrypt) No new encrypted files', \&multi_encrypt);
&test_driver('(Decrypt dir) gpgdir directory decryption', \&decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&recursively_decrypted);
&test_driver('(Paths) match paths across encrypt/decrypt cycle',
    \&paths_validation);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### ascii encrypt/decrypt
&test_driver('(Ascii-armor dir) gpgdir directory encryption',
    \&ascii_encrypt);
&test_driver('(Ascii-armor dir) Files recursively encrypted',
    \&ascii_recursively_encrypted);
&test_driver('(Ascii-armor dir) Exclude hidden files/dirs',
    \&skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption', \&decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&ascii_recursively_decrypted);
&test_driver('(Paths) match paths across encrypt/decrypt cycle',
    \&paths_validation);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### obfuscate filenames encrypt/decrypt cycle
&test_driver('(Obfuscate filenames) gpgdir directory encryption',
    \&obf_encrypt);
&test_driver('(Obfuscate filenames) Files recursively encrypted',
    \&obf_recursively_encrypted);
&test_driver('(Obfuscate filenames) Exclude hidden files/dirs',
    \&obf_skipped_hidden_files_dirs);
&test_driver('(Decrypt dir) gpgdir directory decryption',
    \&obf_decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&obf_recursively_decrypted);  ### same as ascii_recursively_decrypted()
&test_driver('(Paths) match paths across encrypt/decrypt cycle',
    \&paths_validation);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### multi-cycle obfuscated tests
&test_driver('(Multi-obfuscate cycle) gpgdir directory encryption',
    \&obf_encrypt);
&test_driver('(Multi-obfuscate cycle) Files recursively encrypted',
    \&obf_recursively_encrypted);
&test_driver('(Multi-obfuscate cycle) Exclude hidden files/dirs',
    \&obf_skipped_hidden_files_dirs);
&test_driver('(Multi-obfuscate cycle) No new files',
    \&multi_obf_encrypt);
&test_driver('(Decrypt dir) gpgdir directory decryption',
    \&obf_decrypt);
&test_driver('(Decrypt dir) Files recursively decrypted',
    \&obf_recursively_decrypted);  ### same as ascii_recursively_decrypted()
&test_driver('(Paths) match paths across encrypt/decrypt cycle',
    \&paths_validation);
&test_driver('(MD5 digest) match across encrypt/decrypt cycle',
    \&md5sum_validation);

### sign/verify cycle
&test_driver('(Sign/verify dir) gpgdir directory signing', \&sign);
&test_driver('(Sign/verify dir) Files recursively signed',
    \&recursively_signed);
&test_driver('(Sign/verify dir) Exclude hidden files/dirs',
    \&skipped_hidden_files_dirs);
&test_driver('(Sign/verify dir) Broken signature detection',
    \&broken_sig_detection);
&test_driver('(Sign/verify dir) gpgdir directory verification', \&verify);
&test_driver('(Sign/verify dir) Files recursively verified',
    \&recursively_verified);
&test_driver('(Paths) match paths across sign/verify cycle',
    \&paths_validation);

### bad password detection
&test_driver('(Bad passphrase) detect broken passphrase',
    \&broken_passphrase);

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

    my $test_status = 'pass';
    &dots_print($msg);
    if (&{$func_ref}) {
        &pass();
    } else {
        &logr("fail ($test_num)\n");
        $test_status = 'fail';
        $failed_tests++;
    }

    &write_file("TEST: $msg, STATUS: $test_status\n");

    $previous_test_file = $current_test_file;
    $test_num++;
    $current_test_file = "$output_dir/$test_num.test";
    return;
}

sub broken_passphrase() {
    if (not &run_cmd("$gpgdirCmd --gnupg-dir $gpg_dir " .
            " --pw-file $broken_pw_file --Key-id $key_id -e $data_dir")) {
        my $found_bad_pass = 0;
        open F, "< $current_test_file" or die $!;
        while (<F>) {
            if (/BAD_?PASS/) {
                $found_bad_pass = 1;
            }
        }
        close F;
        if ($found_bad_pass) {
            return 1;
        }
    }
    &write_file("[-] Accepted broken passphrase\n");
    return 0;
}

sub encrypt() {
    if (&run_cmd("$gpgdirCmd $default_args -e $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory encryption\n");
    return 0;
}

sub ascii_encrypt() {
    if (&run_cmd("$gpgdirCmd $default_args --Plain-ascii -e $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory encryption\n");
    return 0;
}

sub obf_encrypt() {
    if (&run_cmd("$gpgdirCmd $default_args -O -e $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory encryption\n");
    return 0;
}

sub multi_obf_encrypt() {

    my @dir_old = ();
    find(\&find_files, $data_dir);

    if (&run_cmd("$gpgdirCmd $default_args -O -e $data_dir")) {
        &write_file("[-] Re-encrypted directory in -O mode.\n");
        return 0;
    }

    my @dir_new = ();
    find(\&find_files, $data_dir);

    my ($rv, $msg) = &compare_paths(\@dir_old, \@dir_new);

    return 1 if $rv;

    &write_file($msg);
    return 0;
}

sub sign() {
    if (&run_cmd("$gpgdirCmd $default_args --sign $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory signing\n");
    return 0;
}

sub decrypt() {
    if (&run_cmd("$gpgdirCmd $default_args -d $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory decryption\n");
    return 0;
}

sub obf_decrypt() {
    if (&run_cmd("$gpgdirCmd $default_args -O -d $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory decryption\n");
    return 0;
}

sub verify() {
    if (&run_cmd("$gpgdirCmd $default_args --verify $data_dir")) {
        return 1;
    }
    &write_file("[-] Directory verification\n");
    return 0;
}

sub recursively_encrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            unless ($file =~ m|\.gpg$|) {
                &write_file("[-] File '$file' not encrypted\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub recursively_signed() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            if ($file !~ m|\.asc$|) {
                unless (-e "$file.asc") {
                    &write_file("[-] File '$file' not signed\n");
                    $rv = 0;
                }
            }
        }
    }
    return $rv;
}

sub recursively_decrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            if ($file =~ m|\.gpg$| or $file =~ m|\.pgp$|) {
                &write_file("[-] File '$file' not encrypted\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub broken_sig_detection() {
    move "$data_dir/multi-line-ascii", "$data_dir/multi-line-ascii.orig"
        or die $!;
    open F, "> $data_dir/multi-line-ascii" or die $!;
    print F "bogus data\n";
    close F;

    &run_cmd("$gpgdirCmd $default_args --verify $data_dir");

    my $found_bad_sig = 0;
    open F, "< $current_test_file" or die $!;
    while (<F>) {
        if (/BADSIG/) {
            $found_bad_sig = 1;
        }
    }
    close F;

    if ($found_bad_sig) {
        unlink "$data_dir/multi-line-ascii";
        move "$data_dir/multi-line-ascii.orig", "$data_dir/multi-line-ascii"
            or die $!;
        return 1;
    }
    &write_file("[-] Could not find bad signature\n");
    return 0;
}

sub recursively_verified() {

    ### search for signature verification errors here
    my $found_bad_sig = 0;
    open F, "< $previous_test_file" or die $!;
    while (<F>) {
        if (/BADSIG/) {
            $found_bad_sig = 1;
        }
    }
    close F;

    if ($found_bad_sig) {
        &write_file("[-] Bad signature generated\n");
        return 0;
    }

    ### now remove signature files
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            if ($file =~ m|\.asc$|) {
                unlink $file;
            }
        }
    }
    return 1;
}

sub ascii_recursively_encrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            unless ($file =~ m|\.asc$|) {
                &write_file("[-] File '$file' not encrypted\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub multi_encrypt() {

    my @dir_old = ();
    find(\&find_files, $data_dir);

    unless (&run_cmd("$gpgdirCmd $default_args -e $data_dir")) {
        &write_file("[-] Could not encrypt directory\n");
        return 0;
    }

    my @dir_new = ();
    find(\&find_files, $data_dir);

    my ($rv, $msg) = &compare_paths(\@dir_old, \@dir_new);

    return 1 if $rv;

    &write_file($msg);
    return 0;
}

sub obf_recursively_encrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        next if $file =~ m|^\.| or $file =~ m|/\.|;
        &write_file("$file\n");
        if (-f $file) {
            ### gpgdir_1.gpg
            unless ($file =~ m|gpgdir_\d+\.gpg$|) {
                &write_file("[-] File '$file' not " .
                    "encrypted and obfuscated as 'gpgdir_N.gpg'\n");
                $rv = 0;
            }
#        } elsif (-d $file) {
#            next if $file eq $data_dir;
#            ### gpgdir_d1/
#            unless ($file =~ m|gpgdir_d\d+$|) {
#                &write_file("[-] Directory '$file' not " .
#                    "obfuscated as 'gpgdir_dN'\n");
#                $rv = 0;
#            }
        }
    }
    return $rv;
}

sub ascii_recursively_decrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            if ($file =~ m|\.asc$|) {
                &write_file("[-] File '$file' not encrypted\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub obf_recursively_decrypted() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file and not ($file =~ m|^\.| or $file =~ m|/\.|)) {
            &write_file("$file\n");
            if ($file =~ m|\.asc$|) {
                &write_file("[-] File '$file' not encrypted\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub skipped_hidden_files_dirs() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if ($file =~ m|^\.| or $file =~ m|/\.|) {
            &write_file("$file\n");
            ### check for any .gpg or .asc extensions
            if ($file =~ m|\.gpg$| or $file =~ m|\.asc$|
                    or $file =~ m|\.pgp$|) {
                &write_file("[-] Encrypted hidden file\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub obf_skipped_hidden_files_dirs() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if ($file =~ m|^\.| or $file =~ m|/\.|) {
            &write_file("$file\n");
            ### check for any .gpg or .asc extensions except
            ### for the gpgdir_map_file
            if (($file !~ m|gpgdir_map_file| and $file !~ m|gpgdir_dir_map_file|)
                    and ($file =~ m|\.gpg$| or $file =~ m|\.asc$|
                    or $file =~ m|\.pgp$|)) {
                &write_file("[-] Encrypted hidden file\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub find_files() {
    my $file = $File::Find::name;
    push @data_dir_files, $file;
    return;
}

sub collect_paths_and_md5sums() {

    @data_dir_files = ();
    find(\&find_files, $data_dir);

    ### save off an initial copy of the directory structure
    @initial_files = @data_dir_files;

    for my $file (@data_dir_files) {
        if (-f $file) {
            $initial_md5sums{$file} = md5_base64($file);
        }
    }
    return 1;
}

sub paths_validation() {
    @data_dir_files = ();
    find(\&find_files, $data_dir);

    my ($rv, $msg) = &compare_paths(\@initial_files, \@data_dir_files);

    return 1 if $rv;

    &write_file($msg);
    return 0;
}

sub compare_paths() {
    my ($old_dir_ar, $new_dir_ar) = @_;

    return (0, "[-] Path mis-match")
        unless @$new_dir_ar eq @$old_dir_ar;

    for my $file (@$new_dir_ar) {
        my $found = 0;
        for my $initial_file (@$old_dir_ar) {
            if ($file eq $initial_file) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            return (0, "[-] New file $file found");
        }
    }

    for my $file (@$old_dir_ar) {
        my $found = 0;
        for my $initial_file (@$new_dir_ar) {
            if ($file eq $initial_file) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            return (0, "[-] Initial file $file not found");
        }
    }

    return 1, '';
}

sub md5sum_validation() {
    my $rv = 1;
    @data_dir_files = ();
    find(\&find_files, $data_dir);
    for my $file (@data_dir_files) {
        if (-f $file) {
            &write_file("$file\n");
            if (not defined $initial_md5sums{$file}
                    or $initial_md5sums{$file} ne md5_base64($file)) {
                &write_file("[-] MD5 sum mis-match for '$file'\n");
                $rv = 0;
            }
        }
    }
    return $rv;
}

sub test_mode() {
    if (&run_cmd("$gpgdirCmd $default_args --test")) {
        my $found = 0;
        open F, "< $current_test_file"
            or die "[*] Could not open $current_test_file: $!";
        while (<F>) {
            if (/Decrypted\s+content\s+matches\s+original/i) {
                $found = 1;
                last;
            }
        }
        close F;
        return 1 if $found;
    }
    &write_file("[-] Encrypt/decrypt basic --test mode\n");
    return 0;
}

sub perl_compilation() {
    unless (&run_cmd("perl -c $gpgdirCmd")) {
        &write_file("[-] $gpgdirCmd does not compile\n");
        return 0;
    }
    return 1;
}

sub getopt_test() {
    if (&run_cmd("$gpgdirCmd --no-such-argument")) {
        &write_file("[-] $gpgdirCmd " .
                "allowed --no-such-argument on the command line\n");
        return 0;
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

    unlink $cmd_out if -e $cmd_out;

    if (-e $current_test_file) {
        open RC, ">> $current_test_file"
            or die "[*] Could not open $current_test_file: $!";
        print RC localtime() . " CMD: $cmd\n";
        close RC;
    } else {
        open RCA, "> $current_test_file"
            or die "[*] Could not open $current_test_file: $!";
        print RCA localtime() . " CMD: $cmd\n";
        close RCA;
    }

    ### copy original file descriptors (credit: Perl Cookbook)
    open OLDOUT, ">&STDOUT";
    open OLDERR, ">&STDERR";

    ### redirect command output
    open STDOUT, "> $cmd_out" or die "[*] Could not redirect stdout: $!";
    open STDERR, ">&STDOUT"   or die "[*] Could not dup stdout: $!";

    my $rv = ((system $cmd) >> 8);

    close STDOUT or die "[*] Could not close STDOUT: $!";
    close STDERR or die "[*] Could not close STDERR: $!";

    ### restore original filehandles
    open STDERR, ">&OLDERR" or die "[*] Could not restore stderr: $!";
    open STDOUT, ">&OLDOUT" or die "[*] Could not restore stdout: $!";

    ### close the old copies
    close OLDOUT or die "[*] Could not close OLDOUT: $!";
    close OLDERR or die "[*] Could not close OLDERR: $!";

    open C, "< $cmd_out" or die "[*] Could not open $cmd_out: $!";
    my @cmd_lines = <C>;
    close C;

    open L, ">> $current_test_file" or
        die "[*] Could not open $current_test_file: $!";
    for (@cmd_lines) {
        if (/\n/) {
            print L $_;
        } else {
            print L $_, "\n";
        }
    }
    close L;

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

    die "[*] Password file $pw_file does not exist" unless -f $pw_file;
    die "[*] Broken password file $broken_pw_file does not exist"
        unless -f $broken_pw_file;
    die "[*] $data_dir/multi-line-ascii file does not exist"
        unless -f "$data_dir/multi-line-ascii";

    for my $file (glob("$output_dir/cmd*")) {
        unlink $file or die "[*] Could not unlink($file)";
    }

    for my $file (glob("$output_dir/*.test")) {
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

sub write_file() {
    my $msg = shift;
    open C, ">> $current_test_file"
        or die "[*] Could not open $current_test_file $!";
    print C $msg;
    close C;
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
