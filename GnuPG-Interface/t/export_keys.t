#!/usr/bin/perl -w
#
# $Id: export_keys.t,v 1.6 2001/05/03 06:00:06 ftobin Exp $
#

use strict;
use English qw( -no_match_vars );

use lib './t';
use MyTest;
use MyTestSpecific;

TEST
{
    reset_handles();
    
    my $pid = $gnupg->export_keys( handles      => $handles,
				   command_args => '0xF950DA9C' );
    close $stdin;
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    $handles->stdout( $texts{temp}->fh() );
    $handles->options( 'stdout' )->{direct} = 1;
    
    my $pid = $gnupg->export_keys( handles            => $handles,
				   command_args => '0xF950DA9C' );
    waitpid $pid, 0;
    return $CHILD_ERROR == 0;
};
