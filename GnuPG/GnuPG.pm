#
#    GnuPG.pm - Interface to the GNU Privacy Guard.
#
#    This file is part of GnuPG.pm.
#
#    Author: Francis J. Lacoste <francis.lacoste@Contre.COM>
#
#    Copyright (C) 2000 iNsu Innovations Inc.
#    Copyright (C) 2001 Francis J. Lacoste
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package GnuPG;


use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK  %EXPORT_TAGS );

BEGIN {
    require Exporter;

    @ISA = qw(Exporter);

    @EXPORT = qw();

    %EXPORT_TAGS = (
		    algo   => [ qw(	DSA_ELGAMAL DSA ELGAMAL_ENCRYPT
					ELGAMAL
				    ) ],
		    trust  => [ qw(	TRUST_UNDEFINED	TRUST_NEVER
					TRUST_MARGINAL	TRUST_FULLY
					TRUST_ULTIMATE ) ],
		   );

    Exporter::export_ok_tags( qw( algo trust ) );

    $VERSION = '0.09';
}

use constant DSA_ELGAMAL	=> 1;
use constant DSA		=> 2;
use constant ELGAMAL_ENCRYPT	=> 3;
use constant ELGAMAL		=> 4;

use constant TRUST_UNDEFINED	=> -1;
use constant TRUST_NEVER	=> 0;
use constant TRUST_MARGINAL	=> 1;
use constant TRUST_FULLY	=> 2;
use constant TRUST_ULTIMATE	=> 3;

use Carp;
use POSIX qw();
use Symbol;
use Fcntl;

sub parse_trust {
    for (shift) {
	/ULTIMATE/  && do { return TRUST_ULTIMATE;  };
	/FULLY/	    && do { return TRUST_FULLY;	    };
	/MARGINAL/  && do { return TRUST_MARGINAL;  };
	/NEVER/	    && do { return TRUST_NEVER;	    };
	# Default
	return TRUST_UNDEFINED;
    }
}

sub options($;$) {
    my $self = shift;
    $self->{cmd_options} = shift if ( $_[0] );
    $self->{cmd_options};
}

sub command($;$) {
    my $self = shift;
    $self->{command} = shift if ( $_[0] );
    $self->{command};
}

sub args($;$) {
    my $self = shift;
    $self->{args} = shift if ( $_[0] );
    $self->{args};
}

sub cmdline($) {
    my $self = shift;
    my $args = [ $self->{gnupg_path} ];

    # Default options
    push @$args, "--no-tty" unless $self->{trace};
    push @$args, "--no-greeting", "--status-fd", fileno $self->{status_fd},
		 "--run-as-shm-coprocess", "0";

    # Check for homedir and options file
    push @$args, "--homedir", $self->{homedir} if $self->{homedir};
    push @$args, "--options", $self->{options} if $self->{options};

    # Command options
    push @$args, @{ $self->options };


    # Command and arguments
    push @$args, "--" . $self->command;
    push @$args, @{ $self->args };

    return $args;
}

sub end_gnupg($) {
    my $self = shift;

    print STDERR "GnuPG: closing status fd " . fileno ($self->{status_fd}) 
      . "\n"
	if $self->{trace};

    close $self->{status_fd}
      or croak "error while closing pipe: $!\n";

    waitpid $self->{gnupg_pid}, 0
      or croak "error while waiting for gpg: $!\n";

    for ( qw(protocol gnupg_pid shmid shm_size shm_lock_size
	     command options args status_fd input output
	     next_status ) )
    {
	delete $self->{$_};
    }

}

sub abort_gnupg($$) {
    my ($self,$msg) = @_;

    # Signal our child that it is the end
    if ($self->{gnupg_pid} && kill 0 => $self->{gnupg_pid} ) {
	kill INT => $self->{gnupg_pid};
    }

    $self->end_gnupg;

    croak ( $msg );
}

# Used to push back status information
sub next_status($$$) {
    my ($self,$cmd,$arg) = @_;

    $self->{next_status} = [$cmd,$arg];
}

