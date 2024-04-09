BUILD_DIR=build
SOURCE_DIR=src
MACHINE=-drive format=raw,file=$(BUILD_DIR)/boot.img,index=0 -m 2048M

.PHONY: clean run debug

$(BUILD_DIR)/boot.img: $(BUILD_DIR) $(BUILD_DIR)/bootloader.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin $(SOURCE_DIR)/kernel.fs
	# Setup disk
	dd if=/dev/zero of=$(BUILD_DIR)/boot.img bs=512 count=65504
	mkfs.fat -F16 -n"FOOBAR" $(BUILD_DIR)/boot.img
	# Copy bootloader
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/boot.img bs=512 count=1 conv=notrunc
	dd if=$(BUILD_DIR)/stage2.bin of=$(BUILD_DIR)/boot.img seek=1 bs=512 count=3 conv=notrunc
	# Copy files to fs
	mcopy -i $(BUILD_DIR)/boot.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	mcopy -i $(BUILD_DIR)/boot.img $(SOURCE_DIR)/kernel.fs "::kernel.fs"

$(BUILD_DIR)/%.bin: $(SOURCE_DIR)/%.s
	fasm $< $@

run: $(BUILD_DIR)/boot.img
	qemu-system-x86_64 $(MACHINE)

debug: $(BUILD_DIR)/boot.img
	qemu-system-x86_64 $(MACHINE) -s -S &
	gdb -ex "set architecture i8086" -ex "target remote localhost:1234" -ex "br *0x7C00" -ex "br *0x7E00" -ex "c" -ex "layout asm"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

