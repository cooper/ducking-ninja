# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file contains the DuckingNinja server implementation for the nginx HTTPd.
package DuckingNinja::HTTPd::nginx;

use warnings;
use strict;
use utf8;

use nginx;
use DuckingNinja;

DuckingNinja::start();

# imports with the git directory.
sub import {
    my ($class, $dir) = @_;
    $DuckingNinja::gitdir = $dir;
}

# handle a request from nginx.
# this is the main handler for the location / on the server.
sub handler {
    my $r = shift;

    # we only accept POST requests.
    return DECLINED if $r->request_method ne 'POST';
    
    # call with POST variables if the request has a body.
    return OK if $r->has_request_body(\&handle_post_variables);
    
    # if not, handle the request without POST variables.
    return handle_request($r);
        
}

# handle a request with POST variables.
sub handle_post_variables {
    my $r = shift;
    
    # use a fake URI to determine the POST variables.
    my %args = URI->new("http://google.com/search?".$r->request_body)->query_form;

    # decode URI percent formats.
    $args{$_} = uri_decode($args{$_}) foreach keys %args;

    # set the arguments to the decoded POST variables.
    $r->variable('hasPostVariables', 1);
    $r->variable('postVariables', \%args);
    
    # finish handling the request.
    return handle_request($r);
    
}

# handle a POST request.
sub handle_request {
    sub $r = shift;
    
    # by now hasPostVariables and postVariables are set if necessary to this request
    
    # if this doesn't match, ignore it.
    my ($api_version, $page_name, $api_prefix);
    if ($r->uri !~ m/\/api\/(.+)\/(.+)$/) {
        $api_version = $1;
        $page_name   = $2;
    }

    # currently only API version 2.0 is supported.
    return HTTP_NOT_FOUND if $api_version != 2.0;
    $api_prefix = 2;
    
    # if the ServerManager has a method for this, use it.
    if (my $code = Numingle::ServerManager->can("http_${api_prefix}_${page_name}")) {
        my %postVariables = $r->variable('postVariables') ? %{$r->variable('postVariables')} : ();

        # apply a few other artificial variables.        
        $args{_clientIP} = $r->remote_addr;
        $args{_recvTime} = time;

        # call it.
        $code->(%postVariables);
        # TODO: do stuff here.
        return OK;
        
    }
    
    # otherwise, we will say it's not found.
    return HTTP_NOT_FOUND;
    
}

1
