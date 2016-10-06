#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib/);
use Strace::Parser;

# Create a parser
my $parser = new Strace::Parser();
#$parser->registerCall(0,'10:10:10.10000','read(3,"blabla\"iei",8096,O_WTVR|O_FOO,[1,2,3,[1,[A,B,[{"a":{"b":[B],"c":[/* ah ah */]},"b":2}],C],2],4]) = 10');
#$parser->registerCall(0,'10:10:10.10000','mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fbcfa3a1000');
$parser->registerCall(0,'10:10:10.10000','rt_sigaction(SIGRTMIN, {0x7f66956b89f0, [], SA_RESTORER|SA_SIGINFO, 0x7f66956c18d0}, NULL, 8) = 0');