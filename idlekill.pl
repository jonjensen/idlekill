#!/usr/bin/perl

# idlekill
# by Jon Jensen <jon@endpointdev.com>
# Unlicense (public domain)
#
# 2003-07-02 created
# 2015-10-16 allow -s 0 to be passed in for testing; suppress header when no sessions to show
# 2015-10-19 switch from skill to better-supported pkill for RHEL 7 compatibility
# 2023-05-23 require (slightly) newer Perl, note common dependency package names
#
# To install the needed dependencies:
# apt install libsys-utmp-perl procps  # Debian & Ubuntu
# yum install perl-Sys-Utmp procps-ng  # RHEL 7 family
# dnf install perl-Sys-Utmp procps-ng  # RHEL 8+ family

use 5.008;
use strict;
use warnings;
no warnings 'void', 'uninitialized';
use Sys::Utmp;
use Getopt::Std;


sub usage {
	print <<EOF;
idlekill - selectively kill processes of idle login sessions

Usage:
$0 [-anx] [-i seconds] [-s signal] [user user2 ...]

    -x  exclude rather than include list of users
    -i  seconds of idle time required for session to match
    -I  seconds of complete terminal inactivity (not just keystrokes,
        but output too) required for session to match
    -s  signal number or name to send to processes that match
        (see "man 7 signal" for complete list)
    -n  match also on numeric UID equivalents of usernames
        (in case multiple usernames have same UID)
    -a  allow root (UID 0) user to match

Examples:

$0 -a -i 3600
    prints list of all users idle one hour or more

$0 -i 86400 -s 9 -n fred sally
    forcibly kills processes started from any login session by fred and
    sally, which have been idle a day or more

$0 -i 600 -s TERM -x nifty
    politely terminates processes started from any login session by any
    user except root and nifty, which have been idle 10 minutes or more

$0 -I 60 -a -n 0
    prints list of all root logins with no terminal activity during the
    last minute, even for alternate usernames of UID 0 (root2, toor, etc.)

This tool is intended primarily for unattended use, and thus focuses on
selecting login sessions by non-ephemeral indentifiers such as username
and UID number, rather than a particular terminal, which is often not
predictable. It is more suitable for running from cron than combinations
of w/top/ps/kill.
EOF
	return;
}


my %opt;
getopts('?ahi:I:ns:x', \%opt);

usage(), exit if $opt{'?'} or $opt{h};

my %users;

for (@ARGV) {
	$users{$_} = 1;
	my $uid = getpwnam($_);
	$users{$uid} = 1 if length($uid);
}

my $utmp = Sys::Utmp->new;
my $time = time;
my $format = "%-16s%-12s%-10s%-10s";
my $header = sprintf $format . "%s\n", qw( user tty idle inactive action );
my $printed_header;

while (my $utent = $utmp->getutent) {
	next unless $utent->user_process;
	my $user = $utent->ut_user or next;
	my $uid;
	if ($user !~ /\D/a) {
		$uid = $user;
		$user = getpwuid($uid);
	}
	else {
		$uid = getpwnam($user);
	}
	next if ! $opt{a} and
		(
			$user eq 'root'
			or (length($uid) and $uid == 0)
		);
	if (%users) {
		my $ok = $users{$user};
		$ok ||= $users{$uid} if $opt{n};
		$ok = ! $ok if $opt{x};
		next unless $ok;
	}
	my $tty = $utent->ut_line;
	unless ($tty) {
		warn "No tty for user $user; skipping\n";
		next;
	}
	my ($idle, $inactive) = map { $time - $_ } (stat("/dev/$tty"))[8, 9];
	$opt{i} and $idle < $opt{i} and next;
	$opt{I} and $inactive < $opt{I} and next;
	$printed_header or $printed_header = 1, print($header);
	printf $format, $user, $tty, $idle, $inactive;
	print("-\n"), next unless defined($opt{s}) and length($opt{s});
	my $ret = system('pkill', "-$opt{s}", '-u', $user, '-t', $tty);
	if ($ret == 0) {
		print "signaled\n";
	}
	else {
		print "error\n";
		warn "Error returned from pkill: $!\n";
	}
}

$utmp->endutent;

exit;
