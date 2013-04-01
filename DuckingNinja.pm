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

use DBI;
use JSON;
use LWP::Simple 'get';

use DuckingNinja::ServerManager;
use DuckingNinja::User;

our %GV;
our $gitdir = $INC[0]; # TODO: figure out a BETTER way to determine this.
our ($conf, $db, $dbh);
sub conf { $conf->get(@_) }

# called immediately as the server starts.
sub start {

    # add add required directories to @INC.
    unshift @INC, (
    
        # EventedObject.
        "$gitdir/evented-object",
    
        # EventedConfiguration.
        "$gitdir/evented-configuration",
        
        # private/
        "$gitdir/private/lib"
        
    );

    # require EventedObject, Evented::Configuration, and Private.
    require EventedObject;
    require Evented::Configuration; 
    require DuckingNinja::Private;


    # set up the configuration.
    _init_config();

    # set up the database.
    _init_database() or die "Database error: $DBI::errstr\n";
    
}

##################################
### CONFIGURATION AND DATABASE ###
##################################

# parse the configuration.
sub _init_config {

    # load the configuration.
    $conf = Evented::Configuration->new(conffile => "$gitdir/etc/duckingninja.conf");
    $conf->parse_config() or die "could not parse configuration: $$conf{conffile}\n";
    
    # if ssl:path isn't set, set it.
    # it defaults to the git directory's ssl directory.
    if (!conf(['database', 'ssl'], 'path')) {
        $conf->{conf}{database}{ssl}{path} = "$gitdir/private/ssl";
    }
    
    return 1;
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
       (conf('database', 'ssl') || 0)
    );
    
    # if SSL is enabled, set the required options.
    my $ssl_opts = q();
    if (conf('database', 'ssl')) {
        my $ssl   = ['database', 'ssl'];
        $ssl_opts = sprintf(
            '%smysql_ssl_ca_path=%s;mysql_ssl_ca_file=%s;
            mysql_ssl_client_key=%s;mysql_ssl_client_cert=%s;mysql_auto_reconnect=1',
            ('mysql_ssl_cipher='.conf($ssl, 'cipher').';' || ''),
            conf($ssl, 'path'),
            conf($ssl, 'ca'),
            conf($ssl, 'key'),
            conf($ssl, 'cert')
        );
    }
    
    # attempt to establish a connection.
    $db = $dbh = DBI->connect(
        "DBI:mysql:$database_opts;$ssl_opts",
        conf('database', 'user'),
        conf('database', 'password')
    );
    
    return 1 if $db;
    return;
    
}

# connect to database if not connected.
sub database_connected {
    if (!$db->ping) {
        return _init_database();
    }
    return 1;
}

# run a do().
sub db_do {
    my ($query, @query_args) = @_;
    return $dbh->do(_db_replace($query), undef, @query_args);
}

# selects a hash (query, query_args, code)
sub select_hash_each {
    my ($query, @query_args) = @_;
    my $callback = pop @query_args;
    return unless ref $callback eq 'CODE';
    
    # prepare the query.
    my $sth = $dbh->prepare(_db_replace($query));
    
    # execute the query with the supplied arguments.
    $sth->execute(@query_args) or return;
    
    # execute the callback for each row.
    while (my $row = $sth->fetchrow_hashref) {
        $callback->(%$row);
    }
    
    # finish the statement.
    $sth->finish();
    
}

# selects and returns a single value.
sub select_single_value {
    my ($query, @query_args) = @_;
    
    # prepare the query.
    my $sth = $dbh->prepare(_db_replace($query));
    
    # execute the query with the supplied arguments.
    $sth->execute(@query_args) or return;
    
    # use the first value found.
    my $value; my $row = $sth->fetchrow_hashref;
    foreach my $key (keys %$row) {
        $value = $row->{$key};
        last;
    }
    
    # finish the statement.
    $sth->finish();
    
    return $value;
}

# replace {table} with the table name from configuration.
sub _db_replace {
    my $query = shift;

    while ($query =~ m/\{(\w+)\}/) {
        my $table_name = conf(['database', 'tables'], $1);
        $table_name  ||= $1;
        $query =~ s/\{$1\}/$table_name/;
    }
    
    return $query;
}

