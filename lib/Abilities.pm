package Abilities;

use warnings;
use strict;

$Abilities::SUPER_USER_ID = 1;

=head1 NAME

Abilities - Simple, hierarchical, pluggable user authorization. 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


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

=head2 new()

Creates a new instance of this module.

=cut

sub new {
	bless {}, shift;
}

=head2 can_perform( $user | $role, $action | @actions )

Returns a true value if the user/role can perform the provided action or actions.
If more than one actions are passed, a true value will be returned only
if the user/role can perform ALL of these actions. This is a unified
method that accepts both users and roles.

=cut

sub can_perform {
	my ($self, $obj) = (shift, shift);

	# the super-user can do whatever they want
	return 1 if ref $obj =~ m/User/ && $obj->id == $Abilities::SUPER_USER_ID;

	ACTION: foreach (@_) {
		# Check specific user abilities
		foreach my $act ($obj->actions) {
			next ACTION if $act->name eq $_; # great, we can do that
		}
		# Check user abilities via roles
		foreach my $role ($obj->roles) {
			next ACTION if $self->can_perform($role, $_); # great, we can do that
		}
		
		# if we've reached this spot, the user/role cannot perform
		# this action, so return a false value
		return undef;
	}

	# if we've reached this spot, the user/role can perform all of
	# the requested actions, so return true
	return 1;
}

=head2 belongs_to( $role_name | @role_names )

Returns a true value if the user is a member of the provided role. Only
direct association is checked, so the user must be specifically assigned
to that role, and not to a role that inherits from that role (see
C<inherits_from()>). If more than one roles are passed, a true value
will be returned only if the user is a member of ALL of these roles.

=cut

sub belongs_to {
	my $user = shift;

	ROLE: foreach (@_) {
		foreach my $role ($user->roles) {
			next ROLE if $role->name eq $_; # great, the user belongs to this role
		}
		
		# if we've reached this spot, the user does not belong to
		# the role, so return a false value
		return undef;
	}

	# if we've reached this spot, the user belongs to the rule,
	# so return true.
	return 1;
}

=head2 inherits_from( $role_name | @role_names )

Returns a true value if the user/role inherits the actions of the provided role.
If more than one roles are passed, a true value will be returned only if
the user/role inherits from ALL of these roles.

=cut

sub inherits_from {
	my $obj = shift;

	ROLE: foreach (@_) {
		foreach my $role ($obj->roles) {
			next ROLE if $role->name eq $_; # great, we inherit this
			next ROLE if $role->inherits_from($_); # great, we inherit this
		}
		
		# if we'e reached this spot, we do not inherit this role
		# so return false
		return undef;
	}
	
	# if we've reached this spot, we inherit all the supplied roles,
	# so return a true value
	return 1;
}

=head2 abilities()

Returns a list of all actions that a user/role can perform, either due to
direct association or due to inheritance.

=cut

sub abilities {
	keys %{$_[0]->_abilities};
}

=head1 INTERNAL METHODS

These methods are only to be used internally.

=head2 _abilities()

=cut

sub _abilities {
	my $obj = shift;

	my $actions;
	foreach my $act ($obj->actions) {
		$actions->{$act} = 1;
	}
	foreach my $role ($obj->roles) {
		my $role_acts = $role->_abilities;
		map { $actions->{$_} = $role_acts->{$_} } keys %$role_acts;
	}

	return $actions;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

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
