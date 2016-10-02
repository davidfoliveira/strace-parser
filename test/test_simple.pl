#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib/);
use Strace::Parser;

# Create a parser
my $parser = new Strace::Parser();
$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[/* bla something */]) = 10');