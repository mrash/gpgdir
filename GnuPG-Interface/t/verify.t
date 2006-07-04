#!/usr/bin/perl -w
#
# $Id: verify.t 389 2005-12-11 22:46:36Z mbr $
#

use strict;
use English;

use lib './t';
use MyTest;
use MyTestSpecific;

TEST
{
    reset_handles();
    
    my $pid = $gnupg->verify( handles => $handles );
    
    print $stdin @{ $texts{signed}->data() };
    close $stdin;
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    $handles->stdin( $texts{signed}->fh() );
    $handles->options( 'stdin' )->{direct} = 1;
    
    my $pid = $gnupg->verify( handles => $handles );
    
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};
