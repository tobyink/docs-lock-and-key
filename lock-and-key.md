# Keeping Your Valuables Under Lock and Key

Consider the following fairly simple class, which creates a lookup object
for month names:

    use v5.24;
    
    package Local::MonthList {
      use experimental qw( signatures );
      
      use Class::Tiny {
        months  => sub ( $self ) { die "`months` is required" },
        _lookup => sub ( $self ) { $self->{_lookup} //= $self->_build_lookup },
      };
      
      use overload (
        q[bool]  => sub { 1 },
        q[@{}]   => sub { shift->months },
        fallback => 1,
      );
      
      sub _build_lookup ( $self ) {
        my $n = 0;
        my %lookup = map {
          lc($_) => ++$n;
        } $self->months->@*;
        return \%lookup;
      }
      
      sub lookup_name ( $self, $month_name ) {
        return $self->_lookup->{ lc $month_name };
      }
      
      sub lookup_number ( $self, $month_number ) {
        return $self->months->[ $month_number - 1 ];
      }
    }

It can be used as follows:

    use v5.24;
    use Test2::V0;
    
    my $list = 'Local::MonthList'->new( months => [ qw{
      January   February  March     April     May       June
      July      August    September October   November  December
    } ] );
    
    is( $list->lookup_name( 'augUST' ), 8, 'lookup_name' );
    is( $list->lookup_number( 7 ), 'July', 'lookup_number' );
    
    is(
      [ $list->@* ],
      [ qw{
        January   February  March     April     May       June
        July      August    September October   November  December
      } ],
      'overloaded as array',
    );
    
    done_testing;

However, there is a potential issue with any class which has attributes
that are references to mutable data structures like arrays and hashes.

    push $list->months->@*, 'Extrember';     # add an extra month

Even if we do in fact want to allow users to add extra months, this will
invalidate the cached lookup hash held in `_lookup`, making the
`lookup_name` method no longer work reliably.

A solution at the API level is to provide a method like this:

    sub push_month ( $self, $month_name ) {
      push $self->months->@*, $month_name;
      delete $self->{_lookup};
      return $self;
    }

People can add their months via:

    $list->push_month( 'Extrember' );

While this does provide a sanctioned way for people to add months to the list,
it doesn't do anything to _prevent_ them adding months (or removing them!)
the old way.

## Internals::SvREADONLY to the rescue

`Internals::SvREADONLY` is a Perl internal function for marking a
scalar, array, or hash read-only or not. The first argument is the thing
you want to tweak. The second argument is a boolean indicating whether you
want to make it read-only (true) or writable (false).

(The Internals package contains a bunch of functions which are theoretically
unstable and experimental, but in practice haven't been changed in a while.
Nevertheless a degree of caution should be employed when using its functions.
It may be a better idea to use a third-party package which wraps their
functionality. Some of these will be explored later in this article.)

By adding a one line `BUILD` method (the `BUILD` method is
automatically called by the constructor in classes based on Moose, Mouse,
Moo, Class::Tiny, etc) we can lock down the `months` array:

    sub BUILD ( $self, $arg ) {
      Internals::SvREADONLY( $self->months->@*, 1 );
    }

Our `push_month` method will need a few changes to be able to alter the
read-only array:

    sub push_month ( $self, $month_name ) {
      Internals::SvREADONLY( $self->months->@*, 0 );
      push $self->months->@*, $month_name;
      Internals::SvREADONLY( $self->months->@*, 1 );
      delete $self->{_lookup};
      return $self;
    }

We can test that this has worked:

    {
      my $e = dies {
        push $list->@*, 'Extrember';
      };
      like $e, qr/read-only/, 'dies trying to push onto overloaded array';
    }
    
    {
      my $e = dies {
        push $list->months->@*, 'Extrember';
      };
      like $e, qr/read-only/, 'dies trying to push onto months array';
    }

One thing to note is that `Internals::SvREADONLY` is extremely shallow.
It will prevent items being added to or removed from the `months` array, but
it doesn't prevent the items on the array being altered.

    $list->months->[0] = 'Not January?';

Applying and removing the read-only flag recursively is left as an exercise
to the reader.

## Sub::Trigger::Lock

A while ago I wrote a module that packages up this behaviour for
[Moose](https://metacpan.org/pod/Moose), [Mouse](https://metacpan.org/pod/Mouse), [Moo](https://metacpan.org/pod/Moo), and sufficiently-compatible frameworks.

First of all, let's rewrite our original class using [Moo](https://metacpan.org/pod/Moo).

    package Local::MonthList {
      use Moo;
      use Types::Common qw( -types );
      use experimental qw( signatures );
      
      has months   => ( is => 'ro', isa => ArrayRef );
      has _lookup  => ( is => 'lazy', builder => 1, clearer => 1 );
      
      use overload (
        q[bool]  => sub { 1 },
        q[@{}]   => sub { shift->months },
        fallback => 1,
      );
      
      sub _build__lookup ( $self ) {
        my $n = 0;
        my %lookup = map {
          lc($_) => ++$n;
        } $self->months->@*;
        return \%lookup;
      }
      
      sub lookup_name ( $self, $month_name ) {
        return $self->_lookup->{ lc $month_name };
      }
      
      sub lookup_number ( $self, $month_number ) {
        return $self->months->[ $month_number - 1 ];
      }
      
      sub push_month ( $self, $month_name ) {
        push $self->months->@*, $month_name;
        $self->_clear_lookup;
        return $self;
      }
    }

As before, it is possible to directly push to the `months` array:

    push $list->months->@*, 'Extrember';     # add an extra month

[Sub::Trigger::Lock](https://metacpan.org/pod/Sub%3A%3ATrigger%3A%3ALock) will lock down the attribute:

    use Sub::Trigger::Lock -all;
    has months => ( is => 'ro', isa => ArrayRef, trigger => Lock );

And our `push_month` method becomes:

    sub push_month ( $self, $month_name ) {
      my $guard = unlock( $self->months );
      push $self->months->@*, $month_name;
      $self->_clear_lookup;
      return $self;
    }

What is this `$guard` variable? It is an object which will re-lock the
`$self->months` array after it has gone out of scope.

While [Sub::Trigger::Lock](https://metacpan.org/pod/Sub%3A%3ATrigger%3A%3ALock) doesn't fully recurse into locked data structures,
it does go one level deep, which means this is prevented:

    $list->months->[0] = 'Not January?';

## Mite

[Mite](https://metacpan.org/pod/Mite) also makes locking attributes reasonably easy, using
`locked => true` in the attribute definition. The `push_month`
method can also be included declaratively via Mite's support for
`handles_via => 'Array'`. The only additional step is an
`after push_month` method modifier to clear the `_lookup` hashref.

    package Local2::MonthList;
    
    use Local2::Mite qw( -default -bool );
    use experimental qw( signatures );
    
    has months => (
      is          => 'ro',
      isa         => 'ArrayRef',
      locked      => true,
      handles_via => 'Array',
      handles     => { push_month => 'push' },
    );
    
    has _lookup  => (
      is          => 'lazy',
      builder     => true,
      clearer     => true,
    );
    
    use overload (
      q[bool]  => sub { 1 },
      q[@{}]   => sub { shift->months },
      fallback => 1,
    );
    
    sub _build__lookup ( $self ) {
      my $n = 0;
      my %lookup = map {
        lc($_) => ++$n;
      } $self->months->@*;
      return \%lookup;
    }
    
    sub lookup_name ( $self, $month_name ) {
      return $self->_lookup->{ lc $month_name };
    }
    
    sub lookup_number ( $self, $month_number ) {
      return $self->months->[ $month_number - 1 ];
    }
    
    after push_month => sub ( $self, $month_name ) {
      $self->_clear__lookup;
    };
    
    1;

## Alternative approaches

An alternative approach to locking attributes is cloning them. The basic idea
is whenever somebody requests `$list->months`, instead of returning a
reference to your internal array, return a deep clone of it.

This way, if they alter the clone, your internal copy is unaffected.

A major difference with this approach is that there is no exception thrown
when they alter the clone. In some cases, this will be preferable. In others,
it may be a source of confusion.

[MooseX::Extended](https://metacpan.org/pod/MooseX%3A%3AExtended) offers a `clone` feature to make this approach easy.
[Mite](https://metacpan.org/pod/Mite) also supports `clone`. One drawback is that this can be an expensive
operation for large and deeply nested structures.

## Conclusion

Locking reference attributes can be a fast and easy way to protect the
internal state of your objects.

Perl has built-in support for read-only arrays and hashes via
`Internals::SvREADONLY`, but modules like [Sub::Trigger::Lock](https://metacpan.org/pod/Sub%3A%3ATrigger%3A%3ALock) exist
to make using the feature simpler in object-oriented code.

You can find the full code and test cases for the classes discussed in this
module here:

[https://github.com/tobyink/docs-lock-and-key](https://github.com/tobyink/docs-lock-and-key).
