# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Meta

Objects of this class act as handles onto real store objects. An
object of this class can represent the Foswiki root, a web, or a topic.

Meta objects interact with the store using only the methods of
Foswiki::Store. The rest of the core should interact only with Meta
objects; the only exception to this are the *Exists methods that are
published by the store interface (and facaded by the Foswiki class).

A meta object exists in one of two states; either unloaded, in which case
it is simply a lightweight handle to a store location, and loaded, in
which case it acts as a portal onto the actual store content of a specific
revision of the topic.

An unloaded object is constructed by the =new= constructor on this class,
passing one to three parameters depending on whether the object represents the
root, a web, or a topic.

A loaded object may be constructed by calling the =load= constructor, or
a previously constructed object may be converted to 'loaded' state by
calling =loadVersion=. Once an object is loaded with a specific revision, it
cannot be reloaded.

Unloaded objects return undef from =getLoadedRev=, or the loaded revision
otherwise.

An unloaded object can be populated through calls to =text($text)=, =put=
and =putKeyed=. Such an object can be saved using =save()= to create a new
revision of the topic.

To the caller, a meta object carries two types of data. The first
is the "plain text" of the topic, which is accessible through the =text()=
method. The object also behaves as a hash of different types of
meta-data (keyed on the type, such as 'FIELD' and 'FILEATTACHMENT').

Each entry in the hash is an array, where each entry in the array
contains another hash of the key=value pairs, corresponding to a
single meta-datum.

If there may be multiple entries of the same top-level type (i.e. for FIELD
and FILEATTACHMENT) then the array has multiple entries. These types
are referred to as "keyed" types. The array entries are keyed with the
attribute 'name' which must be in each entry in the array.

For unkeyed types, the array has only one entry.

Pictorially,
   * TOPICINFO
      * author => '...'
      * date => '...'
      * ...
   * FILEATTACHMENT
      * [0] = { name => 'a' ... }
      * [1] = { name => 'b' ... }
   * FIELD
      * [0] = { name => 'c' ... }
      * [1] = { name => 'd' ... }

Implementor note: the =_indices= field gives a quick lookup into this
structure; it is a hash of top-level types, each mapping to a hash indexed
on the key name. For the above example, it looks like this:
   * _indices => {
      FILEATTACHMENT => { a => 0, b => 1 },
      FIELD => { c => 0, d => 1 }
   }
It is maintained on the fly by the methods of this module, which makes it
important *not* to write new data directly into the structure, but *always*
to go through the methods exported from here.

As required by the contract with Foswiki::Store, version numbers are required
to be positive, non-zero integers. When passing in version numbers, 0, 
undef and '' are treated as referring to the *latest* (most recent)
revision of the object. Version numbers are required to increase (later
version numbers are greater than earlier) but are *not* required to be
sequential.

This module also includes some methods to support embedding meta-data for
topics directly in topic text, a la the traditional Foswiki store
(getEmbeddedStoreForm and setEmbeddedStoreForm)

*IMPORTANT* the methods on =Foswiki::Meta= _do not check access permissions_
(other than =haveAccess=, obviously).
This is a deliberate design decision, as these checks are expensive and many
callers don't require them. For this reason, be *very careful* how you use
=Foswiki::Meta=. Extension authors will almost always find the methods
they want in =Foswiki::Func=, rather than in this class.

API version $Date: 2010-10-14 19:40:28 +0200 (Thu, 14 Oct 2010) $ (revision $Rev: 9743 (2010-10-25) $)

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (Foswiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

package Foswiki::Meta;

use strict;
use warnings;
use Error qw(:try);
use Assert;
use Errno 'EINTR';

our $reason;
our $VERSION = '$Rev: 9743 (2010-10-25) $';

# Version for the embedding format (increment when embedding format changes)
our $EMBEDDING_FORMAT_VERSION = 1.1;

# defaults for truncation of summary text
our $SUMMARY_TMLTRUNC = 162;
our $SUMMARY_MINTRUNC = 16;
our $SUMMARY_ELLIPSIS = '<b>&hellip;</b>';    # Google style

# the number of characters either side of a search term
our $SUMMARY_DEFAULT_CONTEXT = 30;

# max number of lines in a summary (best to keep it even)
our $CHANGES_SUMMARY_LINECOUNT  = 6;
our $CHANGES_SUMMARY_PLAINTRUNC = 70;

# META:x validation. See Foswiki::Func::registerMETA for more information.
# Note that 'other' is *not* the same as 'allow'; it doesn't imply any
# exclusion of tags that contain unaccepted params. It's really just for
# documentation (and DB schema initialisation).
our %VALIDATE = (
    TOPICINFO => {
        allow => [qw( author version date format reprev rev comment encoding )]
    },
    TOPICMOVED => { require => [qw( from to by date )] },

    # Special case, see Item2554; allow an empty TOPICPARENT, as this was
    # erroneously generated at some point in the past
    TOPICPARENT    => { allow => [qw( name )] },
    FILEATTACHMENT => {
        require => [qw( name )],
        other   => [
            qw( version path size date user
              comment attr )
        ]
    },
    FORM  => { require => [qw( name )] },
    FIELD => {
        require => [qw( name value )],
        other   => [qw( title )]
    },
    PREFERENCE => {
        require => [qw( name value )],
        other   => [qw( type )],
    }
);

=begin TML

---++ StaticMethod registerMETA($name, $check)

See Foswiki::Func::registerMETA for full doc of this function.

=cut

sub registerMETA {
    my ( $name, %check ) = @_;
    $VALIDATE{$name} = \%check;
}

############# GENERIC METHODS #############

=begin TML

---++ ClassMethod new($session, $web, $topic [, $text])
   * =$session= - a Foswiki object (e.g. =$Foswiki::Plugins::SESSION=)
   * =$web=, =$topic= - the pathname of the object. If both are undef,
     this object is a handle for the root container. If $topic is undef,
     it is the handle to a web. Otherwise it's a handle to a topic.
   * $text - optional raw text, which may include embedded meta-data. Will
     be passed to =setEmbeddedStoreForm= to initialise the object. Only valid
     if =$web= and =$topic= are defined.
Construct a new, unloaded object. This method creates lightweight
handles for store objects; the full content of the actual object will
*not* be loaded. If you need to interact with the existing content of
the stored object, use the =load= method to load the content.

---++ ClassMethod new($prototype)

Construct a new, unloaded object, using the session, web and topic in the
prototype object (which must be type Foswiki::Meta).

=cut

sub new {
    my ( $class, $session, $web, $topic, $text ) = @_;

    if ($session->isa('Foswiki::Meta')) {
        # Prototype
        ASSERT(!defined($web) && !defined($topic) && !defined($text))
          if DEBUG;
        return $class->new($session->session, $session->web, $session->topic);
    }

    my $this = bless(
        {
            _session => $session,

            # Index keyed on top level type mapping entry names to their
            # index within the data array.
            _indices => undef,
        },
        ref($class) || $class
    );

    # Normalise web path (replace [./]+ with /)
    if ( defined $web ) {
        ASSERT( UNTAINTED($web), 'web is tainted' ) if DEBUG;
        $web =~ tr#/.#/#s;
    }

    # Note: internal fields are prepended with _. All uppercase
    # fields will be assumed to be meta-data.

    $this->{_web} = $web;

    ASSERT( UNTAINTED($topic), 'topic is tainted' )
      if ( DEBUG && defined $topic );

    $this->{_topic} = $topic;

    #print STDERR "--new Meta($web, ".($topic||'undef').")\n";
    #$this->{_text}  = undef;    # topics only

    # Preferences cache object. We store a pointer, rather than looking
    # up the name each time, because we want to be able to invalidate the
    # loaded preferences if this object is loaded.
    #$this->{_preferences} = undef;

    $this->{FILEATTACHMENT} = [];

    if ( defined $text ) {
        # User supplied topic body forces us to consider this as the
        # latest rev
        ASSERT( defined($web),   'web is not defined' )   if DEBUG;
        ASSERT( defined($topic), 'topic is not defined' ) if DEBUG;
        $this->setEmbeddedStoreForm($text);
        $this->{_latestIsLoaded} = 1;
    }

    return $this;
}

=begin TML

---++ ClassMethod load($session, $web, $topic, $rev)

This constructor will load (or otherwise fetch) the meta-data for a
named web/topic.
   * =$rev= - revision to load. If undef, 0, '' or > max available rev, will
     load the latest rev.

This method is functionally identical to:
<verbatim>
$this = Foswiki::Meta->new( $session, $web, $topic );
$this->loadVersion( $rev );
</verbatim>

WARNING: see notes on revision numbers under =getLoadedRev=

---++ ObjectMethod load($rev) -> $metaObject

Load an unloaded meta-data object with a given version of the data.
Once loaded, the object is locked to that revision.

   * =$rev= - revision to load. If undef, 0, '' or > max available rev, will
     load the latest rev.

WARNING: see notes on revision numbers under =getLoadedRev=

=cut

sub load {
    my $proto = shift;
    my $this;
    my $rev;

    if (ref($proto)) {
        # Existing unloaded object
        ASSERT(!$this->{_loadedRev}) if DEBUG;
        $this = $proto;
        $rev  = shift;
    } else {
        (my $session, my $web, my $topic, $rev ) = @_;
        $this = $proto->new( $session, $web, $topic );
    }
    $this->loadVersion($rev);

    return $this;
}

=begin TML

---++ ObjectMethod unload()

Return the object to an unloaded state. This method should be used
with the greatest of care, as it resets the load state of the object,
which may have surprising effects on other code that shares the object.

=cut

sub unload {
    my $this = shift;
    $this->{_loadedRev} = undef;
    $this->{_latestIsLoaded} = undef;
    $this->{_text} = undef;
    $this->{_preferences}->finish() if defined $this->{_preferences};
    undef $this->{_preferences};
    $this->{_preferences} = undef;
    # Unload meta-data
    foreach my $type (keys %{$this->{_indices}}) {
        delete $this->{$type};
    }
    undef $this->{_indices};
}

=begin TML

---++ ObjectMethod finish()
Clean up the object, releasing any memory stored in it. Make sure this
gets called before an object you have created goes out of scope.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->unload();
    undef $this->{_web};
    undef $this->{_topic};
    undef $this->{_session};
}

=begin TML

---++ ObjectMethod session()

Get the session associated with the object when it was created.

=cut

sub session {
    return $_[0]->{_session};
}

=begin TML

---++ ObjectMethod web([$name])
   * =$name= - optional, change the web name in the object
      * *Since* 28 Nov 2008
Get/set the web name associated with the object.

=cut

sub web {
    my ( $this, $web ) = @_;
    $this->{_web} = $web if defined $web;
    return $this->{_web};
}

=begin TML

---++ ObjectMethod topic([$name])
   * =$name= - optional, change the topic name in the object
      * *Since* 28 Nov 2008
Get/set the topic name associated with the object.

=cut

sub topic {
    my ( $this, $topic ) = @_;
    $this->{_topic} = $topic if defined $topic;
    return $this->{_topic};
}

=begin TML

---++ ObjectMethod getPath() -> $objectpath

Get the canonical content access path for the object

=cut

sub getPath {
    my $this = shift;
    my $path = $this->{_web};

    return '' unless $path;
    return $path unless $this->{_topic};
    $path .= '.' . $this->{_topic};
    return $path;
}

=begin TML

---++ ObjectMethod isSessionTopic() -> $boolean
Return true if this object refers to the session topic

=cut

sub isSessionTopic {
    my $this = shift;
    return 0
      unless defined $this->{_web}
          && defined $this->{_topic}
          && defined $this->{_session}->{webName}
          && defined $this->{_session}->{topicName};
    return $this->{_web} eq $this->{_session}->{webName}
      && $this->{_topic} eq $this->{_session}->{topicName};
}

=begin TML

---++ ObjectMethod getPreference( $key ) -> $value

Get a value for a preference defined in the object. Note that
web preferences always inherit from parent webs, but topic preferences
are strictly local to topics.

=cut

sub getPreference {
    my ( $this, $key ) = @_;

    unless ( $this->{_web} || $this->{_topic} ) {
        return $this->{_session}->{prefs}->getPreference($key);
    }

    # make sure the preferences are parsed and cached
    unless ( $this->{_preferences} ) {
        $this->{_preferences} =
          $this->{_session}->{prefs}->loadPreferences($this);
    }
    return $this->{_preferences}->get($key);
}

