#!/usr/bin/perl -w
#
####################################################################
#
# File: install.pl
#
# Purpose: To install gpgdir on a Linux system.
#
# Author: Michael Rash (mbr@cipherdyne.org)
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
####################################################################
#
# $Id$
#

use File::Copy;
use strict;

#======================= config =======================
my $install_dir = '/usr/bin';
my $libdir      = '/usr/lib/gpgdir';
my $manpage     = 'gpgdir.1';

### system binaries
my $gzipCmd = '/usr/bin/gzip';
my $perlCmd = '/usr/bin/perl';
my $makeCmd = '/usr/bin/make';
#===================== end config =====================

### Everthing after this point must be executed as root.
$< == 0 && $> == 0 or
    die " ** You must be root (or equivalent " .
        "UID 0 account) to install gpgdir!  Exiting.\n";

my %Cmds = (
    'gzip' => $gzipCmd,
    'perl' => $perlCmd,
    'make' => $makeCmd
);

### make sure we can find the system binaries
### in the expected locations.
&check_commands();

### create directories, make sure executables exist, etc.
&setup();

print " .. Installing gpgdir in $install_dir\n";
&install_gpgdir();

print " .. Installing GnuPG perl module in $libdir\n";
&install_gnupg_pm();

print " .. Installing Term::Readkey perl module in $libdir\n";
&install_term_readkey_pm();

print " .. Installing man page.\n";
&install_manpage();

print " .. gpgdir installed!\n";

exit 0;
#===================== end main =======================

sub install_gpgdir() {
    die " ** gpgdir does not exist.  Download gpgdir from " .
        "http://www.cipherdyne.org/gpgdir" unless -e 'gpgdir';
    copy 'gpgdir', "${install_dir}/gpgdir" or die " ** Could not copy " .
        "gpgdir to $install_dir: $!";
    chmod 0755, "${install_dir}/gpgdir" or die " ** Could not set " .
        "permissions on gpgdir to 0755";
    chown 0, 0, "${install_dir}/gpgdir" or
        die " ** Could not chown 0,0,${install_dir}/gpgdir: $!";
    return;
}

sub install_gnupg_pm() {
    ### installing GnuPG
    chdir 'GnuPG' or die " ** Could not chdir to ",
        "GnuPG: $!";
    unless (-e 'Makefile.PL' && -e 'GnuPG.pm') {
        die " ** Your source directory appears to be incomplete!  GnuPG.pm ",
            "is missing.\n    Download the latest sources from ",
            "http://www.cipherdyne.org\n";
    }
    system "$Cmds{'perl'} Makefile.PL PREFIX=$libdir LIB=$libdir";
    system $Cmds{'make'};
#    system "$Cmds{'make'} test";
    system "$Cmds{'make'} install";
    chdir '..';
    return;
}

sub install_term_readkey_pm() {
    ### installing GnuPG
    chdir 'TermReadKey' or die " ** Could not chdir to ",
        "TermReadKey: $!";
    unless (-e 'Makefile.PL' && -e 'ReadKey.pm') {
        die " ** Your source directory appears to be incomplete!  ReadKey.pm ",
            "is missing.\n    Download the latest sources from ",
            "http://www.cipherdyne.org\n";
    }
    system "$Cmds{'perl'} Makefile.PL PREFIX=$libdir LIB=$libdir";
    system $Cmds{'make'};
#    system "$Cmds{'make'} test";
    system "$Cmds{'make'} install";
    chdir '..';
    return;
}

sub install_manpage() {
    die " ** man page: $manpage does not exist.  Download gpgdir " .
        "from http://www.cipherdyne.org/gpgdir" unless -e $manpage;
    ### default location to put the gpgdir man page, but check with
    ### /etc/man.config
    my $mpath = '/usr/share/man/man1';
    if (-e '/etc/man.config') {
        ### prefer to install $manpage in /usr/local/man/man1 if
        ### this directory is configured in /etc/man.config
        open M, '< /etc/man.config' or
            die " ** Could not open /etc/man.config: $!";
        my @lines = <M>;
        close M;
        ### prefer the path "/usr/share/man"
        my $found = 0;
        for my $line (@lines) {
            chomp $line;
            if ($line =~ m|^MANPATH\s+/usr/share/man|) {
                $found = 1;
                last;
            }
        }
        ### try to find "/usr/local/man" if we didn't find /usr/share/man
        unless ($found) {
            for my $line (@lines) {
                chomp $line;
                if ($line =~ m|^MANPATH\s+/usr/local/man|) {
                    $mpath = '/usr/local/man/man1';
                    $found = 1;
                    last;
                }
            }
        }
        ### if we still have not found one of the above man paths,
        ### just select the first one out of /etc/man.config
        unless ($found) {
            for my $line (@lines) {
                chomp $line;
                if ($line =~ m|^MANPATH\s+(\S+)|) {
                    $mpath = $1;
                    last;
                }
            }
        }
    }
    mkdir $mpath, 0755 unless -d $mpath;
    my $mfile = "${mpath}/${manpage}";
    print " .. Installing $manpage man page as: $mfile\n";
    copy $manpage, $mfile or die " ** Could not copy $manpage to " .
        "$mfile: $!";
    chmod 0644, $mfile or die " ** Could not set permissions on ".
        "$mfile to 0644";
    chown 0, 0, $mfile or
        die " ** Could not chown 0,0,$mfile: $!";
    print " .. Compressing man page: $mfile\n";
    ### remove the old one so gzip doesn't prompt us
    unlink "${mfile}.gz" if -e "${mfile}.gz";
    system "$Cmds{'gzip'} $mfile";
    return;
}

### check paths to commands and attempt to correct if any are wrong.
sub check_commands() {
    my @path = qw(
        /bin
        /sbin
        /usr/bin
        /usr/sbin
        /usr/local/bin
        /usr/local/sbin
    );
    CMD: for my $cmd (keys %Cmds) {
        unless (-x $Cmds{$cmd}) {
            my $found = 0;
            PATH: for my $dir (@path) {
                if (-x "${dir}/${cmd}") {
                    $Cmds{$cmd} = "${dir}/${cmd}";
                    $found = 1;
                    last PATH;
                }
            }
            unless ($found) {
                die "\n ** Could not find $cmd anywhere!!!  ",
                    "Please edit the config section to include the path to ",
                    "$cmd.\n";
            }
        }
        unless (-x $Cmds{$cmd}) {
            die "\n ** $cmd is located at ",
                "$Cmds{$cmd} but is not executable by uid: $<\n";
        }
    }
    return;
}

sub setup() {
    unless (-d $libdir) {
        mkdir $libdir, 0755 or die " ** Could not create $libdir: $!"
    }
    return;
}