sub read_from_status($) {
    my $self = shift;
    # Check if a status was pushed back
    if ( $self->{next_status} ) {
	my $status = $self->{next_status};
	$self->{next_status} = undef;
	return @$status;
    }

    print STDERR "GnuPG: reading from status fd " . fileno ($self->{status_fd}) . "\n"
      if $self->{trace};
    my $fd = $self->{status_fd};
    local $/ = "\n"; # Just to be sure
    my $line = <$fd>;
    unless ($line) {
	print STDERR "GnuPG: got from status fd: EOF" if $self->{trace};
	return ();
    }
    print STDERR "GnuPG: got from status fd: $line"
      if $self->{trace};

    my ( $cmd,$arg ) = $line =~ /\[GNUPG:\] (\w+) ?(.+)?$/;
    $self->abort_gnupg( "error communicating with gnupg: bad status line: $line\n" )
      unless $cmd;
    return wantarray ? ( $cmd, $arg ) : $cmd;
}

sub run_gnupg($) {
    my $self = shift;

    my $fd  = gensym;
    my $wfd = gensym;

    pipe $fd, $wfd
      or croak ( "error creating pipe: $!\n" );
    my $old = select $wfd; $| = 1;  # Unbuffer
    select $old;

    # Keep pipe open after close
    fcntl( $fd, F_SETFD, 0 )
	or croak "error removing close on exec flag: $!\n" ;
    fcntl( $wfd, F_SETFD, 0 )
	or croak "error removing close on exec flag: $!\n" ;

    my $pid = fork;
    croak( "error forking: $!" ) unless defined $pid;
    if ( $pid ) {
	# Parent
	close $wfd;

	$self->{status_fd} = $fd;
	$self->{gnupg_pid} = $pid;

	my ($cmd, $arg ) = $self->read_from_status;

	$self->abort_gnupg( "wrong response from gnupg (expected SHM_INFO): $cmd\n")
	  unless ( $cmd eq "SHM_INFO" );

	my ( $proto, $gpid, $shmid, $sz, $lz ) =
	  $arg =~ /pv=(\d+) pid=(\d+) shmid=(\d+) sz=(\d+) lz=(\d+)/;

	$self->abort_gnupg( "unsupported protocol version: $proto\n" )
	  unless $proto == 1;

	$self->{protocol}		= $proto;
	$self->{shmid}			= $shmid;
	$self->{shm_size}		= $sz;
	$self->{shm_lock_size}  = $lz;
    } else {
	# Child
	$self->{status_fd} = $wfd;

	my $cmdline = $self->cmdline;
	unless ( $self->{trace} ) {
	    open (STDERR, "> /dev/null" )
	       or die "can't redirect stderr to /dev/null: $!\n";
	}

	# This is where we grab the data
	if ( ref $self->{input} && defined fileno $self->{input} ) {
	    open ( STDIN, "<&" . fileno $self->{input} )
	      or die "error setting up data input: $!\n";
	} elsif ( $self->{input} ) {
	    open ( STDIN, $self->{input} )
	      or die "error setting up data input: $!\n";
	} # Defaults to stdin

	# This is where the output goes
	if ( ref $self->{output} && defined fileno $self->{output} ) {
	    open ( STDOUT, ">&" . fileno $self->{output} )
	      or die "can't redirect stdout to proper output fd: $!\n";
	} elsif ( $self->{output} ) {
	    open ( STDOUT, ">".$self->{output} )
	      or die "can't open $self->{output} for output: $!\n";
	} # Defaults to stdout

	# Close all open file descriptors except STDIN, STDOUT, STDERR
	# and the status filedescriptor.
	#
	# This is needed for the tie interface which opens pipes which
	# some ends must be closed in the child.
	#
	# Besides this is just plain good hygiene
	my $max_fd = POSIX::sysconf( POSIX::_SC_OPEN_MAX ) || 256;
	foreach my $f ( 3 .. $max_fd ) {
	    next if $f == fileno $self->{status_fd};
	    POSIX::close( $f );
	}

	exec ( @$cmdline )
	  or CORE::die "can't exec gnupg: $!\n";
    }
}

