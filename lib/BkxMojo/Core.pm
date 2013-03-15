package BkxMojo::Core;
use Mojo::Base 'Mojolicious::Controller';

sub welcome {
	my $self = shift;
	return $self->redirect_to('/bkmrx') if $self->session('user_id');
	$self->render();
}

sub about {
	my $self = shift;
	$self->render();
}

sub tos {
	my $self = shift;
	$self->render();
}

sub privacy {
	my $self = shift;
	$self->render();
}

sub contact {
	my $self = shift;
	$self->render();
}

1;