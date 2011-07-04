package TestUser;

use Any::Moose;
use namespace::autoclean;

has 'name' => (is => 'ro', isa => 'Str', required => 1);

has 'actions' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'roles' => (is => 'ro', isa => 'ArrayRef', default => sub { [] } );

has 'is_super' => (is => 'ro', isa => 'Bool', default => 0);

with 'Abilities' => { -version => '0.3' };

around qr/^actions|roles$/ => sub {
	my ($orig, $self) = @_;

	return @{$self->$orig || []};
};

__PACKAGE__->meta->make_immutable;
