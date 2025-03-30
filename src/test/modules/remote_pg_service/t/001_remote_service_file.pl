
use FindBin;
use lib $FindBin::RealBin;

use PgRemoteService::Server;

my $server = PgRemoteService::Server->new();
$server->run();

my $port = $server->port;
my $issuer = "http://127.0.0.1:$port";

# test against $issuer...

$server->stop;
