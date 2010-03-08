# Declare our package
package POE::Component::SimpleDBI::PoolManager;
use strict; use warnings;

# Initialize our version $LastChangedRevision: 35 $
use vars qw( $VERSION );
$VERSION = '0.01';

# Import what we need from the POE namespace
use POE;

# Automatically generate our states, thanks!
use base 'POE::Session::AttributeBased';

# We use SimpleDBI, no duh
use POE::Component::SimpleDBI;

# Set some constants
BEGIN {
	# Debug fun!
	if ( ! defined &DEBUG ) {
		## no critic
		eval "sub DEBUG () { 0 }";
		## use critic
	}
}

# Set things in motion!
sub new {
	# Get our arguments
	my( $type, $ALIAS, $PREPARE_CACHED, %opts ) = @_;

	# Get the session alias
	if ( ! defined $ALIAS ) {
		# Debugging info...
		if ( DEBUG() ) {
			warn 'using default ALIAS = SimpleDBI-PoolManager';
		}

		# Set the default
		$ALIAS = 'SimpleDBI-PoolManager';
	}

	# Should we disable prepare_cached?
	if ( ! defined $PREPARE_CACHED ) {
		# Debugging info...
		if ( DEBUG() ) {
			warn 'setting default PREPARE_CACHED = 1';
		}

		$PREPARE_CACHED = 1;
	} else {
		# make sure we have a simple boolean
		if ( $PREPARE_CACHED ) {
			$PREPARE_CACHED = 1;
		} else {
			$PREPARE_CACHED = 0;
		}
	}

	# Sanity check the options
	my( $MIN, $MAX, $SPARE, $CHILD_MAXREQ, $CHILD_MAXTIME, $CHILD_CREATE, $CHILD_KILL, $CHILD_RECONNECT, $CHILD_TRIES );
	if ( exists $opts{'pool_min'} and defined $opts{'pool_min'} ) {
		if ( $opts{'pool_min'} !~ /^\d+$/ ) {
			warn 'pool_min isn\'t an integer';

			$opts{'pool_min'} = 5;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_min = 5';
		}

		$opts{'pool_min'} = 5;
	}
	$MIN = delete $opts{'pool_min'};

	if ( exists $opts{'pool_max'} and defined $opts{'pool_max'} ) {
		if ( $opts{'pool_max'} !~ /^\d+$/ ) {
			warn 'pool_max isn\'t an integer';

			$opts{'pool_max'} = 10;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_max = 10';
		}

		$opts{'pool_max'} = 10;
	}
	$MAX = delete $opts{'pool_max'};

	if ( exists $opts{'pool_spare'} and defined $opts{'pool_spare'} ) {
		if ( $opts{'pool_spare'} !~ /^\d+$/ ) {
			warn 'pool_spare isn\'t an integer';

			$opts{'pool_spare'} = 2;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_spare = 2';
		}

		$opts{'pool_spare'} = 2;
	}
	$SPARE = delete $opts{'pool_spare'};

	if ( exists $opts{'pool_child_maxreq'} and defined $opts{'pool_child_maxreq'} ) {
		if ( $opts{'pool_child_maxreq'} !~ /^\d+$/ ) {
			warn 'pool_child_maxreq isn\'t an integer';

			$opts{'pool_child_maxreq'} = 0;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_maxreq = 0 ( infinite )';
		}

		$opts{'pool_child_maxreq'} = 0;
	}
	$CHILD_MAXREQ = delete $opts{'pool_child_maxreq'};

	if ( exists $opts{'pool_child_maxtime'} and defined $opts{'pool_child_maxtime'} ) {
		if ( $opts{'pool_child_maxtime'} !~ /^\d+$/ ) {
			warn 'pool_child_maxtime isn\'t an integer';

			$opts{'pool_child_maxtime'} = 0;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_maxtime = 0 ( infinite )';
		}

		$opts{'pool_child_maxtime'} = 0;
	}
	$CHILD_MAXTIME = delete $opts{'pool_child_maxtime'};

	if ( exists $opts{'pool_child_reconnect'} and defined $opts{'pool_child_reconnect'} ) {
		if ( $opts{'pool_child_reconnect'} !~ /^\d+$/ ) {
			warn 'pool_child_reconnect isn\'t an integer';

			$opts{'pool_child_reconnect'} = 5;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_reconnect = 5';
		}

		$opts{'pool_child_reconnect'} = 5;
	}
	$CHILD_RECONNECT = delete $opts{'pool_child_reconnect'};

	if ( exists $opts{'pool_child_tries'} and defined $opts{'pool_child_tries'} ) {
		if ( $opts{'pool_child_tries'} !~ /^\d+$/ ) {
			warn 'pool_child_tries isn\'t an integer';

			$opts{'pool_child_tries'} = 0;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_tries = 5';
		}

		$opts{'pool_child_tries'} = 5;
	}
	$CHILD_TRIES = delete $opts{'pool_child_tries'};

	if ( exists $opts{'pool_child_create'} and defined $opts{'pool_child_create'} ) {
		if ( $opts{'pool_child_create'} !~ /^\d+$/ ) {
			warn 'pool_child_create isn\'t an integer';

			$opts{'pool_child_create'} = 1;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_create = 1';
		}

		$opts{'pool_child_create'} = 1;
	}
	$CHILD_CREATE = delete $opts{'pool_child_create'};

	if ( exists $opts{'pool_child_kill'} and defined $opts{'pool_child_kill'} ) {
		if ( $opts{'pool_child_kill'} !~ /^\d+$/ ) {
			warn 'pool_child_kill isn\'t an integer';

			$opts{'pool_child_kill'} = 30;
		}
	} else {
		if ( DEBUG() ) {
			warn 'setting default pool_child_kill = 30';
		}

		$opts{'pool_child_kill'} = 30;
	}
	$CHILD_KILL = delete $opts{'pool_child_kill'};

	# Anything left over is unrecognized
	if ( DEBUG() ) {
		if ( keys %opts > 0 ) {
			warn 'Unrecognized options were present in POE::Component::SimpleDBI::PoolManager->new -> ' . join( ', ', keys %opts );
		}
	}

	# FIXME add sanity checks like $MIN > $MAX and etc

	# Create a new session for ourself
	POE::Session->create(
		'heap'		=>	{
			# our pool ( keyed by session id )
			'pool'		=>	{},
			'poolCounter'	=>	0,

			# pool options
			'pool_min'		=>	$MIN,
			'pool_max'		=>	$MAX,
			'pool_spare'		=>	$SPARE,
			'pool_child_maxreq'	=>	$CHILD_MAXREQ,
			'pool_child_maxtime'	=>	$CHILD_MAXTIME,
			'pool_child_reconnect'	=>	$CHILD_RECONNECT,
			'pool_child_tries'	=>	$CHILD_TRIES,
			'pool_child_create'	=>	$CHILD_CREATE,
			'pool_child_kill'	=>	$CHILD_KILL,

			# The queue of DBI calls
			'QUEUE'		=>	[],
			'IDCounter'	=>	0,
			'queue_firing'	=>	0,

			# Are we shutting down?
			'SHUTDOWN'	=>	0,
			'CONNECTING'	=>	0,
			'CONNECTED'	=>	0,

			# The DB Info
			'DB_DSN'	=>	undef,
			'DB_USERNAME'	=>	undef,
			'DB_PASSWORD'	=>	undef,
			'DB_EVENT'	=>	undef,
			'DB_SESSION'	=>	undef,

			# The alias we will run under
			'ALIAS'		=>	$ALIAS,

			# Cache sql statements?
			'PREPARE_CACHED'=>	$PREPARE_CACHED,
		},
		__PACKAGE__->inline_states(),
	) or die 'Unable to create a new session!';

	# Return success
	return 1;
}

