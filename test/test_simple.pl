#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib/);
use Strace::Parser;

# Create a parser
my $parser = new Strace::Parser();
#$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[/* bla something */]) = 10');
#$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[1,2,3,[1,[A,B,[/* something here */],C,{},D],2],4]) = 10');
#$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[1,2,3,[1,[A,B,[/* something here */],C],2],4]) = 10');
$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[1,2,3,[1,[A,B,[{"a":{"b":[B],"c":[/* ah ah */]},"b":2}],C],2],4]) = 10');