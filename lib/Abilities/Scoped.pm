package Abilities::Scoped;

use Moose::Role;
use namespace::autoclean;

# ABSTRACT: Scoped version of the Abilities user authorization system.

=head1 NAME

Abilities::Scoped - Scoped version of the Abilities user authorization system.

=head1 SYNOPSIS

	package User;
	
	use Moose;
	with 'Abilities::Scoped';
	
	# ... define required methods ...
	
	# somewhere else in your code:

	# get a user object that consumed the Abilities role
	my $user = MyApp->get_user('username'); # $user is a User object
		
	# check if the user is able to do something in the scope of the app
	if ($user->can_perform('app', 'something')) {
		do_something();
	} else {
		die "Hey you can't do that in the app, you can only do ", join(', ', $user->abilities('app'));
	}

=head1 DESCRIPTION

This L<Moose role|Moose::Role> defines a scoped version of the L<Abilities>
role for hierarchial user authorization. In this version, users are granted
abilities to perform actions within certain scopes. This allows building
a much more comprehensive user authorization system for your app.

For example, say you're creating a content-rich website that has different
sections such as 'news', 'video archive', 'picture galleries', etc. You might
want to assign responsibilities on these sections for different users. Each
section is, therefore, a scope. A user can be granted the ability to 
'do_something' in the 'news' scope, or the 'video archive' scope, or both.
But the 'do_something' action is different in each scope. Global actions,
such as creating users and maintenance actions, can be thought of as
belonging to a 'global', or 'app' scope.

This can be taken much further. Say you're building a hosted blogging
platform. Users should be able to create and edit posts only in their
own blogs, otherwise chaos will erupt. Checking that a user has the ability
to 'edit_post' isn't sufficient, because their ability to do so should be
limited within their own scope, i.e. their own blogs. So, if there's a
blog called 'my_blog' hosted on your platform, that in order to be able
to edit a post in that blog, a user must have the 'edit_post' ability
in the 'my_blog' scope.

Abilities::Scoped requires implementing your user-base a little differently
than L<Abilities>. The same three methods are required - C<actions()>, C<roles()>
and is_super()> - but now they require a scope argument, which turns them into
C<actions( $scope )>, C<roles( $scope )> and C<is_super( $super )>. Notice
that C<is_super()> is now scoped as well. This is interesting. In L<Abilities>,
a super-user (or super-role) are allowed to perform whatever they want.
Here, their "super-powers" can also be limited to some scope(s). So, a certain
user can be a super-user in the 'my_blog' scope, allowing them to perform
any defined action in that scope. Again, you can make someone a super user
in a global scope (e.g. 'global' or 'app'), this is purely semantics.

=head3 ADVANCED USAGE

By default, Abilities::Scoped treats scopes as names (i.e. scalars),
and while this may be sufficient for a lot of cases, it isn't flexible or
comfortable enough. Say a blog hosted on your blogging platform has many
users who were granted abilities on it (and some of them even on other blogs).
Storing this information in a database (or whatever backend you use, see
L<Entities> for a reference implementation) can be difficult, inconvenient
or even impossible. Should you store a list of actions/roles for each user
in each scope? That can be a major pain in the ass.

Sometimes, therefore, it would make much more sense to _calculate_ a user's
ability to perform an action within a certain scope instead of looking for
it in a store. For example, consider a case in which L<Abilities::Scoped>
is paired with L<Abilities::Features>, again in our blogging platform.
A customer entity has a blog, and we want to limit the child users of that
customer to perform actions only within that blog. In the store, we can
grant these users the ability to perform 'edit_post' in a 'customer_blog'
scope instead of using a very-specific scope name (i.e. the specific blog name).
The, in our app's code, when some user requests authorization to perform
the 'edit_post' action on a certain blog, we first make sure this blog
belongs to the user's parent customer entity, and then check their ability
to perform 'edit_post':

	if ($user->can_perform({ blog => $blog_id, post => $post_id }, 'edit_post')) {
		# ... edit the post ... #
	} else {
		# ... you can't do that ... #
	}

Here, we're not passing the C<can_perform()> method a scope name, but a
hash-ref. You can pass anything you want, actually, but you'd have to
override C<can_perform()> with your own method. For example, you can do
this in your user class:

	package MyApp::User;

	use Moose;
	with 'Abilities::Scoped';

	override 'can_perform' => sub {
		my ($self, $scope, $action) = @_; # $self is the user object, obviously

		# find the blog
		my $blog = MyApp->load_blog($scope->{blog});
		
		# does this blog belong to the user's parent customer?
		return unless $blog->customer_id == $self->customer_id;
		
		# it does belong, now let's make sure the user do the
		# requested action in this scope
		return super('customer_blog', $action);
	};

