define n


endef

DISABLE_NOTARIZATION := ${DISABLE_NOTARIZATION}
DISABLE_PACKING := ${DISABLE_PACKING}
ENV=Release

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
install-git-lfs: /usr/local/bin/git-lfs

install-deps: install-swiftformat install-sourcery install-git-secret install-git-lfs

codegen: $(GENERATED_FILES)

CHANGELOG.md: $(RELEASE_NOTES_FILES)
	tail -n +1 `ls -r ReleaseNotes/*.md` | sed -E 's/==> ReleaseNotes\/(.+)\.md <==/# \1/g' > CHANGELOG.md

changelog: CHANGELOG.md
dev: install-deps install-hooks codegen

.PHONY: release upload build sentry-release pkg dmg pack appcast
upload:
	rsync -avzP Releases/*.delta noiseblend:/static/Lunar/deltas/
	rsync -avzP Releases/*.dmg noiseblend:/static/Lunar/releases/
	fish -c 'upload -d Lunar Releases/appcast.xml'
	cfcli -d lunar.fyi purge

release: changelog
	echo "$(VERSION)" > /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	cat ReleaseNotes/$(VERSION).md >> /tmp/release_file_$(VERSION).md
	hub release create v$(VERSION) -a "Releases/Lunar-$(VERSION).dmg#Lunar.dmg" -F /tmp/release_file_$(VERSION).md

sentry-release:
	./release.sh

print-%  : ; @echo $* = $($*)

pkg: SHELL=/usr/local/bin/fish
pkg:
	env CODESIGNING_FOLDER_PATH=(xcdir -s 'Lunar $(ENV)' -c $(ENV))/Lunar.app CONFIGURATION=$(ENV) ./bin/make-installer pkg

dmg: SHELL=/usr/local/bin/fish
dmg:
	env CODESIGNING_FOLDER_PATH=(xcdir -s 'Lunar $(ENV)' -c $(ENV))/Lunar.app CONFIGURATION=$(ENV) ./bin/make-installer dmg

pack: SHELL=/usr/local/bin/fish
pack:
	env CODESIGNING_FOLDER_PATH=(xcdir -s 'Lunar $(ENV)' -c $(ENV))/Lunar.app CONFIGURATION=$(ENV) PROJECT_DIR=$$PWD ./bin/pack

appcast:
	env CONFIGURATION=$(ENV) ./bin/update_appcast

build:
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO