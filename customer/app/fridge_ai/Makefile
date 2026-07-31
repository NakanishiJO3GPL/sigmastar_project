########################################
# fridge_ai
########################################

TARGET := fridge_ai

CROSS_COMPILE ?= arm-sigmastar-linux-uclibcgnueabihf-9.1.0-
SDK_ROOT ?= $(CURDIR)/../../../../project

CC := $(CROSS_COMPILE)gcc
CXX := $(CROSS_COMPILE)g++
STRIP := $(CROSS_COMPILE)strip

CURDIR := $(shell pwd)

SRC_DIR := $(CURDIR)/src
INIT_DIR := $(CURDIR)/init
INC_DIR := $(CURDIR)/src
OUT_DIR := $(CURDIR)/output

########################################
# Sources
########################################
C_SRCS := $(wildcard $(SRC_DIR)/*.c)
CXX_SRCS := $(wildcard $(SRC_DIR)/*.cpp)

C_OBJS := $(C_SRCS:$(SRC_DIR)/%.c=$(OUT_DIR)/%.o)
CXX_OBJS := $(CXX_SRCS:$(SRC_DIR)/%.cpp=$(OUT_DIR)/%.o)

OBJS := $(C_OBJS) $(CXX_OBJS)

########################################
# Compiler Flags
########################################
CFLAGS += \
	-O2 \
	-Wall \
	-Wextra \
	-I$(INC_DIR)
CXXFLAGS += \
	-O2 \
	-Wall \
	-Wextra \
	-I$(INC_DIR)

########################################
# SigmaStar SDK
########################################
CFLAGS += \
	-I$(SDK_ROOT)/release/include
CXXFLAGS += \
	-I$(SDK_ROOT)/release/include

LDFLAGS += \
	-L$(SDK_ROOT)/release/chip/ifado/ipc/common/uclibc/9.1.0/release/mi_libs/static \
	-lpthread \
	-lm \
	-ldl \
	-lrt

########################################
# SigmaStar MI Library
########################################
LDFLAGS += \
	-lmi_sys \
	-lmi_isp \
	-lmi_ipu \
	-lmi_sensor \
	-lmi_venc \
	-lmi_vif \
	-lmi_ai \
	-lmi_ao

########################################
# Build
########################################
TARGET_BIN := $(OUT_DIR)/$(TARGET)

all: $(TARGET_BIN)

$(TARGET_BIN): $(OBJS)
	@mkdir -p $(OUT_DIR)
	$(CXX) $^ -o $@ $(LDFLAGS)
	$(STRIP) $@

$(OUT_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(OUT_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OUT_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(OBJS)
	rm -rf $(OUT_DIR)

########################################
# RootFS Intall
########################################
ROOTFS_BIN ?= $(SDK_ROOT)/image/output/customer

install: all
	@mkdir -p $(ROOTFS_BIN)
	@cp $(TARGET_BIN) $(ROOTFS_BIN)
	cp $(INIT_DIR)/fridge_ai.script $(ROOTFS_BIN)

########################################
.PHONY: all clean install
