package BkxMojo;
use Mojo::Base 'Mojolicious';
use MongoDB::Connection;
use Mojolicious::Plugin::Config;
use Mojolicious::Plugin::Bcrypt;
use URI::Escape qw(uri_escape);

sub startup {
	my $self = shift;
	$self->secret('changeme');

	# Helpers.. #

	# Initialise config file
	my $config = $self->plugin('Config');
	# Initialise password crypt
	$self->plugin('bcrypt', { cost => 6 });
	# common functions
	$self->plugin('BkxMojo::Plugin::Bkmrx');
	# mongodb
	$self->attr(db => sub { 
		MongoDB::Connection
			->new(host => $config->{database_host})
			->get_database($config->{database_name});
	});
	$self->helper('db' => sub { shift->app->db });

	# Routing #
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/')->to('core#welcome');
	$r->get('/about')->to('core#about');
	$r->get('/contact-us')->to('core#contact');
	$r->get('/privacy')->to('core#privacy');
	$r->get('/tos')->to('core#tos');

	# Login functions
	$r->get('/login')->to( 'auth#login', user_id => '' );
	$r->post('/login' => sub {
		my $self = shift;

		my $email = $self->param('email') || '';
		my $pass  = $self->param('pass')  || '';

		my $db = $self->db;
		my $users = $db->get_collection( 'users' );

		my $res = $users->find({ email => $email });
		my $count = $res->count;

		# error unless 1 result
		unless ($count == 1) {
			$self->flash( error => "error logging in" );
			return $self->redirect_to('/login');
		}

		my $doc = $res->next;
		my $user_id = $doc->{"_id"}->to_string;
		my $username = $doc->{"username"};

		# error unless password matches
		unless ($self->bcrypt_validate( $pass, $doc->{"pass"} )) {
			$self->flash( error => "error logging in" );
			return $self->redirect_to('/login');
		}

		# log the user in
		$self->session( user_id => $user_id );
		$self->session( username => $username );

		# go to bookmarklet if applicable
		if ($self->param('title') && $self->param('url')) {
			return $self->redirect_to('/bklet?url=' . 
				uri_escape($self->param('url')) . 
				'&title=' . 
				uri_escape($self->param('title'))
				);
		}

		$self->flash( message => 'welcome back!' );
		$self->redirect_to('/bkmrx');
	} => 'auth/login');
  
	$r->post('/register')->to('account#register');

	# account - protected area
	my $logged_in = $r->under( sub {
		my $self = shift;

		return 1 if $self->session('user_id');

		if ($self->tx->req->url->path eq '/bklet') {
			$self->flash(bk_title => $self->param('title'), bk_url => $self->param('url'));
		}

		$self->redirect_to('/login');
		return undef;
	} );

	# AJAJ Functions
	$logged_in->get('/ajax/fetch_url')->to('functions#fetch_url');
	$logged_in->get('/ajax/modal')->to('ajax#modal_add');

	# core account pages
	$logged_in->get('/bkmrx')->to('account#my_bkmrx');
	$logged_in->get('/me/')->to('account#account');
	$logged_in->get('/addons')->to('account#addons');
	
	# search
	$logged_in->get('/search')->to('search#search');

	$logged_in->get('/bklet')->to('account#bklet');

	$logged_in->get('/me/import')->to('account#import');
	$logged_in->post('/me/import-ffx')->to('functions#import_ffx');
	$logged_in->post('/me/import-delicious')->to('functions#import_delicious');
	$logged_in->get('/me/edit-tags')->to('account#edit_tags');
	$logged_in->get('/me/backup')->to('account#backup');
	$logged_in->get('/me/backup-html')->to('functions#backup_html');

	# ajax
	$logged_in->any('/ajax/json_taglist')->to('ajax#json_taglist');
	$logged_in->any('/ajax/add-tag')->to('ajax#add_tag');

	# crud
	$logged_in->get('/me/delete-tags')->to('crud#remove_tags');
	$logged_in->get('/ajax/delete-tag')->to('crud#remove_tag');
	$logged_in->post('/ajax/update-bkmrk')->to('crud#update_bkmrk');
	$logged_in->get('/ajax/delete-bkmrk')->to('crud#delete_bkmrk');
	$logged_in->get('/ajax/lock-unlock')->to('crud#lock_unlock');
	$logged_in->post('/me/')->to('crud#update_user');
	$logged_in->post('/me/add')->to('crud#add_bkmrk');

	# log out
	$logged_in->get('/logout' => sub {
		my $self = shift;
		$self->session(expires => 1);
		$self->redirect_to('/');
	});

	# public user profiles
	$r->get('/user/:name')->to('user#profile');
}


1;