# This starts the SimpleDBI
sub _start : State {
	# Extensive debug
	if ( DEBUG() ) {
		warn 'Starting up SimpleDBI::PoolManager!';
	}

	# Set up the alias for ourself
	$_[KERNEL]->alias_set( $_[HEAP]->{'ALIAS'} );

	# fire up the pool!
	$_[KERNEL]->yield( 'pool_child_create' );

	# all done!
	return;
}

# Stops everything we have
sub _stop : State {
	# Extensive debug
	if ( DEBUG() ) {
		warn 'Stopping SimpleDBI::PoolManager!';
	}

	# FIXME dodo?

	# all done!
	return;
}

# a child session spwaned/died
sub _child : State {
	my( $reason, $ses ) = @_[ ARG0, ARG1 ];

	if ( $reason eq 'lose' ) {
		# get the child pool struct
		my $child;
		foreach my $c ( keys %{ $_[HEAP]->{'pool'} } ) {
			if ( $_[HEAP]->{'pool'}->{ $c }->{'SESSION'} eq $ses->ID ) {
				$child = $c;
				last;
			}
		}
		if ( defined $child ) {
			# localize it
			$child = $_[HEAP]->{'pool'}->{ $child };

			# was it properly terminated?
			if ( $child->{'ACTIVE'} ) {
				# FIXME wow, child unexpectedly died
			}

			# FIXME get rid of the pool_child_maxtime timer if needed

			# get rid of our reference to it
			delete $_[HEAP]->{'pool'}->{ $child->{'ID'} };

			# spawn another child?
			$_[KERNEL]->yield( 'pool_child_create' );
		} else {
			# FIXME wow, unknown child
			if ( DEBUG() ) {
				warn 'internal inconsistency';
			}
		}
	}

	# all done!
	return;
}

sub process_queue : State {
	# we aren't firing anymore
	$_[HEAP]->{'queue_firing'} = 0;

	# we are allowed to tell a child to connect once
	my $told_connect = 0;

	# process each query in the queue
	for my $count ( 0 .. @{ $_[HEAP]->{'QUEUE'} } - 1 ) {
		# local alias
		my $query = $_[HEAP]->{'QUEUE'}->[ $count ];

		# skip processed queries
		if ( exists $query->{'_PROCESSING'} ) {
			next;
		}

		# what kind of query?
		if ( $query->{'ACTION'} eq 'DISCONNECT' ) {
			if ( $_[HEAP]->{'CONNECTED'} or $_[HEAP]->{'CONNECTING'} ) {
				$query->{'_PROCESSING'} = 1;
				$_[HEAP]->{'CONNECTED'} = 0;

				# how many children are we killing?
				my $killing = 0;

				# actually kill off the children!
				foreach my $child ( keys %{ $_[HEAP]->{'pool'} } ) {
					if ( $_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} ) {
						$killing++;

						# set this child to non-ACTIVE
						$_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} = 0;

						# can we disconnect now?
						if ( defined $_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} ) {
							# wait for the query to finish
						} else {
							# setup some stats
							$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = $query->{'ID'};

							# send it off!
							$_[KERNEL]->post( $_[HEAP]->{'pool'}->{ $child }->{'SESSION'}, 'DISCONNECT',
								'SESSION'	=>	$_[SESSION],
								'EVENT'		=>	'got_child_disconnect',
							);
						}
					}
				}

				# okay, take note of the number
				$query->{'_DISCONNECT_children'} = $killing;
			} else {
				# FIXME send disconnect when already disconnected error
			}
		} elsif ( $query->{'ACTION'} eq 'CONNECT' ) {
			if ( ! $_[HEAP]->{'CONNECTED'} ) {
				# okay, are we connecting?
				if ( $_[HEAP]->{'CONNECTING'} ) {
					# let the previous CONNECT complete
					last;
				} else {
					$_[HEAP]->{'CONNECTING'} = 1;
					$query->{'_PROCESSING'} = 1;
				}

				# Save the connection info
				foreach my $key ( qw( DSN USERNAME PASSWORD SESSION EVENT ) ) {
					$_[HEAP]->{ 'DB_' . $key } = $query->{ $key };
				}

				foreach my $child ( keys %{ $_[HEAP]->{'pool'} } ) {
					if ( $_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} and ! $_[HEAP]->{'pool'}->{ $child }->{'CONNECTED'} and ! $_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} ) {
						# setup some stats
						$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = $query->{'ID'};

						# execute connect action
						my %connect_struct = (
							'SESSION'	=>	$_[SESSION],
							'EVENT'		=>	'got_child_connect',
							'NOW'		=>	1,
							'CLEAR'		=>	1,
						);
						foreach my $arg ( qw/ DSN USERNAME PASSWORD / ) {
							if ( exists $query->{ $arg } ) {
								$connect_struct{ $arg } = $query->{ $arg };
							}
						}

						# send it off!
						$_[KERNEL]->post( $_[HEAP]->{'pool'}->{ $child }->{'SESSION'}, 'CONNECT', %connect_struct );

						# all done!
						last;
					}
				}
			} else {
				# FIXME send connect when already connected error
			}
		} else {
			# normal MULTIPLE/SINGLE/DO/QUOTE query

			# are we connected?
			if ( ! $_[HEAP]->{'CONNECTED'} ) {
				if ( ! $_[HEAP]->{'CONNECTING'} ) {
					# FIXME add deadlock detection
				}

				last;
			}

			# do we have a child available?
			my $child = undef;
			foreach my $p ( keys %{ $_[HEAP]->{'pool'} } ) {
				if ( $_[HEAP]->{'pool'}->{ $p }->{'ACTIVE'} and ! defined $_[HEAP]->{'pool'}->{ $p }->{'PROCESSING'} ) {
					# is it connected yet?
					if ( $_[HEAP]->{'pool'}->{ $p }->{'CONNECTED'} ) {
						# use this child!
						$child = $p;
						last;
					} else {
						# can we tell it to connect?
						if ( ! $told_connect ) {
							$told_connect = 1;

							# setup some stats
							$_[HEAP]->{'pool'}->{ $p }->{'PROCESSING'} = 'CONNECT';

							# execute connect action
							my %connect_struct = (
								'SESSION'	=>	$_[SESSION],
								'EVENT'		=>	'got_child_connect',
								'NOW'		=>	1,
								'CLEAR'		=>	1,
							);
							foreach my $arg ( qw/ DSN USERNAME PASSWORD / ) {
								$connect_struct{ $arg } = $_[HEAP]->{'DB_' . $arg };
							}

							# send it off!
							$_[KERNEL]->post( $_[HEAP]->{'pool'}->{ $p }->{'SESSION'}, 'CONNECT', %connect_struct );
						}
					}
				}
			}

			if ( defined $child ) {
				# setup some stats
				$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = $query->{'ID'};
				$_[HEAP]->{'pool'}->{ $child }->{'QUERIES'}++;
				$query->{'_PROCESSING'} = $child;

				# create a duplicate query structure so SimpleDBI doesn't touch ours!
				my %query_struct = (
					'SESSION'	=>	$_[SESSION],
					'EVENT'		=>	'got_child_query',
					'BAGGAGE'	=>	$query->{'ID'},
				);
				foreach my $arg ( qw/ SQL PLACEHOLDERS PREPARE_CACHED INSERT_ID / ) {
					if ( exists $query->{ $arg } ) {
						$query_struct{ $arg } = $query->{ $arg };
					}
				}

				# send it off!
				$_[KERNEL]->post( $_[HEAP]->{'pool'}->{ $child }->{'SESSION'}, $query->{'ACTION'}, %query_struct );
			} else {
				# we ran out of children to execute queries on
				last;
			}
		}
	}

	# all done!
	return;
}