#########################
### SERVER OPERATIONS ###
#########################


# update server status.
sub server_status {

    # if it has not been five minutes since we updated, use the cached value.
    if (
        $GV{server_status}               &&
        ref $GV{server_status} eq 'HASH' &&
        (time - $GV{server_status}{update_time}) <= 300
    ) {
        return $GV{server_status};
    }
    
    # otherwise, we need to request it...
    my $data   = get('http://omegle.com/status') or return;
    my $status = JSON->new->decode($data) or return;
    
    
    # fetch user count peak.
    my ($peak_user_count, $peak_user_count_num) = @_;
    select_hash_each('
        SELECT
            `count`,
            `num`
        FROM {statistics}
        ORDER BY `num` DESC
        LIMIT 1', sub {
        my %row = @_;
        $peak_user_count     = $row{count};
        $peak_user_count_num = $row{num};
    });
    
    # default to zero.
    $peak_user_count     ||= 0;
    $peak_user_count_num ||= 0;
    
    # if the user count if higher than the highest, update that statistic.
    if ($status->{count} >= $peak_user_count) {
        db_do(
            'INSERT INTO {statistics} (
                `count`,
                `time`,
                `num`
            ) VALUES (?, ?, ?)',
            $status->{count},
            time,
            $peak_user_count_num + 1
        );
    }
    
    # success.
    $status->{update_time} = time;
    $GV{server_status}     = $status;
    
    return $status;
}

######################
### MANAGING USERS ###
######################

# returns a user based on a hash of post variables.
sub fetch_user_from_post {
    my %post      = @_; my %return;
    my $client_ip = $post{_clientIP};
    my $page_name = $post{_pageName};
    

    
    # query for registration.
    my %reg;
    select_hash_each('
    SELECT * FROM `registry`
     WHERE `license_key`             = ?
       AND `unique_device_id`        = ?
       AND `unique_global_device_id` = ?',
    
    $post{licenseKey}                   || '',
    $post{uniqueDeviceIdentifier}       || '',
    $post{uniqueGlobalDeviceIdentifier} || '',
        
    sub {
        %reg = @_;
    });
    
    # no match was found.
    if (!$reg{license_key}) {
        $return{accepted}           = 0 unless $page_name ~~ @DuckingNinja::ServerManager::dev_exceptions;
        $return{notRegistered}      = 1;
        $return{notRegisteredError} = 'Invalid product license key.';
    }
        
    
        
    # query for a ban.
    my %ban;
    select_hash_each('
    SELECT * FROM `bans`
     WHERE `license_key`             = ?
        OR `unique_device_id`        = ?
        OR `unique_global_device_id` = ?
        OR `ip`                      = ?',
        
    $post{licenseKey},
    $post{uniqueDeviceIdentifier},
    $post{uniqueGlobalDeviceIdentifier},
    $client_ip,
        
    sub {
        %ban = @_;
    });
    
    # a ban was found.
    if ($ban{banned}) {
        $return{accepted}  = 0 unless $page_name ~~ @DuckingNinja::ServerManager::ban_exceptions;
        $return{banned}    = 1;
        $return{banReason} = $ban{reason} || 'The server is not currently accepting requests';
    }
    
    
    $return{accepted} = 1 unless exists $return{accepted};
    return \%return;
}

#######################
### MANAGING GROUPS ###
#######################

# creates a list of trend group hashes.
sub trend_groups {
    my @groups;
    select_hash_each('SELECT * FROM {groups}', sub {
        my %row = @_;
        
        # fetch group information.
        my %group = (
            group           => $row{name},
            popularity      => $row{popularity},
            display         => $row{display_title},
            subdisplay      => $row{display_subtitle},
            borderColor     => $row{style_border_color},
            backgroundColor => $row{style_background_color},
            imageURL        => $row{style_background_image},
            fontSize        => $row{style_font_size},
            textColor       => $row{style_text_color}
        );
        
        # remove omitted values.
        foreach my $key (keys %group) {
            delete $group{$key} if !defined $group{$key} || !length $group{$key};
        }
        
        # add the group.
        push @groups, \%group;
        
    });
    
    # return groups as an array reference for JSON encoding.
    return \@groups;
    
}

1
