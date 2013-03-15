#!/usr/bin/env perl
use Modern::Perl;
use Mojo::UserAgent;
use HTML::TreeBuilder::XPath;
use HTML::Entities;
use JSON;
use MongoDB;
use Date::Manip;
use Date::Calc;
use Mojo::Log;
my $log = Mojo::Log->new();

my %months = qw(jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7 aug 8 sep 9 oct 10 nov 11 dec 12);

my $client = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db     = $client->get_database( 'bkmrx' );
my $users  = $db->get_collection( 'users' );

my $res = $users->find({'social.github' => {'$ne' => ''}});

while (my $doc = $res->next) {
    next unless my $git_user = $doc->{'social'}->{'github'};
    my $user_id  = $doc->{'_id'}->to_string;
    
    my $url = 'https://github.com/' . $git_user . '.json';
    
    my $ua = Mojo::UserAgent->new;
    
    my $tx = $ua->get($url);
    
    if (my $res = $tx->success) {
        my $content = $res->body;
        
        my $parsed = from_json($content);
        
        foreach my $node (@$parsed) {
            
            my $g_url       = $node->{'url'};
            my $created_at  = $node->{'created_at'};
            my $type        = $node->{'type'};
            my $title       = $node->{'repository'}->{'description'};
            
            my $dm = new Date::Manip::Date;
            my $err = $dm->parse($created_at);
            my $unix = $dm->printf('%s');
            
            if ($type eq 'WatchEvent') {
                my $g_url_id;

                my $urls = $db->get_collection( 'urls' );
                
                # insert url
                $urls->insert({ _id => $g_url, crawled => 0 });
            	
                my $bkmrx = $db->get_collection('bookmarks');

                $bkmrx->update({user_id => $user_id, url => $g_url}, 
                    {'$set' => {
                        url => $g_url,
                        added => int $unix,
                        'meta.title' => $title,
                        'meta.source' => 'github',
                        'meta.status' => 0,
                        'meta.tags' => ['github']
                        }}, 
                    {upsert => 1});
        	} else {
        	    next;
        	}    
        }
    } else {
        my ($err, $code) = $tx->error;
        die "$url error: $err - $code";
    }
}
