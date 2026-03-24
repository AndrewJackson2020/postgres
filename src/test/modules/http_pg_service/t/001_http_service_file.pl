use strict;
use warnings FATAL => 'all';

use FindBin;
use lib $FindBin::RealBin;

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

use PgHttpService::Server;

if ($ENV{with_libcurl} ne 'yes')
{
	plan skip_all => 'HTTP service file not supported by this build';
}

if ($ENV{with_python} ne 'yes')
{
	plan skip_all => 'HTTP service tests require --with-python to run';
}

my $td = PostgreSQL::Test::Utils::tempdir;

my $node_dummy = PostgreSQL::Test::Cluster->new('node_dummy');
$node_dummy->init;

my $node = PostgreSQL::Test::Cluster->new('node');
$node->init;
$node->start;

# Windows vs non-Windows: CRLF vs LF for the file's newline, relying on
# the fact that libpq uses fgets() when reading the lines of a service file.
my $newline = "\n";

# Create the set of service files used in the tests.
# File that includes a valid service name, that uses a decomposed connection
# string for its contents, split on spaces.
my $srvfile_valid = "$td/pg_service_valid.conf";
append_to_file($srvfile_valid, "[my_srv]");
append_to_file($srvfile_valid, $newline);
append_to_file($srvfile_valid, "port=");
append_to_file($srvfile_valid, $node->port());
append_to_file($srvfile_valid, $newline);
append_to_file($srvfile_valid, "host=");
append_to_file($srvfile_valid, $node->host());
append_to_file($srvfile_valid, $newline);
append_to_file($srvfile_valid, "dbname=postgres");
append_to_file($srvfile_valid, $newline);

# File defined with no contents, used as default value for PGSERVICEFILE,
# so as no lookup is attempted in the user's home directory.
my $srvfile_empty = "$td/pg_service_empty.conf";
append_to_file($srvfile_empty, '');

my $server = PgHttpService::Server->new();
$server->run($srvfile_valid);

my $port = $server->port;
my $issuer = "http://127.0.0.1:$port";

# Set the fallback directory lookup of the service file to the temporary
# directory of this test.  PGSYSCONFDIR is used if the service file
# defined in PGSERVICEFILE cannot be found, or when a service file is
# found but not the service name.
local $ENV{PGSYSCONFDIR} = $td;

# Force PGSERVICEFILE to a default location, so as this test never
# tries to look at a home directory.  This value needs to remain
# at the top of this script before running any tests, and should never
# be changed.
local $ENV{PGSERVICEFILE} = "$srvfile_empty";

{
	local $ENV{PGSERVICEFILE} = $issuer;

	$node_dummy->connect_ok(
		'service=my_srv',
		'connection with correct "service" string and PGSERVICEFILE',
		sql => "SELECT 'connect1_1'",
		expected_stdout => qr/connect1_1/);

	$node_dummy->connect_ok(
		'postgres://?service=my_srv',
		'connection with correct "service" URI and PGSERVICEFILE',
		sql => "SELECT 'connect1_2'",
		expected_stdout => qr/connect1_2/);

	$node_dummy->connect_fails(
		'service=non_existant_service',
		'connection with incorrect PGSERVICE and correct PGSERVICEFILE',
		expected_stdout =>
		  qr/definition of service "undefined-service" not found/);

	$node_dummy->connect_fails(
		'',
		'connection with blank string');

	local $ENV{PGSERVICE} = 'my_srv';
	$node_dummy->connect_ok(
		'',
		'connection with correct PGSERVICE and PGSERVICEFILE',
		sql => "SELECT 'connect1_3'",
		expected_stdout => qr/connect1_3/);

	local $ENV{PGSERVICE} = 'undefined-service';
	$node_dummy->connect_fails(
		'',
		'connection with incorrect PGSERVICE and PGSERVICEFILE',
		expected_stdout =>
		  qr/definition of service "undefined-service" not found/);
}
$server->stop;

$node->teardown_node;

done_testing();
