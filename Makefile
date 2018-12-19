#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2018, Joyent, Inc.
#

GO_PREBUILT_VERSION = 1.10.3
NODE_PREBUILT_VERSION = v6.15.1

ifeq ($(shell uname -s),SunOS)
    NODE_PREBUILT_TAG=zone
    # Allow building on other than sdc-minimal-multiarch-lts@15.4.1
    NODE_PREBUILT_IMAGE=18b094b0-eb01-11e5-80c1-175dac7ddf02
endif

include ./tools/mk/Makefile.defs
include ./tools/mk/Makefile.smf.defs
ifeq ($(shell uname -s),SunOS)
    include ./tools/mk/Makefile.go_prebuilt.defs
    include ./tools/mk/Makefile.node_prebuilt.defs
endif

SERVICE_NAME = prometheus
RELEASE_TARBALL := $(SERVICE_NAME)-pkg-$(STAMP).tar.bz2
RELSTAGEDIR := /tmp/$(STAMP)
SMF_MANIFESTS = smf/manifests/prometheus.xml

PROMETHEUS_IMPORT = github.com/prometheus/prometheus
PROMETHEUS_GO_DIR = $(GO_GOPATH)/src/$(PROMETHEUS_IMPORT)
PROMETHEUS_EXEC = $(PROMETHEUS_GO_DIR)/prometheus

JS_FILES := $(TOP)/bin/certgen
ESLINT_FILES := $(JS_FILES)

STAMP_CERTGEN := $(MAKE_STAMPS_DIR)/certgen

#
# Repo-specific targets
#
.PHONY: all
all: $(PROMETHEUS_EXEC) $(STAMP_CERTGEN)

#
# Link the "pg_prefaulter" submodule into the correct place within our
# project-local GOPATH, then build the binary.
#
$(PROMETHEUS_EXEC): deps/prometheus/.git $(STAMP_GO_TOOLCHAIN)
	$(GO) version
	mkdir -p $(dir $(PROMETHEUS_GO_DIR))
	rm -f $(PROMETHEUS_GO_DIR)
	ln -s $(TOP)/deps/prometheus $(PROMETHEUS_GO_DIR)
	(cd $(PROMETHEUS_GO_DIR) && env -i $(GO_ENV) make build)

$(STAMP_CERTGEN): | $(NODE_EXEC) $(NPM_EXEC)
	$(MAKE_STAMP_REMOVE)
	rm -rf $(TOP)/node_modules && cd $(TOP) && $(NPM) install --production
	$(MAKE_STAMP_CREATE)

clean::
	# Clean certgen
	rm -rf $(TOP)/node_modules

.PHONY: release
release: all deps docs $(SMF_MANIFESTS)
	@echo "Building $(RELEASE_TARBALL)"
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)
	cp -r \
		$(TOP)/bin \
		$(TOP)/package.json \
		$(TOP)/node_modules \
		$(TOP)/smf \
		$(TOP)/sapi_manifests \
		$(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)/
	# our prometheus build
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)/prometheus
	cp -r \
		$(PROMETHEUS_GO_DIR)/prometheus \
		$(PROMETHEUS_GO_DIR)/promtool \
		$(PROMETHEUS_GO_DIR)/consoles \
		$(PROMETHEUS_GO_DIR)/console_libraries \
		$(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)/prometheus/
	# our node version
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)/build
	cp -r \
		$(TOP)/build/node \
		$(RELSTAGEDIR)/root/opt/triton/$(SERVICE_NAME)/build/
	# zone boot
	mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/boot
	cp -r $(TOP)/deps/sdc-scripts/{etc,lib,sbin,smf} \
		$(RELSTAGEDIR)/root/opt/smartdc/boot/
	cp -r $(TOP)/boot/* \
		$(RELSTAGEDIR)/root/opt/smartdc/boot/
	# tar it up
	(cd $(RELSTAGEDIR) && $(TAR) -jcf $(TOP)/$(RELEASE_TARBALL) root)
	@rm -rf $(RELSTAGEDIR)


.PHONY: publish
publish: release
	@if [[ -z "$(BITS_DIR)" ]]; then \
		echo "error: 'BITS_DIR' must be set for 'publish' target"; \
		exit 1; \
	fi
	mkdir -p $(BITS_DIR)/$(SERVICE_NAME)
	cp $(TOP)/$(RELEASE_TARBALL) $(BITS_DIR)/$(SERVICE_NAME)/$(RELEASE_TARBALL)

.PHONY: dumpvar
dumpvar:
	@if [[ -z "$(VAR)" ]]; then \
		echo "error: set 'VAR' to dump a var"; \
		exit 1; \
	fi
	@echo "$(VAR) is '$($(VAR))'"

mytarget:
	echo my command

include ./tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
    include ./tools/mk/Makefile.go_prebuilt.targ
    include ./tools/mk/Makefile.node_prebuilt.targ
endif
include ./tools/mk/Makefile.smf.targ
include ./tools/mk/Makefile.targ