sub got_child_connect : State {
	my $result = $_[ARG0];

	# get the child pool struct
	my $child;
	foreach my $c ( keys %{ $_[HEAP]->{'pool'} } ) {
		if ( $_[HEAP]->{'pool'}->{ $c }->{'SESSION'} eq $_[SENDER]->ID ) {
			$child = $c;
			last;
		}
	}

	# check for errors
	if ( exists $result->{'ERROR'} ) {
		if ( $_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} ) {
			# FIXME ah, we couldn't connect, kill the entire pool + report back to app failure
			$_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} = 0;
		} else {
			# this was a child that failed to connect, but we already processed another child + turned the pool off
		}

		# tell it to shutdown
		$_[KERNEL]->post( $_[SENDER], 'shutdown' );
		$_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} = 0;
		$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = undef;

		# all done!
		return;
	}
	if ( exists $result->{'GONE'} ) {
		# was it processing a request?
		if ( $_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} ) {
			# FIXME salvage the failed query
		}

		# tell it to shutdown
		if ( $_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} ) {
			$_[KERNEL]->post( $_[SENDER], 'shutdown' );
			$_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} = 0;
		}

		return;
	}

	# process this connect!
	$_[HEAP]->{'pool'}->{ $child }->{'CONNECTED'} = 1;
	$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = undef;

	# do we care?
	if ( $_[HEAP]->{'pool'}->{ $child }->{'ACTIVE'} ) {
		# process the next entry in the queue
		if ( ! $_[HEAP]->{'queue_firing'} ) {
			$_[HEAP]->{'queue_firing'} = 1;
			$_[KERNEL]->yield( $_[SESSION], 'process_queue' );
		}

		# FIXME setup the pool_child_maxtime timer
	} else {
		# ah, we was disconnected before we could connect, shutdown!
		$_[KERNEL]->post( $_[SENDER], 'shutdown' );
	}

	# all done!
	return;
}

sub got_child_disconnect : State {
	my $result = $_[ARG0];

	# get the child pool struct
	my $child;
	foreach my $c ( keys %{ $_[HEAP]->{'pool'} } ) {
		if ( $_[HEAP]->{'pool'}->{ $c }->{'SESSION'} eq $_[SENDER]->ID ) {
			$child = $c;
			last;
		}
	}

	# process this disconnect!
	$_[HEAP]->{'pool'}->{ $child }->{'CONNECTED'} = 0;
	$_[HEAP]->{'pool'}->{ $child }->{'PROCESSING'} = undef;

	# check for errors
	if ( exists $result->{'ERROR'} ) {
		# FIXME process the error
		return;
	}

	# actually shutdown SimpleDBI!
	$_[KERNEL]->post( $_[SENDER], 'shutdown' );

	# all done!
	return;
}

