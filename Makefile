.PHONY: tag

tag:
ifndef TYPE
	$(error Usage: make tag TYPE=minor or make tag TYPE=major)
endif
	@latest=$$(git tag --sort=-v:refname | head -1); \
	if [ -z "$$latest" ]; then \
		major=0; minor=0; \
	else \
		major=$$(echo "$$latest" | sed 's/^v//' | cut -d. -f1); \
		minor=$$(echo "$$latest" | sed 's/^v//' | cut -d. -f2); \
	fi; \
	if [ "$(TYPE)" = "major" ]; then \
		major=$$((major + 1)); minor=0; \
	elif [ "$(TYPE)" = "minor" ]; then \
		minor=$$((minor + 1)); \
	else \
		echo "Error: TYPE must be 'major' or 'minor'"; exit 1; \
	fi; \
	tag="v$$major.$$minor"; \
	echo "Tagging $$tag"; \
	git tag "$$tag" && git push origin "$$tag"
