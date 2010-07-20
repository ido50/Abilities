package Abilities::Features;

use Moose::Role;
use namespace::autoclean;

# ABSTRACT: Extends Abilities with plan management for subscription-based web services.

=head1 NAME

Abilities::Features - Extends Abilities with plan management for subscription-based web services.

=head1 SYNOPSIS

	use Abilities::Features;

	# get a user object that consumed the Abilities role
	my $user = MyApp->get_user('username');
		
	# check if the user is able to do something
	if ($user->can_perform('something')) {
		do_something();
	} else {
		die "Hey you can't do that, you can only do ", join(', ', $user->abilities);
	}

=head1 DESCRIPTION

This L<Moose role|Moose::Role> extends the ability-based authorization
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

More information about how these roles work can be found in the L<Entities>
documentation.

=head1 REQUIRED METHODS

Customer and plan classes that consume this role are required to provide
the following methods:

=head2 plans()

This method returns a list of all plans that a customer has subscribed to,
or that a plan inherits from. The list should have references to the plan
objects, not just their names.

=cut

requires 'plans';

=head2 features()

This method returns a list of all features that a customer has explicitely
been given, or that a plan has. The list should have references to the
feature objects, not just their names.

=cut

requires 'features';

=head1 METHODS

Classes that consume this role will have the following methods provided
to them:

=head2 has_feature( $feature_name | @feature_names )

Returns a true value if the customer/plan has the provided feature or features
associated with it (either via plans or explicitly). If more than one
features are passed, a true value will be returned only if the
customer/plan has ALL of these features.

=cut

sub has_feature {
	my $self = shift;

	FEATURE: foreach (@_) {
		# Check specific features
		foreach my $feature ($self->features) {
			next FEATURE if $feature->name eq $_; # great, we can do that
		}
		# Check features via plans
		foreach my $plan ($self->plans) {
			next FEATURE if $plan->has_feature($_); # great, we can do that
		}
		
		# if we've reached this spot, the user/customer/plan 
		# does not have this feature, so return a false value.
		return;
	}

	# if we've reached this spot, the user/customer/plan has all the
	# requested features, so return a true value
	return 1;
}

=head2 in_plan( $plan_name | @plan_names )

Receives the name of plan (or names of plans), and returns a true value
if the user/customer is a direct member of the provided plan(s). Only
direct association is checked, so the user/customer must be specifically
assigned to that plan, and not to a plan that inherits from that plan
(see C<inherits_from_plan()>). If more than one plans are passed, a true
value will be returned only if the user is a member of ALL of these plans.

=cut

sub in_plan {
	my $self = shift;

	PLAN: foreach (@_) {
		foreach my $plan ($self->plans) {
			next PLAN if $plan->name eq $_; # great, the customer belongs to this plan
		}
		
		# if we've reached this spot, the customer does not belong to
		# the plan, so return a false value
		return;
	}

	# if we've reached this spot, the customer belongs to the plan,
	# so return true.
	return 1;
}

=head2 inherits_from_plan( $role_name | @role_names )

Returns a true value if the customer/plan inherits the features of
the provided plan(s). If more than one plans are passed, a true value will
be returned only if the customer/plan inherits from ALL of these plans.

=cut

sub inherits_from_plan {
	my $self = shift;

	ROLE: foreach (@_) {
		foreach my $plan ($self->plans) {
			next ROLE if $plan->name eq $_; # great, we inherit this
			next ROLE if $plan->inherits_from_plan($_); # great, we inherit this
		}
		
		# if we'e reached this spot, we do not inherit this plan
		# so return false
		return;
	}
	
	# if we've reached this spot, we inherit all the supplied plans,
	# so return a true value
	return 1;
}

=head2 all_features()

Returns a list of all feature names that a customer/plan has, either due to
direct association or due to inheritance.

=cut

sub all_features {
	keys %{$_[0]->_all_features()};
}

=head1 INTERNAL METHODS

These methods are only to be used internally.

=head2 _all_features()

=cut

sub _all_features {
	my $self = shift;

	my $features = {};
	foreach my $feature ($self->features) {
		$features->{$feature->name} = 1;
	}
	foreach my $plan ($self->plans) {
		my $plan_features = $plan->_features;
		map { $features->{$_} = $plan_features->{$_} } keys %$plan_features;
	}

	return $features;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50 dot net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-abilities at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Abilities>.  I will be notified, and then you'll
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

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
