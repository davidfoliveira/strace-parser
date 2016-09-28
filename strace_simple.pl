#!/usr/bin/perl

use strict;
use warnings;


# Register a system call
sub registerCall {
	my ($pid, $time, $call) = @_;

	if ( $call =~ /^\s*(\w+)\(/ ) {
		my $syscall = $1;
		if ( $syscall eq "connect" ) {
			print "IM CONNECTING!! $call\n";
		}
#		print "SYSCALL: $syscall\n";
	}

}


my ($source, $arg) = @ARGV;
$source || die "Please specify an source type (pid|exec)\n";

my $strace = "strace -s 2000 -f -t ";
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

open(STRACE, $strace) || die "Error running strace '$strace' $!\n";
my $continues = 0;
my $prev;
while (<STRACE>) {
	s/\r?\n$//g;
	my ($pid, $time) = $prev ? @{$prev}{qw(pid time)} : (undef, undef);

	# Get the PID
	$pid = $1 if !$pid && s/^\s*\[pid +(\d+)\] +//;

	# Get the time
	$time = $1 if !$time && s/^\s*(\d+:\d+:\d+) +//;

	# The rest of the line
	my $call = ($prev ? $prev->{data} : "") . $_;

	# Does it continue ?
	$continues = !/\s+=\s+(\-?[\dxa-f]+)\s*(?: +[A-Z]+ +\([\w.\- ]+\)\s*)?$/;
	if ( !$continues ) {
		$pid ||= "main";
		$time ||= "??";
#		print "strace: ($pid) ($time) '$call'\n";
		registerCall($pid, $time, $call);
		$prev = undef;
	}
	else {
#		print "CONT: $_\n";
		if ( $prev ) {
			$prev->{data} .= $_;
		}
		else {
			$prev = { pid => $pid, time => $time, data => $_ };
		}
	}
}
close(STRACE);
