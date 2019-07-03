export PERL5LIB:=lib

PERL            = perl-latest
PROVE           = prove-latest
PODS            = $(shell cat chapter_order.txt)
MARKDOWNS       = $(shell bin/markdown_chapters chapter_order.txt)
MODULES         = $(shell find lib -name '*.pm')
MARKDOWN_DIR    = markdown
DONE            = `$(PERL) $(BIN)/list_done_chapters`
BIN             = bin
DETAB           = $(BIN)/detab
POD2MD          = $(BIN)/pod2md
POD2TOC         = $(BIN)/pod2toc
POD_DIR         = .
PANDOC          = pandoc
KINDLEGEN       = kindlegen
EBOOKCONVERT    = /Applications/calibre.app/Contents/MacOS/ebook-convert
BOOK_FILENAME   = mojo_web_useragents
EPUB_ASSET_DIR  = epub_assets
COVER_IMAGE     = $(EPUB_ASSET_DIR)/cover.png


.PHONY: all
all: refs.txt epub kindle pdf   ## Create the EPUB, Mobi, and PDF versions
	@ echo "Placeholder Makefile for now"

######################################################################
# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## show a list of targets
	@ grep -E '^[a-zA-Z][/a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: detab
detab:                  ## remove tabs from pod files
	@ $(DETAB) $(PODS)

.PHONY: podtest
podtest: detab          ## check the pod validity (but there's `make test` too)
	 $(PERL) $(BIN)/pseudopodchecker $(PODS)

.PHONY: lint
lint: detab refs.txt    ## run the linter program to check for problems in the text
	@  $(PERL) linters/run_all

refs.txt: $(PODS) $(BIN)/get_labels
	@  $(PERL) $(BIN)/get_labels > refs.txt

.PHONY: toc
toc:                    ## Extract the table of contents from pods
	@ $(PERL) -CSD $(BIN)/pod2toc -0 -1 -2 -3 $(PODS)

.PHONY: status
status:                 ## Show the status for each pod file
	@ grep "=for status" pod/*.pod

.PHONY: test
test:                   ## run all the tests (mostly for code items)
	@ cat t/test_manifest | xargs $(PROVE) -Ilib

# https://blog.dave.org.uk/2015/08/writing-books-the-easy-bit.html
# https://github.com/jgm/pandoc
.PHONY: epub
epub: $(BOOK_FILENAME).epub  refs.txt ## create the EPUB
	@ echo "Creating EPUB"

$(BOOK_FILENAME).epub: $(PODS) $(EPUB_ASSETS) $(MODULES) $(POD2MD)
	rm -rf $(MARKDOWN_DIR)
	$(PERL) $(POD2MD) $(PODS)
	$(PANDOC) -o $(BOOK_FILENAME).epub $(EPUB_ASSET_DIR)/title.txt $(MARKDOWNS) \
		--epub-metadata=$(EPUB_ASSET_DIR)/metadata.xml --toc --toc-depth=2      \
		--css=$(EPUB_ASSET_DIR)/epub.css --epub-cover-image=$(COVER_IMAGE)

# https://www.amazon.com/gp/feature.html?docId=1000765211
.PHONY: kindle
kindle: $(BOOK_FILENAME).mobi  ## create the Kindle Mobi version (also makes EPUB)
	@ echo "Converting EPUB to Kindle"

$(BOOK_FILENAME).mobi: $(BOOK_FILENAME).epub
	$(KINDLEGEN) $(BOOK_FILENAME).epub

# from Calibre
.PHONY: pdf  ## create the PDF version
pdf: $(BOOK_FILENAME).pdf $(BOOK_FILENAME).epub
	@ echo "Creating PDF"

$(BOOK_FILENAME).pdf: $(BOOK_FILENAME).epub
	$(EBOOKCONVERT) $(BOOK_FILENAME).epub $(BOOK_FILENAME).pdf

.PHONY: clean
clean:  ## remove the markdown and ebooks
	rm  -f $(BOOK_FILENAME)*.{epub,md,pdf,mobi}
	rm -rf $(MARKDOWN_DIR)/*
	rm -rf EPUB META-INF mimetype
