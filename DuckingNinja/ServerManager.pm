# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file manages and handles requests to the server.
package DuckingNinja::ServerManager;

use warnings;
use strict;
use utf8;

use nginx;
use JSON;

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
    my %return = $code->(%variables) || ();
    
    # default content-type to 'text/plain'
    $return{contentType} ||= 'text/plain';
    
    # default return code to success.
    $return{statusCode} = &OK if !exists $return{statusCode};
    
    # convert jsonObject to body.
    if (defined $return{jsonObject}) {
        $return{body} = JSON->new->allow_nonref->encode($return{jsonObject});
    }

    return %return;
}

# request to /servers, the server load balancer.
sub http_2_servers {
    my %post = @_;
    my %return;
    
    $return{jsonObject} = ['someserver.asia', 'otherserver.net'];
    
    return %return;
}

1
