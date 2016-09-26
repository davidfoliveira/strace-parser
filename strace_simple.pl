#!/usr/bin/perl

use strict;
use warnings;

my ($source, $arg) = @ARGV;
$source || die "Please specify an source type (pid|exec)\n";

my $strace = "strace -s 2000 -f -t ";
if ( $source eq "pid" ) {
	$arg || die "Please specify a process id\n";
	$strace .= "-p $arg";
}
elsif ( $source eq "exec" ) {
	$strace .= "$arg";
}
else {
	die "Unsupported source '$source'\n";
}


open(STRACE, "$strace 2>&1 |") || die "Error running strace '$strace' $!\n";
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
		print "strace: ($pid) ($time) '$call'\n";
		$prev = undef;
	}
	else {
		print "CONT: $_\n";
		if ( $prev ) {
			$prev->{data} .= $_;
		}
		else {
			$prev = { pid => $pid, time => $time, data => $_ };
		}
	}
}
close(STRACE);
