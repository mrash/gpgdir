#!/usr/bin/perl -w
#
###########################################################################
#
# File: gpgdir
#
# URL: http://www.cipherdyne.org/gpgdir/
#
# Purpose:  To encrypt/decrypt whole directories
#
# Author: Michael Rash (mbr@cipherdyne.com)
#
# Version: 1.7
#
# Copyright (C) 2002-2007 Michael Rash (mbr@cipherdyne.org)
#
# License (GNU General Public License):
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
###########################################################################
#

use lib '/usr/lib/gpgdir';
use File::Find;
use File::Copy;
use Term::ReadKey;
use GnuPG::Interface;
use IO::File;
use IO::Handle;
use Getopt::Long;
use Cwd;
use strict;

### set the current gpgdir version and file revision numbers
my $version = '1.7';
my $revision_svn = '$Revision: 246 $';
my $rev_num = '1';
($rev_num) = $revision_svn =~ m|\$Rev.*:\s+(\S+)|;

### establish some defaults
my $encrypt_user    = '';
my $gpg_homedir     = '';
my $dir             = '';
my $pw              = '';
my $encrypt_dir     = '';
my $decrypt_dir     = '';
my $homedir         = '';
my $exclude_pat     = '';
my $exclude_file    = '';
my $include_pat     = '';
my $include_file    = '';
my $total_encrypted = 0;
my $total_decrypted = 0;
my $norecurse       = 0;
my $printver        = 0;
my $no_delete       = 0;
my $no_fs_times     = 0;
my $test_and_exit   = 0;
my $trial_run       = 0;
my $skip_test_mode  = 0;
my $verbose         = 0;
my $quiet           = 0;
my $use_gpg_agent   = 0;  ### use gpg-agent for passwords
my $gpg_agent_info  = '';
my $force_mode      = 0;
my $help            = 0;
my $wipe_mode       = 0;
my $encrypt_mode    = 0;
my $use_default_key = 0;
my $pw_file         = '';
my $wipe_cmd        = '/usr/bin/wipe';
my $wipe_cmdline    = '';
my $wipe_interactive = 0;
my $interactive_mode = 0;
my $ascii_armor_mode = 0;
my @exclude_patterns = ();
my @include_patterns = ();
my %files            = ();
my %options          = ();
my %obfuscate_ctrs   = ();
my %obfuscated_dirs  = ();
my $have_obfuscated_file = 0;
my $cmdline_no_password = 0;
my $obfuscate_mode = 0;
my $obfuscate_map_filename  = '.gpgdir_map_file';
my $overwrite_encrypted = 0;
my $overwrite_decrypted = 0;
my $symmetric_mode  = 0;
my $DEL_SOURCE_FILE = 1;
my $NO_DEL_SOURCE_FILE = 0;

### for user answers
my $ACCEPT_YES_DEFAULT = 1;
my $ACCEPT_NO_DEFAULT  = 2;

unless ($< == $>) {
    die "[*] Real and effective uid must be the same.  Make sure\n",
        "    gpgdir has not been installed as a SUID binary.\n",
        "Exiting.";
}

my @args_cp = @ARGV;

### make Getopts case sensitive
Getopt::Long::Configure('no_ignore_case');

