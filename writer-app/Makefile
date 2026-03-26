# Use the Buildroot cross-compiler when provided
CC ?= $(CROSS_COMPILE)gcc

# Default target
all: writer

# Build the writer application
writer: writer.c
	$(CC) -Wall -Werror writer.c -o writer

# Clean build artifacts
clean:
	rm -f writer
