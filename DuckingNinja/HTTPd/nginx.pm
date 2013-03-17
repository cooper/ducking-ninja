# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file contains the DuckingNinja server implementation for the nginx HTTPd.
package DuckingNinja::HTTPd::nginx;

use warnings;
use strict;
use utf8;

use nginx;
use URI;
use URI::Encode qw(uri_encode uri_decode);
use DuckingNinja;

DuckingNinja::start();

# handle a request from nginx.
# this is the main handler for the location / on the server.
sub handler {
    my $r = shift;

    # we only accept POST requests.
    if ($r->request_method ne 'POST') {
        $r->send_http_header('text/plain');
        $r->print('This server does not server content of the requested type.');
        return &OK;
    }
    
    # call with POST variables if the request has a body.
    if ($r->has_request_body(\&handle_post_variables)) {
        return handle_request($r);
    }
    
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
    return &OK;
    
}

# handle a POST request.
sub handle_request {
    my $r = shift;
    
    # by now hasPostVariables and postVariables are set if necessary to this request
    
    # if this doesn't match, ignore it.
    my ($api_version, $page_name, $api_prefix);
    if ($r->uri !~ m/\/api\/(.+)\/(.+)$/) {
        $api_version = $1;
        $page_name   = $2;
    }

    # currently only API version 2.0 is supported.
    return &HTTP_NOT_FOUND if $api_version != 2.0;
    $api_prefix = 2;
    
    # server manager does not handle this...
    if (!DuckingNinja::ServerManager::has_page($page_name, $api_prefix)) {
        return &HTTP_NOT_FOUND;
    }
    
    my %postVariables = $r->variable('postVariables') ? %{$r->variable('postVariables')} : ();

    # apply a few other artificial variables.        
    $postVariables{_clientIP} = $r->remote_addr;
    $postVariables{_recvTime} = time;

    # call it the handler.
    my %return = DuckingNinja::ServerManager::page_for(
        $page_name, $api_prefix, %postVariables
    ) or return &HTTP_NOT_FOUND;

    # send Content-Type. defaults to text/plain.
    $r->send_http_header($return{contentType});
    
    # TODO: only send header if only header was requested.

    # if a body is specified, print it.
    if (defined $return{body} && length $return{body}) {
        $r->print($return{body});
    }

    # status defaults to HTTP 200 OK.
    return $return{statusCode};

}

1
