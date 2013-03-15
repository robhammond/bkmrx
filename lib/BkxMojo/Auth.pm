package BkxMojo::Auth;
use Mojo::Base 'Mojolicious::Controller';

sub login {
	my $self = shift;
	
	if ($self->flash('bk_title') && $self->flash('bk_url')) {
		$self->flash(bk_title => $self->flash('bk_title'));
		$self->flash(bk_url => $self->flash('bk_url'));

		return $self->render(
			template => 'auth/login-minimal',
		);
	}

	if ($self->session('user_id')) {
		return $self->redirect_to('/bkmrx');
	}

	$self->render();
}

1;