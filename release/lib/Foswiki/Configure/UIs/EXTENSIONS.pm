# See bottom of file for license and copyright information
package Foswiki::Configure::UIs::EXTENSIONS;
use base 'Foswiki::Configure::UI';

use strict;
use Foswiki::Configure::Type;

my @tableHeads =
  qw(image topic description version installedVersion testedOn install );
my %headNames = (
    image            => '',
    topic            => 'Extension',
    description      => 'Description',
    version          => 'Most&nbsp;Recent&nbsp;Version',
    installedVersion => 'Installed Version',
    testedOn         => 'Tested On Foswiki',
    testedOnOS       => 'Tested On OS',
    install          => 'Action',
);

# Download the report page from the repository, and extract a hash of
# available extensions
sub _getListOfExtensions {
    my $this = shift;

    $this->findRepositories();

    if ( !$this->{list} ) {
        $this->{list}   = {};
        $this->{errors} = [];
        foreach my $place ( @{ $this->{repositories} } ) {
            $place->{data} =~ s#/*$#/#;
            print CGI::div("Consulting $place->{name}...");
            my $url =
              $place->{data} . 'FastReport?skin=text';
            my $response = $this->getUrl($url);
            if ( !$response->is_error() ) {
                my $page = $response->content();
                $page =~ s/{(.*?)}/$this->_parseRow($1, $place)/ges;
            }
            else {
                push(
                    @{ $this->{errors} },
                    "Error accessing $place->{name}: " . $response->message()
                );

                #see if its because LWP isn't installed..
                eval "require LWP";
                if ($@) {
                    push(
                        @{ $this->{errors} },
"This is most likely because the LWP CPAN module isn't installed."
                    );
                }
            }
        }
    }
    return $this->{list};
}

sub _parseRow {
    my ( $this, $row, $place ) = @_;
    my %data;
    return '' unless $row =~ s/^ *(\w+): *(.*?) *$/$data{$1} = $2;''/gem;
    ($data{installedVersion},
     $data{namespace}) = $this->_getInstalledVersion( $data{topic} );
    $data{repository}       = $place->{name};
    $data{data}             = $place->{data};
    $data{pub}              = $place->{pub};
    die "$row: " . Data::Dumper->Dump( [ \%data ] ) unless $data{topic};
    $this->{list}->{ $data{topic} } = \%data;
    return '';
}

sub ui {
    my $this  = shift;
    my $table = '';

    my $rows      = 0;
    my $installed = 0;
    my $exts      = $this->_getListOfExtensions();
    foreach my $error ( @{ $this->{errors} } ) {
        $table .= CGI::Tr( { class => 'foswikiAlert' },
                           CGI::td( { colspan => "7" }, $error ) );
    }

    $table .= CGI::Tr(
        join( '',
              map { CGI::th( { valign => 'bottom' }, $headNames{$_} ) }
                @tableHeads )
       );
    foreach my $key ( sort keys %$exts ) {
        my $ext = $exts->{$key};
        my $row = '';
        foreach my $f (@tableHeads) {
            my $text;
            if ( $f eq 'install' ) {
                my @script     = File::Spec->splitdir( $ENV{SCRIPT_NAME} );
                my $scriptName = pop(@script);
                $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

                my $link =
                  $scriptName
                    . '?action=InstallExtension'
                      . ';repository='
                        . $ext->{repository}
                          . ';extension='
                            . $ext->{topic};
                $text = 'Install';
                if ( $ext->{installedVersion} ) {
                    $text = 'Upgrade';
                    $installed++;
                }
                $text = CGI::a( { href => $link }, $text );
            }
            else {
                $text = $ext->{$f} || '-';
                if ( $f eq 'topic' ) {
                    my $link = $ext->{data} . $ext->{topic};
                    $text = CGI::a( { href => $link }, $text );
                } elsif ($f eq 'image' && $ext->{namespace} &&
                           $ext->{namespace} ne 'Foswiki') {
                    $text = "$text ($ext->{namespace})";
                }
            }
            my %opts = ( valign => 'top' );
            if ($ext->{namespace} && $ext->{namespace} ne 'Foswiki') {
                $opts{class} = 'alienExtension';
            }
            $row .= CGI::td( \%opts, $text );
        }
        my @classes = ( $rows % 2 ? 'odd' : 'even' );
        if ($ext->{installedVersion}) {
            push @classes, qw( patternAccessKeyInfo installed );
            push @classes, 'twikiExtension'
              if $ext->{installedVersion} =~ /\(TWiki\)/;
        }
        $table .= CGI::Tr( { class => join( ' ', @classes ) }, $row );
        $rows++;
    }
    $table .= CGI::Tr(
        { class => 'patternAccessKeyInfo' },
        CGI::td(
            { colspan => "7" },
            $installed
              . ' extension'
                . ( $installed == 1 ? '' : 's' )
                  . ' out of '
                    . $rows
                      . ' already installed'
                     )
         );
    my $page = <<INTRO;
<div class="foswikiHelp">Note that the webserver user has to be able to
write files everywhere in your Foswiki installation. Otherwise you may see
'No permission to write' errors during extension installation.</div>
INTRO
    $page .= CGI::table( { class => 'foswikiTable extensionsTable' }, $table );
    return $page;
}

sub _getInstalledVersion {
    my ( $this, $module ) = @_;
    my $lib;

    return undef unless $module;

    if ( $module =~ /Plugin$/ ) {
        $lib = 'Plugins';
    }
    else {
        $lib = 'Contrib';
    }

    my $release;
    my $from;
    foreach my $frm qw(Foswiki TWiki) {
        my $path = $frm.'::'.$lib.'::'.$module;
        eval "use $path";
        next if $@;

        $from = $frm;
        $release = eval '$'.$path.'::RELEASE';

        my $version;
        $version = eval '$'.$path.'::VERSION';
        if ($version) {
            # tidy up the subversion rev number
            $version =~ s/^\s*\$Rev:\s*(.*?)\s*\$$/$1/;
            $version =~ s/(\d+)\s\((.*)\)/$1, $2/;
            if ($release) {
                $release .= " ($version)";
            } else {
                $release = $version;
            }
        }
        $release ||= '';
        $release =~ s/\$Date:\s*([^\$]*)\s*\$/$1/;
        last;
    }

    return ($release, $from);
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.