die "[-] Use --help for usage information.\n" unless(GetOptions (
    'encrypt=s'      => \$encrypt_dir,     # Encrypt files in this directory.
    'decrypt=s'      => \$decrypt_dir,     # Decrypt files in this directory.
    'gnupg-dir=s'    => \$gpg_homedir,     # Path to /path/to/.gnupg directory.
    'pw-file=s'      => \$pw_file,         # Read password out of this file.
    'agent'          => \$use_gpg_agent,   # Use gpg-agent for passwords.
    'Agent-info=s'   => \$gpg_agent_info,  # Specify GnuPG agent connection
                                           # information.
    'Wipe'           => \$wipe_mode,       # Securely delete unencrypted files.
    'wipe-path=s'    => \$wipe_cmd,        # Path to wipe command.
    'wipe-interactive' => \$wipe_interactive, # Disable "wipe -I"
    'wipe-cmdline=s' => \$wipe_cmdline,    # Specify wipe command line.
    'Obfuscate-filenames' => \$obfuscate_mode, # substitute real filenames
                                           # with manufactured ones.
    'obfuscate-map-file=s' => \$obfuscate_map_filename, # path to mapping file.
    'Force'          => \$force_mode,      # Continue if files can't be deleted.
    'overwrite-encrypted' => \$overwrite_encrypted, # Overwrite encrypted files
                                                    # even if they exist.
    'overwrite-decrypted' => \$overwrite_decrypted, # Overwrite decrypted files
                                                    # even if they exist.
    'Exclude=s'      => \$exclude_pat,     # Exclude a pattern from encrypt/decrypt
                                           # cycle.
    'Exclude-from=s' => \$exclude_file,    # Exclude patterns in <file> from
                                           # encrypt decrypt cycle.
    'Include=s'      => \$include_pat,     # Specify a pattern used to restrict
                                           # encrypt/decrypt operation to.
    'Include-from=s' => \$include_file,    # Specify a file of include patterns to
                                           # restrict all encrypt/decrypt
                                           # operations to.
    'test-mode'      => \$test_and_exit,   # Run encrypt -> decrypt test only and
                                           # exit.
    'Trial-run'      => \$trial_run,       # Don't modify any files; just show what
                                           # would have happened.
    'quiet'          => \$quiet,           # Print as little as possible to
                                           # stdout.
    'Interactive'    => \$interactive_mode, # Query the user before encrypting/
                                            # decrypting/deleting any files.
    'Key-id=s'       => \$encrypt_user,    # Specify encrypt/decrypt key
    'Default-key'    => \$use_default_key, # Assume that default-key is set within
                                           # ~/.gnupg/options.
    'Symmetric'      => \$symmetric_mode, # encrypt using symmetric cipher.
                                                  # (this option is not required to
                                                  # also decrypt, GnuPG handles
                                                  # that automatically).
    'Plain-ascii'    => \$ascii_armor_mode, # Ascii armor mode (creates non-binary
                                            # encrypted files).
    'skip-test'      => \$skip_test_mode,  # Skip encrypt -> decrypt test.
    'no-recurse'     => \$norecurse,       # Don't encrypt/decrypt files in
                                           # subdirectories.
    'no-delete'      => \$no_delete,       # Don't delete files once they have
                                           # been encrypted.
    'no-password'    => \$cmdline_no_password, # Do not query for a password (only
                                               # useful for when the gpg literally
                                               # has no password).
    'user-homedir=s' => \$homedir,         # Path to home directory.
    'no-preserve-times' => \$no_fs_times,  # Don't preserve mtimes or atimes.
    'verbose'        => \$verbose,         # Verbose mode.
    'Version'        => \$printver,        # Print version
    'help'           => \$help             # Print help
));
&usage_and_exit() if $help;

print "[+] gpgdir v$version (file revision: $rev_num)\n",
    "      by Michael Rash <mbr\@cipherdyne.org>\n"
    and exit 0 if $printver;

if ($symmetric_mode and ($use_gpg_agent or $gpg_agent_info)) {
    die "[*] gpg-agent incompatible with --Symmetric mode";
}

if ($encrypt_dir and $overwrite_decrypted) {
    die "[*] The -e and --overwrite-decrypted options are incompatible.";
}
if ($decrypt_dir and $overwrite_encrypted) {
    die "[*] The -d and --overwrite-encrypted options are incompatible.";
}

if ($wipe_mode) {
    unless (-e $wipe_cmd) {
        die "[*] Can't find wipe command at: $wipe_cmd,\n",
            "    use --wipe-path to specify path.";
    }
    unless (-e $wipe_cmd) {
        die "[*] Can't execute $wipe_cmd";
    }
}

### build up GnuPG options hash
if ($verbose) {
    %options = ('homedir' => $gpg_homedir);
} else {
    %options = (
        'batch'   => 1,
        'homedir' => $gpg_homedir
    );
}

$options{'armor'} = 1 if $ascii_armor_mode;

### get the path to the user's home directory
$homedir = &get_homedir() unless $homedir;

unless ($symmetric_mode) {
    if ($gpg_homedir) {  ### specified on the command line with --gnupg-dir
        unless ($gpg_homedir =~ /\.gnupg$/) {
            die "[*] Must specify the path to a user .gnupg directory ",
                "e.g. /home/username/.gnupg\n";
        }
    } else {
        if (-d "${homedir}/.gnupg") {
            $gpg_homedir = "${homedir}/.gnupg";
        }
    }
    unless (-d $gpg_homedir) {
        die "[*] GnuPG directory: ${homedir}/.gnupg does not exist. Please\n",
            "    create it by executing: \"gpg --gen-key\".  Exiting.\n";
    }

    ### get the key identifier from ~/.gnupg
    $encrypt_user = &get_key() unless $encrypt_user or $use_default_key;
}

if ($decrypt_dir and $encrypt_dir) {
    die "[*] You cannot encrypt and decrypt the same directory.\n";
    &usage_and_exit();
}

unless ($decrypt_dir or $encrypt_dir or $test_and_exit) {
    print "[*] Please specify -e <dir>, -d <dir>, or --test-mode\n";
    &usage_and_exit();
}

### exclude file pattern
push @exclude_patterns, $exclude_pat if $exclude_pat;

if ($exclude_file) {
    open P, "< $exclude_file" or die "[*] Could not open file: $exclude_file";
    my @lines = <P>;
    close P;
    for my $line (@lines) {
        next unless $line =~ /\S/;
        chomp $line;
        push @exclude_patterns, qr{$line};
    }
}

### include file pattern
push @include_patterns, $include_pat if $include_pat;

if ($include_file) {
    open P, "< $include_file" or die "[*] Could not open file: $include_file";
    my @lines = <P>;
    close P;
    for my $line (@lines) {
        next unless $line =~ /\S/;
        chomp $line;
        push @include_patterns, qr{$line};
    }
}

