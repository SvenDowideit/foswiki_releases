# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008-2009 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is Foswiki's Spreadsheet Plugin.
#

package Foswiki::Plugins::SpreadSheetPlugin;

use strict;

# =========================
use vars qw(
  $web $topic $user $installWeb $debug $skipInclude $doInit
);

our $VERSION           = '$Rev: 5484 (2009-11-10) $';
our $RELEASE           = '10 Nov 2009';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
'Add spreadsheet calculations like "$SUM($ABOVE())" to Foswiki tables and other topic text';

$doInit = 0;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between SpreadSheetPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag("SPREADSHEETPLUGIN_DEBUG") || 0;

    # Flag to skip calc if in include
    $skipInclude =
      Foswiki::Func::getPreferencesFlag("SPREADSHEETPLUGIN_SKIPINCLUDE") || 1;

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::SpreadSheetPlugin::initPlugin( $web.$topic ) is OK"
    ) if $debug;
    $doInit = 1;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug(
        "- SpreadSheetPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    if ( ( $_[3] ) && ($skipInclude) ) {

        # bail out, handler called from an %INCLUDE{}%
        return;
    }
    unless ( $_[0] =~ /%CALC\{.*?\}%/ ) {

        # nothing to do
        return;
    }

    require Foswiki::Plugins::SpreadSheetPlugin::Calc;

    if ($doInit) {
        $doInit = 0;
        Foswiki::Plugins::SpreadSheetPlugin::Calc::init( $web, $topic, $debug );
    }
    Foswiki::Plugins::SpreadSheetPlugin::Calc::CALC(@_);
}

1;

# EOF