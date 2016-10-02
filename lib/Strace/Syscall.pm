package Strace::Syscall;

use strict;
use warnings;


sub register {
    my ($pid, $time, $callName, $args) = @_;
    print "Register [$pid] at $time $callName ".join(' <,> ',@{$args})."\n";
}

1;
