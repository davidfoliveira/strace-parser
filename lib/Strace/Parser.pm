#!/usr/bin/perl

use strict;
use warnings;
use Strace::Syscalls;

# TODO:
#
#

# Global data
my %unfinished;

#
sub new {
	my $class = shift;
	my $self = {
		unfinished => { }
	};


	bless $self, $class;
	return $self;
}



# Parse a system call argument list
sub parseArgs {
	my ($argStr) = @_;
#	print "PARSE: $argStr\n";
}

# Register a system call
sub registerCall {
	my ($pid, $time, $call) = @_;

	# Is it a resumed call ?
	if ( $call =~ /\s*<\.{3}\s*(\w+) resumed>\s+(.*)$/ ) {
		return registerResume($pid, $time, $1, $2);
	}


	# A normal syscall
	if ( $call =~ /^\s*(\w+)\((.*?)\) += +(\-?[\dxa-f]+|\?)/ ) {
		my ($callName, $argStr) = ($1, $2);
		my @args = parseArgs($argStr);

		if ( !Strace::Syscalls::register($callName, @args) ) {
			print STDERR "Could not register system call '$call'. Ignoring...\n";
			return undef;
		}
		return 1;
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

# Register an unfinished system call
sub registerUnfinished {
	my ($pid, $time, $call) = @_;
	unless ( $call =~ /^\s*((\w+)\((.*?))<unfinished[^>]*>\s*$/ ) {
		print STDERR "Can't get the unfinished syscall name and args from '$call'\n";
		return undef;
	}

	if ( $unfinished{$pid} ) {
		print STDERR "There's already an unfinished call on pid $pid. Overwriting...\n";
	}

	return $unfinished{$pid} = { time => $time, call => $1, callName => $2 };
}

# Register a system call resume
sub registerResume {
	my ($pid, $time, $callName, $line) = @_;
	if ( $unfinished{$pid} ) {
		if ( $unfinished{$pid}->{callName} ne $callName ) {
			print STDERR "Unfinished syscall name on pid $pid doesn't match ($unfinished{$pid}->{callName} vs $callName), ignoring...\n";
			return undef;
		}
		return registerCall($pid, $unfinished{$pid}->{time}, "$unfinished{$pid}->{call}$line");
		delete $unfinished{$pid};
	}
}


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


# Call strace
open(STRACE, $strace) || die "Error running strace '$strace' $!\n";

# Read strace output
my $continues = 0;
my $prev;
while (<STRACE>) {
	s/\r?\n$//g;
	my ($pid, $time) = $prev ? @{$prev}{qw(pid time)} : (undef, undef);

	# Get the PID
	$pid = $1 if !$pid && s/^\s*\[pid +(\d+)\] +//;
	$pid ||= "main";

	# Get the time
	$time = $1 if !$time && s/^\s*(\d{1,2}:\d{1,2}:\d{1,2}(?:\.\d{6})?) +//;
	$time ||= "??";

	# The rest of the line
	my $call = ($prev ? $prev->{data} : "") . $_;

	# Does it continue ?
	$continues = !/\s+=\s+(\-?[\dxa-f]+|\?)\s*(?:(?:[A-Z_]+ +)?\([^)]*?\))?$/;
	if ( !$continues ) {
#		print "strace: ($pid) ($time) '$call'\n";
		registerCall($pid, $time, $call);
		$prev = undef;
	}
	else {
		# Unfinished syscalls
		if ( /<unfinished \.{3}>\s*$/ ) {
			registerUnfinished($pid, $time, $_);
			next;
		}
		# Process exits
		elsif ( /^\s*\+{3}\s+exited with\s*(\d+)\s+\+{3}\s*$/ ) {
			registerExit($pid, $time, $1);
			next;
		}
		# Signals
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
