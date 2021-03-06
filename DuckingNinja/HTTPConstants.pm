# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file contants HTTP status constants.
package DuckingNinja::HTTPConstants;

use 5.006001;
use strict;
use warnings;

require Exporter;
use parent 'Exporter';

our @EXPORT = qw(

    OK
    DECLINED

    HTTP_OK
    HTTP_CREATED
    HTTP_NO_CONTENT
    HTTP_PARTIAL_CONTENT

    HTTP_MOVED_PERMANENTLY
    HTTP_MOVED_TEMPORARILY
    HTTP_REDIRECT
    HTTP_NOT_MODIFIED

    HTTP_BAD_REQUEST
    HTTP_UNAUTHORIZED
    HTTP_PAYMENT_REQUIRED
    HTTP_FORBIDDEN
    HTTP_NOT_FOUND
    HTTP_NOT_ALLOWED
    HTTP_NOT_ACCEPTABLE
    HTTP_REQUEST_TIME_OUT
    HTTP_CONFLICT
    HTTP_GONE
    HTTP_LENGTH_REQUIRED
    HTTP_REQUEST_ENTITY_TOO_LARGE
    HTTP_REQUEST_URI_TOO_LARGE
    HTTP_UNSUPPORTED_MEDIA_TYPE
    HTTP_RANGE_NOT_SATISFIABLE

    HTTP_INTERNAL_SERVER_ERROR
    HTTP_SERVER_ERROR
    HTTP_NOT_IMPLEMENTED
    HTTP_BAD_GATEWAY
    HTTP_SERVICE_UNAVAILABLE
    HTTP_GATEWAY_TIME_OUT
    HTTP_INSUFFICIENT_STORAGE
    
);

# I don't like use constant.

use constant OK                             => '_CONST_OK_';
use constant DECLINED                       => '_CONST_DECLINED_';

use constant HTTP_OK                        => 200;
use constant HTTP_CREATED                   => 201;
use constant HTTP_NO_CONTENT                => 204;
use constant HTTP_PARTIAL_CONTENT           => 206;

use constant HTTP_MOVED_PERMANENTLY         => 301;
use constant HTTP_MOVED_TEMPORARILY         => 302;
use constant HTTP_REDIRECT                  => 302;
use constant HTTP_NOT_MODIFIED              => 304;

use constant HTTP_BAD_REQUEST               => 400;
use constant HTTP_UNAUTHORIZED              => 401;
use constant HTTP_PAYMENT_REQUIRED          => 402;
use constant HTTP_FORBIDDEN                 => 403;
use constant HTTP_NOT_FOUND                 => 404;
use constant HTTP_NOT_ALLOWED               => 405;
use constant HTTP_NOT_ACCEPTABLE            => 406;
use constant HTTP_REQUEST_TIME_OUT          => 408;
use constant HTTP_CONFLICT                  => 409;
use constant HTTP_GONE                      => 410;
use constant HTTP_LENGTH_REQUIRED           => 411;
use constant HTTP_REQUEST_ENTITY_TOO_LARGE  => 413;
use constant HTTP_REQUEST_URI_TOO_LARGE     => 414;
use constant HTTP_UNSUPPORTED_MEDIA_TYPE    => 415;
use constant HTTP_RANGE_NOT_SATISFIABLE     => 416;

use constant HTTP_INTERNAL_SERVER_ERROR     => 500;
use constant HTTP_SERVER_ERROR              => 500;
use constant HTTP_NOT_IMPLEMENTED           => 501;
use constant HTTP_BAD_GATEWAY               => 502;
use constant HTTP_SERVICE_UNAVAILABLE       => 503;
use constant HTTP_GATEWAY_TIME_OUT          => 504;
use constant HTTP_INSUFFICIENT_STORAGE      => 507;

1
