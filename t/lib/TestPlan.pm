package TestPlan;

use Moo;
use namespace::autoclean;

has 'name' => (
	is => 'ro',
	required => 1
);

has 'features' => (
	is => 'ro',
	default => sub { [] }
);

has 'plans' => (
	is => 'ro',
	default => sub { [] }
);

with 'Abilities::Features';

around qw/features plans/ => sub {
	my ($orig, $self) = @_;

	return @{$self->$orig || []};
};

1;
