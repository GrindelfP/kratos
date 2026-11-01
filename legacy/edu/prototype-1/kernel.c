#include <stddef.h>
#include <stdint.h>

#define true 1
#define false 0

#if defined(__linux__)
#error "You are not using cross-compiler!"
#endif

#if !defined(__i386__)
#error "Was not compiled in a ix86-elf enviroment!"
#endif

/**
* Text color constants enumeration.
*/
enum vga_color {
	VGA_COLOR_BLACK = 0,
	
};

