#!/usr/bin/perl -w

use Sort::Versions;

use strict;
use warnings;

#get the releases already unzipped
my @tags = `git tag 2>&1`;
if (scalar(@tags) && $tags[0] =~ /fatal:.*/) {
    print "initialising new git repo\n";
    die 'what?';
    `git init .`;
    `git add .`;
    `git commit -m 'initial repository, commit all release zips'`;
}

my %tagged;
map {chomp ; $tagged{$_} = 1;} @tags;

print join(',', keys(%tagged));


#mmm, one line with \n on end per file

#this is an rsync from sourceforge, so its a bit weird.
#first the OldFiles layout
my @oldreleases = `ls foswiki/OldFiles/*.zip`;
#now the new, in directories layout
my @newreleases = sort { versioncmp($a, $b) } `ls foswiki/foswiki`;

my @releases;
foreach (@oldreleases) {chomp;push(@releases, $_) unless ($_ =~ /upgrade/)};
foreach (@newreleases) {chomp;push(@releases, 'foswiki/foswiki/'.$_.'/Foswiki-'.$_.'.zip') unless ($_ =~ /upgrade/)};

#die join("\n", @releases);

my $count=0;

mkdir('release') unless (-e 'release');
foreach my $zip (@releases) {

    my $tag = $zip;
    $tag =~ s/\.zip//;
    $tag =~ s/.*Foswiki-//;

    if (defined($tagged{$tag})) {
        print "skipping $tag\n";
        next;
    }
    $count++;
    print "unziping $tag\n";
    
    `unzip $zip`;
    #delete all the files and dirs,
    `chmod -R 777 release`;
    `rm -r release`;
    mkdir('release');
    `cp -r Foswiki-$tag/* release`;
    
    `git add -A release`;
    `git commit -m '$zip'`;
    `git tag -a $tag -m '$zip'`;

    #last if ($count > 2);   #testing.
}
