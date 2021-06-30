# Arduino makefile
#
# This makefile allows you to build sketches from the command line
# without the Arduino environment (or Java).
#
# The Arduino environment does preliminary processing on a sketch before
# compiling it.  If you're using this makefile instead, you'll need to do
# a few things differently:
#
#   - Give your program's file a .cpp extension (e.g. foo.cpp).
#
#   - Put this line at top of your code: #include <WProgram.h>
#
#   - Write prototypes for all your functions (or define them before you
#     call them).  A prototype declares the types of parameters a
#     function will take and what type of value it will return.  This
#     means that you can have a call to a function before the definition
#     of the function.  A function prototype looks like the first line of
#     the function, with a semi-colon at the end.  For example:
#     int digitalRead(int pin);
#
# Instructions for using the makefile:
#
#  1. Copy this file into the folder with your sketch.
#
#  2. Below, modify the line containing "TARGET" to refer to the name of
#     of your program's file without an extension (e.g. TARGET = foo).
#
#  3. Modify the line containg "ARDUINO" to point the directory that
#     contains the Arduino core (for normal Arduino installations, this
#     is the lib/targets/arduino sub-directory).
#
#  4. Modify the line containing "PORT" to refer to the filename
#     representing the USB or serial connection to your Arduino board
#     (e.g. PORT = /dev/tty.USB0).  If the exact name of this file
#     changes, you can use * as a wildcard (e.g. PORT = /dev/tty.USB*).
#
#  5. At the command line, change to the directory containing your
#     program's file and the makefile.
#
#  6. Type "make" and press enter to compile/verify your program.
#
#  7. Type "make upload", reset your Arduino board, and press enter  to
#     upload your program to the Arduino board.
#
# $Id$


# Sources
TARGET = TFTScreen

