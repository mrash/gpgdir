# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#use Test;

use strict;

use constant USERID	=> "GnuPG Test";
use constant PASSWD	=> "test";
use constant UNTRUSTED	=> "Francis";

use Symbol;

BEGIN {
    $| = 1;
}

use GnuPG;
use GnuPG::Tie::Encrypt;
use GnuPG::Tie::Decrypt;

my $gpg = new GnuPG( homedir => "test", trace => $ENV{TRACING} );

sub gen_key_test {
    printf "%-40s", "Key generation";
    $gpg->gen_key(
		  passphrase => PASSWD,
		  name	     => USERID,
		 );
}

sub import_test {
    printf "%-40s", "Import new public key";
    $gpg->import_keys( keys => "test/key1.pub" );
}

sub import2_test {
    printf "%-40s", "Import existing public key";
    $gpg->import_keys( keys => "test/key1.pub" );
}

sub import3_test {
    printf "%-40s", "Import many public keys";
    $gpg->import_keys( keys => [ qw( test/key1.pub test/key2.pub ) ] );
}
sub export_test {
    printf "%-40s", "Public key export";
    $gpg->export_keys( keys	=> USERID,
		       armor	=> 1,
		       output	=> "test/key.pub",
		     );
}

sub export2_test {
    printf "%-40s", "Exporting public key ring";
    $gpg->export_keys( armor	=> 1,
		       output	=> "test/keyring.pub",
		     );
}

sub export_secret_test {
    printf "%-40s", "Exporting secret key";
    $gpg->export_keys( secret	=> 1,
		       armor	=> 1,
		       output	=> "test/key.sec",
		     );
}

sub encrypt_test {
    printf "%-40s", "Encrypt";
    $gpg->encrypt(
		  recipient => USERID,
		  output    => "test/file.txt.gpg",
		  armor	    => 1,
		  plaintext => "test/file.txt",
		 );
}

sub pipe_encrypt_test {
    printf "%-40s", "Pipe Encrypt";
    open CAT, "| cat > test/pipe-file.txt.gpg"
      or die "can't fork: $!\n";
    $gpg->encrypt(
		  recipient => USERID,
		  output    => \*CAT,
		  armor	    => 1,
		  plaintext => "test/file.txt",
		 );
    close CAT;
}