sub cpr_maybe_send($$$) {
    ($_[0])->cpr_send( @_[1, $#_], 1);
}

sub cpr_send($$$;$) {
    my ($self,$key,$value, $optional) = @_;

    my ( $cmd, $arg ) = $self->read_from_status;
    unless ( defined $cmd && $cmd =~ /^SHM_GET/) {
	$self->abort_gnupg( "protocol error: expected SHM_GET_XXX got $cmd\n" )
	  unless $optional;
	$self->next_status( $cmd, $arg );
	return;
    }

    unless ( $arg eq $key ) {
	$self->abort_gnupg ( "protocol error: expected key $key got $arg\n" )
	  unless $optional;
	return;
    }

    my $shmid		= $self->{shmid};
    my $shm_size	= $self->{shm_size};

    my $offset = 0;
    shmread $shmid,$offset,0,2
      or $self->abort_gnupg( "shared memory error: $!\n" );

    $offset = unpack "n", $offset;
    $self->abort_gnupg( "Too long parameter for shared memory\n" )
      if ( ( $shm_size - $offset ) < length $value );

    if ( $cmd eq "SHM_GET_BOOL" ) {
	my $truth = $value ? 1 : 0;
	shmwrite $shmid, pack( "nC", 1, $truth ), $offset, 3
	  or $self->abort_gnupg( "shared memory error: $!\n" );
    } else {
	my $len = length $value;
	shmwrite $shmid, pack( "na*", $len, $value ), $offset, $len + 2
	  or $self->abort_gnupg( "shared memory error: $!\n" );
    }

    # Set data ready flag
    shmwrite $shmid, "\001", 3, 1
      or $self->abort_gnupg( "shared memory error: $!\n" );
    kill USR1 => $self->{gnupg_pid};
}

sub send_passphrase($$) {
    my ($self,$passwd) = @_;

    # GnuPG should now tell us that it needs a passphrase
    my $cmd = $self->read_from_status;
    # Skip UserID hint
    $cmd = $self->read_from_status if ( $cmd =~ /USERID_HINT/ );
    $self->abort_gnupg( "Protocol error: expected NEED_PASSPHRASE.* got $cmd\n")
      unless $cmd =~ /NEED_PASSPHRASE/;
    $self->cpr_send( "passphrase.enter", $passwd );
    unless ( $passwd ) {
	my $cmd = $self->read_from_status;
	$self->abort_gnupg( "Protocol error: expected MISSING_PASSPHRASE got $cmd\n" )
	  unless $cmd eq "MISSING_PASSPHRASE";
    }
}

sub new($%) {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %args = @_;

    my $self = {};
    if ($args{homedir}) {
	croak ( "Invalid home directory: $args{homedir}\n")
	  unless -d $args{homedir} && -w _ && -x _;
	$self->{homedir} = $args{homedir};
    }
    if ($args{options}) {
	croak ( "Invalid options file: $args{options}\n")
	  unless -r $args{options};
	$self->{options} = $args{options};
    }
    if ( $args{gnupg_path} ) {
	croak ( "Invalid gpg path: $args{gnupg_path}\n")
	  unless -x $args{gnupg_path};
	$self->{gnupg_path} = $args{gnupg_path};
    } else {
	my ($path) = grep { -x "$_/gpg" } split /:/, $ENV{PATH};
	croak ( "Couldn't find gpg in PATH ($ENV{PATH})\n" )
	  unless $path;
	$self->{gnupg_path} = "$path/gpg";
    }
    $self->{trace} = $args{trace} ? 1 : 0;

    bless $self, $class;
}

sub DESTROY {
    my $self = shift;
    # Signal our child that it is the end
    if ($self->{gnupg_pid} && kill 0 => $self->{gnupg_pid} ) {
	kill INT => $self->{gnupg_pid};
    }
}

sub gen_key($%) {
    my ($self,%args) = @_;

    my $algo	  = $args{algo};
    $algo ||= DSA_ELGAMAL;

    my $size	  = $args{size};
    $size ||= 1024;
    croak ( "Keysize is too small: $size" ) if $size < 768;
    croak ( "Keysize is too big: $size" )   if $size > 2048;

    my $expire	  = $args{valid};
    $expire		  ||= 0;

    my $passphrase = $args{passphrase} || "";
    my $name	  = $args{name};

    croak "Missing key name\n"	  unless $name;
    croak "Invalid name: $name\n" 
      unless $name =~ /^\s*[^0-9\<\(\[\]\)\>][^\<\(\[\]\)\>]+$/;

    my $email	  = $args{email};
    if ( $email ) {
	croak "Invalid email address: $email"
	  unless $email =~ /^\s*		# Whitespace are okay
				[a-zA-Z0-9_-]	# Doesn't start with a dot
				[a-zA-Z0-9_.-]*
				\@		# Contains at most one at
				[a-zA-Z0-9_.-]+
				[a-zA-Z0-9_-]	# Doesn't end in a dot
			       /x 
				 && $email !~ /\.\./;
    } else {
	$email = "";
    }

    my $comment	  = $args{comment};
    if ( $comment ) {
	croak "Invalid characters in comment" if $comment =~ /[()]/;
    } else {
	$comment = "";
    }

    $self->command( "gen-key" );
    $self->options( [] );
    $self->args( [] );

    $self->run_gnupg;

    $self->cpr_send("keygen.algo", $algo );
    if ( $algo == ELGAMAL ) {
	# Shitty interactive program, yes I'm sure.
	# I'm a program, I can't change my mind now.
	$self->cpr_send( "keygen.algo.elg_se", 1 )
    }
    $self->cpr_send( "keygen.size",		$size );
    $self->cpr_send( "keygen.valid",	$expire );
    $self->cpr_send( "keygen.name",		$name );
    $self->cpr_send( "keygen.email",	$email );
    $self->cpr_send( "keygen.comment",	$comment );

    $self->send_passphrase( $passphrase );

    $self->end_gnupg;

    # Woof. We should now have a generated key !
}

sub import_keys($%) {
    my ($self,%args) = @_;


    $self->command( "import" );
    $self->options( [] );

    my $count;
    if ( ref $args{keys} ) {
	$self->args( $args{keys} );
    } else {
	# Only one file to import
	$self->{input} = $args{keys};
	$self->args( [] );
    }

    $self->run_gnupg;
  FILE:
    my $num_files = ref $args{keys} ? @{$args{keys}} : 1;
    my ($cmd,$arg);

    # We will see one IMPORTED for each key that is imported
  KEY:
    while ( 1 ) {
	($cmd,$arg) = $self->read_from_status;
	last KEY unless $cmd =~ /IMPORTED/;
	$count++
    }

    # We will see one IMPORT_RES for all files processed
    $self->abort_gnupg ( "protocol error expected IMPORT_RES got $cmd\n" )
      unless $cmd =~ /IMPORT_RES/;
    $self->end_gnupg;

    # We return the number of imported keys
    return $count;
}

sub export_keys($%) {
    my ($self,%args) = @_;

    my $options = [];
    push @$options, "--armor"	    if $args{armor};

    $self->{output} = $args{output};

    my $keys = [];
    if ( $args{keys}) {
	push @$keys,
	  ref $args{keys} ? @{$args{keys}} : $args{keys};
    }

    if ( $args{secret} ) {
	$self->command( "export-secret-keys" );
    } elsif ( $args{all} ){
	$self->command( "export-all" );
    } else {
	$self->command( "export" );
    }
    $self->options( $options );
    $self->args( $keys );

    $self->run_gnupg;
    $self->end_gnupg;
}

sub encrypt($%) {
    my ($self,%args) = @_;

    my $options = [];
    croak ( "no recipient specified\n" )
      unless $args{recipient} or $args{symmetric};
    push @$options, "--recipient" => $args{recipient};

    push @$options, "--sign"	    if $args{sign};
    croak ( "can't sign an symmetric encrypted message\n" )
      if $args{sign} and $args{symmetric};

    my $passphrase  = $args{passphrase} || "";

    push @$options, "--armor"	    if $args{armor};
    push @$options, "--local-user", $args{"local-user"}
      if defined $args{"local-user"};

    $self->{input}  = $args{plaintext} || $args{input};
    $self->{output} = $args{output};
    if ( $args{symmetric} ) {
	$self->command( "symmetric" );
    } else {
	$self->command( "encrypt" );
    }
    $self->options( $options );
    $self->args( [] );

    $self->run_gnupg;

    # Unless we decided to sign or are using symmetric cipher, we are done
    if ( $args{sign} or $args{symmetric} ) {
	$self->send_passphrase( $passphrase );
	if ( $args{sign} ) {
	    my ($cmd,$line) = $self->read_from_status;
	    $self->abort_gnupg( "invalid passphrase\n" )
	      unless $cmd =~ /GOOD_PASSPHRASE/;
	}
    }

    # It is possible that this key has no assigned trust value.
    # Assume the caller knows what he is doing.
    $self->cpr_maybe_send( "untrusted_key.override", 1 );

    $self->end_gnupg unless $args{tie_mode};
}

sub sign($%) {
    my ($self,%args) = @_;

    my $options = [];
    my $passphrase  = $args{passphrase} || "";

    push @$options, "--armor"	    if $args{armor};
    push @$options, "--local-user", $args{"local-user"}
      if defined $args{"local-user"};

    $self->{input}  = $args{plaintext} || $args{input};
    $self->{output} = $args{output};
    if ( $args{clearsign} ) {
	$self->command( "clearsign" );
    } elsif ( $args{"detach-sign"}) {
	$self->command( "detach-sign" );
    } else {
	$self->command( "sign" );
    }
    $self->options( $options );
    $self->args( [] );

    $self->run_gnupg;

    # We need to unlock the private key
    $self->send_passphrase( $passphrase );
    my ($cmd,$line) = $self->read_from_status;
    $self->abort_gnupg( "invalid passphrase\n" )
      unless $cmd =~ /GOOD_PASSPHRASE/;

    $self->end_gnupg unless $args{tie_mode};
}

sub clearsign($%) {
    my $self = shift;
    $self->sign( @_, clearsign => 1 );
}


sub check_sig($;$$) {
    my ( $self, $cmd, $arg) = @_;

    # Our caller may already have grabbed the first line of
    # signature reporting.
    ($cmd,$arg) = $self->read_from_status unless ( $cmd );

    # Ignore patent warnings.
    ( $cmd, $arg ) = $self->read_from_status()
      if ( $cmd =~ /RSA_OR_IDEA/ );

    $self->abort_gnupg( "invalid signature from ", $arg =~ /[^ ](.+)/, "\n" )
      if ( $cmd =~ /BADSIG/);

    $self->abort_gnupg( "error verifying signature from ", 
			$arg =~ /([^ ])/, "\n" )
      if ( $cmd =~ /ERRSIG/);

    $self->abort_gnupg ( "protocol error: expected SIG_ID" )
      unless $cmd =~ /SIG_ID/;
    my ( $sigid, $date, $time ) = split /\s+/, $arg;

    ( $cmd, $arg ) = $self->read_from_status;
    $self->abort_gnupg ( "protocol error: expected GOODSIG" )
      unless $cmd =~ /GOODSIG/;
    my ( $keyid, $name ) = split /\s+/, $arg, 2;

    ( $cmd, $arg ) = $self->read_from_status;
    $self->abort_gnupg ( "protocol error: expected VALIDSIG" )
      unless $cmd =~ /VALIDSIG/;
    my ( $fingerprint ) = split /\s+/, $arg, 2;

    ( $cmd, $arg ) = $self->read_from_status;
    $self->abort_gnupg ( "protocol error: expected TRUST*" )
      unless $cmd =~ /TRUST/;
    my ($trust) = parse_trust( $cmd );

    return { sigid	    => $sigid,
	     date	    => $date,
	     timestamp	    => $time,
	     keyid	    => $keyid,
	     user	    => $name,
	     fingerprint    => $fingerprint,
	     trust	    => $trust,
	   };
}

sub verify($%) {
    my ($self,%args) = @_;

    croak ( "missing signature argument\n" ) unless $args{signature};
    my $files = [];
    if ( $args{file} ) {
	croak ( "detached signature must be in a file\n" ) 
	  unless -f $args{signature};
	push @$files, $args{signature}, 
	  ref $args{file} ? @{$args{file}} : $args{file};
    } else {
	$self->{input} = $args{signature};
    }
    $self->command( "verify" );
    $self->options( [] );
    $self->args( $files );

    $self->run_gnupg;
    my $sig = $self->check_sig;

    $self->end_gnupg;

    return $sig;
}

sub decrypt($%) {
    my $self = shift;
    my %args = @_;

    $self->{input}  = $args{ciphertext} || $args{input};
    $self->{output} = $args{output};
    $self->command( "decrypt" );
    $self->options( [] );
    $self->args( [] );

    $self->run_gnupg;

    $self->decrypt_postwrite( @_ ) unless $args{tie_mode};
}

sub decrypt_postwrite($%) {
    my ($self,%args) = @_;

    my $passphrase  = $args{passphrase} || "";

    my ( $cmd, $arg );
    unless ( $args{symmetric} ) {
	( $cmd, $arg ) = $self->read_from_status;
	$self->abort_gnupg ( "protocol error: expected ENC_TO got $cmd: \n" )
	  unless $cmd =~ /ENC_TO/;
    }

    $self->send_passphrase( $passphrase );

    ($cmd,$arg) = $self->read_from_status;
    $self->abort_gnupg ( "invalid passphrase\n" )
      if $cmd =~ /BAD_PASSPHRASE/;
    my $sig = undef;
    if ( ! $args{symmetric} ) {
	$self->abort_gnupg ( "protocol error: expected GOOD_PASSPHRASE got $cmd: \n" )
	  unless $cmd =~ /GOOD_PASSPHRASE/;

	$sig = $self->decrypt_postread() unless $args{tie_mode};
    } else {
	# gnupg 1.0.2 adds this status message
	( $cmd, $arg ) = $self->read_from_status()
	  if $cmd =~ /BEGIN_DECRYPTION/;

	$self->abort_gnupg( "invalid passphrase" )
	  unless $cmd =~ /DECRYPTION_OKAY/;
    }

    $self->end_gnupg() unless $args{tie_mode};

    return $sig ? $sig : 1;
}

sub decrypt_postread($) {
    my $self = shift;

    # gnupg 1.0.2 adds this status message
    my ( $cmd, $arg ) = $self->read_from_status;

    ( $cmd, $arg ) = $self->read_from_status()
      if $cmd =~ /BEGIN_DECRYPTION/;

    my $sig = undef;
    if ( $cmd =~ /SIG_ID/ ) {
	$sig = $self->check_sig( $cmd, $arg );
	( $cmd, $arg ) = $self->read_from_status;
    }

    $self->abort_gnupg( "protocol error: expected DECRYPTION_OKAY got $cmd: \n" )
      unless $cmd =~ /DECRYPTION_OKAY/;

    return $sig ? $sig : 1;
}

1;
__END__

=pod

=head1 NAME

GnuPG - Perl module interface to the GNU Privacy Guard.

=head1 SYNOPSIS

    use GnuPG qw( :algo );

    my $gpg = new GnuPG();

    $gpg->encrypt(  plaintext	=> "file.txt",	output	    => "file.gpg",
		    armor	=> 1,		 sign	=> 1,
		    passphrase  => $secret );

    $gpg->decrypt( ciphertext	=> "file.gpg",	output	    => "file.txt" );

    $gpg->clearsign( plaintext => "file.txt", output => "file.txt.asc",
		     passphrase => $secret,   armor => 1,
		    );

    $gpg->verify( signature => "file.txt.asc", file => "file.txt" );

    $gpg->gen_key( name => "Joe Blow",	    comment => "My GnuPG key",
		   passphrase => $secret,
		    );

=head1 DESCRIPTION

GnuPG is a perl interface to the GNU Privacy Guard. It uses the
shared memory coprocess interface that gpg provides for its 
wrappers. It tries its best to map the interactive interface of
the gpg to a more programmatic model.

=head1 API OVERVIEW

The API is accessed through methods on a GnuPG object which is
a wrapper around the B<gpg> program.  All methods takes their
argument using named parameters, and errors are returned by
throwing an exception (using croak).  If you wan't to catch
errors you will have to use eval.

There is also a tied file handle interface which you may find more
convenient for encryption and decryption. See GnuPG::Tie(3) for details.

=head1 CONSTRUCTOR

=head2 new ( [params] )

You create a new GnuPG wrapper object by invoking its new method.
(How original !).  The module will try to finds the B<gpg> program
in your path and will croak if it can't find it. Here are the
parameters that it accepts :

=over

=item gnupg_path

Path to the B<gpg> program.

=item options

Path to the options file for B<gpg>. If not specified, it will use
the default one (usually F<~/.gnupg/options>).

=item homedir

Path to the B<gpg> home directory. This is the directory that contains
the default F<options> file, the public and private key rings as well
as the trust database.

=item trace

If this variable is set to true, B<gpg> debugging output will be sent
to stderr.

=back

    Example: my $gpg = new GnuPG();

=head1 METHODS

=head2 gen_key( [params] )

This methods is used to create a new gpg key pair. The methods croaks
if there is an error. It is a good idea to press random keys on the
keyboard while running this methods because it consumes a lot of
entropy from the computer. Here are the parameters it accepts :

    Ex: $gpg->

=over

=item algo

This is the algorithm use to create the key. Can be ELGAMAL,
DSA_ELGAMAL or DSA. It defaults to DSA_ELGAMAL. To import
those constant in your name space, use the :algo tag.

=item size

The size of the public key. Defaults to 1024. Cannot be less than
768 bits, and keys longer than 2048 are also discouraged. (You *DO*
know that your monitor may be leaking sensitive informations ;-).

=item valid

How long the key is valid. Defaults to 0 or never expire.

=item name

This is the only mandatory argument. This is the name that will used 
to construct the user id.

=item email

Optional email portion of the user id.

=item comment

Optional comment portion of the user id.

=item passphrase

The passphrase that will be used to encrypt the private key. Optional
but strongly recommended.

=back

    Example: $gpg->gen_key( algo => DSA_ELGAMAL, size => 1024,
			    name => "My name" );

=head2 import_keys( [params] )

Import keys into the GnuPG private or public keyring. The method
croaks if it encounters an error. It returns the number of
keys imported. Parameters :

=over

=item keys

Only parameter and mandatory. It can either be a filename or a
reference to an array containing a list of files that will be
imported.

=back

    Example: $gpg->import_keys( keys => [ qw( key.pub key.sec ) ] );

=head2 export_keys( [params] )

Exports keys from the GnuPG keyrings. The method croaks if it
encounters an error. Parameters :

=over

=item keys

Optional argument that restricts the keys that will be exported. 
Can either be a user id or a reference to an array of userid that
specifies the keys to be exported. If left unspecified, all keys
will be exported.

=item secret

If this argument is to true, the secret keys rather than the public
ones will be exported.

=item all

If this argument is set to true, all keys (even those that aren't
OpenPGP compliant) will be exported.

=item output

This argument specifies where the keys will be exported. Can be either
a file name or a reference to a file handle. If not specified, the 
keys will be exported to stdout.

=item armor

Set this parameter to true, if you want the exported keys to be ASCII
armored.

=back

    Example: $gpg->export_keys( armor => 1, output => "keyring.pub" );


=head2 encrypt( [params] )

This method is used to encrypt a message, either using assymetric
or symmetric cryptography. The methods croaks if an error is
encountered. Parameters:

=over

=item plaintext

This argument specifies what to encrypt. It can be either a filename
or a reference to a file handle. If left unspecified, STDIN will be
encrypted.

=item output

This optional argument specifies where the ciphertext will be output.
It can be either a file name or a reference to a file handle. If left
unspecified, the ciphertext will be sent to STDOUT.

=item armor

If this parameter is set to true, the ciphertext will be ASCII
armored.

=item symmetric

If this parameter is set to true, symmetric cryptography will be
used to encrypt the message. You will need to provide a I<passphrase>
parameter.

=item recipient

If not using symmetric cryptography, you will have to provide this
parameter. It should contains the userid of the intended recipient of
the message. It will be used to look up the key to use to encrypt the
message.

=item sign

If this parameter is set to true, the message will also be signed. You
will probably have to use the I<passphrase> parameter to unlock the
private key used to sign message. This option is incompatible with
the I<symmetric> one.

=item local-user

This parameter is used to specified the private key that will be used
to sign the message. If left unspecified, the default user will be
used. This option only makes sense when using the I<sign> option.

=item passphrase

This parameter contains either the secret passphrase for the symmetric
algorithm or the passphrase that should be used to decrypt the private
key.

=back

    Example: $gpg->encrypt( plaintext => file.txt, output => "file.gpg",
			    sign => 1, passphrase => $secret
			    );

=head2 sign( [params] )

This method is used create a signature for a file or stream of data.
This method croaks on errors. Parameters :

=over

=item plaintext

This argument specifies what  to sign. It can be either a filename
or a reference to a file handle. If left unspecified, the data read on
STDIN will be signed.

=item output

This optional argument specifies where the signature will be output.
It can be either a file name or a reference to a file handle. If left
unspecified, the signature will be sent to STDOUT.

=item armor

If this parameter is set to true, the signature will be ASCII armored.

=item passphrase

This parameter contains the secret that should be used to decrypt the
private key.

=item local-user

This parameter is used to specified the private key that will be used
to make the signature . If left unspecified, the default user will be
used.

=item detach-sign

If set to true, a digest of the data will be signed rather than
the whole file.

=back

    Example: $gpg->sign( plaintext => "file.txt", output => "file.txt.asc",
			 armor => 1,
			 );

=head2 clearsign( [params] )

This methods clearsign a message. The output will contains the original
message with a signature appended. It takes the same parameters as
the B<sign> method.

=head2 verify( [params] )

This method verifies a signature against the signed message. The
methods croaks if the signature is invalid or an error is
encountered. If the signature is valid, it returns an hash with
the signature parameters. Here are the method's parameters :

=over

=item signature

If the message and the signature are in the same file (i.e. a
clearsigned message), this parameter can be either a file name or a
reference to a file handle. If the signature doesn't follows the
message, than it must be the name of the file that contains the
signature.

=item file

This is a file name or a reference to an array of file names that
contains the signed data.

=back

When the signature is valid, here are the elements of the hash
that is returned by the method :

=over

=item sigid

The signature id. This can be used to protect against replay
attack.

=item date

The data at which the signature has been made.

=item timestamp

The epoch timestamp of the signature.

=item keyid

The key id used to make the signature.

=item user

The userid of the signer.

=item fingerprint

The fingerprint of the signature.

=item trust

The trust value of the public key of the signer. Those are values that
can be imported in your namespace with the :trust tag. They are 
(TRUST_UNDEFINED, TRUST_NEVER, TRUST_MARGINAL, TRUST_FULLY, TRUST_ULTIMATE).

=back

    Example : my $sig = $gpg->verify( signature => "file.txt.asc",
				      file => "file.txt" );

=head2 decrypt( [params] )

This method decrypts an encrypted message. It croaks, if there is an
error while decrypting the message. If the message was signed, this
method also verifies the signature. If decryption is sucessful, the
method either returns the valid signature parameters if present, or
true. Method parameters :

=over

=item ciphertext

This optional parameter contains either the name of the file 
containing the ciphertext or a reference to a file handle containing
the ciphertext. If not present, STDIN will be decrypted.

=item output

This optional parameter determines where the plaintext will be stored.
It can be either a file name or a reference to a file handle.  If left
unspecified, the plaintext will be sent to STDOUT.

=item symmetric

This should be set to true, if the message is encrypted using
symmetric cryptography.

=item passphrase

The passphrase that should be used to decrypt the message (in the case
of a message encrypted using a symmetric cipher) or the secret that
will unlock the private key that should be used to decrypt the
message.

=back

    Example: $gpg->decrypt( ciphertext => "file.gpg", output => "file.txt" 
			    passphrase => $secret );

=head1 AUTHOR

Francis J. Lacoste <francis.lacoste@Contre.COM>

=head1 COPYRIGHT

Copyright (c) 1999,2000 iNsu Innovations. Inc.
Copyright (c) 2001 Francis J. Lacoste

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 SEE ALSO

gpg(1) GnuPG::Tie(3)

=cut
