define n


endef

RELEASE_NOTES_FILES := $(wildcard ReleaseNotes/*.md)
TEMPLATE_FILES := $(wildcard Lunar/Templates/*.stencil)
GENERATED_FILES=$(patsubst Lunar/Templates/%.stencil,Lunar/Generated/%.generated.swift,$(TEMPLATE_FILES))

PATCH_FILES := $(wildcard Patches/*.patch)
FRAMEWORK_PATCH_DIRS=$(patsubst Patches/%.patch,Carthage/Checkouts/%,$(PATCH_FILES))

FRAMEWORK_FILES := $(wildcard Carthage/Build/Mac/*.framework)
ARCHIVED_FRAMEWORK_FILES=$(patsubst Carthage/Build/Mac/%.framework,PreBuiltFrameworks/%.framework.zip,$(FRAMEWORK_FILES))
PREBUILT_FRAMEWORK_FILES=$(patsubst Carthage/Build/Mac/%.framework,Frameworks/%.framework,$(FRAMEWORK_FILES))

$(ARCHIVED_FRAMEWORK_FILES): PreBuiltFrameworks/%.framework.zip: Carthage/Build/Mac/%.framework
	carthage archive $* --output PreBuiltFrameworks/
	git lfs track $@

$(FRAMEWORK_PATCH_DIRS): Carthage/Checkouts/%: Patches/%.patch
	patch -f -d Carthage/Checkouts/$* -p1 < Patches/$*.patch || true

$(PREBUILT_FRAMEWORK_FILES): Frameworks/%.framework: PreBuiltFrameworks/%.framework.zip
	cd /tmp && \
	unzip -o ${PWD}/PreBuiltFrameworks/$*.framework.zip && \
	rm -rf ${PWD}/Frameworks/$*.framework* && \
	mv /tmp/Carthage/Build/Mac/$*.framework* ${PWD}/Frameworks/

$(GENERATED_FILES): Lunar/Generated/%.generated.swift: Lunar/Templates/%.stencil
	source ${PWD}/.env.sh && sourcery

carthage-archive: $(ARCHIVED_FRAMEWORK_FILES)
carthage-extract: $(PREBUILT_FRAMEWORK_FILES)
carthage-patch: $(FRAMEWORK_PATCH_DIRS)
carthage-clean:
	rm -rf Frameworks/*.framework*

carthage-update:
	carthage update --cache-builds --platform macOS

carthage-build:
	carthage build --cache-builds --platform macOS


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
	echo "$(VERSION)" > /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	cat ReleaseNotes/$(VERSION).md >> /tmp/release_file_$(VERSION).md
	hub release create v$(VERSION) -a "Releases/Lunar-$(VERSION).dmg#Lunar.dmg" -F /tmp/release_file_$(VERSION).md

print-%  : ; @echo $* = $($*)