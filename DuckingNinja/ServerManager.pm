# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file manages and handles requests to the server.
package DuckingNinja::ServerManager;

use warnings;
use strict;
use utf8;

use DuckingNinja::HTTPConstants;
use JSON;
use LWP::Simple 'get';

# returns true if the server manager has a handler for the page.
sub has_page {
    my ($page_name, $api_prefix) = @_;
    return __PACKAGE__->can("http_${api_prefix}_${page_name}")
}

# returns the return value of a page's handler.
# returns undef if there is no handler for the page.
sub page_for {
    my ($page_name, $api_prefix, %variables) = @_;
    my $code = has_page($page_name, $api_prefix);
    return undef if !$code;
    return undef if ref $code ne 'CODE';
    
    # call the handler.
    my $return = $code->(%variables) || (); return if ref $return ne 'HASH';
    my %return = %$return;
    
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
    DuckingNinja::select_hash_each('SELECT * FROM {servers} WHERE name = \'last\'', sub {
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
sub http_2_status {
    my %post = @_;
    my %return;
    my %json = {};
    
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
    # TODO: update highest user count.
    # TODO: update client server list.
    # TODO: trends.
    # TODO: stats: maxCount, totalConvos, longestConvo, averageConvo.
    $json{popular} = []; # XXX
    $json{clientServers} = [DuckingNinja::conf('server', 'name')]; # XXX
    
    # chat servers.
    $json{servers} = $status{servers} if ref $status{servers} eq 'ARRAY';
    
    # user count.
    $json{count} = $status{counts};
    
    # this server's name.
    $json{server} = DuckingNinja::conf('server', 'name');
    
    $return{jsonObject} = \%json;
    return \%return;
}

1
