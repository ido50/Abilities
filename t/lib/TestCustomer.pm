package TestCustomer;

use Any::Moose;
use namespace::autoclean;

has 'name' => (is => 'ro', isa => 'Str', required => 1);

has 'features' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'plans' => (is => 'ro', isa => 'ArrayRef', default => sub { [] } );

with 'Abilities::Features' => { -version => '0.3_01' };

around qr/^features|plans$/ => sub {
	my ($orig, $self) = @_;

	return @{$self->$orig || []};
};

__PACKAGE__->meta->make_immutable;
