# gpgdir - Recursive Directory Encryption with GnuPG

## Summary
gpgdir is a perl script that uses the CPAN GnuPG::Interface perl module to recursively encrypt and
decrypt directories using gpg. gpgdir recursively descends through a directory in order to encrypt,
decrypt, sign, or verify every file in a directory and all of its subdirectories. By default, the
mtime and atime values of all files will be preserved upon encryption and decryption (this can be
disabled with the --no-preserve-times option). Note that in --encrypt mode, gpgdir will delete the
original files that it successfully encrypts (unless the --no-delete option is given). However,
upon startup gpgdir first asks for a the decryption password to be sure that a dummy file can suc‐
cessfully be encrypted and decrypted. The initial test can be disabled with the --skip-test option
so that a directory can easily be encrypted without having to also specify a password (this is con‐
sistent with gpg behavior). Also, note that gpgdir is careful not encrypt hidden files and directo‐
ries. After all, you probably don't want your ~/.gnupg directory or ~/.bashrc file to be encrypted.
The GnuPG key gpgdir uses to encrypt/decrypt a directory is specified in ~/.gpgdirrc. Also, gpgdir
can use the wipe program with the --Wipe command line option to securely delete the original unen‐
crypted files after they have been successfully encrypted. This elevates the security stance of
gpgdir since it is more difficult to recover the unencrypted data associated with files from the
filesystem after they are encrypted (unlink() does not erase data blocks even though a file is
removed).

Note that gpgdir is not designed to be a replacement for an encrypted filesystem solution like encfs
or ecryptfs. Rather, it is an alternative that allows one to take advantage of the cryptographic
properties offered by GnuPG in a recursive manner across an existing filesystem.

## Installation:
Just run the install.pl script (as root) that comes with the gpgdir sources.

## License
The gpgdir project is released as open source software under the terms of
the **GNU General Public License (GPL v2)**. The latest release can be found
at [http://www.cipherdyne.org/gpgdir/](http://www.cipherdyne.org/gpgdir/)

 * Author:   Michael Rash <mbr@cipherdyne.org>
 * Download: http://www.cipherdyne.org/gpgdir
 * Version:  1.9.6
