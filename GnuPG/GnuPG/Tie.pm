#
#    GnuPG.pm - Abstract tied interface to the GnuPG.
#
#    This file is part of GnuPG.pm.
#
#    Author: Francis J. Lacoste <francis.lacoste@Contre.COM>
#
#    Copyright (C) 1999, 2000 iNsu Innovations Inc.
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
package GnuPG::Tie;

use GnuPG;
use Symbol;

use Carp;

use Fcntl;

use strict;

sub TIEHANDLE {
    my $class = shift;
    $class = ref $class || $class;

    my ($gpg_in, $gpg_out)  = ( gensym, gensym );
    my ($tie_in,$tie_out)   = ( gensym, gensym );
    pipe $gpg_in, $tie_out
      or croak "error while creating pipe: $!";
    pipe $tie_in, $gpg_out
      or croak "error while creating pipe: $!";

    # Unbuffer writer pipes
    for my $fd ( ($gpg_out, $tie_out) ) {
	my $old = select $fd;
	$| = 1;
	select $old;
    }

    # Keep pipes open after exec
    # Removed close on exec from all file descriptor
    for my $fd ( ( $gpg_in, $gpg_out, $tie_in, $tie_out ) ) {
	fcntl( $fd, F_SETFD, 0 )
	  or croak "error removing close on exec flag: $!\n" ;
    }

    # Operate in non blocking mode
    for my $fd ( $tie_in, $tie_out ) {
	my $flags = fcntl $fd, F_GETFL, 0
	  or croak "error getting flags on pipe: $!\n";
	fcntl $fd, F_SETFL, $flags | O_NONBLOCK
	  or croak "error setting non-blocking IO on pipe: $!\n";
    }

    my $self = bless { reader	    => $tie_in,
		       writer	    => $tie_out,
		       done_writing => 0,
		       buffer	    => "",
		       len	    => 0,
		       offset	    => 0,
		       line_buffer  => "",
		       eof	    => 0,
		       gnupg	    => new GnuPG( @_ ),
		     }, $class;

    # Let subclass call the appropriate method and set
    # up the GnuPG object.
    $self->run_gnupg( @_,
		      input	=> $gpg_in,
		      output	=> $gpg_out,
		      tie_mode	=> 1,
		    );
    close $gpg_in;
    close $gpg_out;

    return $self;
}

sub WRITE {
    my ( $self, $buf, $len, $offset ) = @_;

    croak "attempt to read on a closed file handle\n"
      unless defined $self->{writer};

    croak ( "can't write after having read" ) if $self->{done_writing};

    my ( $r_in, $w_in ) = ( '', '' );
    vec( $r_in, fileno $self->{reader}, 1) = 1;
    vec( $w_in, fileno $self->{writer}, 1) = 1;

    my $left = $len;
    while ( $left ) {
	my ($r_out, $w_out) = ($r_in, $w_in);
	my $nfound = select $r_out, $w_out, undef, undef;
	croak "error in select: $!\n" unless defined $nfound;

	# Check if we can write
	if ( vec $w_out, fileno $self->{writer}, 1 ) {
	    my $n = syswrite $self->{writer}, $buf, $len, $offset;
	    croak "error on write: $!\n" unless defined $n;
	    $left -= $n;
	    $offset += $n;
	}
	# Check if we can read
	if ( vec $r_out, fileno $self->{reader}, 1 ) {
	    my $n = sysread $self->{reader}, $self->{buffer}, 1024,
	      $self->{len};
	    croak "error on read: $!\n" unless defined $n;
	    $self->{len} += $n;
	}
    }

    return $len;
}

sub done_writing() {
    my $self = shift;

    # Once we start reading, no other writing can be place
    # on the pipe. So we close the writer file descriptor
    unless ( $self->{done_writing} ) {
	$self->{done_writing} = 1;
	close $self->{writer}
	  or croak "error closing writer pipe: $\n";

	$self->postwrite_hook();
    }
}

sub READ {
    my $self = shift;
    my $bufref = \$_[0];
    my ( undef, $len, $offset ) = @_;

    croak "attempt to read on a closed file handle\n" 
      unless defined $self->{reader};

    if ( $self->{eof}) {
	$self->{eof} = 0;
	return 0;
    }

    # Start reading the input
    $self->done_writing unless ( $self->{done_writing} );

    # Check if we have something in our buffer
    if ( $self->{len} - $self->{offset} ) {
	my $left = $self->{len} - $self->{offset};
	my $n = $left > $len ? $len : $left;
	substr( $$bufref, $offset, $len) =
	  substr $self->{buffer}, $self->{offset}, $n;
	$self->{offset} += $n;

	# Return only if we have read the requested length.
	return $n if $n == $len;

	$offset += $n;
	$len    -= $n;
    }

    # Wait for the reader fd to come ready
    my ( $r_in ) = '';
    vec( $r_in, fileno $self->{reader}, 1 ) = 1;
    my $nfound = select $r_in, undef, undef, undef;
    croak "error in select: $!\n" unless defined $nfound;

    my $n = sysread $self->{reader}, $$bufref, $len, $offset;
    croak "error in read: $!\n" unless defined $n;

    $n;
}