if ($encrypt_dir) {
    $dir = $encrypt_dir;
    $encrypt_mode = 1;
} elsif ($decrypt_dir) {
    $dir = $decrypt_dir;
    $encrypt_mode = 0;
}

if ($dir) {
    die "[*] Directory does not exist: $dir" unless -e $dir;
    die "[*] Not a directory: $dir" unless -d $dir;
}

### don't need to test encrypt/decrypt ability if we are running
### in --Trial-run mode.
$skip_test_mode = 1 if $trial_run;

my $initial_dir = cwd or die "[*] Could not get CWD: $!";

if ($symmetric_mode) {
    &get_password();
} else {
    &get_password() unless $encrypt_mode and $skip_test_mode;
}

if ($dir eq '.') {
    $dir = $initial_dir;
} elsif ($dir !~ m|^/|) {
    $dir = $initial_dir . '/' . $dir;
}
$dir =~ s|/$||;  ### remove any trailing slash

### run a test to make sure gpgdir and encrypt and decrypt a file
unless ($skip_test_mode) {
    my $rv = &test_mode();
    exit $rv if $test_and_exit;
}

if ($encrypt_mode) {
    print "[+] Encrypting directory: $dir\n" unless $quiet;
} else {
    print "[+] Decrypting directory: $dir\n" unless $quiet;
}

### build a hash of file paths to work against
&get_files($dir);

### perform the gpg operation (encrypt/decrypt)
&gpg_operation();

&obfuscated_mapping_files() if $obfuscate_mode;

unless ($obfuscate_mode) {
    if ($have_obfuscated_file) {
        print "[-] Obfuscated filenames detected, try decrypting with -O.\n"
            unless $quiet;
    }
}

if ($encrypt_mode) {
    print "[+] Total number of files encrypted: " .
        "$total_encrypted\n" unless $quiet;
} else {
    print "[+] Total number of files decrypted: " .
        "$total_decrypted\n" unless $quiet;
}

exit 0;
#==================== end main =====================

sub encrypt_file() {
    my ($in_file, $out_file, $del_flag) = @_;

    my $gpg = GnuPG::Interface->new();
    $gpg->options->hash_init(%options);

    die "[*] Could not create new gpg object with ",
        "homedir: $gpg_homedir" unless $gpg;

    unless ($symmetric_mode or $use_default_key) {
        $gpg->options->default_key($encrypt_user);
        $gpg->options->push_recipients($encrypt_user);
    }

    my ($input_fh, $output_fh, $error_fh, $pw_fh, $status_fh) =
        (IO::File->new($in_file),
        IO::File->new("> $out_file"),
        IO::Handle->new(),
        IO::Handle->new(),
        IO::Handle->new());

    my $handles = GnuPG::Handles->new(
        stdin  => $input_fh,
        stdout => $output_fh,
        stderr => $error_fh,
        passphrase => $pw_fh,
        status => $status_fh
    );
    $handles->options('stdin')->{'direct'}  = 1;
    $handles->options('stdout')->{'direct'} = 1;

    my $pid;

    if ($use_gpg_agent or $gpg_agent_info) {

        ### set environment explicitly if --Agent was specified
        if ($gpg_agent_info) {
            $ENV{'GPG_AGENT_INFO'} = $gpg_agent_info;
        }

        $pid = $gpg->encrypt('handles' => $handles,
            'command_args' => [ qw( --use-agent ) ]);

    } else {
        if ($symmetric_mode) {
            $pid = $gpg->encrypt_symmetrically('handles' => $handles);
        } else {
            $pid = $gpg->encrypt('handles' => $handles);
        }
    }

    print $pw_fh $pw;
    close $pw_fh;

    my @errors = <$error_fh>;

    if ($verbose) {
        print for @errors;
    } else {
        for (@errors) {
            print if /bad\s+pass/;
        }
    }

    close $input_fh;
    close $output_fh;
    close $error_fh;
    close $status_fh;

    waitpid $pid, 0;

    if (-s $out_file == 0) {
        &delete_file($out_file);
        &delete_file($in_file) if $del_flag == $DEL_SOURCE_FILE;
        if ($use_gpg_agent) {
            die "[*] Created zero-size file: $out_file\n",
"    Maybe gpg-agent does not yet have the password for that key?\n",
"    Try re-running with -v.";
        } else {
            die "[*] Created zero-size file: $out_file\n",
                "    Bad password? Try re-running with -v.";
        }
    }

    return;
}

