package BkxMojo::Plugin::Bkmrx;
use Mojo::Base 'Mojolicious::Plugin';

use Net::IP::Match::Regexp qw( create_iprange_regexp match_ip );
use Mojo::URL;
use Data::Validate::Domain;
use Data::Validate::IP;
use List::Util qw( max min );
use POSIX qw( ceil );

sub register {
	my ($self, $app) = @_;

	# Controller alias helpers
	for my $name (qw(paginate clean_tag clean_url valid_uri)) {
		$app->helper($name => sub { shift->$name(@_) });
	}

	$app->helper(paginate  => \&_paginate);
	$app->helper(clean_tag => \&_clean_tag);
	$app->helper(clean_url => \&_clean_url);
	$app->helper(valid_uri => \&_is_valid_uri);
}

# core functions
sub _paginate {
    my ($self, $total_hits, $offset, $page_size, $href, $params) = @_;
    my $paging_info;
    if ( $total_hits == 0 ) {
        # Alert the user that their search failed.
        $paging_info = '';
    } else {

        # if page size != 10 append num param
        my $num = '';
        if ($page_size != 10) {
          $num = '&num=' . $page_size;
        }

        # Calculate the nums for the first and last hit to display.
        my $last_result = min( ( $offset + $page_size ), $total_hits );
        my $first_result = min( ( $offset + 1 ), $last_result );

        # Calculate first and last hits pages to display / link to.
        my $current_page = int( $first_result / $page_size ) + 1;
        my $last_page    = ceil( $total_hits / $page_size );
        my $first_page   = max( 1, ( $current_page - 9 ) );
        $last_page = min( $last_page, ( $current_page + 10 ) );

        # Create a url for use in paging links.
        $href .= "?offset=" . $offset;
        if ($params->{'tag'}) {
          $href .= "&tag=" . $params->{'tag'};
        }
        if ($params->{'source'}) {
          $href .= "&source=" . $params->{'source'};
        }
        if ($params->{'q'}) {
          $href .= "&q=" . $params->{'q'};
        }

        # Generate the "Prev" link.
        if ( $current_page > 1 ) {
            my $new_offset = ( $current_page - 2 ) * $page_size;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $href .= $num;
            $paging_info .= qq|<li><a href="$href">Prev</a></li>|;
        }

        # Generate paging links.
        for my $page_num ( $first_page .. $last_page ) {
            if ( $page_num == $current_page ) {
                $paging_info .= qq|<li class="active"><a href="">$page_num</a></li> |;
            }
            else {
                my $new_offset = ( $page_num - 1 ) * $page_size;
                $href =~ s/(?<=offset=)\d+/$new_offset/;
                $href .= $num;
                $paging_info .= qq|<li><a href="$href">$page_num</a></li>|;
            }
        }

        # Generate the "Next" link.
        if ( $current_page != $last_page ) {
            my $new_offset = $current_page * $page_size;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $href .= $num;
            $paging_info .= qq|<li><a href="$href">Next</a></li>|;
        }

    }

    return $paging_info;
}



sub _clean_tag {
	my ($self, $tag) = @_;
	# ensure lower case
	$tag = lc $tag;
	# sub whitespace & underscores
	$tag =~ s![ _]!-!g;
	# remove dupe hyphens
	$tag =~ s!-+!-!g;
	# ensure only alphanum & hyphen
	$tag =~ s![^-a-z0-9]!!g;
	return $tag;
}

sub _clean_url {
	my ($self, $url) = @_;
	$url =~ s![?&]utm_(?:medium|source|campaign|content)=[^&]+!!gi;
	unless ($url =~ m{^[hf]t?tps?://}gsi) {
		$url = "http://$url";
	}
	return $url;
}


sub _is_valid_uri {
	my ($self, $uri) = @_;
	my $url = Mojo::URL->new($uri);

	# ensure critical pieces
	return unless $url->scheme;
	return unless $url->host;
	# ignore local IP ranges
	my $regexp = create_iprange_regexp(
		qw( 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 )
	);
	return if match_ip($url->host, $regexp);
	return if $url->host =~ m{^localhost|127\.0\.0\.1$};

	unless (Data::Validate::Domain::is_domain($url->host) || Data::Validate::IP::is_ipv4($url->host)){
		return;
	}
	return 1;
}



1;

=head1 NAME

Mojolicious::Plugin::Bkmrx - Bkmrx helpers plugin for bkmrx.org

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('BkxMojo::Plugin::Bkmrx');

=head1 DESCRIPTION

Mojolicious::Plugin::Bkmrx is a collection of helpers for
bkmrx.org


=head1 HELPERS

Mojolicious::Plugin::Bkmrx implements the following helpers.

=head2 paginate

  $self->paginate($total_hits, $offset, $page_size, $href, \%params)

Accepts a list of arguments and produces Bootstrap-friendly pagination HTML.

=head2 clean_tag

  $self->clean_tag($tag)

Applies rules to 'clean' tag inputs

=head2 clean_url

  $self->clean_url($url)

Applies rules to 'clean' URL inputs

=head2 valid_uri

  $self->valid_uri($url)

Tests any given URI for validity.

=head2 register

  $plugin->register(Mojolicious->new);

Register helpers in L<Mojolicious> application.

=cut
