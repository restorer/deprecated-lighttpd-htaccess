#!/usr/bin/perl -w

use strict;
use File::Glob ':glob';
use File::Find;
use File::Basename;

my $document_root = '/var/www/';

# -------------------------------------------------------------------

my %already = ();
my @confs = ();
my $find_name = '';

sub find_confs
{
	my $file = $File::Find::name;
	my $name = basename($file);

	if ($name eq $find_name) {
		push(@confs, $file);
	}
}

# -------------------------------------------------------------------

sub print_lighttpd
{
	my $root = shift;

	@confs = ();
	$find_name = '.lighttpd';
	find(\&find_confs, $root);

	for my $conf_name (@confs)
	{
		my $url = dirname(substr($conf_name, length($root) - 1));
		$already{$url} = 1;

		my $url_sl = ($url eq '/' ? '/' : "$url/");

		my $url_esc = $url;
		$url_esc =~ s/\./\\./;

		my $dir = dirname($conf_name) . '/';

		open(F_CONF, $conf_name);
		my @lines = <F_CONF>;
		close(F_CONF);

		my @inner = ();
		my @outer = ();

		for my $line (@lines)
		{
			chomp($line);

			$line =~ s/\{dir\}/$dir/g;
			$line =~ s/\{url\}/$url_sl/g;
			$line =~ s/\{root\}/$root/g;

			if ($line =~ /^\s*url\.rewrite/) {
			    push(@outer, $line);
			} else {
			    push(@inner, $line);
			}
		}

		my $conf = join("\n", @inner);
		my $outer_conf = join("\n", @outer);

		if ($url ne '/') {
    			print "\t\$HTTP[\"url\"] =~ \"^$url_esc/\" {\n";
		}

		print "$conf\n";

		if ($url ne '/') {
			print "\t}\n";
		}

		if ($outer_conf ne '') {
			print "$outer_conf\n";
		}
	}
}

# -------------------------------------------------------------------

my @ht_indexes = ();
my %ht_errors = ();
my $ht_deny_all = 0;
my @ht_rules = ();
my $ht_charset = '';

sub read_htaccess
{
	my $file = shift;

	open(F_CONF, $file);
	my @lines = <F_CONF>;
	close(F_CONF);

	@ht_indexes = ();
	%ht_errors = ();
	$ht_deny_all = 0;
	@ht_rules = ();
	$ht_charset = '';

#	for my $line (@lines)
#	{
#	}
}

sub print_htaccess
{
	my $root = shift;

	@confs = ();
	$find_name = '.htaccess';
	find(\&find_confs, $root);

	for my $conf_name (@confs)
	{
		my $url = dirname(substr($conf_name, length($root) - 1));

		if (!$already{$url})
		{
			read_htaccess($conf_name);
		}
	}
}

# -------------------------------------------------------------------

sub print_fastcgi
{
	my $root_name = shift;

	open(F_ORIG_INI, "/etc/php5/cgi/php.ini");
	open(F_INI, ">/var/run/lighttpd-runner/php-${root_name}.ini");

	while (<F_ORIG_INI>)
	{
		chomp;
		my $line = $_;

		if ($line =~ /^open_basedir\s*=/) {
			print F_INI "open_basedir = /var/www/$root_name\n";
		} else {
			print F_INI "$line\n";
		}
	}

	close(F_INI);
	close(F_ORIG_INI);

    print<<EOF
	fastcgi.server = ( ".php" => 
		((
			"bin-path" => "/usr/bin/php5-cgi -c /var/run/lighttpd-runner/php-${root_name}.ini",
			"socket" => "/tmp/php-${root_name}.socket",
			"max-procs" => 2,
			"idle-timeout" => 20,
			"bin-environment" => ( 
				"PHP_FCGI_CHILDREN" => "4",
				"PHP_FCGI_MAX_REQUESTS" => "10000"
			),
			"bin-copy-environment" => (
				"PATH", "SHELL", "USER"
			),
			"broken-scriptfilename" => "enable"
		))
	)
EOF
}

# -------------------------------------------------------------------

`mkdir -p /var/run/lighttpd-runner`;

chdir($document_root);
my @files = bsd_glob('*');

for my $root_name (@files)
{
	if ($root_name =~ /\./)
	{
		my $root = $document_root . $root_name . '/';

		my $root_name_esc = $root_name;
		$root_name_esc =~ s/\./\\./g;

		my @aliases = ();

		if (-e "$root/.enable-www")
		{
			push @aliases, 'www';
		}
		elsif (-e "$root/.aliases")
		{
			open(F_ALIASES, "$root/.aliases");
			my @lines = <F_ALIASES>;
			close(F_ALIASES);

			for my $line (@lines)
			{
				chomp($line);
				push @aliases, $line if $line ne '';
			}
		}

		if (@aliases) {
			my $aliases_str = join('\\.|', @aliases) . '\\.';
			print "\$HTTP[\"host\"] =~ \"^($aliases_str)?$root_name_esc\$\" {\n";
		} else {
			print "\$HTTP[\"host\"] =~ \"^$root_name_esc\$\" {\n";
		}

		unless (-e "$root/.disable-def") {
			print "\tserver.document-root = \"$root\"\n";
		}

		# print_fastcgi($root_name);

		%already = ();
		print_lighttpd($root);
		# print_htaccess($root);

		print "}\n";
	}
}
