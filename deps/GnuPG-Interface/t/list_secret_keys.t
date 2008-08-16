#!/usr/bin/perl -w
#
# $Id: list_secret_keys.t,v 1.7 2001/05/03 06:00:06 ftobin Exp $
#

use strict;
use English qw( -no_match_vars );

use lib './t';
use MyTest;
use MyTestSpecific;

my $outfile;

TEST
{
    reset_handles();
    
    my $pid = $gnupg->list_secret_keys( handles => $handles );
    close $stdin;
    
    $outfile = 'test/secret-keys/1.out';
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
    my @files_to_test = ( 'test/secret-keys/1.0.test' );

    return file_match( $outfile, @files_to_test );
};


TEST
{
    reset_handles();
    
    my $pid = $gnupg->list_secret_keys( handles      => $handles,
					command_args => '0xF950DA9C' );
    close $stdin;
    
    $outfile = 'test/secret-keys/2.out';
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
    
    my $pid = $gnupg->list_secret_keys( handles      => $handles,
					command_args => '0xF950DA9C' );
    
    waitpid $pid, 0;
    
    $outfile = $texts{temp}->fn();
    
    return $CHILD_ERROR == 0;
};