sub got_child_query : State {
	my $result = $_[ARG0];

	# match up the query via the baggage
	for my $count ( 0 .. @{ $_[HEAP]->{'QUEUE'} } - 1 ) {
		if ( $_[HEAP]->{'QUEUE'}->[ $count ]->{'ID'} eq $result->{'BAGGAGE'} ) {
			# okay, found it!
			my $query = $_[HEAP]->{'QUEUE'}->[ $count ];
			splice( @{ $_[HEAP]->{'QUEUE'} }, $count, 1 );

			# report the result back to the originator
			my %result_struct = (
				'SESSION'	=>	$query->{'SESSION'},
				'EVENT'		=>	$query->{'EVENT'},
				'ID'		=>	$query->{'ID'},
				'BAGGAGE'	=>	$query->{'BAGGAGE'},
			);
			foreach my $arg ( qw/ ERROR ACTION RESULT SQL PLACEHOLDERS INSERTID / ) {
				if ( exists $result->{ $arg } ) {
					$result_struct{ $arg } = $result->{ $arg };
				}
			}

			# send it off!
			$_[KERNEL]->post( $result_struct{'SESSION'}, $result_struct{'EVENT'}, %result_struct );

			# this child is not processing a query anymore!
			$_[HEAP]->{'pool'}->{ $query->{'_PROCESSING'} }->{'PROCESSING'} = undef;

			# honor pool_child_maxreq
			if ( $_[HEAP]->{'pool_child_maxreq'} > 0 ) {
				if ( $_[HEAP]->{'pool'}->{ $query->{'_PROCESSING'} }->{'QUERIES'} > $_[HEAP]->{'pool_child_maxreq'} ) {
					# FIXME kill this child!

					# all done!
					return;
				}
			}

			# honor pool_child_maxtime
			if ( $_[HEAP]->{'pool_child_maxtime'} > 0 ) {
				if ( time() - $_[HEAP]->{'pool'}->{ $query->{'_PROCESSING'} }->{'STARTTIME'} > $_[HEAP]->{'pool_child_maxtime'} ) {
					# FIXME kill this child!

					# all done!
					return;
				}
			}

			# do we care?
			if ( $_[HEAP]->{'pool'}->{ $query->{'_PROCESSING'} }->{'ACTIVE'} ) {
				# process the next entry in the queue
				if ( ! $_[HEAP]->{'queue_firing'} ) {
					$_[HEAP]->{'queue_firing'} = 1;
					$_[KERNEL]->yield( $_[SESSION], 'process_queue' );
				}
			} else {
				# FIXME send disconnect
			}

			# all done!
			return;
		}
	}

	if ( DEBUG() ) {
		# FIXME dodo?
		warn 'internal failure';
	}

	# all done!
	return;
}

sub pool_child_create : State {
	# skip all this if we're dying
	if ( $_[HEAP]->{'SHUTDOWN'} ) {
		return;
	}

	# okay, should we create a child?
	my $do_create = 0;
	my $children = 0;
	my $processing = 0;
	foreach my $p ( keys %{ $_[HEAP]->{'pool'} } ) {		# FIXME make this a variable look-up instead? ( if we have a million... )
		if ( $_[HEAP]->{'pool'}->{ $p }->{'ACTIVE'} ) {
			$children++;

			if ( $_[HEAP]->{'pool'}->{ $p }->{'CONNECTED'} and defined $_[HEAP]->{'pool'}->{ $p }->{'PROCESSING'} ) {
				$processing++;
			}
		}
	}
	if ( $children < $_[HEAP]->{'pool_min'} ) {
		$do_create = 1;
	} else {
		if ( $processing and $processing > $children - $_[HEAP]->{'pool_spare'} ) {
			# argh, have we hit the limit?
			if ( $children < $_[HEAP]->{'pool_max'} ) {
				$do_create = 1;
			}
		}
	}

	if ( $do_create ) {
		# go create a child!
		my $child = {
			'ID'		=>	$_[HEAP]->{'ALIAS'} . '-child-' . $_[HEAP]->{'poolCounter'}++,
			'ACTIVE'	=>	1,
			'CONNECTED'	=>	0,
			'STARTTIME'	=>	time(),
			'QUERIES'	=>	0,
			'PROCESSING'	=>	undef,
			'SESSION'	=>	undef,
		};

		if ( DEBUG() ) {
			warn 'setting up child(' . $child->{'ID'} . ')';
		}

		# setup the child session
		my $ses = POE::Component::SimpleDBI->new( $child->{'ID'}, $_[HEAP]->{'PREPARE_CACHED'} );
		if ( defined $ses ) {
			$child->{'SESSION'} = $ses->ID;
			$children++;

			# add it to our pool!
			$_[HEAP]->{'pool'}->{ $child->{'ID'} } = $child;

			# automatically send the CONNECT data if we're already connected
			if ( $_[HEAP]->{'CONNECTED'} ) {
				# setup some stats
				$_[HEAP]->{'pool'}->{ $child->{'ID'} }->{'PROCESSING'} = 'CONNECT';

				# execute connect action
				my %connect_struct = (
					'SESSION'	=>	$_[SESSION],
					'EVENT'		=>	'got_child_connect',
					'NOW'		=>	1,
					'CLEAR'		=>	1,
				);
				foreach my $arg ( qw/ DSN USERNAME PASSWORD / ) {
					$connect_struct{ $arg } = $_[HEAP]->{'DB_' . $arg };
				}

				# send it off!
				$_[KERNEL]->post( $child->{'SESSION'}, 'CONNECT', %connect_struct );
			}
		} else {
			if ( DEBUG() ) {
				warn 'unable to create SimpleDBI session for child(' . $child->{'ID'} . ')';
			}
		}

		# Fire off another child?
		if ( $children < $_[HEAP]->{'pool_min'} ) {
			$_[KERNEL]->yield( 'pool_child_create' );
		} else {
			# do we need a spare?
			if ( $processing and $processing > $children - $_[HEAP]->{'pool_spare'} ) {
				$_[KERNEL]->delay_set( 'pool_child_create' => $_[HEAP]->{'pool_child_create'} );
			}
		}
	}

	# all done!
	return;
}

# This subroutine handles shutdown signals
sub shutdown : State {
	# Extensive debugging...
	if ( DEBUG() ) {
		warn 'Initiating shutdown procedure!';
	}

	# Check for duplicate shutdown signals
	if ( $_[HEAP]->{'SHUTDOWN'} ) {
		# Duplicate shutdown events
		if ( DEBUG() ) {
			warn 'Duplicate shutdown event was posted to SimpleDBI::PoolManager!';
		}
		return;
	}

	# Remove our alias so we can be properly terminated
	$_[KERNEL]->alias_remove( $_[HEAP]->{'ALIAS'} );

	# Gracefully shut down...
	$_[HEAP]->{'SHUTDOWN'} = 1;

	# Clean up the queue
	$_[KERNEL]->call( $_[SESSION], 'Clear_Queue', 'SimpleDBI is shutting down now' );

	# FIXME kill our pool

	# all done!
	return;
}

sub MULTIPLE : State {
	goto &DB_HANDLE;
}
sub SINGLE : State {
	goto &DB_HANDLE;
}
sub DO : State {
	goto &DB_HANDLE;
}
sub QUOTE : State {
	goto &DB_HANDLE;
}

