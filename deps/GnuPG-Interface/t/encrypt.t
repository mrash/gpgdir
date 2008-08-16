#!/usr/bin/perl -w
#
# $Id: encrypt.t,v 1.4 2001/05/03 06:00:06 ftobin Exp $
#

use strict;
use English qw( -no_match_vars );

use lib './t';
use MyTest;
use MyTestSpecific;

TEST
{
    reset_handles();
    
    $gnupg->options->clear_recipients();
    $gnupg->options->clear_meta_recipients_keys();
    $gnupg->options->push_recipients( '0x2E854A6B' );
    
    my $pid = $gnupg->encrypt( handles => $handles );
    
    print $stdin @{ $texts{plain}->data() };
    close $stdin;
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    my @keys = $gnupg->get_public_keys( '0xF950DA9C' );
    $gnupg->options->clear_recipients();
    $gnupg->options->clear_meta_recipients_keys();
    $gnupg->options->push_meta_recipients_keys( @keys );
    
    my $pid = $gnupg->encrypt( handles => $handles );
    
    print $stdin @{ $texts{plain}->data() };
    close $stdin;
    waitpid $pid,  0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    $gnupg->options->clear_recipients();
    $gnupg->options->clear_meta_recipients_keys();
    $gnupg->options->push_recipients( '0x2E854A6B' );
    
    $handles->stdin( $texts{plain}->fh() );
    $handles->options( 'stdin' )->{direct} = 1;
    my $pid = $gnupg->encrypt( handles => $handles );
    
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};
