# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file represents a DuckingNinja user.
package DuckingNinja::IRC;

use warnings;
use strict;
use IO::Socket::IP;

sub post {
    my $r = shift;
    my @final;
    foreach my $line (@_) {
        if (ref $line eq 'ARRAY') {
            my $key   = $line->[0];
            my $value = $line->[1] // 'undefined';
            push @final, "\2$key\2: $value";
            next;
        }
        push @final, $line;
    }
    return irc_message($r, @final);
}

sub irc_message {
    return if !DuckingNinja::conf('irc', 'enabled');
    my ($r, @lines) = @_;
    
    my $sock = IO::Socket::IP->new(
        PeerHost => (split /:/, DuckingNinja::conf('irc', 'address'))[0],
        PeerPort => (split /:/, DuckingNinja::conf('irc', 'address'))[1] || 6667,
        Type     => SOCK_STREAM
    ) or return;
    
    my $chan = DuckingNinja::conf('irc', 'channel');
    my $nick = 'duck-'.substr(time, -3);
    print $sock "NICK $nick\r\n";
    print $sock "USER ninja * * :DuckingNina\r\n";

    sleep 3;
    print $sock "JOIN $chan\r\n";
    print $sock "PRIVMSG $chan :$_\r\n" foreach @lines;
    print $sock "QUIT\r\n";
}

1
