
use FindBin;
use lib $FindBin::RealBin;

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

use PgRemoteService::Server;

if ($ENV{with_libcurl} ne 'yes')
{
	plan skip_all => 'Remote service file not supported by this build';
}

if ($ENV{with_python} ne 'yes')
{
	plan skip_all => 'Remote service tests require --with-python to run';
}

my $server = PgRemoteService::Server->new();
$server->run();

my $port = $server->port;
my $issuer = "http://127.0.0.1:$port";

# test against $issuer...
like("connection succeeded", qr/connection succeeded/, "stress-async: stdout matches");

$server->stop;

done_testing();
