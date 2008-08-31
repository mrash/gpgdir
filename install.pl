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
# Copyright (C) 2002-2008 Michael Rash (mbr@cipherdyne.org)
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

use Cwd;
use File::Copy;
use Getopt::Long;
use strict;

#======================= config =======================
my $install_dir = '/usr/bin';
my $libdir      = '/usr/lib/gpgdir';
my $manpage     = 'gpgdir.1';

### only used it $ENV{'HOME'} is not set for some reason
my $config_homedir = '';

### system binaries
my $gzipCmd = '/usr/bin/gzip';
my $perlCmd = '/usr/bin/perl';
my $makeCmd = '/usr/bin/make';
#===================== end config =====================

my $print_help = 0;
my $uninstall  = 0;
my $force_mod_re  = '';
my $exclude_mod_re  = '';
my $skip_module_install   = 0;
my $cmdline_force_install = 0;
my $locale = 'C';  ### default LC_ALL env variable
my $no_locale = 0;
my $deps_dir  = 'deps';

my %cmds = (
    'gzip' => $gzipCmd,
    'perl' => $perlCmd,
    'make' => $makeCmd
);

### map perl modules to versions
my %required_perl_modules = (
    'Class::MethodMaker' => {
        'force-install' => 0,
        'mod-dir' => 'Class-MethodMaker'
    },
    'GnuPG::Interface' => {
        'force-install' => 0,
        'mod-dir' => 'GnuPG-Interface'
    },
    'Term::ReadKey' => {
        'force-install' => 0,
        'mod-dir' => 'TermReadKey'
    }
);

### make Getopts case sensitive
Getopt::Long::Configure('no_ignore_case');

&usage(1) unless (GetOptions(
    'force-mod-install' => \$cmdline_force_install,  ### force install of all modules
    'Force-mod-regex=s' => \$force_mod_re,  ### force specific mod install with regex
    'Exclude-mod-regex=s' => \$exclude_mod_re, ### exclude a particular perl module
    'Skip-mod-install'  => \$skip_module_install,
    'home-dir=s'        => \$config_homedir, ### force a specific home dir
    'LC_ALL=s'          => \$locale,
    'locale=s'          => \$locale,
    'no-LC_ALL'         => \$no_locale,
    'no-locale'         => \$no_locale,  ### synonym
    'uninstall' => \$uninstall,      # Uninstall gpgdir.
    'help'      => \$print_help      # Display help.
));
&usage(0) if $print_help;

### set LC_ALL env variable
$ENV{'LC_ALL'} = $locale unless $no_locale;

$force_mod_re = qr|$force_mod_re| if $force_mod_re;
$exclude_mod_re = qr|$exclude_mod_re| if $exclude_mod_re;

### check to see if we are installing in a Cygwin environment
my $non_root_user = 0;
if (&is_cygwin()) {

    print
"[+] It looks like you are installing gpgdir in a Cygwin environment.\n";
    $non_root_user = 1;

} else {

    unless ($< == 0 && $> == 0) {
        print
"[+] It looks like you are installing gpgdir as a non-root user, so gpgdir\n",
"    will be installed in your local home directory.\n\n";

        $non_root_user = 1;
    }
}

if ($non_root_user) {

    ### we are installing as a normal user instead of root, so see
    ### if it is ok to install within the user's home directory
    my $homedir = '';
    if ($config_homedir) {
        $homedir = $config_homedir;
    } else {
        $homedir = $ENV{'HOME'} or die '[*] Could not get home ',
            "directory, set the $config_homedir var.";
    }

    print
"    gpgdir will be installed at $homedir/bin/gpgdir, and a few\n",
"    perl modules needed by gpgdir will be installed in $homedir/lib/gpgdir/.\n\n",

    mkdir "$homedir/lib" unless -d "$homedir/lib";
    $libdir = "$homedir/lib/gpgdir";
    $install_dir = "$homedir/bin";
}

### make sure we can find the system binaries
### in the expected locations.
&check_commands();

my $src_dir = getcwd() or die "[*] Could not get current working directory.";

### create directories, make sure executables exist, etc.
&setup();

print "[+] Installing gpgdir in $install_dir\n";
&install_gpgdir();