=begin TML

---++ ObjectMethod getContainer() -> $containerObject

Get the container of this object; for example, the web that a topic is within

=cut

sub getContainer {
    my $this = shift;

    if ( $this->{_topic} ) {
        return Foswiki::Meta->new( $this->{_session}, $this->{_web} );
    }
    if ( $this->{_web} ) {
        return Foswiki::Meta->new( $this->{_session} );
    }
    ASSERT( 0, 'no container for this object type' ) if DEBUG;
    return;
}

=begin TML

---++ ObjectMethod existsInStore() -> $boolean

A Meta object can be created for a web or topic that doesn't exist in the
actual store (e.g. is in the process of being created). This method returns
true if the corresponding web or topic really exists in the store.

=cut

sub existsInStore {
    my $this = shift;
    if ( defined $this->{_topic} ) {

        # only checking for a topic existence already establishes a dependency
        $this->addDependency();

        return $this->{_session}->{store}
          ->topicExists( $this->{_web}, $this->{_topic} );
    }
    elsif ( defined $this->{_web} ) {
        return $this->{_session}->{store}->webExists( $this->{_web} );
    }
    else {
        return 1;    # the root always exists
    }
}

=begin TML

---++ ObjectMethod stringify( $debug ) -> $string

Return a string version of the meta object. $debug adds
extra debug info.

=cut

sub stringify {
    my ( $this, $debug ) = @_;
    my $s = $this->{_web};
    if ( $this->{_topic} ) {
        $s .= ".$this->{_topic} ";
        $s .=
          ( defined $this->{_loadedRev} )
          ? $this->{_loadedRev}
          : '(not loaded)'
          if $debug;
        $s .= "\n" . $this->getEmbeddedStoreForm();
    }
    return $s;
}

=begin TML

---++ ObjectMethod addDependency() -> $this

This establishes a dependency between $this and the
base topic this session is currently rendering. The dependency
will be asserted during Foswiki::PageCache::cachePage().
See Foswiki::PageCache::addDependency().

=cut

sub addDependency {
    my $cache = $_[0]->{_session}->{cache};
    return unless $cache;
    return $cache->addDependency( $_[0]->{_web}, $_[0]->{_topic} );
}

=begin TML

---++ ObjectMethod fireDependency() -> $this

Invalidates the cache bucket of the current meta object
within the Foswiki::PageCache. See Foswiki::PageCache::fireDependency().

=cut

sub fireDependency {
    my $cache = $_[0]->{_session}->{cache};
    return unless $cache;
    return $cache->fireDependency( $_[0]->{_web}, $_[0]->{_topic} );
}

############# WEB METHODS #############

=begin TML

---++ ObjectMethod populateNewWeb( [$baseWeb [, $opts]] )

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into this web. If it is a normal web, only topics starting
with 'Web' will be copied. If no base web is specified, an empty web
(with no topics) will be created. If it is specified but does not exist,
an error will be thrown.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

