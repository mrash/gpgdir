Summary: Perl interface to the Gnu Privacy Guard
Name: GnuPG
Version: 0.09
Release: 1c
Source: http://www.cpan.org/modules/by-module/GnuPG/%{name}-%{version}.tar.gz
Copyright: GPL
Group: Development/Languages
Prefix: /usr
URL: http://www.cpan.org/modules/by-module/GnuPG/%{name}-%{version}.readme
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArchitectures: noarch
Requires: gnupg >= 1.0

%description
GnuPG is a perl interface to the GNU Privacy Guard. It uses the shared
memory coprocess interface that gpg provides for its wrappers. It
tries its best to map the interactive interface of gpg to a more
programmatic model.

%prep
%setup -q
%fix_perl_path

%build
perl Makefile.PL 
make OPTIMIZE="$RPM_OPT_FLAGS"
make test

%install
rm -fr $RPM_BUILD_ROOT
%perl_make_install

BuildDirList > %pkg_file_list
BuildFileList >> %pkg_file_list

%clean
rm -fr $RPM_BUILD_ROOT

%files -f %pkg_file_list
%defattr(-,root,root)
%doc README ChangeLog NEWS

%changelog
* Fri Jun 08 2001  Francis J. Lacoste <francis.lacoste@Contre.COM> 
  [0.09-1c]
- Updated to version 0.09.

* Mon May 21 2001  Francis J. Lacoste <francis.lacoste@Contre.COM> 
  [0.08-1c]
- Updated to version 0.08.

* Tue Aug 15 2000  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.07-1i]
- Updated to version 0.07.

* Mon Aug 07 2000  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.06-1i]
- Updated for version 0.06.

* Fri Jul 14 2000  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.05-2i]
- Updated spec file to use new macros.

* Wed Jun 21 2000  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.05-1i]
- Updated to version 0.05.

* Mon Dec 06 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.04-1i]
- Updated to version 0.04.

* Tue Nov 30 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.03-1i]
- Updated to version 0.03.

* Wed Sep 08 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.02-1i]
- Added gpgmailtunl and its man pages.
- Updated to version 0.02.

* Sun Sep 05 1999 Francis J. Lacoste <francis.lacoste@iNsu.COM>
  [0.01-1i]
- Packaged for iNs/linux


