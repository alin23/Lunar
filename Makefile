define n


endef

.EXPORT_ALL_VARIABLES:

DISABLE_NOTARIZATION := ${DISABLE_NOTARIZATION}
DISABLE_PACKING := ${DISABLE_PACKING}
ENV=Release
CHANNEL=
V=
DSA=0

ifeq (beta, $(CHANNEL))
FULL_VERSION:=$(VERSION)b$V
else
FULL_VERSION:=$(VERSION)
endif

RELEASE_NOTES_FILES := $(wildcard ReleaseNotes/*.md)
TEMPLATE_FILES := $(wildcard Lunar/Templates/*.stencil)
GENERATED_FILES=$(patsubst Lunar/Templates/%.stencil,Lunar/Generated/%.generated.swift,$(TEMPLATE_FILES))

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

install-deps: install-swiftformat install-sourcery install-git-secret

codegen: $(GENERATED_FILES)

CHANGELOG.md: $(RELEASE_NOTES_FILES)
	tail -n +1 $$(ls -r ReleaseNotes/*.md | egrep -v '\d[ab]\d') | sed -E 's/==> ReleaseNotes\/(.+)\.md <==/# \1/g' > CHANGELOG.md

changelog: CHANGELOG.md
dev: install-deps install-hooks codegen

.PHONY: release upload build sentry pkg dmg pack appcast
upload: ReleaseNotes/release.css
	rsync -avz Releases/*.delta darkwoods:/static/Lunar/deltas/ || true
	rsync -avzP Releases/*.dmg darkwoods:/static/Lunar/releases/
	rsync -avz Releases/*.html ReleaseNotes/*.css darkwoods:/static/Lunar/ReleaseNotes/
	rsync -avzP Releases/appcast*.xml darkwoods:/static/Lunar/
	cfcli -d lunar.fyi purge

release: changelog
	echo "$(VERSION)" > /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	cat ReleaseNotes/$(VERSION).md >> /tmp/release_file_$(VERSION).md
	gh release create v$(VERSION) -F /tmp/release_file_$(VERSION).md "Releases/Lunar-$(VERSION).dmg#Lunar.dmg"

sentry: export DWARF_DSYM_FOLDER_PATH="$(shell xcodebuild -scheme $(ENV) -configuration $(ENV) -showBuildSettings -json 2>/dev/null | jq -r .[0].buildSettings.DWARF_DSYM_FOLDER_PATH)"
sentry:
	./bin/sentry.sh

print-%  : ; @echo $* = $($*)

dmg: SHELL=/usr/local/bin/fish
dmg:
	env CODESIGNING_FOLDER_PATH=(xcdir -s '$(ENV)' -c $(ENV))/Lunar.app ./bin/make-installer dmg

pack: SHELL=/usr/local/bin/fish
pack: export SPARKLE_BIN_DIR="$$PWD/Frameworks/Sparkle/bin/"
pack:
	env CODESIGNING_FOLDER_PATH=(xcdir -s '$(ENV)' -c $(ENV))/Lunar.app PROJECT_DIR=$$PWD ./bin/pack

appcast: export SPARKLE_BIN_DIR="$$PWD/Frameworks/Sparkle/bin/"
appcast: VERSION=$(shell xcodebuild -scheme $(ENV) -configuration $(ENV) -workspace Lunar.xcworkspace -showBuildSettings -json 2>/dev/null | jq -r .[0].buildSettings.MARKETING_VERSION)
appcast: Releases/Lunar-$(FULL_VERSION).html
	rm Releases/Lunar.dmg || true
ifneq (, $(CHANNEL))
	rm Releases/Lunar$(FULL_VERSION)*.delta || true
	"$(SPARKLE_BIN_DIR)/generate_appcast" --maximum-versions 10 --maximum-deltas 2 --major-version "6.0.0" --link "https://lunar.fyi/" --full-release-notes-url "https://lunar.fyi/changelog" --channel "$(CHANNEL)" --release-notes-url-prefix https://files.lunar.fyi/ReleaseNotes/ --download-url-prefix https://files.lunar.fyi/releases/ -o Releases/appcast2.xml Releases
else
	rm Releases/Lunar-*{a,b}*.dmg || true
	rm Releases/Lunar*{a,b}*.delta || true
	"$(SPARKLE_BIN_DIR)/generate_appcast" --maximum-versions 10 --major-version "6.0.0" --link "https://lunar.fyi/" --full-release-notes-url "https://lunar.fyi/changelog" --release-notes-url-prefix https://files.lunar.fyi/ReleaseNotes/ --download-url-prefix https://files.lunar.fyi/releases/ -o Releases/appcast2.xml Releases
	"$(SPARKLE_BIN_DIR)/generate_appcast" --maximum-versions 10 --major-version "6.0.0" --link "https://lunar.fyi/" --full-release-notes-url "https://lunar.fyi/changelog" --release-notes-url-prefix https://files.lunar.fyi/ReleaseNotes/ --download-url-prefix https://files.lunar.fyi/releases/ -o Releases/appcast-stable.xml Releases
	cp Releases/Lunar-$(FULL_VERSION).dmg Releases/Lunar.dmg
	sd 'https://files.lunar.fyi/releases/([^"]+).delta' 'https://files.lunar.fyi/deltas/$$1.delta' Releases/appcast-stable.xml
endif
	sd 'https://files.lunar.fyi/releases/([^"]+).delta' 'https://files.lunar.fyi/deltas/$$1.delta' Releases/appcast2.xml


setversion: OLD_VERSION=$(shell xcodebuild -scheme $(ENV) -configuration $(ENV) -workspace Lunar.xcworkspace -showBuildSettings -json 2>/dev/null | jq -r .[0].buildSettings.MARKETING_VERSION)
setversion:
ifneq (, $(FULL_VERSION))
	rg -l 'VERSION = "?$(OLD_VERSION)"?' && sed -E -i .bkp 's/VERSION = "?$(OLD_VERSION)"?/VERSION = $(FULL_VERSION)/g' $$(rg -l 'VERSION = "?$(OLD_VERSION)"?')
endif

clean:
	xcodebuild -scheme $(ENV) -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO clean

build: BEAUTIFY=0
build: ONLY_ACTIVE_ARCH=NO
build: setversion
ifneq ($(BEAUTIFY),0)
	xcodebuild -scheme $(ENV) -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=$(ONLY_ACTIVE_ARCH) | xcbeautify
else
	xcodebuild -scheme $(ENV) -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=$(ONLY_ACTIVE_ARCH)
endif
ifneq ($(DISABLE_PACKING),1)
	make pack VERSION=$(VERSION) CHANNEL=$(CHANNEL) V=$V
endif
ifneq ($(DISABLE_SENTRY),1)
	make sentry VERSION=$(VERSION) CHANNEL=$(CHANNEL) V=$V
endif

css: ReleaseNotes/release.css
ReleaseNotes/release.css: ReleaseNotes/release.styl
	stylus --compress $<

Releases/Lunar-%.html: ReleaseNotes/$(VERSION)*.md
	@echo Compiling $^ to $@
ifneq (, $(CHANNEL))
	pandoc -f gfm -o $@ --standalone --metadata title="Lunar $(FULL_VERSION) - Release Notes" --css https://files.lunar.fyi/ReleaseNotes/release.css $(shell ls -t ReleaseNotes/$(VERSION)*.md)
else
	pandoc -f gfm -o $@ --standalone --metadata title="Lunar $(FULL_VERSION) - Release Notes" --css https://files.lunar.fyi/ReleaseNotes/release.css ReleaseNotes/$(VERSION).md
endif
