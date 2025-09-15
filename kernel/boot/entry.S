# kernel/entry.S
# 改进版RISC-V内核启动代码
# 参考xv6但大幅简化，适合单核系统

.section .text
.global _entry

# 内核入口点 - QEMU从这里开始执行
_entry:
    # ========== 调试检查点: 启动标记 ==========
    # 任务5要求：先在汇编中直接写UART验证硬件工作
    li t0, 0x10000000           # UART基地址 (THR - Transmit Holding Register)
    li t1, 'S'                  # 启动标记字符
    sb t1, 0(t0)                # 发送到串口

    # ========== 1. 设置栈指针 ==========
    # 使用链接脚本定义的栈顶地址
    la sp, _stack_top           # 加载栈顶地址到sp寄存器
    
    # 调试检查点: 栈设置完成
    li t1, 'P'                  # 栈设置完成标记
    sb t1, 0(t0)                # 发送到串口

    # ========== 2. 清零BSS段 ==========
    # 使用链接脚本提供的精确符号
    la t0, sbss                 # BSS段开始地址
    la t1, ebss                 # BSS段结束地址
    
    # 调试检查点: 开始清零BSS
    li t2, 0x10000000           # 重新加载UART地址
    li t3, 'B'                  # BSS清零开始标记
    sb t3, 0(t2)                # 发送到串口

clear_bss_loop:
    beq t0, t1, bss_done        # 如果已到BSS段末尾 跳出循环
    sd zero, 0(t0)              # 将当前8字节清零
    addi t0, t0, 8              # 移动到下一个8字节位置
    j clear_bss_loop            # 继续循环

bss_done:
    # 调试检查点: BSS清零完成
    li t2, 0x10000000           # UART地址
    li t3, 'b'                  # BSS清零完成标记
    sb t3, 0(t2)                # 发送到串口

    # ========== 3. 跳转到C启动函数 ==========
    # 三阶段启动：entry.S → start.c → kmain.c
    li t2, 0x10000000           # UART地址  
    li t3, 'C'                  # 跳转到C代码标记
    sb t3, 0(t2)                # 发送到串口
    
    call start                  # 调用start函数(Machine模式)
    
    # ========== 4. 防止程序意外退出 ==========
    # 如果start()函数意外返回，在这里安全停止
    # 注意：正常情况下start()会通过mret跳转，不会返回
hang:
    # 调试检查点: 意外返回 - 这不应该发生
    li t0, 0x10000000           # UART地址
    li t1, 'E'                  # 错误标记 - kmain()不应该返回
    sb t1, 0(t0)                # 发送到串口
    
    # 禁用中断，进入安全的无限循环
    csrci mstatus, 0x8          # 清除MIE位，禁用中断
    
    # 无限循环，防止CPU继续执行随机内存
    j hang

# ========== 符号导出 ==========
# 供链接器和调试器使用
.global hang
.type _entry, @function
.type hang, @function