ARDUINO = ./ArduinoCore-avr
ARDUINO_CORE = $(ARDUINO)/cores/arduino
ARDUINO_VARIANT = $(ARDUINO)/variants/standard
SRC = $(wildcard $(ARDUINO_CORE)/*.c) 
CXXSRC = $(wildcard  $(ARDUINO_CORE)/*.cpp) $(TARGET).cpp
ASRC = $(wildcard $(ARDUINO_CORE)/*.S)
CINCS = -I$(ARDUINO_VARIANT)/ -I$(ARDUINO_CORE)/

ADAFRUIT_GFX = ./Adafruit-GFX-Library
CXXSRC += $(ADAFRUIT_GFX)/Adafruit_GFX.cpp
CINCS += -I$(ADAFRUIT_GFX)

MCUFRIEND = ./MCUFRIEND_kbv
MCUFRIEND_UTILS = $(MCUFRIEND)/utility
CXXSRC += $(MCUFRIEND)/MCUFRIEND_kbv.cpp
CINCS += -I$(MCUFRIEND) -I$(MCUFRIEND_UTILS)


# Defines
F_CPU = 16000000
MCU = atmega328p
DEF = -DF_CPU=$(F_CPU) -DARDUINO=10815 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR

# Environment settings
CC = avr-gcc
CXX = avr-g++
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size
NM = avr-nm
AVRDUDE = avrdude
REMOVE = rm -f
MV = mv -f

FORMAT = ihex

# Name of this Makefile (used for "make depend").
MAKEFILE = Makefile


# Define all object files.
OBJ = $(SRC:.c=.c.o) $(CXXSRC:.cpp=.cpp.o) $(ASRC:.S=.S.o)

# Define all listing files.
LST = $(ASRC:.S=.lst) $(CXXSRC:.cpp=.lst) $(SRC:.c=.lst)


# Place -D or -U options here
CDEFS = $(DEF) 
CXXDEFS = $(DEF)
# Compiler flag to set the C Standard level.
# c89   - "ANSI" C
# gnu89 - c89 plus GCC extensions
# c99   - ISO C99 standard (not yet fully implemented)
# gnu99 - c99 plus GCC extensions
DEBUG = stabs
OPT = s
CSTANDARD = -std=gnu99
CDEBUG = -g$(DEBUG)
CWARN = -Wall
CTUNING =  -ffunction-sections -fdata-sections -MMD -flto -fno-fat-lto-objects

CFLAGS = $(CDEBUG) $(CDEFS) $(CINCS) -O$(OPT) $(CWARN) $(CSTANDARD) $(CEXTRA)
CXXFLAGS =  -g -O$(OPT) -Wall $(CXXDEFS) -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -MMD -flto
ELF_FLAGS = $(CWARN) -Os -g -flto -fuse-linker-plugin -Wl,--gc-sections
ASFLAGS = -c -g -x assembler-with-cpp -flto -MMD $(CDEFS)
LDFLAGS = 


# Combine all necessary flags and optional flags.
# Add target processor to flags.
ALL_CFLAGS = $(CFLAGS) -mmcu=$(MCU) $(CINCS)
ALL_CXXFLAGS = $(CXXFLAGS) -mmcu=$(MCU) $(CINCS)
ALL_ASFLAGS = -mmcu=$(MCU) -x assembler-with-cpp $(ASFLAGS) $(CINCS) 


# Default target.
all: build

build: elf hex eep

elf: $(TARGET).elf
hex: $(TARGET).hex
eep: $(TARGET).eep
lss: $(TARGET).lss 
sym: $(TARGET).sym




# Convert ELF to COFF for use in debugging / simulating in AVR Studio or VMLAB.
COFFCONVERT=$(OBJCOPY) --debugging \
--change-section-address .data-0x800000 \
--change-section-address .bss-0x800000 \
--change-section-address .noinit-0x800000 \
--change-section-address .eeprom-0x810000 


coff: $(TARGET).elf
	$(COFFCONVERT) -O coff-avr $(TARGET).elf $(TARGET).cof

extcoff: $(TARGET).elf
	$(COFFCONVERT) -O coff-ext-avr $(TARGET).elf $(TARGET).cof

%.hex : %.elf
	$(OBJCOPY) -O $(FORMAT) -R .eeprom $< $@

%.eep : %.elf
	$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings  --change-section-lma .eeprom=0 -O $(FORMAT) $< $@

# Create extended listing file from ELF output file.
%lss : %.elf
	$(OBJDUMP) -h -S $< > $@

# Create a symbol table from ELF output file.
%.sym: %.elf
	$(NM) -n $< > $@



# Link: create ELF output file from object files.
$(TARGET).elf: $(OBJ)
	$(CC) $(ALL_CFLAGS) $(OBJ) --output $@ $(LDFLAGS)


# Compile: create object files from C++ source files.
%.cpp.o: %.cpp
	$(CXX) -c $(ALL_CXXFLAGS) $< -o $@ 

# Compile: create object files from C source files.
%.c.o: %.c
	$(CC) -c $(ALL_CFLAGS) $< -o $@ 


# Compile: create assembler files from C source files.
%.c.s: %.c
	$(CC) -S $(ALL_CFLAGS) $< -o $@


# Assemble: create object files from assembler source files.
%.S.o: %.S
	$(CC) -c $(ALL_ASFLAGS) $< -o $@

# Programming support using avrdude. Settings and variables.
UPLOAD_RATE = 115200
AVRDUDE_PROGRAMMER = arduino
AVRDUDE_PART = atmega328p
AVRDUDE_PORT = /dev/ttyACM0
AVRDUDE_WRITE_FLASH = -Uflash:w:$(TARGET).hex:i
AVRDUDE_FLAGS = -v  -p $(AVRDUDE_PART) -c $(AVRDUDE_PROGRAMMER) -P $(AVRDUDE_PORT) -b $(UPLOAD_RATE) -D
	
# Program the device.  
upload: $(TARGET).hex $(TARGET).eep
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FLASH)




# Target: clean project.
clean:
	$(REMOVE) $(TARGET).hex $(TARGET).eep $(TARGET).cof $(TARGET).elf \
	$(TARGET).map $(TARGET).sym $(TARGET).lss \
	$(OBJ) $(LST) $(SRC:.c=.s) $(SRC:.c=.c.d) $(CXXSRC:.cpp=.s) $(CXXSRC:.cpp=.cpp.d) $(ASRC:.S=.S.d)

depend:
	if grep '^# DO NOT DELETE' $(MAKEFILE) >/dev/null; \
	then \
		sed -e '/^# DO NOT DELETE/,$$d' $(MAKEFILE) > \
			$(MAKEFILE).$$$$ && \
		$(MV) $(MAKEFILE).$$$$ $(MAKEFILE); \
	fi
	echo '# DO NOT DELETE THIS LINE -- make depend depends on it.' \
		>> $(MAKEFILE); \
	$(CC) -M -mmcu=$(MCU) $(CDEFS) $(CINCS) $(SRC) $(ASRC) >> $(MAKEFILE)

.PHONY:	all build elf hex eep lss sym program coff extcoff clean depend
