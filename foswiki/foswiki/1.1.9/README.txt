Highlights of this release

     * Security, performance and bug fix Release

For users:

     * 44 bug fixes and 4 enhancements relative to 1.1.8
     * JQuery 2.x is the fastest, lightest JQuery, for an improved user
       experience.

For administrators:

     * Fixes several code issues that would block migration to recent
       versions of perl and certain CPAN modules.
     * Resolves two important performance issues, accumulation of CSS by
       TablePlugin, and a major memory leak for certain search strings.
     * Security changes:
          + TOPICLIST macro no longer reveals names of view restricted
            topics
          + username and password URL params are restricted to POST to the
            login script
          + Additional sanitizing of the URL path is performed.


Upgrade Instructions

   Always remember to run configure and save the configuration after an
   upgrade to check for configuration changes.

Changes to login using URL parameters

   All versions of foswiki previously allowed the username and password
   parameters to be provided on the URL. For ex:
   bin/view/Myweb/SomeTopic?username=JoeUser;password=SEcrET This has been
   changed to further restrict login.
     * username and password will only be accepted on POST type
       operations. a simple GET url with username and password will not
       accept the supplied credentials.
          + The previous behaviour can be restored by enabling
            $Foswiki::cfg{Session}{AcceptUserPwParamOnGET} in the
            configuration
     * username and password will only be accepted as login credentials on
       the view, viewauth and loginscripts.
          + Other scripts can be authorized by configuring
            $Foswiki::cfg{Session}{AcceptUserPwParam}

JQuery upgrade

   This release ships with several upgraded versions of JQuery including:
     * jQuery 1.10.1,
     * jQuery-2.0.2
     * jQuery-ui-1.10.3

   The default jQuery release is changed to version 1.8.3. It also
   replaces the deprecated JQuery Tooltip plugin with the new UI::Tooltip.
   Before upgrade, determine if any topics or plugins JQREQUIRE "tooltip".
   Those topics or plugins need to be upgraded to use the new UI::Tooltip.
   Upgraders should visit bin/configure and make the following changes to
   the Jquery configuration:
     * Update {JQueryPlugin}{JQueryVersion} to version 1.8.3
     * Disable {JQueryPlugin}{Plugins}{Tooltip}{Enabled} and
     * Enable {JQueryPlugin}{Plugins}{'UI::Tooltip'}{Enabled}

   The following optional plugins:Extensions.ClassificationPlugin,
   HarvestPlugin, ImagePlugin, NatSkin, SolrPlugin are
   known to use tooltip and if used, will require an upgrade to the latest
   version during the 1.1.9 upgrade.

   You might also start using jquery-2.0.2 to get the best performance and
   configure jQuery-1.10.1 to be served to old Internet Explorers
   automatically:
     * Update {JQueryPlugin}{JQueryVersion} to version 2.0.2
     * Set {JQueryPlugin}{JQueryVersionForOldIEs} to version 1.10.1

Upgrade package will include the Sandbox.WebHome topic

   The topic creator script has been improved, and the Sandbox topic
   was included in the upgrade package. Normally WebHome topics are
   never shipped in an upgrade package.

Module version strings and new module dependency since 1.1.6

   The Foswiki and default extension version strings have been changed
   from a developer oriented string Foswiki-1.1.5, Tue, 10 Apr 2012, build
   14595, to a simple perl version string - "v1.1.6". The "RELEASE" string
   will continue to be more descriptive and can be displayed with a new
   macro %WIKIRELEASE%.

   This adds a dependency on version 0.77 - the Perl module version class.
     * Sites using Perl 5.10.1 or newer have the correct version of
       version.
     * Sites on older versions of perl should install the latest version
       using CPAN or their system's package manager.

     ALERT! Before upgrading, verify that the installed version of
     CPAN:version is at least version 0.77. If not, upgrade
     CPAN:version before attempting to upgrade Foswiki! For example:

#>perl -Mversion -e 'print "$version::VERSION\n"'
0.9901

New setting needed for PatternSkin

   If PatternSkin is installed on an older Foswiki, or the
   Foswiki-upgrade package is used to upgrade an existing Foswiki system,
   there is a new required setting that must be added to
   Main.SitePreferences.

   * Set PATTERNSKIN_JQUERY_THEME = PatternSkinTheme

   The new System.DefaultPreferences topic shipped with the upgrade
   package does have this setting, but if you have customized you
   DefaultPreferences, then this needs to be added.

   Also, you'll need to go through one save cycle of configure to register
   the new JQuery pattern theme in the configuration. (If configure
   reports no changes, make a minor change and save again, and configure
   will merge in the changed settings). Or edit the LocalSite.cfg file by
   hand and add

$Foswiki::cfg{JQueryPlugin}{Themes}{PatternSkinTheme}{Url} = '$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/PatternSkinTheme/jquery-ui.css';
$Foswiki::cfg{JQueryPlugin}{Themes}{PatternSkinTheme}{Enabled} = 1;

Other important things to know.

   Most extensions released since Foswiki 1.1.6 have converted to formal
   perl version strings. version->declare('v1.1.6'). The
   PatchFoswikiContrib must be installed on older versions of Foswiki
   before installing any of these extensions on older Foswiki versions.
   Note that they have not been tested on Foswiki 1.0

Installation

   Please refer to the INSTALL.html which can be found the downloaded
   tgz/zip.

License

     * This program is free software; you can redistribute it and/or
       modify it under the terms of the GNU General Public License as
       published by the Free Software Foundation; either version 2 of the
       License, or (at your option) any later version.
     * This program is distributed in the hope that it will be useful, but
       WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
     * See the GNU General Public License for more details, published at
       http://www.gnu.org/copyleft/gpl.html

Release Details

     * Build date 2013-11-18
     * Publish date 2013-11-19
     * Built from http://svn.foswiki.org/branches/Release01x01 svn
       revision 17101

