package Strace::Parser;

use strict;
use warnings;
use Strace::Syscall;
use Strace::Flagset;
use Strace::Args::Array;
use Strace::Args::Object;


# The constructor
sub new {
	my $class = shift;
	my $self = {
		unfinished => { }
	};

	bless $self, $class;
	return $self;
}


# Parse the strace command output (or file)
sub parse {
	my ($self, $strace) = @_;

	# Call strace
	open(STRACE, $strace) || die "Error running strace '$strace' $!\n";

	# Read strace output
	my $multiLine = 0;
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
		$multiLine = !/\s+=\s+(\-?[\dxa-f]+|\?)\s*(?:(?:[A-Z_]+ +)?\([^)]*?\))?$/;
		if ( !$multiLine ) {
			$self->registerCall($pid, $time, $call);
			$prev = undef;
		}
		else {
			# Unfinished syscalls
			if ( /<unfinished \.{3}>\s*$/ ) {
				$self->registerUnfinished($pid, $time, $_);
				next;
			}
			# Process exits
			elsif ( /^\s*\+{3}\s+exited with\s*(\d+)\s+\+{3}\s*$/ ) {
				$self->registerExit($pid, $time, $1);
				next;
			}
			# Signals
			elsif ( /^\s*\-{3}\s+([A-Z]+)(?: (\{.+?\}))?\s+\-{3}\s*$/ ) {
				$self->registerSignal($pid, $time, $1, $2);
				next;
			}

#			print "ML: $_\n";
			if ( $prev ) {
				$prev->{data} .= $_;
			}
			else {
				$prev = { pid => $pid, time => $time, data => $_ };
			}
		}
	}
	close(STRACE);

	return 1;

}


# Register a system call
sub registerCall {
	my $self = shift;
	my ($pid, $time, $call) = @_;

	# Is it a resumed call ?
	if ( $call =~ /\s*<\.{3}\s*(\w+) resumed>\s+(.*)$/ ) {
		return registerResume($pid, $time, $1, $2);
	}


	# A normal syscall
	if ( $call =~ /^\s*(\w+)\((.*?)\) += +(\-?[\dxa-f]+|\?)/ ) {
		my ($callName, $argStr) = ($1, $2);
		my $args = parseArgs($argStr) || die "Unable to parse syscall argument string '$argStr'\n";

		if ( !Strace::Syscall::register($pid, $time, $callName, $args) ) {
			print STDERR "Could not register system call '$call'. Ignoring...\n";
			return undef;
		}
		return 1;
	}

}

# Register a process exit
sub registerExit {
	my $self = shift;
	my ($pid, $time, $signal) = @_;
}

# Register a received signal
sub registerSignal {
	my $self = shift;
	my ($pid, $time, $signal, $data) = @_;
}

