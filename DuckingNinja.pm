# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file
package DuckingNinja;

use warnings;
use strict;
use utf8;

use lib 'evented-object';
use EventedObject;
use lib 'evented-configuration';
use Evented::Configuration;

use DuckingNinja::ServerManager;
use DuckingNinja::User;

our $gitdir; # set by HTTPd or host.
our $conf;
sub conf { $conf->get(@_) }

# called immediately as the server starts.
sub start {
    $gitdir = shift;
    
    # load the configuration.
    $conf = Evented::Configuration->new(conffile => "$gitdir/etc/duckingninja.conf");
}

1
