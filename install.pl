#!/usr/bin/perl -w
#
####################################################################
#
# File: install.pl
#
# Purpose: To install gpgdir on a Linux system.
#
# Author: Michael Rash (mbr@cipherdyne.com)
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
my $manpage = 'gpgdir.1';

### system binaries
my $gzipCmd = '/usr/bin/gzip';
my $perlCmd = '/usr/bin/perl';
#===================== end config =====================

die " ** gzip command is not located at: $gzipCmd" unless -e $gzipCmd;
die " ** $gzipCmd is not executable." unless -x $gzipCmd;

unless (((system "$perlCmd -e 'use GnuPG' 2> /dev/null") >> 8) == 0) {
    die " ** It does not appear that you have the GnuPG installed.\n" .
        "    Download from http://www.cpan.org and install it.\n";
}
### Everthing after this point must be executed as root.
$< == 0 && $> == 0 or
    die " ** You must be root (or equivalent " .
        "UID 0 account) to install gpgdir!  Exiting.\n";

print localtime() . " .. Installing gpgdir in $install_dir\n";
&install_gpgdir();
print localtime() . " .. Installing man page.\n";
&install_manpage();
print localtime() . " .. gpgdir installed!\n";

exit 0;

sub install_gpgdir() {
    die " ** gpgdir does not exist.  Download gpgdir from " .
        "http://www.cipherdyne.com/gpgdir" unless -e 'gpgdir';
    copy 'gpgdir', "${install_dir}/gpgdir" or die " ** Could not copy " .
        "gpgdir to $install_dir: $!";
    chmod 0755, "${install_dir}/gpgdir" or die " ** Could not set " .
        "permissions on gpgdir to 0755";
    chown 0, 0, "${install_dir}/gpgdir" or
        die " ** Could not chown 0,0,${install_dir}/gpgdir: $!";
    return;
}

sub install_manpage() {
    die " ** man page: $manpage does not exist.  Download gpgdir " .
        "from http://www.cipherdyne.com/gpgdir" unless -e $manpage;
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
    print localtime() . " .. Installing $manpage man page as: $mfile\n";
    copy $manpage, $mfile or die " ** Could not copy $manpage to " .
        "$mfile: $!";
    chmod 0644, $mfile or die " ** Could not set permissions on ".
        "$mfile to 0644";
    chown 0, 0, $mfile or
        die " ** Could not chown 0,0,$mfile: $!";
    print localtime() . " .. Compressing man page: $mfile\n";
    ### remove the old one so gzip doesn't prompt us
    unlink "${mfile}.gz" if -e "${mfile}.gz";
    system "$gzipCmd $mfile";
    return;
}
