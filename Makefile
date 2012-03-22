# Helper Variables
# The command to replace the @VERSION in the files with the actual version
HEAD_SHA = $(shell git log -1 --format=format:"%H")
VER = sed "s/v@VERSION/$$(git log -1 --format=format:"Git Build: SHA1: %H <> Date: %cd")/"
VER_MIN = "/*! jQuery Mobile v$$(git log -1 --format=format:"Git Build: SHA1: %H <> Date: %cd") jquerymobile.com | jquery.org/license */"
VER_OFFICIAL = $(shell cat version.txt)
SED_VER_REPLACE = 's/__version__/"${VER_OFFICIAL}"/g'
SED_VER_API = sed ${SED_VER_REPLACE}
SED_INPLACE_EXT = "whyunowork"
deploy: VER = sed "s/v@VERSION/${VER_OFFICIAL} ${HEAD_SHA}/"
deploy: VER_MIN = "/*! jQuery Mobile v${VER_OFFICIAL} ${HEAD_SHA} jquerymobile.com | jquery.org/license */"

# The output folder for the finished files
OUTPUT = compiled

# The name of the files
NAME = jquery.mobile
BASE_NAME = jquery.mobile
THEME_FILENAME = jquery.mobile.theme
STRUCTURE = jquery.mobile.structure
deploy: NAME = jquery.mobile-${VER_OFFICIAL}
deploy: THEME_FILENAME = jquery.mobile.theme-${VER_OFFICIAL}
deploy: STRUCTURE = jquery.mobile.structure-${VER_OFFICIAL}

# The CSS theme being used
THEME = default

# Build Targets
# When no build target is specified, all gets ran
all: css js zip notify

clean:
	# -------------------------------------------------
	# Cleaning build output
	@@rm -rf ${OUTPUT}
	@@rm -rf tmp

# Create the output directory.
init:
	@@mkdir -p ${OUTPUT}

# Build and minify the CSS files
css: init
	@@bash build/bin/css.sh

# Build and minify the JS files
js: init
	@@bash build/bin/js.sh

docs: init js css
	@@bash build/bin/docs.sh

# Output a message saying the process is complete
notify: init
	@@echo "The files have been built and are in: " $$(pwd)/${OUTPUT}
	# -------------------------------------------------


# Zip up the jQm files without docs
zip: init css js
	@@bash build/bin/zip.sh

# -------------------------------------------------
# -------------------------------------------------
# -------------------------------------------------
#
# For jQuery Team Use Only
#
# -------------------------------------------------
# NOTE the clean (which removes previous build output) has been removed to prevent a gap in service
build_latest: css docs js zip
	# ... Copy over the lib js, avoid the compiled stuff, to get the defines for tests/unit/*
	@@ # TODO centralize list of built files
	@@find js -name "*.js" -not -name "*.docs.js" -not -name "*.mobile.js"  | xargs -L1 -I FILENAME cp FILENAME ${OUTPUT}/demos/js/

# Push the latest git version to the CDN. This is done on a post commit hook
deploy_latest:
	# Time to put these on the CDN
	@@scp -qr ${OUTPUT}/* jqadmin@code.origin.jquery.com:/var/www/html/code.jquery.com/mobile/latest/
	# -------------------------------------------------

# TODO target name preserved to avoid issues during refactor, latest -> deploy_latest
latest: build_latest deploy_latest

# Push the nightly backups. This is done on a server cronjob
deploy_nightlies:
	# Time to put these on the CDN
	@@scp -qr ${OUTPUT} jqadmin@code.origin.jquery.com:/var/www/html/code.jquery.com/mobile/nightlies/$$(date "+%Y%m%d")
	# -------------------------------------------------

# Deploy a finished release. This is manually done.
deploy: clean init css js docs zip
	# Deploying all the files to the CDN
	@@mkdir tmp
	@@cp -R ${OUTPUT} tmp/${VER_OFFICIAL}
	@@scp -qr tmp/* jqadmin@code.origin.jquery.com:/var/www/html/code.jquery.com/mobile/
	@@rm -rf tmp/${VER_OFFICIAL}
	@@mv ${OUTPUT}/demos tmp/${VER_OFFICIAL}
	# Create the Demos/Docs/Tests/Tools for jQueryMobile.com
	# ... By first replacing the paths
	@@ # TODO update jQuery Version replacement on deploy
	@@find tmp/${VER_OFFICIAL} -type f \
		\( -name '*.html' -o -name '*.php' \) \
		-exec perl -pi -e \
		's|src="(.*)${BASE_NAME}.js"|src="//code.jquery.com/mobile/${VER_OFFICIAL}/${NAME}.min.js"|g;s|href="(.*)${BASE_NAME}.css"|href="//code.jquery.com/mobile/${VER_OFFICIAL}/${NAME}.min.css"|g;s|src="(.*)jquery.js"|src="//code.jquery.com/jquery-1.7.1.min.js"|g' {} \;
	# ... So they can be copied to jquerymobile.com
	@@scp -qr tmp/* jqadmin@jquerymobile.com:/srv/jquerymobile.com/htdocs/demos/
	# Do some cleanup to wrap it up
	@@rm -rf tmp
	@@rm -rf ${OUTPUT}
	# -------------------------------------------------
