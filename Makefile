define n


endef

.EXPORT_ALL_VARIABLES:

DISABLE_NOTARIZATION := ${DISABLE_NOTARIZATION}
DISABLE_PACKING := ${DISABLE_PACKING}
ENV=Release
DSA=1

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
	rsync -avzP Releases/*.delta noiseblend:/static/Lunar/deltas/ || exit 0
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
	./bin/release.sh

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

signatures: SHELL=/usr/local/bin/fish
signatures:
	echo '<signature>'(timeout 2 /tmp/Lunar/Lunar.app/Contents/MacOS/Lunar @ signature)'</signature>'\n'<signature>'(timeout 2 arch -x86_64 /tmp/Lunar/Lunar.app/Contents/MacOS/Lunar @ signature)'</signature>' | pbcopy
	subl Releases/appcast.xml

setversion: OLD_VERSION=$(shell xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace -showBuildSettings 2>/dev/null | rg -o -r '$$1' 'MARKETING_VERSION = (\S+)')
setversion:
ifneq (, $(VERSION))
	rg -l 'VERSION = "?$(OLD_VERSION)"?' && sed -E -i .bkp 's/VERSION = "?$(OLD_VERSION)"?/VERSION = $(VERSION)/g' $$(rg -l 'VERSION = "?$(OLD_VERSION)"?')
endif

clean:
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO clean

build: BEAUTIFY=1
build: setversion
ifneq ($(BEAUTIFY),0)
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO | tee /tmp/lunar-$(ENV)-build.log | xcbeautify
else
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO | tee /tmp/lunar-$(ENV)-build.log
endif

build-version: BEAUTIFY=1
build-version:
ifneq ($(BEAUTIFY),0)
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(VERSION) | tee /tmp/lunar-$(ENV)-build.log | xcbeautify
else
	xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace ONLY_ACTIVE_ARCH=NO MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(VERSION) | tee /tmp/lunar-$(ENV)-build.log
endif

beta-upload: SHELL=/usr/local/bin/fish
beta-upload: ENV=Release
beta-upload: V=1
beta-upload: VERSION=$(shell xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace -showBuildSettings 2>/dev/null | rg -o -r '$$1' 'MARKETING_VERSION = (\S+)')-beta$V
beta-upload:
	upload -d lunar -n Lunar-(defaults read /tmp/Lunar/Lunar.app/Contents/Info.plist CFBundleVersion).zip /tmp/Lunar/Lunar.zip
	upload -d lunar Releases/appcast.xml

beta: SHELL=/usr/local/bin/fish
beta: ENV=Release
beta: DISABLE_PACKING=1
beta: DISABLE_SENTRY=1
beta: V=1
beta: VERSION=$(shell xcodebuild -scheme "Lunar $(ENV)" -configuration $(ENV) -workspace Lunar.xcworkspace -showBuildSettings 2>/dev/null | rg -o -r '$$1' 'MARKETING_VERSION = (\S+)')-beta$V
beta: build-version appcast
	test (defaults read /tmp/Lunar/Lunar.app/Contents/Info.plist CFBundleVersion) = $(VERSION)
	xcnotary notarize -d alin.p32@gmail.com -k altool /tmp/Lunar/Lunar.app
	spctl -vvv --assess /tmp/Lunar/Lunar.app 2>&1 | grep Notarized
	upload -d lunar -n Lunar-(defaults read /tmp/Lunar/Lunar.app/Contents/Info.plist CFBundleVersion).zip /tmp/Lunar/Lunar.zip
	upload -d lunar Releases/appcast.xml
