#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Abilities' ) || print "Bail out!
";
}

diag( "Testing Abilities $Abilities::VERSION, Perl $], $^X" );
