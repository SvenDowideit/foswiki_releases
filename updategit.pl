#!/usr/bin/perl -w

use strict;
use warnings;

#mmm, one line with \n on end per file
#TODO: opendir....
my @releases = `ls zips`;
#print join("", @releases);

my @tags = `git tag 2>&1`;
if ($tags[0] =~ /fatal:.*/) {
    print "initialising new git repo\n";
    `git init .`;
    `git add .`;
    `git commit -m 'initial repository, commit all release zips'`;
}

my %tagged;
map {chomp ; $tagged{$_} = 1;} @tags;

print join(',', keys(%tagged));

my $count=0;

chdir('twiki');
foreach my $zip (@releases) {
    chomp $zip;

    my $tag = $zip;
    $tag =~ s/\.zip//;

    if (defined($tagged{$tag})) {
        print "skipping $tag\n";
        next;
    }
    $count++;
    print "unziping $tag\n";
    
    #delete all the files and dirs,
    `chmod -R 777 *`;
    `rm -r *`;
    `unzip ../zips/$zip`;
    `git add -A`;
    `git commit -m '$zip'`;
    `git tag -a $tag -m '$zip'`;
    
#    last if ($count > 5);   #testing.
}