### install perl modules
unless ($skip_module_install) {
    for my $module (keys %required_perl_modules) {
        &install_perl_module($module);
    }
}
chdir $src_dir or die "[*] Could not chdir $src_dir: $!";

print "[+] Installing man page.\n";
&install_manpage();

print "\n    It is highly recommended to run the test suite in the test/\n",
    "    directory to ensure proper gpgdir operation.\n",
    "\n[+] gpgdir has been installed!\n";

exit 0;
#===================== end main =======================

sub install_gpgdir() {
    die "[*] gpgdir does not exist.  Download gpgdir from " .
        "http://www.cipherdyne.org/gpgdir" unless -e 'gpgdir';
    copy 'gpgdir', "${install_dir}/gpgdir" or die "[*] Could not copy " .
        "gpgdir to $install_dir: $!";

    if ($non_root_user) {
        open F, "< ${install_dir}/gpgdir" or die "[*] Could not open ",
            "${install_dir}/gpgdir: $!";
        my @lines = <F>;
        close F;
        open P, "> ${install_dir}/gpgdir.tmp" or die "[*] Could not open ",
            "${install_dir}/gpgdir.tmp: $!";
        for my $line (@lines) {
            ### change the lib dir to new homedir path
            if ($line =~ m|^\s*use\s+lib\s+\'/usr/lib/gpgdir\';|) {
                print P "use lib '", $libdir, "';\n";
            } else {
                print P $line;
            }
        }
        close P;
        move "${install_dir}/gpgdir.tmp", "${install_dir}/gpgdir" or
            die "[*] Could not move ${install_dir}/gpgdir.tmp -> ",
                "${install_dir}/gpgdir: $!";

        chmod 0700, "${install_dir}/gpgdir" or die "[*] Could not set " .
            "permissions on gpgdir to 0755";
    } else {
        chmod 0755, "${install_dir}/gpgdir" or die "[*] Could not set " .
            "permissions on gpgdir to 0755";
        chown 0, 0, "${install_dir}/gpgdir" or
            die "[*] Could not chown 0,0,${install_dir}/gpgdir: $!";
    }
    return;
}

sub install_perl_module() {
    my $mod_name = shift;

    chdir $src_dir or die "[*] Could not chdir $src_dir: $!";
    chdir $deps_dir or die "[*] Could not chdir($deps_dir): $!";

    die '[*] Missing force-install key in required_perl_modules hash.'
        unless defined $required_perl_modules{$mod_name}{'force-install'};
    die '[*] Missing mod-dir key in required_perl_modules hash.'
        unless defined $required_perl_modules{$mod_name}{'mod-dir'};

    if ($exclude_mod_re and $exclude_mod_re =~ /$mod_name/) {
        print "[+] Excluding installation of $mod_name module.\n";
        return;
    }

    my $version = '(NA)';

    my $mod_dir = $required_perl_modules{$mod_name}{'mod-dir'};

    if (-e "$mod_dir/VERSION") {
        open F, "< $mod_dir/VERSION" or
            die "[*] Could not open $mod_dir/VERSION: $!";
        $version = <F>;
        close F;
        chomp $version;
    } else {
        print "[-] Warning: VERSION file does not exist in $mod_dir\n";
    }

    my $install_module = 0;

    if ($required_perl_modules{$mod_name}{'force-install'}
            or $cmdline_force_install) {
        ### install regardless of whether the module may already be
        ### installed
        $install_module = 1;
    } elsif ($force_mod_re and $force_mod_re =~ /$mod_name/) {
        print "[+] Forcing installation of $mod_name module.\n";
        $install_module = 1;
    } else {
        if (has_perl_module($mod_name)) {
            print "[+] Module $mod_name is already installed in the ",
                "system perl tree, skipping.\n";
        } else {
            ### install the module in the /usr/lib/gpgdir directory because
            ### it is not already installed.
            $install_module = 1;
        }
    }

    if ($install_module) {
        unless (-d $libdir) {
            print "[+] Creating $libdir\n";
            mkdir $libdir, 0755 or die "[*] Could not mkdir $libdir: $!";
        }
        print "[+] Installing the $mod_name $version perl " .
            "module in $libdir/\n";
        my $mod_dir = $required_perl_modules{$mod_name}{'mod-dir'};
        chdir $mod_dir or die "[*] Could not chdir to ",
            "$mod_dir: $!";
        unless (-e 'Makefile.PL') {
            die "[*] Your $mod_name source directory appears to be incomplete!\n",
                "    Download the latest sources from ",
                "http://www.cipherdyne.org/\n";
        }
        system "$cmds{'make'} clean" if -e 'Makefile';
        system "$cmds{'perl'} Makefile.PL PREFIX=$libdir LIB=$libdir";
        system $cmds{'make'};
#        system "$cmds{'make'} test";
        system "$cmds{'make'} install";
        chdir $src_dir or die "[*] Could not chdir $src_dir: $!";

        print "\n\n";
    }
    chdir $src_dir or die "[*] Could not chdir $src_dir: $!";
    return;
}

