package BkxMojo::Account;
use Mojo::Base 'Mojolicious::Controller';

use BkxMojo::Crud;
use MongoDB;
use MongoDB::OID;
use DateTime;
use String::Truncate qw(elide);
use List::MoreUtils qw(uniq);
use Digest::MD5 qw(md5_hex);
use List::Util qw( max min );

# Standard account dashboard
sub account {
	my $self = shift;

	my $db	  = $self->db;
	my $users = $db->get_collection( 'users' );

	my %user_details;

	my $id    = MongoDB::OID->new( value => $self->session('user_id') );

	my $user = $users->find({ _id => $id });
	if (my $doc = $user->next) {
		$user_details{'email'}    = $doc->{'email'};
		$user_details{'name'}     = $doc->{'name'};
		$user_details{'website'}  = $doc->{'website'};
		$user_details{'twitter'}  = $doc->{'social'}->{'twitter'};
		$user_details{'github'}   = $doc->{'social'}->{'github'};
		$user_details{'gravatar'} = "https://secure.gravatar.com/avatar/" . md5_hex( lc( $doc->{'email'} ) ) . "?d=&s=40";

	} else {
		return $self->render_exception("user not found");
	}

	$self->render(user_details => \%user_details);
}

# import bkmrx
sub import {
	my $self = shift;

	$self->render( );
}

# edit tags
sub edit_tags {
	my $self = shift;

	my $offset 	= $self->param('offset') || 0;
	my $tag 	= $self->param('tag');
	my $type 	= $self->param('type');
	my $page_size = 10;

	my $db    = $self->db;
	my $bkmrx = $db->get_collection( 'bookmarks' );

	my $user_id = $self->session('user_id');

	my $temp_collection = 'temp_tags';

    my $cmd = Tie::IxHash->new("mapreduce" => $bkmrx->{'name'},
        "map" => _map_tags(),
        "reduce" => _reduce_tags(),
        "query" => {user_id => $user_id},
        "out" => $temp_collection
        );

    my $result = $db->run_command($cmd);

    die ("Mongo error: $result") unless ref($result) eq 'HASH';

    my $temp_h = $db->get_collection( $temp_collection );
    my $id_cursor = $temp_h->find()->sort({'value.count' => -1})->limit($page_size)->skip($offset);
    my $total_results = $id_cursor->count;
    my %tags;

    # ensure tags come out in the right order
    my $t = tie(%tags, 'Tie::IxHash');
    while (my $doc = $id_cursor->next) {
    	$tags{$doc->{'_id'}} = $doc->{'value'}->{'count'};
    }

    my $last_result  = min( ( $offset + $page_size ), $total_results );
	my $first_result = min( ( $offset + 1 ), $last_result );

	my $req_path = $self->req->url->path;

	$self->render( 
		tags => \%tags,
		first_result => $first_result,
		last_result => $last_result,
		total_results => $total_results, 
		pages => $self->paginate($total_results, $offset, $page_size, $req_path) );
}

