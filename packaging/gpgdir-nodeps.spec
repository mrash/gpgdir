%define name gpgdir
%define version 1.9.6
%define release 1
%define gpgdirlibdir %_libdir/%name

Summary: Gpgdir recursively encrypts/decrypts directories with GnuPG.
Name: %name
Version: %version
Release: %release
License: GPL
Group: Applications/Cryptography
Url: http://www.cipherdyne.org/gpgdir/
Source: %name-%version.tar.gz
BuildRoot: %_tmppath/%{name}-buildroot
#Prereq: rpm-helper

%description
gpgdir is a perl script that uses the CPAN GnuPG::Interface perl module to encrypt
and decrypt directories using a gpg key specified in ~/.gpgdirrc. gpgdir recursively
descends through a directory in order to make sure it encrypts or decrypts every file
in a directory and all of its subdirectories. By default the mtime and atime values
of all files will be preserved upon encryption and decryption (this can be disabled
with the --no-preserve-times option). Note that in --encrypt mode, gpgdir will
delete the original files that it successfully encrypts (unless the --no-delete
option is given). However, upon startup gpgdir first asks for a the decryption pass-
word to be sure that a dummy file can successfully be encrypted and decrypted. The
initial test can be disabled with the --skip-test option so that a directory can eas-
ily be encrypted without having to also specify a password (this is consistent with
gpg behavior). Also, note that gpgdir is careful not encrypt hidden files and direc-
tories. After all, you probably don't want your ~/.gnupg directory or ~/.bashrc file
to be encrypted.

%prep
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%setup -q

%build

%install

install -m 755 gpgdir $RPM_BUILD_ROOT%_bindir/
install -m 644 gpgdir.1 $RPM_BUILD_ROOT%{_mandir}/man1/

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%pre

%post

%preun

%files
%defattr(-,root,root)
%_bindir/*
%{_mandir}/man1/*
%_libdir/%name

%changelog
* Mon Jan 05 2015 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9.6 release

* Sat Sep 05 2009 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9.5 release

* Thu Feb 12 2009 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9.4 release

* Wed Nov 11 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9.3 release

* Sun Aug 31 2008 Michael Rash <mbr@cipherdyne.org>
- This spec file omits installing any perl module dependencies.
- gpgdir-1.9.2 release

* Sat Jun 07 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9.1 release

* Sat May 31 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.9 release

* Mon Feb 18 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.8 release

* Mon Feb 18 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.7 release

* Sun Feb 17 2008 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.6 release

* Fri Aug 31 2007 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.5 release

* Sat Jul 20 2007 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.4 release

* Sat Jun 09 2007 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.3 release

* Mon May 28 2007 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.2 release

* Mon May 21 2007 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.1 release

* Sun Sep 17 2006 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.0.3 release (1.0.2 was skipped accidentally).

* Sat Sep 16 2006 Michael Rash <mbr@cipherdyne.org>
- Added x86_64 RPM.
- Removed iptables as a prerequisite.
- gpgdir-1.0.1 release

* Wed Sep 13 2006 Michael Rash <mbr@cipherdyne.org>
- gpgdir-1.0 release

* Thu Sep 09 2006 Michael Rash <mbr@cipherdyne.org>
- Initial RPM release of gpgdir-0.9.9