sub encrypt_sign_test {
    printf "%-40s", "Encrypt and Sign";
    $gpg->encrypt(
		  recipient	=> USERID,
		  output	=> "test/file.txt.sgpg",
		  armor		=> 1,
		  sign		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub encrypt_sym_test {
    printf "%-40s", "Symmetric encryption";
    $gpg->encrypt(
		  output	=> "test/file.txt.cipher",
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  symmetric	=> 1,
		  passphrase	=> PASSWD,
		 );
}

sub encrypt_notrust_test {
    printf "%-40s", "Encrypt to undefined trust";
    $gpg->encrypt(
		  recipient	=> UNTRUSTED,
		  output	=> "test/file.txt.dist.gpg",
		  armor		=> 1,
		  sign		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub sign_test {
    printf "%-40s", "Sign a file";
    $gpg->sign(
		  recipient	=> USERID,
		  output	=> "test/file.txt.sig",
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub detachsign_test {
    printf "%-40s", "Detach signature of a file";
    $gpg->sign(
		  recipient	=> USERID,
		  output	=> "test/file.txt.asc",
		  "detach-sign" => 1,
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub clearsign_test {
    printf "%-40s", "Clear Sign a File";
    $gpg->clearsign(
		    output	=> "test/file.txt.clear",
		    armor	=> 1,
		    plaintext	=> "test/file.txt",
		    passphrase  => PASSWD,
		 );
}

sub decrypt_test {
    printf "%-40s", "Decrypt a file";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain",
		    ciphertext	=> "test/file.txt.gpg",
		    passphrase  => PASSWD,
		 );
}
sub pipe_decrypt_test {
    printf "%-40s", "Pipe Decrypt";
    open CAT, "cat test/file.txt.gpg|"
      or die "can't fork: $!\n";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain",
		    ciphertext	=> \*CAT,
		    passphrase  => PASSWD,
		 );
    close CAT;
}

sub decrypt_sign_test {
    printf "%-40s", "Decrypt a Signed File";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain2",
		    ciphertext	=> "test/file.txt.sgpg",
		    passphrase  => PASSWD,
		 );
}

sub decrypt_sym_test {
    printf "%-40s", "Symmetric decryption";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain3",
		    ciphertext	=> "test/file.txt.cipher",
		    symmetric	=> 1,
		    passphrase  => PASSWD,
		 );
}

sub verify_sign_test {
    printf "%-40s", "Verify a signed file";
    $gpg->verify( signature	=> "test/file.txt.sig" );
}

sub verify_detachsign_test {
    printf "%-40s", "Verify a detach signature";
    $gpg->verify( signature	=> "test/file.txt.asc",
		  file		=> "test/file.txt",
		);
}

sub verify_clearsign_test {
    printf "%-40s", "Verify a clearsigned file";
    $gpg->verify( signature => "test/file.txt.clear" );
}

sub encrypt_from_fh_test {
    printf "%-40s", "Encrypt from file handle";
    open ( FH, "test/file.txt" )
      or die "error opening file: $!\n";
    $gpg->encrypt(
		  recipient => UNTRUSTED,
		  output    => "test/file-fh.txt.gpg",
		  armor	    => 1,
		  plaintext => \*FH,
		 );
    close ( FH )
      or die "error closing file: $!\n";
}

sub encrypt_to_fh_test {
    printf "%-40s", "Encrypt to file handle";
    open ( FH, ">test/file-fho.txt.gpg" )
      or die "error opening file: $!\n";
    $gpg->encrypt(
		  recipient => UNTRUSTED,
		  output    => \*FH,
		  armor	    => 1,
		  plaintext => "test/file.txt",
		 );
    close ( FH )
      or die "error closing file: $!\n";
}

sub tie_encrypt_test {
    printf "%-40s", "Tied encrypt interface";
    open( PLAINTEXT, "test/file.txt" )
      or die "error opening file: $!\n";
    open( CIPHER_OUT, ">test/file-tie.txt.asc" )
      or die "error writing encrypting file\n";
    tie *CIPHER, 'GnuPG::Tie::Encrypt', homedir => "test",
      recipient => 'GnuPG', armor => 1, trace => $ENV{TRACING};
    while (<PLAINTEXT>) {
	print CIPHER $_;
    }
    close PLAINTEXT;

    while (<CIPHER>) {
	print CIPHER_OUT $_;
    }
    close CIPHER;
    untie *CIPHER;
    close CIPHER_OUT;
}

sub tie_decrypt_test {
    printf "%-40s", "Tied decrypt interface";
    open( PLAINTEXT, "test/file.txt" )
      or die "error opening plaintext file: $!\n";
    my $plaintext_orig = "";
    $plaintext_orig .= $_ while ( <PLAINTEXT>);
    close PLAINTEXT;

    open( CIPHER, "test/file-tie.txt.asc" )
      or die "error opening encrypted file\n";
    tie *GNUPG, 'GnuPG::Tie::Decrypt', homedir => "test",
      passphrase => PASSWD, trace => $ENV{TRACING};

    while ( <CIPHER> ) {
	print GNUPG $_;
    }
    my $plaintext = "";
    while ( <GNUPG> ) {
	$plaintext .= $_;
    }
    close GNUPG;
    untie *GNUPG;
    close CIPHER;

    die "plaintext doesn't match\n" unless $plaintext_orig eq $plaintext;
}

sub tie_decrypt_para_mode_test {
    printf "%-40s", "Tied decrypt in paragraph mode";
    my $plaintext = <<EOF;
This is a paragraph.

This is another paragraph
which continue on another line.



This is the final paragraph.
EOF
    tie *CIPHER, 'GnuPG::Tie::Encrypt', homedir => "test",
      recipient => 'GnuPG', armor => 1, trace => $ENV{TRACING};

    print CIPHER $plaintext;
    local $/ = undef;
    my $cipher = <CIPHER>;
    close CIPHER;
    untie *CIPHER;

    local $/ = "";
    tie *TEST, 'GnuPG::Tie::Decrypt', homedir => "test", passphrase => PASSWD;
    print TEST $cipher;

    my @para = <TEST>;
    close TEST;
    untie *TEST;

    my $count = @para;
    die "paragraph count should be 3: $count\n" unless $count == 3;
    die "plaintext doesn't match input\n" unless join( "", @para) eq $plaintext;
}

my @tests = qw(
                gen_key_test
    		import_test	 import2_test		import3_test
    		export_test	 export2_test		export_secret_test
    		encrypt_test	 pipe_encrypt_test	pipe_decrypt_test
		encrypt_sign_test encrypt_sym_test
    		encrypt_notrust_test
    		decrypt_test	 decrypt_sign_test	decrypt_sym_test
    		sign_test	 detachsign_test	clearsign_test
    		verify_sign_test verify_detachsign_test verify_clearsign_test
		tie_encrypt_test tie_decrypt_test tie_decrypt_para_mode_test
    	        );

if ( defined $ENV{TESTS} ) {
    @tests = split /\s+/, $ENV{TESTS};
}

print "1..", scalar @tests, "\n";
my $i = 1;
for ( @tests ) {
    eval { 
	no strict 'refs';   # We are using symbolic references
	&$_();
    };
    if ( $@ ) {
	print "not ok $i: $@";
    } else {
	print "ok $i\n";
    }
    $i++;
}



