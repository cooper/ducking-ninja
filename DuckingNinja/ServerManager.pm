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

        # fetched user successfully.
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
    ) or return &HTTP_INTERNAL_SERVER_ERROR;
    
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
            error    => 'The service is currently unavailable.'
        };
        return \%return;
    }
    
    
    
    #-- registration stuff --#
    
    
    
    # if there is no registration key and the user was not accepted, give up here.
    if (!$post{registrationKey} && $user{notRegistered}) {
        $return{jsonObject} = {
            accepted => JSON::false,
            error    => $user{notRegisteredError}
        };
        return \%return;
    }
    
    # if the user isn't registered and provided a registration key, attempt to register.
    if ($post{registrationKey} && $user{notRegistered}) {
    
        # check if registration key is valid. if it's not, give up.
        if (!DuckingNinja::Private::registration_key_check(%post)) {
            $return{jsonObject} = {
                accepted => JSON::false,
                error    => 'Device registration failed.'
            };
            return \%return;
        }
    
        # it's valid.
        $json{registeredSuccessfully} = JSON::true;
        $json{licenseKey} = DuckingNinja::Private::generate_license_key(%post);
        DuckingNinja::db_do('
            INSERT INTO {registry} (
                license_key,
                registration_key,
                unique_device_id,
                unique_global_device_id,
                ip,
                server,
                time
            ) VALUES (?, ?, ?, ?, ?, ?, ?)',
            $json{licenseKey},
            $post{registrationKey},
            $post{uniqueDeviceIdentifier},
            $post{uniqueGlobalDeviceIdentifier},
            $post{_clientIP},
            DuckingNinja::conf('server', 'name'),
            $post{_recvTime}
        ) or return &HTTP_INTERNAL_SERVER_ERROR;
        $user{notRegistered} = 0;
    
    }
    
    
    
    #-- trend stuff --#
    
    
    
    $json{popular} = DuckingNinja::trend_groups();



    #-- server stuff --#
    
    

    # fetch the client servers. currently, these are in no absolute order.
    my @client_servers;
    DuckingNinja::select_hash_each('SELECT `name` FROM {servers} ORDER BY `index`', sub {
        my %row = @_;
        return if $row{name} eq 'last';
        push @client_servers, $row{name};
    }) or return &HTTP_INTERNAL_SERVER_ERROR;
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
    }) or return &HTTP_INTERNAL_SERVER_ERROR;
    $json{maxCount} = $user_peak + 0 || 0;
    
    # current user count.
    $json{count} = $status->{count};
    
    # TODO: totalConvos, longestConvo, averageConvo.
    


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
    DuckingNinja::db_do('
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
    ) or return &HTTP_INTERNAL_SERVER_ERROR;
    
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
sub http_2_end {
    my %post = @_;
    my %return;
    
    # check for required parameters.
    my @required = qw(
        omegleID omegleServer foundTime fate
        messagesSent messagesReceived duration
        conversationID
    ); foreach (@required) {
        next if defined $post{$_} && length $post{$_};
        $return{jsonObject} = { accepted => JSON::false, error => 'Invalid argument.' };
        return \%return;
    }
    
    # update database.
    my @arguments = (
        $post{omegleID},
        $post{omegleServer},
        1,
        $post{foundTime} + 0,
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
    DuckingNinja::db_do(
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
        WHERE `id` = ?
    ', @arguments, $post{conversationID})
    or return &HTTP_INTERNAL_SERVER_ERROR;
    
    $return{jsonObject} = { accepted => JSON::true };
    return \%return;
}

1
