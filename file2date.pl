#!/usr/local/bin/perl -w
# -*- CPerl -*-
# $Id$

# <http://nais.to/~yto/tools/file2date/> ¤Î²þÎÉÈÇ

# convert file name "dir/dir/foo.ext" to "year-month-day-hour-min-sec.ext"
# Usage: prog file [file ...]
# Ex: dcp_0003.jpg --> 2001-06-23T20:05:32.jpg
# Ex: /home/yto/e-01.txt --> 2001-06-12T14:32:10.txt

use strict;
use POSIX qw(strftime);
use File::Copy;
use File::Basename;

main();
sub main {
    usage() unless  defined($ARGV[0]);

    foreach my $fname (@ARGV) {
	if (! -f $fname) {
	    print "$fname (skip)\n";
	    next;
	}
	my ($name, $path, $ext) = fileparse($fname, '\..*');
	$ext = lc $ext;
	my $date = strftime "%Y-%m-%d", localtime((stat $fname)[9]);
	my $time = strftime "%H:%M:%S", localtime((stat $fname)[9]);
	my $dir = mkdir_p($basedir, $date);
	if (-e "$dir/$time$ext") {
	    for my $dummy ('a'..'z') {
		if (!-e "$dir/$time$dummy$ext") {
		    $time .= $dummy;
		    last;
		}
	    }
	}
	print "$fname --> $dir/$time$ext\n";
	copy($fname, "$dir/$time$ext");
	utime((stat $fname)[8, 9], "$dir/$time$ext"); # set timestamps
    }
}

sub usage() {
    print "Usage: $0 files... dir\n";
    exit;
}
