# ducking-ninja: A flexible, secure, synchronized statistic server
# Copyright (c) 2013, Mitchell Cooper
# This file manages and handles requests to the server.
package DuckingNinja::ServerManager;

use warnings;
use strict;
use utf8;
use feature 'switch';

use DuckingNinja::HTTPConstants;
use JSON;

sub error ($);

our @get_exceptions = qw(servers); # page names that allow GET requests.
our @ban_exceptions = qw(servers); # page names that are exempt from bans.
our @dev_exceptions = qw(servers welcome); # page names that do not require device
                                           # identifiers and license keys.
our @all_exceptions = qw(eula panel);            

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
                    error    => $user{notRegisteredError},
                    pleaseRegisterAgain => JSON::true
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

        # fetched user successfully.
        else {
        
            # call the handler.
            my $return = $code->(%post) || ();
            
            # success.
            if (ref $return eq 'HASH') {
                %return = %$return;
            }
            
            # error.
            elsif (ref $return eq 'SCALAR') {
                $return{jsonObject} = {
                    accepted => JSON::false,
                    error    => $$return
                };
            }
            
            # unknown type.
            else {
                $return{jsonObject} = {
                    accepted => JSON::false,
                    error    => "Error $return"
                };
            }
            
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

    # convert HTML::Template to body.
    if (!defined $return{body} && defined $return{template}) {
        $return{body} = $return{template}->output();
        $return{contentType} = 'text/html';
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
    DuckingNinja::select_hash_each('SELECT * FROM {servers}', sub {
        my %row = @_;
        return if $row{name} eq 'last';
        $DuckingNinja::servers[$row{index}] = [ $row{name}, $row{enabled} ];
    });



##### while (!$server_passed_ping)
    my $index_used = DuckingNinja::choose_server($last_index);
    
    my $success = DuckingNinja::db_do(
        'UPDATE {servers} SET `index` = ? WHERE `name` = ?',
        $index_used,
        'last'
    );
    return error "Failed to set current server index: $err" if $err;
    
    # success.
    
    # use the server in index_used and set the last server to that value.
    $return{jsonObject} = [$DuckingNinja::servers[$index_used][0]];
    
    return \%return;
    
}

# request to /welcome, the main status indicator.
# TODO: systemName and systemVersion are now sent as well.
sub http_2_welcome {
    my %post = @_;
    my (%json, %return);
    
    
    #-- ban stuff --#
    
    
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
    
    
    
    #-- omegle status stuff --#
    
    
    
    # update status if necessary.
    # if it fails, send an error to the client.
    my $status = DuckingNinja::server_status();
    if (!$status) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => 'The chat service is currently unavailable.'
        };
        return \%return;
    }
    
    
    
    #-- registration stuff --#
    
    
    
    # if there is no registration key and the user was not accepted, give up here.
    if (!$post{registrationKey} && $user{notRegistered}) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => 'Please wait, registering device...', #'Device did not attempt to register.',
            pleaseRegisterAgain => JSON::true
        };
        return \%return;
    }
    
    # if the user isn't registered and provided a registration key, attempt to register.
    if ($post{registrationKey} && $user{notRegistered}) {
    
        # check if registration key is valid. if it's not, give up.
        if (!DuckingNinja::Private::registration_key_check(%post)) {
            $return{jsonObject} = {
                accepted => JSON::false,
                error    => 'Device registration failed.',
                pleaseRegisterAgain => JSON::true
            };
            return \%return;
        }
    
        # it's valid.
        $json{registeredSuccessfully} = JSON::true;
        $json{licenseKey} = DuckingNinja::Private::generate_license_key(%post);
        my $err = DuckingNinja::db_do('
            INSERT INTO {registry} (
                license_key,
                registration_key,
                unique_device_id,
                unique_global_device_id,
                ip,
                server,
                model,
                common_name,
                short_version,
                bundle_version_key,
                time,
                last_time
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            $json{licenseKey},
            $post{registrationKey},
            $post{uniqueDeviceIdentifier},
            $post{uniqueGlobalDeviceIdentifier},
            $post{_clientIP},
            DuckingNinja::conf('server', 'name'),
            $post{modelIdentifier},
            $post{commonName},
            $post{shortVersion},
            $post{bundleVersionKey},
            $post{_recvTime},
            $post{_recvTime},
            1
        ); 
        return error "Failed to store device registration: $err" if $err;
        $user{notRegistered} = 0;
        
        DuckingNinja::IRC::post(
            'New device registration',
            [ 'Application',    "$post{bundleID} $post{shortVersion} ($post{bundleVersionKey})" ],
            [ 'Device name',    $post{commonName}                   ],
            [ 'Device model',   $post{modelIdentifier}              ],
            [ 'Device system',  "$post{systemName} $post{systemVersion}" ],
            [ 'IP address',     $post{_clientIP}                    ]
        );
    
    }

    
    
    #-- trend stuff and welcome message --#
    
    
    
    $json{popular} = DuckingNinja::trend_groups();

    my $welcome_message;
    DuckingNinja::select_hash_each(
        'SELECT `message` FROM {welcome} ORDER BY `time` DESC LIMIT 1',
        sub { my %row = @_; $welcome_message = $row{message} }
    );
    
    $json{welcomeMessage} = $welcome_message if defined $welcome_message;

    #-- server stuff --#
    
    

    # fetch the client servers. currently, these are in no absolute order.
    my %client_servers;
    DuckingNinja::select_hash_each('SELECT `name`, `enabled` FROM {servers} ORDER BY `index`', sub {
        my %row = @_;
        return if $row{name} eq 'last';
        $client_servers{$row{name}} = $row{enabled} ? JSON::true : JSON::false;
    }) or return error 'Failed to fetch available servers';
    $json{clientServers} = \%client_servers;
    
    # chat servers.
    $json{servers} = $status->{servers} if ref $status->{servers} eq 'ARRAY';
    
    # this server's name.
    $json{server} = DuckingNinja::conf('server', 'name');
    
    
    
    #-- statistic stuff --#
    
    
    
    # peak user count.
    DuckingNinja::select_hash_each(
    'SELECT `count` FROM {stats_peak} ORDER BY `num` DESC LIMIT 1', sub {
        my %row = @_;
         $json{maxCount} = int $row{count};
    }) or return error 'Failed to fetch peak user count';

    # total conversation count and total conversation duration..
    DuckingNinja::select_hash_each(
    'SELECT
        SUM(`client_duration`) AS `total_time`,
        COUNT(*) AS `total_num`
    FROM {conversations}', sub {
        my %row = @_;
         $json{totalChatTime} = int $row{total_time};
         $json{totalConvos}   = int $row{total_num};
    }) or return error 'Failed to fetch conversation statistics';
    
    # longest conversation.
    DuckingNinja::select_hash_each('
    SELECT 
        `client_duration`
    FROM {conversations}
    ORDER BY `client_duration` DESC
    LIMIT 1', sub {
        my %row = @_;
        $json{longestConvo} = int $row{client_duration};
    });
    

    # current user count.
    $json{count} = $status->{count};
    
    # TODO: averageConvo.
    # temporarily default to 15 minutes.
    $json{averageConvo} = 15 * 60;
    

    # HARDCODED: clean chat force
    $json{forceInterests} = ['clean', 'chat', 'clean chat'];


    #-- success --#


    $json{accepted}     = JSON::true;
    $return{jsonObject} = \%json;
    return \%return;
}

