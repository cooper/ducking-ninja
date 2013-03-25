# Copyright (c) 2013, Mitchell Cooper
# This script inserts trends into a database.

use warnings;
use strict;
use utf8;
use feature 'say';

use DuckingNinja;

my $trends = do(shift @ARGV); # file containing has ref of trends.
die "not a hash ref\n" unless ref $trends eq 'HASH';
my %trends = %$trends;

# connect to database and parse configuration.
# this assumes that the script is run from the git dir
# as in `perl DuckingNinja/insert_trends.pl`

use lib './DuckingNinja';
use lib './evented-object';
use lib './evented-configuration';
DuckingNinja::start();

foreach my $group_name (keys %trends) {
    my %group = %{$trends{$group_name}};
    
    my $group_exists = 0;
    DuckingNinja::select_hash_each(
        'SELECT * FROM {groups} WHERE `name` = ?',
        $group_name,
        sub { $group_exists = 1 }
    );
    
    # these are required.
    my @arguments = (
        $group_name,
        $group{popularity},
        $group{display}
    );
    
    # only add these if they are present.
    my @maybe = qw(subdisplay borderColor backgroundColor imageURL fontSize textColor);
    foreach (@maybe) {
        push @arguments, $group{$_} if defined $group{$_};
    }
    
    # current timestamp.
    push @arguments, time;
    
    
    # if the group doesn't exist, create it.
    if (!$group_exists) {
    
        # required columns.
        my $query = 'INSERT INTO {groups} (name, popularity, display_title';
        
        # add optional columns if they are present.     
        $query   .= ', display_subtitle'        if defined $group{subdisplay};
        $query   .= ', style_border_color'      if defined $group{borderColor};
        $query   .= ', style_background_color'  if defined $group{backgroundColor};
        $query   .= ', style_background_image'  if defined $group{imageURL};
        $query   .= ', style_font_size'         if defined $group{fontSize};
        
        # current timestamp.
        $query   .= ', create_time)';
        
        # required values.
        $query   .= 'VALUES (?, ?, ?';
        
        # optional values.
        foreach (@maybe) {
            $query .= ', ?' if defined $group{$_};
        }
        
        # current timestamp.
        $query .= ', ?)';
        
        # run it.
        DuckingNinja::db_do($query, @arguments) or die "Insert query failed\n";
        
        say "Created group '$group_name'";
        
    }
    
    # otherwise, update it.
    if ($group_exists) {
    
        # required columns.
        my $query = 'UPDATE {groups} SET `name` = ?, `popularity` = ?, `display_title` = ?';
        
        # optional columns.
        foreach (@maybe) {
            $query .= ', `'.$_.'` = ?';
        }
        
        # current timestamp.
        $query .= ', `create_time` = ?';
        
        # where statement.
        $query .= ' WHERE `name` = ?';
        
        # run it.
        DuckingNinja::db_do($query, @arguments, $group_name) or die "Update query failed.\n";

        say "Updated group '$group_name'";

    }
    
    # insert the interests in the group.
    foreach my $interest (@{$group{interests}}) {
        my $interest_exists = 0;
        
        # check if the interest already exists.
        DuckingNinja::select_hash_each(
            'SELECT * FROM {interests} WHERE `group` = ? AND `interest` = ?',
            $group_name,
            $interest,
            sub { $interest_exists = 1 }
        );
        
        # if it exists, skip it.
        next if $interest_exists;
        
        # otherwise, add it.
        DuckingNinja::db_do(
            'INSERT INTO {interests} (group, interest, time) VALUES (?, ?, ?)',
            $group_name,
            $interest,
            time
        ) or die "Insert interest query failed.\n";
        
        say "Added '$interest' to '$group_name'";
        
    }
    
}

1
