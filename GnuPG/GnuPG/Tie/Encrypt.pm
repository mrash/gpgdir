#
#    GnuPG/Tie/Encrypt.pm - Tied file handle interface to the encryption 
#			    function of GnuPG.
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
package GnuPG::Tie::Encrypt;

use GnuPG;
use GnuPG::Tie;

use vars qw( @ISA );

BEGIN {
    @ISA = qw( GnuPG::Tie );
};

sub run_gnupg {
    my $self = shift;

    $self->{gnupg}->encrypt( @_ );
};

1;
