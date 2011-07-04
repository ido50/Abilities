package Abilities;

use Any::Moose 'Role';
use namespace::autoclean;

use Carp;
use Hash::Merge qw/merge/;

our $VERSION = "0.3_01";
$VERSION = eval $VERSION;

# ABSTRACT: Simple, hierarchical user authorization for web applications, with optional support for plan-based (paid) services.

=head1 NAME

Abilities - Simple, hierarchical user authorization for web applications, with optional support for plan-based (paid) services.

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

=head2 (PAID) SUBSCRIPTION-BASED WEB SERVICES

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

has 'abilities' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

=head1 PROVIDED METHODS

Classes that consume this role will have the following methods available
for them:

=head2 can_perform( $action, [ $constraint ] )

=cut

sub can_perform {
	my ($self, $action, $constraint) = @_;

	# a super-user/super-role can do whatever they want
	return 1 if $self->is_super;

	# return false if user/role doesn't have that ability
	return unless $self->abilities->{$action};

	# user/role has ability, but is there a constraint?
	if ($constraint && $constraint ne '_all_') {
		# return true if user/role's ability is not constrained
		return 1 if !ref $self->abilities->{$action};
		
		# it is constrained (or at least it should be, let's make
		# sure we have an array-ref of constraints)
		if (ref $self->abilities->{$action} eq 'ARRAY') {
			return 1 if $constraint eq '_any_';	# caller wants to know if
								# user/role has any constraint,
								# which we now know is true
			foreach (@{$self->abilities->{$action}}) {
				return 1 if $_ eq $constraint;
			}
			return; # constraint not met
		} else {
			carp "Expected an array-ref of constraints for action $action, received ".ref($self->abilities->{$action}).", returning false.";
			return;
		}
	} else {
		# no constraint, make sure user/role's ability is indeed
		# not constrained
		return if ref $self->abilities->{$action}; # implied: ref == 'ARRAY', thus constrained
		return 1; # not constrained
	}
}

=head2 assigned_role( $role_name )

This method receives a role name and returns a true value if the user/role
is a direct member of the provided role. Only direct membership is checked,
so the user/role must be specifically assigned to the provided role, and
not to a role that inherits from that role (see L</"inherits_from_role( $role )">
instead).

=head2 takes_from( $role_name )

=head2 belongs_to( $role_name )

The above two methods are the same as C<assigned_role()>. Since version
0.3 they are deprecated, and using them will issue a deprecation warning.
They will be removed in future versions.

=cut

sub assigned_role {
	my ($self, $role) = @_;

	return unless $role;

	foreach ($self->roles) {
		return 1 if $_->name eq $role;
	}

	return;
}

sub takes_from {
	carp __PACKAGE__.'::takes_from() is deprecated, please use assigned_role() instead.';
	return shift->assigned_role(@_);
}

sub belongs_to {
	carp __PACKAGE__.'::belongs_to() is deprecated, please use assigned_role() instead.';
	return shift->assigned_role(@_);
}

=head2 does_role( $role_name )

Receives the name of a role, and returns a true value if the user/role
inherits the abilities of the provided role. This method takes inheritance
into account, so if a user was directly assigned to the 'admins' role,
and the 'admins' role inherits from the 'devs' role, then C<does_role('devs')>
will return true for that user (while C<assigned_role('devs')> returns false).

=head2 inherits_from_role( $role_name )

This method is exactly the same as C<does_role()>. Since version 0.3 it
is deprecated and using it issues a deprecation warning. It will be removed
in future versions.

=cut

sub does_role {
	my ($self, $role) = @_;

	return unless $role;

	foreach ($self->roles) {
		return 1 if $_->name eq $role || $_->does_role($role);
	}

	return;
}

sub inherits_from_role {
	carp __PACKAGE__.'::inherits_from_role() is deprecated, please use does_role() instead.';
	return shift->does_role(@_);
}

=head1 INTERNAL METHODS

These methods are only to be used internally.

=head2 _build_abilities()

=cut

sub _build_abilities {
	my $self = shift;

	my $abilities = {};

	# load direct actions granted to this user/role
	foreach ($self->actions) {
		# is this action constrained/scoped?
		unless (ref $_) {
			$abilities->{$_} = 1;
		} elsif (ref $_ eq 'ARRAY' && scalar @$_ == 2) {
			$abilities->{$_->[0]} = [$_->[1]];
		} else {
			carp "Can't handle action of reference ".ref($_);
		}
	}

	# load actions from roles this user/role consumes
	my @hashes = map { $_->abilities } $self->roles;

	# merge all abilities
	while (scalar @hashes) {
		$abilities = merge($abilities, shift @hashes);
	}

	return $abilities;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50 dot net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-abilities at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Abilities>. I will be notified, and then you'll
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

Copyright 2010-2011 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
