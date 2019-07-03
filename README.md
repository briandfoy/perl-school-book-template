# Your Book Title

A not-so-short book on writing web user-agents in Mojolicious
for [Perl School](https://perlschool.com)

## Setting up the publishing system

This uses the Perl School system that Dave Cross details in his
[ebookbook](https://github.com/davorg/ebookbook) repo.

Basically, install:

* [pandoc](https://pandoc.org) (for epub)

* [kindlegen](https://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000765211) (for mobi)

* [calibre](https://calibre-ebook.com) (for PDFs)

Look at the [Makefile](https://github.com/briandfoy/mojo-useragent-book/blob/master/Makefile)
to see what you can do. The `help` target shows you the commands.

	% make help

Some of the _Makefile_ is specific to my setup only because I've been
to lazy to generalize it.
