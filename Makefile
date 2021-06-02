define n


endef

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

.PHONY: release
release: changelog
	echo "$(VERSION)" > /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	echo "" >> /tmp/release_file_$(VERSION).md
	cat ReleaseNotes/$(VERSION).md >> /tmp/release_file_$(VERSION).md
	hub release create v$(VERSION) -a "Releases/Lunar-$(VERSION).dmg#Lunar.dmg" -F /tmp/release_file_$(VERSION).md
# 	rsync -avz --remove-source-files -e ssh Releases/Lunar-$(VERSION).dmg Lunar.dmg noiseblend:/static/Lunar
# 	rsync -avz -e ssh Releases/appcast.xml noiseblend:/static/Lunar
sentry-release:
	./release.sh

print-%  : ; @echo $* = $($*)