package Dancer::Session::MongoDB;

# ABSTRACT: MongoDB session backend for Dancer.

use warnings;
use strict;
use vars '$VERSION';
use base 'Dancer::Session::Abstract';
use MongoDB;
use Dancer::Config 'setting';
use Dancer::ModuleLoader;
use Carp;

# singleton for the MongoDB connection
my ($DB, $COLL);

=head1 NAME

Dancer::Session::MongoDB - MongoDB session backend for Dancer.

=head1 SYNOPSIS

	# in your config.yml file:
	session: "MongoDB"
	mongodb_dbname: "myapp_database"
	mongodb_host: "mongo.server.com"	# optional, defaults to 'localhost'
	mongodb_port: 27017			# optional, this is the default
	mongodb_coll: "myapp_sessions"		# optional, defaults to 'sessions'

	# now you can use sessions in your app as described in L<Dancer::Session>.
	# for example:
	session user => params->{user};
	
	...
	
	if (session('user')) {
		my $msg = "Welcome back, ".session('user');
	}

=head1 DESCRIPTION

This module implements a L<MongoDB> based session engine for L<Dancer>
applications. It keeps session data in a L<MongoDB collection|MongoDB::Collection>,
providing you with a simple, easy to setup, yet powerful session backend.

If you're running your Dancer application in a L<PSGI>/L<Plack> environment,
please consider using L<Plack::Session::Store::MongoDB> with
L<Dancer::Session::PSGI> instead.

This module is a subclass of L<Dancer::Session::Abstract>.

=head1 CONFIGURATION

In order to use this session engine, you need to define a few settings in
your app's settings file (or in your app's code):

=over

=item * session

Give this the value "MongoDB" (take care of using this exact capitalization).
This is required.

=item * mongodb_dbname

Give this the name of the MongoDB database to use. This is required.

=item * mongodb_host

The hostname of the server where the MongoDB daemon is running. Optional,
defaults to 'localhost'.

=item * mongodb_port

The port on the host where the MongoDB daemon is listening. Optional,
defaults to 27017 (the default MongoDB port).

=item * mongodb_coll

The name of the collection in which session objects will be stored. Optional,
defaults to 'sessions'.

=back

=head1 CLASS METHODS

=head2 init()

=cut

sub init {
	my $class = shift;

	my $host = setting('mongodb_host') || 'localhost';
	my $port = setting('mongodb_port') || 27017;
	my $db_name = setting('mongodb_dbname')
		|| croak "You must define the name of the MongoDB database for session use in the app's settings (parameter 'mongodb_dbname'.";
	my $coll_name = setting('mongodb_coll') || 'sessions';

	my $conn = MongoDB::Connection->new(host => $host, port => $port);
	$DB = $conn->get_database($db_name);
	$COLL = $DB->get_collection($coll_name);

    # rodrigo: relies on Mongo for a session id
    # optionally could use this: $class->SUPER::init();
    $class->id( "" . $COLL->insert({}) );
}

=head2 create()

Creates a new session object and returns it.

=cut

sub create {
	$_[0]->new->flush;
}

=head2 retrieve( $id )

Returns the session object whose ID is C<$id> if exists, otherwise returns
a false value.

=cut

sub retrieve($$) {
	my ($class, $id) = @_;

    my $obj = $COLL->find_one({ _id => MongoDB::OID->new( value => $id ) }) || return;

	$obj->{id} = "" . delete $obj->{_id};

	return bless $obj, $class;
}

=head1 OBJECT METHODS

=head2 flush()

Writes the session object to the MongoDB database. If a database error
occurs and the object is not saved, this method will die.

=cut

sub flush {
	my $self = shift;

	my %obj = %$self;
	delete $obj{id};

	$COLL->update({ _id => MongoDB::OID->new( value => $self->id ) }, \%obj, { safe => 1, upsert => 1 })
		|| croak "Failed writing session to MongoDB database: ".$DB->last_error;

	return $self;
}

=head2 destroy()

Removes the session object from the MongoDB database. If a database error
occurs and the object is not removed, this method will generate a warning.

=cut

sub destroy {
	my $self = shift;

	$COLL->remove({ _id => MongoDB::OID->new( value => $_[0]->id ) }, { safe => 1, just_one => 1 })
		|| carp "Failed removing session from MongoDB database: ".$DB->last_error;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50 dot net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dancer-session-mongodb at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dancer-Session-MongoDB>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Session::MongoDB

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dancer-Session-MongoDB>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dancer-Session-MongoDB>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer-Session-MongoDB>

=item * Search CPAN

L<http://search.cpan.org/dist/Dancer-Session-MongoDB/>

=back

=head1 ACKNOWLEDGEMENTS

Alexis Sukrieh, author of L<Dancer::Session::Memcached>, on which this
module is based.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;