# This subroutine handles MULTIPLE + SINGLE + DO + QUOTE queries
sub DB_HANDLE {
	# Get the arguments
	my %args = @_[ARG0 .. $#_ ];

	# Check for unknown args
	foreach my $key ( keys %args ) {
		if ( $key !~ /^(?:SQL|PLACEHOLDERS|BAGGAGE|EVENT|SESSION|PREPARE_CACHED|INSERT_ID)$/ ) {
			if ( DEBUG() ) {
				warn "Unknown argument to $_[STATE] -> $key";
			}
			delete $args{ $key };
		}
	}

	# Add some stuff to the args
	$args{'ACTION'} = $_[STATE];
	if ( ! exists $args{'SESSION'} ) {
		$args{'SESSION'} = $_[SENDER]->ID();
	}

	# Check for Session
	if ( ! defined $args{'SESSION'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive a SESSION argument -> State: $_[STATE] Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ref $args{'SESSION'} ) {
			if ( UNIVERSAL::isa( $args{'SESSION'}, 'POE::Session') ) {
				# Convert it!
				$args{'SESSION'} = $args{'SESSION'}->ID();
			} else {
				if ( DEBUG() ) {
					warn "Received malformed SESSION argument -> State: $_[STATE] Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
				}
				return;
			}
		}
	}

	# Check for Event
	if ( ! exists $args{'EVENT'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive an EVENT argument -> State: $_[STATE] Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ! defined $args{'EVENT'} or ref $args{'EVENT'} ) {
			# Same quietness...
			if ( DEBUG() ) {
				warn "Received a malformed EVENT argument -> State: $_[STATE] Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
			}
			return;
		}
	}

	# Check for SQL
	if ( ! exists $args{'SQL'} or ! defined $args{'SQL'} or ref $args{'SQL'} ) {
		# Extensive debug
		if ( DEBUG() ) {
			warn 'Did not receive/malformed SQL string!';
		}

		# Okay, send the error to the Event
		$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
			( exists $args{'SQL'} ? ( 'SQL' => $args{'SQL'} ) : () ),
			( exists $args{'PLACEHOLDERS'} ? ( 'PLACEHOLDERS' => $args{'PLACEHOLDERS'} ) : () ),
			( exists $args{'BAGGAGE'} ? ( 'BAGGAGE' => $args{'BAGGAGE'} ) : () ),
			'ERROR'		=>	'Received an empty/malformed SQL string!',
			'ACTION'	=>	$args{'ACTION'},
			'EVENT'		=>	$args{'EVENT'},
			'SESSION'	=>	$args{'SESSION'},
			}
		);
		return;
	}

	# Check for placeholders
	if ( exists $args{'PLACEHOLDERS'} ) {
		if ( ! ref $args{'PLACEHOLDERS'} or ref( $args{'PLACEHOLDERS'} ) ne 'ARRAY' ) {
			# Extensive debug
			if ( DEBUG() ) {
				warn 'PLACEHOLDERS was not a ref to an ARRAY!';
			}

			# Okay, send the error to the Event
			$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
				'SQL'		=>	$args{'SQL'},
				'PLACEHOLDERS'	=>	$args{'PLACEHOLDERS'},
				( exists $args{'BAGGAGE'} ? ( 'BAGGAGE' => $args{'BAGGAGE'} ) : () ),
				'ERROR'		=>	'PLACEHOLDERS is not an array!',
				'ACTION'	=>	$args{'ACTION'},
				'EVENT'		=>	$args{'EVENT'},
				'SESSION'	=>	$args{'SESSION'},
				}
			);
			return;
		}
	}

	# check for INSERT_ID
	if ( exists $args{'INSERT_ID'} ) {
		if ( $args{'INSERT_ID'} ) {
			$args{'INSERT_ID'} = 1;
		} else {
			$args{'INSERT_ID'} = 0;
		}
	} else {
		# set default
		$args{'INSERT_ID'} = 1;
	}

	# check for PREPARE_CACHED
	if ( exists $args{'PREPARE_CACHED'} ) {
		if ( $args{'PREPARE_CACHED'} ) {
			$args{'PREPARE_CACHED'} = 1;
		} else {
			$args{'PREPARE_CACHED'} = 0;
		}
	} else {
		# What does our global setting say?
		$args{'PREPARE_CACHED'} = $_[HEAP]->{'PREPARE_CACHED'};
	}

	# Check if we have shutdown or not
	if ( $_[HEAP]->{'SHUTDOWN'} ) {
		# Extensive debug
		if ( DEBUG() ) {
			warn 'Denied query due to SHUTDOWN';
		}

		# Do not accept this query
		$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
			'SQL'		=>	$args{'SQL'},
			( exists $args{'PLACEHOLDERS'} ? ( 'PLACEHOLDERS' => $args{'PLACEHOLDERS'} ) : () ),
			( exists $args{'BAGGAGE'} ? ( 'BAGGAGE' => $args{'BAGGAGE'} ) : () ),
			'ERROR'		=>	'POE::Component::SimpleDBI::PoolManager is shutting down now, requests are not accepted!',
			'ACTION'	=>	$args{'ACTION'},
			'EVENT'		=>	$args{'EVENT'},
			'SESSION'	=>	$args{'SESSION'},
			}
		);
		return;
	}

	# Increment the refcount for the session that is sending us this query
	$_[KERNEL]->refcount_increment( $args{'SESSION'}, 'SimpleDBI::PoolManager' );

	# Add the ID to the query
	$args{'ID'} = $_[HEAP]->{'IDCounter'}++;

	# Add this query to the queue
	push( @{ $_[HEAP]->{'QUEUE'} }, \%args );

	# send the query!
	if ( ! $_[HEAP]->{'queue_firing'} ) {
		$_[HEAP]->{'queue_firing'} = 1;
		$_[KERNEL]->yield( $_[SESSION], 'process_queue' );
	}

	# Return the ID for interested parties :)
	return $args{'ID'};
}