#SMELL: there seems to be no reason to call this method 'NewWeb', it can be used to copy into an existing web
and it does not appear to be unexpectedly destructive.
perhaps refactor into something that takes a resultset as an input list? (users have asked to be able to copy a SEARCH'd set of topics..)

=cut

sub populateNewWeb {
    my ( $this, $templateWeb, $opts ) = @_;
    ASSERT( $this->{_web} && !$this->{_topic}, 'this is not a web object' )
      if DEBUG;

    my $session = $this->{_session};

    my ( $parent, $new ) = $this->{_web} =~ m/^(.*)\/([^\.\/]+)$/;

    if ($parent) {
        unless ( $Foswiki::cfg{EnableHierarchicalWebs} ) {
            throw Error::Simple( 'Unable to create '
                  . $this->{_web}
                  . ' - Hierarchical webs are disabled' );
        }

        unless ( $session->webExists($parent) ) {
            throw Error::Simple( 'Parent web ' . $parent . ' does not exist' );
        }
    }

    # Validate that template web exists, or error should be thrown
    if ($templateWeb) {
        unless ( $session->webExists($templateWeb) ) {
            throw Error::Simple(
                'Template web ' . $templateWeb . ' does not exist' );
        }
    }

    # Make sure there is a preferences topic; this is how we know it's a web
    my $prefsTopicObject;
    if (
        !$session->topicExists(
            $this->{_web}, $Foswiki::cfg{WebPrefsTopicName}
        )
      )
    {
        my $prefsText = 'Preferences';
        $prefsTopicObject = $this->new(
            $this->{_session},                $this->{_web},
            $Foswiki::cfg{WebPrefsTopicName}, $prefsText
        );
        $prefsTopicObject->save();
    }

    if ($templateWeb) {
        my $tWebObject = $this->new( $session, $templateWeb );
        require Foswiki::WebFilter;
        my $sys =
          Foswiki::WebFilter->new('template')->ok( $session, $templateWeb );
        my $it = $tWebObject->eachTopic();
        while ( $it->hasNext() ) {
            my $topic = $it->next();
            next unless ( $sys || $topic =~ /^Web/ );
            my $to = Foswiki::Meta->load(
                $this->{_session}, $templateWeb, $topic );
            $to->saveAs( $this->{_web}, $topic, (forcenewrevision => 1) );
        }
    }

    # patch WebPreferences in new web. We ignore permissions, because
    # we are creating a new web here.
    if ($opts) {
        my $prefsTopicObject =
          Foswiki::Meta->load( $this->{_session}, $this->{_web},
            $Foswiki::cfg{WebPrefsTopicName} );
        my $text = $prefsTopicObject->text;
        foreach my $key ( keys %$opts ) {
            #don't create the required params to create web.
            next if ($key eq 'BASEWEB');
            next if ($key eq 'NEWWEB');
            next if ($key eq 'NEWTOPIC');
            next if ($key eq 'ACTION');
            
            if (defined($opts->{$key})) {
                if ($text =~
                  s/($Foswiki::regex{setRegex}$key\s*=).*?$/$1 $opts->{$key}/gm) {
              } else {
                  #this setting wasn't found, so we need to append it.
                  $text .= "\n   * Web Created with KEY set\n";
                  $text .= "\n      * Set $key = $opts->{$key}\n";
              }
            }
        }
        $prefsTopicObject->text($text);
        $prefsTopicObject->save();
    }
}

=begin TML

---++ ObjectMethod searchInText($searchString, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use queries instead).

   * =$searchString= - the search string, in egrep format if regex
   * =\@topics= - reference to a list of names of topics to search, or undef to search all topics in the web
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (default true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub THISISBEINGDELETEDsearchInText {
    my ( $this, $searchString, $topics, $options ) = @_;
    ASSERT( !$this->{_topic} ) if DEBUG;
    unless ($topics) {
        my $it   = $this->eachTopic();
        my @list = $it->all();
        $topics = \@list;
    }
    return $this->{_session}->{store}
      ->searchInWebContent( $searchString, $this->{_web}, $topics,
        $this->{_session}, $options );
}

=begin TML

---++ StaticMethod query($query, $inputTopicSet, \%options) -> $outputTopicSet

Search for topic information
=$query= must be a =Foswiki::*::Node= object. 

   * $inputTopicSet is a reference to an iterator containing a list
     of topic in this web, if set to undef, the search/query algo will
     create a new iterator using eachTopic() 
     and the web, topic and excludetopics options (as per SEARCH)
   * web option - The web/s to search in - string can have the same form
     as the =web= param of SEARCH


Returns an Foswiki::Search::InfoCache iterator

=cut

sub query {
    my ( $query, $inputTopicSet, $options ) = @_;
    return $Foswiki::Plugins::SESSION->{store}
      ->query( $query, $inputTopicSet, $Foswiki::Plugins::SESSION, $options );
}

=begin TML

---++ ObjectMethod eachWeb( $all ) -> $iterator

Return an iterator over each subweb. If =$all= is set, will return a
list of all web names *under* the current location. Returns web pathnames
relative to $this.

Only valid on webs and the root.

=cut

sub eachWeb {
    my ( $this, $all ) = @_;

    # Works on the root, so {_web} may be undef
    ASSERT( !$this->{_topic}, 'this object may not contain webs' ) if DEBUG;
    return $this->{_session}->{store}->eachWeb( $this, $all );

}

=begin TML

---++ ObjectMethod eachTopic() -> $iterator

Return an iterator over each topic name in the web. Only valid on webs.

=cut

sub eachTopic {
    my ($this) = @_;
    ASSERT( $this->{_web} && !$this->{_topic}, 'this is not a web object' )
      if DEBUG;
    if ( !$this->{_web} ) {

        # Root
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( [] );
    }
    return $this->{_session}->{store}->eachTopic($this);
}

=begin TML

---++ ObjectMethod eachAttachment() -> $iterator

Return an iterator over each attachment name in the topic.
Only valid on topics.

The list of the names of attachments stored for the given topic may be a
longer list than the list that comes from the topic meta-data, which may
only lists the attachments that are normally visible to the user.

=cut

sub eachAttachment {
    my ($this) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}->eachAttachment($this);
}

=begin TML

---++ ObjectMethod eachChange( $time ) -> $iterator

Get an iterator over the list of all the changes in the web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now -
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

Only valid for a web.

=cut

sub eachChange {
    my ( $this, $time ) = @_;

    # not valid at root level
    ASSERT( $this->{_web} && !$this->{_topic}, 'this is not a web object' )
      if DEBUG;
    return $this->{_session}->{store}->eachChange( $this, $time );
}

############# TOPIC METHODS #############

=begin TML

---++ ObjectMethod loadVersion($rev) -> $version

Load the object from the store. The object must not be already loaded
with a different rev (verified by an ASSERT)

See =getLoadedRev= to determine what revision is currently being viewed.
   * =$rev= - revision to load. If undef, 0, '' or > max available rev, will
     load the latest rev.

Returns the version identifier for the loaded revision.

WARNING: see notes on revision numbers under =getLoadedRev=

=cut

sub loadVersion {
    my ( $this, $rev ) = @_;
    return unless $this->{_topic};

    # If no specific rev was requested, check that the latest rev is
    # loaded.
    if (!defined $rev || !$rev) {
        # Trying to load the latest
        return if $this->{_latestIsLoaded};
        ASSERT(!defined($this->{_loadedRev})) if DEBUG;
    }
    elsif (defined($this->{_loadedRev})) {
        # Cannot load a different rev into an already-loaded
        # Foswiki::Meta object
        $rev = -1 unless defined $rev;
        ASSERT(0, "Attempt to reload $rev over version $this->{_loadedRev}");
    }

    # Is it already loaded?
    ASSERT( !($rev) or $rev =~ /^\s*\d+\s*/ ) if DEBUG; # looks like a number
    return if ($rev && $this->{_loadedRev} && $rev == $this->{_loadedRev});
    ($this->{_loadedRev}, $this->{_latestIsLoaded})
      = $this->{_session}->{store}->readTopic( $this, $rev );
    # Make sure text always has a value once loadVersion has been called
    # once.
    $this->{_text} = '' unless defined $this->{_text};

    $this->addDependency();
}

=begin TML

---++ ObjectMethod text([$text]) -> $text

Get/set the topic body text. If $text is undef, gets the value, if it is
defined, sets the value to that and returns the new text.

Be warned - it can return undef - when a topic exists but has no topicText.

=cut

sub text {
    my ( $this, $val ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    if ( defined($val) ) {
        $this->{_text} = $val;
    }
    else {

        # Lazy load. Reload with no params will reload the _loadedRev,
        # or load the latest if that is not defined.
        $this->loadVersion() unless defined( $this->{_text} );
    }
    return $this->{_text};
}

=begin TML

---++ ObjectMethod put($type, \%args)

Put a hash of key=value pairs into the given type set in this meta. This
will *not* replace another value with the same name (for that see =putKeyed=)

For example,
<verbatim>
$meta->put( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

sub put {
    my ( $this, $type, $args ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT( defined $type ) if DEBUG;
    ASSERT( defined $args && ref($args) eq 'HASH' ) if DEBUG;

    unless ( $this->{$type} ) {
        $this->{$type} = [];
        $this->{_indices}->{$type} = {};
    }

    my $data = $this->{$type};
    my $i    = 0;
    if ($data) {

        # overwrite old single value
        if ( scalar(@$data) && defined $data->[0]->{name} ) {
            delete $this->{_indices}->{$type}->{ $data->[0]->{name} };
        }
        $data->[0] = $args;
    }
    else {
        $i = push( @$data, $args ) - 1;
    }
    if ( defined $args->{name} ) {
        $this->{_indices}->{$type} ||= {};
        $this->{_indices}->{$type}->{ $args->{name} } = $i;
    }
}

=begin TML

---++ ObjectMethod putKeyed($type, \%args)

Put a hash of key=value pairs into the given type set in this meta, replacing
any existing value with the same key.

For example,
<verbatim>
$meta->putKeyed( 'FIELD',
    { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

# Note: Array is used instead of a hash to preserve sequence

sub putKeyed {
    my ( $this, $type, $args ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT($type) if DEBUG;
    ASSERT( $args && ref($args) eq 'HASH' ) if DEBUG;
    my $keyName = $args->{name};
    ASSERT( $keyName, join( ',', keys %$args ) ) if DEBUG;

    unless ( $this->{$type} ) {
        $this->{$type} = [];
        $this->{_indices}->{$type} = {};
    }

    my $data = $this->{$type};

    # The \% shouldn't be necessary, but it is
    my $indices = \%{ $this->{_indices}->{$type} };
    if ( defined $indices->{$keyName} ) {
        $data->[ $indices->{$keyName} ] = $args;
    }
    else {
        $indices->{$keyName} = push( @$data, $args ) - 1;
    }
}

=begin TML

---++ ObjectMethod putAll

Replaces all the items of a given key with a new array.

For example,
<verbatim>
$meta->putAll( 'FIELD',
     { name => 'MinAge', title => 'Min Age', value =>'50' },
     { name => 'MaxAge', title => 'Max Age', value =>'103' },
     { name => 'HairColour', title => 'Hair Colour', value =>'white' }
 );
</verbatim>

=cut

sub putAll {
    my ( $this, $type, @array ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my %indices;
    for ( my $i = 0 ; $i < scalar(@array) ; $i++ ) {
        if ( defined $array[$i]->{name} ) {
            $indices{ $array[$i]->{name} } = $i;
        }
    }
    $this->{$type} = \@array;
    $this->{_indices}->{$type} = \%indices;
}

=begin TML

---++ ObjectMethod get( $type, $key ) -> \%hash

Find the value of a meta-datum in the map. If the type is
keyed (identified by a =name=), the =$key= parameter is required
to say _which_ entry you want. Otherwise you will just get the first value.

If you want all the keys of a given type use the 'find' method.

The result is a reference to the hash for the item.

For example,
<verbatim>
my $ma = $meta->get( 'FIELD', 'MinAge' );
my $topicinfo = $meta->get( 'TOPICINFO' ); # get the TOPICINFO hash
</verbatim>

=cut

sub get {
    my ( $this, $type, $name ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $data = $this->{$type};
    if ($data) {
        if ( defined $name ) {
            my $indices = $this->{_indices}->{$type};
            return undef unless defined $indices;
            return undef unless defined $indices->{$name};
            return $data->[ $indices->{$name} ];
        }
        else {
            return $data->[0];
        }
    }

    return undef;
}

=begin TML

---++ ObjectMethod find (  $type  ) -> @values

Get all meta data for a specific type.
Returns the array stored for the type. This will be zero length
if there are no entries.

For example,
<verbatim>
my $attachments = $meta->find( 'FILEATTACHMENT' );
</verbatim>

=cut

sub find {
    my ( $this, $type ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $itemsr = $this->{$type};
    my @items  = ();

    if ($itemsr) {
        @items = @$itemsr;
    }

    return @items;
}

=begin TML

---++ ObjectMethod remove($type, $key)

With no type, will remove all the meta-data in the object.

With a $type but no $key, will remove _all_ items of that type
(so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove {
    my ( $this, $type, $name ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    if ($type) {
        my $data = $this->{$type};
        return unless defined $data;
        if ($name) {
            my $indices = $this->{_indices}->{$type};
            if ( defined $indices ) {
                my $i = $indices->{$name};
                return unless defined $i;
                splice( @$data, $i, 1 );
                delete $indices->{$name};
                for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
                    my $item = $data->[$i];
                    next unless exists $item->{name};
                    $indices->{ $item->{name} } = $i;
                }
            }
        }
        else {
            delete $this->{$type};
            delete $this->{_indices}->{$type};
        }
    }
    else {
        foreach my $entry ( keys %$this ) {
            unless ( $entry =~ /^_/ ) {
                delete $this->{$entry};
            }
        }
        $this->{_indices} = {};
    }
}

=begin TML

---++ ObjectMethod copyFrom( $otherMeta [, $type [, $nameFilter]] )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

If $type is undef, will copy ALL TYPES.

If $nameFilter is defined (a perl regular expression), it will copy
only data where ={name}= matches $nameFilter.

Does *not* copy web, topic or text.

=cut

sub copyFrom {
    my ( $this, $other, $type, $filter ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT( $other->isa('Foswiki::Meta') && $other->{_web} && $other->{_topic},
        'other is not a topic object' )
      if DEBUG;

    if ($type) {
        return if $type =~ /^_/;
        my @data;
        foreach my $item ( @{ $other->{$type} } ) {
            if ( !$filter
                || ( $item->{name} && $item->{name} =~ /$filter/ ) )
            {
                my %datum = %$item;
                push( @data, \%datum );
            }
        }
        $this->putAll( $type, @data );
    }
    else {
        foreach my $k ( keys %$other ) {
            unless ( $k =~ /^_/ ) {
                $this->copyFrom( $other, $k );
            }
        }
    }
}

=begin TML

---++ ObjectMethod count($type) -> $integer

Return the number of entries of the given type

=cut

sub count {
    my ( $this, $type ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    my $data = $this->{$type};

    return scalar @$data if ( defined($data) );

    return 0;
}

=begin TML

---++ ObjectMethod setRevisionInfo( %opts )

Set TOPICINFO information on the object, as specified by the parameters.
   * =version= - the revision number
   * =time= - the time stamp
   * =author= - the user id (cUID)
   * + additional data fields to save e.g. reprev, comment

=cut

sub setRevisionInfo {
    my ( $this, %data ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $ti = $this->get('TOPICINFO') || {};

    foreach my $k ( keys %data ) {
        $ti->{$k} = $data{$k};
    }

    # compatibility; older versions of the code use
    # RCS rev numbers. Save with them so old code can
    # read these topics
    $ti->{version} = 1 if $ti->{version} < 1;
    $ti->{version} = $ti->{version};
    $ti->{format}  = $EMBEDDING_FORMAT_VERSION;

    $this->put( 'TOPICINFO', $ti );
}

=begin TML

---++ ObjectMethod getRevisionInfo() -> \%info

Return revision info for the loaded revision in %info with at least:
   * ={date}= in epochSec
   * ={author}= canonical user ID
   * ={version}= the revision number

---++ ObjectMethod getRevisionInfo() -> ( $revDate, $author, $rev, $comment )

Limited backwards compatibility for plugins that assume the 1.0.x interface
The comment is *always* blank

=cut

sub getRevisionInfo {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $info;

    # This used to try and get revision info from the meta
    # information and only kick down to the Store module for the
    # same information if it was not present. However there have
    # been several cases where the meta information in the cache
    # is badly out of step with the store, and the conclusion is
    # that it can't be trusted. For this reason, when meta is read
    # TOPICINFO version field is automatically undefined, which
    # forces this function to re-get it from the store.
    my $topicinfo = $this->get('TOPICINFO');

    if ( $topicinfo && defined $topicinfo->{version} ) {
        $info = {
            date    => $topicinfo->{date},
            author  => $topicinfo->{author},
            version => $topicinfo->{version},
        };
    }
    else {

        # Delegate to the store
        $info = $this->{_session}->{store}->getVersionInfo($this);

        # cache the result
        $this->setRevisionInfo(%$info);
    }
    if (wantarray)
    {
        # Backwards compatibility for 1.0.x plugins
        return ( $info->{date}, $info->{author}, $info->{version}, '' );
    }
    else
    {
        return $info;
    }
}

# Determines, and caches, the topic revision info of the base version,
# SMELL: this is a horrid little legacy of the InfoCache object, and
# should be done away with.
sub getRev1Info {
    my ( $this, $attr ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

#my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $this->{_defaultWeb}, $webtopic );
    my $web   = $this->web;
    my $topic = $this->topic;

    if ( !defined( $this->{getRev1Info} ) ) {
        $this->{getRev1Info} = {};
    }
    my $info = $this->{getRev1Info};
    unless ( defined $info->{$attr} ) {
        my $ri = $info->{rev1info};
        unless ($ri) {
            my $tmp = Foswiki::Meta->load(
                $this->{_session}, $web, $topic, 1 );
            $info->{rev1info} = $ri = $tmp->getRevisionInfo();
        }

        if ( $attr eq 'createusername' ) {
            $info->{createusername} =
              $this->{_session}->{users}->getLoginName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiname' ) {
            $info->{createwikiname} =
              $this->{_session}->{users}->getWikiName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiusername' ) {
            $info->{createwikiusername} =
              $this->{_session}->{users}->webDotWikiName( $ri->{author} );
        }
        elsif ($attr eq 'createdate'
            or $attr eq 'createlongdate'
            or $attr eq 'created' )
        {
            $info->{created} = $ri->{date};
            require Foswiki::Time;
            $info->{createdate} = Foswiki::Time::formatTime( $ri->{date} );

            #TODO: wow thats disgusting.
            $info->{created} = $info->{createlongdate} = $info->{createdate};
        }
    }
    return $info->{$attr};
}

=begin TML

---++ ObjectMethod merge( $otherMeta, $formDef )

   * =$otherMeta= - a block of meta-data to merge with $this
   * =$formDef= reference to a Foswiki::Form that gives the types of the fields in $this

Merge the data in the other meta block.
   * File attachments that only appear in one set are preserved.
   * Form fields that only appear in one set are preserved.
   * Form field values that are different in each set are text-merged
   * We don't merge for field attributes or title
   * Topic info is not touched
   * The =mergeable= method on the form def is used to determine if that field is mergeable. If it isn't, the value currently in meta will _not_ be changed.

=cut

sub merge {
    my ( $this, $other, $formDef ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT( $other->isa('Foswiki::Meta') && $other->{_web} && $other->{_topic},
        'other is not a topic object' )
      if DEBUG;

    my $data = $other->{FIELD};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FIELD', $otherD->{name} );
            if ( $thisD && $thisD->{value} ne $otherD->{value} ) {
                if ( $formDef->isTextMergeable( $thisD->{name} ) ) {
                    require Foswiki::Merge;
                    my $merged = Foswiki::Merge::merge2(
                        'A',
                        $otherD->{value},
                        'B',
                        $thisD->{value},
                        '.*?\s+',
                        $this->{_session},
                        $formDef->getField( $thisD->{name} )
                    );

                    # SMELL: we don't merge attributes or title
                    $thisD->{value} = $merged;
                }
            }
            elsif ( !$thisD ) {
                $this->putKeyed( 'FIELD', $otherD );
            }
        }
    }

    $data = $other->{FILEATTACHMENT};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FILEATTACHMENT', $otherD->{name} );
            if ( !$thisD ) {
                $this->putKeyed( 'FILEATTACHMENT', $otherD );
            }
        }
    }
}

=begin TML

---++ ObjectMethod forEachSelectedValue( $types, $keys, \&fn, \%options )

Iterate over the values selected by the regular expressions in $types and
$keys.
   * =$types= - regular expression matching the names of fields to be processed. Will default to qr/^[A-Z]+$/ if undef.
   * =$keys= - regular expression matching the names of keys to be processed.  Will default to qr/^[a-z]+$/ if undef.

Iterates over each value, calling =\&fn= on each, and replacing the value
with the result of \&fn.

\%options will be passed on to $fn, with the following additions:
   * =_type= => the type name (e.g. "FILEATTACHMENT")
   * =_key= => the key name (e.g. "user")

=cut

sub forEachSelectedValue {
    my ( $this, $types, $keys, $fn, $options ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    $types ||= qr/^[A-Z]+$/;
    $keys  ||= qr/^[a-z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        $options->{_type} = $type;
        my $data = $this->{$type};
        next unless $data;
        foreach my $datum (@$data) {
            foreach my $key ( grep { /$keys/ } keys %$datum ) {
                $options->{_key} = $key;
                $datum->{$key} = &$fn( $datum->{$key}, $options );
            }
        }
    }
}

=begin TML

---++ ObjectMethod getParent() -> $parent

Gets the TOPICPARENT name.

=cut

sub getParent {
    my ($this) = @_;

    my $value  = '';
    my $parent = $this->get('TOPICPARENT');
    $value = $parent->{name} if ($parent);

    # Return empty string (not undef), if TOPICPARENT meta is broken
    $value = '' if ( !defined $value );
    return $value;
}

=begin TML

---++ ObjectMethod getFormName() -> $formname

Returns the name of the FORM, or '' if none.

=cut

sub getFormName {
    my ($this) = @_;

    my $aForm = $this->get('FORM');
    if ($aForm) {
        return $aForm->{name};
    }
    return '';
}

=begin TML

---++ ObjectMethod renderFormForDisplay() -> $html

Render the form contained in the meta for display.

=cut

sub renderFormForDisplay {
    my ($this) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $fname = $this->getFormName();

    require Foswiki::Form;
    require Foswiki::OopsException;
    return '' unless $fname;

    my $form;
    my $result;
    try {
        $form = new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );
        $result = $form->renderForDisplay($this);
    }
    catch Foswiki::OopsException with {

        # Make pseudo-form from field data
        $form =
          new Foswiki::Form( $this->{_session}, $this->{_web}, $fname, $this );
        $result =
          $this->{_session}->inlineAlert( 'alerts', 'formdef_missing', $fname );
        $result .= $form->renderForDisplay($this) if $form;
    };

    return $result;
}

=begin TML

---++ ObjectMethod renderFormFieldForDisplay($name, $format, $attrs) -> $text

Render a single formfield, using the $format. See
Foswiki::Form::FormField::renderForDisplay for a description of how the value
is rendered.

=cut

sub renderFormFieldForDisplay {
    my ( $this, $name, $format, $attrs ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $value;
    my $mf = $this->get( 'FIELD', $name );
    unless ($mf) {

        # Not a valid field name, maybe it's a title.
        require Foswiki::Form;
        $name = Foswiki::Form::fieldTitle2FieldName($name);
        $mf = $this->get( 'FIELD', $name );
    }
    return '' unless $mf;    # field not found

    $value = $mf->{value};

    # remove nop exclamation marks from form field value before it is put
    # inside a format like [[$topic][$formfield()]] that prevents it being
    # detected
    $value =~ s/!(\w+)/<nop>$1/gos;

    my $fname = $this->getFormName();
    if ($fname) {
        require Foswiki::Form;
        my $result;
        try {
            my $form =
              new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );
            my $field = $form->getField($name);
            if ($field) {
                $result = $field->renderForDisplay( $format, $value, $attrs );
            }
        }
        catch Foswiki::OopsException with {

            # Form not found, ignore
        };

        return $result if defined $result;
    }

    # Form or field wasn't found, do your best!
    my $f = $this->get( 'FIELD', $name );
    if ($f) {
        $format =~ s/\$title/$f->{title}/;
        require Foswiki::Render;
        $value = Foswiki::Render::protectFormFieldValue( $value, $attrs );
        $format =~ s/\$value/$value/;
    }
    return $format;
}

# Enable this for debug. Done as a sub to allow perl to optimise it out.
sub MONITOR_ACLS { 0 }

# Get an ACL preference. Returns a reference to a list of cUIDs, or undef.
# If the preference is defined but is empty, then a reference to an
# empty list is returned.
# This function canonicalises the parsing of a users list. Is this the right
# place for it?
sub _getACL {
    my ($this, $mode) = @_;
    my $text = $this->getPreference( $mode );
    return undef unless defined $text;
    # Remove HTML tags (compatibility, inherited from Users.pm
    $text =~ s/(<[^>]*>)//g;
    # Dump the users web specifier if userweb
    my @list = grep { /\S/ } map {
        s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//; $_
    } split(/[,\s]+/, $text);
    return \@list;
}

=begin TML

---++ ObjectMethod haveAccess($mode, $cUID) -> $boolean

   * =$mode=  - 'VIEW', 'CHANGE', 'CREATE', etc. (defaults to VIEW)
   * =$cUID=    - Canonical user id (defaults to current user)
Check if the user has the given mode of access to the topic. This call
may result in the topic being read.

=cut

sub haveAccess {
    my ( $this, $mode, $cUID ) = @_;
    $mode ||= 'VIEW';
    $cUID ||= $this->{_session}->{user};
    if ( defined $this->{_topic} && !defined $this->{_loadedRev} ) {

        # Lazy load the latest version.
        $this->loadVersion();
    }
    my $session = $this->{_session};
    undef $reason;

    print STDERR "Check $mode access $cUID to " . $this->getPath() . "\n"
      if MONITOR_ACLS;

    # super admin is always allowed
    if ( $session->{users}->isAdmin($cUID) ) {
        print STDERR "$cUID - ADMIN\n" if MONITOR_ACLS;
        return 1;
    }

    $mode = uc($mode);

    my ( $allow, $deny );
    if ( $this->{_topic} ) {

        my $allow = $this->_getACL( 'ALLOWTOPIC' . $mode );
        my $deny  = $this->_getACL( 'DENYTOPIC' . $mode );

        # Check DENYTOPIC
        if ( defined($deny) ) {
            if ( scalar(@$deny) != 0 ) {
                if ( $session->{users}->isInUserList( $cUID, $deny ) ) {
                    $reason =
                      $session->i18n->maketext('access denied on topic');
                    print STDERR $reason, "\n" if MONITOR_ACLS;
                    return 0;
                }
            }
            else {

                # If DENYTOPIC is empty, don't deny _anyone_
                print STDERR "DENYTOPIC is empty\n" if MONITOR_ACLS;
                return 1;
            }
        }

        # Check ALLOWTOPIC. If this is defined the user _must_ be in it
        if ( defined($allow) && scalar(@$allow) != 0 ) {
            if ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                print STDERR "in ALLOWTOPIC\n" if MONITOR_ACLS;
                return 1;
            }
            $reason = $session->i18n->maketext('access not allowed on topic');
            print STDERR $reason, "\n" if MONITOR_ACLS;
            return 0;
        }
        $this = $this->getContainer();    # Web
    }

    if ( $this->{_web} ) {

        # Check DENYWEB, but only if DENYTOPIC is not set (even if it
        # is empty - empty means "don't deny anybody")
        unless ( defined($deny) ) {
            $deny = $this->_getACL( 'DENYWEB' . $mode );
            if ( defined($deny)
                && $session->{users}->isInUserList( $cUID, $deny ) )
            {
                $reason = $session->i18n->maketext('access denied on web');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }

        # Check ALLOWWEB. If this is defined and not overridden by
        # ALLOWTOPIC, the user _must_ be in it.
        $allow = $this->_getACL( 'ALLOWWEB' . $mode );

        if ( defined($allow) && scalar(@$allow) != 0 ) {
            unless ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                $reason = $session->i18n->maketext('access not allowed on web');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }

    }
    else {

        # No web, we are checking at the root. Check DENYROOT and ALLOWROOT.
        $deny = $this->_getACL( 'DENYROOT' . $mode );

        if ( defined($deny)
            && $session->{users}->isInUserList( $cUID, $deny ) )
        {
            $reason = $session->i18n->maketext('access denied on root');
            print STDERR $reason, "\n" if MONITOR_ACLS;
            return 0;
        }

        $allow = $this->_getACL( 'ALLOWROOT' . $mode );

        if ( defined($allow) && scalar(@$allow) != 0 ) {
            unless ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                $reason =
                  $session->i18n->maketext('access not allowed on root');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }
    }

    if (MONITOR_ACLS) {
        print STDERR "OK, permitted\n";
        print STDERR 'ALLOW: '.join(',',@$allow)."\n" if defined $allow;
        print STDERR 'DENY: '.join(',',@$deny)."\n"   if defined $deny;
    }
    return 1;
}

=begin TML

---++ ObjectMethod save( %options  )

Save the current object, invoking appropriate plugin handlers
   * =%options= - Hash of options, see saveAs for list of keys

=cut

# SMELL: arguably save should only be permitted if the loaded rev of
# the object is the same as the latest rev.
sub save {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0 ) if DEBUG;
    my %opts = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $plugins = $this->{_session}->{plugins};

    # make sure version and date in TOPICINFO are up-to-date
    # (side effect of getRevisionInfo)
    $this->getRevisionInfo();

    # Semantics inherited from Cairo. See
    # Foswiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('beforeSaveHandler') ) {

        # Break up the tom and write the meta into the topic text.
        # Nasty compatibility requirement as some old plugins may hack the
        # meta instead of using the Meta API
        my $text = $this->getEmbeddedStoreForm();

        my $pretext = $text;               # text before the handler modifies it
        my $premeta = $this->stringify();  # just the meta, no text

        $plugins->dispatch( 'beforeSaveHandler', $text, $this->{_topic},
            $this->{_web}, $this );

        # If the text has changed; it may be a text or meta change, or both
        if ( $text ne $pretext ) {

            # Create a new object to parse the changed text
            my $after =
              new Foswiki::Meta( $this->{_session}, $this->{_web},
                $this->{_topic}, $text );
            unless ( $this->stringify() ne $premeta ) {

                # Meta-data changes in the object take priority over
                # conflicting changes in the text. So if there have been
                # *any* changes in the meta, ignore changes in the text.
                $this->copyFrom($after);
            }
            $this->text( $after->text() );
        }
    }

    my $signal;
    my $newRev;
    try {
        $newRev = $this->saveAs( $this->{_web}, $this->{_topic}, %opts );
    }
    catch Error::Simple with {
        $signal = shift;
    };

    # Semantics inherited from TWiki. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('afterSaveHandler') ) {
        my $text = $this->getEmbeddedStoreForm();
        my $error = $signal ? $signal->{-text} : undef;
        $plugins->dispatch( 'afterSaveHandler', $text, $this->{_topic},
            $this->{_web}, $error, $this );
    }

    throw $signal if $signal;

    my @extras = ();
    push( @extras, 'minor' )   if $opts{minor};      # don't notify
    push( @extras, 'dontlog' ) if $opts{dontlog};    # don't statisticify

    $this->{_session}->logEvent(
        'save',
        $this->{_web} . '.' . $this->{_topic},
        join( ', ', @extras ),
        $this->{_session}->{user}
    );

    return $newRev;
}

=begin TML

---++ ObjectMethod saveAs( $web, $topic, %options  ) -> $rev

Save the current topic to a store location. Only works on topics.
*without* invoking plugins handlers.
   * =$web.$topic= - where to move to
   * =%options= - Hash of options, may include:
      * =forcenewrevision= - force an increment in the revision number,
        even if content doesn't change.
      * =dontlog= - don't include this change in statistics
      * =minor= - don't notify this change
      * =savecmd= - Save command (core use only)
      * =forcedate= - force the revision date to be this (core only)
      * =author= - cUID of author of change (core only - default current user)

Note that the %options are passed on verbatim from Foswiki::Func::saveTopic,
so an extension author can in fact use all these options. However those
marked "core only" are for core use only and should *not* be used in
extensions.

Returns the saved revision number.

=cut

# SMELL: arguably save should only be permitted if the loaded rev
# of the object is the same as the latest rev.
sub saveAs {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    my $newWeb   = shift;
    my $newTopic = shift;
    ASSERT( scalar(@_) % 2 == 0 ) if DEBUG;
    my %opts = @_;
    my $cUID = $opts{author} || $this->{_session}->{user};
    $this->{_web}   = $newWeb   if $newWeb;
    $this->{_topic} = $newTopic if $newTopic;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    unless ( $this->{_topic} eq $Foswiki::cfg{WebPrefsTopicName} ) {
        # Don't verify web existance for WebPreferences, as saving
        # WebPreferences creates the web.
        unless ( $this->{_session}->{store}->webExists( $this->{_web} ) ) {
            throw Error::Simple( 'Unable to save topic '
                  . $this->{_topic}
                  . ' - web '. $this->{_web} . ' does not exist' );
        }
    }
     
    $this->_atomicLock($cUID);
    my $i = $this->{_session}->{store}->getRevisionHistory($this);
    my $currentRev = $i->hasNext() ? $i->next() : 1;
    try {
        if ( $currentRev && !$opts{forcenewrevision} ) {
            # See if we want to replace the existing top revision
            my $mtime1 =
              $this->{_session}->{store}
              ->getApproxRevTime( $this->{_web}, $this->{_topic} );
            my $mtime2 = time();
            my $dt     = abs( $mtime2 - $mtime1 );
            if ( $dt < $Foswiki::cfg{ReplaceIfEditedAgainWithin} ) {
                my $info = $this->{_session}->{store}->getVersionInfo($this);

                # same user?
                if ( $info->{author} eq $cUID ) {

                    # reprev is required so we can tell when a merge is
                    # based on something that is *not* the original rev
                    # where another users' edit started.
                    $info->{reprev} = $info->{version};
                    $info->{date} = $opts{forcedate} || time();
                    $this->setRevisionInfo(%$info);
                    $this->{_session}->{store}->repRev( $this, $cUID, %opts );
                    $this->{_loadedRev} = $currentRev;
                    return $currentRev;
                }
            }
        }
        my $nextRev = $this->{_session}->{store}->getNextRevision($this);
        $this->setRevisionInfo(
            date => $opts{forcedate} || time(),
            author  => $cUID,
            version => $nextRev,
        );

        my $checkSave =
          $this->{_session}->{store}->saveTopic( $this, $cUID, \%opts );
        ASSERT( $checkSave == $nextRev, "$checkSave != $nextRev" ) if DEBUG;
        $this->{_loadedRev} = $nextRev;
    }
    finally {
        $this->_atomicUnlock($cUID);
        $this->fireDependency();
    };
    return $this->{_loadedRev};
}

# An atomic lock will cause other
# processes that also try to claim a lock to block. A lock has a
# maximum lifetime of 2 minutes, so operations on a locked topic
# must be completed within that time. You cannot rely on the
# lock timeout clearing the lock, though; that should always
# be done by calling _atomicUnlock. The best thing to do is to guard
# the locked section with a try..finally clause. See man Error for more info.
#
# Atomic locks are  _not_ the locks used when a topic is edited; those are
# Leases.

sub _atomicLock {
    my ( $this, $cUID ) = @_;
    if ( $this->{_topic} ) {
        my $logger = $this->{_session}->logger();
        while (1) {
            my ( $user, $time ) =
              $this->{_session}->{store}->atomicLockInfo($this);
            last if ( !$user || $cUID eq $user );
            $logger->log( 'warning',
                    'Lock on '
                  . $this->getPath() . ' for '
                  . $cUID
                  . " denied by $user" );

            # see how old the lock is. If it's older than 2 minutes,
            # break it anyway. Locks are atomic, and should never be
            # held that long, by _any_ process.
            if ( time() - $time > 2 * 60 ) {
                $logger->log( 'warning',
                    $cUID . " broke ${user}s lock on " . $this->getPath() );
                $this->{_session}->{store}->atomicUnlock( $this, $cUID );
                last;
            }

            # wait a couple of seconds before trying again
            sleep(2);
        }

        # Topic
        $this->{_session}->{store}->atomicLock( $this, $cUID );
    }
    else {

        # Web: Recursively lock subwebs and topics
        my $it = $this->eachWeb();
        while ( $it->hasNext() ) {
            my $web = $this->{_web} . '/' . $it->next();
            my $meta = $this->new( $this->{_session}, $web );
            $meta->_atomicLock($cUID);
        }
        $it = $this->eachTopic();
        while ( $it->hasNext() ) {
            my $meta =
              $this->new( $this->{_session}, $this->{_web}, $it->next() );
            $meta->_atomicLock($cUID);
        }
    }
}

sub _atomicUnlock {
    my ( $this, $cUID ) = @_;
    if ( $this->{_topic} ) {
        $this->{_session}->{store}->atomicUnlock($this);
    }
    else {
        my $it = $this->eachWeb();
        while ( $it->hasNext() ) {
            my $web = $this->{_web} . '/' . $it->next();
            my $meta = $this->new( $this->{_session}, $web );
            $meta->_atomicUnlock($cUID);
        }
        $it = $this->eachTopic();
        while ( $it->hasNext() ) {
            my $meta =
              $this->new( $this->{_session}, $this->{_web}, $it->next() );
            $meta->_atomicUnlock($cUID);
        }
    }
}

=begin TML

---++ ObjectMethod move($to, %opts)

Move this object (web or topic) to a store location specified by the
object $to. %opts may include:
   * =user= - cUID of the user doing the moving.

=cut

# will assert false if the loaded rev of the object is not
# the latest rev.
sub move {
    my ( $this, $to, %opts ) = @_;
    ASSERT( $this->{_web}, 'this is not a movable object' ) if DEBUG;
    ASSERT( $to->isa('Foswiki::Meta') && $to->{_web},
        'to is not a moving target' )
      if DEBUG;

    my $cUID = $opts{user} || $this->{_session}->{user};

    if ( $this->{_topic} ) {

        # Move topic

        $this->_atomicLock($cUID);
        $to->_atomicLock($cUID);

        # Ensure latest rev is loaded
        my $from;
        if ($this->latestIsLoaded()) {
            $from = $this;
        } else {
            $from = $this->load();
        }

        # Clear outstanding leases. We assume that the caller has checked
        # that the lease is OK to kill.
        $from->clearLease() if $from->getLease();
        try {
            $from->put(
                'TOPICMOVED',
                {
                    from => $from->getPath(),
                    to   => $to->getPath(),
                    date => time(),
                    by   => $cUID,
                }
            );
            $from->save();    # to save the metadata change
            $from->{_session}->{store}->moveTopic( $from, $to, $cUID );
            $to->loadVersion();
        }
        finally {
            $from->_atomicUnlock($cUID);
            $to->_atomicUnlock($cUID);
            $from->fireDependency();
            $to->fireDependency();
        };

    }
    else {

        # Move web
        ASSERT( !$this->{_session}->{store}->webExists( $to->{_web} ),
            "$to->{_web} does not exist" )
          if DEBUG;
        $this->_atomicLock($cUID);
        $this->{_session}->{store}->moveWeb( $this, $to, $cUID );

        # No point in unlocking $this - it's moved!
        $to->_atomicUnlock($cUID);
    }

    # Log rename
    my $old = $this->{_web} . '.' . ( $this->{_topic} || '' );
    my $new = $to->{_web} . '.' .   ( $to->{_topic}   || '' );
    $this->{_session}
      ->logEvent( 'rename', $old, "moved to $new", $this->{_session}->{user} );

    # alert plugins of topic move
    $this->{_session}->{plugins}
      ->dispatch( 'afterRenameHandler', $this->{_web}, $this->{_topic} || '',
        '', $to->{_web}, $to->{_topic} || '', '' );
}

=begin TML

---++ ObjectMethod deleteMostRecentRevision(%opts)
Delete (or elide) the most recent revision of this. Only works on topics.

=%opts= may include
   * =user= - cUID of user doing the unlocking

=cut

sub deleteMostRecentRevision {
    my ( $this, %opts ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    my $rev;
    my $cUID = $opts{user} || $this->{_session}->{user};

    $this->_atomicLock($cUID);
    try {
        $rev = $this->{_session}->{store}->delRev( $this, $cUID );
    }
    finally {
        $this->_atomicUnlock($cUID);
    };

    # TODO: delete entry in .changes

    # write log entry
    $this->{_session}->writeLog(
        'cmd',
        $this->{_web} . '.' . $this->{_topic},
        " delRev $rev by " . $this->{_session}->{user}
    );
}

=begin TML

---++ ObjectMethod replaceMostRecentRevision( %opts )
Replace the most recent revision with whatever is in the memory copy.
Only works on topics.

%opts may include:
   * =forcedate= - try and re-use the date of the original check
   * =user= - cUID of the user doing the action

=cut

sub replaceMostRecentRevision {
    my $this = shift;
    my %opts = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $cUID = $opts{user} || $this->{_session}->{user};

    $this->_atomicLock($cUID);

    my $info = $this->getRevisionInfo();

    if ( $opts{forcedate} ) {

        # We are trying to force the rev to be saved with the same date
        # and user as the prior rev. However, exactly the same date may
        # cause some revision control systems to barf, so to avoid this we
        # add 1 minute to the rev time. Note that this mode of operation
        # will normally require sysadmin privilege, as it can result in
        # confused rev dates if abused.
        $info->{date} += 60;
    }
    else {

        # use defaults (current time, current user)
        $info->{date}   = time();
        $info->{author} = $cUID;
    }

    # repRev is required so we can tell when a merge is based on something
    # that is *not* the original rev where another users' edit started.
    $info->{reprev} = $info->{version};
    $this->setRevisionInfo(%$info);

    try {
        $this->{_session}->{store}->repRev( $this, $cUID, @_ );
    }
    finally {
        $this->_atomicUnlock($cUID);
    };

    # write log entry
    require Foswiki::Time;
    my @extras = ( $info->{version} );
    push( @extras,
        Foswiki::Time::formatTime( $info->{date}, '$rcs', 'gmtime' ) );
    push( @extras, 'minor' )   if $opts{minor};
    push( @extras, 'dontlog' ) if $opts{dontlog};
    push( @extras, 'forced' )  if $opts{forcedate};
    $this->{_session}
      ->logEvent( 'reprev', $this->getPath(), join( ', ', @extras ), $cUID );
}

=begin TML

---++ ObjectMethod getRevisionHistory([$attachment]) -> $iterator

Get an iterator over the range of version identifiers (just the identifiers,
not the content).

$attachment is optional.

Not valid on webs. Returns a null iterator if no revisions exist.

=cut

sub getRevisionHistory {
    my ( $this, $attachment ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}->getRevisionHistory( $this, $attachment );
}

=begin TML

---++ ObjectMethod getLatestRev[$attachment]) -> $revision

Get the revision ID of the latest revision.

$attachment is optional.

Not valid on webs.

=cut

sub getLatestRev {
    my $this = shift;
    my $it   = $this->getRevisionHistory(@_);
    return 0 unless $it->hasNext();
    return $it->next();
}

=begin TML

---++ ObjectMethod latestIsLoaded() -> $boolean
Return true if the currently loaded rev is the latest rev. Note that there may have
been changes to the meta or text locally in the loaded meta; these changes will be
retained.

Only valid on topics.

=cut

sub latestIsLoaded {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_latestIsLoaded} if defined $this->{_latestIsLoaded};
    return defined $this->{_loadedRev}
      && $this->{_loadedRev} == $this->getLatestRev();
}

=begin TML

---++ ObjectMethod getLoadedRev() -> $integer

Get the currently loaded revision. Result will be a revision number, or
undef if no revision has been loaded. Only valid on topics.

WARNING: some store implementations use the concept of a "working copy" of
each topic that may be modified *without* being added to the revision
control system. This means that the version number reported for the latest
rev may not be the actual latest version.

=cut

sub getLoadedRev {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_loadedRev};
}

=begin TML

---++ ObjectMethod removeFromStore( $attachment )
   * =$attachment= - optional, provide to delete an attachment

Use with great care! Removes all trace of the given web, topic
or attachment from the store, possibly including all its history.

=cut

sub removeFromStore {
    my ( $this, $attachment ) = @_;
    my $store = $this->{_session}->{store};
    ASSERT( $this->{_web}, 'this is not a removable object' ) if DEBUG;

    if ( !$store->webExists( $this->{_web} ) ) {
        throw Error::Simple( 'No such web ' . $this->{_web} );
    }
    if ( $this->{_topic}
        && !$store->topicExists( $this->{_web}, $this->{_topic} ) )
    {
        throw Error::Simple(
            'No such topic ' . $this->{_web} . '.' . $this->{_topic} );
    }

    if ( $attachment && !$this->hasAttachment($attachment) ) {
        ASSERT( $this->{topic}, 'this is not a removable object' ) if DEBUG;
        throw Error::Simple( 'No such attachment '
              . $this->{_web} . '.'
              . $this->{_topic} . '.'
              . $attachment );
    }

    $store->remove( $this->{_session}->{user}, $this );
}

=begin TML

---++ ObjectMethod getDifferences( $rev2, $contextLines ) -> \@diffArray

Get the differences between the rev loaded into this object, and another
rev of the same topic. Return reference to an array of differences.
   * =$rev2= - the other revision to diff against
   * =$contextLines= - number of lines of context required

Each difference is of the form [ $type, $right, $left ] where
| *type* | *Means* |
| =+= | Added |
| =-= | Deleted |
| =c= | Changed |
| =u= | Unchanged |
| =l= | Line Number |

=cut

sub getDifferences {
    my ( $this, $rev2, $contextLines ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}
      ->getRevisionDiff( $this, $rev2, $contextLines );
}

=begin TML

---++ ObjectMethod getRevisionAtTime( $time ) -> $rev
   * =$time= - time (in epoch secs) for the rev

Get the revision number for a topic at a specific time.
Returns a single-digit rev number or 0 if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $time ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}->getRevisionAtTime( $this, $time );
}

=begin TML

---++ ObjectMethod setLease( $length )

Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my ( $this, $length ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    my $t     = time();
    my $lease = {
        user    => $this->{_session}->{user},
        expires => $t + $length,
        taken   => $t
    };
    return $this->{_session}->{store}->setLease( $this, $lease );
}

=begin TML

---++ ObjectMethod getLease() -> $lease

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}->getLease($this);
}

=begin TML

---++ ObjectMethod clearLease()

Cancel the current lease.

See =getLease= for more details about Leases.

=cut

sub clearLease {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 
        ($this->{_web}||'undef').'.'.($this->{_topic}||'undef').' this is not a topic object' )
      if DEBUG;
    $this->{_session}->{store}->setLease($this);
}

=begin TML

---++ ObjectMethod onTick($time)

Method invoked at regular intervals, usually by a cron job. The job of
this method is to prod the store into cleaning up expired leases, and
any other admin job that needs doing at regular intervals.

=cut

sub onTick {
    my ( $this, $time ) = @_;

    if ( !$this->{_topic} ) {
        my $it = $this->eachWeb();
        while ( $it->hasNext() ) {
            my $web = $it->next();
            $web = $this->getPath() . "/$web" if $this->getPath();
            my $m = $this->new( $this->{_session}, $web );
            $m->onTick($time);
        }
        if ( $this->{_web} ) {
            $it = $this->eachTopic();
            while ( $it->hasNext() ) {
                my $topic = $it->next();
                my $topicObject =
                  $this->new( $this->{_session}, $this->getPath(), $topic );
                $topicObject->onTick($time);
            }
        }

        # Clean up spurious leases that may have been left behind
        # during cancelled topic creation
        $this->{_session}->{store}->removeSpuriousLeases( $this->getPath() ) if $this->getPath();
    }
    else {
        my $lease = $this->getLease();
        if ( $lease && $lease->{expires} < $time ) {
            $this->clearLease();
        }
    }
}

############# ATTACHMENTS ON TOPICS #############

=begin TML

---++ ObjectMethod getAttachmentRevisionInfo($attachment, $rev) -> \%info
   * =$attachment= - attachment name
   * =$rev= - optional integer attachment revision number
Get revision info for an attachment. Only valid on topics.

$info will contain at least: date, author, version, comment

=cut

sub getAttachmentRevisionInfo {
    my ( $this, $attachment, $fromrev ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    return $this->{_session}->{store}
      ->getAttachmentVersionInfo( $this, $fromrev, $attachment );
}

=begin TML

---++ ObjectMethod attach ( %opts )

   * =%opts= may include:
      * =name= - Name of the attachment
      * =dontlog= - don't add to statistics
      * =comment= - comment for save
      * =hide= - if the attachment is to be hidden in normal topic view
      * =stream= - Stream of file to upload. Uses =file= if not set.
      * =file= - Name of a *server* file to use for the attachment
        data. This should be passed if it is known, as it may be used
        to optimise handler calls.
      * =filepath= - Optional. Client path to file.
      * =filesize= - Optional. Size of uploaded data.
      * =filedate= - Optional. Date of file.
      * =author= - Optional. cUID of author of change. Defaults to current.
      * =notopicchange= - Optional. if the topic is *not* to be modified.
        This may result in incorrect meta-data stored in the topic, so must
        be used with care. Only has a meaning if the store implementation 
        stores meta-data in topics.

Saves a new revision of the attachment, invoking plugin handlers as
appropriate. This method automatically updates the loaded rev of $this
to the latest topic revision.

If neither of =stream= or =file= are set, this is a properties-only save.

Throws an exception on error.

=cut

# SMELL: arguably should only be permitted if the loaded rev of the object is the same as the
# latest rev.

sub attach {
    my $this = shift;
    my %opts = @_;
    my $action;
    my $plugins = $this->{_session}->{plugins};
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    if ( $opts{file} && !$opts{stream} ) {
        # no stream given, but a file was given; open it.
        open( $opts{stream}, '<', $opts{file} )
          || throw Error::Simple( 'Could not open ' . $opts{file} );
        binmode( $opts{stream} )
          || throw Error::Simple( $opts{file} . ' binmode failed: ' . $! );
    }

    my $attrs;
    if ( $opts{stream} ) {
        $action = 'upload';

        $attrs = {
            name        => $opts{name},
            attachment  => $opts{name},
            stream      => $opts{stream},
            user        => $this->{_session}->{user},    # cUID
            comment     => $opts{comment} || '',
        };

        if ($plugins->haveHandlerFor('beforeAttachmentSaveHandler')) {

            # *Deprecated* handler.

            # The handler may have been called as a result of an upload,
            # in which case the data is already in a file in the CGI cache,
            # and the stream is valid, or it may be been arrived at via a
            # call to Func::saveAttachment, in which case it's possible that
            # the stream isn't open but we have a tmpFilename instead.
            # 
            $attrs->{tmpFilename} = $opts{file};

            if ( !defined( $attrs->{tmpFilename} )) {

                # CGI (or the caller) did not provide a temporary file

                # Stream the data to a temporary file, so it can be passed
                # to the handler.

                require File::Temp;

                my $fh = new File::Temp();
                binmode( $fh );
                # transfer 512KB blocks
                my $transfer;
                my $r;
                while( $r = sysread( $opts{stream}, $transfer, 0x80000 )) {
                    if( !defined $r ) {
                        next if( $! == Errno::EINTR );
                        die "system read error: $!\n";
                    }
                    my $offset = 0;
                    while( $r ) {
                        my $w = syswrite( $fh, $transfer, $r, $offset );
                        die "system write error: $!\n" unless( defined $w );
                        $offset += $w;
                        $r -= $w;
                    }
                }
                select((select($fh), $| = 1)[0]);
                # $fh->seek only in File::Temp 0.17 and later
                seek($fh, 0, 0 ) or die "Can't seek temp: $!\n";
                $opts{stream} = $fh;
                $attrs->{tmpFilename} = $fh->filename();
            }

            if ( $plugins->haveHandlerFor('beforeAttachmentSaveHandler') ) {
                $plugins->dispatch( 'beforeAttachmentSaveHandler', $attrs,
                    $this->{_topic}, $this->{_web} );
            }

            # Have to assume it's changed, even if it hasn't.
            open( $attrs->{stream}, '<', $attrs->{tmpFilename} )
              || die "Internal error: $!";
            binmode( $attrs->{stream} );
            $opts{stream} = $attrs->{stream};

            delete $attrs->{tmpFilename};
        }

        if ( $plugins->haveHandlerFor('beforeUploadHandler') ) {
            # Check the stream is seekable
            ASSERT(seek($attrs->{stream}, 0, 1),
                   'Stream for attachment is not seekable') if DEBUG;

            $plugins->dispatch( 'beforeUploadHandler', $attrs, $this );
            $opts{stream} = $attrs->{stream};
            seek($opts{stream}, 0, 0); # seek to beginning
            binmode( $opts{stream} );
        }

        # Force reload of the latest version
        $this = $this->load() unless $this->latestIsLoaded();

        my $error;
        try {
            $this->{_session}->{store}
              ->saveAttachment( $this, $opts{name}, $opts{stream},
                $opts{author} || $this->{_session}->{user} );
        }
        finally {
            $this->fireDependency();
        };

        my $fileVersion = $this->getLatestRev( $opts{name} );
        $attrs->{version} = $fileVersion;
        $attrs->{path}    = $opts{filepath} if ( defined( $opts{filepath} ) );
        $attrs->{size}    = $opts{filesize} if ( defined( $opts{filesize} ) );
        $attrs->{date}    = defined $opts{filedate} ? $opts{filedate} : time();

        if ( $plugins->haveHandlerFor('afterAttachmentSaveHandler') ) {
            # *Deprecated* handler
            $plugins->dispatch( 'afterAttachmentSaveHandler', $attrs,
                $this->{_topic}, $this->{_web} );
        }
    }
    else {

        # Property change
        $action        = 'save';
        $attrs         = $this->get( 'FILEATTACHMENT', $opts{name} );
        $attrs->{name} = $opts{name};
        $attrs->{comment} = $opts{comment} if ( defined( $opts{comment} ) );
    }
    $attrs->{attr} = ( $opts{hide} ) ? 'h' : '';
    delete $attrs->{stream};
    delete $attrs->{tmpFilename};
    $this->putKeyed( 'FILEATTACHMENT', $attrs );

    if ( $opts{createlink} ) {
        my $text = $this->text();
        $text = '' unless defined $text;
        $text .=
          $this->{_session}->attach->getAttachmentLink( $this, $opts{name} );
        $this->text($text);
    }

    $this->saveAs() unless $opts{notopicchange};

    my @extras = ( $opts{name} );
    push( @extras, 'dontlog' ) if $opts{dontlog};    # no statistics
    $this->{_session}->logEvent(
        $action,
        $this->{_web} . '.' . $this->{_topic},
        join( ', ', @extras ),
        $this->{_session}->{user}
    );

    if ( $plugins->haveHandlerFor('afterUploadHandler') ) {
        $plugins->dispatch( 'afterUploadHandler', $attrs, $this );
    }
}

=begin TML

---++ ObjectMethod hasAttachment( $name ) -> $boolean
Test if the named attachment exists. Only valid on topics. The attachment
must exist in the store (it is not sufficient for it to be referenced
in the object only)

=cut

sub hasAttachment {
    my ( $this, $name ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->{store}->attachmentExists( $this, $name );
}

=begin TML

---++ ObjectMethod testAttachment( $name, $test ) -> $value

Performs a type test on the given attachment file.
    * =$name= - name of the attachment to test e.g =lolcat.gif=
    * =$test= - the test to perform e.g. ='r'=

The return value is the value that would be returned by the standard
perl file operations, as indicated by $type

    * r File is readable by current user (tests Foswiki VIEW permission)
    * w File is writable by current user (tests Foswiki CHANGE permission)
    * e File exists.
    * z File has zero size.
    * s File has nonzero size (returns size).
    * T File is an ASCII text file (heuristic guess).
    * B File is a "binary" file (opposite of T).
    * M Last modification time (epoch seconds).
    * A Last access time (epoch seconds).

Note that all these types should behave as the equivalent standard perl
operator behaves, except M and A which are independent of the script start
time (see perldoc -f -X for more information)

Other standard Perl file tests may also be supported on some store
implementations, but cannot be relied on.

Errors will be signalled by an Error::Simple exception.

=cut

sub testAttachment {
    my ( $this, $attachment, $test ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    $this->addDependency();

    $test =~ /(\w)/;
    $test = $1;
    if ( $test eq 'r' ) {
        return $this->haveAccess('VIEW');
    }
    elsif ( $test eq 'w' ) {
        return $this->haveAccess('CHANGE');
    }

    return
      return $this->{_session}->{store}
      ->testAttachment( $this, $attachment, $test );
}

=begin TML

---+++ openAttachment($attachment, $mode, %opts) -> $fh
   * =$attachment= - the attachment
   * =$mode= - mode to open the attachment in
Opens a stream onto the attachment. This method is primarily to
support virtual file systems, and as such access controls are *not*
checked, plugin handlers are *not* called, and it does *not* update the
meta-data in the topicObject.

=$mode= can be '&lt;', '&gt;' or '&gt;&gt;' for read, write, and append
respectively.

=%opts= can take different settings depending on =$mode=.
   * =$mode='&lt;'=
      * =version= - revision of the object to open e.g. =version => 6=
   * =$mode='&gt;'= or ='&gt;&gt;'
      * no options
Errors will be signalled by an =Error= exception.

See also =attach= if this function is too basic for you.

=cut

sub openAttachment {
    my ( $this, $attachment, $mode, @opts ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    return $this->{_session}->{store}
      ->openAttachment( $this, $attachment, $mode, @opts );

}

=begin TML

---++ ObjectMethod moveAttachment( $name, $to, %opts ) -> $data
Move the named attachment to the topic indicates by $to.
=%opts= may include:
   * =new_name= - new name for the attachment
   * =user= - cUID of user doing the moving

=cut

sub moveAttachment {
    my $this = shift;
    my $name = shift;
    my $to   = shift;
    my %opts = @_;
    my $cUID = $opts{user} || $this->{_session}->{user};
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT( $to->{_web} && $to->{_topic}, 'to is not a topic object' ) if DEBUG;

    my $newName = $opts{new_name} || $name;

    # Make sure we have latest revs
    $this = $this->load() unless $this->latestIsLoaded();

    $this->_atomicLock($cUID);
    $to->_atomicLock($cUID);

    try {
        $this->{_session}->{store}
          ->moveAttachment( $this, $name, $to, $newName, $cUID );

        # Modify the cache of the old topic
        my $fileAttachment = $this->get( 'FILEATTACHMENT', $name );
        $this->remove( 'FILEATTACHMENT', $name );
        $this->saveAs(
            undef, undef,
            dontlog => 1,                # no statistics
            comment => 'lost ' . $name
        );

        # Add file attachment to new topic
        $fileAttachment->{name}     = $newName;
        $fileAttachment->{movefrom} = $this->getPath() . '.' . $name;
        $fileAttachment->{moveby} =
          $this->{_session}->{users}->getLoginName($cUID);
        $fileAttachment->{movedto}   = $to->getPath() . '.' . $newName;
        $fileAttachment->{movedwhen} = time();
        $to->loadVersion();
        $to->putKeyed( 'FILEATTACHMENT', $fileAttachment );

        if ( $this->getPath() eq $to->getPath() ) {
            $to->remove( 'FILEATTACHMENT', $name );
        }

        $to->saveAs(
            undef, undef,
            dontlog => 1,                    # no statistics
            comment => 'gained' . $newName
        );
    }
    finally {
        $to->_atomicUnlock($cUID);
        $this->_atomicUnlock($cUID);
        $this->fireDependency();
        $to->fireDependency();
    };

    # alert plugins of attachment move
    $this->{_session}->{plugins}
      ->dispatch( 'afterRenameHandler', $this->{_web}, $this->{_topic}, $name,
        $to->{_web}, $to->{_topic}, $newName );

    $this->{_session}->logEvent(
        'move',
        $this->getPath() . '.' 
          . $name
          . ' moved to '
          . $to->getPath() . '.'
          . $newName,
        $cUID
    );
}

=begin TML

---++ ObjectMethod copyAttachment( $name, $to, %opts ) -> $data
Copy the named attachment to the topic indicates by $to.
=%opts= may include:
   * =new_name= - new name for the attachment
   * =user= - cUID of user doing the moving

=cut

sub copyAttachment {
    my $this = shift;
    my $name = shift;
    my $to   = shift;
    my %opts = @_;
    my $cUID = $opts{user} || $this->{_session}->{user};
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    ASSERT( $to->{_web} && $to->{_topic}, 'to is not a topic object' ) if DEBUG;

    my $newName = $opts{new_name} || $name;

    # Make sure we have latest revs
    my $from;
    if ( $this->latestIsLoaded() ) {
        $from = $this;
    } else {
        $from = $this->load();
    }

    $from->_atomicLock($cUID);
    $to->_atomicLock($cUID);

    try {
        $from->{_session}->{store}
          ->copyAttachment( $from, $name, $to, $newName, $cUID );

        # Add file attachment to new topic by copying the old one
        my $fileAttachment = { %{$from->get( 'FILEATTACHMENT', $name )} };
        $fileAttachment->{name} = $newName;

        $to->loadVersion() unless $to->latestIsLoaded();
        $to->putKeyed( 'FILEATTACHMENT', $fileAttachment );

        if ( $from->getPath() eq $to->getPath() ) {
            $to->remove( 'FILEATTACHMENT', $name );
        }

        $to->saveAs(
            undef, undef,
            dontlog => 1,                    # no statistics
            comment => 'gained' . $newName
        );
    }
    finally {
        $to->_atomicUnlock($cUID);
        $from->_atomicUnlock($cUID);
        $from->fireDependency();
        $to->fireDependency();
    };

    # alert plugins of attachment move
# SMELL: no defined handler for attachment copies
#    $this->{_session}->{plugins}
#      ->dispatch( 'afterCopyHandler', $this->{_web}, $this->{_topic}, $name,
#        $to->{_web}, $to->{_topic}, $newName );

    $this->{_session}->logEvent(
        'copy',
        $this->getPath() . '.' 
          . $name
          . ' copied to '
          . $to->getPath() . '.'
          . $newName,
        $cUID
    );
}

=begin TML

---++ ObjectMethod expandNewTopic()
Expand only that subset of Foswiki variables that are
expanded during topic creation, in the body text and
PREFERENCE meta only.

The expansion is in-place in the object data.

Only valid on topics.

=cut

sub expandNewTopic {
    my ($this) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    $this->{_session}->expandMacrosOnTopicCreation($this);
}

=begin TML

---++ ObjectMethod expandMacros( $text ) -> $text
Expand only all Foswiki variables that are
expanded during topic view. Returns the expanded text.
Only valid on topics.

=cut

sub expandMacros {
    my ( $this, $text ) = @_;
    ASSERT( defined( $this->web ) && defined( $this->topic ),
        'this is not a topic object' )
      if DEBUG;

    return $this->{_session}->expandMacros( $text, $this );
}

=begin TML

---++ ObjectMethod renderTML( $text ) -> $text
Render all TML constructs in the text into HTML. Returns the rendered text.
Only valid on topics.

=cut

sub renderTML {
    my ( $this, $text ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    return $this->{_session}->renderer->getRenderedVersion( $text, $this );
}

=begin TML

---++ ObjectMethod summariseText( $flags [, $text, \%searchOptions] ) -> $tml

Makes a plain text summary of the topic text by simply trimming a bit
off the top. Truncates to $TMTRUNC chars or, if a number is specified
in $flags, to that length.

If $text is defined, use it in place of the topic text.

The =\%searchOptions= hash may contain the following options:
   * =type= - search type: keyword, literal, query
   * =casesensitive= - false to ignore case (default true)
   * =wordboundaries= - if type is 'keyword'
   * =tokens= - array ref of search tokens
   
TODO: should this really be in Meta? it seems like a rendering issue to me.

   
=cut

sub summariseText {
    my ( $this, $flags, $text, $searchOptions ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    $flags ||= '';

    $text = $this->text() unless defined $text;
    $text = ''            unless defined $text;

    my $plainText =
      $this->session->renderer->TML2PlainText( $text, $this, $flags );
    $plainText =~ s/\n+/ /g;

    # limit to n chars
    my $limit = $flags || '';
    unless ( $limit =~ s/^.*?([0-9]+).*$/$1/ ) {
        $limit = $SUMMARY_TMLTRUNC;
    }
    $limit = $SUMMARY_MINTRUNC if ( $limit < $SUMMARY_MINTRUNC );

    if ( $flags =~ m/searchcontext/ ) {
        return $this->_summariseTextWithSearchContext( $plainText, $limit,
            $searchOptions );
    }
    else {
        return $this->_summariseTextSimple( $plainText, $limit );
    }
}

=begin TML

---++ ObjectMethod _summariseTextSimple( $text, $limit ) -> $tml

Makes a plain text summary of the topic text by simply trimming a bit
off the top. Truncates to $TMTRUNC chars or, if a number is specified
in $flags, to that length.

TODO: should this really be in Meta? it seems like a rendering issue to me.

=cut

sub _summariseTextSimple {
    my ( $this, $text, $limit ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    # SMELL: need to avoid splitting within multi-byte characters
    # by encoding bytes as Perl UTF-8 characters.
    # This avoids splitting within a Unicode codepoint (or a UTF-16
    # surrogate pair, which is encoded as a single Perl UTF-8 character),
    # but we ideally need to avoid splitting closely related Unicode
    # codepoints.
    # Specifically, this means Unicode combining character sequences (e.g.
    # letters and accents)
    # Might be better to split on \b if possible.

    $text =~
      s/^(.{$limit}.*?)($Foswiki::regex{mixedAlphaNumRegex}).*$/$1$2 \.\.\./s;

    return $this->_makeSummaryTextSafe($text);
}

sub _makeSummaryTextSafe {
    my ( $this, $text ) = @_;

    my $session  = $this->session();
    my $renderer = $session->renderer();

    # We do not want the summary to contain any $variable that formatted
    # searches can interpret to anything (Item3489).
    # Especially new lines (Item2496)
    # To not waste performance we simply replace $ by $<nop>
    $text =~ s/\$/\$<nop>/g;

    # Escape Interwiki links and other side effects introduced by
    # plugins later in the rendering pipeline (Item4748)
    $text =~ s/\:/<nop>\:/g;
    $text =~ s/\s+/ /g;

    return $this->session->renderer->protectPlainText($text);
}

=begin TML

---++ ObjectMethod _summariseTextWithSearchContext( $text, $limit, $type, $searchOptions ) -> $tml

Improves the presentation of summaries for keyword, word and literal searches, by displaying topic content on either side of the search terms wherever they are found in the topic.

The =\%searchOptions= hash may contain the following options:
   * =type= - search type: keyword, literal, query
   * =casesensitive= - false to ignore case (default true)
   * =wordboundaries= - if type is 'keyword'
   * =tokens= - array ref of search tokens
   
=cut

sub _summariseTextWithSearchContext {
    my ( $this, $text, $limit, $searchOptions ) = @_;

    if ( !$searchOptions->{tokens} ) {
        return $this->_summariseTextSimple( $text, $limit );
    }

    my $type = $searchOptions->{type} || '';
    if ( $type ne 'keyword' && $type ne 'literal' && $type ne '' ) {
        return $this->_summariseTextSimple( $text, $limit );
    }

    my $caseSensitive  = $searchOptions->{casesensitive}  || '';
    my $wordBoundaries = $searchOptions->{wordboundaries} || '';

    my @tokens = grep { !/^!.*$/ } @{ $searchOptions->{tokens} };
    my $keystrs = join( '|', @tokens );

    if ( !$keystrs ) {
        return $this->_summariseTextSimple( $text, $limit );
    }

    # we don't have a means currently to set the word window through a parameter
    # so we always use the default
    my $context = $SUMMARY_DEFAULT_CONTEXT;

# break on words with search type 'word' (which is passed as type 'keyword' with $wordBoundaries as true
    my $wordBoundaryAnchor =
      ( $type eq 'keyword' && $wordBoundaries ) ? '\b' : '';
    $keystrs = $caseSensitive ? "($keystrs)" : "((?i:$keystrs))";
    my $termsPattern = $wordBoundaryAnchor . $keystrs . $wordBoundaryAnchor;

# if $wordBoundaries is false, only break on whole words at start and end, not surrounding the search term; therefore the pattern at start differs from the pattern at the end
    my $beforePattern = "(\\b.{0,$context}$wordBoundaryAnchor)";
    my $afterPattern  = "($wordBoundaryAnchor.{0,$context}\\b)";
    my $searchPattern = $beforePattern . $termsPattern . $afterPattern;

    my $summary       = '';
    my $summaryLength = 0;
    while ( $summaryLength < $limit && $text =~ m/$searchPattern/gs ) {
        my $before = $1 || '';
        my $term   = $2 || '';
        my $after  = $3 || '';

        $before = $this->_makeSummaryTextSafe($before);
        $term   = $this->_makeSummaryTextSafe($term);
        $after  = $this->_makeSummaryTextSafe($after);

        $summaryLength += length "$before$term$after";

        my $startLoc = $-[0];

        # only show ellipsis when not at the start
        # and when we don't have any summary text yet
        if ( !$summary && $startLoc != 0 ) {
            $before = "$SUMMARY_ELLIPSIS $before";
        }

        my $endLoc = $+[0] || $-[0];
        $after = "$after $SUMMARY_ELLIPSIS" if $endLoc != length $text;

        $summary .= $before . CGI::em( {}, $term ) . $after . ' ';
    }

    return $this->_summariseTextSimple( $text, $limit ) if !$summary;

    return $summary;
}

=begin TML

---++ ObjectMethod summariseChanges( $orev, $nrev, $tml) -> $text

Generate a (max 3 line) summary of the differences between the revs.

   * =$orev= - older rev, if not defined will use ($nrev - 1)
   * =$nrev= - later rev, if not defined defaults to latest
   * =$tml= - if true will generate renderable TML (i.e. HTML with NOPs.
     If false will generate a summary suitable for use in plain text
    (mail, for example)

If there is only one rev, a topic summary will be returned.

If =$tml= is not set, all HTML will be removed.

In non-tml, lines are truncated to 70 characters. Differences are shown using + and - to indicate added and removed text.

=cut

sub summariseChanges {
    my ( $this, $orev, $nrev, $tml ) = @_;
    my $summary  = '';
    my $session  = $this->session();
    my $renderer = $session->renderer();

    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    $nrev = $this->getLatestRev() unless $nrev;

    ASSERT( $nrev =~ /^\s*\d+\s*/ ) if DEBUG; # looks like a number

    $orev = $nrev - 1 unless defined($orev);

    ASSERT( $orev =~ /^\s*\d+\s*/ ) if DEBUG; # looks like a number
    ASSERT( $orev >= 0 ) if DEBUG;
    ASSERT( $nrev >= $orev ) if DEBUG;

    unless (defined $this->{_loadedRev} && $this->{_loadedRev} eq $nrev) {
        $this = $this->load($nrev);
    }

    my $ntext = '';
    if ( $this->haveAccess('VIEW') ) {

        # Only get the text if we have access to nrev
        $ntext = $this->text();
    }

    return '' if ( $orev == $nrev );    # same rev, no differences

    my $metaPick = qr/^[A-Z](?!OPICINFO)/;    # all except TOPICINFO

    $ntext =
        $renderer->TML2PlainText( $ntext, $this, 'nonop' ) . "\n"
      . $this->stringify($metaPick);

    my $oldTopicObject = $this->new( $session, $this->web, $this->topic );
    unless ( $oldTopicObject->haveAccess('VIEW') ) {

        # No access to old rev, make a blank topic object
        $oldTopicObject = $this->new( $session, $this->web, $this->topic, '' );
    }
    my $otext =
      $renderer->TML2PlainText( $oldTopicObject->text(), $oldTopicObject,
        'nonop' )
      . "\n"
      . $oldTopicObject->stringify($metaPick);

    require Foswiki::Merge;
    my $blocks = Foswiki::Merge::simpleMerge( $otext, $ntext, qr/[\r\n]+/ );

    # sort through, keeping one line of context either side of a change
    my @revised;
    my $getnext  = 0;
    my $prev     = '';
    my $ellipsis = $tml ? $SUMMARY_ELLIPSIS : '...';
    my $trunc    = $tml ? $SUMMARY_TMLTRUNC : $CHANGES_SUMMARY_PLAINTRUNC;
    while ( scalar @$blocks && scalar(@revised) < $CHANGES_SUMMARY_LINECOUNT ) {
        my $block = shift(@$blocks);
        next unless $block =~ /\S/;
        my $trim = length($block) > $trunc;
        $block =~ s/^(.{$trunc}).*$/$1/ if ($trim);
        if ( $block =~ m/^[-+]/ ) {
            if ($tml) {
                $block =~ s/^-(.*)$/CGI::del( {}, $1 )/se;
                $block =~ s/^\+(.*)$/CGI::ins( {}, $1 )/se;
            }
            elsif ( $session->inContext('rss') ) {
                $block =~ s/^-/REMOVED: /;
                $block =~ s/^\+/INSERTED: /;
            }
            push( @revised, $prev ) if $prev;
            $block .= $ellipsis if $trim;
            push( @revised, $block );
            $getnext = 1;
            $prev    = '';
        }
        else {
            if ($getnext) {
                $block .= $ellipsis if $trim;
                push( @revised, $block );
                $getnext = 0;
                $prev    = '';
            }
            else {
                $prev = $block;
            }
        }
    }
    if ($tml) {
        $summary = join( CGI::br(), @revised );
    }
    else {
        $summary = join( "\n", @revised );
    }

    unless ($summary) {
        $summary = $this->summariseText( '', $ntext );
    }

    if ( !$tml ) {
        $summary = $renderer->protectPlainText($summary);
    }
    return $summary;
}

=begin TML

---++ ObjectMethod getEmbeddedStoreForm() -> $text

Generate the embedded store form of the topic. The embedded store
form has meta-data values embedded using %META: lines. The text
stored in the meta is taken as the topic text.

TODO: Soooo.... if we wanted to make a meta->setPreference('VARIABLE', 'Values...'); we would have to change this to
   1 see if that preference is set in the {_text} using the    * Set syntax, in which case, replace that
   2 or let the META::PREF.. work as it does now..
   
yay :/

=cut

sub getEmbeddedStoreForm {
    my $this = shift;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    $this->{_text} ||= '';

    require Foswiki::Store;    # for encoding

    my $ti = $this->get('TOPICINFO');
    delete $ti->{rev} if $ti; # don't want this written

    my $text = $this->_writeTypes( 'TOPICINFO', 'TOPICPARENT' );
    $text .= $this->{_text};
    my $end =
      $this->_writeTypes( 'FORM', 'FIELD', 'FILEATTACHMENT', 'TOPICMOVED' )
      . $this->_writeTypes(
        'not',   'TOPICINFO',      'TOPICPARENT', 'FORM',
        'FIELD', 'FILEATTACHMENT', 'TOPICMOVED'
      );
    $text .= "\n" if $end;

    $ti->{rev} = $ti->{version} if $ti;

    return $text . $end;
}

# PRIVATE STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
sub _writeKeyValue {
    my ( $key, $value ) = @_;

    if ( defined($value) ) {
        $value = dataEncode($value);
    }
    else {
        $value = '';
    }

    return $key . '="' . $value . '"';
}

# PRIVATE STATIC: Write all the key=value pairs for the types listed
sub _writeTypes {
    my ( $this, @types ) = @_;

    my $text = '';

    if ( $types[0] eq 'not' ) {

        # write all types that are not in the list
        my %seen;
        @seen{@types} = ();
        @types = ();    # empty "not in list"
        foreach my $key ( keys %$this ) {
            push( @types, $key )
              unless ( exists $seen{$key} || $key =~ /^_/ );
        }
    }

    foreach my $type (@types) {
        next if $type eq '_session';
        my $data = $this->{$type};
        foreach my $item (@$data) {
            my $sep = '';
            $text .= '%META:' . $type . '{';
            my $name = $item->{name};
            if ($name) {

                # If there's a name field, put first to make regexp
                # based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {
                if ( $key ne 'name' ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = ' ';
                }
            }
            $text .= '}%' . "\n";
        }
    }

    return $text;
}

=begin TML

---++ ObjectMethod setEmbeddedStoreForm( $text )

Populate this object with embedded meta-data from $text. This method
is a utility provided for use with stores that store data embedded in
topic text. Only valid on topics.

Note: line endings must be normalised to \n *before* calling this method.

=cut

sub setEmbeddedStoreForm {
    my ( $this, $text ) = @_;
    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;

    my $format = $EMBEDDING_FORMAT_VERSION;

    # head meta-data
    $text =~ s/^(%META:(TOPICINFO){(.*)}%\n)/
      $this->_readMETA($1, $2, $3)/gem;
    my $ti = $this->get('TOPICINFO');
    if ($ti) {
        $format = $ti->{format} || 0;

        # Make sure we update the topic format for when we save
        $ti->{format} = $EMBEDDING_FORMAT_VERSION;

        # Clean up SVN and other malformed rev nums. This can happen
        # when old code (e.g. old plugins) generated the meta.
        $ti->{version} = Foswiki::Store::cleanUpRevID( $ti->{version} );
        $ti->{rev} = $ti->{version}; # not used, maintained for compatibility
        $ti->{reprev} = Foswiki::Store::cleanUpRevID( $ti->{reprev} )
          if defined $ti->{reprev};
    }

    # Other meta-data
    my $endMeta = 0;
    if ( $format !~ /^[\d.]+$/ || $format < 1.1 ) {
        require Foswiki::Compatibility;
        if (
            $text =~ s/^%META:([^{]+){(.*)}%\n/
              Foswiki::Compatibility::readSymmetricallyEncodedMETA(
                  $this, $1, $2 ); ''/gem
          )
        {
            $endMeta = 1;
        }
    }
    else {
        if (
            $text =~ s/^(%META:([^{]+){(.*)}%\n)/
              $this->_readMETA($1, $2, $3)/gem
          )
        {
            $endMeta = 1;
        }
    }

    # eat the extra newline put in to separate text from tail meta-data
    $text =~ s/\n$//s if $endMeta;

    # If there is no meta data then convert from old format
    if ( !$this->count('TOPICINFO') ) {

        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ /<!--TWikiAttachment-->/ ) {
            require Foswiki::Compatibility;
            $text = Foswiki::Compatibility::migrateToFileAttachmentMacro(
                $this->{_session}, $this, $text );
        }

        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ /<!--TWikiCat-->/ ) {
            require Foswiki::Compatibility;
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{_session},
                $this->{_web}, $this->{_topic}, $this, $text );
        }
    }
    elsif ( $format eq '1.0beta' ) {
        require Foswiki::Compatibility;

        # This format used live at DrKW for a few months
        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ /<!--TWikiCat-->/ ) {
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{_session},
                $this->{_web}, $this->{_topic}, $this, $text );
        }
        Foswiki::Compatibility::upgradeFrom1v0beta( $this->{_session}, $this );
        if ( $this->count('TOPICMOVED') ) {
            my $moved = $this->get('TOPICMOVED');
            $this->put( 'TOPICMOVED', $moved );
        }
    }

    if ( $format !~ /^[\d.]+$/ || $format < 1.1 ) {

        # compatibility; topics version 1.0 and earlier equivalenced tab
        # with three spaces. Respect that.
        $text =~ s/\t/   /g;
    }

    $this->{_text} = $text;
}

=begin TML

---++ ObjectMethod isValidEmbedding($macro, \%args) -> $boolean

Test that the arguments defined in =\%args= are sufficient to satisfy the
requirements of the embeddable meta-data given by =$macro=. For example,
=isValidEmbedding('FILEATTACHMENT', $args)= will only succeed if $args contains
at least =name=, =date=, =user= and =attr= fields. Note that extra fields are
simply ignored (unless they are explicitly excluded).

If the macro is not registered for validation, then it will be ignored.

If the embedding is not valid, then $Foswiki::Meta::reason is set with a
message explaining why.

=cut

sub isValidEmbedding {
    my ( $this, $macro, $args ) = @_;

    my $validate = $VALIDATE{$macro};
    return 1 unless $validate;    # not validated

    if ( defined $validate->{function} ) {
        unless ( &{ $validate->{function} }( $macro, $args ) ) {
            $reason = "\%META:$macro validation failed";
            return 0;
        }

        # Fall through to check other constraints
    }

    my %allowed;
    if ( defined $validate->{require} ) {
        map { $allowed{$_} = 1 } @{ $validate->{require} };
        foreach my $p ( @{ $validate->{require} } ) {
            if ( !defined $args->{$p} ) {
                $reason = "$p was missing from \%META:$macro";
                return 0;
            }
        }
    }

    if ( defined $validate->{allow} ) {
        map { $allowed{$_} = 1 } @{ $validate->{allow} };
        foreach my $arg ( keys %$args ) {
            if ( !$allowed{$arg} ) {
                $reason = "$arg was present in \%META:$macro";
                return 0;
            }
        }
    }

    return 1;
}

sub _readMETA {
    my ( $this, $expr, $type, $args ) = @_;
    my $keys = _readKeyValues($args);
    if ( $this->isValidEmbedding( $type, $keys ) ) {
        if ( defined( $keys->{name} ) ) {

            # save it keyed if it has a name
            $this->putKeyed( $type, $keys );
        }
        else {
            $this->put( $type, $keys );
        }
        return '';
    }
    else {
        return $expr;
    }
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of Foswiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my ($args) = @_;
    my %res;

    # Format of data is name='value' name1='value1' [...]
    $args =~ s/\s*([^=]+)="([^"]*)"/
      $res{$1} = dataDecode( $2 ), ''/ge;

    return \%res;
}

=begin TML

---++ StaticMethod dataEncode( $uncoded ) -> $coded

Encode meta-data field values, escaping out selected characters.
The encoding is chosen to avoid problems with parsing the attribute
values in embedded meta-data, while minimising the number of
characters encoded so searches can still work (fairly) sensibly.

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

=begin TML

---++ StaticMethod dataDecode( $encoded ) -> $decoded

Decode escapes in a string that was encoded using dataEncode

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