# main bkmrx page
sub my_bkmrx {
	my $self = shift;

	my $offset 	     = $self->param('offset') || 0;
	my $query_tag 	 = $self->param('tag') 	  || '';
	my $query_source = $self->param('source') || '';
	my $user_id      = $self->session('user_id');
	my $page_size = 10;

	my $db 	  = $self->db;
	my $bkmrx = $db->get_collection( 'bookmarks' );
	
	my $res;

	if ($query_tag && $query_source) {
		$res = $bkmrx->find({ user_id => $user_id, 
			'meta.tags' => $query_tag,
			'meta.source' => $query_source })->sort({added => -1})->limit($page_size)->skip($offset);
	} elsif ($query_tag) {
		$res = $bkmrx->find({ user_id => $user_id, 
			'meta.tags' => $query_tag })->sort({added => -1})->limit($page_size)->skip($offset);
	} elsif ($query_source) {
		$res = $bkmrx->find({ user_id => $user_id,
			'meta.source' => $query_source })->sort({added => -1})->limit($page_size)->skip($offset);
	} else {
		$res = $bkmrx->find({ user_id => $user_id })->sort({added => -1})->limit($page_size)->skip($offset);
	}
	
	my $total_results = $res->count;

	my (@bkx, @dates);

	while (my $doc = $res->next) {
		my $url = $doc->{'url'};
		my ($disp_url) = $url =~ m{^[hf]tt?ps?://(?:www\.)?(.*)$}i;
		$disp_url = elide($disp_url, 90);
		my $title = $doc->{'meta'}->{'title'};
		my $disp_title = elide($title, 55);

		my $desc = $doc->{'meta'}->{'desc'} || '';

		my $dt = DateTime->from_epoch( epoch => $doc->{'added'} );
		my $added = $dt->day . " " . $dt->month_abbr . " " . $dt->year;

		push(@bkx, {
			b_id 	=> $doc->{'_id'},
			added 	=> $added,
			url 	=> $url,
			disp_url => $disp_url,
			title 	=> $title,
			disp_title => $disp_title,
			tags 	=> $doc->{'meta'}->{'tags'},
			status 	=> $doc->{'meta'}->{'status'},
			desc 	=> $desc,
			source => $doc->{'meta'}->{'source'},
			});
		push(@dates, $added);
	}
	
	my @uniq_dates = uniq @dates;

	my $last_result  = min( ( $offset + $page_size ), $total_results );
	my $first_result = min( ( $offset + 1 ), $last_result );

	my $req_path = $self->req->url->path;

	my $heading = 'my bkmrx';
	if ($query_source eq 'twitter') {
		$heading = '<i class="icon-twitter"></i> your tweets';
	} elsif ($query_source eq 'github') {
		$heading = '<i class="icon-github"></i> your repos';
	}

	my %params = ( tag => $query_tag, source => $query_source );

	$self->render(
		first_result => $first_result, 
		last_result => $last_result, 
		total_results => $total_results,
		pages => $self->paginate($total_results, $offset, $page_size, $req_path, \%params),
		bkmrx => \@bkx,
		dates => \@uniq_dates,
		heading => $heading,
		source => $query_source,
		);
}

# register user
sub register {
	my $self = shift;

	my $username = $self->param('username');
	my $email    = $self->param('email');
	my $pass     = $self->param('pass');
	my $pass2    = $self->param('pass2');

	if ($pass !~ m{^$pass2$}) {
		$self->flash(error => "passwords don't match!");
		return $self->redirect_to('/login');
	}

	my $db    = $self->db;
	my $users = $db->get_collection( 'users' );

	my $user_id = $users->insert({
		username => $username,
		email => $email,
		pass => $self->bcrypt($pass),
		joined => time(),
	});

	$self->session( user_id => $user_id->to_string );
	$self->session( username => $username );

	$self->redirect_to('/me/');
}

# addons page
sub addons {
	my $self = shift;

	# alter bookmarklet based on host
	my $host = $self->req->url->base->host;
	my $port = $self->req->url->base->port;
	if ($port != 80 || $port != 443) {
		$port = ":$port";
	} else {
		$port = "";
	}
	$self->render( host => $host, port => $port );
}

sub bklet {
	my $self = shift;

	return $self->redirect_to('/login') unless $self->session('username');

	my $title   = $self->param('title');
	my $url     = $self->param('url');
	my $user_id = $self->session('user_id');

	my $db = $self->db;
	my $bkmrx = $db->get_collection('bookmarks');

	my $res = $bkmrx->find({ user_id => $user_id, url => $url });
	
	if ($res->count > 0) {
		$self->flash(dupe => 'URL already bookmarked!');
	}

	$self->render( display_url => elide($url, 60) );
}

sub backup {
	my $self = shift;

	$self->render();
}

sub _map_tags {
	return "function() {
        this.meta.tags.forEach(function(tag) {
            emit(tag, {count : 1});
        });
    };";
}

sub _reduce_tags {
	return "function(prev, current) {
        result = {count : 0};
        current.forEach(function(item) {
            result.count += item.count;
        });
        return result;
    };";
}

1;