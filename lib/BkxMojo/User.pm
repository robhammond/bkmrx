package BkxMojo::User;
use Mojo::Base 'Mojolicious::Controller';

use MongoDB;
use MongoDB::OID;
use DateTime;
use Digest::MD5 qw(md5_hex);
use URI::Encode qw(uri_encode);
use String::Truncate qw(elide);

# User page
sub profile {
	my $self = shift;

	my $db    = $self->db;
	my $users = $db->get_collection( 'users' );

	my $res = $users->find({ username => $self->stash('name') });
	my $count = $res->count;
	
	return $self->render_not_found() unless $count == 1;

	my $doc = $res->next;

	my $size = 100;
	my $grav_url = "https://secure.gravatar.com/avatar/" . md5_hex( lc( $doc->{'email'} ) ) . "?d=&s=" . $size;

	my $type;

	my $profile_id = $doc->{'_id'}->to_string;

	if (($self->session('user_id')) && (($self->session('user_id') =~ m/^$profile_id$/))) {
		# the user is looking at their own profile
		$type = 'me';
	} elsif (($self->session('user_id')) && (($self->session('user_id') !~ m/^$profile_id$/))) {
		my $usr_res = $users->find({
			_id => MongoDB::OID->new( value => $self->session('user_id') ),
			follows => $doc->{'_id'}->to_string
			});
		my $usr_count = $usr_res->count;
		if ($usr_res->count == 0) {
			# the user is looking at another user they follow
			$type = 'friend';
		} else {
			# the user isn't following this person yet
			$type = 'stranger';
		}
	} else {
		# the user isn't logged in
		$type = 'viewer';
	}

	my $bkmrx = $db->get_collection( 'bookmarks' );

	# find public bkmrx
	$res = $bkmrx->find({ user_id => $profile_id, 'meta.status' => 0 })->sort({added => -1})->limit(10);
	
	my $total_results = $res->count;

	my (@bkx);

	while (my $doc = $res->next) {
		my $url = $doc->{'url'};
		my ($disp_url) = $url =~ m{^[hf]tt?ps?://(?:www\.)?(.*)$}i;
		$disp_url = elide($disp_url, 90);
		my $title = $doc->{'meta'}->{'title'};
		my $disp_title = elide($title, 55);

		my $desc = $doc->{'meta'}->{'desc'};

		my $dt = DateTime->from_epoch( epoch => $doc->{'added'} );
		my $added = $dt->day . " " . $dt->month_abbr . " " . $dt->year;

		my $source_icon = '';
		if ($doc->{'meta'}->{'source'} eq 'twitter') {
			$source_icon = " <i class='icon-twitter'></i>";
		} elsif ($doc->{'meta'}->{'source'} eq 'github') {
			$source_icon = " <i class='icon-github'></i>";
		}

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
			source_icon => $source_icon,
			});
	}

	$self->render( user => $doc, gravatar => $grav_url, type => $type, bkmrx => \@bkx );
}

1;
