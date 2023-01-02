{
package Local2::MonthList;
use strict;
use warnings;
no warnings qw( once void );

our $USES_MITE = "Mite::Class";
our $MITE_SHIM = "Local2::Mite";
our $MITE_VERSION = "0.012000";
# Mite keywords
BEGIN {
    my ( $SHIM, $CALLER ) = ( "Local2::Mite", "Local2::MonthList" );
    ( *after, *around, *before, *extends, *has, *signature_for, *with ) = do {
        package Local2::Mite;
        no warnings 'redefine';
        (
            sub { $SHIM->HANDLE_after( $CALLER, "class", @_ ) },
            sub { $SHIM->HANDLE_around( $CALLER, "class", @_ ) },
            sub { $SHIM->HANDLE_before( $CALLER, "class", @_ ) },
            sub {},
            sub { $SHIM->HANDLE_has( $CALLER, has => @_ ) },
            sub { $SHIM->HANDLE_signature_for( $CALLER, "class", @_ ) },
            sub { $SHIM->HANDLE_with( $CALLER, @_ ) },
        );
    };
};

# Mite imports
BEGIN {
    *false = \&Local2::Mite::false;
    *true = \&Local2::Mite::true;
};

# Gather metadata for constructor and destructor
sub __META__ {
    no strict 'refs';
    my $class      = shift; $class = ref($class) || $class;
    my $linear_isa = mro::get_linear_isa( $class );
    return {
        BUILD => [
            map { ( *{$_}{CODE} ) ? ( *{$_}{CODE} ) : () }
            map { "$_\::BUILD" } reverse @$linear_isa
        ],
        DEMOLISH => [
            map { ( *{$_}{CODE} ) ? ( *{$_}{CODE} ) : () }
            map { "$_\::DEMOLISH" } @$linear_isa
        ],
        HAS_BUILDARGS => $class->can('BUILDARGS'),
        HAS_FOREIGNBUILDARGS => $class->can('FOREIGNBUILDARGS'),
    };
}


# Standard Moose/Moo-style constructor
sub new {
    my $class = ref($_[0]) ? ref(shift) : shift;
    my $meta  = ( $Mite::META{$class} ||= $class->__META__ );
    my $self  = bless {}, $class;
    my $args  = $meta->{HAS_BUILDARGS} ? $class->BUILDARGS( @_ ) : { ( @_ == 1 ) ? %{$_[0]} : @_ };
    my $no_build = delete $args->{__no_BUILD__};

    # Attribute months (type: ArrayRef)
    # has declaration, file lib/Local2/MonthList.pm, line 6
    if ( exists $args->{"months"} ) { do { package Local2::Mite; ref($args->{"months"}) eq 'ARRAY' } or Local2::Mite::croak "Type check failed in constructor: %s should be %s", "months", "ArrayRef"; $self->{"months"} = $args->{"months"}; } ;
    Local2::Mite::lock($self->{"months"}) if ref $self->{"months"};

    # Attribute _lookup
    # has declaration, file lib/Local2/MonthList.pm, line 14
    if ( exists $args->{"_lookup"} ) { $self->{"_lookup"} = $args->{"_lookup"}; } ;


    # Call BUILD methods
    $self->BUILDALL( $args ) if ( ! $no_build and @{ $meta->{BUILD} || [] } );

    # Unrecognized parameters
    my @unknown = grep not( /\A(?:_lookup|months)\z/ ), keys %{$args}; @unknown and Local2::Mite::croak( "Unexpected keys in constructor: " . join( q[, ], sort @unknown ) );

    return $self;
}

# Used by constructor to call BUILD methods
sub BUILDALL {
    my $class = ref( $_[0] );
    my $meta  = ( $Mite::META{$class} ||= $class->__META__ );
    $_->( @_ ) for @{ $meta->{BUILD} || [] };
}

# Destructor should call DEMOLISH methods
sub DESTROY {
    my $self  = shift;
    my $class = ref( $self ) || $self;
    my $meta  = ( $Mite::META{$class} ||= $class->__META__ );
    my $in_global_destruction = defined ${^GLOBAL_PHASE}
        ? ${^GLOBAL_PHASE} eq 'DESTRUCT'
        : Devel::GlobalDestruction::in_global_destruction();
    for my $demolisher ( @{ $meta->{DEMOLISH} || [] } ) {
        my $e = do {
            local ( $?, $@ );
            eval { $demolisher->( $self, $in_global_destruction ) };
            $@;
        };
        no warnings 'misc'; # avoid (in cleanup) warnings
        die $e if $e;       # rethrow
    }
    return;
}

my $__XS = !$ENV{PERL_ONLY} && eval { require Class::XSAccessor; Class::XSAccessor->VERSION("1.19") };

# Accessors for _lookup
# has declaration, file lib/Local2/MonthList.pm, line 14
sub _clear__lookup { @_ == 1 or Local2::Mite::croak( 'Clearer "_clear__lookup" usage: $self->_clear__lookup()' ); delete $_[0]{"_lookup"}; $_[0]; }
sub _lookup { @_ == 1 or Local2::Mite::croak( 'Reader "_lookup" usage: $self->_lookup()' ); ( exists($_[0]{"_lookup"}) ? $_[0]{"_lookup"} : ( $_[0]{"_lookup"} = $_[0]->_build__lookup ) ) }

# Accessors for months
# has declaration, file lib/Local2/MonthList.pm, line 6
if ( $__XS ) {
    Class::XSAccessor->import(
        chained => 1,
        "getters" => { "months" => "months" },
    );
}
else {
    *months = sub { @_ == 1 or Local2::Mite::croak( 'Reader "months" usage: $self->months()' ); $_[0]{"months"} };
}

# Delegated methods for months
# has declaration, file lib/Local2/MonthList.pm, line 6
*push_month = sub {
my $mite_guard = Local2::Mite::unlock($_[0]->{"months"});
my $shv_self=shift;
1;
my $shv_ref_invocant = do { $shv_self->months };
push(@{$shv_ref_invocant}, @_)
};

# See UNIVERSAL
sub DOES {
    my ( $self, $role ) = @_;
    our %DOES;
    return $DOES{$role} if exists $DOES{$role};
    return 1 if $role eq __PACKAGE__;
    if ( $INC{'Moose/Util.pm'} and my $meta = Moose::Util::find_meta( ref $self or $self ) ) {
        $meta->can( 'does_role' ) and $meta->does_role( $role ) and return 1;
    }
    return $self->SUPER::DOES( $role );
}

# Alias for Moose/Moo-compatibility
sub does {
    shift->DOES( @_ );
}

1;
}