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
#   jsonObject:  a JSON object to be converted to JSON data which will be used for the body.
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

use DuckingNinja::ServerManager;
use DuckingNinja::User;

our $gitdir = $INC[0]; # TODO: figure out a BETTER way to determine this.
our ($conf, $db);
sub conf { $conf->get(@_) }

# called immediately as the server starts.
sub start {

    # add $git_dir to @INC and load the required modules.
    unshift @INC, $gitdir, "$gitdir/evented-object", "$gitdir/evented-configuration";

    require EventedObject;
    require Evented::Configuration; 

    # load the configuration.
    $conf = Evented::Configuration->new(conffile => "$gitdir/etc/duckingninja.conf");
    
    # if ssl:path isn't set, set it.
    # it defaults to the git directory's ssl directory.
    if (!conf(['database', 'ssl'], 'path')) {
        $conf->{conf}{database}{ssl} = "$gitdir/ssl";
    }
    
    # set up the database.
    _init_database() or die "Database error: $@\n";
    
    
}

# connect to database.
sub _init_database {
    if (conf('database', 'format') ne 'mysql') {
        # Currently only mysql is supported.
        return;
    }
    
    # general database options.
    my $database_opts = sprintf(
        'database=%s;host=%s;port=%s;mysql_ssl=%d',
        conf('database', 'database'),
        conf('database', 'server'),
        conf('database', 'port'),
        conf('database', 'ssl')
    );
    
    # if SSL is enabled, set the required options.
    my $ssl_opts = q();
    if (conf('database', 'ssl')) {
        my $ssl   = ['database', 'ssl'];
        $ssl_opts = sprintf(
            'mysql_ssl_cipher=%s;mysql_ssl_ca_path=%s;mysql_ssl_ca_file=%s;
            mysql_ssl_client_key=%s;mysql_ssl_client_cert=%s;mysql_auto_reconnect=1',
            conf($ssl, 'cipher'),
            conf($ssl, 'path'),
            conf($ssl, 'ca'),
            conf($ssl, 'key'),
            conf($ssl, 'cert')
        );
    }
    
    # attempt to establish a connection.
    $db = DBI->connect(
        "DBI:mysql:$database_opts;$ssl_opts",
        conf('database', 'user'),
        conf('database', 'password')
    );
    
    return 1 if $db;
    return;
    
}

# returns a user based on a hash of post variables.
sub fetch_user_from_post {
    my %post = @_;
}


1
