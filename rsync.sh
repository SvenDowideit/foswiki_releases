#!/bin/sh

rsync -r -e ssh svenud,foswiki@frs.sourceforge.net:/home/frs/project/f/fo/foswiki .
git commit foswiki -m "update via rsync"
