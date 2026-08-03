########################################
# fridge_ai
########################################

TARGET := fridge_ai

CROSS_COMPILE ?= arm-sigmastar-linux-uclibcgnueabihf-9.1.0-
PRJ_ROOT ?= $(CURDIR)/../../../../project
SDK_ROOT ?= $(CURDIR)/../../../../sdk
KERNEL_ROOT ?= $(CURDIR)/../../../../kernel
SDK_INC_DIR ?= $(SDK_ROOT)/verify/sample_code/internal
KERNEL_INC_DIR ?= $(KERNEL_ROOT)/drivers/sstar/include

CC := $(CROSS_COMPILE)gcc
CXX := $(CROSS_COMPILE)g++
STRIP := $(CROSS_COMPILE)strip

CURDIR := $(shell pwd)

SRC_DIR := $(CURDIR)/src
INIT_DIR := $(CURDIR)/init

INC_DIRS +=	$(PRJ_ROOT)/release/include
INC_DIRS += $(CURDIR)/src

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
CFLAGS := \
	-O2 \
	-Wall \
	-Wextra
CXXFLAGS := \
	-O2 \
	-Wall \
	-Wextra

########################################
# SigmaStar SDK
########################################
INC_DIRS += $(SDK_INC_DIR)/common
INC_DIRS += $(SDK_INC_DIR)/vif
INC_DIRS += $(SDK_INC_DIR)/isp
INC_DIRS += $(SDK_INC_DIR)/scl
INC_DIRS += $(SDK_INC_DIR)/venc
INC_DIRS += $(SDK_INC_DIR)/rtsp_video
INC_DIRS += $(SDK_INC_DIR)/../../common/ss_rtsp
INC_DIRS += $(SDK_INC_DIR)/../../common/list
INC_DIRS += $(KERNEL_INC_DIR)

INC = $(addprefix -I,$(INC_DIRS))
CFLAGS += $(INC)
CXXFLAGS += $(INC)

LDFLAGS += \
	-L$(PRJ_ROOT)/release/chip/ifado/ipc/common/uclibc/9.1.0/release/mi_libs/static \
	-L$(PRJ_ROOT)/release/chip/ifado/sigma_common_libs/uclibc/9.1.0/release/static \
	-L$(SDK_ROOT)/verify/sample_code/out/arm/libs/static \
	-lpthread \
	-lm \
	-ldl \
	-lrt

########################################
# SigmaStar MI Library
########################################
LDFLAGS += \
	-Wl,--start-group \
	-lrtsp_video \
	-lss_rtsp \
	-llive555 \
	-lcommon \
	-lisp \
	-lvenc \
	-lscl \
	-lvif \
	-lmi_common \
	-lmi_sensor \
	-lmi_vif \
	-lmi_isp \
	-lmi_scl \
	-lmi_venc \
	-lmi_sys \
	-lmi_ipu \
	-lmi_ai \
	-lmi_ao \
	-lcus3a \
	-lispalgo \
	-lcam_os_wrapper \
	-lcam_fs_wrapper \
	-Wl,--end-group

########################################
# Build
########################################
TARGET_BIN := $(OUT_DIR)/$(TARGET)

all: $(TARGET_BIN)

$(TARGET_BIN): $(OBJS)
	@mkdir -p $(OUT_DIR)
	@$(CXX) $^ -o $@ $(LDFLAGS)
	@$(STRIP) $@

$(OUT_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(OUT_DIR)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OUT_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	@$(CC) $(CFLAGS) -c $< -o $@

clean:
	@rm -rf $(OBJS)
	@rm -rf $(OUT_DIR)

########################################
# RootFS Intall
########################################
ROOTFS_BIN ?= $(PRJ_ROOT)/image/output/customer

install: all
	@mkdir -p $(ROOTFS_BIN)
	@cp $(TARGET_BIN) $(ROOTFS_BIN)
	@cp $(INIT_DIR)/fridge_ai.script $(ROOTFS_BIN)

########################################
.PHONY: all clean install
