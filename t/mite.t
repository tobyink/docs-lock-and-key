use v5.24;
use Test2::V0;

use FindBin qw( $Bin );
use lib "$Bin/lib";
use Local2::MonthList;

my $list = 'Local2::MonthList'->new( months => [ qw{
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

$list->push_month( 'Extrember' );
$list->push_month( 'Extrember 2: Electric Boogaloo' );

is( $list->lookup_name( 'extrember' ), 13, 'lookup_name for extra month' );

done_testing;
