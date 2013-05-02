package Abilities::Features;

# ABSTRACT: Extends Abilities with plan management for subscription-based web services.

use Moo::Role;
use namespace::autoclean;

use Carp;
use Hash::Merge qw/merge/;

our $VERSION = "0.4";
$VERSION = eval $VERSION;

=head1 NAME

Abilities::Features - Extends Abilities with plan management for subscription-based web services.

=head1 SYNOPSIS

	package Customer;
	
	use Moose; # or Moo
	with 'Abilities::Features';
	
	# ... define required methods ...
	
	# somewhere else in your code:

	# get a customer object that consumed the Abilities::Features role
	my $customer = MyApp->get_customer('some_company');
		
	# check if the customer has a certain feature
	if ($customer->has_feature('ssl_encryption')) {
		&initiate_https_connection();
	} else {
		&initiate_http_connection();
	}

=head1 DESCRIPTION

This L<Moo role|Moo::Role> extends the ability-based authorization
system defined by the L<Abilities> module with customer and plan management
for subscription-based web services. This includes paid services, where
customers subscribe to a plan from a list of available plans, each plan
with a different set of features. Examples of such a service are GitHub
(a Git revision control hosting service, where customers purchase a plan
that provides them with different amounts of storage, SSH support, etc.)
and MailChimp (email marketing service where customers purchase plans
that provide them with different amounts of monthly emails to send and
other features).

The L<Abilities> role defined three entities: users, roles and actions.
This role defines three more entities: customers, plans and features.
Customers are organizations, companies or individuals that subscribe to
your web service. They can subscribe to any number of plans, and thus be
provided with the features of these plans. The users from the Abilities
module will now be children of the customers. They still go on being members
of roles and performing actions they are granted with, but now possibly
only within the scope of their parent customer, and to the limits defined
in the customer's plan. Plans can inherit features from other plans, allowing
for defining plans faster and easier.

Customer and plan objects are meant to consume the Abilities::Features
role. L<Entities> is a reference implementation of both the L<Abilities> and
L<Abilities::Features> roles. It is meant to be used as-is by web applications,
or just as an example of how a user management and authorization system
that consumes these roles might look like. L<Entities::Customer> and
L<Entities::Plan> are customer and plan classes that consume this role.

Just like in L<Abilities>, features can be constrained. For more info,
see L<Abilities/"CONSTRAINTS">.

More information about how these roles work can be found in the L<Entities>
documentation.

=head1 REQUIRED METHODS

Customer and plan classes that consume this role are required to provide
the following methods:

=head2 plans()

This method returns a list of all plan names that a customer has subscribed to,
or that a plan inherits from.

NOTE: In previous versions, this method was required to return
an array of plan objects, not a list of plan names. This has been changed
in version 0.3.

=cut

requires 'plans';

=head2 features()

This method returns a list of all feature names that a customer has explicitely
been given, or that a plan has.

NOTE: In previous versions, this method was required to return
an array of feature objects, not a list of feature names. This has been changed
in version 0.3.

=cut

requires 'features';

=head1 PROVIDED ATTRIBUTES

=head2 available_features

Holds a hash-ref of all features available to a customer/plan object, after
consolidating features from inherited plans (recursively) and directly granted.
Keys of this hash-ref will be the names of the features, values will either be
1 (for yes/no features), or a single-item array-ref with a name of a constraint
(for constrained features).

=cut

has 'available_features' => (
	is => 'lazy',
	isa => sub { die "abilities must be a hash-ref" unless ref $_[0] eq 'HASH' },
);

=head1 METHODS

Classes that consume this role will have the following methods provided
to them:

=head2 has_feature( $feature_name, [ $constraint ] )

Receives the name of a feature, and possibly a constraint, and returns a
true value if the customer/plan has that feature, false value otherwise.

=cut

sub has_feature {
	my ($self, $feature, $constraint) = @_;

	# return false if customer/plan does not have that feature
	return unless $self->available_features->{$feature};

	# customer/plan has feature, but is there a constraint?
	if ($constraint) {
		# return true if customer/plan's feature is not constrained
		return 1 if !ref $self->available_features->{$feature};
		
		# it is constrained (or at least it should be, let's make
		# sure we have an array-ref of constraints)
		if (ref $self->available_features->{$feature} eq 'ARRAY') {
			foreach (@{$self->available_features->{$feature}}) {
				return 1 if $_ eq $constraint;
			}
			return; # constraint not met
		} else {
			carp "Expected an array-ref of constraints for feature $feature, received ".ref($self->available_features->{$feature}).", returning false.";
			return;
		}
	} else {
		# no constraint, make sure customer/plan's feature is indeed
		# not constrained
		return if ref $self->available_features->{$feature}; # implied: ref == 'ARRAY', thus constrained
		return 1; # not constrained
	}
}

=head2 in_plan( $plan_name )

Receives the name of plan and returns a true value if the user/customer
is a direct member of the provided plan(s). Only direct association is
checked, so the user/customer must be specifically assigned to that plan,
and not to a plan that inherits from that plan (see L</"inherits_plan( $plan_name )">
instead).

=cut

sub in_plan {
	my ($self, $plan) = @_;

	return unless $plan;

	foreach ($self->plans) {
		return 1 if $_->name eq $plan;
	}

	return;
}

=head2 inherits_plan( $plan_name )

Returns a true value if the customer/plan inherits the features of
the provided plan(s). If a customer belongs to the 'premium' plan, and
the 'premium' plan inherits from the 'basic' plan, then C<inherits_plan('basic')>
will be true for that customer, while C<in_plan('basic')> will be false.

=head2 inherits_from_plan( $plan_name )

This method is exactly the same as C<inherits_plan()>. Since version 0.3
it is deprecated, and using it issues a deprecation warning. It will be
removed in future versions.

=cut

sub inherits_plan {
	my ($self, $plan) = @_;

	return unless $plan;

	foreach ($self->plans) {
		return 1 if $_->name eq $plan || $_->inherits_plan($plan);
	}

	return;
}

sub inherits_from_plan {
	carp __PACKAGE__.'::inherits_from_plan() is deprecated, please use inherits_plan() instead.';
	return shift->inherits_plan(@_);
}

##### INTERNAL METHODS #####

sub _build_available_features {
	my $self = shift;

	my $features = {};

	# load direct features granted to this customer/plan
	foreach ($self->features) {
		# is this features constrained?
		unless (ref $_) {
			$features->{$_} = 1;
		} elsif (ref $_ eq 'ARRAY' && scalar @$_ == 2) {
			$features->{$_->[0]} = [$_->[1]];
		} else {
			carp "Can't handle feature of reference ".ref($_);
		}
	}

	# load features from plans this customer/plan has
	my @hashes = map { $_->available_features } $self->plans;

	# merge all features
	while (scalar @hashes) {
		$features = merge($features, shift @hashes);
	}

	return $features;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50 dot net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-abilities at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Abilities>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Abilities::Features

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Abilities>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Abilities>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Abilities>

=item * Search CPAN

L<http://search.cpan.org/dist/Abilities/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010-2013 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
