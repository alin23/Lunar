define n


endef

RELEASE_NOTES_FILES := $(wildcard ReleaseNotes/*.md)
TEMPLATE_FILES := $(wildcard Lunar/Templates/*.stencil)
GENERATED_FILES=$(patsubst Lunar/Templates/%.stencil,Lunar/Generated/%.generated.swift,$(TEMPLATE_FILES))

FRAMEWORK_FILES := $(wildcard Carthage/Build/Mac/*.framework)
ARCHIVED_FRAMEWORK_FILES=$(patsubst Carthage/Build/Mac/%.framework,PreBuiltFrameworks/%.framework.zip,$(FRAMEWORK_FILES))
PREBUILT_FRAMEWORK_FILES=$(patsubst Carthage/Build/Mac/%.framework,Frameworks/%.framework,$(FRAMEWORK_FILES))

$(ARCHIVED_FRAMEWORK_FILES): PreBuiltFrameworks/%.framework.zip: Carthage/Build/Mac/%.framework
	carthage archive $* --output PreBuiltFrameworks/
	git lfs track $@

$(PREBUILT_FRAMEWORK_FILES): Frameworks/%.framework: PreBuiltFrameworks/%.framework.zip
	cd /tmp && \
	unzip -o ${PWD}/PreBuiltFrameworks/$*.framework.zip && \
	rm -rf ${PWD}/Frameworks/$*.framework* && \
	mv /tmp/Carthage/Build/Mac/$*.framework* ${PWD}/Frameworks/

$(GENERATED_FILES): Lunar/Generated/%.generated.swift: Lunar/Templates/%.stencil
	source ${PWD}/.env.sh && sourcery

carthage-archive: $(ARCHIVED_FRAMEWORK_FILES)
carthage-extract: $(PREBUILT_FRAMEWORK_FILES)
carthage-clean:
	rm -rf Frameworks/*.framework*

carthage-update:
	carthage update --cache-builds --platform macOS

carthage-track:
	git lfs track PreBuiltFrameworks/*.zip
	git add .gitattributes
	git commit -m "Track prebuilt frameworks"
	git add PreBuiltFrameworks/*.zip
	git commit -m "Add prebuilt frameworks"

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

codegen: $(GENERATED_FILES)

CHANGELOG.md: $(RELEASE_NOTES_FILES)
	tail -n +1 `ls -r ReleaseNotes/*.md` | sed -E 's/==> ReleaseNotes\/(.+)\.md <==/# \1/g' > CHANGELOG.md

changelog: CHANGELOG.md
dev: install-deps install-hooks carthage-dev codegen

.PHONY: release
release: changelog
	hub release create v$(VERSION) -a Releases/Lunar-$(VERSION).dmg#Lunar.dmg -m "$(VERSION)\$n\$n$$(cat ReleaseNotes/$(VERSION).md)"

print-%  : ; @echo $* = $($*)