# This subroutine connects to the DB
sub CONNECT : State {
	# Get the arguments
	my %args = @_[ARG0 .. $#_ ];

	# If we got no arguments, assume that we will use the old connection
	if ( keys %args == 0 ) {
		if ( ! defined $_[HEAP]->{'DB_DSN'} ) {
			# How should we connect?
			if ( DEBUG() ) {
				warn 'Got CONNECT event but no arguments/did not have a cached copy of connect args';
			}
			return;
		}
	}

	# Check for unknown args
	foreach my $key ( keys %args ) {
		if ( $key !~ /^(?:SESSION|EVENT|DSN|USERNAME|PASSWORD|NOW|CLEAR)$/ ) {
			if ( DEBUG() ) {
				warn "Unknown argument to CONNECT -> $key";
			}
			delete $args{ $key };
		}
	}

	# Add the cached copy if applicable
	foreach my $key ( qw( DSN USERNAME PASSWORD SESSION EVENT ) ) {
		if ( ! exists $args{ $key } and defined $_[HEAP]->{ 'DB_' . $key } ) {
			$args{ $key } = $_[HEAP]->{ 'DB_' . $key };
		}
	}

	# Add some stuff to the args
	$args{'ACTION'} = 'CONNECT';
	if ( ! exists $args{'SESSION'} ) {
		$args{'SESSION'} = $_[SENDER]->ID();
	}

	# Check for Session
	if ( ! defined $args{'SESSION'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive a SESSION argument -> State: CONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ref $args{'SESSION'} ) {
			if ( UNIVERSAL::isa( $args{'SESSION'}, 'POE::Session') ) {
				# Convert it!
				$args{'SESSION'} = $args{'SESSION'}->ID();
			} else {
				if ( DEBUG() ) {
					warn "Received malformed SESSION argument -> State: CONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
				}
				return;
			}
		}
	}

	# Check for Event
	if ( ! exists $args{'EVENT'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive an EVENT argument -> State: CONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ! defined $args{'EVENT'} or ref $args{'EVENT'} ) {
			# Same quietness...
			if ( DEBUG() ) {
				warn "Received a malformed EVENT argument -> State: CONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
			}
			return;
		}
	}

	# Check the 3 things we are interested in
	foreach my $key ( qw( DSN USERNAME PASSWORD ) ) {
		# Check for it!
		if ( ! exists $args{ $key } or ! defined $args{ $key } or ref $args{ $key } ) {
			# Extensive debug
			if ( DEBUG() ) {
				warn "Did not receive/malformed $key!";
			}

			# Okay, send the error to the Event
			$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
				( exists $args{'DSN'} ? ( 'DSN' => $args{'DSN'} ) : () ),
				( exists $args{'USERNAME'} ? ( 'USERNAME' => $args{'USERNAME'} ) : () ),
				( exists $args{'PASSWORD'} ? ( 'PASSWORD' => $args{'PASSWORD'} ) : () ),
				'ERROR'		=>	"Cannot connect without the $key!",
				'ACTION'	=>	'CONNECT',
				'EVENT'		=>	$args{'EVENT'},
				'SESSION'	=>	$args{'SESSION'},
				}
			);
			return;
		}
	}

	# Some sanity
	if ( exists $args{'NOW'} and $args{'NOW'} and $_[HEAP]->{'CONNECTED'} ) {
		# Okay, send the error to the Event
		$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
			'DSN'		=> $args{'DSN'},
			'USERNAME'	=> $args{'USERNAME'},
			'PASSWORD'	=> $args{'PASSWORD'},
			'ERROR'		=> "Cannot CONNECT NOW when we are already connected!",
			'ACTION'	=> 'CONNECT',
			'EVENT'		=> $args{'EVENT'},
			'SESSION'	=> $args{'SESSION'},
			}
		);
		return;
	}

	# If we got CLEAR, empty the queue
	if ( exists $args{'CLEAR'} and $args{'CLEAR'} ) {
		$_[KERNEL]->call( $_[SESSION], 'Clear_Queue', 'The request queue was cleared via CONNECT' );
	}

	# Increment the refcount for the session that is sending us this query
	$_[KERNEL]->refcount_increment( $args{'SESSION'}, 'SimpleDBI::PoolManager' );

	# Add the ID to the query
	$args{'ID'} = $_[HEAP]->{'IDCounter'}++;

	# Are we connecting now?
	if ( exists $args{'NOW'} and $args{'NOW'} ) {
		# Add this query to the top of the queue
		unshift( @{ $_[HEAP]->{'QUEUE'} }, \%args );
	} else {
		# Add this to the bottom of the queue
		push( @{ $_[HEAP]->{'QUEUE'} }, \%args );
	}

	# send the query!
	if ( ! $_[HEAP]->{'queue_firing'} ) {
		$_[HEAP]->{'queue_firing'} = 1;
		$_[KERNEL]->yield( $_[SESSION], 'process_queue' );
	}

	# Return the ID for interested parties :)
	return $args{'ID'};
}