# request to /start.
# licenseKey, unqiqueDeviceIdentifier, uniqueGlobalDeviceIdentifier
# sessionType:  NSStringFromNewOmegleSessionType() of session type
# interests:    JSON-encoded array of standalone interests
# groups:       JSON-encoded array of interest group names
# question:     the question being used if the session type is ask (answer will be at end)
sub http_2_start {
    my %post = @_;
    my (%return, %json);
    
    # check for required parameters.
    if (!defined $post{sessionType}) {
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # generate a unique conversation identifier.
    my $unique_id = DuckingNinja::Private::generate_session_identifier(%post);
    $json{uniqueConversationIdentifier} = $unique_id;
    
    my (%groups, @interests);#, @finalized_interests);
    
    # determine standalone interests.
    if (defined $post{interests}) {
        my $interests_ref = JSON::decode_json($post{interests});
        if (!$interests_ref || ref $interests_ref ne 'ARRAY') {
            $return{jsonObject} = { accepted => JSON::false, error => 'Group encoding error.' };
            return \%return;
        }
        push @interests, @$interests_ref;
    }
    
    # determine interest groups.
    if (defined $post{groups}) {
        my $groups_ref = JSON::decode_json($post{groups});
        if (!$groups_ref || ref $groups_ref ne 'ARRAY') {
            $return{jsonObject} = { accepted => JSON::false, error => 'Group encoding error.' };
            return \%return;
        }
        
        # for each group, select the interests.
        foreach my $group_name (@$groups_ref) {
        
            # fetch interests from group.
            DuckingNinja::select_hash_each('SELECT * FROM {interests} WHERE `group` = ?', $group_name, sub {
                my %row = @_;
                $groups{$group_name} ||= [];
                push @{$groups{$group_name}}, $row{interest};
                #push @finalized_interests, $row{interest};
            });
            
        }

    }

    # insert into database.
    my $err = DuckingNinja::db_do('
        INSERT INTO {conversations} (
            id,
            session_type,
            server,
            ip,
            unique_device_id,
            unique_global_device_id,
            start_time
            '.( defined $post{question} ? ', question' : '' ).'
        ) VALUES (?, ?, ?, ?, ?, ?, ?'. ( defined $post{question} ? ', ?)' : ')' ),
            $unique_id,
            $post{sessionType},
            DuckingNinja::conf('server', 'name'),
            $post{_clientIP},
            $post{uniqueDeviceIdentifier},
            $post{uniqueGlobalDeviceIdentifier},
            $post{_recvTime},
            $post{question}
    );
    return error "Failed to store conversation info: $err" if $err;
    
    # insert interest groups.
    DuckingNinja::db_do(
        'INSERT INTO {convo_interests} (id, group_supplied) VALUES(?, ?)',
        $unique_id,
        $_
    ) foreach keys %groups;
    
    # insert standalone interests.
    DuckingNinja::db_do(
        'INSERT INTO {convo_interests} (id, interest_supplied) VALUES(?, ?)',
        $unique_id,
        $_
    ) foreach @interests;
    
    # set return values.
    $json{interests}    = \@interests if scalar @interests;
    $json{groups}       = \%groups    if scalar keys %groups;
    $json{accepted}     = JSON::true;
    
    $return{jsonObject} = \%json;
    return \%return;
}