sub has_perl_module() {
    my $module = shift;

    # 5.8.0 has a bug with require Foo::Bar alone in an eval, so an
    # extra statement is a workaround.
    my $file = "$module.pm";
    $file =~ s{::}{/}g;
    eval { require $file };

    return $@ ? 0 : 1;
}

sub install_manpage() {

    if ($non_root_user) {
        print
"[+] Because this is a non-root install, the man page will not be installed\n",
"    but you can download it here:  http://www.cipherdyne.org/gpgdir\n\n";
        return;
    }

    die "[*] man page: $manpage does not exist.  Download gpgdir " .
        "from http://www.cipherdyne.org/gpgdir" unless -e $manpage;
    ### default location to put the gpgdir man page, but check with
    ### /etc/man.config
    my $mpath = '/usr/share/man/man1';
    if (-e '/etc/man.config') {
        ### prefer to install $manpage in /usr/local/man/man1 if
        ### this directory is configured in /etc/man.config
        open M, '< /etc/man.config' or
            die "[*] Could not open /etc/man.config: $!";
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
    print "[+] Installing $manpage man page as: $mfile\n";
    copy $manpage, $mfile or die "[*] Could not copy $manpage to " .
        "$mfile: $!";
    chmod 0644, $mfile or die "[*] Could not set permissions on ".
        "$mfile to 0644";
    chown 0, 0, $mfile or
        die "[*] Could not chown 0,0,$mfile: $!";
    print "[+] Compressing man page: $mfile\n";
    ### remove the old one so gzip doesn't prompt us
    unlink "${mfile}.gz" if -e "${mfile}.gz";
    system "$cmds{'gzip'} $mfile";
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
    CMD: for my $cmd (keys %cmds) {
        unless (-x $cmds{$cmd}) {
            my $found = 0;
            PATH: for my $dir (@path) {
                if (-x "${dir}/${cmd}") {
                    $cmds{$cmd} = "${dir}/${cmd}";
                    $found = 1;
                    last PATH;
                }
            }
            unless ($found) {
                die "[*] Could not find $cmd anywhere!!!  ",
                    "Please edit the config section to include the path to ",
                    "$cmd.\n";
            }
        }
        unless (-x $cmds{$cmd}) {
            die "[*] $cmd is located at ",
                "$cmds{$cmd} but is not executable by uid: $<\n";
        }
    }
    return;
}

sub is_cygwin() {

    my $rv = 0;

    ### get OS output from uname
    open UNAME, "uname -o |" or return $rv;
    while (<UNAME>) {
        $rv = 1 if /Cygwin/;
    }
    close UNAME;

    return $rv;
}


sub setup() {
    unless (-d $libdir) {
        mkdir $libdir, 0755 or die "[*] Could not create $libdir: $!"
    }
    return;
}

sub usage() {
    my $exit_status = shift;
    print <<_HELP_;

Usage: install.pl [options]

    -u,  --uninstall             - Uninstall gpgdir.
    -f, --force-mod-install      - Force all perl modules to be installed
                                   even if some already exist in the system
                                   /usr/lib/perl5 tree.
    -F, --Force-mod-regex <re>   - Specify a regex to match a module name
                                   and force the installation of such modules.
    -E, --Exclude-mod-regex <re> - Exclude a perl module that matches this
                                   regular expression.
    -S, --Skip-mod-install       - Do not install any perl modules.

    -L, --LANG <locale>          - Specify LANG env variable (actually the
                                   LC_ALL variable).
    -h  --help                   - Prints this help message.

_HELP_
    exit $exit_status;
}