# This subroutine disconnects from the DB
sub DISCONNECT : State {
	# Get the arguments
	my %args = @_[ARG0 .. $#_ ];

	# Check for unknown args
	foreach my $key ( keys %args ) {
		if ( $key !~ /^(?:SESSION|EVENT|NOW|CLEAR)$/ ) {
			if ( DEBUG() ) {
				warn "Unknown argument to DISCONNECT -> $key";
			}
			delete $args{ $key };
		}
	}

	# Add some stuff to the args
	$args{'ACTION'} = 'DISCONNECT';
	if ( ! exists $args{'SESSION'} ) {
		$args{'SESSION'} = $_[SENDER]->ID();
	}

	# Check for Session
	if ( ! defined $args{'SESSION'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive a SESSION argument -> State: DISCONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ref $args{'SESSION'} ) {
			if ( UNIVERSAL::isa( $args{'SESSION'}, 'POE::Session') ) {
				# Convert it!
				$args{'SESSION'} = $args{'SESSION'}->ID();
			} else {
				if ( DEBUG() ) {
					warn "Received malformed SESSION argument -> State: DISCONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
				}
				return;
			}
		}
	}

	# Check for Event
	if ( ! exists $args{'EVENT'} ) {
		# Nothing much we can do except drop this quietly...
		if ( DEBUG() ) {
			warn "Did not receive an EVENT argument -> State: DISCONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
		}
		return;
	} else {
		if ( ! defined $args{'EVENT'} or ref $args{'EVENT'} ) {
			# Same quietness...
			if ( DEBUG() ) {
				warn "Received a malformed EVENT argument -> State: DISCONNECT Args: " . join( ' / ', %args ) . " Caller: " . $_[CALLER_FILE] . ' -> ' . $_[CALLER_LINE];
			}
			return;
		}
	}

	# Some sanity
	if ( exists $args{'NOW'} and $args{'NOW'} and ! $_[HEAP]->{'CONNECTED'} ) {
		# Okay, send the error to the Event
		$_[KERNEL]->post( $args{'SESSION'}, $args{'EVENT'}, {
			'ERROR'		=> "Cannot DISCONNECT NOW when we are already disconnected!",
			'ACTION'	=> 'DISCONNECT',
			'EVENT'		=> $args{'EVENT'},
			'SESSION'	=> $args{'SESSION'},
			}
		);
		return;
	}

	# If we got CLEAR, empty the queue
	if ( exists $args{'CLEAR'} and $args{'CLEAR'} ) {
		$_[KERNEL]->call( $_[SESSION], 'Clear_Queue', 'The request queue was cleared via DISCONNECT' );
	}

	# Increment the refcount for the session that is sending us this query
	$_[KERNEL]->refcount_increment( $args{'SESSION'}, 'SimpleDBI::PoolManager' );

	# Add the ID to the query
	$args{'ID'} = $_[HEAP]->{'IDCounter'}++;

	# Are we disconnecting now?
	if ( exists $args{'NOW'} and $args{'NOW'} ) {
		# Add it to the top!
		unshift( @{ $_[HEAP]->{'QUEUE'} }, \%args );
	} else {
		# Add this to the bottom of the queue
		push( @{ $_[HEAP]->{'QUEUE'} }, \%args );
	}

	# send the query!
	if ( ! $_[HEAP]->{'queue_firing'} ) {
		$_[HEAP]->{'queue_firing'} = 1;
		$_[KERNEL]->yield( $_[SESSION], 'process_queue' );
	}

	# Return the ID for interested parties :)
	return $args{'ID'};
}

# This subroutine clears the queue
sub Clear_Queue : State {
	# Get the error string
	my $err = $_[ARG0];

	# If it is not defined, make it the default
	if ( ! defined $err ) {
		$err = 'Cleared the queue';
	}

	# the "processing" ones
	my @processing;

	# Go over our queue, and do some stuff
	foreach my $queue ( shift @{ $_[HEAP]->{'QUEUE'} } ) {
		# is this pending?
		if ( exists $queue->{'_PROCESSING'} ) {
			push( @processing, $queue );
			next;
		}

		# Construct the response
		my $ret = {
			'ERROR'		=>	$err,
			'ACTION'	=>	$queue->{'ACTION'},
			'EVENT'		=>	$queue->{'EVENT'},
			'SESSION'	=>	$queue->{'SESSION'},
			'ID'		=>	$queue->{'ID'},
		};

		# Add needed fields
		if ( $queue->{'ACTION'} eq 'CONNECT' ) {
			$ret->{'DSN'} = $queue->{'DSN'};
			$ret->{'USERNAME'} = $queue->{'USERNAME'};
			$ret->{'PASSWORD'} = $queue->{'PASSWORD'};
		} elsif ( $queue->{'ACTION'} ne 'DISCONNECT' ) {
			$ret->{'SQL'} = $queue->{'SQL'};

			if ( exists $queue->{'PLACEHOLDERS'} ) {
				$ret->{'PLACEHOLDERS'} = $queue->{'PLACEHOLDERS'};
			}

			if ( exists $queue->{'BAGGAGE'} ) {
				$ret->{'BAGGAGE'} = $queue->{'BAGGAGE'};
			}
		}

		# Post a failure event to all the queries on the Queue, informing them that we have been shutdown...
		$_[KERNEL]->post( $queue->{'SESSION'}, $queue->{'EVENT'}, $ret );

		# Argh, decrement the refcount
		$_[KERNEL]->refcount_decrement( $queue->{'SESSION'}, 'SimpleDBI::PoolManager' );
	}

	# Clear the queue / put back processing ones
	if ( @processing ) {
		$_[HEAP]->{'QUEUE'} = \@processing;
	} else {
		$_[HEAP]->{'QUEUE'} = [];
	}

	# All done!
	return 1;
}

# This subroutine deletes a query from the queue
sub Delete_Query : State {
	# ARG0 = ID
	my $id = $_[ARG0];

	# Validation
	if ( ! defined $id ) {
		# Debugging
		if ( DEBUG() ) {
			warn 'Got a Delete_Query event with no arguments!';
		}
		return undef;
	}

	# Search through the rest of the queue and see what we get
	for my $count ( 0 .. @{ $_[HEAP]->{'QUEUE'} } - 1 ) {
		if ( $_[HEAP]->{'QUEUE'}->[ $count ]->{'ID'} eq $id ) {
			if ( exists $_[HEAP]->{'QUEUE'}->[ $count ]->{'_PROCESSING'} ) {
				# Extensive debug
				if ( DEBUG() ) {
					warn 'Could not delete query as it is being processed by the SubProcess!';
				}

				# Query is still active, nothing we can do...
				return 0;
			} else {
				# FIXME send an error event notifying we successfully deleted?

				# Found a match, delete it!
				splice( @{ $_[HEAP]->{'QUEUE'} }, $count, 1 );

				# Return success
				return 1;
			}
		}
	}

	# If we got here, we didn't find anything
	return undef;
}

1;
__END__
=head1 NAME

POE::Component::SimpleDBI::PoolManager - Pool of SimpleDBI connections made simple

=head1 SYNOPSIS

	use POE;
	use POE::Component::SimpleDBI::PoolManager;

	# drop-in replacement for SimpleDBI with default pool config
	POE::Component::SimpleDBI::PoolManager->new( 'SimpleDBI' ) or die 'Unable to create the DBI session';

	# Create our own session to communicate with SimpleDBI
	POE::Session->create(
		inline_states => {
			_start => sub {
				# look at SimpleDBI for examples
			},
		},
	);

=head1 ABSTRACT

	If you liked SimpleDBI, this will be a breeze to use! The purpose of this module
	is to make managing a pool of SimpleDBI connections easy to use. The interface is exactly
	the same as SimpleDBI, making it a "drop-in replacement!"

	The concept is that this module will make N connections, and spread incoming queries to them. In
	essence, this will make the queue run faster, instead of waiting for slow queries to finish before
	executing the next one.

	However, this will seriously disrupt certain SQL flows, namely transactional ones. Furthermore, now that
	we are running multiple connections, we cannot guarantee execution order of queries in the queue. If your
	application can handle this, then it will be a beautiful match.

=head1 DESCRIPTION

This module works it's magic by spawning a pool of SimpleDBI sessions. We add some pool management concepts, otherwise
the interface is the same as SimpleDBI. Think of this as "turbocharging" SimpleDBI with multiple connections.

The pool concept/features was lifted from Apache and other popular web/ftp servers, thanks!

The design was intentionally kept simple, and in the spirit of "drop-in replacement" for SimpleDBI. That's why we are unable
to fine-tune the pool, customize each child connection, or direct queries to individual children. I'm sure there are more advanced
"pool" concepts that we would love to see here, but they might be implemented later. Emphasis on *might* :)

