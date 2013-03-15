package BkxMojo::Crud;
use Mojo::Base 'Mojolicious::Controller';
use MongoDB;
use MongoDB::OID;

# insert info into DB
sub add_bkmrk {
	my $self = shift;

	my $url     = $self->param('url');
	my $title   = $self->param('title')  || '[[blank]]';
	my $desc    = $self->param('desc')   || '';
	# default to private bkmrk if not specified
	my $status  = $self->param('status');
	my $source  = $self->param('source') || '';
	my @tags    = $self->param('tags[]');
	my $user_id = $self->session('user_id');

	# remove whitespace-only tags
	@tags = grep /\S/, @tags;

	# clean tags
	for (my $i=0; $i < scalar(@tags); $i++) {
		$tags[$i] = $self->clean_tag($tags[$i]);
	}

	my $db = $self->db;
	my $urls = $db->get_collection( 'urls' );

	my $url_id = $urls->insert({ _id => $url, crawled => 0 });

	my $bkmrx = $db->get_collection( 'bookmarks' );

	$bkmrx->insert( 
		{
			user_id   => $user_id,
			url => $url,
			meta   => {
				title => $title,
				desc => $desc,
				status => $status,
				source => $source,
				tags => \@tags,
			},
			added     => time(),
		}
	);

	my $referrer = Mojo::URL->new($self->tx->req->headers->referrer)->path;

	# close the wondow using JS if the save request is from the bookmarklet
	return $self->render(format => 'html', text => '<html><body><script>window.close()</script></body></html>') 
		if $referrer eq '/bklet';

	# if referrer != bklet, redirect
	$self->flash( msg => 'added' );

	# redirect
	$self->redirect_to('/bkmrx');
}

sub update_user {
	my $self = shift;

	my $name     	= $self->param('name') 		|| '';
	my $website  	= $self->param('website') 	|| '';
	my $github  	= $self->param('github') 	|| '';
	my $twitter  	= $self->param('twitter') 	|| '';

	my $db = $self->db;
	my $user = $db->get_collection( 'users' );

	my $user_id    = MongoDB::OID->new( value => $self->session('user_id') );

	$user->update({ _id => $user_id }, {'$set' =>
		{
			name   	 => $name,
			website => $website,
			social => {
				github   => $github, 
				twitter  => $twitter,
			},
		}
	});

  $self->flash( msg => 'Profile updated!' );

  # redirect
  $self->redirect_to('/me/');
}

# remove tag from all bookmarks
sub remove_tags {
	my $self  = shift;
	my $tag   = $self->param('tag') || '';
	
	my $user_id = $self->session('user_id');
	if ($tag) {
		my $db = $self->db;
		my $bkmrx = $db->get_collection( 'bookmarks' );

		$bkmrx->update({ 'user_id' => $user_id }, 
			{ '$pull' => { 'meta.tags' => $tag } }, 
			{ multiple => 1 });

		$self->flash(msg => "Tag '$tag' removed from all bookmarks!");
		return $self->redirect_to($self->tx->req->headers->referrer);
	}
	$self->flash(msg => "Error: no tag provided!");
	$self->redirect_to($self->tx->req->headers->referrer);
}

# remove from a single bookmark
sub remove_tag {
	my $self  = shift;
	my $tag   = $self->param('tag')  || '';
	my $b_id  = $self->param('b_id') || '';
	my $id    = MongoDB::OID->new( value => $b_id );
	if ($tag) {
		my $db = $self->db;
		my $bkmrx = $db->get_collection( 'bookmarks' );

		$bkmrx->update({ _id => $id }, { '$pull' => { 'meta.tags' => $tag } }, { multiple => 1 });
		return $self->render_json({status => 'ok'});
	}
	$self->redirect_to($self->tx->req->headers->referrer);
}

# update a bookmark
sub update_bkmrk {
	my $self  = shift;
	my $b_id  = $self->param('id')    || '';
	my $title = $self->param('title') || '';
	my $desc  = $self->param('desc')  || '';
	if ($b_id) {
		$b_id =~ s!^\w_!!;
		my $id    = MongoDB::OID->new( value => $b_id );

		my $db 	  = $self->db;
		my $bkmrx = $db->get_collection( 'bookmarks' );
		
		if ($title ne '') {	
			$bkmrx->update({ _id => $id }, { '$set' => { 'meta.title' => $title } });
			return $self->render_text($title);
		} elsif ($desc ne '') {
			$bkmrx->update({ _id => $id }, { '$set' => { 'meta.desc' => $desc } }, { safe => 1});
			return $self->render_text($desc);
		}	
	}
	
	$self->render_exception('Error: No bookmark ID passed!');
}

# delete a bookmark
sub delete_bkmrk {
	my $self  = shift;
	my $b_id  = $self->param('b_id')  || '';

	if ($b_id) {
		$b_id =~ s!^\w_!!;
		my $id    = MongoDB::OID->new( value => $b_id );

		my $db = $self->db;
		my $bkmrx = $db->get_collection( 'bookmarks' );
		$bkmrx->remove({ _id => $id, user_id => $self->session('user_id') } );
		return $self->render_text('ok');
	}
	
	$self->render_exception('Error: No bookmark ID passed!');
}

# public/private bookmark
sub lock_unlock {
	my $self  = shift;
	my $b_id  = $self->param('b_id')  || '';
	my $action = $self->param('action') || '';

	if ($action eq 'lock') {
		$action = 1;
	} else {
		$action = 0;
	}

	if ($b_id) {
		my $id    = MongoDB::OID->new( value => $b_id );

		my $db = $self->db;
		my $bkmrx = $db->get_collection( 'bookmarks' );
		
		$bkmrx->update({ _id => $id }, { '$set' => { 'meta.status' => $action } });
		return $self->render_json({status => 'ok'});
	}
	
	$self->render_exception('Error: No bookmark ID passed!');
}


1;
