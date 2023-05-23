# idlekill

A program to kill idle interactive logins on Linux.

The way I use it:

Copy it to /root/bin/idlekill.pl and make it executable:

```sh
mkdir -p /root/bin
chmod +rx,go-w /root/bin/idlekill.pl
```

Then add a root cron job with `crontab -e`:

```
* * * * * bin/idlekill.pl -a -i 3600 -s 9
```

That'll kick out everyone, including direct root logins, who are logged into an interactive shell after 1 hour of idle time.

It needs Perl, CPAN module Sys::Utmp, and the pkill executable, which you can install like this:

```sh
apt install libsys-utmp-perl procps  # Debian & Ubuntu
yum install perl-Sys-Utmp procps-ng  # RHEL 7 family
dnf install perl-Sys-Utmp procps-ng  # RHEL 8+ family
```

Its built-in usage help shows the options and gives more examples:

```plain
# bin/idlekill.pl -h
idlekill - selectively kill processes of idle login sessions

Usage:
bin/idlekill.pl [-anx] [-i seconds] [-s signal] [user user2 ...]

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

bin/idlekill.pl -a -i 3600
    prints list of all users idle one hour or more

bin/idlekill.pl -i 86400 -s 9 -n fred sally
    forcibly kills processes started from any login session by fred and
    sally, which have been idle a day or more

bin/idlekill.pl -i 600 -s TERM -x nifty
    politely terminates processes started from any login session by any
    user except root and nifty, which have been idle 10 minutes or more

bin/idlekill.pl -I 60 -a -n 0
    prints list of all root logins with no terminal activity during the
    last minute, even for alternate usernames of UID 0 (root2, toor, etc.)

This tool is intended primarily for unattended use, and thus focuses on
selecting login sessions by non-ephemeral indentifiers such as username
and UID number, rather than a particular terminal, which is often not
predictable. It is more suitable for running from cron than combinations
of w/top/ps/kill.
```
