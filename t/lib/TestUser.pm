package TestUser;

use Moo;
use namespace::autoclean;

has 'name' => (
	is => 'ro',
	required => 1
);

has 'actions' => (
	is => 'ro',
	default => sub { [] }
);

has 'roles' => (
	is => 'ro',
	default => sub { [] }
);

has 'is_super' => (
	is => 'ro',
	default => sub { 0 }
);

with 'Abilities';

around qw/actions roles/ => sub {
	my ($orig, $self) = @_;

	return @{$self->$orig || []};
};

1;
