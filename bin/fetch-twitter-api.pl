#!/usr/bin/env perl
use strict;
use Net::Twitter;
use Scalar::Util 'blessed';
use MongoDB;
use MongoDB::OID;
use WWW::Mechanize;
use Date::Manip;

# When no authentication is required:
my $consumer_key    = ''; # Enter consumer key here
my $consumer_secret = ''; # Enter consumer secret here
my $token           = ''; # Enter token here
my $token_secret    = ''; # Enter token secret here

exit unless $consumer_key ne '';

# As of 13-Aug-2010, Twitter requires OAuth for authenticated requests
my $nt = Net::Twitter->new(
    traits   => [qw/OAuth API::REST/],
    consumer_key        => $consumer_key,
    consumer_secret     => $consumer_secret,
    access_token        => $token,
    access_token_secret => $token_secret,
);

my %months = qw(jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7 aug 8 sep 9 oct 10 nov 11 dec 12);

my $client = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db     = $client->get_database( 'bkmrx' );
my $users  = $db->get_collection( 'users' );

my $res = $users->find({'social.twitter' => {'$ne' => 'null'}});

while (my $doc = $res->next) {
    my $screen_name = $doc->{'social'}->{'twitter'};
    my $since_id    = $doc->{'social'}->{'twitter_since'} || undef;
    my $user_id     = $doc->{'_id'}->to_string;
    
    #user_timeline
    #Parameters: id, user_id, screen_name, since_id, max_id, count, page, skip_user, trim_user, include_entities, include_rts
    my $statuses;
    my %params = (
                    include_entities => 'true', 
                    include_rts => 'true', 
                    screen_name => $screen_name, 
                    count => 50
                  );
        
    if (defined($since_id)) {
        $params{'since_id'} = $since_id;
    }
    
    eval { $statuses = $nt->user_timeline(\%params); };
        
    if ( my $err = $@ ) {
        die $@ unless blessed $err && $err->isa('Net::Twitter::Error');
    
        warn "HTTP Response Code: ", $err->code, "\n",
        "HTTP Message......: ", $err->message, "\n",
        "Twitter error.....: ", $err->error, "\n";
    }
        
    my @since_ids;
        
    for my $status ( @$statuses ) {
        my $created_at       = $status->{'created_at'};
        my $user_screen_name = $status->{'user'}{'screen_name'};
        my $status_text      = $status->{'text'};
        my $hashtags         = $status->{'entities'}{'hashtags'};
        my $tweet_id         = $status->{'id'};
        my $urls             = $status->{'entities'}{'urls'};
            
        # add id to array so we can track which the last tweet we fetched was
        push @since_ids, $tweet_id;
        
        # reformat date for DB
        my $dm = new Date::Manip::Date;
        my $err = $dm->parse($created_at);
        my $unix = $dm->printf('%s');
        
        if (scalar(@$urls) > 0) {
            foreach my $u (@$urls) {
                # although unlikely to be a t.co url could well be another shortened url
                # so let's fetch & insert longer url instead
                # later...
                my $t_url = $u->{'expanded_url'};
                my ($t_title, $t_desc);
                $t_url =~ s![?&]utm_(?:medium|source|campaign|content)=[^&]+!!gi;
                
                my $mech2 = WWW::Mechanize->new( autocheck => 0 );
                $mech2->get($t_url);
                
                if ($mech2->success) {
                    $t_url = $mech2->uri->as_string;
                    $t_title = $mech2->title || $t_url;
                } else {
                    # skip onto next url if this one doesn't resolve
                    next;
                }

                my @tags;

                if (scalar(@$hashtags) > 0) {
                    foreach my $h (@$hashtags) {
                        my $tag = lc $h->{'text'};
                        $tag =~ s![^-a-z0-9]!!g;
                        push(@tags, $tag);
                    }
                }
                
                my $urls = $db->get_collection( 'urls' );
                
                # insert url
                $urls->insert({ _id => $t_url, crawled => 0 });
                
                my $bkmrx = $db->get_collection('bookmarks');

                $bkmrx->update({user_id => $user_id, url => $t_url}, 
                    {'$set' => {
                        url => $t_url,
                        added => int $unix,
                        'meta.title' => $t_title,
                        'meta.desc' => $status_text,
                        'meta.source' => 'twitter',
                        'meta.status' => 0,
                        'meta.tags' => \@tags,
                        }}, 
                    {upsert => 1});
            }
        }
    }
    @since_ids = sort { $b cmp $a } @since_ids;
    $users->update({_id => MongoDB::OID->new( value => $user_id) },
                    {'$set' => {
                        'social.twitter_since' => $since_ids[0],
                        }}, 
                    {upsert => 1});
}