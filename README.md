What is it?
===========

Virtual hosts + per-directory config for lighttpd.

Project goal is to automatically convert .htaccess files into lighttpd config,
but currently .htaccess is **NOT** supported.

But you can convert .htaccess files into .lighttpd, it's easy
(except "RewriteCond %{REQUEST_FILENAME} !-f" - there is no easy way to convert it).

**examples** folder contains ready-to-go configuration files for some popular projecs.

How to install
==============

  - Ensure that mod_rewrite and mod_redirect included into server.modules
  - Set server.document-root to "/var/www/default"
  - Ensure that ".lighttpd", ".enable-www", and ".aliases" is not readable from browser
  - Put enable-sites.pl in /usr/share/lighttpd
  - Append include_shell "/usr/share/lighttpd/enable-sites.pl" to the end of lighttpd.conf

Directory structure
===================

    |- var
    |  |- www
    |  |  |- somehost.com
    |  |  |  |- .aliases
    |  |  |  |- .lighttpd
    |  |  |  |- somefile.php
    |  |  |  |- sources
    |  |  |  |  |- .lighttpd
    |  |  |  |  |- nextfile.php
    |  |  |  |- ...
    |  |  |- anotherhost.net
    |  |  |  |- .enable-www
    |  |  |  |- .lighttpd
    |  |  |  |- anotherfile.php
    |  |  |  |- ...

.aliases
========

Put domain aliases one per line.
If domain is "somehost.com" and .aliases is:

```
www
temp
m
```

Than folder will be accessible at somehost.com, www.somehost.com, temp.somehost.com, and m.somehost.com

.enable-www
===========

Empty file. Same as append "www" to .aliases.
If domain is "anotherhost.net" and there is .enable-www in it's folder,
than folder will be accessible at anotherhost.net and www.anotherhost.net

.lighttpd
=========

Per-directory configuration file.
Following substitutions available:

**{root}** - root path of current virtual host folder with trailing slash (for example "/var/www/somehost.com/")
**{dir}** - current directory path with trailing slash (for example "/var/www/somehost.com/sources/")
**{url}** - current directory url with trailing slash (for example "/sources/")

Example of lighttpd.conf
========================

```
server.modules = (
    "mod_access",
    "mod_alias",
    "mod_rewrite", # Ensure that mod_rewrite and mod_redirect included into server.modules
    "mod_redirect" # Ensure that mod_rewrite and mod_redirect included into server.modules
)

server.document-root = "/var/www/default" # Set server.document-root to "/var/www/default"
server.upload-dirs = ( "/var/cache/lighttpd/uploads" )
server.errorlog = "/var/log/lighttpd/error.log"
server.pid-file = "/var/run/lighttpd.pid"
server.username = "www-data"
server.groupname = "www-data"

index-file.names = (
    "index.php",
    "index.html",
    "index.htm",
    "default.htm"
)

url.access-deny = ( "~", ".inc" )
static-file.exclude-extensions = ( ".php", ".pl", ".fcgi" )
include_shell "/usr/share/lighttpd/use-ipv6.pl"

# Ensure that ".lighttpd", ".enable-www", and ".aliases" is not readable from browser
# Easy way - just deny all hidden files
$HTTP["url"] =~ "/\." {
    url.access-deny = ( "" )
}

dir-listing.encoding = "utf-8"
server.dir-listing = "disable"

include_shell "/usr/share/lighttpd/create-mime.assign.pl"
include_shell "/usr/share/lighttpd/include-conf-enabled.pl"

# Append include_shell "/usr/share/lighttpd/enable-sites.pl" to the end of lighttpd.conf
include_shell "/usr/share/lighttpd/enable-sites.pl"
```
