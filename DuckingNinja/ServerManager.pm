# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file manages and handles requests to the server.
package DuckingNinja::ServerManager;

use warnings;
use strict;
use utf8;

use DuckingNinja::HTTPConstants;
use JSON;

our @get_exceptions = qw(servers); # page names that allow GET requests.
our @ban_exceptions = qw(servers); # page names that are exempt from bans.
our @dev_exceptions = qw(servers welcome); # page names that do not require device
                                           # identifiers and license keys.

# returns true if the server manager has a handler for the page.
sub has_page {
    my ($page_name, $api_prefix) = @_;
    return __PACKAGE__->can("http_${api_prefix}_${page_name}")
}

# returns the return value of a page's handler.
# returns undef if there is no handler for the page.
sub page_for {
    my ($page_name, $api_prefix, %post) = @_;
    my $code = has_page($page_name, $api_prefix);
    return undef if !$code;
    return undef if ref $code ne 'CODE';
    
    my %return;
    
    # if we're not connected to mySQL, send an error.
    if (!DuckingNinja::database_connected()) {
        my $email = DuckingNinja::conf('service', 'support_email');
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => 'Please report this server database error to '.$email
        };
        return \%return;
    }

    # mySQL is connected.
    else {

        # failed to fetch user...
        my $user = DuckingNinja::fetch_user_from_post(%post); my %user = %$user;
        if (!$user{accepted}) {
        
            # user is banned.
            if ($user{banned}) {
                $return{jsonObject} = {
                    accepted => JSON::false,
                    error    => $user{banReason}
                };
            }
            
            # user failed registration test.
            elsif ($user{notRegistered}) {
                $return{jsonObject} = {
                    accepted => JSON::false,
                    error    => $user{notRegisteredError}
                };
            }
            
            # other error.
            else {
                $return{jsonObject} = {
                    accepted => JSON::false,
                    error    => 'Unknown error.'
                };
            }
            
        }

        else {
        
            # call the handler.
            my $return = $code->(%post) || (); return if ref $return ne 'HASH';
            %return = %$return;
            
        }
        
    }
    
    # default content-type to 'text/plain'
    $return{contentType} ||= 'text/plain';
    
    # default return code to success.
    $return{statusCode} = &OK if !exists $return{statusCode};
    
    # convert jsonObject to body.
    if (!defined $return{body} && defined $return{jsonObject}) {
        $return{body} = JSON->new->allow_nonref->encode($return{jsonObject});
    }

    # return as a hash reference.
    return \%return;
}

################
### HANDLERS ###
################

# request to /servers, the server load balancer.
sub http_2_servers {
    my %post = @_;
    my %return;
    
    # fetch the last-used index.
    my $last_index;
    DuckingNinja::select_hash_each('SELECT * FROM {servers} WHERE `name` = \'last\'', sub {
        my %row     = @_;
        $last_index = $row{index};
    });
    
    # couldn't fetch the last-used index.
    if (!defined $last_index) {
        $return{statusCode} = &HTTP_INTERNAL_SERVER_ERROR;
        $return{body}       = 'could not determine server order';
        return \%return;
    }
    
    # select the servers.
    my @servers;
    DuckingNinja::select_hash_each('SELECT * FROM {servers}', sub {
        my %row = @_;
        $servers[$row{index}] = $row{name};
    });

    # try using the next in line server.
    my $index_used;
    if (defined $servers[$last_index + 1]) {
        $index_used = $last_index + 1;
    }
    
    # try using the first server instead.
    elsif (defined $servers[0]) {
        $index_used = 0;
    }
    
    # give up.
    else {
        $return{statusCode} = &HTTP_INTERNAL_SERVER_ERROR;
        return \%return;
    }
    
    my $success = DuckingNinja::db_do(
        'UPDATE {servers} SET `index` = ? WHERE `name` = ?',
        $index_used,
        'last'
    ) or die $DBI::errstr."\n";
    
    # failed to set.
    if (!$success) {
        $return{statusCode} = &HTTP_INTERNAL_SERVER_ERROR;
        $return{body}       = 'failed to set current server';
        return \%return;
    }
    
    
    # success.
    
    # use the server in index_used and set the last server to that value.
    $return{jsonObject} = [$servers[$index_used]];
    
    return \%return;
    
}

# request to /welcome, the main status indicator.
sub http_2_welcome {
    my %post = @_;
    my (%json, %return);
    
    
    #-- bans and registration stuff --#
    
    
    # fetch the user manually.
    my $user = DuckingNinja::fetch_user_from_post(%post); my %user = %$user;
    
    # if the user is banned, give up here.
    if ($user{banned}) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => $user{banReason}
        };
        return \%return;
    }
    
    # if there is no registration key and the user was not accepted, give up here.
    if (!$post{registrationKey} && $user{notRegistered) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => $user{notRegisteredError}
        };
        return \%return;
    }
    
    
    
    #-- omegle status stuff --#
    
    
    
    # update status if necessary.
    # if it fails, send an error to the client.
    my $status = DuckingNinja::server_status();
    if (!$status) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => 'The service is currently unavailable.'
        };
        return \%return;
    }
    
    # TODO: check if the device or IP is banned.
    # TODO: update client server list.


    
    
    #-- trend stuff --#
    
    
    
    $json{popular} = []; # XXX
    # TODO: trends.



    #-- server stuff --#
    
    

    # fetch the client servers. currently, these are in no absolute order.
    my @client_servers;
    DuckingNinja::select_hash_each('SELECT `name` FROM {servers} ORDER BY `index`', sub {
        my %row = @_;
        return if $row{name} eq 'last';
        push @client_servers, $row{name};
    });
    $json{clientServers} = \@client_servers;
    
    # chat servers.
    $json{servers} = $status->{servers} if ref $status->{servers} eq 'ARRAY';
    
    # this server's name.
    $json{server} = DuckingNinja::conf('server', 'name');
    
    
    
    #-- statistic stuff --#
    
    
    
    # peak user count.
    my $user_peak = 0;
    DuckingNinja::select_hash_each(
    'SELECT peak_user_count FROM {statistics} ORDER BY peak_user_count_num DESC LIMIT 1', sub {
        my %row = @_;
        $user_peak = $row{peak_user_count};
    });
    $json{maxCount} = $user_peak + 0 || 0;
    
    # current user count.
    $json{count} = $status->{count};
    


    #-- success --#



    $return{jsonObject} = \%json;
    $return{accepted}   = JSON::true;
    return \%return;
}

1