sub decrypt_file() {
    my ($in_file, $out_file, $del_flag) = @_;

    my $gpg = GnuPG::Interface->new();
    $gpg->options->hash_init(%options);

    die "[*] Could not create new gpg object with ",
        "homedir: $gpg_homedir" unless $gpg;

    unless ($symmetric_mode or $use_default_key) {
        $gpg->options->default_key($encrypt_user);
        $gpg->options->push_recipients($encrypt_user);
    }

    my ($input_fh, $output_fh, $error_fh, $pw_fh, $status_fh) =
        (IO::File->new($in_file),
        IO::File->new("> $out_file"),
        IO::Handle->new(),
        IO::Handle->new(),
        IO::Handle->new());

    my $handles = GnuPG::Handles->new(
        stdin  => $input_fh,
        stdout => $output_fh,
        stderr => $error_fh,
        passphrase => $pw_fh,
        status => $status_fh
    );
    $handles->options('stdin')->{'direct'}  = 1;
    $handles->options('stdout')->{'direct'} = 1;

    my $pid;

    if ($use_gpg_agent) {
        $pid = $gpg->decrypt('handles' => $handles,
            'command_args' => [ qw( --use-agent ) ]);
    } else {
        $pid = $gpg->decrypt('handles' => $handles);
    }

    print $pw_fh $pw;
    close $pw_fh;

    my @errors = <$error_fh>;

    if ($verbose) {
        print for @errors;
    } else {
        for (@errors) {
            print if /bad\s+pass/;
        }
    }

    close $input_fh;
    close $output_fh;
    close $error_fh;
    close $status_fh;

    waitpid $pid, 0;

    if (-s $out_file == 0) {
        &delete_file($out_file);
        &delete_file($in_file) if $del_flag == $DEL_SOURCE_FILE;
        if ($use_gpg_agent) {
            die "[*] Created zero-size file: $out_file\n",
"    Maybe gpg-agent does not yet have the password for that key?\n",
"    Try re-running with -v.";
        } else {
            die "[*] Created zero-size file: $out_file\n",
                "    Bad password? Try re-running with -v.";
        }
    }
    return;
}

sub delete_file() {
    my $file = shift;

    return if $no_delete;
    return unless -e $file;

    if ($wipe_mode) {
        my $cmd = $wipe_cmd;
        if ($wipe_cmdline) {
            $cmd .= " $wipe_cmdline ";
        } else {
            if ($wipe_interactive) {
                $cmd .= ' -i ';
            } else {
                $cmd .= ' -I -s ';
            }
        }
        $cmd .= $file;
        if ($verbose) {
            print "    Executing: $cmd\n";
        }

        ### wipe the file
        system $cmd;

    } else {
        unlink $file;
    }

    if (-e $file) {
        my $msg = "[-] Could not delete file: $file\n";
        if ($force_mode) {
            print $msg unless $quiet;
        } else {
            die $msg unless $quiet;
        }
    }
    return;
}

