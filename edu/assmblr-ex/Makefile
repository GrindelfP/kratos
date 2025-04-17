AS = as
LD = ld

ASFLAGS = -arch x86_64
LDFLAGS = -lSystem -syslibroot $(shell xcrun --show-sdk-path --sdk macosx) -e _main

TARGET = hello
OBJECTS = $(TARGET).o
SOURCES = $(TARGET).s

all: $(TARGET)

$(TARGET) : $(OBJECTS)
	$(LD) -o $@ $^ $(LDFLAGS)

$(TARGET) : $(SOURCES)
	$(AS) $(ASFLAGS) -o $@ $<

clean: 
	rm -f $(TARGET) $(OBJECTS)
	
