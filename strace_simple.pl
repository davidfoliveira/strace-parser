#!/usr/bin/perl

use strict;
use warnings;

# TODO:
#
# - Support for <unfinished ...> and <... bla resumed>
#


# Parse a system call argument list
sub parseArgs {
	my ($argStr) = @_;
#	print "PARSE: $argStr\n";
}

# Register a system call
sub registerCall {
	my ($pid, $time, $call) = @_;

	if ( $call =~ /^\s*(\w+)\((.*?)\) += +(\-?[\dxa-f]+|\?)/ ) {
		my ($syscall, $argStr) = ($1, $2);
		my @args = parseArgs($argStr);
		if ( $syscall eq "connect" ) {
			print "IM CONNECTING!! $call\n";
		}
#		print "SYSCALL: $syscall\n";
	}

}

# Register a process exit
sub registerExit {
	my ($pid, $time, $signal) = @_;
}

# Register a received signal
sub registerSignal {
	my ($pid, $time, $signal, $data) = @_;
}

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

open(STRACE, $strace) || die "Error running strace '$strace' $!\n";
my $continues = 0;
my $prev;
while (<STRACE>) {
	s/\r?\n$//g;
	my ($pid, $time) = $prev ? @{$prev}{qw(pid time)} : (undef, undef);

	# Get the PID
	$pid = $1 if !$pid && s/^\s*\[pid +(\d+)\] +//;

	# Get the time
	$time = $1 if !$time && s/^\s*(\d{1,2}:\d{1,2}:\d{1,2}(?:\.\d{6})?) +//;

	# The rest of the line
	my $call = ($prev ? $prev->{data} : "") . $_;

	# Does it continue ?
	$continues = !/\s+=\s+(\-?[\dxa-f]+|\?)\s*(?:(?:[A-Z_]+ +)?\([^)]*?\))?$/;
	if ( !$continues ) {
		$pid ||= "main";
		$time ||= "??";
#		print "strace: ($pid) ($time) '$call'\n";
		registerCall($pid, $time, $call);
		$prev = undef;
	}
	else {
		if ( /^\s*\+{3}\s+exited with\s*(\d+)\s+\+{3}\s*$/ ) {
			registerExit($pid, $time, $1);
			next;
		}
		elsif ( /^\s*\-{3}\s+([A-Z]+)(?: (\{.+?\}))?\s+\-{3}\s*$/ ) {
			registerSignal($pid, $time, $1, $2);
			next;
		}

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
