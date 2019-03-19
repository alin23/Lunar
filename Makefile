define n


endef

FRAMEWORK_FILES := $(wildcard Carthage/Build/Mac/*.framework)
PREBUILT_FRAMEWORK_FILES := $(wildcard Frameworks/*.framework)
ARCHIVED_FRAMEWORK_FILES=$(patsubst Carthage/Build/Mac/%.framework,PreBuiltFrameworks/%.framework.zip,$(FRAMEWORK_FILES))

$(ARCHIVED_FRAMEWORK_FILES): PreBuiltFrameworks/%.framework.zip: Carthage/Build/Mac/%.framework
	carthage archive $* --output PreBuiltFrameworks/

$(PREBUILT_FRAMEWORK_FILES): Frameworks/%.framework: PreBuiltFrameworks/%.framework.zip
	bsdtar --strip-components=3 -xvf $< -C Frameworks

carthage-archive: $(ARCHIVED_FRAMEWORK_FILES)
carthage-extract: $(PREBUILT_FRAMEWORK_FILES)

carthage-update:
	carthage update --cache-builds --platform macOS

carthage: carthage-update carthage-archive
carthage-dev: carthage-extract

.git/hooks/pre-commit: pre-commit.sh
	@ln -fs "${PWD}/pre-commit.sh" "${PWD}/.git/hooks/pre-commit"; \
	chmod +x "${PWD}/.git/hooks/pre-commit"
install-hooks: .git/hooks/pre-commit

/usr/local/bin/%:
ifeq (, $(shell which brew))
	$(error No brew in PATH, aborting...:$n)
else
	brew install $*
endif

install-swiftformat: /usr/local/bin/swiftformat
install-sourcery: /usr/local/bin/sourcery
install-git-secret: /usr/local/bin/git-secret
install-git-lfs: /usr/local/bin/git-lfs

install-deps: install-swiftformat install-sourcery install-git-secret install-git-lfs

dev: install-deps install-hooks carthage-dev