sub gpg_operation() {

    ### sort by oldest to youngest mtime
    FILE: for my $file (sort
            {$files{$a}{'mtime'} <=> $files{$b}{'mtime'}} keys %files) {

        ### see if we have an exclusion pattern that implies
        ### we should skip this file
        if (@exclude_patterns and &exclude_file($file)) {
            print "[+] Skipping excluded file: $file\n"
                if $verbose and not $quiet;
            next FILE;
        }

        ### see if we have an inclusion pattern that implies
        ### we should process this file
        if (@include_patterns and not &include_file($file)) {
            print "[+] Skipping non-included file: $file\n"
                if $verbose and not $quiet;
            next FILE;
        }

        ### dir is always a full path
        my ($dir, $filename) = ($file =~ m|(.*)/(.*)|);

        unless (chdir($dir)) {
            print "[-] Could not chdir $dir, skipping.\n" unless $quiet;
            next FILE;
        }

        my $mtime = $files{$file}{'mtime'};
        my $atime = $files{$file}{'atime'};

        if ($encrypt_mode) {

            my $encrypt_filename = "$filename.gpg";

            if ($obfuscate_mode) {

                unless (defined $obfuscate_ctrs{$dir}) {

                    ### create a new gpgdir mapping file for obfuscated file
                    ### names, but preserve any previously encrypted file
                    ### name mappings
                    &handle_old_obfuscated_map_file();

                    ### make obfuscated file names start at 1 for each
                    ### directory
                    $obfuscate_ctrs{$dir} = 1;
                }

                $encrypt_filename = 'gpgdir_' . $$ . '_'
                        . $obfuscate_ctrs{$dir} . '.gpg';
            }

            if ($ascii_armor_mode) {
                $encrypt_filename = "$filename.asc";
            }

            if (-e $encrypt_filename and not $overwrite_encrypted) {
                print "[-] Encrypted file $dir/$encrypt_filename already ",
                    "exists, skipping.\n" unless $quiet;
                next FILE;
            }

            if ($interactive_mode) {
                next FILE unless (&query_yes_no(
                    "    Encrypt: $file ([y]/n)?  ", $ACCEPT_YES_DEFAULT));
            }

            print "[+] Encrypting:  $file\n" unless $quiet;

            unless ($trial_run) {

                &encrypt_file($filename, $encrypt_filename,
                        $NO_DEL_SOURCE_FILE);

                if (-e $encrypt_filename && -s $encrypt_filename != 0) {
                    ### set the atime and mtime to be the same as the
                    ### original file.
                    unless ($no_fs_times) {
                        if (defined $mtime and $mtime and
                                defined $atime and $atime) {
                            utime $atime, $mtime, $encrypt_filename;
                        }
                    }
                    ### only delete the original file if
                    ### the encrypted one exists
                    if ($wipe_mode and not $quiet) {
                        print "    Securely deleting file: $file\n";
                    }
                    &delete_file($filename);

                    if ($obfuscate_mode) {

                        ### record the original file name mapping
                        &append_obfuscated_mapping($filename,
                            $encrypt_filename);

                        $obfuscate_ctrs{$dir}++;
                    }

                    $total_encrypted++;

                } else {
                    print "[-] Could not encrypt file: $file\n" unless $quiet;
                    next FILE;
                }
            }

        } else {

            ### allow filenames with spaces
            my $decrypt_filename = '';
            if ($filename =~ /^(.+)\.gpg$/) {
                $decrypt_filename = $1;
            } elsif ($filename =~ /^(.+)\.asc$/) {
                $decrypt_filename = $1;
            }

            if ($obfuscate_mode) {

                &import_obfuscated_file_map($dir)
                    unless defined $obfuscated_dirs{$dir};

                if (defined $obfuscated_dirs{$dir}{$filename}) {
                    $decrypt_filename = $obfuscated_dirs{$dir}{$filename};
                } else {
                    ###
                    print "[-] Obfuscated file map does not exist for $filename in\n",
                        "    $obfuscate_map_filename, skipping.\n";
                    next FILE;
                }

            } else {
                if (not $force_mode and $file =~ /gpgdir_\d+_\d+.gpg/) {
                    ### be careful not to decrypt obfuscated file unless we
                    ### are running in -O mode.  This ensures that the
                    ### original file names will be acquired from the
                    ### /some/dir/.gpgdir_map_file
                    $have_obfuscated_file = 1;
                    next FILE;
                }
            }

            ### length() allows files named "0"
            next FILE unless length($decrypt_filename) > 0;

            ### don't decrypt a file on top of a normal file of
            ### the same name
            if (-e $decrypt_filename and not $overwrite_decrypted) {
                print "[-] Decrypted file $dir/$decrypt_filename ",
                    "already exists. Skipping.\n" unless $quiet;
                next FILE;
            }

            if ($interactive_mode) {
                next FILE unless (&query_yes_no(
                    "    Decrypt: $file ([y]/n)?  ", $ACCEPT_YES_DEFAULT));
            }

            unless ($trial_run) {

                print "[+] Decrypting:  $dir/$filename\n" unless $quiet;
                &decrypt_file($filename, $decrypt_filename,
                        $NO_DEL_SOURCE_FILE);

                if (-e $decrypt_filename && -s $decrypt_filename != 0) {
                    ### set the atime and mtime to be the same as the
                    ### original file.
                    unless ($no_fs_times) {
                        if (defined $mtime and $mtime and
                                defined $atime and $atime) {
                            utime $atime, $mtime, $decrypt_filename;
                        }
                    }
                    if ($wipe_mode and not $quiet) {
                        print "    Securely deleting file: $file\n";
                    }
                    ### only delete the original encrypted
                    ### file if the decrypted one exists
                    &delete_file($filename);

                    $total_decrypted++;

                } else {
                    print "[-] Could not decrypt file: $file\n" unless $quiet;
                    next FILE;
                }
            }
        }
    }
    print "\n" unless $quiet;
    chdir $initial_dir or die "[*] Could not chdir: $initial_dir\n";
    return;
}

sub get_files() {
    my $dir = shift;

    print "[+] Building file list...\n" unless $quiet;
    if ($norecurse) {
        opendir D, $dir or die "[*] Could not open $dir: $!";
        my @files = readdir D;
        closedir D;

        for my $file (@files) {
            next if $file eq '.';
            next if $file eq '..';
            &check_file_criteria("$dir/$file");
        }
    } else {
        ### get all files in all subdirectories
        find(\&find_files, $dir);
    }
    return;
}

sub exclude_file() {
    my $file = shift;
    for my $pat (@exclude_patterns) {
        if ($file =~ m|$pat|) {
            print "[+] Skipping $file (matches exclude pattern: $pat)\n"
                if $verbose and not $quiet;
            return 1;
        }
    }
    return 0;
}

sub include_file() {
    my $file = shift;
    for my $pat (@include_patterns) {
        if ($file =~ m|$pat|) {
            print "[+] Including $file (matches include pattern: $pat)\n"
                if $verbose and not $quiet;
            return 1;
        }
    }
    return 0;
}