# Register an unfinished system call
sub registerUnfinished {
	my $self = shift;
	my ($pid, $time, $call) = @_;
	unless ( $call =~ /^\s*((\w+)\((.*?))<unfinished[^>]*>\s*$/ ) {
		print STDERR "Can't get the unfinished syscall name and args from '$call'\n";
		return undef;
	}

	if ( $self->{unfinished}->{$pid} ) {
		print STDERR "There's already an unfinished call on pid $pid. Overwriting...\n";
	}

	return $self->{unfinished}->{$pid} = { time => $time, call => $1, callName => $2 };
}

# Register a system call resume
sub registerResume {
	my $self = shift;
	my ($pid, $time, $callName, $line) = @_;
	if ( $self->{unfinished}->{$pid} ) {
		if ( $self->{unfinished}->{$pid}->{callName} ne $callName ) {
			print STDERR "Unfinished syscall name on pid $pid doesn't match ($self->{unfinished}->{$pid}->{callName} vs $callName), ignoring...\n";
			return undef;
		}
		return registerCall($pid, $self->{unfinished}->{$pid}->{time}, "$self->{unfinished}->{$pid}->{call}$line");
		delete $self->{unfinished}->{$pid};
	}
}

# Parse a system call arguments list
sub parseArgs {
	my ($argStr) = @_;

	# Empty string, empty list of arguments
	return [] if $argStr =~ /^\s*$/;

	my $obj = [];
	my $type = "a";
	my $mainObj = $obj;
	my $match = 1;
	my @objSeq = ($obj);
	my @objType = ("Array");
	my $objK;
	my $hadComma = 0;
	sub setValue {
		my ($target, $val) = @_;
		print "SET $val on $target ($type = $objK)\n";
		if ( $type eq "Object" && defined $objK ) {
			$target->{$objK} = $val;
			$objK = undef;
		}
		else {
			push @{$target}, $val;
		}
	}
	while ( $match ) {
		# Remove initial spaces
		$argStr =~ s/^\s+//;

		if ( $type eq "Object" && !defined($objK) ) {

			# String
			if ( $argStr =~ /^["']/ ) {
				print "STRINGK: $argStr\n";
				$objK = parseArgsStr(\$argStr);
				print "objK: $objK\n";
				if ( !defined $objK ) {
					print STDERR "Unable to parse string as an object key '$argStr'\n";
					return undef;
				}
				next;
			}
		}

		# A comma
		if ( $argStr =~ /^\,\s*/ ) {
			$hadComma = 1;
			print "COMMA: $argStr\n";
			$argStr =~ s/^\s*\,\s*//;
			next;
		}
		# A collon
		if ( $argStr =~ /^:\s*/ ) {
			$hadComma = 1;
			print "COLLON: $argStr\n";
			$argStr =~ s/\:\s*//;
			next;
		}
		# A comment
		if ( $argStr =~ /^\/\*.*?\*\// ) {
			$argStr =~ s/^\/\*.*?\*\///;
			next;
		}
		# Closing an array ?
		if ( $argStr =~ /^\]/ ) {
			print "CLOSE: $argStr\n";
			$obj = pop @objSeq;
			$type = pop @objType;
			$argStr =~ s/^\]//;
			next;
		}
		# Closing an object ?
		if ( $argStr =~ /^\}/ ) {
			print "OBJCLOSE: $argStr\n";
			$obj = pop @objSeq;
			$type = pop @objType;
			$argStr =~ s/^\}//;
			next;
		}


		# Number
		if ( $argStr =~ /^([0-9]+)/ ) {
			print "NUM: $argStr\n";
			setValue($obj, $1+0);
			$argStr =~ s/^([0-9]+|0x[a-f0-9]+)//;
			next;
		}
		# Hex number
		if ( $argStr =~ /^(0x[a-f0-9]+)/ ) {
			print "HEX: $argStr\n";
			setValue($obj, hex($1));
			$argStr =~ s/^([0-9]+|0x[a-f0-9]+)//;
			next;
		}
		# String
		if ( $argStr =~ /^["']/ ) {
			print "STRING: $argStr\n";
			my $str = parseArgsStr(\$argStr);
			if ( !defined $str ) {
				print STDERR "Unable to parse string on the arguments list '$argStr'\n";
				return undef;
			}
			setValue($obj, $str);
			next;
		}
		# Constant OR
		if ( $argStr =~ /^([A-Z_]+(\|[A-Z_]+)*)/ ) {
			print "CONST: $argStr\n";
			setValue($obj, new Strace::Flagset($1));
			$argStr =~ s/^([A-Z_]+(\|[A-Z_]+)*)//;
			next;
		}
		# Array start
		if ( $argStr =~ /^\[/ ) {
			print "OPEN: $argStr\n";
			push @objSeq, $obj;
			push @objType, $type;
			$type = "Array";
			$obj = new Strace::Args::Array();
			setValue($objSeq[-1], $obj);
			$argStr =~ s/^\[//;
			next;
		}
		# Object start
		if ( $argStr =~ /^\{/ ) {
			print "OBJOPEN: $argStr\n";
			push @objSeq, $obj;
			push @objType, $type;
			$obj = new Strace::Args::Object();
			$type = "Object";
			setValue($objSeq[-1], $obj);
			$objK = undef;
			$argStr =~ s/^\{//;
			next;
		}
		$match = 0;
	}

	if ( $argStr !~ /^\s*$/ ) {
		print STDERR "Error parsing argument string '$argStr': $@\n";
		return undef;
	}

	return $mainObj;
}

# Parse a string argument
sub parseArgsStr {
	my ($strRef) = @_;
	my $argStr = $$strRef;

	# Find the string delimiter char
	$argStr =~ /^(["'])/ || return undef;
	my $strChar = $1;
	for ( my $x = 1 ; $x < length($argStr) ; $x++ ) {
		my $char = substr($argStr,$x,1);
		# Is it a backslash? Ignore the next char, 'cos it's escaped
		if ( $char eq '\\' ) {
			$x++;
		}
		# The string delimiter char
		elsif ( $char eq $strChar ) {
			my $str = substr($argStr,1,$x-1);
			$str = unescapeStr($str);
			$$strRef = substr($argStr,$x+1);
			$$strRef =~ s/\s*\,\s*//;
			return $str;
		}
	}

	return undef;

}

# Unescape a string (FIXME)
sub unescapeStr {
	my ($str) = @_;
	$str =~ s/\\n/\n/g;
	$str =~ s/\\r/\r/g;
	$str =~ s/\\(.)/$1/g;
	return $str;
}


1;