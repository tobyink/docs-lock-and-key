use v5.24;
use Test2::V0;

package Local::MonthList {
	use Moo;
	use Types::Common qw( -types );
	use Sub::Trigger::Lock qw( -all );
	use experimental qw( signatures );

	has months   => ( is => 'ro', isa => ArrayRef, trigger => Lock );
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
		my $guard = unlock( $self->months );
		push $self->months->@*, $month_name;
		$self->_clear_lookup;
		return $self;
	}
}

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

$list
	->push_month( 'Extrember' )
	->push_month( 'Extrember 2: Electric Boogaloo' );

is( $list->lookup_name( 'extrember' ), 13, 'lookup_name for extra month' );

done_testing;
