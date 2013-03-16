# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file should be loaded by the server module.
# 
# Artificial post variables set by the HTTPd:
#   
#   _clientIP: string IP address of the requesting client.
#   _recvTime: UNIX timestamp at which the request was received.
# 
# Values returned by HTTP page handlers in the ServerManager:
#   
#   contentType: a MIME type for the content of the reply's body; default: text/plain.
#   body:        the content body in the format of contentType or none if there is no body.
#   statusCode:  an nginx constant HTTP status reply code; default HTTP 200 OK.
#
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
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
