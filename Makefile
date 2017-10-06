all: index.html

.PHONY: force
force: ./index.src.html
	bikeshed -f spec $^

index.html: ./index.src.html
	bikeshed -f spec $^

publish:
	git push origin master master:gh-pages

