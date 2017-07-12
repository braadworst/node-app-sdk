
PRE_COMMIT = quality-staged
HEADER ?= "// Copyright © 2017 The Things Network\n// Use of this source code is governed by the MIT license that can be found in the LICENCE file."

JS_FILES ?= $(ALL_FILES) | $(only_js) | $(not_flowtyped)
JS_STAGED_FILES = $(STAGED_FILES) | $(only_js) | $(not_flowtyped)

include .make/*.make
include .make/js/*.make

dev-deps: js.dev-deps type-deps
test: js.test
quality: js.quality typecheck headers.check
quality-staged: js.quality-staged headers.fix-staged typecheck-staged

BABEL_FLAGS = -D --ignore '*.test.js'
build: js.build

.PHONY: protos docs

PROTOC ?= protoc

GOLAST ?= $(lastword $(subst :, ,$(GOPATH)))

PROTO_DIR = ./src/proto
NODE_MODULES = node_modules

PROTOC_INCLUDES ?= \
	-I/usr/local/include \
	-I$(GOLAST)/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
	-I`dirname $(PWD)` \
	-I$(GOLAST)/src

PROTOC_FLAGS ?= $(PROTOC_INCLUDES) \
	--grpc_out=$(PROTO_DIR) \
	--flowtypes_out=$(PROTO_DIR)/types \
  --plugin=protoc-gen-grpc=$(PWD)/$(NODE_MODULES)/.bin/grpc_tools_node_protoc_plugin \
	--js_out=import_style=commonjs,binary:$(PROTO_DIR)

only_pb = grep '_pb\.js$$'

protos: fix-protos

compile-protos:
	$(log) "building protos"
	@mkdir -p $(PROTO_DIR)
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/discovery/discovery.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/handler/handler.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/gateway/gateway.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/api.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/api.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/broker/broker.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/protocol/protocol.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/protocol/lorawan/device.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/protocol/lorawan/lorawan.proto
	@$(PROTOC) $(PROTOC_FLAGS) $(GOLAST)/src/github.com/TheThingsNetwork/ttn/api/trace/trace.proto
	@mkdir -p $(PROTO_DIR)/google/protobuf
	@touch $(PROTO_DIR)/google/protobuf/empty_pb.js
	@mkdir -p $(PROTO_DIR)/google/api
	@touch $(PROTO_DIR)/google/api/annotations_pb.js
	@mkdir -p $(PROTO_DIR)/github.com/gogo/protobuf/gogoproto
	@touch $(PROTO_DIR)/github.com/gogo/protobuf/gogoproto/gogo_pb.js

fix-protos: compile-protos
	$(log) "fixing protos"
	@$(JS_FILES) | $(only_pb) | xargs sed -i.bk 's:\([^/]\)github\.com:\1github_com:g'
	@find $(PROTO_DIR) -name '*_pb.js.bk' | xargs rm

DOCJS = ./node_modules/.bin/documentation
DOCJS_FLAGS = --shallow -g

DOC_FILE = DOCUMENTATION.md

docs:
	$(log) building documentation
	@$(DOCJS) build `$(JS_LINT_FILES)` $(DOCJS_FLAGS) -f md > $(DOC_FILE)

FLOW = ./node_modules/.bin/flow

typecheck:
	$(log) "typechecking all files"
	@$(FLOW) check

typecheck-staged:
	$(log) "typechecking `$(JS_STAGED_FILES) | $(count)` js files"
	@CODE=0; for file in `$(JS_STAGED_FILES)`; do $(FLOW) focus-check --quiet $$file || { $(erri) "type error in $$file"; CODE=1; }; done; exit $$CODE

typestatus:
	$(log) "checking flow status"
	@$(FLOW) status

FLOW_TYPED = $(NODE_MODULES)/.bin/flow-typed

type-deps:
	$(log) "installing type definitions"
	@$(FLOW_TYPED) install


not_flowtyped = grep -v './flow-typed'

JS_FILES ?= $(ALL_FILES) | $(only_js) | $(not_flowtyped)
JS_STAGED_FILES = $(STAGED_FILES) | $(only_js) | $(not_flowtyped)