The standard way to use this module is to do this:

	use POE;
	use POE::Component::SimpleDBI::PoolManager;

	POE::Component::SimpleDBI::PoolManager->new( ... );

	POE::Session->create( ... );

	POE::Kernel->run();

=head2 Starting SimpleDBI::PoolManager

To start SimpleDBI::PoolManager, just call it's new method:

	POE::Component::SimpleDBI::PoolManager->new( 'ALIAS' );

This method will die on error or return success.

This constructor accepts only 2 arguments + the options hash.

=head3 Alias

This sets the session alias in POE.

The default is "SimpleDBI-PoolManager".

=head3 PREPARE_CACHED

This sets the global PREPARE_CACHED setting. This is a boolean value.

	POE::Component::SimpleDBI::PoolManager->new( 'ALIAS', 0 );

The default is enabled.

=head3 options hash

This sets the pool configuration values. It is passed in like this:

	# incidentally, the default values are here!
	POE::Component::SimpleDBI::PoolManager->new( 'ALIAS', 1,
		'pool_min'		=>	5,
		'pool_max'		=>	10,
		'pool_spare'		=>	2,
		'pool_child_maxreq'	=>	0,
		'pool_child_maxtime'	=>	0,
		'pool_child_reconnect'	=>	5,
		'pool_child_tries'	=>	5,
		'pool_child_create'	=>	1,
		'pool_child_kill'	=>	30
	);

=head4 pool_min

This sets the minimum number of children ( also the starting number )

	Must be an integer >= 0

	DEFAULT: 5

=head4 pool_max

This sets the maximum number of children.

	Must be an integer >= 0
	Must be greater than 'pool_min' + 'pool_spare'

	DEFAULT: 10

=head4 pool_spare

This sets the number of "spare" children.

	Must be an integer >= 0
	Must be less than 'pool_max' - 'pool_min'

	DEFAULT: 2

=head4 pool_child_maxreq

This sets the number of requests a child can serve before self-destruction.

Setting it to 0 disables it.

	Must be an integer >= 0

	DEFAULT: 0

=head4 pool_child_maxtime

This sets the number of seconds a child can live before self-destruction.

Setting it to 0 disables it.

	Must be an integer >= 0

	DEFAULT: 0

=head4 pool_child_reconnect

This sets the number of seconds a child will wait between reconnections. This is a special case version
of 'pool_spare_create' if the child connection was unable to connect on the first time. If a child dies / gets
disconnected, they will still follow 'pool_spare_create' and re-spawn later.

	Must be an integer > 0

	DEFAULT: 5

=head4 pool_child_tries

This sets the number of connection attempts a child will try before self-destruction. Again, if a child gets connected
then disconnected, it will follow 'pool_spare_create' and re-spawn later.

	Must be an integer > 0

	DEFAULT: 5

=head4 pool_child_create

This sets the number of seconds between creating child connections.

	Must be an integer > 0

	DEFAULT: 1

=head4 pool_child_kill

This sets the number of seconds before killing idle connections over the limit. ( pool_min + pool_spare )

Setting it to 0 disables it.

	Must be an integer >= 0

	DEFAULT: 30

=head2 Commands

The usual SimpleDBI commands ( DO, SINGLE, MULTIPLE, QUOTE, CONNECT, DISCONNECT ) are accepted. There is no difference
in arguments / return events. There are subtle differences across the board, and we are bolting on pool management concepts
to SimpleDBI.

Please read the L<POE::Component::SimpleDBI> pod for information on basic usage. If the command isn't mentioned here then
there is no difference in how we behave against SimpleDBI.

=head3 C<CONNECT>

	We don't issue CONNECT to each child in the pool! This means the pool will actually try only one child, and if it successfully
	connects, returns success to your app. From there, poolManager will tell each child to connect whenever a query comes in. This
	avoids the "thundering herd" problem if we have a big pool! ( hundreds of children ) Likewise, if the first child is unable to
	connect, the pool will return failure.

	If the pool is connected and running queries, then a single connection disconnects, the pool will remain running. PoolManager
	simply creates a new child to compensate for the lost one, and moves on. The only "exceptional" case is when all the children are
	unable to re-connect. In this case, the pool is considered "disconnected" and an error returned to the application.

	Furthermore, the session/event data here is where we send updates regarding the pool. ( child gained/lost, stats, etc )

=head3 C<DISCONNECT>

	We might take longer than normal, because we have to make sure the entire pool is disconnected before returning success to the
	application. If one child successfully disconnects, we will consider it a success for the entire pool, other failures notwithstanding.

	Similar to CONNECT, if all children are unable to disconnect, we will return an error to the application. In this case, PoolManager
	simply sends SHUTDOWN to the old children and creates new children. That way, we guarantee "fresh" children.

=head2 Pool Management

The PoolManager provides us some commands to manage the pool. For now we simply tweak the configuration values, and let PoolManager
re-configure the pool itself.

=head3 C<Pool_Config>

Allows us to get/set the pool configuration values. Please look at the options hash above for details.

When setting, please pass in key/value pairs. Returns boolean true/false for success.

When getting, this function returns a hashref with the options.

Remember to use $_[KERNEL]->call( ... ) to get this data!

	my $config = $_[KERNEL]->call( 'SimpleDBI-PoolManager', 'Pool_Config' );
	foreach my $opt ( keys %$config ) {
		warn "option $opt (" . $config->{ $opt } . ")";
	}

	$_[KERNEL]->post( 'SimpleDBI-PoolManager', 'Pool_Config',
		'pool_child_maxreq'	=>	1_000,
		'pool_max'		=>	25,
	);

	if ( $_[KERNEL]->call( 'SimpleDBI-PoolManager', 'Pool_Config', 'pool_min' => 5 ) ) {
		warn "changed pool_min to 5";
	} else {
		warn "unable to change pool_min parameter!";
	}

=head2 SimpleDBI::PoolManager Notes

This module is very picky about capitalization!

All of the options are uppercase, to avoid confusion.

You can enable debugging mode by doing this:

	sub POE::Component::SimpleDBI::PoolManager::DEBUG () { 1 }
	use POE::Component::SimpleDBI::PoolManager;


=head2 EXPORT

Nothing.

=head1 SEE ALSO

L<POE::Component::SimpleDBI>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