sub obfuscated_mapping_files() {
    my $dirs_href;

    if ($encrypt_mode) {
        $dirs_href = \%obfuscate_ctrs;
    } else {
        $dirs_href = \%obfuscated_dirs;
    }

    DIR: for my $dir (keys %$dirs_href) {
        unless (chdir($dir)) {
            print "[-] Could not chdir $dir, skipping.\n" unless $quiet;
            next DIR;
        }

        if ($encrypt_mode) {
            next DIR unless -e $obfuscate_map_filename;
            ### encrypt the map file now that we have encrypted
            ### the directory
            print "[+] Encrypting mapping file:  ",
                "$dir/$obfuscate_map_filename\n" unless $quiet;
            unless ($trial_run) {
                &encrypt_file($obfuscate_map_filename,
                    "$obfuscate_map_filename.gpg", $NO_DEL_SOURCE_FILE);

                unlink $obfuscate_map_filename;
            }
        } else {
            next DIR unless -e "$obfuscate_map_filename.gpg";
            ### delete the map file since we have decrypted
            ### the directory
            print "[+] Decrypting mapping file:  ",
                "$dir/$obfuscate_map_filename.gpg\n" unless $quiet;
            unless ($trial_run) {
                &decrypt_file("$obfuscate_map_filename.gpg",
                    $obfuscate_map_filename, $NO_DEL_SOURCE_FILE);

                unlink "$obfuscate_map_filename.gpg";
            }
        }
    }
    return;
}

sub handle_old_obfuscated_map_file() {
    return unless -e "$obfuscate_map_filename.gpg";

    &decrypt_file("$obfuscate_map_filename.gpg",
            $obfuscate_map_filename, $NO_DEL_SOURCE_FILE);

    unlink "$obfuscate_map_filename.gpg";

    my @existing_obfuscated_files = ();

    open F, "< $obfuscate_map_filename" or die "[*] Could not open ",
        "$obfuscate_map_filename: $!";
    while (<F>) {
        if (/^\s*.*\s+(gpgdir_\d+_\d+.gpg)/) {
            if (-e $1) {
                push @existing_obfuscated_files, $_;
            }
        }
    }
    close F;

    if (@existing_obfuscated_files) {
        ### there are some obfuscated files from a previous gpgdir
        ### execution
        open G, "> $obfuscate_map_filename" or die "[*] Could not open ",
            "$obfuscate_map_filename: $!";
        print G for @existing_obfuscated_files;
        close G;
    }
    return;
}

sub append_obfuscated_mapping() {
    my ($filename, $encrypt_filename) = @_;

    open G, ">> $obfuscate_map_filename" or die "[*] Could not open ",
        "$obfuscate_map_filename: $!";
    print G "$filename $encrypt_filename\n";
    close G;
    return;
}

sub import_obfuscated_file_map() {
    my $dir = shift;

    $obfuscated_dirs{$dir} = {};

    return unless -e "$obfuscate_map_filename.gpg";

    &decrypt_file("$obfuscate_map_filename.gpg",
            $obfuscate_map_filename, $NO_DEL_SOURCE_FILE);

    open G, "< $obfuscate_map_filename" or die "[*] Could not open ",
        "$obfuscate_map_filename: $!";
    while (<G>) {
        if (/^\s*(.*)\s+(gpgdir_\d+_\d+.gpg)/) {
            $obfuscated_dirs{$dir}{$2} = $1;
        }
    }
    close G;

    return;
}

sub get_homedir() {
    my $uid = $<;
    my $homedir = '';
    if (-e '/etc/passwd') {
        open P, '< /etc/passwd' or
            die "[*] Could not open /etc/passwd. Exiting.\n";
        my @lines = <P>;
        close P;
        for my $line (@lines) {
            ### mbr:x:222:222:Michael Rash:/home/mbr:/bin/bash
            chomp $line;
            if ($line =~ /^(?:.*:){2}$uid:(?:.*:){2}(\S+):/) {
                $homedir = $1;
                last;
            }
        }
    } else {
        $homedir = $ENV{'HOME'} if defined $ENV{'HOME'};
    }
    die "[*] Could not determine home directory. Use the -u <homedir> option."
        unless $homedir;
    return $homedir;
}

sub get_key() {
    if (-e "${homedir}/.gpgdirrc") {
        open F, "< ${homedir}/.gpgdirrc" or die "[*] Could not open ",
            "${homedir}/.gpgdirrc.  Exiting.\n";
        my @lines = <F>;
        close F;
        my $key = '';
        for my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*default_key/) {
                ### prefer to use the default GnuPG key
                $use_default_key = 1;
                return '';
            } elsif ($line =~ /^\s*use_key\s+(.*)$/) {
                ### GnuPG accepts strings to match the key, so we don't
                ### have to strictly require a key ID... just a string
                ### that matches the key
                return $1;
            }
        }
        die
"[*] Please edit ${homedir}/.gpgdirrc to include your gpg key identifier\n",
"    (e.g. \"D4696445\"; see the output of \"gpg --list-keys\"), or use the\n",
"    default GnuPG key defined in ~/.gnupg/options";
    }
    print "[+] Creating gpgdir rc file: $homedir/.gpgdirrc\n";
    open F, "> ${homedir}/.gpgdirrc" or die "[*] Could not open " .
        "${homedir}/.gpgdirrc.  Exiting.\n";

    print F <<_CONFIGRC_;
# Config file for gpgdir.
#
# Set the key to use to encrypt files with "use_key <key>", e.g.
# "use_key D4696445".  See "gpg --list-keys" for a list of keys on your
# GnuPG key ring.  Alternatively, if you want gpgdir to always use the
# default key that is defined by the "default-key" variable in
# ~/.gnupg/options, then uncomment the "default_key" line below.

