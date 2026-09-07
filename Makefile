APP_NAME=Nudgie
BUILD_DIR=build

.PHONY: test build app run install notarize clean

test:
	swift test

build:
	swift build

app:
	./tools/make-app.sh

run: app
	open $(BUILD_DIR)/$(APP_NAME).app

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(BUILD_DIR)/$(APP_NAME).app /Applications/

notarize: app
	./tools/notarize.sh

clean:
	rm -rf .build $(BUILD_DIR)
