package Abilities::Features;

use Moose::Role;
use namespace::autoclean;

requires 'plans';
requires 'features';

=head1 NAME

Abilities::Features - Extends Abilities with plan management for subscription-based web services.

=head1 SYNOPSIS

	# use one of the Abilities base classes, for example in a
	# DBIx::Class schema

	package MyApp::Schema::Result::User;
	use base qw/Abilities::DBIC/;

	# then check authorization somewhere in your code (in this example
	# a L<Catalyst> controller):

	# get user from the Catalyst context
	my $user = $c->user;
	
	# check if the user is able to do something
	if ($user->can_perform('something')) {
		do_something();
	} else {
		my @abilities = $user->abilities;
		die "Hey you can't do that, you can only do ", join(', ', @abilities);
	}

=head1 DESCRIPTION

Abilities is a simple mechanism for authorizing them to perform certain
actions in your code. This is an extension of the familiar role-based
access control that is common in various systems and frameworks like L<Catalyst>
(See L<Catalyst::Plugin::Authorization::Roles> for the role-based
implementation and L<Catalyst::Plugin::Authorization::Abilities>
for the ability-based implementation that uses this module).

As opposed to the role-based access control - where users are allowed access
to a certain feature (here called 'action') only through their association
to a certain role that is hard-coded in the program's code - in ability-based
acccess control, a list of actions is assigned to every user, and they are
only allowed to perform these actions. Actions are not assigned by the
developer during development, but rather by the end-user during deployment.
This allows for much more flexibility, and also speeds up development,
as you (the developer) do not need to think about who should be allowed
to perform a certain action, and can easily grant access later on after
deployment (assuming you're also the end-user).

Abilities to perform certain actions can be given to a user specifically, or
via roles the user can assume (as in role-based access control). For example,
if user 'user01' is a member of role 'admin', and this user wishes to perform
some action, for example 'delete_foo', then they will only be able to do
so if the 'delete_foo' ability was given to either the user itself or the
'admin' role itself. Furthermore, roles can be assigned other roles; for
example, roles 'mods' and 'editors' can be assigned _inside_ role 'mega_mods'.
Users of the 'mega_mods' role will assume all actions owned by the 'mods'
and 'editors' roles.

A commonly known use-case for this type of access control is message boards,
where the administrator might wish to create roles with certain actions
and associate users with the roles (more commonly called 'user groups');
for example, the admin can create an 'editor' role, giving users of this
role the ability to edit and delete posts, but not any other administrative
action. So in essence, this type of access control relieves the developer
from deciding who gets to do what and passes these decisions to the
end-user, which might be necessary in certain situations.

=head1 METHODS

=head2 new( [%options] )

Creates a new instance of the Abilities::Features module. Optionally,
an options hash (or hash-ref) can be provided. Currently only the 'super_user_id'
options is supported, which defines the super user's ID; defaults to 1.

=head2 has_feature( $feature | @features )

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

Returns a list of all features that a customer/plan has, either due to
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

    perldoc Abilities

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