# Uncomment to use the GnuPG default key defined in ~/.gnupg/options:
#default_key

# If you want to use a specific GnuPG key, Uncomment the next line and
# replace "KEYID" with your real key id:
#use_key KEYID
_CONFIGRC_

    close F;
    print
"[*] Please edit $homedir/.gpgdirrc to include your gpg key identifier,\n",
"    or use the default GnuPG key defined in ~/.gnupg/options.  Exiting.\n";
    exit 0;
}

sub find_files() {
    my $file = $File::Find::name;
    &check_file_criteria($file);
    return;
}

sub check_file_criteria() {
    my $file = shift;
    ### skip all links, zero size files, all hidden
    ### files (includes .gnupg files), etc.
    return if -d $file;
    if (-e $file and not -l $file and -s $file != 0
            and $file !~ m|/\.|) {
        if ($encrypt_mode) {
            if ($file =~ m|\.gpg| or $file =~ m|\.asc|) {
                print "[-] Skipping encrypted file: $file\n" unless $quiet;
                return;
            }
        } else {
            unless ($file =~ m|\.gpg| or $file =~ m|\.asc|) {
                print "[-] Skipping unencrypted file: $file\n" unless $quiet;
                return;
            }
        }
        my ($atime, $mtime) = (stat($file))[8,9];
        $files{$file}{'atime'} = $atime;
        $files{$file}{'mtime'} = $mtime;
    } else {
        print "[-] Skipping file: $file\n"
            if $verbose and not $quiet;
    }
    return;
}

sub get_password() {

    ### this is only useful if the gpg key literally has no password
    ### (usually this is not the case, but gpgdir will support it if
    ### so).
    return if $cmdline_no_password;

    ### if we are using gpg-agent for passwords, then return
    return if $use_gpg_agent;

    if ($pw_file) {
        open PW, "< $pw_file" or die "[*] Could not open $pw_file: $!";
        $pw = <PW>;
        close PW;
        chomp $pw;
    } else {
        print "[+] Executing: gpgdir @args_cp\n" unless $quiet;
        if ($symmetric_mode) {
            print "    [Symmetric mode]\n" unless $quiet;
        } else {
            if ($use_default_key) {
                print "    Using default GnuPG key.\n" unless $quiet;
            } else {
                print "    Using GnuPG key: $encrypt_user\n" unless $quiet;
            }
        }
        if ($test_and_exit) {
            print "    *** test_mode() ***\n" unless $quiet;
        }
        if ($encrypt_mode) {
            print '    Enter password (for initial ' .
                "encrypt/decrypt test)\n" unless $quiet;
        }
        my $msg = 'Password: ';
        ### get the password without echoing the chars back to the screen
        ReadMode 'noecho';
        while (! $pw) {
            print $msg;
            $pw = ReadLine 0;
            chomp $pw;
        }
        ReadMode 'normal';
        if ($quiet) {
            print "\n";
        } else {
            print "\n\n";
        }
    }
    return;
}

sub test_mode() {
    chdir $dir or die "[*] Could not chdir($dir): $!";

    my $test_file = "gpgdir_test.$$";
    print "[+] test_mode(): Encrypt/Decrypt test of $test_file\n"
        if (($test_and_exit or $verbose) and not $quiet);

    if (-e $test_file) {
        &delete_file($test_file) or
            die "[*] test_mode(): Could not remove $test_file: $!";
    }
    if (-e "$test_file.gpg") {
        &delete_file("$test_file.gpg") or
            die "[*] test_mode(): Could not remove $test_file.gpg: $!";
    }

    open G, "> $test_file" or
        die "[*] test_mode(): Could not create $test_file: $!";
    print G "gpgdir test\n";
    close G;

    if (-e $test_file) {
        print "[+] test_mode(): Created $test_file\n"
            if (($test_and_exit or $verbose) and not $quiet);
    } else {
        die "[*] test_mode(): Could not create $test_file\n";
    }

    &encrypt_file($test_file, "${test_file}.gpg", $DEL_SOURCE_FILE);

    if (-e "$test_file.gpg" and (-s $test_file != 0)) {
        print "[+] test_mode(): Successful encrypt of $test_file\n"
            if (($test_and_exit or $verbose) and not $quiet);
        &delete_file($test_file) if -e $test_file;
    } else {
        die "[*] test_mode(): not encrypt $test_file (try adding -v).\n";
    }

    &decrypt_file("${test_file}.gpg", $test_file, $DEL_SOURCE_FILE);

    if (-e $test_file and (-s $test_file != 0)) {
        print "[+] test_mode(): Successful decrypt of $test_file\n"
            if (($test_and_exit or $verbose) and not $quiet);
    } else {
        die "[*] test_mode(): Could not decrypt $test_file.gpg ",
            "(try adding -v).\n";
    }
    open F, "< $test_file" or
        die "[*] test_mode(): Could not open $test_file: $!";
    my $line = <F>;
    close F;

    if (defined $line and $line =~ /\S/) {
        chomp $line;
        if ($line eq 'gpgdir test') {
            print "[+] test_mode(): Decrypted content matches original.\n",
                "[+] test_mode(): Success!\n\n"
                if (($test_and_exit or $verbose) and not $quiet);
        } else {
            die "[*] test_mode(): Decrypted content does not match ",
                "original (try adding -v).";
        }
    } else {
        die "[*] test_mode(): Fail (try adding -v).\n";
    }
    &delete_file($test_file) if -e $test_file;
    &delete_file("$test_file.gpg") if -e "$test_file.gpg";

    chdir $initial_dir or die "[*] Could not chdir($initial_dir)";

    return 1;
}

