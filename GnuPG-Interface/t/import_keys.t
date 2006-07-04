#!/usr/bin/perl -w
#
# $Id: import_keys.t 389 2005-12-11 22:46:36Z mbr $
#

use strict;
use English;

use lib './t';
use MyTest;
use MyTestSpecific;

TEST
{
    reset_handles();
    
    my $pid = $gnupg->import_keys( handles => $handles );
    
    print $stdin @{ $texts{key}->data() };
    close $stdin;
    my @output = <$stdout>;
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    $handles->stdin( $texts{key}->fh() );
    $handles->options( 'stdin' )->{direct} = 1;
    
    my $pid = $gnupg->import_keys( handles => $handles );
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};
