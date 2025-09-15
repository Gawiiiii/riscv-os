OUTPUT_ARCH("riscv")
ENTRY(_entry)

SECTIONS {
    . = 0x80000000;
    
    .text : {
        PROVIDE(_text_start = .);
        *(.text .text.*)
        . = ALIGN(16);
        PROVIDE(_text_end = .);
        PROVIDE(etext = .);
    }
    
    .rodata : {
        . = ALIGN(16);
        *(.rodata .rodata.*)
    }
    
    .data : {
        . = ALIGN(16);
        PROVIDE(_data_start = .);
        *(.data .data.*)
        PROVIDE(_data_end = .);
        PROVIDE(edata = .);
    }
    
    .bss : {
        . = ALIGN(16);
        PROVIDE(_bss_start = .);
        PROVIDE(sbss = .);
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        PROVIDE(_bss_end = .);
        PROVIDE(ebss = .);
    }
    
    PROVIDE(end = .);
    . = ALIGN(0x1000);
    PROVIDE(_stack_bottom = .);
    . = . + 0x1000;
    PROVIDE(_stack_top = .);
}