sub query_yes_no() {
    my ($msg, $style) = @_;
    my $ans = '';
    while ($ans ne 'y' and $ans ne 'n') {
        print $msg;
        $ans = lc(<STDIN>);
        if ($style == $ACCEPT_YES_DEFAULT) {
            return 1 if $ans eq "\n";
        } elsif ($style == $ACCEPT_NO_DEFAULT) {
            return 0 if $ans eq "\n";
        }
        chomp $ans;
    }
    return 1 if $ans eq 'y';
    return 0;
}

sub usage_and_exit() {
    print <<_HELP_;

gpgdir; Recursive direction encryption and decryption with GnuPG

[+] Version: $version (file revision: $rev_num)
    By Michael Rash (mbr\@cipherdyne.org)
    URL: http://www.cipherdyne.org/gpgdir/

Usage: gpgdir -e|-d <directory> [options]

Options:
    -e, --encrypt <directory>   - Encrypt <directory> and all of its
                                  subdirectories.
    -d, --decrypt <directory>   - Decrypt <directory> and all of its
                                  subdirectories.
    -a, --agent                 - Acquire password information from a
                                  running instance of gpg-agent.
    -A, --Agent-info <info>     - Specify the value for the GPG_AGENT_INFO
                                  environment variable as returned by
                                  'gpg-agent --daemon'.
    -g, --gnupg-dir <dir>       - Specify a path to a .gnupg directory for
                                  gpg keys (the default is ~/.gnupg if this
                                  option is not used).
    -p, --pw-file <file>        - Read password in from <file>.
    -s, --skip-test             - Skip encrypt -> decrypt test.
    -t, --test-mode             - Run encrypt -> decrypt test and exit.
    -T, --Trial-run             - Show what filesystem actions would take
                                  place without actually doing them.
    -P, --Plain-ascii           - Ascii armor mode (creates non-binary
                                  encrypted files).
    --Interactive               - Query the user before encrypting,
                                  decrypting, or deleting any files.
    --Exclude <pattern>         - Skip all filenames that match <pattern>.
    --Exclude-from <file>       - Skip all filenames that match any pattern
                                  contained within <file>.
    --Include <pattern>         - Include only those filenames that match
                                  <pattern>.
    --Include-from <file>       - Include only those filenames that match a
                                  pattern contained within <file>.
    -K, --Key-id <id>           - Specify GnuPG key ID, or key-matching
                                  string. This overrides the use_key value
                                  in ~/.gpgdirrc
    -D, --Default-key           - Use the key that GnuPG defines as the
                                  default (i.e. the key that is specified
                                  by the default-key option in
                                  ~/.gnupg/options).
    -O, --Obfuscate-filenames   - Substitute all real filenames in a
                                  directory with manufactured ones (the
                                  original filenames are preserved in a
                                  mapping file and restored when the
                                  directory is decrypted).
    --obfuscate-map_file <file> - Specify path to obfuscated mapping file
                                  (in -O mode).
    -F, --Force                 - Continue to run even if files cannot be
                                  deleted (because of permissions problems
                                  for example).
    --overwrite-encrypted       - Overwrite encrypted files even if a
                                  previous <file>.gpg file already exists.
    --overwrite-decrypted       - Overwrite decrypted files even if the
                                  previous unencrypted file already exists.
    -q, --quiet                 - Print as little to the screen as possible
    -W, --Wipe                  - Use the 'wipe' command to securely delete
                                  unencrypted copies of files after they
                                  have been encrypted.
    --wipe-path <path>          - Specify path to the wipe command.
    --wipe-interactive          - Force interactive mode with the wipe
                                  command.
    --wipe-cmdline <args>       - Manually specify command line arguments
                                  to the wipe command.
    --no-recurse                - Don't recursively encrypt/decrypt
                                  subdirectories.
    --no-delete                 - Don't delete original unencrypted files.
    --no-preserve-times         - Don't preserve original mtime and atime
                                  values on encrypted/decrypted files.
    --no-password               - Assume the gpg key has no password at all
                                  (this is not common).
    -u, --user-homedir <dir>    - Path to home directory.
    -v, --verbose               - Run in verbose mode.
    -V, --Version               - print version.
    -h, --help                  - print help.
_HELP_
    exit 0;
}
