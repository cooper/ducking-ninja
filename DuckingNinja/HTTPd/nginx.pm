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

our %_vars;

# handle a request from nginx.
# this is the main handler for the location / on the server.
sub handler {
    my $r = shift;

    # if this doesn't match, ignore it.
    my ($api_version, $page_name, $api_prefix);
    if ($r->uri =~ m/\/api\/(.+)\/(.+)$/) {
        $api_version = $1;
        $page_name   = $2;
    }
    
    # GET exception.
    if ($r->request_method eq 'GET' && defined $page_name &&
    $page_name ~~ @DuckingNinja::ServerManager::get_exceptions) {
        return handle_request($r, $api_version, $page_name, $api_prefix);
    }

    # otherwise we only accept POST requests.
    elsif ($r->request_method ne 'POST') {
        $r->send_http_header('text/plain');
        $r->print('This server does not server content of the requested type.');
        return &OK;
    }
    
    # call with POST variables if the request has a body.
    elsif ($r->request_method eq 'POST' &&
    $r->has_request_body(\&handle_post_variables)) {
        return handle_request($r, $api_version, $page_name, $api_prefix);
    }
    
    # if not, handle the request without POST variables.
    return handle_request($r, $api_version, $page_name, $api_prefix);
        
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
    #$r->variable('postVariables', \%args);
    %_vars = %args;
    
}

# handle a POST request.
sub handle_request {
    my ($r, $api_version, $page_name, $api_prefix) = @_;
    
    # by now hasPostVariables and postVariables are set if necessary to this request

    # currently only API version 2.0 is supported.
    return &HTTP_INTERNAL_SERVER_ERROR if $api_version != 2.0;
    $api_prefix = 2;
    
    # server manager does not handle this...
    if (!DuckingNinja::ServerManager::has_page($page_name, $api_prefix)) {
        return &HTTP_NOT_FOUND;
    }
    
    my %postVariables = %_vars;
    %_vars            = ();
    #my $variables     = $r->variable('postVariables');
    #if ($variables && ref $variables eq 'HASH') {
    #    %postVariables = %$variables;
    #    $r->variable(postVariables => undef);
    #}

    # apply a few other artificial variables.        
    $postVariables{_clientIP} = $r->remote_addr;
    $postVariables{_recvTime} = time;
    $postVariables{_pageName} = $page_name;

    # call it the handler.
    my $return = DuckingNinja::ServerManager::page_for(
        $page_name, $api_prefix, %postVariables
    ) or return &HTTP_NOT_FOUND;
    
    # must return a hash reference.
    return &HTTP_INTERNAL_SERVER_ERROR if ref $return ne 'HASH';
    my %return = %$return;

    # send Content-Type. defaults to text/plain.
    $r->send_http_header($return{contentType});
    
    # only send header if so requested.
    return _status($return{statusCode}) if $r->header_only;


    # BODY

    # if a body is specified, print it.
    if (defined $return{body} && length $return{body}) {
        $r->print($return{body});
    }

    # status defaults to HTTP 200 OK.
    return _status($return{statusCode});

}

# convert a status code to an nginx code.
sub _status {
    my $code = shift;
    return -5 if !defined $code;
    return  0 if $code eq '_CONST_OK_';         # OK.
    return -5 if $code eq '_CONST_DECLINED_';   # DECLINED.
    return $code if int $code == $code;         # HTTP status code.
    return -5;                                  # fallback.
}

1