Of course, you can use your own imagination and implement whatever kind
of checking you want. Since the whole Abilities system is just Moose roles,
you can take advantage of Moose's flexibility and really do some neat stuff.

=head1 REQUIRED METHODS

Classes that consume this role are required to implement the following
methods:

=head2 roles( $scope )

Returns a list of all roles that a user object belongs to, or a role object
inherits from, in a certain scope. The list must contain references to
the role objects, not just their names.

=cut

requires 'roles';

=head2 actions( $scope )

Returns a list of all actions that a user object has been explicitely granted,
or that a role object has been granted, in a certain scope. The list must
contain references to the action objects, not just their names.

=cut

requires 'actions';

=head2 is_super( $scope )

This is a boolean attribute that both user and role objects should have.
If a user/role object has a true value for this attribute in a certain
scope, then they will be able to perform any action in that scope, even
if it wasn't granted to them.

=cut

requires 'is_super';

=head1 PROVIDED METHODS

Classes that consume this role will have the following methods available
for them:

=head2 can_perform( $scope, $action_name | @action_names )

Receives a scope and the name of an action (or names of actions), and
returns a true value if the user/role can perform the provided action(s)
in that scope. If more than one actions are passed, a true value will be
returned only if the user/role can perform ALL of these actions.

=cut

sub can_perform {
	my ($self, $scope) = (shift, shift);

	# a super-user/super-role can do whatever they want
	return 1 if $self->is_super;

	ACTION: foreach (@_) {
		# Check specific user abilities
		foreach my $act ($self->actions($scope)) {
			next ACTION if $act->name eq $_; # great, we can do that
		}
		# Check user abilities via roles
		foreach my $role ($self->roles($scope)) {
			next ACTION if $role->can_perform($scope, $_); # great, we can do that
		}
		
		# if we've reached this spot, the user/role cannot perform
		# this action, so return a false value
		return;
	}

	# if we've reached this spot, the user/role can perform all of
	# the requested actions, so return true
	return 1;
}

=head2 belongs_to( $scope, $role_name | @role_names )

=head2 takes_from( $scope, $role_name | @role_names )

The above two methods are actually the same. The names are meant to differentiate
between user objects (first case) and role objects (second case).

These methods receive a scope and a role name (or names). In case of a user
object, the method will return a true value if the user is a direct member
of the provided role in the required scope. In case multiple role names
were provided, a true value will be returned only if the user is a member
of ALL of these roles. Only direct association is checked, so the user
must be specifically assigned to the provided role, and not to a role
that inherits from that role (see C<inherits_from_role()> instead.

In case of a role object, this method will return a true value if the role
directly consumes the abilities of the provided role in the required scope.
In case multiple role names were provided, a true value will be returned
only if the role directly consumes ALL of these roles. Like in case of a
user, only direct association is checked, so inheritance doesn't count.

=cut

sub belongs_to {
	my ($self, $scope) = @_;

	ROLE: foreach (@_) {
		foreach my $role ($self->roles($scope)) {
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

=head2 inherits_from_role( $scope, $role_name | @role_names )

Receives a scope and the name of a role (or names of roles), and returns
a true value if the user/role inherits the abilities of the provided role
in the required scope. If more than one roles are passed, a true value
will be returned only if the user/role inherits from ALL of these roles.

This method takes inheritance into account, so if a user was directly assigned
to the 'admins' role in the required scope, and the 'admins' role inherits
from the 'devs' role in the same scope, then inherits_from_role($scope, 'devs')
will return true for that user.

=cut

sub inherits_from_role {
	my ($self, $scope) = (shift, shift);

	ROLE: foreach (@_) {
		foreach my $role ($self->roles($scope)) {
			next ROLE if $role->name eq $_; # great, we inherit this
			next ROLE if $role->inherits_from_role($scope, $_); # great, we inherit this
		}
		
		# if we'e reached this spot, we do not inherit this role
		# so return false
		return;
	}
	
	# if we've reached this spot, we inherit all the supplied roles,
	# so return a true value
	return 1;
}

=head2 all_abilities( $scope )

Returns a list of all actions that a user/role can perform in a certain
scope, either due to direct association or due to inheritance.

=cut

sub all_abilities {
	keys %{$_[0]->_all_abilities($_[1])};
}

=head1 INTERNAL METHODS

These methods are only to be used internally.

=head2 _all_abilities()

=cut

sub _all_abilities {
	my ($self, $scope) = @_;

	my $actions = {};
	foreach my $act ($self->actions($scope)) {
		$actions->{$act->name} = 1;
	}
	foreach my $role ($self->roles($scope)) {
		my $role_acts = $role->_all_abilities($scope);
		map { $actions->{$_} = $role_acts->{$_} } keys %$role_acts;
	}

	return $actions;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50 dot net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-abilities at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Abilities>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Abilities::Scoped

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
