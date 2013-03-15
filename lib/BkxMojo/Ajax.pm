package BkxMojo::Ajax;
use Mojo::Base 'Mojolicious::Controller';

use MongoDB;
use MongoDB::OID;
use Data::Dumper;
use Mojo::Log;
use DateTime;
use Tie::IxHash;
my $log = Mojo::Log->new;

# Render modal window 
sub modal_add {
	my $self = shift;

	$self->render();
}

# list of tags on bkmrx page
sub json_taglist {
	my $self = shift;

	my $filter = $self->param('filter') || '';

	my $db      = $self->db;
	my $tags    = $db->get_collection( 'bookmarks' );
	my $user_id = $self->session('user_id');
	
	my $temp_collection = 'temp_filters';

    my $cmd = Tie::IxHash->new("mapreduce" => $tags->{'name'},
        "map" => _map_filters($filter),
        "reduce" => _reduce_filters(),
        "query" => {user_id => $user_id, 'meta.tags' => {'$exists' => 'true'}},
        "out" => $temp_collection
        );

    my $result = $db->run_command($cmd);

    die ("Mongo error: $result") unless ref($result) eq 'HASH';

    my $temp_h = $db->get_collection( $temp_collection );
    my $id_cursor = $temp_h->find()->sort({'value.count' => -1})->limit(10);

    my %json_tags;

    # ensure tags come out in the right order
    my $t = tie(%json_tags, 'Tie::IxHash');
    while (my $doc = $id_cursor->next) {
    	$json_tags{$doc->{'_id'}} = $doc->{'value'}->{'count'};
    }

	$self->render_json(\%json_tags);
}

# follow another user's bkmrx
sub follow {
    my $self = shift;

    # to be implemented

    $self->redirect_to('/');
}

# add a tag from the bkmrx page
sub add_tag {
    my $self = shift;

    my $tag     = $self->clean_tag($self->param('tag')) || '';
    my $b_id    = $self->param('id')  || '';
    my $user_id = $self->session('user_id');

    my $db    = $self->db;
    my $bkmrx  = $db->get_collection( 'bookmarks' );
    $bkmrx->update({ _id => MongoDB::OID->new( value => $b_id ), user_id => $user_id }, 
        {'$push' => {'meta.tags' => $tag}});
    # tag id bkx id tag
    $self->render_json({tag => $tag, b_id => $b_id});
}

sub _map_filters {
    my $regex = shift;
    # Ensure we pass something
    if ($regex eq '') {
        $regex = '.*';
    }
	return "function() {
        if (Object.prototype.toString.call( this.meta.tags ) === '[object Array]') {
            this.meta.tags.forEach(function(tag) {
                if (tag.match(/$regex/i)) {
                    emit(tag, {count : 1});
                }
            });
        }
    };";
}

sub _reduce_filters {
	return "function(prev, current) {
        result = {count : 0};
        current.forEach(function(item) {
            result.count += item.count;
        });
        return result;
    };";
}

1;