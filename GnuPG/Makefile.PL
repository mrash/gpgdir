use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'GnuPG',
    'VERSION_FROM' => 'GnuPG.pm', # finds $VERSION
    'EXE_FILES'	=> [ gpgmailtunl ],
);
