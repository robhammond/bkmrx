package BkxMojo::Search;
use Mojo::Base 'Mojolicious::Controller';

use MongoDB;
use MongoDB::OID;
use DateTime;
use Mojo::Home;
use List::Util qw( max min );
use Encode qw( decode );
use String::Truncate qw(elide);
use Lucy::Search::IndexSearcher;
use Lucy::Highlight::Highlighter;
use Lucy::Search::QueryParser;
use Lucy::Search::TermQuery;
use Lucy::Search::ANDQuery;

my $home = Mojo::Home->new;
$home->detect('BkxMojo');

my $path_to_index = $home->rel_dir("web-index");

# Search page
sub search {
	my $self = shift;

	my $q         = $self->param('q')      || '';
	my $offset    = $self->param('offset') || 0;
	my $type      = $self->param('type')   || '';
	my $page_size = $self->param('num')    || 10;
	my $user_id   = $self->session('user_id');

	my $db    = $self->db;
	my $bkmrx = $db->get_collection( 'bookmarks' );

	# Create an IndexSearcher and a QueryParser.
	my $searcher = Lucy::Search::IndexSearcher->new( 
	    index => $path_to_index,
	);
	my $qparser = Lucy::Search::QueryParser->new( 
	    schema => $searcher->get_schema,
	    default_boolop => 'AND',
	);
	$qparser->set_heed_colons(1);
	# Build up a query
	my $query = $qparser->parse($q);

	# Custom searches
	if ($type) {
	    my $res;
	    if ($type eq 'me') {
	    	$res = $bkmrx->find({ 'user_id' => $user_id });
    	} else {
    		$res = $bkmrx->find({ 'meta.source' => $type, 'user_id' => $user_id });
    	}
	    
	    my @urls;
	    while (my $doc = $res->next) {
	        push @urls, $doc->{'url'};
	    }
	    
	    my $url_ids = join(" OR ", @urls);
	    
	    my $filter_parser = Lucy::Search::QueryParser->new( 
	        schema => $searcher->get_schema,
	        fields => ['url'],
	        default_boolop => 'OR',
	    );
	    
	    my $url_id_query = $filter_parser->parse($url_ids);
	    
	    $query = Lucy::Search::ANDQuery->new(
			children => [ $query, $url_id_query ]
		);
	}

	# Execute the Query and get a Hits object.
	my $hits = $searcher->hits(
	    query      => $query,
	    offset     => $offset,
	    num_wanted => $page_size,
	);
	my $hit_count = $hits->total_hits;

	# Arrange for highlighted excerpts to be created.
	my $highlighter = Lucy::Highlight::Highlighter->new(
	    searcher => $searcher,
	    query    => $q,
	    field    => 'content'
	);

	my (@search_results, %search_meta);

	# loop through results
	while ( my $hit = $hits->next ) {
	    my $score   = sprintf( "%0.3f", $hit->get_score );
	    my $excerpt = $highlighter->create_excerpt($hit);
	    my ($display_url) = $hit->{url} =~ m{^[hf]tt?ps?://(?:www\.)?(.*)$}i;
	    
	    # search all users' bookmarks
	    push(@search_results, {
		        url => $hit->{url},
		        orig_url => $hit->{orig_url},
		        display_url => elide($display_url, 90),
		        url_id => $hit->{url_id}, 
		        title => $hit->{title},
		        snippet => $excerpt,
		        score => $score,
		    });
	}

	$search_meta{'total_results'} = $hit_count;
	my $last_result = min( ( $offset + $page_size ), $hit_count );
	my $first_result = min( ( $offset + 1 ), $last_result );
	$search_meta{'first_result'} = $first_result;
	$search_meta{'last_result'} = $last_result;

	$search_meta{'query'}   = $q;
	$search_meta{'results'} = \@search_results;
	my %params = ( q => $q );

	my $req_path = $self->req->url->path;

	$self->render( results => \%search_meta, pages => $self->paginate($hit_count, $offset, $page_size, $req_path, \%params) );
}

1;