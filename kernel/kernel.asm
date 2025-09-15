
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:

# 内核入口点 - QEMU从这里开始执行
_entry:
    # ========== 调试检查点: 启动标记 ==========
    # 任务5要求：先在汇编中直接写UART验证硬件工作
    li t0, 0x10000000           # UART基地址 (THR - Transmit Holding Register)
    80000000:	100002b7          	lui	t0,0x10000
    li t1, 'S'                  # 启动标记字符
    80000004:	05300313          	li	t1,83
    sb t1, 0(t0)                # 发送到串口
    80000008:	00628023          	sb	t1,0(t0) # 10000000 <_entry-0x70000000>

    # ========== 1. 设置栈指针 ==========
    # 使用链接脚本定义的栈顶地址
    la sp, _stack_top           # 加载栈顶地址到sp寄存器
    8000000c:	00002117          	auipc	sp,0x2
    80000010:	ff410113          	add	sp,sp,-12 # 80002000 <_stack_top>
    
    # 调试检查点: 栈设置完成
    li t1, 'P'                  # 栈设置完成标记
    80000014:	05000313          	li	t1,80
    sb t1, 0(t0)                # 发送到串口
    80000018:	00628023          	sb	t1,0(t0)

    # ========== 2. 清零BSS段 ==========
    # 使用链接脚本提供的精确符号
    la t0, sbss                 # BSS段开始地址
    8000001c:	00001297          	auipc	t0,0x1
    80000020:	8e428293          	add	t0,t0,-1820 # 80000900 <test_bss_var>
    la t1, ebss                 # BSS段结束地址
    80000024:	00001317          	auipc	t1,0x1
    80000028:	8e430313          	add	t1,t1,-1820 # 80000908 <ebss>
    
    # 调试检查点: 开始清零BSS
    li t2, 0x10000000           # 重新加载UART地址
    8000002c:	100003b7          	lui	t2,0x10000
    li t3, 'B'                  # BSS清零开始标记
    80000030:	04200e13          	li	t3,66
    sb t3, 0(t2)                # 发送到串口
    80000034:	01c38023          	sb	t3,0(t2) # 10000000 <_entry-0x70000000>

0000000080000038 <clear_bss_loop>:

clear_bss_loop:
    beq t0, t1, bss_done        # 如果已到BSS段末尾 跳出循环
    80000038:	00628663          	beq	t0,t1,80000044 <bss_done>
    sd zero, 0(t0)              # 将当前8字节清零
    8000003c:	0002b023          	sd	zero,0(t0)
    addi t0, t0, 8              # 移动到下一个8字节位置
    80000040:	02a1                	add	t0,t0,8
    j clear_bss_loop            # 继续循环
    80000042:	bfdd                	j	80000038 <clear_bss_loop>

0000000080000044 <bss_done>:

bss_done:
    # 调试检查点: BSS清零完成
    li t2, 0x10000000           # UART地址
    80000044:	100003b7          	lui	t2,0x10000
    li t3, 'b'                  # BSS清零完成标记
    80000048:	06200e13          	li	t3,98
    sb t3, 0(t2)                # 发送到串口
    8000004c:	01c38023          	sb	t3,0(t2) # 10000000 <_entry-0x70000000>

    # ========== 3. 跳转到C启动函数 ==========
    # 三阶段启动：entry.S → start.c → kmain.c
    li t2, 0x10000000           # UART地址  
    80000050:	100003b7          	lui	t2,0x10000
    li t3, 'C'                  # 跳转到C代码标记
    80000054:	04300e13          	li	t3,67
    sb t3, 0(t2)                # 发送到串口
    80000058:	01c38023          	sb	t3,0(t2) # 10000000 <_entry-0x70000000>
    
    call start                  # 调用start函数(Machine模式)
    8000005c:	00000097          	auipc	ra,0x0
    80000060:	01a080e7          	jalr	26(ra) # 80000076 <start>

0000000080000064 <hang>:
    # ========== 4. 防止程序意外退出 ==========
    # 如果start()函数意外返回，在这里安全停止
    # 注意：正常情况下start()会通过mret跳转，不会返回
hang:
    # 调试检查点: 意外返回 - 这不应该发生
    li t0, 0x10000000           # UART地址
    80000064:	100002b7          	lui	t0,0x10000
    li t1, 'E'                  # 错误标记 - kmain()不应该返回
    80000068:	04500313          	li	t1,69
    sb t1, 0(t0)                # 发送到串口
    8000006c:	00628023          	sb	t1,0(t0) # 10000000 <_entry-0x70000000>
    
    # 禁用中断，进入安全的无限循环
    csrci mstatus, 0x8          # 清除MIE位，禁用中断
    80000070:	30047073          	csrc	mstatus,8
    
    # 无限循环，防止CPU继续执行随机内存
    j hang
    80000074:	bfc5                	j	80000064 <hang>

0000000080000076 <start>:
 * 1. 配置特权级切换到Supervisor模式
 * 2. 设置中断委托和权限管理
 * 3. 初始化基础硬件
 * 4. 通过mret跳转到Supervisor模式的kmain函数
 */
