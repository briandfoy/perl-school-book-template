use lib "lib";
use Test::More;

use Local::Test::PseudoPod;

pseudopod_ok( glob( 'pod/*.pod' ) );

done_testing();
