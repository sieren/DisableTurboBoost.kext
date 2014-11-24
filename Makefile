NAME := DisableTurboBoost
#KEXT := /System/Library/Extensions/$(NAME).kext
KEXT := /tmp/$(NAME).kext
DIR  := Contents/MacOS
BIN  := $(DIR)/$(NAME)
INFO := Contents/Info.plist
FRAMEWORKS:= -framework Foundation -framework IOKit
LIBRARIES:= -lobjc
LDFLAGS :=$(LIBRARIES) $(FRAMEWORKS)
CC = g++
# detect current kernel architecture
CPU  := $(shell uname -m)
ifeq ($(CPU),i386)
CPPFLAGS += -m32
else
ifeq ($(CPU),x86_64)
CPPFLAGS += -m64
endif
endif

$(BIN): $(DIR) $(NAME).cpp Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(CPPFLAGS) $(MARCH) -Xlinker -kext -static $(NAME).cpp -o $@ -fno-builtin -nostdlib -lkmod -r -I/System/Library/Frameworks/Kernel.framework/Headers -Wall

$(DIR):; mkdir -p $(DIR)

load: $(KEXT) $(KEXT)/$(BIN) $(KEXT)/$(INFO)
	sudo chown -R root:wheel $(KEXT)
	sudo kextutil -v $(KEXT)

unload:
	sudo kextunload -v $(KEXT)

$(KEXT):; mkdir -p $@
$(KEXT)/$(DIR):; mkdir -p $@

$(KEXT)/$(INFO): $(KEXT) $(INFO)
	sudo cp $(INFO) $@

$(KEXT)/$(BIN): $(KEXT)/$(DIR) $(BIN)
	sudo cp $(BIN) $@
