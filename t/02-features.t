#!perl

use lib 't/lib';
use TestPlan;
use TestCustomer;
use Test::More tests => 14;

my $pa = TestPlan->new(name => 'PA', features => ['ssl', ['storage', '5GB']]);
my $pb = TestPlan->new(name => 'PB', features => ['backups', ['storage', '10GB']], plans => [$pa]);
my $pc = TestPlan->new(name => 'PC', features => ['backups', ['phone_support', '24hrs']]);

my $ca = TestCustomer->new(name => 'CA', plans => [$pa]);
my $cb = TestCustomer->new(name => 'CB', plans => [$pb], features => [['phone_support', '12h']]);
my $cc = TestCustomer->new(name => 'CC', plans => [$pc]);
my $cd = TestCustomer->new(name => 'CD', features => [['storage', '200GB']]);

ok($pa, 'Got PA');
ok($pb, 'Got PB');
ok($pc, 'Got PC');
ok($ca, 'Got CA');
ok($cb, 'Got CB');
ok($cc, 'Got CC');
ok($cd, 'Got CD');

ok($ca->in_plan('PA'), 'CA in PA');
ok(!$ca->in_plan('PB'), 'CA not in PB');
ok($cb->inherits_plan('PA'), 'CB inherits PA');
ok(!$cb->in_plan('PA'), 'CB not in PA');
ok($cc->in_plan('PC'), 'CC in PC');
ok(!$cc->inherits_plan('PB'), 'CC does not inherit PB');
ok(!$cd->in_plan('PA'), 'CD not in PA');

done_testing();
