#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib/);
use Strace::Parser;

# TODO:
#
#

# Parse CLI arguments and create an strace call
my ($source, $arg) = @ARGV;
$source || die "Please specify an source type (pid|exec)\n";

my $strace = "strace -s 4096 -q -f -tt ";
if ( $source eq "pid" ) {
	$arg || die "Please specify a process id\n";
	$strace = "-p $arg 2>&1 |";
}
elsif ( $source eq "exec" ) {
	$strace .= "$arg 2>&1 |";
}
elsif ( $source eq "file" ) {
	$strace = $arg;
}
else {
	die "Unsupported source '$source'\n";
}



# Create a parser
my $parser = new Strace::Parser();
$parser->parse($strace);