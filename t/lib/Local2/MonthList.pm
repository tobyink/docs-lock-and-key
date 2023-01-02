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
