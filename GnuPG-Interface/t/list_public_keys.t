#!/usr/bin/perl -w
#
# $Id: list_public_keys.t 389 2005-12-11 22:46:36Z mbr $
#

use strict;
use English;
use IO::File;

use lib './t';
use MyTest;
use MyTestSpecific;

my $outfile;

TEST
{
    reset_handles();
    
    my $pid = $gnupg->list_public_keys( handles => $handles );
    close $stdin;
    
    $outfile = 'test/public-keys/1.out';
    my $out = IO::File->new( "> $outfile" )
      or die "cannot open $outfile for writing: $ERRNO";
    $out->print( <$stdout> );
    close $stdout;
    $out->close();
    
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};


TEST
{
    reset_handles();
    
    my $pid = $gnupg->list_public_keys( handles     => $handles,
					ommand_args => '0xF950DA9C'
				      );
    close $stdin;
    
    $outfile = 'test/public-keys/2.out';
    my $out = IO::File->new( "> $outfile" )
      or die "cannot open $outfile for writing: $ERRNO";
    $out->print( <$stdout> );
    close $stdout;
    $out->close();
    
    waitpid $pid, 0;
    
    return $CHILD_ERROR == 0;
};



TEST
{
    reset_handles();
    
    $handles->stdout( $texts{temp}->fh() );
    $handles->options( 'stdout' )->{direct} = 1;
    
    my $pid = $gnupg->list_public_keys( handles      => $handles,
					command_args => '0xF950DA9C',
				      );
    
    waitpid $pid, 0;
    
    $outfile = $texts{temp}->fn();
    
    return $CHILD_ERROR == 0;
};