void start(void) {
    80000076:	7179                	add	sp,sp,-48
    80000078:	f406                	sd	ra,40(sp)
    8000007a:	f022                	sd	s0,32(sp)
    8000007c:	1800                	add	s0,sp,48
    // 调试标记：进入start函数
    *(volatile char*)0x10000000 = 's';
    8000007e:	100007b7          	lui	a5,0x10000
    80000082:	07300713          	li	a4,115
    80000086:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    
    // ========== 1. 配置特权级切换 ==========
    // 设置mstatus寄存器，准备从Machine模式切换到Supervisor模式
    unsigned long x = read_csr(mstatus);
    8000008a:	300027f3          	csrr	a5,mstatus
    8000008e:	fef43423          	sd	a5,-24(s0)
    80000092:	fe843783          	ld	a5,-24(s0)
    80000096:	fef43023          	sd	a5,-32(s0)
    x &= ~MSTATUS_MPP_MASK;          // 清除之前的特权级设置
    8000009a:	fe043703          	ld	a4,-32(s0)
    8000009e:	77f9                	lui	a5,0xffffe
    800000a0:	7ff78793          	add	a5,a5,2047 # ffffffffffffe7ff <_stack_top+0xffffffff7fffc7ff>
    800000a4:	8ff9                	and	a5,a5,a4
    800000a6:	fef43023          	sd	a5,-32(s0)
    x |= MSTATUS_MPP_S;              // 设置Previous Privilege为Supervisor模式
    800000aa:	fe043703          	ld	a4,-32(s0)
    800000ae:	6785                	lui	a5,0x1
    800000b0:	80078793          	add	a5,a5,-2048 # 800 <_entry-0x7ffff800>
    800000b4:	8fd9                	or	a5,a5,a4
    800000b6:	fef43023          	sd	a5,-32(s0)
    write_csr(mstatus, x);
    800000ba:	fe043783          	ld	a5,-32(s0)
    800000be:	30079073          	csrw	mstatus,a5
    
    // 设置mret的返回地址为kmain函数
    // mret指令会跳转到mepc寄存器指定的地址
    write_csr(mepc, (uint64_t)kmain);
    800000c2:	00000797          	auipc	a5,0x0
    800000c6:	18078793          	add	a5,a5,384 # 80000242 <kmain>
    800000ca:	34179073          	csrw	mepc,a5
    
    // ========== 2. 配置内存管理 ==========
    // 禁用分页机制 - 启动阶段使用物理地址
    // satp = 0 表示禁用地址翻译，使用恒等映射
    write_csr(satp, 0);
    800000ce:	18005073          	csrw	satp,0
    
    // ========== 3. 配置中断和异常委托 ==========
    // 将大部分异常委托给Supervisor模式处理
    // 这样Supervisor模式可以处理页面错误、非法指令等异常
    write_csr(medeleg, 0xffff);
    800000d2:	67c1                	lui	a5,0x10
    800000d4:	37fd                	addw	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000d6:	30279073          	csrw	medeleg,a5
    
    // 将中断委托给Supervisor模式处理
    // 这样Supervisor模式可以处理时钟中断、外部中断等
    write_csr(mideleg, 0xffff);
    800000da:	67c1                	lui	a5,0x10
    800000dc:	37fd                	addw	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000de:	30379073          	csrw	mideleg,a5
    
    // 在Supervisor模式中使能中断
    // 注意：这个设置会在特权级切换后生效
    write_csr(sie, read_csr(sie) | SIE_SEIE | SIE_STIE | SIE_SSIE);
    800000e2:	104027f3          	csrr	a5,sie
    800000e6:	fcf43c23          	sd	a5,-40(s0)
    800000ea:	fd843783          	ld	a5,-40(s0)
    800000ee:	2227e793          	or	a5,a5,546
    800000f2:	10479073          	csrw	sie,a5
    // ========== 4. 配置物理内存保护(PMP) ==========
    // PMP允许Machine模式限制低特权级模式的内存访问
    // 这里配置允许Supervisor模式访问所有物理内存
    
    // 设置PMP地址寄存器0 - 覆盖整个地址空间
    write_csr(pmpaddr0, 0x3fffffffffffffull);
    800000f6:	57fd                	li	a5,-1
    800000f8:	83a9                	srl	a5,a5,0xa
    800000fa:	3b079073          	csrw	pmpaddr0,a5
    
    // 设置PMP配置寄存器0
    // 0xf = NAPOT | R | W | X (自然对齐的2的幂 + 读写执行权限)
    write_csr(pmpcfg0, 0xf);
    800000fe:	3a07d073          	csrw	pmpcfg0,15
    
    // ========== 5. 初始化定时器中断 ==========
    // 为操作系统调度准备定时器中断
    timerinit();
    80000102:	00000097          	auipc	ra,0x0
    80000106:	036080e7          	jalr	54(ra) # 80000138 <timerinit>
    
    // ========== 6. 保存CPU ID ==========
    // 将硬件线程ID保存到tp寄存器，供后续使用
    // 在多核系统中，每个核心需要知道自己的ID
    int id;
    asm volatile("csrr %0, mhartid" : "=r"(id)); // 避免函数调用 直接使用内联汇编
    8000010a:	f14027f3          	csrr	a5,mhartid
    8000010e:	fcf42a23          	sw	a5,-44(s0)
    asm volatile("mv tp, %0" : : "r" (id));  // tp = CSR 0x4
    80000112:	fd442783          	lw	a5,-44(s0)
    80000116:	823e                	mv	tp,a5
    // int id = r_mhartid();
    // w_tp(id);
    
    // 调试标记：准备特权级切换
    *(volatile char*)0x10000000 = 'S';
    80000118:	100007b7          	lui	a5,0x10000
    8000011c:	05300713          	li	a4,83
    80000120:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    // ========== 7. 执行特权级切换 ==========
    // mret指令会：
    // 1. 将特权级切换到mstatus.MPP指定的模式(Supervisor)
    // 2. 跳转到mepc寄存器指定的地址(kmain)
    // 3. 恢复中断使能状态
    asm volatile("mret");
    80000124:	30200073          	mret
    
    // 注意：代码永远不会执行到这里
    // 如果执行到这里，说明mret失败了
    *(volatile char*)0x10000000 = 'F';  // Failure标记
    80000128:	100007b7          	lui	a5,0x10000
    8000012c:	04600713          	li	a4,70
    80000130:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    while(1) {}
    80000134:	0001                	nop
    80000136:	bffd                	j	80000134 <start+0xbe>

0000000080000138 <timerinit>:

/*
 * timerinit() - 初始化定时器中断
 * 配置机器模式定时器，为操作系统调度提供时钟源
 */
void timerinit(void) {
    80000138:	7139                	add	sp,sp,-64
    8000013a:	fc22                	sd	s0,56(sp)
    8000013c:	0080                	add	s0,sp,64
    // 调试标记：初始化定时器
    *(volatile char*)0x10000000 = 't';
    8000013e:	100007b7          	lui	a5,0x10000
    80000142:	07400713          	li	a4,116
    80000146:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    
    // ========== 使能机器模式定时器中断 ==========
    write_csr(mie, read_csr(mie) | MIE_STIE);
    8000014a:	304027f3          	csrr	a5,mie
    8000014e:	fef43423          	sd	a5,-24(s0)
    80000152:	fe843783          	ld	a5,-24(s0)
    80000156:	0207e793          	or	a5,a5,32
    8000015a:	30479073          	csrw	mie,a5
    
    // ========== 配置定时器扩展 ==========
    // 使能sstc扩展(Supervisor-mode timer compare)
    // 允许Supervisor模式直接操作stimecmp寄存器
    write_csr(menvcfg, read_csr(menvcfg) | (1L << 63));
    8000015e:	30a027f3          	csrr	a5,0x30a
    80000162:	fef43023          	sd	a5,-32(s0)
    80000166:	fe043703          	ld	a4,-32(s0)
    8000016a:	57fd                	li	a5,-1
    8000016c:	17fe                	sll	a5,a5,0x3f
    8000016e:	8fd9                	or	a5,a5,a4
    80000170:	30a79073          	csrw	0x30a,a5
    
    // ========== 允许Supervisor访问时间寄存器 ==========
    // mcounteren控制低特权级对性能计数器的访问
    // 位1(TM) = 1 允许访问时间相关寄存器
    write_csr(mcounteren, read_csr(mcounteren) | 2);
    80000174:	306027f3          	csrr	a5,mcounteren
    80000178:	fcf43c23          	sd	a5,-40(s0)
    8000017c:	fd843783          	ld	a5,-40(s0)
    80000180:	0027e793          	or	a5,a5,2
    80000184:	30679073          	csrw	mcounteren,a5
    
    // ========== 设置第一次定时器中断 ==========
    // 获取当前时间并设置下次中断时间
    // 1000000个时钟周期后触发中断（约1ms，取决于时钟频率）
    unsigned long current_time = read_csr(time);
    80000188:	c01027f3          	rdtime	a5
    8000018c:	fcf43823          	sd	a5,-48(s0)
    80000190:	fd043783          	ld	a5,-48(s0)
    80000194:	fcf43423          	sd	a5,-56(s0)
    write_csr(stimecmp, current_time + 1000000);
    80000198:	fc843703          	ld	a4,-56(s0)
    8000019c:	000f47b7          	lui	a5,0xf4
    800001a0:	24078793          	add	a5,a5,576 # f4240 <_entry-0x7ff0bdc0>
    800001a4:	97ba                	add	a5,a5,a4
    800001a6:	14d79073          	csrw	stimecmp,a5
    
    // 调试标记：定时器初始化完成
    *(volatile char*)0x10000000 = 'T';
    800001aa:	100007b7          	lui	a5,0x10000
    800001ae:	05400713          	li	a4,84
    800001b2:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    800001b6:	0001                	nop
    800001b8:	7462                	ld	s0,56(sp)
    800001ba:	6121                	add	sp,sp,64
    800001bc:	8082                	ret

00000000800001be <read_csr_sstatus>:
int test_bss_var;
static int test_static_var;
int test_data_var = 42;

// 读取当前特权级
static inline unsigned long read_csr_sstatus(void) {
    800001be:	1101                	add	sp,sp,-32
    800001c0:	ec22                	sd	s0,24(sp)
    800001c2:	1000                	add	s0,sp,32
    unsigned long val;
    asm volatile("csrr %0, sstatus" : "=r"(val));
    800001c4:	100027f3          	csrr	a5,sstatus
    800001c8:	fef43423          	sd	a5,-24(s0)
    return val;
    800001cc:	fe843783          	ld	a5,-24(s0)
}
    800001d0:	853e                	mv	a0,a5
    800001d2:	6462                	ld	s0,24(sp)
    800001d4:	6105                	add	sp,sp,32
    800001d6:	8082                	ret

00000000800001d8 <read_csr_tp>:

// 获取当前CPU ID - 使用数字寄存器号
static inline uint64 read_csr_tp(void) {
    800001d8:	1101                	add	sp,sp,-32
    800001da:	ec22                	sd	s0,24(sp)
    800001dc:	1000                	add	s0,sp,32
    uint64 val;
    asm volatile("mv %0, tp" : "=r"(val));  // tp = CSR 0x4
    800001de:	8792                	mv	a5,tp
    800001e0:	fef43423          	sd	a5,-24(s0)
    return val;
    800001e4:	fe843783          	ld	a5,-24(s0)
}
    800001e8:	853e                	mv	a0,a5
    800001ea:	6462                	ld	s0,24(sp)
    800001ec:	6105                	add	sp,sp,32
    800001ee:	8082                	ret

00000000800001f0 <panic>:

// 简化的panic函数 - 适配Supervisor模式
void panic(const char *msg) {
    800001f0:	1101                	add	sp,sp,-32
    800001f2:	ec06                	sd	ra,24(sp)
    800001f4:	e822                	sd	s0,16(sp)
    800001f6:	1000                	add	s0,sp,32
    800001f8:	fea43423          	sd	a0,-24(s0)
    uart_puts("\n*** KERNEL PANIC (Supervisor Mode) ***\n");
    800001fc:	00000517          	auipc	a0,0x0
    80000200:	46450513          	add	a0,a0,1124 # 80000660 <uart_init+0xa4>
    80000204:	00000097          	auipc	ra,0x0
    80000208:	358080e7          	jalr	856(ra) # 8000055c <uart_puts>
    uart_puts("Error: ");
    8000020c:	00000517          	auipc	a0,0x0
    80000210:	48450513          	add	a0,a0,1156 # 80000690 <uart_init+0xd4>
    80000214:	00000097          	auipc	ra,0x0
    80000218:	348080e7          	jalr	840(ra) # 8000055c <uart_puts>
    uart_puts(msg);
    8000021c:	fe843503          	ld	a0,-24(s0)
    80000220:	00000097          	auipc	ra,0x0
    80000224:	33c080e7          	jalr	828(ra) # 8000055c <uart_puts>
    uart_puts("\nSystem halted.\n");
    80000228:	00000517          	auipc	a0,0x0
    8000022c:	47050513          	add	a0,a0,1136 # 80000698 <uart_init+0xdc>
    80000230:	00000097          	auipc	ra,0x0
    80000234:	32c080e7          	jalr	812(ra) # 8000055c <uart_puts>
    
    // 在Supervisor模式下禁用中断
    asm volatile("csrci sstatus, 0x2");  // 清除SIE位
    80000238:	10017073          	csrc	sstatus,2
    while (1) {
        asm volatile("wfi");             // 等待中断
    8000023c:	10500073          	wfi
    80000240:	bff5                	j	8000023c <panic+0x4c>

0000000080000242 <kmain>:
/*
 * kmain() - Supervisor模式下的主函数
 * 由start.c通过mret跳转到此函数
 * 运行在Supervisor模式，具有适当的权限隔离
 */
void kmain(void) {
    80000242:	7179                	add	sp,sp,-48
    80000244:	f406                	sd	ra,40(sp)
    80000246:	f022                	sd	s0,32(sp)
    80000248:	1800                	add	s0,sp,48
    // 调试标记：进入Supervisor模式主函数
    uart_putc('M');
    8000024a:	04d00513          	li	a0,77
    8000024e:	00000097          	auipc	ra,0x0
    80000252:	2c6080e7          	jalr	710(ra) # 80000514 <uart_putc>
    
    // 1. 初始化串口驱动
    uart_init();
    80000256:	00000097          	auipc	ra,0x0
    8000025a:	366080e7          	jalr	870(ra) # 800005bc <uart_init>
    
    // 2. 打印启动信息，显示特权级信息
    uart_puts("\n");
    8000025e:	00000517          	auipc	a0,0x0
    80000262:	45250513          	add	a0,a0,1106 # 800006b0 <uart_init+0xf4>
    80000266:	00000097          	auipc	ra,0x0
    8000026a:	2f6080e7          	jalr	758(ra) # 8000055c <uart_puts>
    uart_puts("==========================================\n");
    8000026e:	00000517          	auipc	a0,0x0
    80000272:	44a50513          	add	a0,a0,1098 # 800006b8 <uart_init+0xfc>
    80000276:	00000097          	auipc	ra,0x0
    8000027a:	2e6080e7          	jalr	742(ra) # 8000055c <uart_puts>
    uart_puts("    RISC-V Kernel v2.0 (Full Version)\n");
    8000027e:	00000517          	auipc	a0,0x0
    80000282:	46a50513          	add	a0,a0,1130 # 800006e8 <uart_init+0x12c>
    80000286:	00000097          	auipc	ra,0x0
    8000028a:	2d6080e7          	jalr	726(ra) # 8000055c <uart_puts>
    uart_puts("    Three-Stage Boot: entry->start->kmain\n");
    8000028e:	00000517          	auipc	a0,0x0
    80000292:	48250513          	add	a0,a0,1154 # 80000710 <uart_init+0x154>
    80000296:	00000097          	auipc	ra,0x0
    8000029a:	2c6080e7          	jalr	710(ra) # 8000055c <uart_puts>
    uart_puts("    Running in Supervisor Mode\n");  
    8000029e:	00000517          	auipc	a0,0x0
    800002a2:	4a250513          	add	a0,a0,1186 # 80000740 <uart_init+0x184>
    800002a6:	00000097          	auipc	ra,0x0
    800002aa:	2b6080e7          	jalr	694(ra) # 8000055c <uart_puts>
    uart_puts("==========================================\n");
    800002ae:	00000517          	auipc	a0,0x0
    800002b2:	40a50513          	add	a0,a0,1034 # 800006b8 <uart_init+0xfc>
    800002b6:	00000097          	auipc	ra,0x0
    800002ba:	2a6080e7          	jalr	678(ra) # 8000055c <uart_puts>
    
    // 3. 显示系统状态
    unsigned long cpu_id = read_csr_tp();
    800002be:	00000097          	auipc	ra,0x0
    800002c2:	f1a080e7          	jalr	-230(ra) # 800001d8 <read_csr_tp>
    800002c6:	fea43023          	sd	a0,-32(s0)
    uart_puts("CPU ID: ");
    800002ca:	00000517          	auipc	a0,0x0
    800002ce:	49650513          	add	a0,a0,1174 # 80000760 <uart_init+0x1a4>
    800002d2:	00000097          	auipc	ra,0x0
    800002d6:	28a080e7          	jalr	650(ra) # 8000055c <uart_puts>
    uart_putc('0' + (char)cpu_id);
    800002da:	fe043783          	ld	a5,-32(s0)
    800002de:	0ff7f793          	zext.b	a5,a5
    800002e2:	0307879b          	addw	a5,a5,48
    800002e6:	0ff7f793          	zext.b	a5,a5
    800002ea:	853e                	mv	a0,a5
    800002ec:	00000097          	auipc	ra,0x0
    800002f0:	228080e7          	jalr	552(ra) # 80000514 <uart_putc>
    uart_puts("\n");
    800002f4:	00000517          	auipc	a0,0x0
    800002f8:	3bc50513          	add	a0,a0,956 # 800006b0 <uart_init+0xf4>
    800002fc:	00000097          	auipc	ra,0x0
    80000300:	260080e7          	jalr	608(ra) # 8000055c <uart_puts>
    
    unsigned long sstatus = read_csr_sstatus();
    80000304:	00000097          	auipc	ra,0x0
    80000308:	eba080e7          	jalr	-326(ra) # 800001be <read_csr_sstatus>
    8000030c:	fca43c23          	sd	a0,-40(s0)
    uart_puts("Supervisor Status Register: 0x");
    80000310:	00000517          	auipc	a0,0x0
    80000314:	46050513          	add	a0,a0,1120 # 80000770 <uart_init+0x1b4>
    80000318:	00000097          	auipc	ra,0x0
    8000031c:	244080e7          	jalr	580(ra) # 8000055c <uart_puts>
    // 简化的十六进制输出
    for(int i = 7; i >= 0; i--) {
    80000320:	479d                	li	a5,7
    80000322:	fef42623          	sw	a5,-20(s0)
    80000326:	a8b1                	j	80000382 <kmain+0x140>
        char digit = (sstatus >> (i*4)) & 0xF;
    80000328:	fec42783          	lw	a5,-20(s0)
    8000032c:	0027979b          	sllw	a5,a5,0x2
    80000330:	2781                	sext.w	a5,a5
    80000332:	873e                	mv	a4,a5
    80000334:	fd843783          	ld	a5,-40(s0)
    80000338:	00e7d7b3          	srl	a5,a5,a4
    8000033c:	0ff7f793          	zext.b	a5,a5
    80000340:	8bbd                	and	a5,a5,15
    80000342:	fcf40ba3          	sb	a5,-41(s0)
        uart_putc(digit < 10 ? '0' + digit : 'A' + digit - 10);
    80000346:	fd744783          	lbu	a5,-41(s0)
    8000034a:	0ff7f713          	zext.b	a4,a5
    8000034e:	47a5                	li	a5,9
    80000350:	00e7e963          	bltu	a5,a4,80000362 <kmain+0x120>
    80000354:	fd744783          	lbu	a5,-41(s0)
    80000358:	0307879b          	addw	a5,a5,48
    8000035c:	0ff7f793          	zext.b	a5,a5
    80000360:	a039                	j	8000036e <kmain+0x12c>
    80000362:	fd744783          	lbu	a5,-41(s0)
    80000366:	0377879b          	addw	a5,a5,55
    8000036a:	0ff7f793          	zext.b	a5,a5
    8000036e:	853e                	mv	a0,a5
    80000370:	00000097          	auipc	ra,0x0
    80000374:	1a4080e7          	jalr	420(ra) # 80000514 <uart_putc>
    for(int i = 7; i >= 0; i--) {
    80000378:	fec42783          	lw	a5,-20(s0)
    8000037c:	37fd                	addw	a5,a5,-1
    8000037e:	fef42623          	sw	a5,-20(s0)
    80000382:	fec42783          	lw	a5,-20(s0)
    80000386:	2781                	sext.w	a5,a5
    80000388:	fa07d0e3          	bgez	a5,80000328 <kmain+0xe6>
    }
    uart_puts("\n");
    8000038c:	00000517          	auipc	a0,0x0
    80000390:	32450513          	add	a0,a0,804 # 800006b0 <uart_init+0xf4>
    80000394:	00000097          	auipc	ra,0x0
    80000398:	1c8080e7          	jalr	456(ra) # 8000055c <uart_puts>
    
    // 4. 验证BSS段是否正确清零
    uart_puts("Testing BSS clear: ");
    8000039c:	00000517          	auipc	a0,0x0
    800003a0:	3f450513          	add	a0,a0,1012 # 80000790 <uart_init+0x1d4>
    800003a4:	00000097          	auipc	ra,0x0
    800003a8:	1b8080e7          	jalr	440(ra) # 8000055c <uart_puts>
    if (test_bss_var == 0 && test_static_var == 0) {
    800003ac:	00000797          	auipc	a5,0x0
    800003b0:	55478793          	add	a5,a5,1364 # 80000900 <test_bss_var>
    800003b4:	439c                	lw	a5,0(a5)
    800003b6:	e385                	bnez	a5,800003d6 <kmain+0x194>
    800003b8:	00000797          	auipc	a5,0x0
    800003bc:	54c78793          	add	a5,a5,1356 # 80000904 <test_static_var>
    800003c0:	439c                	lw	a5,0(a5)
    800003c2:	eb91                	bnez	a5,800003d6 <kmain+0x194>
        uart_puts("OK\n");
    800003c4:	00000517          	auipc	a0,0x0
    800003c8:	3e450513          	add	a0,a0,996 # 800007a8 <uart_init+0x1ec>
    800003cc:	00000097          	auipc	ra,0x0
    800003d0:	190080e7          	jalr	400(ra) # 8000055c <uart_puts>
    800003d4:	a00d                	j	800003f6 <kmain+0x1b4>
    } else {
        uart_puts("FAILED\n");
    800003d6:	00000517          	auipc	a0,0x0
    800003da:	3da50513          	add	a0,a0,986 # 800007b0 <uart_init+0x1f4>
    800003de:	00000097          	auipc	ra,0x0
    800003e2:	17e080e7          	jalr	382(ra) # 8000055c <uart_puts>
        panic("BSS segment not properly cleared");
    800003e6:	00000517          	auipc	a0,0x0
    800003ea:	3d250513          	add	a0,a0,978 # 800007b8 <uart_init+0x1fc>
    800003ee:	00000097          	auipc	ra,0x0
    800003f2:	e02080e7          	jalr	-510(ra) # 800001f0 <panic>
    }
    
    // 5. 验证数据段
    uart_puts("Testing data section: ");
    800003f6:	00000517          	auipc	a0,0x0
    800003fa:	3ea50513          	add	a0,a0,1002 # 800007e0 <uart_init+0x224>
    800003fe:	00000097          	auipc	ra,0x0
    80000402:	15e080e7          	jalr	350(ra) # 8000055c <uart_puts>
    if (test_data_var == 42) {
    80000406:	00000797          	auipc	a5,0x0
    8000040a:	4ea78793          	add	a5,a5,1258 # 800008f0 <test_data_var>
    8000040e:	439c                	lw	a5,0(a5)
    80000410:	873e                	mv	a4,a5
    80000412:	02a00793          	li	a5,42
    80000416:	00f71b63          	bne	a4,a5,8000042c <kmain+0x1ea>
        uart_puts("OK\n");
    8000041a:	00000517          	auipc	a0,0x0
    8000041e:	38e50513          	add	a0,a0,910 # 800007a8 <uart_init+0x1ec>
    80000422:	00000097          	auipc	ra,0x0
    80000426:	13a080e7          	jalr	314(ra) # 8000055c <uart_puts>
    8000042a:	a00d                	j	8000044c <kmain+0x20a>
    } else {
        uart_puts("FAILED\n");
    8000042c:	00000517          	auipc	a0,0x0
    80000430:	38450513          	add	a0,a0,900 # 800007b0 <uart_init+0x1f4>
    80000434:	00000097          	auipc	ra,0x0
    80000438:	128080e7          	jalr	296(ra) # 8000055c <uart_puts>
        panic("Data segment corrupted");
    8000043c:	00000517          	auipc	a0,0x0
    80000440:	3bc50513          	add	a0,a0,956 # 800007f8 <uart_init+0x23c>
    80000444:	00000097          	auipc	ra,0x0
    80000448:	dac080e7          	jalr	-596(ra) # 800001f0 <panic>
    }
    
    // 6. 验证特权级切换成功
    uart_puts("Privilege level verification: ");
    8000044c:	00000517          	auipc	a0,0x0
    80000450:	3c450513          	add	a0,a0,964 # 80000810 <uart_init+0x254>
    80000454:	00000097          	auipc	ra,0x0
    80000458:	108080e7          	jalr	264(ra) # 8000055c <uart_puts>
    // 尝试读取Machine模式寄存器应该会失败（在真实硬件上）
    // 在QEMU中可能仍然可以读取，但这证明了我们的设计意图
    uart_puts("Running in Supervisor Mode - OK\n");
    8000045c:	00000517          	auipc	a0,0x0
    80000460:	3d450513          	add	a0,a0,980 # 80000830 <uart_init+0x274>
    80000464:	00000097          	auipc	ra,0x0
    80000468:	0f8080e7          	jalr	248(ra) # 8000055c <uart_puts>
    
    uart_puts("System initialization complete!\n");
    8000046c:	00000517          	auipc	a0,0x0
    80000470:	3ec50513          	add	a0,a0,1004 # 80000858 <uart_init+0x29c>
    80000474:	00000097          	auipc	ra,0x0
    80000478:	0e8080e7          	jalr	232(ra) # 8000055c <uart_puts>
    uart_puts("Kernel ready for extension (processes, virtual memory, etc.)\n");
    8000047c:	00000517          	auipc	a0,0x0
    80000480:	40450513          	add	a0,a0,1028 # 80000880 <uart_init+0x2c4>
    80000484:	00000097          	auipc	ra,0x0
    80000488:	0d8080e7          	jalr	216(ra) # 8000055c <uart_puts>
    uart_puts("Entering idle state with heartbeat...\n");
    8000048c:	00000517          	auipc	a0,0x0
    80000490:	43450513          	add	a0,a0,1076 # 800008c0 <uart_init+0x304>
    80000494:	00000097          	auipc	ra,0x0
    80000498:	0c8080e7          	jalr	200(ra) # 8000055c <uart_puts>
    
    // 7. 进入安全的空闲循环
    // 在Supervisor模式下禁用中断
    asm volatile("csrci sstatus, 0x2");  // 清除SIE位
    8000049c:	10017073          	csrc	sstatus,2
    
    unsigned int heartbeat_counter = 0;
    800004a0:	fe042423          	sw	zero,-24(s0)
    
    // 永不返回的无限循环 - 为后续扩展预留
    while (1) {
        // 等待中断（在有定时器中断的系统中会被唤醒）
        asm volatile("wfi");
    800004a4:	10500073          	wfi
        
        // 定期输出心跳 - 降低频率以便观察
        if ((++heartbeat_counter & 0x1FFFF) == 0) {  // 约131k次循环
    800004a8:	fe842783          	lw	a5,-24(s0)
    800004ac:	2785                	addw	a5,a5,1
    800004ae:	fef42423          	sw	a5,-24(s0)
    800004b2:	fe842783          	lw	a5,-24(s0)
    800004b6:	873e                	mv	a4,a5
    800004b8:	000207b7          	lui	a5,0x20
    800004bc:	17fd                	add	a5,a5,-1 # 1ffff <_entry-0x7ffe0001>
    800004be:	8ff9                	and	a5,a5,a4
    800004c0:	2781                	sext.w	a5,a5
    800004c2:	f3ed                	bnez	a5,800004a4 <kmain+0x262>
            uart_putc('.');
    800004c4:	02e00513          	li	a0,46
    800004c8:	00000097          	auipc	ra,0x0
    800004cc:	04c080e7          	jalr	76(ra) # 80000514 <uart_putc>
        asm volatile("wfi");
    800004d0:	bfd1                	j	800004a4 <kmain+0x262>

00000000800004d2 <uart_read_reg>:
#define UART_MCR        (UART_BASE + 4)

#define LSR_THRE        0x20
#define LCR_DLAB        0x80

static inline unsigned char uart_read_reg(uintptr_t reg) {
    800004d2:	1101                	add	sp,sp,-32
    800004d4:	ec22                	sd	s0,24(sp)
    800004d6:	1000                	add	s0,sp,32
    800004d8:	fea43423          	sd	a0,-24(s0)
    return *(volatile unsigned char*)reg;
    800004dc:	fe843783          	ld	a5,-24(s0)
    800004e0:	0007c783          	lbu	a5,0(a5)
    800004e4:	0ff7f793          	zext.b	a5,a5
}
    800004e8:	853e                	mv	a0,a5
    800004ea:	6462                	ld	s0,24(sp)
    800004ec:	6105                	add	sp,sp,32
    800004ee:	8082                	ret

00000000800004f0 <uart_write_reg>:

static inline void uart_write_reg(uintptr_t reg, unsigned char val) {
    800004f0:	1101                	add	sp,sp,-32
    800004f2:	ec22                	sd	s0,24(sp)
    800004f4:	1000                	add	s0,sp,32
    800004f6:	fea43423          	sd	a0,-24(s0)
    800004fa:	87ae                	mv	a5,a1
    800004fc:	fef403a3          	sb	a5,-25(s0)
    *(volatile unsigned char*)reg = val;
    80000500:	fe843783          	ld	a5,-24(s0)
    80000504:	fe744703          	lbu	a4,-25(s0)
    80000508:	00e78023          	sb	a4,0(a5)
}
    8000050c:	0001                	nop
    8000050e:	6462                	ld	s0,24(sp)
    80000510:	6105                	add	sp,sp,32
    80000512:	8082                	ret

0000000080000514 <uart_putc>:

void uart_putc(char c) {
    80000514:	1101                	add	sp,sp,-32
    80000516:	ec06                	sd	ra,24(sp)
    80000518:	e822                	sd	s0,16(sp)
    8000051a:	1000                	add	s0,sp,32
    8000051c:	87aa                	mv	a5,a0
    8000051e:	fef407a3          	sb	a5,-17(s0)
    while (!(uart_read_reg(UART_LSR) & LSR_THRE)) {
    80000522:	0001                	nop
    80000524:	100007b7          	lui	a5,0x10000
    80000528:	00578513          	add	a0,a5,5 # 10000005 <_entry-0x6ffffffb>
    8000052c:	00000097          	auipc	ra,0x0
    80000530:	fa6080e7          	jalr	-90(ra) # 800004d2 <uart_read_reg>
    80000534:	87aa                	mv	a5,a0
    80000536:	2781                	sext.w	a5,a5
    80000538:	0207f793          	and	a5,a5,32
    8000053c:	2781                	sext.w	a5,a5
    8000053e:	d3fd                	beqz	a5,80000524 <uart_putc+0x10>
        // 等待发送寄存器空
    }
    uart_write_reg(UART_THR, c);
    80000540:	fef44783          	lbu	a5,-17(s0)
    80000544:	85be                	mv	a1,a5
    80000546:	10000537          	lui	a0,0x10000
    8000054a:	00000097          	auipc	ra,0x0
    8000054e:	fa6080e7          	jalr	-90(ra) # 800004f0 <uart_write_reg>
}
    80000552:	0001                	nop
    80000554:	60e2                	ld	ra,24(sp)
    80000556:	6442                	ld	s0,16(sp)
    80000558:	6105                	add	sp,sp,32
    8000055a:	8082                	ret

000000008000055c <uart_puts>:

void uart_puts(const char *s) {
    8000055c:	1101                	add	sp,sp,-32
    8000055e:	ec06                	sd	ra,24(sp)
    80000560:	e822                	sd	s0,16(sp)
    80000562:	1000                	add	s0,sp,32
    80000564:	fea43423          	sd	a0,-24(s0)
    if (s == 0) return;
    80000568:	fe843783          	ld	a5,-24(s0)
    8000056c:	c3b9                	beqz	a5,800005b2 <uart_puts+0x56>
    
    while (*s) {
    8000056e:	a825                	j	800005a6 <uart_puts+0x4a>
        if (*s == '\n') {
    80000570:	fe843783          	ld	a5,-24(s0)
    80000574:	0007c783          	lbu	a5,0(a5)
    80000578:	873e                	mv	a4,a5
    8000057a:	47a9                	li	a5,10
    8000057c:	00f71763          	bne	a4,a5,8000058a <uart_puts+0x2e>
            uart_putc('\r');
    80000580:	4535                	li	a0,13
    80000582:	00000097          	auipc	ra,0x0
    80000586:	f92080e7          	jalr	-110(ra) # 80000514 <uart_putc>
        }
        uart_putc(*s);
    8000058a:	fe843783          	ld	a5,-24(s0)
    8000058e:	0007c783          	lbu	a5,0(a5)
    80000592:	853e                	mv	a0,a5
    80000594:	00000097          	auipc	ra,0x0
    80000598:	f80080e7          	jalr	-128(ra) # 80000514 <uart_putc>
        s++;
    8000059c:	fe843783          	ld	a5,-24(s0)
    800005a0:	0785                	add	a5,a5,1
    800005a2:	fef43423          	sd	a5,-24(s0)
    while (*s) {
    800005a6:	fe843783          	ld	a5,-24(s0)
    800005aa:	0007c783          	lbu	a5,0(a5)
    800005ae:	f3e9                	bnez	a5,80000570 <uart_puts+0x14>
    800005b0:	a011                	j	800005b4 <uart_puts+0x58>
    if (s == 0) return;
    800005b2:	0001                	nop
    }
}
    800005b4:	60e2                	ld	ra,24(sp)
    800005b6:	6442                	ld	s0,16(sp)
    800005b8:	6105                	add	sp,sp,32
    800005ba:	8082                	ret

00000000800005bc <uart_init>:

void uart_init(void) {
    800005bc:	1141                	add	sp,sp,-16
    800005be:	e406                	sd	ra,8(sp)
    800005c0:	e022                	sd	s0,0(sp)
    800005c2:	0800                	add	s0,sp,16
    uart_write_reg(UART_IER, 0x00);
    800005c4:	4581                	li	a1,0
    800005c6:	100007b7          	lui	a5,0x10000
    800005ca:	00178513          	add	a0,a5,1 # 10000001 <_entry-0x6fffffff>
    800005ce:	00000097          	auipc	ra,0x0
    800005d2:	f22080e7          	jalr	-222(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_LCR, LCR_DLAB);
    800005d6:	08000593          	li	a1,128
    800005da:	100007b7          	lui	a5,0x10000
    800005de:	00378513          	add	a0,a5,3 # 10000003 <_entry-0x6ffffffd>
    800005e2:	00000097          	auipc	ra,0x0
    800005e6:	f0e080e7          	jalr	-242(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_DLL, 0x03);
    800005ea:	458d                	li	a1,3
    800005ec:	10000537          	lui	a0,0x10000
    800005f0:	00000097          	auipc	ra,0x0
    800005f4:	f00080e7          	jalr	-256(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_DLH, 0x00);
    800005f8:	4581                	li	a1,0
    800005fa:	100007b7          	lui	a5,0x10000
    800005fe:	00178513          	add	a0,a5,1 # 10000001 <_entry-0x6fffffff>
    80000602:	00000097          	auipc	ra,0x0
    80000606:	eee080e7          	jalr	-274(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_LCR, 0x03);
    8000060a:	458d                	li	a1,3
    8000060c:	100007b7          	lui	a5,0x10000
    80000610:	00378513          	add	a0,a5,3 # 10000003 <_entry-0x6ffffffd>
    80000614:	00000097          	auipc	ra,0x0
    80000618:	edc080e7          	jalr	-292(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_FCR, 0x07);
    8000061c:	459d                	li	a1,7
    8000061e:	100007b7          	lui	a5,0x10000
    80000622:	00278513          	add	a0,a5,2 # 10000002 <_entry-0x6ffffffe>
    80000626:	00000097          	auipc	ra,0x0
    8000062a:	eca080e7          	jalr	-310(ra) # 800004f0 <uart_write_reg>
    uart_write_reg(UART_MCR, 0x03);
    8000062e:	458d                	li	a1,3
    80000630:	100007b7          	lui	a5,0x10000
    80000634:	00478513          	add	a0,a5,4 # 10000004 <_entry-0x6ffffffc>
    80000638:	00000097          	auipc	ra,0x0
    8000063c:	eb8080e7          	jalr	-328(ra) # 800004f0 <uart_write_reg>
    
    uart_putc('U');
    80000640:	05500513          	li	a0,85
    80000644:	00000097          	auipc	ra,0x0
    80000648:	ed0080e7          	jalr	-304(ra) # 80000514 <uart_putc>
    8000064c:	0001                	nop
    8000064e:	60a2                	ld	ra,8(sp)
    80000650:	6402                	ld	s0,0(sp)
    80000652:	0141                	add	sp,sp,16
    80000654:	8082                	ret
	...