# request to /end.
# conversationID:   numingle conversation ID
# omegleID:         omegle session ID
# omegleServer:     omegle chat server
# foundTime:        time at which stranger was found
# question:         question (if ask/answer mode)
# messagesSent:     number of messages sent
# messagesReceived: number of messages received
# duration:         client-deteremined duration
# fate:             0 = user disconnected; 1 = stranger disconnected
# interestsMatched: JSON array of interests that matched (if common interests)
# foundStranger:    true if a stranger was ever found
sub http_2_end {
    my %post = @_;
    my %return;
    
    # check for required parameters.
    my @required = qw(
        omegleID omegleServer foundTime fate
        messagesSent messagesReceived duration
        conversationID foundStranger
    ); foreach (@required) {
        next if defined $post{$_} && length $post{$_};
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # update database.
    my @arguments = (
        $post{omegleID},
        $post{omegleServer},
        $post{foundStranger} + 0,
        $post{foundTime}     + 0,
        $post{_recvTime}
    );
    push @arguments, $post{question} if defined $post{question};
    push @arguments, (
        $post{messagesSent}     + 0,
        $post{messagesReceived} + 0,
        $post{duration}         + 0,
        0, # XXX
        $post{fate}             + 0
    );
    my $err = DuckingNinja::db_do(
       'UPDATE {conversations} SET
        `omegle_id`         = ?,
        `omegle_server`     = ?,
        `found_stranger`    = ?,
        `found_time`        = ?,
        `end_time`          = ?,
       '.( defined $post{question} ? '`question` = ?,' : '').'
        `messages_sent`     = ?,
        `messages_received` = ?,
        `client_duration`   = ?,
        `server_duration`   = ?,
        `fate`              = ?
        WHERE `id` = ? AND unique_device_id = ? AND unique_global_device_id = ?
    ',
        @arguments,
        $post{conversationID},
        $post{uniqueDeviceIdentifier},
        $post{uniqueGlobalDeviceIdentifier}
    );
    return error "Failed to store conversation info: $err" if $err;
    
    # insert interests matched.
    if ($post{interestsMatched}) {
        my $interests_ref = JSON::decode_json($post{interestsMatched});
        if (!$interests_ref || ref $interests_ref ne 'ARRAY') {
            $return{jsonObject} = { accepted => JSON::false, error => 'Interest encoding error.' };
            return \%return;
        }
        DuckingNinja::db_do(
            'INSERT INTO {convo_interests} (id, interest_matched) VALUES (?, ?)',
            $post{conversationID},
            $_
        ) foreach @$interests_ref;
    }
    
    $return{jsonObject} = { accepted => JSON::true };
    return \%return;
}

# request to /report.
sub http_2_report {
    my %post = @_;
    my %return;

    # check for required parameters.
    my @required = qw(conversationID reason conversation);
    foreach (@required) {
        next if defined $post{$_} && length $post{$_};
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # must be an array ref.
    my $logs;
    $logs = decode_json($post{conversation});
    if (!$logs || ref $logs ne 'ARRAY') {
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # ensure that this conversation exists.
    my $found_row = 0;
    DuckingNinja::select_hash_each(
    'SELECT `id` FROM {conversations}
     WHERE  `id`                      = ?
     AND    `unique_device_id`        = ?
     AND    `unique_global_device_id` = ?
     LIMIT 1',
        $post{conversationID},
        $post{uniqueDeviceIdentifier},
        $post{uniqueGlobalDeviceIdentifier},
        sub { $found_row = 1 }
    ) or return error 'Failed to fetch conversation info';
    
    # didn't find it.
    if (!$found_row) {
        $return{jsonObject} = { accepted => JSON::false, error => 'Conversation invalid.' };
        return \%return;
    }
    
    # found it. go ahead and add it.
    my $err = DuckingNinja::db_do('
    INSERT INTO {reports} (
        `id`,
        `server`,
        `ip`,
        `unique_device_id`,
        `unique_global_device_id`,
        `reason`,
        `time`
    ) VALUES (?, ?, ?, ?, ?, ?, ?)',
        $post{conversationID},
        DuckingNinja::conf('server', 'name'),
        $post{_clientIP},
        $post{uniqueDeviceIdentifier},
        $post{uniqueGlobalDeviceIdentifier},
        $post{reason},
        $post{_recvTime}
    );
    return error "Failed to store report info: $err" if $err;
    
    
    # insert the log's individual events.
    foreach my $log (@$logs) {
    
        # TODO: ensure the log type is a valid one.
    
    
        # must be an array ref.
        if (ref $log ne 'ARRAY') {
            $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
            return \%return;
        }
    
        # conversation identifier and event name.
        my @log_arguments = (
            $post{conversationID},
            $log->[0]
        );
        
        # value.
        push @log_arguments, $log->[1] if defined $log->[1];
    
        # source.
        push @log_arguments, 'report';
    
        my $err = DuckingNinja::db_do('
        INSERT INTO {convo_events} (
            `id`,
            `event`,
            '.(defined $log->[1] ? '`value`,' : '').'
            `source`
        ) VALUES(?, ?, ?'.(defined $log->[1] ? ', ?)' : ')'),        
            @log_arguments
        );
        return error "Failed to store conversation data: $err" if $err;
        
    }
    
    # success.
    $return{jsonObject} = {
        accepted => JSON::true,
        message  => 'Your report has been submitted and is pending review.'
    };
    
    return \%return;
}

# submit a log.
sub http_2_submitLog {
    my %post = @_;
    my %return;

    # check for required parameters.
    my @required = qw(conversationID conversation);
    foreach (@required) {
        next if defined $post{$_} && length $post{$_};
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # must be an array ref.
    my $logs;
    $logs = decode_json($post{conversation});
    if (!$logs || ref $logs ne 'ARRAY') {
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # ensure that this conversation exists.
    my $found_row = 0;
    DuckingNinja::select_hash_each(
    'SELECT `id` FROM {conversations}
     WHERE  `id`                      = ?
     AND    `unique_device_id`        = ?
     AND    `unique_global_device_id` = ?
     LIMIT 1',
        $post{conversationID},
        $post{uniqueDeviceIdentifier},
        $post{uniqueGlobalDeviceIdentifier},
        sub { $found_row = 1 }
    ) or return error 'Failed to fetch conversation info';
    
    # didn't find it.
    if (!$found_row) {
        $return{jsonObject} = { accepted => JSON::false, error => 'Conversation invalid.' };
        return \%return;
    }
    
    # found it. go ahead and add it.
    my $err = DuckingNinja::db_do('
    INSERT INTO {logs} (
        `id`,
        `server`,
        `ip`,
        `unique_device_id`,
        `unique_global_device_id`,
        `time`
    ) VALUES (?, ?, ?, ?, ?, ?)',
        $post{conversationID},
        DuckingNinja::conf('server', 'name'),
        $post{_clientIP},
        $post{uniqueDeviceIdentifier},
        $post{uniqueGlobalDeviceIdentifier},
        $post{_recvTime}
    );
    return error "Failed to insert log data: $err" if $err;
    
    
    # insert the log's individual events.
    foreach my $log (@$logs) {
    
        # TODO: ensure the log type is a valid one.
    
    
        # must be an array ref.
        if (ref $log ne 'ARRAY') {
            $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
            return \%return;
        }
    
        # conversation identifier and event name.
        my @log_arguments = (
            $post{conversationID},
            $log->[0]
        );
        
        # value.
        push @log_arguments, $log->[1] if defined $log->[1];
    
        # source.
        push @log_arguments, 'log_url'; # 'Share Log URL'
    
        my $err = DuckingNinja::db_do('
        INSERT INTO {convo_events} (
            `id`,
            `event`,
            '.(defined $log->[1] ? '`value`,' : '').'
            `source`
        ) VALUES(?, ?, ?'.(defined $log->[1] ? ', ?)' : ')'),        
            @log_arguments
        );
        return error "Failed to insert conversation data: $err" if $err;
        
    }
    
    # success.
    $return{jsonObject} = {
        accepted => JSON::true
    };
    
    return \%return;
}


# EULA.
sub http_0_eula {
    return my $h = {
        template    => DuckingNinja::html_template_db('eula')
    };
}

# admin homepage.
sub http_0_panel {
    return my $h = {
        template    => DuckingNinja::admin_template('home')
    };
}

# return error.
sub error ($) {
    my $msg = shift;
    return \$msg;
}

1
