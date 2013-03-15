#!/usr/bin/env perl
use Modern::Perl;
use AnyEvent;
use AnyEvent::HTTP;
use Mojo::Util qw(decode encode html_unescape xml_escape);
use Mojo::DOM;
use File::Spec::Functions qw( catfile );
use Getopt::Long;
use Time::HiRes qw(time);
use File::Path qw(make_path);
use MongoDB;
use MongoDB::OID;
use FindBin;

# change user agent string and add contact email for webmasters
my $user_agent = 'bkmrx bot (email@domain.com here';

# default to only indexing links which *haven't* been indexed
my $all_links = 0;
# default limit set to 500 since the crontab's running this script 
# every 2 minutes, so no point in thrashing it all in one go.
my $limit     = 500;
my $create    = 0;
GetOptions( 'all_links=i' => \$all_links, 'limit=i' => \$limit, 'create=i' => \$create );

my $client = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db     = $client->get_database( 'bkmrx' );
my $urls   = $db->get_collection( 'urls' );

# Source directory for crawl data
our $corpus_source = "$FindBin::Bin/../corpus";

my $queue;
if ($all_links == 1) {
    $queue = $urls->find();
} else {
    $queue = $urls->find({crawled => 0})->limit($limit);
}

# don't continue if we've nothing to index.
if ( $queue->count == 0 ) {
    exit;
}

my @urls;
while (my $doc = $queue->next) {
    my $url    = $doc->{'_id'};
    push @urls, $url; 
    
    # check out URL for crawling
    _crawl_checkout($url);
}

my $cv = AE::cv;

my $result;

# Create a unique folder for this crontask so we don't end up
# indexing the same pages twice; this unique path is then sent to
# the indexer at the end of the crawl script
my $start = int time;
if ( make_path( "$corpus_source/$start", {verbose => 1,mode => 0755,}) ) {
    $corpus_source .= "/$start";
} else {
    die "Couldn't create crawl data folder";
}

for my $url (@urls) {
    $cv->begin;
    my $now = time;
    my $request;
    
    $request = http_request(
        GET => $url, 
        timeout => 10, # seconds
        recurse => 5, # redirects
        headers => { "user-agent" => $user_agent },
        sub {
            my ($body, $hdr) = @_;

            # only index successful responses and a limited set of content types
	        if ($hdr->{Status} =~ /^2/ && $hdr->{'content-type'} =~ m{^text/(?:html|plain|json|xml)}i) {
                my $content = $body;
                
                my ($charset) = $hdr->{'content-type'} =~ /charset=([-0-9A-Za-z]+)$/; 
                
                # attempt to decode content
                if ($charset) {
                    $charset =~ s!utf-8!utf8!;
                    $content = decode($charset, $body);
                }

                # remove junk content
                $content =~ s!<(script|style|iframe)[^>]*>.*?</\1>!!gis;

                # initialise DOM parser
                my $dom = Mojo::DOM->new($content);
                
                # store destination url
                my $uri = $hdr->{URL};
        
                # Store title or URL if title not found
                my $title = $dom->at('head > title') ? $dom->at('head > title')->text : $uri;
              
                # Turn back into DOM object to retrieve text
                my $clean_content = $dom->all_text;
                $clean_content =~ s![<>]!!g;

                # url crawled successfully
                _crawl_ok($url);
                
                my $ts = time;
    
                open(XML,">:utf8", catfile( $corpus_source, "$ts.xml") ) or die $!;
                print XML "<uri>$uri</uri><title>$title</title><content>$clean_content</content>";
                close XML;
            } else {
	            push (@$result, join("",
			     "Error for ",
			       $url,
			       ": (", 
			       $hdr->{Status}, 
			       ") ", 
			       $hdr->{Reason})
		        );
		        _crawl_fail($url);
	        }
            undef $request;
            $cv->end;
        }
    );
}

$cv->wait;

# Run the indexer for this segment
my @args = ("$FindBin::Bin/../bin/indexer.pl", "--corpus_source=$corpus_source", "--create=$create");
exec("perl", @args) or die "exec failed: $!";

sub _crawl_checkout {
    my $url = shift;
    # checking out URL for indexing
    $urls->update({_id => $url}, {'$set' => {
        crawled => 2,
        status => 'in progress',
    }});
}

sub _crawl_ok {
    my $url = shift;
    # url crawled successfully
    $urls->update({_id => $url}, {'$set' => {
        crawled => 1,
        date_crawled => time(),
        status => 'ok',
    }});
}

sub _crawl_fail {
    my $url = shift;
    # url crawled unsuccessfully
    $urls->update({_id => $url}, {'$set' => {
        crawled => 3,
        date_crawled => time(),
        status => 'fail',
    }});
}

