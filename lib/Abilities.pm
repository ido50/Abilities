package Abilities;

use Moose::Role;
use namespace::autoclean;

# ABSTRACT: Simple, hierarchical user authorization for web applications, with optional support for plan-based paid services.

=head1 NAME

Abilities - Simple, hierarchical user authorization for web applications, with optional support for plan-based paid services.

=head1 SYNOPSIS

	package User;
	
	use Moose;
	with 'Abilities';
	
	# ... define required methods ...
	
	# somewhere else in your code:

	# get a user object that consumed the Abilities role
	my $user = MyApp->get_user('username'); # $user is a User object
		
	# check if the user is able to do something
	if ($user->can_perform('something')) {
		do_something();
	} else {
		die "Hey you can't do that, you can only do ", join(', ', $user->abilities);
	}

=head1 DESCRIPTION

Abilities is a simple yet powerful mechanism for authorizing users of web
applications to perform certain actions in the app's code. This is an
extension of the familiar role-based access control that is common in
various systems and frameworks like L<Catalyst> (See L<Catalyst::Plugin::Authorization::Roles>
for the role-based implementation and L<Catalyst::Plugin::Authorization::Abilities>
for the ability-based implementation that inspired this module).

As opposed to the role-based access control - where users are allowed access
to a certain feature (here called 'action') only through their association
to a certain role that is hard-coded in the program's code - in ability-based
acccess control, a list of actions is assigned to every user, and they are
only allowed to perform these actions. Actions are not assigned by the
developer during development, but rather by the end-user during deployment.
This allows for much more flexibility, and also speeds up development,
as you (the developer) do not need to think about who should be allowed
to perform a certain action, and can easily grant access later-on after
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

The Abilities module is implemented as a L<Moose role|Moose::Role>. In order
to be able to use this mechanism, web applications must implement a user
management system that will consume this role. More specifically, a user
class and a role class must be implemented, consuming this role. L<Entities>
is a reference implementation that can be used by web applications, or
just as an example of an ability-based authorization system. L<Entities::User>
and L<Entities::Role> are the user and role classes that consume the Abilities
role in the Entities distribution.

=head2 PAID, SUBSCRIPTION-BASED WEB SERVICES

Apart from the scenario described above, this module also provides optional
support for subscription-based web services, such as those where customers
subscribe to a certain paid (or free, doesn't matter) plan from a list
of available plans (GitHub is an example of such a service). This functionality
is also implemented as a role, in the L<Abilities::Features> module provided
with this distribution. Read its documentation for detailed information.

=head1 REQUIRED METHODS

Classes that consume this role are required to implement the following
methods:

=head2 roles()

Returns a list of all roles that a user object belongs to, or a role object
inherits from. The list must contain references to the role objects, not
just their names.

=cut

requires 'roles';

=head2 actions()

Returns a list of all actions that a user object has been explicitely granted,
or that a role object has been granted. The list must contain references
to the action objects, not just their names.

=cut

requires 'actions';

=head2 is_super()

This is a boolean attribute that both user and role objects should have.
If a user/role object has a true value for this attribute, then they
will be able to perform any action, even if it wasn't granted to them.

=cut

requires 'is_super';

=head1 PROVIDED METHODS

Classes that consume this role will have the following methods available
for them:

=head2 can_perform( $action_name | @action_names )

Receives the name of an action (or names of actions), and returns a true
value if the user/role can perform the provided action(s). If more than
one actions are passed, a true value will be returned only if the user/role
can perform ALL of these actions.

=cut

sub can_perform {
	my $self = shift;

	# a super-user/super-role can do whatever they want
	return 1 if $self->is_super;

	ACTION: foreach (@_) {
		# Check specific user abilities
		foreach my $act ($self->actions) {
			next ACTION if $act->name eq $_; # great, we can do that
		}
		# Check user abilities via roles
		foreach my $role ($self->roles) {
			next ACTION if $role->can_perform($_); # great, we can do that
		}
		
		# if we've reached this spot, the user/role cannot perform
		# this action, so return a false value
		return;
	}

	# if we've reached this spot, the user/role can perform all of
	# the requested actions, so return true
	return 1;
}

=head2 belongs_to( $role_name | @role_names )

=head2 takes_from( $role_name | @role_names )

The above two methods are actually the same. The names are meant to differentiate
between user objects (first case) and role objects (second case).

These methods receive a role name (or names). In case of a user object,
the method will return a true value if the user is a direct member of the
provided role. In case multiple role names were provided, a true value will
be returned only if the user is a member of ALL of these roles. Only direct
association is checked, so the user must be specifically assigned to the
provided role, and not to a role that inherits from that role (see C<inherits_from_role()>
instead.

In case of a role object, this method will return a true value if the role
directly consumes the abilities of the provided role. In case multiple role
names were provided, a true value will be returned only if the role directly
consumes ALL of these roles. Like in case of a user, only direct association
is checked, so inheritance doesn't count.

=cut

sub belongs_to {
	my $self = shift;

	ROLE: foreach (@_) {
		foreach my $role ($self->roles) {
			next ROLE if $role->name eq $_; # great, the user/role belongs to this role
		}
		
		# if we've reached this spot, the user/role does not belong to
		# the role, so return a false value
		return;
	}

	# if we've reached this spot, the user belongs to the rule,
	# so return true.
	return 1;
}

sub takes_from {
	shift->belongs_to(@_);
}

=head2 inherits_from_role( $role_name | @role_names )

Receives the name of a role (or names of roles), and returns a true value
if the user/role inherits the abilities of the provided role. If more than
one roles are passed, a true value will be returned only if the user/role
inherits from ALL of these roles.

This method takes inheritance into account, so if a user was directly assigned
to the 'admins' role, and the 'admins' role inherits from the 'devs' role,
then inherits_from_role('devs') will return true for that user.

=cut

sub inherits_from_role {
	my $self = shift;

	ROLE: foreach (@_) {
		foreach my $role ($self->roles) {
			next ROLE if $role->name eq $_; # great, we inherit this
			next ROLE if $role->inherits_from_role($_); # great, we inherit this
		}
		
		# if we'e reached this spot, we do not inherit this role
		# so return false
		return;
	}
	
	# if we've reached this spot, we inherit all the supplied roles,
	# so return a true value
	return 1;
}

=head2 all_abilities()

Returns a list of all actions that a user/role can perform, either due to
direct association or due to inheritance.

=cut

sub all_abilities {
	keys %{$_[0]->_all_abilities()};
}

=head1 INTERNAL METHODS

These methods are only to be used internally.

=head2 _all_abilities()

=cut

sub _all_abilities {
	my $self = shift;

	my $actions = {};
	foreach my $act ($self->actions) {
		$actions->{$act->name} = 1;
	}
	foreach my $role ($self->roles) {
		my $role_acts = $role->_all_abilities;
		map { $actions->{$_} = $role_acts->{$_} } keys %$role_acts;
	}

	return $actions;
}

=head1 TODO

=over

=item * Create tests

Create tests for these roles. Right now the only way this is actually
tested is through the L<Entities> distribution tests.

=item * Catalyst::Plugin::Authorization::Abilities

Find a way to make L<Catalyst::Plugin::Authorization::Abilities> use
this role.

=back

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