sub PRINT {
    my $self = shift;

    my $sep = defined $, ? $, : "";
    my $buf = join $sep, @_;

    $self->WRITE( $buf, length $buf, 0 );
}

sub PRINTF {
    my $self = shift;

    my $buf = sprintf @_;

    $self->WRITE( $buf, length $buf, 0 );
}

sub GETC {
    my $self = shift;

    my $c = undef;
    my $n = $self->READ( $c, 1, 0 );

    return undef unless $n;
    $c;
}

sub READLINE {
    wantarray ? $_[0]->getlines() : $_[0]->getline();
}

sub CLOSE {
    my $self = shift;

    $self->done_writing;

    close $self->{reader}
      or croak "error closing reader pipe: $!\n";

    $self->postread_hook();

    $self->{gnupg}->end_gnupg();

    $self->{reader} = undef;
    $self->{writer} = undef;

    ! $?;
}

sub getlines {
    my $self = shift;

    my @lines = ();
    my $line;
    while ( defined( $line = $self->getline ) ) {
	push @lines, $line;
    }

    @lines;
}

sub getline {
    my $self = shift;

    if ( $self->{eof} ) {
	# Clear EOF
	$self->{eof} = 0;
	return undef;
    }

    # Handle slurp mode
    if ( not defined $/ ) {
	my $buf	    = $self->{line_buffer};
	my $offset  = length $buf;
	while ( my $n = $self->READ( $buf, 4096, $offset ) ) {
	    $offset += $n
	}
	return $buf;
    }

    # Handle explicit RS
    if ( $/ ne "" ) {
	my $buf = $self->{line_buffer};
	while ( not $self->{eof} ) {

	    if ( length $buf != 0 ) {
		my $i;
		if ( ( $i = index $buf, $/ ) != -1 ) {
		    # Found end of line
		    $self->{line_buffer} = substr $buf, $i + length $/;

		    return substr $buf, 0, $i + length $/;
		}
	    }

	    # Read more data in our buffer
	    my $n = $self->READ( $buf, 4096, length $buf );
	    if ( $n == 0 ) {
		# Set EOF
		$self->{eof} = 1;
		return length $buf == 0 ? undef : $buf ;
	    }
	}
    } else {
	my $buf = $self->{line_buffer};
	while ( not $self->{eof} ) {

	    if ( $buf =~ m/(\r\n\r\n+|\n\n+)/s ) {
		my ($para, $rest) = split /\r\n\r\n+|\n\n+/, $buf, 2;
		$self->{line_buffer} = $rest;
		return $para . $1;
	    }

	    # Read more data in our buffer
	    my $n = $self->READ( $buf, 4096, length $buf );
	    if ( $n == 0 ) {
		# Set EOF
		$self->{eof} = 1;
		return length $buf == 0 ? undef : $buf ;
	    }
	}
    }
}

# Hook called after reading is done
sub postread_hook {

}

# Hook called when writing is done.
sub postwrite_hook {

}

1;

__END__

=pod

=head1 NAME

GnuPG::Tie::Encrypt - Tied filehandle interface to encryption with the GNU Privacy Guard.

GnuPG::Tie::Decrypt - Tied filehandle interface to decryption with the GNU Privacy Guard.

=head1 SYNOPSIS

    use GnuPG::Tie::Encrypt;
    use GnuPG::Tie::Decrypt;

    tie *CIPHER, 'GnuPG::Tie::Encrypt', armor => 1, recipient => 'User';
    print CIPHER <<EOF
This is a secret
EOF
    local $/ = undef;
    my $ciphertext = <CIPHER>;
    close CIPHER;
    untie *CIPHER;

    tie *PLAINTEXT, 'GnuPG::Tie::Decrypt', passphrase => 'secret';
    print PLAINTEXT $ciphertext;
    my $plaintext = <PLAINTEXT>;

    # $plaintext should now contains 'This is a secret'
    close PLAINTEXT;
    untie *PLAINTEXT

=head1 DESCRIPTION

GnuPG::Tie::Encrypt and GnuPG::Tie::Decrypt provides a tied  file handle
interface to encryption/decryption facilities of the GNU Privacy guard.

With GnuPG::Tie::Encrypt everyting you write to the file handle will be
encrypted. You can read the ciphertext from the same file handle.

With GnuPG::Tie::Decrypt you may read the plaintext equivalent of a
ciphertext. This is one can have been written to file handle.

All options given to the tie constructor will be passed on to the underlying
GnuPG object. You can use a mix of options to ouput directly to a file or
to read directly from a file, only remember than once you start reading
from the file handle you can't write to it anymore.

=head1 AUTHOR

Francis J. Lacoste <francis.lacoste@Contre.COM>

=head1 COPYRIGHT

Copyright (c) 1999, 2000 iNsu Innovations Inc.
Copyright (c) 2001 Francis J. Lacoste

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 SEE ALSO

gpg(1) GnuPG(3)

=cut
