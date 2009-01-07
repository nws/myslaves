#!/usr/bin/perl
use strict;
use warnings;

if ($>) {
	die "you are not root. please become root.\n";
}

if (not @ARGV) {
	die "usage: $0 <slave_label>\n";
}

my $label = shift @ARGV;
if ($label !~ m/^\w+$/) {
	die "label $label is badly formatted (the usual is allowed...)\n";
}

use constant {
	MYSQL_USER => 'mysql',
	MYSQL_BASE_PORT => 3306,
	MYSQL_INSTALL_DB => '/usr/bin/mysql_install_db',

	CONF_DIR => '/etc/mysql-slaves/',
	DATA_DIR => '/var/lib/mysql-slaves/',
	RUN_DIR => '/var/run/mysql-slaves/',
};

ensure_dir(CONF_DIR);
ensure_dir(DATA_DIR);
ensure_dir(RUN_DIR);
chown_dir(RUN_DIR);

if (slave_exists($label)) {
	die "slave $label already exists\n";
}

my $port = get_next_free_port();
my $config = create_config($label, $port);
if (not $config) {
	die "cannot create config for slave $label\n";
}
write_config($label, $config) or die "cannot write config for $label\n";

if (not init_db($label)) {
	die "cannot init db for slave $label\n";
}

print "created $label on $port\n";

exit 0;

### SUBS ###

sub init_db {
	my $label = shift;
	ensure_dir(DATA_DIR.$label);
	chown_dir(DATA_DIR.$label);
	return !system(MYSQL_INSTALL_DB.' --datadir='.DATA_DIR.$label.' --user='.MYSQL_USER);
}

sub get_next_free_port {
	my $freeport = MYSQL_BASE_PORT;

	opendir my $dh, CONF_DIR or die "cannot open @{[CONF_DIR]}: $!\n";
	while (my $e = readdir $dh) {
		next unless $e =~ m/\.cnf$/;
		my $port = find_used_port($e);
		if (defined $port and $port > $freeport) {
			$freeport = $port;
		}
	}
	closedir $dh;

	return $freeport+1;
}

sub find_used_port {
	my $fn = shift;
	my $used;
	open my $fh, CONF_DIR.$fn or die "cannot open $fn: $!\n";
	while (<$fh>) {
		next unless m/#!!!DO NOT MODIFY THIS MARKER!!!#/;
		if (m/port\s*=\s*(\d+)/) {
			$used = $1;
			last;
		}
	}
	close $fh;
	return $used;
}

sub write_config {
	my ($label, $cfg) = @_;
	open my $fh, '>', CONF_DIR.$label.'.cnf' or return 0;
	print $fh $cfg;
	close $fh;
	return 1;
}

sub create_config {
	my ($label, $port) = @_;

	my $user = MYSQL_USER;

	my $conf = <<EOS;
[client]
port		= $port
socket		= @{[RUN_DIR]}mysqld.sock.$label
[mysqld_safe]
socket		= @{[RUN_DIR]}mysqld.sock.$label
nice		= 0
[mysqld]
user		= $user
pid-file	= @{[RUN_DIR]}mysqld.pid.$label
socket		= @{[RUN_DIR]}mysqld.sock.$label
port		= $port #!!!DO NOT MODIFY THIS MARKER!!!#
basedir		= /usr
datadir		= @{[DATA_DIR]}$label
tmpdir		= /tmp
language	= /usr/share/mysql/english
skip-external-locking
bind-address		= 127.0.0.1
key_buffer		= 16M
max_allowed_packet	= 16M
thread_stack		= 128K
thread_cache_size	= 8
myisam-recover		= BACKUP
query_cache_limit       = 1M
query_cache_size        = 16M
skip-bdb
[mysqldump]
quick
quote-names
max_allowed_packet	= 16M
[mysql]
[isamchk]
key_buffer		= 16M
!includedir /etc/mysql/conf.d/

EOS
	return $conf;
}

sub slave_exists {
	my $label = shift;
	return -f CONF_DIR.$label.'.cnf';
}

sub chown_dir {
	my $dir = shift;
	my ($login, $pass, $uid, $gid) = getpwnam(MYSQL_USER);
	chown $uid, $gid, $dir or die "cannot chown $dir: $!\n";
}

sub ensure_dir {
	my $dir = shift;
	if (-e $dir and not -d $dir) {
		die "$dir exists but is not a dir\n";
	}
	
	if (not -e _) {
		mkdir $dir or die "cannot mkdir $dir: $!\n";
	}
}


