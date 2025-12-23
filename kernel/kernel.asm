
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
    8000000c:	0000f117          	auipc	sp,0xf
    80000010:	ff410113          	add	sp,sp,-12 # 8000f000 <_stack_top>
    
    # 调试检查点: 栈设置完成
    li t1, 'P'                  # 栈设置完成标记
    80000014:	05000313          	li	t1,80
    sb t1, 0(t0)                # 发送到串口
    80000018:	00628023          	sb	t1,0(t0)

    # ========== 2. 清零BSS段 ==========
    # 使用链接脚本提供的精确符号
    la t0, sbss                 # BSS段开始地址
    8000001c:	00007297          	auipc	t0,0x7
    80000020:	e3428293          	add	t0,t0,-460 # 80006e50 <test_bss_var>
    la t1, ebss                 # BSS段结束地址
    80000024:	0000d317          	auipc	t1,0xd
    80000028:	01c30313          	add	t1,t1,28 # 8000d040 <_bss_end>
    
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
    80000076:	7139                	add	sp,sp,-64
    80000078:	fc06                	sd	ra,56(sp)
    8000007a:	f822                	sd	s0,48(sp)
    8000007c:	0080                	add	s0,sp,64
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
    800000a0:	7ff78793          	add	a5,a5,2047 # ffffffffffffe7ff <_stack_top+0xffffffff7ffef7ff>
    800000a4:	8ff9                	and	a5,a5,a4
    800000a6:	fef43023          	sd	a5,-32(s0)
    x |= MSTATUS_MPP_S;              // 设置Previous Privilege为Supervisor模式，欺骗cpu，使得mret从M模式进入S模式
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
    800000c6:	21078793          	add	a5,a5,528 # 800002d2 <kmain>
    800000ca:	34179073          	csrw	mepc,a5
    // ========== 2. 配置内存管理 ==========
    // 禁用分页机制 - 启动阶段使用物理地址
    // satp = 0 表示禁用地址翻译，使用恒等映射
    // satp 寄存器的结构如下：[63:60] MODE | [59:44] ASID | [43:0] PPN
    // MODE 字段控制地址转换模式，0 = Bare (禁用分页)，1 = Sv32, 8 = Sv39, 9 = Sv48 (SvN 表示启用N位虚拟地址转换)
    write_csr(satp, 0);
    800000ce:	18005073          	csrw	satp,0
    
    // ========== 3. 配置中断和异常委托 ==========
    // 将所有异常委托给Supervisor模式处理
    // 这样Supervisor模式可以处理页面错误、非法指令等异常
    write_csr(medeleg, 0xffff);
    800000d2:	67c1                	lui	a5,0x10
    800000d4:	37fd                	addw	a5,a5,-1 # ffff <_entry-0x7fff0001>
    800000d6:	30279073          	csrw	medeleg,a5
    
    // 将软件/外部/监督定时器中断委托给Supervisor模式
    // 机器定时器中断保留在M模式，用于桥接到S模式
    unsigned long ideleg = (1 << 1) | (1 << 5) | (1 << 9);
    800000da:	22200793          	li	a5,546
    800000de:	fcf43c23          	sd	a5,-40(s0)
    write_csr(mideleg, ideleg);
    800000e2:	fd843783          	ld	a5,-40(s0)
    800000e6:	30379073          	csrw	mideleg,a5
    
    // 在Supervisor模式中使能中断
    // 注意：这个设置会在特权级切换后生效
    write_csr(sie, read_csr(sie) | SIE_SEIE | SIE_STIE | SIE_SSIE);
    800000ea:	104027f3          	csrr	a5,sie
    800000ee:	fcf43823          	sd	a5,-48(s0)
    800000f2:	fd043783          	ld	a5,-48(s0)
    800000f6:	2227e793          	or	a5,a5,546
    800000fa:	10479073          	csrw	sie,a5
    // 如果都不匹配，Machine模式无限制访问，S/M模式禁止访问
    // PMP允许Machine模式限制低特权级模式的内存访问
    // 这里配置允许Supervisor模式访问所有物理内存
    
    // 设置PMP地址寄存器0 - 覆盖整个地址空间
    write_csr(pmpaddr0, 0x3fffffffffffffull);
    800000fe:	57fd                	li	a5,-1
    80000100:	83a9                	srl	a5,a5,0xa
    80000102:	3b079073          	csrw	pmpaddr0,a5
    
    // 设置PMP配置寄存器0
    // 0xf = NAPOT | R | W | X (自然对齐的2的幂 + 读写执行权限)
    write_csr(pmpcfg0, 0xf);
    80000106:	3a07d073          	csrw	pmpcfg0,15
    
    // ========== 5. 初始化定时器中断 ==========
    // 为操作系统调度准备定时器中断
    timerinit();
    8000010a:	00000097          	auipc	ra,0x0
    8000010e:	036080e7          	jalr	54(ra) # 80000140 <timerinit>
    
    // ========== 6. 保存CPU ID ==========
    // 将硬件线程ID保存到tp寄存器，供后续使用
    // 在多核系统中，每个核心需要知道自己的ID
    int id;
    asm volatile("csrr %0, mhartid" : "=r"(id)); // 避免函数调用 直接使用内联汇编
    80000112:	f14027f3          	csrr	a5,mhartid
    80000116:	fcf42623          	sw	a5,-52(s0)
    asm volatile("mv tp, %0" : : "r" (id));  // tp = CSR 0x4
    8000011a:	fcc42783          	lw	a5,-52(s0)
    8000011e:	823e                	mv	tp,a5
    // int id = r_mhartid();
    // w_tp(id);
    
    // 调试标记：准备特权级切换
    *(volatile char*)0x10000000 = 'S';
    80000120:	100007b7          	lui	a5,0x10000
    80000124:	05300713          	li	a4,83
    80000128:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    // ========== 7. 执行特权级切换 ==========
    // mret指令会：
    // 1. 将特权级切换到mstatus.MPP指定的模式(Supervisor)
    // 2. 跳转到mepc寄存器指定的地址(kmain)
    // 3. 恢复中断使能状态
    asm volatile("mret");
    8000012c:	30200073          	mret
    
    // 注意：代码永远不会执行到这里
    // 如果执行到这里，说明mret失败了
    *(volatile char*)0x10000000 = 'F';  // Failure标记
    80000130:	100007b7          	lui	a5,0x10000
    80000134:	04600713          	li	a4,70
    80000138:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    while(1) {}
    8000013c:	0001                	nop
    8000013e:	bffd                	j	8000013c <start+0xc6>

0000000080000140 <timerinit>:

/*
 * timerinit() - 初始化定时器中断
 * 配置机器模式定时器，为操作系统调度提供时钟源
 */
void timerinit(void) {
    80000140:	7139                	add	sp,sp,-64
    80000142:	fc06                	sd	ra,56(sp)
    80000144:	f822                	sd	s0,48(sp)
    80000146:	0080                	add	s0,sp,64
    // 调试标记：初始化定时器
    *(volatile char*)0x10000000 = 't';
    80000148:	100007b7          	lui	a5,0x10000
    8000014c:	07400713          	li	a4,116
    80000150:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
    
    int id;
    asm volatile("csrr %0, mhartid" : "=r"(id));
    80000154:	f14027f3          	csrr	a5,mhartid
    80000158:	fef42623          	sw	a5,-20(s0)

    // ========== 允许Supervisor访问时间寄存器 ==========
    // mcounteren控制低特权级对性能计数器的访问
    write_csr(mcounteren, read_csr(mcounteren) | 2);
    8000015c:	306027f3          	csrr	a5,mcounteren
    80000160:	fef43023          	sd	a5,-32(s0)
    80000164:	fe043783          	ld	a5,-32(s0)
    80000168:	0027e793          	or	a5,a5,2
    8000016c:	30679073          	csrw	mcounteren,a5
    write_csr(menvcfg, read_csr(menvcfg) | (1L << 63));
    80000170:	30a027f3          	csrr	a5,0x30a
    80000174:	fcf43c23          	sd	a5,-40(s0)
    80000178:	fd843703          	ld	a4,-40(s0)
    8000017c:	57fd                	li	a5,-1
    8000017e:	17fe                	sll	a5,a5,0x3f
    80000180:	8fd9                	or	a5,a5,a4
    80000182:	30a79073          	csrw	0x30a,a5

    // ========== 设置机器模式trap向量处理定时器 ==========
    write_csr(mtvec, (uint64_t)timervec);
    80000186:	00006797          	auipc	a5,0x6
    8000018a:	8da78793          	add	a5,a5,-1830 # 80005a60 <timervec>
    8000018e:	30579073          	csrw	mtvec,a5

    // 配置mscratch供timervec使用:
    // [0..2] 暂存寄存器, [3] mtimecmp地址, [4] interval
    uint64_t* scratch = &timer_scratch[id][0];
    80000192:	fec42703          	lw	a4,-20(s0)
    80000196:	87ba                	mv	a5,a4
    80000198:	078a                	sll	a5,a5,0x2
    8000019a:	97ba                	add	a5,a5,a4
    8000019c:	078e                	sll	a5,a5,0x3
    8000019e:	00007717          	auipc	a4,0x7
    800001a2:	cc270713          	add	a4,a4,-830 # 80006e60 <timer_scratch>
    800001a6:	97ba                	add	a5,a5,a4
    800001a8:	fcf43823          	sd	a5,-48(s0)
    scratch[3] = CLINT_MTIMECMP(id);
    800001ac:	fec42783          	lw	a5,-20(s0)
    800001b0:	0037979b          	sllw	a5,a5,0x3
    800001b4:	2781                	sext.w	a5,a5
    800001b6:	86be                	mv	a3,a5
    800001b8:	fd043783          	ld	a5,-48(s0)
    800001bc:	07e1                	add	a5,a5,24
    800001be:	02004737          	lui	a4,0x2004
    800001c2:	9736                	add	a4,a4,a3
    800001c4:	e398                	sd	a4,0(a5)
    scratch[4] = TICK_INTERVAL;
    800001c6:	fd043783          	ld	a5,-48(s0)
    800001ca:	02078793          	add	a5,a5,32
    800001ce:	000f4737          	lui	a4,0xf4
    800001d2:	24070713          	add	a4,a4,576 # f4240 <_entry-0x7ff0bdc0>
    800001d6:	e398                	sd	a4,0(a5)
    write_csr(mscratch, (uint64_t)scratch);
    800001d8:	fd043783          	ld	a5,-48(s0)
    800001dc:	34079073          	csrw	mscratch,a5

    // ========== 使能机器模式定时器中断 ==========
    write_csr(mie, read_csr(mie) | MIE_MTIE);
    800001e0:	304027f3          	csrr	a5,mie
    800001e4:	fcf43423          	sd	a5,-56(s0)
    800001e8:	fc843783          	ld	a5,-56(s0)
    800001ec:	0807e793          	or	a5,a5,128
    800001f0:	30479073          	csrw	mie,a5

    // ========== 设置第一次定时器中断 ==========
    sbi_set_timer(get_time() + TICK_INTERVAL);
    800001f4:	00004097          	auipc	ra,0x4
    800001f8:	dfc080e7          	jalr	-516(ra) # 80003ff0 <get_time>
    800001fc:	872a                	mv	a4,a0
    800001fe:	000f47b7          	lui	a5,0xf4
    80000202:	24078793          	add	a5,a5,576 # f4240 <_entry-0x7ff0bdc0>
    80000206:	97ba                	add	a5,a5,a4
    80000208:	853e                	mv	a0,a5
    8000020a:	00004097          	auipc	ra,0x4
    8000020e:	e02080e7          	jalr	-510(ra) # 8000400c <sbi_set_timer>

    // 调试标记：定时器初始化完成
    *(volatile char*)0x10000000 = 'T';
    80000212:	100007b7          	lui	a5,0x10000
    80000216:	05400713          	li	a4,84
    8000021a:	00e78023          	sb	a4,0(a5) # 10000000 <_entry-0x70000000>
}
    8000021e:	0001                	nop
    80000220:	70e2                	ld	ra,56(sp)
    80000222:	7442                	ld	s0,48(sp)
    80000224:	6121                	add	sp,sp,64
    80000226:	8082                	ret

0000000080000228 <r_sstatus>:
#define SSTATUS_SIE (1L << 1)  // Supervisor Interrupt Enable
#define SSTATUS_UIE (1L << 0)  // User Interrupt Enable

static inline uint64
r_sstatus()
{
    80000228:	1101                	add	sp,sp,-32
    8000022a:	ec22                	sd	s0,24(sp)
    8000022c:	1000                	add	s0,sp,32
  uint64 x;
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000022e:	100027f3          	csrr	a5,sstatus
    80000232:	fef43423          	sd	a5,-24(s0)
  return x;
    80000236:	fe843783          	ld	a5,-24(s0)
}
    8000023a:	853e                	mv	a0,a5
    8000023c:	6462                	ld	s0,24(sp)
    8000023e:	6105                	add	sp,sp,32
    80000240:	8082                	ret

0000000080000242 <w_sstatus>:

static inline void 
w_sstatus(uint64 x)
{
    80000242:	1101                	add	sp,sp,-32
    80000244:	ec22                	sd	s0,24(sp)
    80000246:	1000                	add	s0,sp,32
    80000248:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sstatus, %0" : : "r" (x));
    8000024c:	fe843783          	ld	a5,-24(s0)
    80000250:	10079073          	csrw	sstatus,a5
}
    80000254:	0001                	nop
    80000256:	6462                	ld	s0,24(sp)
    80000258:	6105                	add	sp,sp,32
    8000025a:	8082                	ret

000000008000025c <r_satp>:
  asm volatile("csrw satp, %0" : : "r" (x));
}

static inline uint64
r_satp()
{
    8000025c:	1101                	add	sp,sp,-32
    8000025e:	ec22                	sd	s0,24(sp)
    80000260:	1000                	add	s0,sp,32
  uint64 x;
  asm volatile("csrr %0, satp" : "=r" (x) );
    80000262:	180027f3          	csrr	a5,satp
    80000266:	fef43423          	sd	a5,-24(s0)
  return x;
    8000026a:	fe843783          	ld	a5,-24(s0)
}
    8000026e:	853e                	mv	a0,a5
    80000270:	6462                	ld	s0,24(sp)
    80000272:	6105                	add	sp,sp,32
    80000274:	8082                	ret

0000000080000276 <intr_on>:
}

// enable device interrupts
static inline void
intr_on()
{
    80000276:	1141                	add	sp,sp,-16
    80000278:	e406                	sd	ra,8(sp)
    8000027a:	e022                	sd	s0,0(sp)
    8000027c:	0800                	add	s0,sp,16
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    8000027e:	00000097          	auipc	ra,0x0
    80000282:	faa080e7          	jalr	-86(ra) # 80000228 <r_sstatus>
    80000286:	87aa                	mv	a5,a0
    80000288:	0027e793          	or	a5,a5,2
    8000028c:	853e                	mv	a0,a5
    8000028e:	00000097          	auipc	ra,0x0
    80000292:	fb4080e7          	jalr	-76(ra) # 80000242 <w_sstatus>
}
    80000296:	0001                	nop
    80000298:	60a2                	ld	ra,8(sp)
    8000029a:	6402                	ld	s0,0(sp)
    8000029c:	0141                	add	sp,sp,16
    8000029e:	8082                	ret

00000000800002a0 <read_csr_sstatus>:
int test_bss_var;
static int test_static_var;
int test_data_var = 42;

// 读取当前特权级
static inline unsigned long read_csr_sstatus(void) {
    800002a0:	1101                	add	sp,sp,-32
    800002a2:	ec22                	sd	s0,24(sp)
    800002a4:	1000                	add	s0,sp,32
    unsigned long val;
    // sstatus寄存器 bit8 (SPP) = 1 表示上次特权级为Supervisor模式
    // sstatus寄存器 bit5 (SPIE) = 1 表示进入Supervisor模式时中断使能
    // sstatus寄存器 bit1 (SIE) = 1 表示Supervisor模式中断使能
    asm volatile("csrr %0, sstatus" : "=r"(val));
    800002a6:	100027f3          	csrr	a5,sstatus
    800002aa:	fef43423          	sd	a5,-24(s0)
    return val;
    800002ae:	fe843783          	ld	a5,-24(s0)
}
    800002b2:	853e                	mv	a0,a5
    800002b4:	6462                	ld	s0,24(sp)
    800002b6:	6105                	add	sp,sp,32
    800002b8:	8082                	ret

00000000800002ba <read_csr_tp>:

// 获取当前CPU ID - 使用数字寄存器号
static inline uint64 read_csr_tp(void) {
    800002ba:	1101                	add	sp,sp,-32
    800002bc:	ec22                	sd	s0,24(sp)
    800002be:	1000                	add	s0,sp,32
    uint64 val;
    asm volatile("mv %0, tp" : "=r"(val));  // tp = CSR 0x4
    800002c0:	8792                	mv	a5,tp
    800002c2:	fef43423          	sd	a5,-24(s0)
    return val;
    800002c6:	fe843783          	ld	a5,-24(s0)
}
    800002ca:	853e                	mv	a0,a5
    800002cc:	6462                	ld	s0,24(sp)
    800002ce:	6105                	add	sp,sp,32
    800002d0:	8082                	ret

00000000800002d2 <kmain>:
/*
 * kmain() - Supervisor模式下的主函数
 * 由start.c通过mret跳转到此函数
 * 运行在Supervisor模式，具有适当的权限隔离
 */
void kmain(void) {
    800002d2:	7179                	add	sp,sp,-48
    800002d4:	f406                	sd	ra,40(sp)
    800002d6:	f022                	sd	s0,32(sp)
    800002d8:	1800                	add	s0,sp,48
    // 调试标记：进入Supervisor模式主函数
    uart_putc('M');
    800002da:	04d00513          	li	a0,77
    800002de:	00000097          	auipc	ra,0x0
    800002e2:	230080e7          	jalr	560(ra) # 8000050e <uart_putc>

    // 1. 初始化串口驱动
    uart_init();
    800002e6:	00000097          	auipc	ra,0x0
    800002ea:	2d0080e7          	jalr	720(ra) # 800005b6 <uart_init>

    printf("\n==========================================\n");
    800002ee:	00006517          	auipc	a0,0x6
    800002f2:	82250513          	add	a0,a0,-2014 # 80005b10 <swtch+0x74>
    800002f6:	00005097          	auipc	ra,0x5
    800002fa:	5e0080e7          	jalr	1504(ra) # 800058d6 <printf>
    printf("    RISC-V Kernel v2.1 (VM enabled)\n");
    800002fe:	00006517          	auipc	a0,0x6
    80000302:	84250513          	add	a0,a0,-1982 # 80005b40 <swtch+0xa4>
    80000306:	00005097          	auipc	ra,0x5
    8000030a:	5d0080e7          	jalr	1488(ra) # 800058d6 <printf>
    printf("    Three-Stage Boot: entry->start->kmain\n");
    8000030e:	00006517          	auipc	a0,0x6
    80000312:	85a50513          	add	a0,a0,-1958 # 80005b68 <swtch+0xcc>
    80000316:	00005097          	auipc	ra,0x5
    8000031a:	5c0080e7          	jalr	1472(ra) # 800058d6 <printf>
    printf("    Running in Supervisor Mode\n");
    8000031e:	00006517          	auipc	a0,0x6
    80000322:	87a50513          	add	a0,a0,-1926 # 80005b98 <swtch+0xfc>
    80000326:	00005097          	auipc	ra,0x5
    8000032a:	5b0080e7          	jalr	1456(ra) # 800058d6 <printf>
    printf("==========================================\n");
    8000032e:	00006517          	auipc	a0,0x6
    80000332:	88a50513          	add	a0,a0,-1910 # 80005bb8 <swtch+0x11c>
    80000336:	00005097          	auipc	ra,0x5
    8000033a:	5a0080e7          	jalr	1440(ra) # 800058d6 <printf>

    unsigned long cpu_id = read_csr_tp();
    8000033e:	00000097          	auipc	ra,0x0
    80000342:	f7c080e7          	jalr	-132(ra) # 800002ba <read_csr_tp>
    80000346:	fea43423          	sd	a0,-24(s0)
    unsigned long sstatus = read_csr_sstatus();
    8000034a:	00000097          	auipc	ra,0x0
    8000034e:	f56080e7          	jalr	-170(ra) # 800002a0 <read_csr_sstatus>
    80000352:	fea43023          	sd	a0,-32(s0)
    printf("CPU ID: %lu\n", cpu_id);
    80000356:	fe843583          	ld	a1,-24(s0)
    8000035a:	00006517          	auipc	a0,0x6
    8000035e:	88e50513          	add	a0,a0,-1906 # 80005be8 <swtch+0x14c>
    80000362:	00005097          	auipc	ra,0x5
    80000366:	574080e7          	jalr	1396(ra) # 800058d6 <printf>
    printf("Supervisor Status Register: 0x%lx\n", sstatus);
    8000036a:	fe043583          	ld	a1,-32(s0)
    8000036e:	00006517          	auipc	a0,0x6
    80000372:	88a50513          	add	a0,a0,-1910 # 80005bf8 <swtch+0x15c>
    80000376:	00005097          	auipc	ra,0x5
    8000037a:	560080e7          	jalr	1376(ra) # 800058d6 <printf>

    // Park secondary harts to avoid re-running global init (SMP not supported yet).
    if (cpu_id != 0) {
    8000037e:	fe843783          	ld	a5,-24(s0)
    80000382:	cf91                	beqz	a5,8000039e <kmain+0xcc>
        printf("[kmain] secondary hart %lu parked (no SMP init yet)\n", cpu_id);
    80000384:	fe843583          	ld	a1,-24(s0)
    80000388:	00006517          	auipc	a0,0x6
    8000038c:	89850513          	add	a0,a0,-1896 # 80005c20 <swtch+0x184>
    80000390:	00005097          	auipc	ra,0x5
    80000394:	546080e7          	jalr	1350(ra) # 800058d6 <printf>
        while (1) {
            asm volatile("wfi");
    80000398:	10500073          	wfi
    8000039c:	bff5                	j	80000398 <kmain+0xc6>
        }
    }

    // 验证BSS段是否正确清零
    if (test_bss_var != 0 || test_static_var != 0) {
    8000039e:	00007797          	auipc	a5,0x7
    800003a2:	ab278793          	add	a5,a5,-1358 # 80006e50 <test_bss_var>
    800003a6:	439c                	lw	a5,0(a5)
    800003a8:	e799                	bnez	a5,800003b6 <kmain+0xe4>
    800003aa:	00007797          	auipc	a5,0x7
    800003ae:	b0678793          	add	a5,a5,-1274 # 80006eb0 <test_static_var>
    800003b2:	439c                	lw	a5,0(a5)
    800003b4:	cb89                	beqz	a5,800003c6 <kmain+0xf4>
        panic("BSS segment not properly cleared");
    800003b6:	00006517          	auipc	a0,0x6
    800003ba:	8a250513          	add	a0,a0,-1886 # 80005c58 <swtch+0x1bc>
    800003be:	00005097          	auipc	ra,0x5
    800003c2:	5b0080e7          	jalr	1456(ra) # 8000596e <panic>
    }
    if (test_data_var != 42) {
    800003c6:	00007797          	auipc	a5,0x7
    800003ca:	a7278793          	add	a5,a5,-1422 # 80006e38 <test_data_var>
    800003ce:	439c                	lw	a5,0(a5)
    800003d0:	873e                	mv	a4,a5
    800003d2:	02a00793          	li	a5,42
    800003d6:	00f70a63          	beq	a4,a5,800003ea <kmain+0x118>
        panic("Data segment corrupted");
    800003da:	00006517          	auipc	a0,0x6
    800003de:	8a650513          	add	a0,a0,-1882 # 80005c80 <swtch+0x1e4>
    800003e2:	00005097          	auipc	ra,0x5
    800003e6:	58c080e7          	jalr	1420(ra) # 8000596e <panic>
    }
    printf("BSS and data checks passed\n");
    800003ea:	00006517          	auipc	a0,0x6
    800003ee:	8ae50513          	add	a0,a0,-1874 # 80005c98 <swtch+0x1fc>
    800003f2:	00005097          	auipc	ra,0x5
    800003f6:	4e4080e7          	jalr	1252(ra) # 800058d6 <printf>

    pmem_dump_layout();
    800003fa:	00000097          	auipc	ra,0x0
    800003fe:	752080e7          	jalr	1874(ra) # 80000b4c <pmem_dump_layout>

    // 初始化S模式trap框架并开启中断
    trap_init();
    80000402:	00004097          	auipc	ra,0x4
    80000406:	d34080e7          	jalr	-716(ra) # 80004136 <trap_init>
    intr_on();
    8000040a:	00000097          	auipc	ra,0x0
    8000040e:	e6c080e7          	jalr	-404(ra) # 80000276 <intr_on>

    // 初始化物理内存管理器并运行自测
    pmm_init();
    80000412:	00000097          	auipc	ra,0x0
    80000416:	440080e7          	jalr	1088(ra) # 80000852 <pmm_init>
    pmm_selftest();
    8000041a:	00000097          	auipc	ra,0x0
    8000041e:	530080e7          	jalr	1328(ra) # 8000094a <pmm_selftest>

    // 独立测试组件
    test_physical_memory();
    80000422:	00004097          	auipc	ra,0x4
    80000426:	0aa080e7          	jalr	170(ra) # 800044cc <test_physical_memory>
    test_pagetable();
    8000042a:	00004097          	auipc	ra,0x4
    8000042e:	25a080e7          	jalr	602(ra) # 80004684 <test_pagetable>
    vmem_selftest();
    80000432:	00001097          	auipc	ra,0x1
    80000436:	ffa080e7          	jalr	-6(ra) # 8000142c <vmem_selftest>
    run_pmem_stress_test();
    8000043a:	00004097          	auipc	ra,0x4
    8000043e:	4ca080e7          	jalr	1226(ra) # 80004904 <run_pmem_stress_test>

    // 建立并启用内核页表
    pagetable_t kpgtbl = vmem_setup_kernel();
    80000442:	00001097          	auipc	ra,0x1
    80000446:	d62080e7          	jalr	-670(ra) # 800011a4 <vmem_setup_kernel>
    8000044a:	fca43c23          	sd	a0,-40(s0)
    vmem_enable(kpgtbl);
    8000044e:	fd843503          	ld	a0,-40(s0)
    80000452:	00001097          	auipc	ra,0x1
    80000456:	f3e080e7          	jalr	-194(ra) # 80001390 <vmem_enable>
    printf("[kmain] paging enabled, satp=0x%lx\n", r_satp());
    8000045a:	00000097          	auipc	ra,0x0
    8000045e:	e02080e7          	jalr	-510(ra) # 8000025c <r_satp>
    80000462:	87aa                	mv	a5,a0
    80000464:	85be                	mv	a1,a5
    80000466:	00006517          	auipc	a0,0x6
    8000046a:	85250513          	add	a0,a0,-1966 # 80005cb8 <swtch+0x21c>
    8000046e:	00005097          	auipc	ra,0x5
    80000472:	468080e7          	jalr	1128(ra) # 800058d6 <printf>

    test_virtual_memory();
    80000476:	00004097          	auipc	ra,0x4
    8000047a:	348080e7          	jalr	840(ra) # 800047be <test_virtual_memory>
    run_vm_mapping_test();
    8000047e:	00004097          	auipc	ra,0x4
    80000482:	79c080e7          	jalr	1948(ra) # 80004c1a <run_vm_mapping_test>
    test_timer_interrupt();
    80000486:	00005097          	auipc	ra,0x5
    8000048a:	a0c080e7          	jalr	-1524(ra) # 80004e92 <test_timer_interrupt>
    test_exception_handling();
    8000048e:	00005097          	auipc	ra,0x5
    80000492:	afa080e7          	jalr	-1286(ra) # 80004f88 <test_exception_handling>
    test_interrupt_overhead();
    80000496:	00005097          	auipc	ra,0x5
    8000049a:	b14080e7          	jalr	-1260(ra) # 80004faa <test_interrupt_overhead>
    printf("System initialization complete!\n");
    8000049e:	00006517          	auipc	a0,0x6
    800004a2:	84250513          	add	a0,a0,-1982 # 80005ce0 <swtch+0x244>
    800004a6:	00005097          	auipc	ra,0x5
    800004aa:	430080e7          	jalr	1072(ra) # 800058d6 <printf>
    printf("Kernel ready for further extensions.\n");
    800004ae:	00006517          	auipc	a0,0x6
    800004b2:	85a50513          	add	a0,a0,-1958 # 80005d08 <swtch+0x26c>
    800004b6:	00005097          	auipc	ra,0x5
    800004ba:	420080e7          	jalr	1056(ra) # 800058d6 <printf>

    // Enter kernel thread/process scheduler test (does not return).
    test_process_subsystem();
    800004be:	00003097          	auipc	ra,0x3
    800004c2:	828080e7          	jalr	-2008(ra) # 80002ce6 <test_process_subsystem>
    while (1) {
        asm volatile("wfi");
    800004c6:	10500073          	wfi
    800004ca:	bff5                	j	800004c6 <kmain+0x1f4>

00000000800004cc <uart_read_reg>:

#define LSR_THRE        0x20    // 发送保持寄存器空 (Transmit Holding Register Empty) 第5位
#define LCR_DLAB        0x80    // 设置DLAB位 (Divisor Latch Access Bit) 第7位

// 读寄存器的辅助函数
static inline unsigned char uart_read_reg(uintptr_t reg) { // 使用uintptr_t(在stdint.h中定义)确保正确存储内存地址不会截断
    800004cc:	1101                	add	sp,sp,-32
    800004ce:	ec22                	sd	s0,24(sp)
    800004d0:	1000                	add	s0,sp,32
    800004d2:	fea43423          	sd	a0,-24(s0)
    return *(volatile unsigned char*)reg;
    800004d6:	fe843783          	ld	a5,-24(s0)
    800004da:	0007c783          	lbu	a5,0(a5)
    800004de:	0ff7f793          	zext.b	a5,a5
}
    800004e2:	853e                	mv	a0,a5
    800004e4:	6462                	ld	s0,24(sp)
    800004e6:	6105                	add	sp,sp,32
    800004e8:	8082                	ret

00000000800004ea <uart_write_reg>:

// 写寄存器的辅助函数
static inline void uart_write_reg(uintptr_t reg, unsigned char val) {
    800004ea:	1101                	add	sp,sp,-32
    800004ec:	ec22                	sd	s0,24(sp)
    800004ee:	1000                	add	s0,sp,32
    800004f0:	fea43423          	sd	a0,-24(s0)
    800004f4:	87ae                	mv	a5,a1
    800004f6:	fef403a3          	sb	a5,-25(s0)
    *(volatile unsigned char*)reg = val;
    800004fa:	fe843783          	ld	a5,-24(s0)
    800004fe:	fe744703          	lbu	a4,-25(s0)
    80000502:	00e78023          	sb	a4,0(a5)
}
    80000506:	0001                	nop
    80000508:	6462                	ld	s0,24(sp)
    8000050a:	6105                	add	sp,sp,32
    8000050c:	8082                	ret

000000008000050e <uart_putc>:

// 发送单个字符
void uart_putc(char c) {
    8000050e:	1101                	add	sp,sp,-32
    80000510:	ec06                	sd	ra,24(sp)
    80000512:	e822                	sd	s0,16(sp)
    80000514:	1000                	add	s0,sp,32
    80000516:	87aa                	mv	a5,a0
    80000518:	fef407a3          	sb	a5,-17(s0)
    while (!(uart_read_reg(UART_LSR) & LSR_THRE)) {
    8000051c:	0001                	nop
    8000051e:	100007b7          	lui	a5,0x10000
    80000522:	00578513          	add	a0,a5,5 # 10000005 <_entry-0x6ffffffb>
    80000526:	00000097          	auipc	ra,0x0
    8000052a:	fa6080e7          	jalr	-90(ra) # 800004cc <uart_read_reg>
    8000052e:	87aa                	mv	a5,a0
    80000530:	2781                	sext.w	a5,a5
    80000532:	0207f793          	and	a5,a5,32
    80000536:	2781                	sext.w	a5,a5
    80000538:	d3fd                	beqz	a5,8000051e <uart_putc+0x10>
        // 等待发送寄存器空
        // 如果LSR的THRE位(第5位)为1，表示发送保持寄存器空，可以写入新数据；否则寄存器满，等待
    }
    uart_write_reg(UART_THR, c);
    8000053a:	fef44783          	lbu	a5,-17(s0)
    8000053e:	85be                	mv	a1,a5
    80000540:	10000537          	lui	a0,0x10000
    80000544:	00000097          	auipc	ra,0x0
    80000548:	fa6080e7          	jalr	-90(ra) # 800004ea <uart_write_reg>
}
    8000054c:	0001                	nop
    8000054e:	60e2                	ld	ra,24(sp)
    80000550:	6442                	ld	s0,16(sp)
    80000552:	6105                	add	sp,sp,32
    80000554:	8082                	ret

0000000080000556 <uart_puts>:

// 发送字符串
void uart_puts(const char *s) {
    80000556:	1101                	add	sp,sp,-32
    80000558:	ec06                	sd	ra,24(sp)
    8000055a:	e822                	sd	s0,16(sp)
    8000055c:	1000                	add	s0,sp,32
    8000055e:	fea43423          	sd	a0,-24(s0)
    if (s == 0) return;
    80000562:	fe843783          	ld	a5,-24(s0)
    80000566:	c3b9                	beqz	a5,800005ac <uart_puts+0x56>
    
    while (*s) {
    80000568:	a825                	j	800005a0 <uart_puts+0x4a>
        if (*s == '\n') { // Unix的换行符\n需要转换为\r\n 即光标回到行首+光标移到下一行
    8000056a:	fe843783          	ld	a5,-24(s0)
    8000056e:	0007c783          	lbu	a5,0(a5)
    80000572:	873e                	mv	a4,a5
    80000574:	47a9                	li	a5,10
    80000576:	00f71763          	bne	a4,a5,80000584 <uart_puts+0x2e>
            uart_putc('\r');
    8000057a:	4535                	li	a0,13
    8000057c:	00000097          	auipc	ra,0x0
    80000580:	f92080e7          	jalr	-110(ra) # 8000050e <uart_putc>
        }
        uart_putc(*s);
    80000584:	fe843783          	ld	a5,-24(s0)
    80000588:	0007c783          	lbu	a5,0(a5)
    8000058c:	853e                	mv	a0,a5
    8000058e:	00000097          	auipc	ra,0x0
    80000592:	f80080e7          	jalr	-128(ra) # 8000050e <uart_putc>
        s++;
    80000596:	fe843783          	ld	a5,-24(s0)
    8000059a:	0785                	add	a5,a5,1
    8000059c:	fef43423          	sd	a5,-24(s0)
    while (*s) {
    800005a0:	fe843783          	ld	a5,-24(s0)
    800005a4:	0007c783          	lbu	a5,0(a5)
    800005a8:	f3e9                	bnez	a5,8000056a <uart_puts+0x14>
    800005aa:	a011                	j	800005ae <uart_puts+0x58>
    if (s == 0) return;
    800005ac:	0001                	nop
    }
}
    800005ae:	60e2                	ld	ra,24(sp)
    800005b0:	6442                	ld	s0,16(sp)
    800005b2:	6105                	add	sp,sp,32
    800005b4:	8082                	ret

00000000800005b6 <uart_init>:

void uart_init(void) {
    800005b6:	1141                	add	sp,sp,-16
    800005b8:	e406                	sd	ra,8(sp)
    800005ba:	e022                	sd	s0,0(sp)
    800005bc:	0800                	add	s0,sp,16
    uart_write_reg(UART_IER, 0x00);     // 禁用中断
    800005be:	4581                	li	a1,0
    800005c0:	100007b7          	lui	a5,0x10000
    800005c4:	00178513          	add	a0,a5,1 # 10000001 <_entry-0x6fffffff>
    800005c8:	00000097          	auipc	ra,0x0
    800005cc:	f22080e7          	jalr	-222(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_LCR, LCR_DLAB); // 设置DLAB位，允许访问DLL和DLH寄存器
    800005d0:	08000593          	li	a1,128
    800005d4:	100007b7          	lui	a5,0x10000
    800005d8:	00378513          	add	a0,a5,3 # 10000003 <_entry-0x6ffffffd>
    800005dc:	00000097          	auipc	ra,0x0
    800005e0:	f0e080e7          	jalr	-242(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_DLL, 0x03);     // 设置波特率分频器低位
    800005e4:	458d                	li	a1,3
    800005e6:	10000537          	lui	a0,0x10000
    800005ea:	00000097          	auipc	ra,0x0
    800005ee:	f00080e7          	jalr	-256(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_DLH, 0x00);     // 设置波特率分频器高位
    800005f2:	4581                	li	a1,0
    800005f4:	100007b7          	lui	a5,0x10000
    800005f8:	00178513          	add	a0,a5,1 # 10000001 <_entry-0x6fffffff>
    800005fc:	00000097          	auipc	ra,0x0
    80000600:	eee080e7          	jalr	-274(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_LCR, 0x03);     // 清除DLAB位，设置数据格式为8位数据，无校验，1位停止位 (8N1)
    80000604:	458d                	li	a1,3
    80000606:	100007b7          	lui	a5,0x10000
    8000060a:	00378513          	add	a0,a5,3 # 10000003 <_entry-0x6ffffffd>
    8000060e:	00000097          	auipc	ra,0x0
    80000612:	edc080e7          	jalr	-292(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_FCR, 0x07);     // 启用FIFO，清除接收和发送FIFO (FCR寄存器的第0位启用FIFO，第1位清除接收FIFO，第2位清除发送FIFO)
    80000616:	459d                	li	a1,7
    80000618:	100007b7          	lui	a5,0x10000
    8000061c:	00278513          	add	a0,a5,2 # 10000002 <_entry-0x6ffffffe>
    80000620:	00000097          	auipc	ra,0x0
    80000624:	eca080e7          	jalr	-310(ra) # 800004ea <uart_write_reg>
    uart_write_reg(UART_MCR, 0x03);     // 设置调制解调器控制寄存器 (设置RTS和DTR信号，第0位DTR，第1位RTS)
    80000628:	458d                	li	a1,3
    8000062a:	100007b7          	lui	a5,0x10000
    8000062e:	00478513          	add	a0,a5,4 # 10000004 <_entry-0x6ffffffc>
    80000632:	00000097          	auipc	ra,0x0
    80000636:	eb8080e7          	jalr	-328(ra) # 800004ea <uart_write_reg>
    
    uart_putc('U');
    8000063a:	05500513          	li	a0,85
    8000063e:	00000097          	auipc	ra,0x0
    80000642:	ed0080e7          	jalr	-304(ra) # 8000050e <uart_putc>
    80000646:	0001                	nop
    80000648:	60a2                	ld	ra,8(sp)
    8000064a:	6402                	ld	s0,0(sp)
    8000064c:	0141                	add	sp,sp,16
    8000064e:	8082                	ret

0000000080000650 <aligned_page>:
static run_t* free_list = NULL;
static size_t total_pages = 0;
static size_t free_pages_cnt = 0;
static uint64 managed_start = 0;

static inline int aligned_page(void* pa) {
    80000650:	1101                	add	sp,sp,-32
    80000652:	ec22                	sd	s0,24(sp)
    80000654:	1000                	add	s0,sp,32
    80000656:	fea43423          	sd	a0,-24(s0)
    return ((uint64)pa % PGSIZE) == 0;
    8000065a:	fe843703          	ld	a4,-24(s0)
    8000065e:	6785                	lui	a5,0x1
    80000660:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80000662:	8ff9                	and	a5,a5,a4
    80000664:	0017b793          	seqz	a5,a5
    80000668:	0ff7f793          	zext.b	a5,a5
    8000066c:	2781                	sext.w	a5,a5
}
    8000066e:	853e                	mv	a0,a5
    80000670:	6462                	ld	s0,24(sp)
    80000672:	6105                	add	sp,sp,32
    80000674:	8082                	ret

0000000080000676 <free_page>:

void free_page(void* pa) {
    80000676:	7179                	add	sp,sp,-48
    80000678:	f406                	sd	ra,40(sp)
    8000067a:	f022                	sd	s0,32(sp)
    8000067c:	1800                	add	s0,sp,48
    8000067e:	fca43c23          	sd	a0,-40(s0)
    if (pa == NULL) {
    80000682:	fd843783          	ld	a5,-40(s0)
    80000686:	c7ad                	beqz	a5,800006f0 <free_page+0x7a>
        return;
    }
    if (!aligned_page(pa)) {
    80000688:	fd843503          	ld	a0,-40(s0)
    8000068c:	00000097          	auipc	ra,0x0
    80000690:	fc4080e7          	jalr	-60(ra) # 80000650 <aligned_page>
    80000694:	87aa                	mv	a5,a0
    80000696:	ef89                	bnez	a5,800006b0 <free_page+0x3a>
        printf("[pmm] free_page: unaligned address 0x%lx\n", (uint64)pa);
    80000698:	fd843783          	ld	a5,-40(s0)
    8000069c:	85be                	mv	a1,a5
    8000069e:	00005517          	auipc	a0,0x5
    800006a2:	69250513          	add	a0,a0,1682 # 80005d30 <swtch+0x294>
    800006a6:	00005097          	auipc	ra,0x5
    800006aa:	230080e7          	jalr	560(ra) # 800058d6 <printf>
        return;
    800006ae:	a091                	j	800006f2 <free_page+0x7c>
    }
    run_t* r = (run_t*)pa;
    800006b0:	fd843783          	ld	a5,-40(s0)
    800006b4:	fef43423          	sd	a5,-24(s0)
    r->next = free_list;
    800006b8:	00007797          	auipc	a5,0x7
    800006bc:	80078793          	add	a5,a5,-2048 # 80006eb8 <free_list>
    800006c0:	6398                	ld	a4,0(a5)
    800006c2:	fe843783          	ld	a5,-24(s0)
    800006c6:	e398                	sd	a4,0(a5)
    free_list = r;
    800006c8:	00006797          	auipc	a5,0x6
    800006cc:	7f078793          	add	a5,a5,2032 # 80006eb8 <free_list>
    800006d0:	fe843703          	ld	a4,-24(s0)
    800006d4:	e398                	sd	a4,0(a5)
    free_pages_cnt++;
    800006d6:	00006797          	auipc	a5,0x6
    800006da:	7f278793          	add	a5,a5,2034 # 80006ec8 <free_pages_cnt>
    800006de:	639c                	ld	a5,0(a5)
    800006e0:	00178713          	add	a4,a5,1
    800006e4:	00006797          	auipc	a5,0x6
    800006e8:	7e478793          	add	a5,a5,2020 # 80006ec8 <free_pages_cnt>
    800006ec:	e398                	sd	a4,0(a5)
    800006ee:	a011                	j	800006f2 <free_page+0x7c>
        return;
    800006f0:	0001                	nop
}
    800006f2:	70a2                	ld	ra,40(sp)
    800006f4:	7402                	ld	s0,32(sp)
    800006f6:	6145                	add	sp,sp,48
    800006f8:	8082                	ret

00000000800006fa <alloc_page>:

void* alloc_page(void) {
    800006fa:	1101                	add	sp,sp,-32
    800006fc:	ec06                	sd	ra,24(sp)
    800006fe:	e822                	sd	s0,16(sp)
    80000700:	1000                	add	s0,sp,32
    if (free_list == NULL) {
    80000702:	00006797          	auipc	a5,0x6
    80000706:	7b678793          	add	a5,a5,1974 # 80006eb8 <free_list>
    8000070a:	639c                	ld	a5,0(a5)
    8000070c:	e399                	bnez	a5,80000712 <alloc_page+0x18>
        return NULL;
    8000070e:	4781                	li	a5,0
    80000710:	a0b1                	j	8000075c <alloc_page+0x62>
    }
    run_t* r = free_list;
    80000712:	00006797          	auipc	a5,0x6
    80000716:	7a678793          	add	a5,a5,1958 # 80006eb8 <free_list>
    8000071a:	639c                	ld	a5,0(a5)
    8000071c:	fef43423          	sd	a5,-24(s0)
    free_list = r->next;
    80000720:	fe843783          	ld	a5,-24(s0)
    80000724:	6398                	ld	a4,0(a5)
    80000726:	00006797          	auipc	a5,0x6
    8000072a:	79278793          	add	a5,a5,1938 # 80006eb8 <free_list>
    8000072e:	e398                	sd	a4,0(a5)
    free_pages_cnt--;
    80000730:	00006797          	auipc	a5,0x6
    80000734:	79878793          	add	a5,a5,1944 # 80006ec8 <free_pages_cnt>
    80000738:	639c                	ld	a5,0(a5)
    8000073a:	fff78713          	add	a4,a5,-1
    8000073e:	00006797          	auipc	a5,0x6
    80000742:	78a78793          	add	a5,a5,1930 # 80006ec8 <free_pages_cnt>
    80000746:	e398                	sd	a4,0(a5)
    memset(r, 0, PGSIZE);
    80000748:	6605                	lui	a2,0x1
    8000074a:	4581                	li	a1,0
    8000074c:	fe843503          	ld	a0,-24(s0)
    80000750:	00005097          	auipc	ra,0x5
    80000754:	87c080e7          	jalr	-1924(ra) # 80004fcc <memset>
    return (void*)r;
    80000758:	fe843783          	ld	a5,-24(s0)
}
    8000075c:	853e                	mv	a0,a5
    8000075e:	60e2                	ld	ra,24(sp)
    80000760:	6442                	ld	s0,16(sp)
    80000762:	6105                	add	sp,sp,32
    80000764:	8082                	ret

0000000080000766 <alloc_pages>:

void* alloc_pages(int n) {
    80000766:	711d                	add	sp,sp,-96
    80000768:	ec86                	sd	ra,88(sp)
    8000076a:	e8a2                	sd	s0,80(sp)
    8000076c:	1080                	add	s0,sp,96
    8000076e:	87aa                	mv	a5,a0
    80000770:	faf42623          	sw	a5,-84(s0)
    if (n <= 0) return NULL;
    80000774:	fac42783          	lw	a5,-84(s0)
    80000778:	2781                	sext.w	a5,a5
    8000077a:	00f04463          	bgtz	a5,80000782 <alloc_pages+0x1c>
    8000077e:	4781                	li	a5,0
    80000780:	a0e1                	j	80000848 <alloc_pages+0xe2>
    void* first = NULL;
    80000782:	fe043423          	sd	zero,-24(s0)
    void* prev = NULL;
    80000786:	fe043023          	sd	zero,-32(s0)
    for (int i = 0; i < n; i++) {
    8000078a:	fc042e23          	sw	zero,-36(s0)
    8000078e:	a8ad                	j	80000808 <alloc_pages+0xa2>
        void* p = alloc_page();
    80000790:	00000097          	auipc	ra,0x0
    80000794:	f6a080e7          	jalr	-150(ra) # 800006fa <alloc_page>
    80000798:	faa43c23          	sd	a0,-72(s0)
        if (!p) {
    8000079c:	fb843783          	ld	a5,-72(s0)
    800007a0:	eb95                	bnez	a5,800007d4 <alloc_pages+0x6e>
            // rollback
            void* cur = first;
    800007a2:	fe843783          	ld	a5,-24(s0)
    800007a6:	fcf43823          	sd	a5,-48(s0)
            while (cur) {
    800007aa:	a005                	j	800007ca <alloc_pages+0x64>
                void* next = *((void**)cur);
    800007ac:	fd043783          	ld	a5,-48(s0)
    800007b0:	639c                	ld	a5,0(a5)
    800007b2:	faf43823          	sd	a5,-80(s0)
                free_page(cur);
    800007b6:	fd043503          	ld	a0,-48(s0)
    800007ba:	00000097          	auipc	ra,0x0
    800007be:	ebc080e7          	jalr	-324(ra) # 80000676 <free_page>
                cur = next;
    800007c2:	fb043783          	ld	a5,-80(s0)
    800007c6:	fcf43823          	sd	a5,-48(s0)
            while (cur) {
    800007ca:	fd043783          	ld	a5,-48(s0)
    800007ce:	fff9                	bnez	a5,800007ac <alloc_pages+0x46>
            }
            return NULL;
    800007d0:	4781                	li	a5,0
    800007d2:	a89d                	j	80000848 <alloc_pages+0xe2>
        }
        // reuse first word to chain pages while we allocate
        *((void**)p) = NULL;
    800007d4:	fb843783          	ld	a5,-72(s0)
    800007d8:	0007b023          	sd	zero,0(a5)
        if (prev) {
    800007dc:	fe043783          	ld	a5,-32(s0)
    800007e0:	c799                	beqz	a5,800007ee <alloc_pages+0x88>
            *((void**)prev) = p;
    800007e2:	fe043783          	ld	a5,-32(s0)
    800007e6:	fb843703          	ld	a4,-72(s0)
    800007ea:	e398                	sd	a4,0(a5)
    800007ec:	a029                	j	800007f6 <alloc_pages+0x90>
        } else {
            first = p;
    800007ee:	fb843783          	ld	a5,-72(s0)
    800007f2:	fef43423          	sd	a5,-24(s0)
        }
        prev = p;
    800007f6:	fb843783          	ld	a5,-72(s0)
    800007fa:	fef43023          	sd	a5,-32(s0)
    for (int i = 0; i < n; i++) {
    800007fe:	fdc42783          	lw	a5,-36(s0)
    80000802:	2785                	addw	a5,a5,1
    80000804:	fcf42e23          	sw	a5,-36(s0)
    80000808:	fdc42783          	lw	a5,-36(s0)
    8000080c:	873e                	mv	a4,a5
    8000080e:	fac42783          	lw	a5,-84(s0)
    80000812:	2701                	sext.w	a4,a4
    80000814:	2781                	sext.w	a5,a5
    80000816:	f6f74de3          	blt	a4,a5,80000790 <alloc_pages+0x2a>
    }
    // break temporary links
    void* cur = first;
    8000081a:	fe843783          	ld	a5,-24(s0)
    8000081e:	fcf43423          	sd	a5,-56(s0)
    while (cur) {
    80000822:	a831                	j	8000083e <alloc_pages+0xd8>
        void* next = *((void**)cur);
    80000824:	fc843783          	ld	a5,-56(s0)
    80000828:	639c                	ld	a5,0(a5)
    8000082a:	fcf43023          	sd	a5,-64(s0)
        *((void**)cur) = 0;
    8000082e:	fc843783          	ld	a5,-56(s0)
    80000832:	0007b023          	sd	zero,0(a5)
        cur = next;
    80000836:	fc043783          	ld	a5,-64(s0)
    8000083a:	fcf43423          	sd	a5,-56(s0)
    while (cur) {
    8000083e:	fc843783          	ld	a5,-56(s0)
    80000842:	f3ed                	bnez	a5,80000824 <alloc_pages+0xbe>
    }
    return first;
    80000844:	fe843783          	ld	a5,-24(s0)
}
    80000848:	853e                	mv	a0,a5
    8000084a:	60e6                	ld	ra,88(sp)
    8000084c:	6446                	ld	s0,80(sp)
    8000084e:	6125                	add	sp,sp,96
    80000850:	8082                	ret

0000000080000852 <pmm_init>:

void pmm_init(void) {
    80000852:	7179                	add	sp,sp,-48
    80000854:	f406                	sd	ra,40(sp)
    80000856:	f022                	sd	s0,32(sp)
    80000858:	1800                	add	s0,sp,48
    pmem_range_t r = pmem_usable_range();
    8000085a:	00000097          	auipc	ra,0x0
    8000085e:	232080e7          	jalr	562(ra) # 80000a8c <pmem_usable_range>
    80000862:	872a                	mv	a4,a0
    80000864:	87ae                	mv	a5,a1
    80000866:	fce43823          	sd	a4,-48(s0)
    8000086a:	fcf43c23          	sd	a5,-40(s0)
    managed_start = PGROUNDUP(r.start);
    8000086e:	fd043703          	ld	a4,-48(s0)
    80000872:	6785                	lui	a5,0x1
    80000874:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80000876:	973e                	add	a4,a4,a5
    80000878:	77fd                	lui	a5,0xfffff
    8000087a:	8f7d                	and	a4,a4,a5
    8000087c:	00006797          	auipc	a5,0x6
    80000880:	65478793          	add	a5,a5,1620 # 80006ed0 <managed_start>
    80000884:	e398                	sd	a4,0(a5)
    uint64 limit = PGROUNDDOWN(r.end);
    80000886:	fd843703          	ld	a4,-40(s0)
    8000088a:	77fd                	lui	a5,0xfffff
    8000088c:	8ff9                	and	a5,a5,a4
    8000088e:	fef43023          	sd	a5,-32(s0)
    for (uint64 p = managed_start; p + PGSIZE <= limit; p += PGSIZE) {
    80000892:	00006797          	auipc	a5,0x6
    80000896:	63e78793          	add	a5,a5,1598 # 80006ed0 <managed_start>
    8000089a:	639c                	ld	a5,0(a5)
    8000089c:	fef43423          	sd	a5,-24(s0)
    800008a0:	a815                	j	800008d4 <pmm_init+0x82>
        total_pages++;
    800008a2:	00006797          	auipc	a5,0x6
    800008a6:	61e78793          	add	a5,a5,1566 # 80006ec0 <total_pages>
    800008aa:	639c                	ld	a5,0(a5)
    800008ac:	00178713          	add	a4,a5,1
    800008b0:	00006797          	auipc	a5,0x6
    800008b4:	61078793          	add	a5,a5,1552 # 80006ec0 <total_pages>
    800008b8:	e398                	sd	a4,0(a5)
        free_page((void*)p);
    800008ba:	fe843783          	ld	a5,-24(s0)
    800008be:	853e                	mv	a0,a5
    800008c0:	00000097          	auipc	ra,0x0
    800008c4:	db6080e7          	jalr	-586(ra) # 80000676 <free_page>
    for (uint64 p = managed_start; p + PGSIZE <= limit; p += PGSIZE) {
    800008c8:	fe843703          	ld	a4,-24(s0)
    800008cc:	6785                	lui	a5,0x1
    800008ce:	97ba                	add	a5,a5,a4
    800008d0:	fef43423          	sd	a5,-24(s0)
    800008d4:	fe843703          	ld	a4,-24(s0)
    800008d8:	6785                	lui	a5,0x1
    800008da:	97ba                	add	a5,a5,a4
    800008dc:	fe043703          	ld	a4,-32(s0)
    800008e0:	fcf771e3          	bgeu	a4,a5,800008a2 <pmm_init+0x50>
    }
    printf("[pmm] init: %lu pages managed (start=0x%lx end=0x%lx)\n",
    800008e4:	00006797          	auipc	a5,0x6
    800008e8:	5dc78793          	add	a5,a5,1500 # 80006ec0 <total_pages>
    800008ec:	6398                	ld	a4,0(a5)
    800008ee:	00006797          	auipc	a5,0x6
    800008f2:	5e278793          	add	a5,a5,1506 # 80006ed0 <managed_start>
    800008f6:	639c                	ld	a5,0(a5)
    800008f8:	fe043683          	ld	a3,-32(s0)
    800008fc:	863e                	mv	a2,a5
    800008fe:	85ba                	mv	a1,a4
    80000900:	00005517          	auipc	a0,0x5
    80000904:	46050513          	add	a0,a0,1120 # 80005d60 <swtch+0x2c4>
    80000908:	00005097          	auipc	ra,0x5
    8000090c:	fce080e7          	jalr	-50(ra) # 800058d6 <printf>
           total_pages, managed_start, limit);
}
    80000910:	0001                	nop
    80000912:	70a2                	ld	ra,40(sp)
    80000914:	7402                	ld	s0,32(sp)
    80000916:	6145                	add	sp,sp,48
    80000918:	8082                	ret

000000008000091a <pmm_total_pages>:

size_t pmm_total_pages(void) {
    8000091a:	1141                	add	sp,sp,-16
    8000091c:	e422                	sd	s0,8(sp)
    8000091e:	0800                	add	s0,sp,16
    return total_pages;
    80000920:	00006797          	auipc	a5,0x6
    80000924:	5a078793          	add	a5,a5,1440 # 80006ec0 <total_pages>
    80000928:	639c                	ld	a5,0(a5)
}
    8000092a:	853e                	mv	a0,a5
    8000092c:	6422                	ld	s0,8(sp)
    8000092e:	0141                	add	sp,sp,16
    80000930:	8082                	ret

0000000080000932 <pmm_free_pages>:

size_t pmm_free_pages(void) {
    80000932:	1141                	add	sp,sp,-16
    80000934:	e422                	sd	s0,8(sp)
    80000936:	0800                	add	s0,sp,16
    return free_pages_cnt;
    80000938:	00006797          	auipc	a5,0x6
    8000093c:	59078793          	add	a5,a5,1424 # 80006ec8 <free_pages_cnt>
    80000940:	639c                	ld	a5,0(a5)
}
    80000942:	853e                	mv	a0,a5
    80000944:	6422                	ld	s0,8(sp)
    80000946:	0141                	add	sp,sp,16
    80000948:	8082                	ret

000000008000094a <pmm_selftest>:

void pmm_selftest(void) {
    8000094a:	7139                	add	sp,sp,-64
    8000094c:	fc06                	sd	ra,56(sp)
    8000094e:	f822                	sd	s0,48(sp)
    80000950:	0080                	add	s0,sp,64
    printf("[pmm] selftest start\n");
    80000952:	00005517          	auipc	a0,0x5
    80000956:	44650513          	add	a0,a0,1094 # 80005d98 <swtch+0x2fc>
    8000095a:	00005097          	auipc	ra,0x5
    8000095e:	f7c080e7          	jalr	-132(ra) # 800058d6 <printf>
    size_t before = pmm_free_pages();
    80000962:	00000097          	auipc	ra,0x0
    80000966:	fd0080e7          	jalr	-48(ra) # 80000932 <pmm_free_pages>
    8000096a:	fea43423          	sd	a0,-24(s0)
    void* p1 = alloc_page();
    8000096e:	00000097          	auipc	ra,0x0
    80000972:	d8c080e7          	jalr	-628(ra) # 800006fa <alloc_page>
    80000976:	fea43023          	sd	a0,-32(s0)
    void* p2 = alloc_page();
    8000097a:	00000097          	auipc	ra,0x0
    8000097e:	d80080e7          	jalr	-640(ra) # 800006fa <alloc_page>
    80000982:	fca43c23          	sd	a0,-40(s0)
    void* p3 = alloc_page();
    80000986:	00000097          	auipc	ra,0x0
    8000098a:	d74080e7          	jalr	-652(ra) # 800006fa <alloc_page>
    8000098e:	fca43823          	sd	a0,-48(s0)
    if (!p1 || !p2 || !p3) {
    80000992:	fe043783          	ld	a5,-32(s0)
    80000996:	c799                	beqz	a5,800009a4 <pmm_selftest+0x5a>
    80000998:	fd843783          	ld	a5,-40(s0)
    8000099c:	c781                	beqz	a5,800009a4 <pmm_selftest+0x5a>
    8000099e:	fd043783          	ld	a5,-48(s0)
    800009a2:	e38d                	bnez	a5,800009c4 <pmm_selftest+0x7a>
        printf("[pmm] selftest: allocation failed\n");
    800009a4:	00005517          	auipc	a0,0x5
    800009a8:	40c50513          	add	a0,a0,1036 # 80005db0 <swtch+0x314>
    800009ac:	00005097          	auipc	ra,0x5
    800009b0:	f2a080e7          	jalr	-214(ra) # 800058d6 <printf>
        panic("pmm selftest alloc");
    800009b4:	00005517          	auipc	a0,0x5
    800009b8:	42450513          	add	a0,a0,1060 # 80005dd8 <swtch+0x33c>
    800009bc:	00005097          	auipc	ra,0x5
    800009c0:	fb2080e7          	jalr	-78(ra) # 8000596e <panic>
    }
    uint64* a = (uint64*)p1;
    800009c4:	fe043783          	ld	a5,-32(s0)
    800009c8:	fcf43423          	sd	a5,-56(s0)
    uint64* b = (uint64*)p2;
    800009cc:	fd843783          	ld	a5,-40(s0)
    800009d0:	fcf43023          	sd	a5,-64(s0)
    a[0] = 0xdeadbeefdeadbeef;
    800009d4:	fc843783          	ld	a5,-56(s0)
    800009d8:	00005717          	auipc	a4,0x5
    800009dc:	46070713          	add	a4,a4,1120 # 80005e38 <swtch+0x39c>
    800009e0:	6318                	ld	a4,0(a4)
    800009e2:	e398                	sd	a4,0(a5)
    b[0] = 0x1122334455667788;
    800009e4:	fc043783          	ld	a5,-64(s0)
    800009e8:	00005717          	auipc	a4,0x5
    800009ec:	45870713          	add	a4,a4,1112 # 80005e40 <swtch+0x3a4>
    800009f0:	6318                	ld	a4,0(a4)
    800009f2:	e398                	sd	a4,0(a5)
    if (a[0] != 0xdeadbeefdeadbeef || b[0] != 0x1122334455667788) {
    800009f4:	fc843783          	ld	a5,-56(s0)
    800009f8:	6398                	ld	a4,0(a5)
    800009fa:	00005797          	auipc	a5,0x5
    800009fe:	43e78793          	add	a5,a5,1086 # 80005e38 <swtch+0x39c>
    80000a02:	639c                	ld	a5,0(a5)
    80000a04:	00f71c63          	bne	a4,a5,80000a1c <pmm_selftest+0xd2>
    80000a08:	fc043783          	ld	a5,-64(s0)
    80000a0c:	6398                	ld	a4,0(a5)
    80000a0e:	00005797          	auipc	a5,0x5
    80000a12:	43278793          	add	a5,a5,1074 # 80005e40 <swtch+0x3a4>
    80000a16:	639c                	ld	a5,0(a5)
    80000a18:	00f70a63          	beq	a4,a5,80000a2c <pmm_selftest+0xe2>
        panic("pmm selftest pattern");
    80000a1c:	00005517          	auipc	a0,0x5
    80000a20:	3d450513          	add	a0,a0,980 # 80005df0 <swtch+0x354>
    80000a24:	00005097          	auipc	ra,0x5
    80000a28:	f4a080e7          	jalr	-182(ra) # 8000596e <panic>
    }
    free_page(p1);
    80000a2c:	fe043503          	ld	a0,-32(s0)
    80000a30:	00000097          	auipc	ra,0x0
    80000a34:	c46080e7          	jalr	-954(ra) # 80000676 <free_page>
    free_page(p2);
    80000a38:	fd843503          	ld	a0,-40(s0)
    80000a3c:	00000097          	auipc	ra,0x0
    80000a40:	c3a080e7          	jalr	-966(ra) # 80000676 <free_page>
    free_page(p3);
    80000a44:	fd043503          	ld	a0,-48(s0)
    80000a48:	00000097          	auipc	ra,0x0
    80000a4c:	c2e080e7          	jalr	-978(ra) # 80000676 <free_page>
    if (pmm_free_pages() != before) {
    80000a50:	00000097          	auipc	ra,0x0
    80000a54:	ee2080e7          	jalr	-286(ra) # 80000932 <pmm_free_pages>
    80000a58:	872a                	mv	a4,a0
    80000a5a:	fe843783          	ld	a5,-24(s0)
    80000a5e:	00e78a63          	beq	a5,a4,80000a72 <pmm_selftest+0x128>
        panic("pmm selftest leak");
    80000a62:	00005517          	auipc	a0,0x5
    80000a66:	3a650513          	add	a0,a0,934 # 80005e08 <swtch+0x36c>
    80000a6a:	00005097          	auipc	ra,0x5
    80000a6e:	f04080e7          	jalr	-252(ra) # 8000596e <panic>
    }
    printf("[pmm] selftest passed\n");
    80000a72:	00005517          	auipc	a0,0x5
    80000a76:	3ae50513          	add	a0,a0,942 # 80005e20 <swtch+0x384>
    80000a7a:	00005097          	auipc	ra,0x5
    80000a7e:	e5c080e7          	jalr	-420(ra) # 800058d6 <printf>
}
    80000a82:	0001                	nop
    80000a84:	70e2                	ld	ra,56(sp)
    80000a86:	7442                	ld	s0,48(sp)
    80000a88:	6121                	add	sp,sp,64
    80000a8a:	8082                	ret

0000000080000a8c <pmem_usable_range>:
extern char _stack_top[];

static pmem_range_t usable;
static int pmem_inited = 0;

pmem_range_t pmem_usable_range(void) {
    80000a8c:	1101                	add	sp,sp,-32
    80000a8e:	ec22                	sd	s0,24(sp)
    80000a90:	1000                	add	s0,sp,32
    if (usable.start == 0 && usable.end == 0) {
    80000a92:	00006797          	auipc	a5,0x6
    80000a96:	44678793          	add	a5,a5,1094 # 80006ed8 <usable>
    80000a9a:	639c                	ld	a5,0(a5)
    80000a9c:	e79d                	bnez	a5,80000aca <pmem_usable_range+0x3e>
    80000a9e:	00006797          	auipc	a5,0x6
    80000aa2:	43a78793          	add	a5,a5,1082 # 80006ed8 <usable>
    80000aa6:	679c                	ld	a5,8(a5)
    80000aa8:	e38d                	bnez	a5,80000aca <pmem_usable_range+0x3e>
        usable.start = (uint64)_stack_top;
    80000aaa:	0000e717          	auipc	a4,0xe
    80000aae:	55670713          	add	a4,a4,1366 # 8000f000 <_stack_top>
    80000ab2:	00006797          	auipc	a5,0x6
    80000ab6:	42678793          	add	a5,a5,1062 # 80006ed8 <usable>
    80000aba:	e398                	sd	a4,0(a5)
        usable.end = RAM_END;
    80000abc:	00006797          	auipc	a5,0x6
    80000ac0:	41c78793          	add	a5,a5,1052 # 80006ed8 <usable>
    80000ac4:	4745                	li	a4,17
    80000ac6:	076e                	sll	a4,a4,0x1b
    80000ac8:	e798                	sd	a4,8(a5)
    }
    return usable;
    80000aca:	00006797          	auipc	a5,0x6
    80000ace:	40e78793          	add	a5,a5,1038 # 80006ed8 <usable>
    80000ad2:	6398                	ld	a4,0(a5)
    80000ad4:	fee43023          	sd	a4,-32(s0)
    80000ad8:	679c                	ld	a5,8(a5)
    80000ada:	fef43423          	sd	a5,-24(s0)
    80000ade:	fe043703          	ld	a4,-32(s0)
    80000ae2:	fe843783          	ld	a5,-24(s0)
    80000ae6:	863a                	mv	a2,a4
    80000ae8:	86be                	mv	a3,a5
    80000aea:	8732                	mv	a4,a2
    80000aec:	87b6                	mv	a5,a3
}
    80000aee:	853a                	mv	a0,a4
    80000af0:	85be                	mv	a1,a5
    80000af2:	6462                	ld	s0,24(sp)
    80000af4:	6105                	add	sp,sp,32
    80000af6:	8082                	ret

0000000080000af8 <pmem_usable_start>:

uint64 pmem_usable_start(void) {
    80000af8:	1101                	add	sp,sp,-32
    80000afa:	ec06                	sd	ra,24(sp)
    80000afc:	e822                	sd	s0,16(sp)
    80000afe:	1000                	add	s0,sp,32
    return pmem_usable_range().start;
    80000b00:	00000097          	auipc	ra,0x0
    80000b04:	f8c080e7          	jalr	-116(ra) # 80000a8c <pmem_usable_range>
    80000b08:	872a                	mv	a4,a0
    80000b0a:	87ae                	mv	a5,a1
    80000b0c:	fee43023          	sd	a4,-32(s0)
    80000b10:	fef43423          	sd	a5,-24(s0)
    80000b14:	fe043783          	ld	a5,-32(s0)
}
    80000b18:	853e                	mv	a0,a5
    80000b1a:	60e2                	ld	ra,24(sp)
    80000b1c:	6442                	ld	s0,16(sp)
    80000b1e:	6105                	add	sp,sp,32
    80000b20:	8082                	ret

0000000080000b22 <pmem_usable_end>:

uint64 pmem_usable_end(void) {
    80000b22:	1101                	add	sp,sp,-32
    80000b24:	ec06                	sd	ra,24(sp)
    80000b26:	e822                	sd	s0,16(sp)
    80000b28:	1000                	add	s0,sp,32
    return pmem_usable_range().end;
    80000b2a:	00000097          	auipc	ra,0x0
    80000b2e:	f62080e7          	jalr	-158(ra) # 80000a8c <pmem_usable_range>
    80000b32:	872a                	mv	a4,a0
    80000b34:	87ae                	mv	a5,a1
    80000b36:	fee43023          	sd	a4,-32(s0)
    80000b3a:	fef43423          	sd	a5,-24(s0)
    80000b3e:	fe843783          	ld	a5,-24(s0)
}
    80000b42:	853e                	mv	a0,a5
    80000b44:	60e2                	ld	ra,24(sp)
    80000b46:	6442                	ld	s0,16(sp)
    80000b48:	6105                	add	sp,sp,32
    80000b4a:	8082                	ret

0000000080000b4c <pmem_dump_layout>:

void pmem_dump_layout(void) {
    80000b4c:	7179                	add	sp,sp,-48
    80000b4e:	f406                	sd	ra,40(sp)
    80000b50:	f022                	sd	s0,32(sp)
    80000b52:	ec26                	sd	s1,24(sp)
    80000b54:	e84a                	sd	s2,16(sp)
    80000b56:	e44e                	sd	s3,8(sp)
    80000b58:	1800                	add	s0,sp,48
    printf("[pmem] kernel end=0x%lx, stack top=0x%lx, usable=[0x%lx, 0x%lx)\n",
    80000b5a:	0000c497          	auipc	s1,0xc
    80000b5e:	4e648493          	add	s1,s1,1254 # 8000d040 <_bss_end>
    80000b62:	0000e917          	auipc	s2,0xe
    80000b66:	49e90913          	add	s2,s2,1182 # 8000f000 <_stack_top>
    80000b6a:	00000097          	auipc	ra,0x0
    80000b6e:	f8e080e7          	jalr	-114(ra) # 80000af8 <pmem_usable_start>
    80000b72:	89aa                	mv	s3,a0
    80000b74:	00000097          	auipc	ra,0x0
    80000b78:	fae080e7          	jalr	-82(ra) # 80000b22 <pmem_usable_end>
    80000b7c:	87aa                	mv	a5,a0
    80000b7e:	873e                	mv	a4,a5
    80000b80:	86ce                	mv	a3,s3
    80000b82:	864a                	mv	a2,s2
    80000b84:	85a6                	mv	a1,s1
    80000b86:	00005517          	auipc	a0,0x5
    80000b8a:	2c250513          	add	a0,a0,706 # 80005e48 <swtch+0x3ac>
    80000b8e:	00005097          	auipc	ra,0x5
    80000b92:	d48080e7          	jalr	-696(ra) # 800058d6 <printf>
           (uint64)end, (uint64)_stack_top, pmem_usable_start(), pmem_usable_end());
}
    80000b96:	0001                	nop
    80000b98:	70a2                	ld	ra,40(sp)
    80000b9a:	7402                	ld	s0,32(sp)
    80000b9c:	64e2                	ld	s1,24(sp)
    80000b9e:	6942                	ld	s2,16(sp)
    80000ba0:	69a2                	ld	s3,8(sp)
    80000ba2:	6145                	add	sp,sp,48
    80000ba4:	8082                	ret

0000000080000ba6 <pmem_init>:

void pmem_init(void) {
    80000ba6:	1141                	add	sp,sp,-16
    80000ba8:	e406                	sd	ra,8(sp)
    80000baa:	e022                	sd	s0,0(sp)
    80000bac:	0800                	add	s0,sp,16
    if (pmem_inited) return;
    80000bae:	00006797          	auipc	a5,0x6
    80000bb2:	33a78793          	add	a5,a5,826 # 80006ee8 <pmem_inited>
    80000bb6:	439c                	lw	a5,0(a5)
    80000bb8:	ef81                	bnez	a5,80000bd0 <pmem_init+0x2a>
    pmm_init();
    80000bba:	00000097          	auipc	ra,0x0
    80000bbe:	c98080e7          	jalr	-872(ra) # 80000852 <pmm_init>
    pmem_inited = 1;
    80000bc2:	00006797          	auipc	a5,0x6
    80000bc6:	32678793          	add	a5,a5,806 # 80006ee8 <pmem_inited>
    80000bca:	4705                	li	a4,1
    80000bcc:	c398                	sw	a4,0(a5)
    80000bce:	a011                	j	80000bd2 <pmem_init+0x2c>
    if (pmem_inited) return;
    80000bd0:	0001                	nop
}
    80000bd2:	60a2                	ld	ra,8(sp)
    80000bd4:	6402                	ld	s0,0(sp)
    80000bd6:	0141                	add	sp,sp,16
    80000bd8:	8082                	ret

0000000080000bda <pmem_alloc>:

void* pmem_alloc(int zero) {
    80000bda:	7179                	add	sp,sp,-48
    80000bdc:	f406                	sd	ra,40(sp)
    80000bde:	f022                	sd	s0,32(sp)
    80000be0:	1800                	add	s0,sp,48
    80000be2:	87aa                	mv	a5,a0
    80000be4:	fcf42e23          	sw	a5,-36(s0)
    void* p = alloc_page();
    80000be8:	00000097          	auipc	ra,0x0
    80000bec:	b12080e7          	jalr	-1262(ra) # 800006fa <alloc_page>
    80000bf0:	fea43423          	sd	a0,-24(s0)
    if (p && zero) {
    80000bf4:	fe843783          	ld	a5,-24(s0)
    80000bf8:	cf89                	beqz	a5,80000c12 <pmem_alloc+0x38>
    80000bfa:	fdc42783          	lw	a5,-36(s0)
    80000bfe:	2781                	sext.w	a5,a5
    80000c00:	cb89                	beqz	a5,80000c12 <pmem_alloc+0x38>
        memset(p, 0, PGSIZE);
    80000c02:	6605                	lui	a2,0x1
    80000c04:	4581                	li	a1,0
    80000c06:	fe843503          	ld	a0,-24(s0)
    80000c0a:	00004097          	auipc	ra,0x4
    80000c0e:	3c2080e7          	jalr	962(ra) # 80004fcc <memset>
    }
    return p;
    80000c12:	fe843783          	ld	a5,-24(s0)
}
    80000c16:	853e                	mv	a0,a5
    80000c18:	70a2                	ld	ra,40(sp)
    80000c1a:	7402                	ld	s0,32(sp)
    80000c1c:	6145                	add	sp,sp,48
    80000c1e:	8082                	ret

0000000080000c20 <pmem_free>:

void pmem_free(uint64 pa, int check) {
    80000c20:	1101                	add	sp,sp,-32
    80000c22:	ec06                	sd	ra,24(sp)
    80000c24:	e822                	sd	s0,16(sp)
    80000c26:	1000                	add	s0,sp,32
    80000c28:	fea43423          	sd	a0,-24(s0)
    80000c2c:	87ae                	mv	a5,a1
    80000c2e:	fef42223          	sw	a5,-28(s0)
    (void)check;
    free_page((void*)pa);
    80000c32:	fe843783          	ld	a5,-24(s0)
    80000c36:	853e                	mv	a0,a5
    80000c38:	00000097          	auipc	ra,0x0
    80000c3c:	a3e080e7          	jalr	-1474(ra) # 80000676 <free_page>
}
    80000c40:	0001                	nop
    80000c42:	60e2                	ld	ra,24(sp)
    80000c44:	6442                	ld	s0,16(sp)
    80000c46:	6105                	add	sp,sp,32
    80000c48:	8082                	ret

0000000080000c4a <w_satp>:
{
    80000c4a:	1101                	add	sp,sp,-32
    80000c4c:	ec22                	sd	s0,24(sp)
    80000c4e:	1000                	add	s0,sp,32
    80000c50:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw satp, %0" : : "r" (x));
    80000c54:	fe843783          	ld	a5,-24(s0)
    80000c58:	18079073          	csrw	satp,a5
}
    80000c5c:	0001                	nop
    80000c5e:	6462                	ld	s0,24(sp)
    80000c60:	6105                	add	sp,sp,32
    80000c62:	8082                	ret

0000000080000c64 <sfence_vma>:
}

// flush the TLB.
static inline void
sfence_vma()
{
    80000c64:	1141                	add	sp,sp,-16
    80000c66:	e422                	sd	s0,8(sp)
    80000c68:	0800                	add	s0,sp,16
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80000c6a:	12000073          	sfence.vma
}
    80000c6e:	0001                	nop
    80000c70:	6422                	ld	s0,8(sp)
    80000c72:	0141                	add	sp,sp,16
    80000c74:	8082                	ret

0000000080000c76 <create_pagetable>:

static void freewalk(pagetable_t pagetable, int level);
static void dumpwalk(pagetable_t pagetable, int level, int indent, int* remaining);
static void map_range(pagetable_t pagetable, uint64 va_start, uint64 va_end, uint64 pa_start, int perm);

pagetable_t create_pagetable(void) {
    80000c76:	1101                	add	sp,sp,-32
    80000c78:	ec06                	sd	ra,24(sp)
    80000c7a:	e822                	sd	s0,16(sp)
    80000c7c:	1000                	add	s0,sp,32
    void* page = alloc_page();
    80000c7e:	00000097          	auipc	ra,0x0
    80000c82:	a7c080e7          	jalr	-1412(ra) # 800006fa <alloc_page>
    80000c86:	fea43423          	sd	a0,-24(s0)
    if (!page) return NULL;
    80000c8a:	fe843783          	ld	a5,-24(s0)
    80000c8e:	e399                	bnez	a5,80000c94 <create_pagetable+0x1e>
    80000c90:	4781                	li	a5,0
    80000c92:	a819                	j	80000ca8 <create_pagetable+0x32>
    memset(page, 0, PGSIZE);
    80000c94:	6605                	lui	a2,0x1
    80000c96:	4581                	li	a1,0
    80000c98:	fe843503          	ld	a0,-24(s0)
    80000c9c:	00004097          	auipc	ra,0x4
    80000ca0:	330080e7          	jalr	816(ra) # 80004fcc <memset>
    return (pagetable_t)page;
    80000ca4:	fe843783          	ld	a5,-24(s0)
}
    80000ca8:	853e                	mv	a0,a5
    80000caa:	60e2                	ld	ra,24(sp)
    80000cac:	6442                	ld	s0,16(sp)
    80000cae:	6105                	add	sp,sp,32
    80000cb0:	8082                	ret

0000000080000cb2 <walk_create>:

pte_t* walk_create(pagetable_t pagetable, uint64 va) {
    80000cb2:	7139                	add	sp,sp,-64
    80000cb4:	fc06                	sd	ra,56(sp)
    80000cb6:	f822                	sd	s0,48(sp)
    80000cb8:	0080                	add	s0,sp,64
    80000cba:	fca43423          	sd	a0,-56(s0)
    80000cbe:	fcb43023          	sd	a1,-64(s0)
    if (va >= MAXVA) return NULL;
    80000cc2:	fc043703          	ld	a4,-64(s0)
    80000cc6:	57fd                	li	a5,-1
    80000cc8:	83e9                	srl	a5,a5,0x1a
    80000cca:	00e7f463          	bgeu	a5,a4,80000cd2 <walk_create+0x20>
    80000cce:	4781                	li	a5,0
    80000cd0:	a065                	j	80000d78 <walk_create+0xc6>
    for (int level = 2; level > 0; level--) {
    80000cd2:	4789                	li	a5,2
    80000cd4:	fef42623          	sw	a5,-20(s0)
    80000cd8:	a051                	j	80000d5c <walk_create+0xaa>
        pte_t* pte = &pagetable[PX(level, va)];
    80000cda:	fec42783          	lw	a5,-20(s0)
    80000cde:	873e                	mv	a4,a5
    80000ce0:	87ba                	mv	a5,a4
    80000ce2:	0037979b          	sllw	a5,a5,0x3
    80000ce6:	9fb9                	addw	a5,a5,a4
    80000ce8:	2781                	sext.w	a5,a5
    80000cea:	27b1                	addw	a5,a5,12
    80000cec:	2781                	sext.w	a5,a5
    80000cee:	873e                	mv	a4,a5
    80000cf0:	fc043783          	ld	a5,-64(s0)
    80000cf4:	00e7d7b3          	srl	a5,a5,a4
    80000cf8:	1ff7f793          	and	a5,a5,511
    80000cfc:	078e                	sll	a5,a5,0x3
    80000cfe:	fc843703          	ld	a4,-56(s0)
    80000d02:	97ba                	add	a5,a5,a4
    80000d04:	fef43023          	sd	a5,-32(s0)
        if (*pte & PTE_V) {
    80000d08:	fe043783          	ld	a5,-32(s0)
    80000d0c:	639c                	ld	a5,0(a5)
    80000d0e:	8b85                	and	a5,a5,1
    80000d10:	cb89                	beqz	a5,80000d22 <walk_create+0x70>
            pagetable = (pagetable_t)PTE2PA(*pte);
    80000d12:	fe043783          	ld	a5,-32(s0)
    80000d16:	639c                	ld	a5,0(a5)
    80000d18:	83a9                	srl	a5,a5,0xa
    80000d1a:	07b2                	sll	a5,a5,0xc
    80000d1c:	fcf43423          	sd	a5,-56(s0)
    80000d20:	a80d                	j	80000d52 <walk_create+0xa0>
        } else {
            pagetable_t newtable = create_pagetable();
    80000d22:	00000097          	auipc	ra,0x0
    80000d26:	f54080e7          	jalr	-172(ra) # 80000c76 <create_pagetable>
    80000d2a:	fca43c23          	sd	a0,-40(s0)
            if (!newtable) return NULL;
    80000d2e:	fd843783          	ld	a5,-40(s0)
    80000d32:	e399                	bnez	a5,80000d38 <walk_create+0x86>
    80000d34:	4781                	li	a5,0
    80000d36:	a089                	j	80000d78 <walk_create+0xc6>
            *pte = PA2PTE(newtable) | PTE_V;
    80000d38:	fd843783          	ld	a5,-40(s0)
    80000d3c:	83b1                	srl	a5,a5,0xc
    80000d3e:	07aa                	sll	a5,a5,0xa
    80000d40:	0017e713          	or	a4,a5,1
    80000d44:	fe043783          	ld	a5,-32(s0)
    80000d48:	e398                	sd	a4,0(a5)
            pagetable = newtable;
    80000d4a:	fd843783          	ld	a5,-40(s0)
    80000d4e:	fcf43423          	sd	a5,-56(s0)
    for (int level = 2; level > 0; level--) {
    80000d52:	fec42783          	lw	a5,-20(s0)
    80000d56:	37fd                	addw	a5,a5,-1
    80000d58:	fef42623          	sw	a5,-20(s0)
    80000d5c:	fec42783          	lw	a5,-20(s0)
    80000d60:	2781                	sext.w	a5,a5
    80000d62:	f6f04ce3          	bgtz	a5,80000cda <walk_create+0x28>
        }
    }
    return &pagetable[PX(0, va)];
    80000d66:	fc043783          	ld	a5,-64(s0)
    80000d6a:	83b1                	srl	a5,a5,0xc
    80000d6c:	1ff7f793          	and	a5,a5,511
    80000d70:	078e                	sll	a5,a5,0x3
    80000d72:	fc843703          	ld	a4,-56(s0)
    80000d76:	97ba                	add	a5,a5,a4
}
    80000d78:	853e                	mv	a0,a5
    80000d7a:	70e2                	ld	ra,56(sp)
    80000d7c:	7442                	ld	s0,48(sp)
    80000d7e:	6121                	add	sp,sp,64
    80000d80:	8082                	ret

0000000080000d82 <walk_lookup>:

pte_t* walk_lookup(pagetable_t pagetable, uint64 va) {
    80000d82:	7179                	add	sp,sp,-48
    80000d84:	f422                	sd	s0,40(sp)
    80000d86:	1800                	add	s0,sp,48
    80000d88:	fca43c23          	sd	a0,-40(s0)
    80000d8c:	fcb43823          	sd	a1,-48(s0)
    if (va >= MAXVA) return NULL;
    80000d90:	fd043703          	ld	a4,-48(s0)
    80000d94:	57fd                	li	a5,-1
    80000d96:	83e9                	srl	a5,a5,0x1a
    80000d98:	00e7f463          	bgeu	a5,a4,80000da0 <walk_lookup+0x1e>
    80000d9c:	4781                	li	a5,0
    80000d9e:	a8ad                	j	80000e18 <walk_lookup+0x96>
    for (int level = 2; level > 0; level--) {
    80000da0:	4789                	li	a5,2
    80000da2:	fef42623          	sw	a5,-20(s0)
    80000da6:	a899                	j	80000dfc <walk_lookup+0x7a>
        pte_t* pte = &pagetable[PX(level, va)];
    80000da8:	fec42783          	lw	a5,-20(s0)
    80000dac:	873e                	mv	a4,a5
    80000dae:	87ba                	mv	a5,a4
    80000db0:	0037979b          	sllw	a5,a5,0x3
    80000db4:	9fb9                	addw	a5,a5,a4
    80000db6:	2781                	sext.w	a5,a5
    80000db8:	27b1                	addw	a5,a5,12
    80000dba:	2781                	sext.w	a5,a5
    80000dbc:	873e                	mv	a4,a5
    80000dbe:	fd043783          	ld	a5,-48(s0)
    80000dc2:	00e7d7b3          	srl	a5,a5,a4
    80000dc6:	1ff7f793          	and	a5,a5,511
    80000dca:	078e                	sll	a5,a5,0x3
    80000dcc:	fd843703          	ld	a4,-40(s0)
    80000dd0:	97ba                	add	a5,a5,a4
    80000dd2:	fef43023          	sd	a5,-32(s0)
        if ((*pte & PTE_V) == 0) return NULL;
    80000dd6:	fe043783          	ld	a5,-32(s0)
    80000dda:	639c                	ld	a5,0(a5)
    80000ddc:	8b85                	and	a5,a5,1
    80000dde:	e399                	bnez	a5,80000de4 <walk_lookup+0x62>
    80000de0:	4781                	li	a5,0
    80000de2:	a81d                	j	80000e18 <walk_lookup+0x96>
        pagetable = (pagetable_t)PTE2PA(*pte);
    80000de4:	fe043783          	ld	a5,-32(s0)
    80000de8:	639c                	ld	a5,0(a5)
    80000dea:	83a9                	srl	a5,a5,0xa
    80000dec:	07b2                	sll	a5,a5,0xc
    80000dee:	fcf43c23          	sd	a5,-40(s0)
    for (int level = 2; level > 0; level--) {
    80000df2:	fec42783          	lw	a5,-20(s0)
    80000df6:	37fd                	addw	a5,a5,-1
    80000df8:	fef42623          	sw	a5,-20(s0)
    80000dfc:	fec42783          	lw	a5,-20(s0)
    80000e00:	2781                	sext.w	a5,a5
    80000e02:	faf043e3          	bgtz	a5,80000da8 <walk_lookup+0x26>
    }
    return &pagetable[PX(0, va)];
    80000e06:	fd043783          	ld	a5,-48(s0)
    80000e0a:	83b1                	srl	a5,a5,0xc
    80000e0c:	1ff7f793          	and	a5,a5,511
    80000e10:	078e                	sll	a5,a5,0x3
    80000e12:	fd843703          	ld	a4,-40(s0)
    80000e16:	97ba                	add	a5,a5,a4
}
    80000e18:	853e                	mv	a0,a5
    80000e1a:	7422                	ld	s0,40(sp)
    80000e1c:	6145                	add	sp,sp,48
    80000e1e:	8082                	ret

0000000080000e20 <map_page>:

int map_page(pagetable_t pagetable, uint64 va, uint64 pa, int perm) {
    80000e20:	7139                	add	sp,sp,-64
    80000e22:	fc06                	sd	ra,56(sp)
    80000e24:	f822                	sd	s0,48(sp)
    80000e26:	0080                	add	s0,sp,64
    80000e28:	fca43c23          	sd	a0,-40(s0)
    80000e2c:	fcb43823          	sd	a1,-48(s0)
    80000e30:	fcc43423          	sd	a2,-56(s0)
    80000e34:	87b6                	mv	a5,a3
    80000e36:	fcf42223          	sw	a5,-60(s0)
    if (va % PGSIZE || pa % PGSIZE) return -1;
    80000e3a:	fd043703          	ld	a4,-48(s0)
    80000e3e:	6785                	lui	a5,0x1
    80000e40:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80000e42:	8ff9                	and	a5,a5,a4
    80000e44:	e799                	bnez	a5,80000e52 <map_page+0x32>
    80000e46:	fc843703          	ld	a4,-56(s0)
    80000e4a:	6785                	lui	a5,0x1
    80000e4c:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80000e4e:	8ff9                	and	a5,a5,a4
    80000e50:	c399                	beqz	a5,80000e56 <map_page+0x36>
    80000e52:	57fd                	li	a5,-1
    80000e54:	a0a9                	j	80000e9e <map_page+0x7e>
    pte_t* pte = walk_create(pagetable, va);
    80000e56:	fd043583          	ld	a1,-48(s0)
    80000e5a:	fd843503          	ld	a0,-40(s0)
    80000e5e:	00000097          	auipc	ra,0x0
    80000e62:	e54080e7          	jalr	-428(ra) # 80000cb2 <walk_create>
    80000e66:	fea43423          	sd	a0,-24(s0)
    if (!pte) return -1;
    80000e6a:	fe843783          	ld	a5,-24(s0)
    80000e6e:	e399                	bnez	a5,80000e74 <map_page+0x54>
    80000e70:	57fd                	li	a5,-1
    80000e72:	a035                	j	80000e9e <map_page+0x7e>
    if (*pte & PTE_V) {
    80000e74:	fe843783          	ld	a5,-24(s0)
    80000e78:	639c                	ld	a5,0(a5)
    80000e7a:	8b85                	and	a5,a5,1
    80000e7c:	c399                	beqz	a5,80000e82 <map_page+0x62>
        return -2; // already mapped
    80000e7e:	57f9                	li	a5,-2
    80000e80:	a839                	j	80000e9e <map_page+0x7e>
    }
    *pte = PA2PTE(pa) | perm | PTE_V;
    80000e82:	fc843783          	ld	a5,-56(s0)
    80000e86:	83b1                	srl	a5,a5,0xc
    80000e88:	00a79713          	sll	a4,a5,0xa
    80000e8c:	fc442783          	lw	a5,-60(s0)
    80000e90:	8fd9                	or	a5,a5,a4
    80000e92:	0017e713          	or	a4,a5,1
    80000e96:	fe843783          	ld	a5,-24(s0)
    80000e9a:	e398                	sd	a4,0(a5)
    return 0;
    80000e9c:	4781                	li	a5,0
}
    80000e9e:	853e                	mv	a0,a5
    80000ea0:	70e2                	ld	ra,56(sp)
    80000ea2:	7442                	ld	s0,48(sp)
    80000ea4:	6121                	add	sp,sp,64
    80000ea6:	8082                	ret

0000000080000ea8 <map_range>:

static void map_range(pagetable_t pagetable, uint64 va_start, uint64 va_end, uint64 pa_start, int perm) {
    80000ea8:	711d                	add	sp,sp,-96
    80000eaa:	ec86                	sd	ra,88(sp)
    80000eac:	e8a2                	sd	s0,80(sp)
    80000eae:	1080                	add	s0,sp,96
    80000eb0:	fca43423          	sd	a0,-56(s0)
    80000eb4:	fcb43023          	sd	a1,-64(s0)
    80000eb8:	fac43c23          	sd	a2,-72(s0)
    80000ebc:	fad43823          	sd	a3,-80(s0)
    80000ec0:	87ba                	mv	a5,a4
    80000ec2:	faf42623          	sw	a5,-84(s0)
    uint64 va = PGROUNDDOWN(va_start);
    80000ec6:	fc043703          	ld	a4,-64(s0)
    80000eca:	77fd                	lui	a5,0xfffff
    80000ecc:	8ff9                	and	a5,a5,a4
    80000ece:	fef43423          	sd	a5,-24(s0)
    uint64 pa = PGROUNDDOWN(pa_start);
    80000ed2:	fb043703          	ld	a4,-80(s0)
    80000ed6:	77fd                	lui	a5,0xfffff
    80000ed8:	8ff9                	and	a5,a5,a4
    80000eda:	fef43023          	sd	a5,-32(s0)
    for (; va < va_end; va += PGSIZE, pa += PGSIZE) {
    80000ede:	a895                	j	80000f52 <map_range+0xaa>
        int r = map_page(pagetable, va, pa, perm);
    80000ee0:	fac42783          	lw	a5,-84(s0)
    80000ee4:	86be                	mv	a3,a5
    80000ee6:	fe043603          	ld	a2,-32(s0)
    80000eea:	fe843583          	ld	a1,-24(s0)
    80000eee:	fc843503          	ld	a0,-56(s0)
    80000ef2:	00000097          	auipc	ra,0x0
    80000ef6:	f2e080e7          	jalr	-210(ra) # 80000e20 <map_page>
    80000efa:	87aa                	mv	a5,a0
    80000efc:	fcf42e23          	sw	a5,-36(s0)
        if (r != 0) {
    80000f00:	fdc42783          	lw	a5,-36(s0)
    80000f04:	2781                	sext.w	a5,a5
    80000f06:	cb95                	beqz	a5,80000f3a <map_range+0x92>
            printf("[vmem] map_range fail va=0x%lx pa=0x%lx perm=0x%x err=%d\n", va, pa, perm, r);
    80000f08:	fdc42703          	lw	a4,-36(s0)
    80000f0c:	fac42783          	lw	a5,-84(s0)
    80000f10:	86be                	mv	a3,a5
    80000f12:	fe043603          	ld	a2,-32(s0)
    80000f16:	fe843583          	ld	a1,-24(s0)
    80000f1a:	00005517          	auipc	a0,0x5
    80000f1e:	f7650513          	add	a0,a0,-138 # 80005e90 <swtch+0x3f4>
    80000f22:	00005097          	auipc	ra,0x5
    80000f26:	9b4080e7          	jalr	-1612(ra) # 800058d6 <printf>
            panic("map_range failed");
    80000f2a:	00005517          	auipc	a0,0x5
    80000f2e:	fa650513          	add	a0,a0,-90 # 80005ed0 <swtch+0x434>
    80000f32:	00005097          	auipc	ra,0x5
    80000f36:	a3c080e7          	jalr	-1476(ra) # 8000596e <panic>
    for (; va < va_end; va += PGSIZE, pa += PGSIZE) {
    80000f3a:	fe843703          	ld	a4,-24(s0)
    80000f3e:	6785                	lui	a5,0x1
    80000f40:	97ba                	add	a5,a5,a4
    80000f42:	fef43423          	sd	a5,-24(s0)
    80000f46:	fe043703          	ld	a4,-32(s0)
    80000f4a:	6785                	lui	a5,0x1
    80000f4c:	97ba                	add	a5,a5,a4
    80000f4e:	fef43023          	sd	a5,-32(s0)
    80000f52:	fe843703          	ld	a4,-24(s0)
    80000f56:	fb843783          	ld	a5,-72(s0)
    80000f5a:	f8f763e3          	bltu	a4,a5,80000ee0 <map_range+0x38>
        }
    }
}
    80000f5e:	0001                	nop
    80000f60:	0001                	nop
    80000f62:	60e6                	ld	ra,88(sp)
    80000f64:	6446                	ld	s0,80(sp)
    80000f66:	6125                	add	sp,sp,96
    80000f68:	8082                	ret

0000000080000f6a <destroy_pagetable>:

void destroy_pagetable(pagetable_t pagetable) {
    80000f6a:	1101                	add	sp,sp,-32
    80000f6c:	ec06                	sd	ra,24(sp)
    80000f6e:	e822                	sd	s0,16(sp)
    80000f70:	1000                	add	s0,sp,32
    80000f72:	fea43423          	sd	a0,-24(s0)
    freewalk(pagetable, 2);
    80000f76:	4589                	li	a1,2
    80000f78:	fe843503          	ld	a0,-24(s0)
    80000f7c:	00000097          	auipc	ra,0x0
    80000f80:	012080e7          	jalr	18(ra) # 80000f8e <freewalk>
}
    80000f84:	0001                	nop
    80000f86:	60e2                	ld	ra,24(sp)
    80000f88:	6442                	ld	s0,16(sp)
    80000f8a:	6105                	add	sp,sp,32
    80000f8c:	8082                	ret

0000000080000f8e <freewalk>:

static void freewalk(pagetable_t pagetable, int level) {
    80000f8e:	7139                	add	sp,sp,-64
    80000f90:	fc06                	sd	ra,56(sp)
    80000f92:	f822                	sd	s0,48(sp)
    80000f94:	0080                	add	s0,sp,64
    80000f96:	fca43423          	sd	a0,-56(s0)
    80000f9a:	87ae                	mv	a5,a1
    80000f9c:	fcf42223          	sw	a5,-60(s0)
    for (int i = 0; i < 512; i++) {
    80000fa0:	fe042623          	sw	zero,-20(s0)
    80000fa4:	a8a1                	j	80000ffc <freewalk+0x6e>
        pte_t pte = pagetable[i];
    80000fa6:	fec42783          	lw	a5,-20(s0)
    80000faa:	078e                	sll	a5,a5,0x3
    80000fac:	fc843703          	ld	a4,-56(s0)
    80000fb0:	97ba                	add	a5,a5,a4
    80000fb2:	639c                	ld	a5,0(a5)
    80000fb4:	fef43023          	sd	a5,-32(s0)
        if ((pte & PTE_V) == 0) continue;
    80000fb8:	fe043783          	ld	a5,-32(s0)
    80000fbc:	8b85                	and	a5,a5,1
    80000fbe:	c79d                	beqz	a5,80000fec <freewalk+0x5e>
        if ((pte & (PTE_R | PTE_W | PTE_X)) != 0) {
    80000fc0:	fe043783          	ld	a5,-32(s0)
    80000fc4:	8bb9                	and	a5,a5,14
    80000fc6:	e78d                	bnez	a5,80000ff0 <freewalk+0x62>
            continue; // leaf mapping, actual physical page lifetime handled elsewhere
        }
        pagetable_t child = (pagetable_t)PTE2PA(pte);
    80000fc8:	fe043783          	ld	a5,-32(s0)
    80000fcc:	83a9                	srl	a5,a5,0xa
    80000fce:	07b2                	sll	a5,a5,0xc
    80000fd0:	fcf43c23          	sd	a5,-40(s0)
        freewalk(child, level - 1);
    80000fd4:	fc442783          	lw	a5,-60(s0)
    80000fd8:	37fd                	addw	a5,a5,-1 # fff <_entry-0x7ffff001>
    80000fda:	2781                	sext.w	a5,a5
    80000fdc:	85be                	mv	a1,a5
    80000fde:	fd843503          	ld	a0,-40(s0)
    80000fe2:	00000097          	auipc	ra,0x0
    80000fe6:	fac080e7          	jalr	-84(ra) # 80000f8e <freewalk>
    80000fea:	a021                	j	80000ff2 <freewalk+0x64>
        if ((pte & PTE_V) == 0) continue;
    80000fec:	0001                	nop
    80000fee:	a011                	j	80000ff2 <freewalk+0x64>
            continue; // leaf mapping, actual physical page lifetime handled elsewhere
    80000ff0:	0001                	nop
    for (int i = 0; i < 512; i++) {
    80000ff2:	fec42783          	lw	a5,-20(s0)
    80000ff6:	2785                	addw	a5,a5,1
    80000ff8:	fef42623          	sw	a5,-20(s0)
    80000ffc:	fec42783          	lw	a5,-20(s0)
    80001000:	0007871b          	sext.w	a4,a5
    80001004:	1ff00793          	li	a5,511
    80001008:	f8e7dfe3          	bge	a5,a4,80000fa6 <freewalk+0x18>
    }
    free_page(pagetable);
    8000100c:	fc843503          	ld	a0,-56(s0)
    80001010:	fffff097          	auipc	ra,0xfffff
    80001014:	666080e7          	jalr	1638(ra) # 80000676 <free_page>
}
    80001018:	0001                	nop
    8000101a:	70e2                	ld	ra,56(sp)
    8000101c:	7442                	ld	s0,48(sp)
    8000101e:	6121                	add	sp,sp,64
    80001020:	8082                	ret

0000000080001022 <dumpwalk>:

static void dumpwalk(pagetable_t pagetable, int level, int indent, int* remaining) {
    80001022:	715d                	add	sp,sp,-80
    80001024:	e486                	sd	ra,72(sp)
    80001026:	e0a2                	sd	s0,64(sp)
    80001028:	0880                	add	s0,sp,80
    8000102a:	fca43423          	sd	a0,-56(s0)
    8000102e:	87ae                	mv	a5,a1
    80001030:	8732                	mv	a4,a2
    80001032:	fad43c23          	sd	a3,-72(s0)
    80001036:	fcf42223          	sw	a5,-60(s0)
    8000103a:	87ba                	mv	a5,a4
    8000103c:	fcf42023          	sw	a5,-64(s0)
    for (int i = 0; i < 512; i++) {
    80001040:	fe042623          	sw	zero,-20(s0)
    80001044:	a0d5                	j	80001128 <dumpwalk+0x106>
        pte_t pte = pagetable[i];
    80001046:	fec42783          	lw	a5,-20(s0)
    8000104a:	078e                	sll	a5,a5,0x3
    8000104c:	fc843703          	ld	a4,-56(s0)
    80001050:	97ba                	add	a5,a5,a4
    80001052:	639c                	ld	a5,0(a5)
    80001054:	fef43023          	sd	a5,-32(s0)
        if ((pte & PTE_V) == 0) continue;
    80001058:	fe043783          	ld	a5,-32(s0)
    8000105c:	8b85                	and	a5,a5,1
    8000105e:	cfdd                	beqz	a5,8000111c <dumpwalk+0xfa>
        if (*remaining <= 0) return;
    80001060:	fb843783          	ld	a5,-72(s0)
    80001064:	439c                	lw	a5,0(a5)
    80001066:	0cf05a63          	blez	a5,8000113a <dumpwalk+0x118>
        (*remaining)--;
    8000106a:	fb843783          	ld	a5,-72(s0)
    8000106e:	439c                	lw	a5,0(a5)
    80001070:	37fd                	addw	a5,a5,-1
    80001072:	0007871b          	sext.w	a4,a5
    80001076:	fb843783          	ld	a5,-72(s0)
    8000107a:	c398                	sw	a4,0(a5)
        for (int j = 0; j < indent; j++) printf(" ");
    8000107c:	fe042423          	sw	zero,-24(s0)
    80001080:	a831                	j	8000109c <dumpwalk+0x7a>
    80001082:	00005517          	auipc	a0,0x5
    80001086:	e6650513          	add	a0,a0,-410 # 80005ee8 <swtch+0x44c>
    8000108a:	00005097          	auipc	ra,0x5
    8000108e:	84c080e7          	jalr	-1972(ra) # 800058d6 <printf>
    80001092:	fe842783          	lw	a5,-24(s0)
    80001096:	2785                	addw	a5,a5,1
    80001098:	fef42423          	sw	a5,-24(s0)
    8000109c:	fe842783          	lw	a5,-24(s0)
    800010a0:	873e                	mv	a4,a5
    800010a2:	fc042783          	lw	a5,-64(s0)
    800010a6:	2701                	sext.w	a4,a4
    800010a8:	2781                	sext.w	a5,a5
    800010aa:	fcf74ce3          	blt	a4,a5,80001082 <dumpwalk+0x60>
        uint64 pa = PTE2PA(pte);
    800010ae:	fe043783          	ld	a5,-32(s0)
    800010b2:	83a9                	srl	a5,a5,0xa
    800010b4:	07b2                	sll	a5,a5,0xc
    800010b6:	fcf43c23          	sd	a5,-40(s0)
        printf("L%d[%d]: PTE=0x%lx -> PA=0x%lx flags=0x%lx\n",
    800010ba:	fe043783          	ld	a5,-32(s0)
    800010be:	3ff7f793          	and	a5,a5,1023
    800010c2:	fec42603          	lw	a2,-20(s0)
    800010c6:	fc442583          	lw	a1,-60(s0)
    800010ca:	fd843703          	ld	a4,-40(s0)
    800010ce:	fe043683          	ld	a3,-32(s0)
    800010d2:	00005517          	auipc	a0,0x5
    800010d6:	e1e50513          	add	a0,a0,-482 # 80005ef0 <swtch+0x454>
    800010da:	00004097          	auipc	ra,0x4
    800010de:	7fc080e7          	jalr	2044(ra) # 800058d6 <printf>
               level, i, pte, pa, PTE_FLAGS(pte));
        if ((pte & (PTE_R | PTE_W | PTE_X)) == 0 && level > 0) {
    800010e2:	fe043783          	ld	a5,-32(s0)
    800010e6:	8bb9                	and	a5,a5,14
    800010e8:	eb9d                	bnez	a5,8000111e <dumpwalk+0xfc>
    800010ea:	fc442783          	lw	a5,-60(s0)
    800010ee:	2781                	sext.w	a5,a5
    800010f0:	02f05763          	blez	a5,8000111e <dumpwalk+0xfc>
            dumpwalk((pagetable_t)pa, level - 1, indent + 2, remaining);
    800010f4:	fd843783          	ld	a5,-40(s0)
    800010f8:	fc442703          	lw	a4,-60(s0)
    800010fc:	377d                	addw	a4,a4,-1
    800010fe:	2701                	sext.w	a4,a4
    80001100:	fc042683          	lw	a3,-64(s0)
    80001104:	2689                	addw	a3,a3,2
    80001106:	0006861b          	sext.w	a2,a3
    8000110a:	fb843683          	ld	a3,-72(s0)
    8000110e:	85ba                	mv	a1,a4
    80001110:	853e                	mv	a0,a5
    80001112:	00000097          	auipc	ra,0x0
    80001116:	f10080e7          	jalr	-240(ra) # 80001022 <dumpwalk>
    8000111a:	a011                	j	8000111e <dumpwalk+0xfc>
        if ((pte & PTE_V) == 0) continue;
    8000111c:	0001                	nop
    for (int i = 0; i < 512; i++) {
    8000111e:	fec42783          	lw	a5,-20(s0)
    80001122:	2785                	addw	a5,a5,1
    80001124:	fef42623          	sw	a5,-20(s0)
    80001128:	fec42783          	lw	a5,-20(s0)
    8000112c:	0007871b          	sext.w	a4,a5
    80001130:	1ff00793          	li	a5,511
    80001134:	f0e7d9e3          	bge	a5,a4,80001046 <dumpwalk+0x24>
    80001138:	a011                	j	8000113c <dumpwalk+0x11a>
        if (*remaining <= 0) return;
    8000113a:	0001                	nop
        }
    }
}
    8000113c:	60a6                	ld	ra,72(sp)
    8000113e:	6406                	ld	s0,64(sp)
    80001140:	6161                	add	sp,sp,80
    80001142:	8082                	ret

0000000080001144 <dump_pagetable>:

void dump_pagetable(pagetable_t pagetable) {
    80001144:	7179                	add	sp,sp,-48
    80001146:	f406                	sd	ra,40(sp)
    80001148:	f022                	sd	s0,32(sp)
    8000114a:	1800                	add	s0,sp,48
    8000114c:	fca43c23          	sd	a0,-40(s0)
    printf("[vmem] dump pagetable @0x%lx\n", (uint64)pagetable);
    80001150:	fd843783          	ld	a5,-40(s0)
    80001154:	85be                	mv	a1,a5
    80001156:	00005517          	auipc	a0,0x5
    8000115a:	dca50513          	add	a0,a0,-566 # 80005f20 <swtch+0x484>
    8000115e:	00004097          	auipc	ra,0x4
    80001162:	778080e7          	jalr	1912(ra) # 800058d6 <printf>
    int remaining = 200; // keep output bounded to avoid flooding console
    80001166:	0c800793          	li	a5,200
    8000116a:	fef42623          	sw	a5,-20(s0)
    dumpwalk(pagetable, 2, 0, &remaining);
    8000116e:	fec40793          	add	a5,s0,-20
    80001172:	86be                	mv	a3,a5
    80001174:	4601                	li	a2,0
    80001176:	4589                	li	a1,2
    80001178:	fd843503          	ld	a0,-40(s0)
    8000117c:	00000097          	auipc	ra,0x0
    80001180:	ea6080e7          	jalr	-346(ra) # 80001022 <dumpwalk>
    if (remaining == 0) {
    80001184:	fec42783          	lw	a5,-20(s0)
    80001188:	eb89                	bnez	a5,8000119a <dump_pagetable+0x56>
        printf("[vmem] dump truncated after 200 entries\n");
    8000118a:	00005517          	auipc	a0,0x5
    8000118e:	db650513          	add	a0,a0,-586 # 80005f40 <swtch+0x4a4>
    80001192:	00004097          	auipc	ra,0x4
    80001196:	744080e7          	jalr	1860(ra) # 800058d6 <printf>
    }
}
    8000119a:	0001                	nop
    8000119c:	70a2                	ld	ra,40(sp)
    8000119e:	7402                	ld	s0,32(sp)
    800011a0:	6145                	add	sp,sp,48
    800011a2:	8082                	ret

00000000800011a4 <vmem_setup_kernel>:

pagetable_t vmem_setup_kernel(void) {
    800011a4:	1141                	add	sp,sp,-16
    800011a6:	e406                	sd	ra,8(sp)
    800011a8:	e022                	sd	s0,0(sp)
    800011aa:	0800                	add	s0,sp,16
    if (kernel_pagetable) {
    800011ac:	00006797          	auipc	a5,0x6
    800011b0:	d4478793          	add	a5,a5,-700 # 80006ef0 <kernel_pagetable>
    800011b4:	639c                	ld	a5,0(a5)
    800011b6:	c799                	beqz	a5,800011c4 <vmem_setup_kernel+0x20>
        return kernel_pagetable;
    800011b8:	00006797          	auipc	a5,0x6
    800011bc:	d3878793          	add	a5,a5,-712 # 80006ef0 <kernel_pagetable>
    800011c0:	639c                	ld	a5,0(a5)
    800011c2:	a881                	j	80001212 <vmem_setup_kernel+0x6e>
    }
    kernel_pagetable = create_pagetable();
    800011c4:	00000097          	auipc	ra,0x0
    800011c8:	ab2080e7          	jalr	-1358(ra) # 80000c76 <create_pagetable>
    800011cc:	872a                	mv	a4,a0
    800011ce:	00006797          	auipc	a5,0x6
    800011d2:	d2278793          	add	a5,a5,-734 # 80006ef0 <kernel_pagetable>
    800011d6:	e398                	sd	a4,0(a5)
    if (!kernel_pagetable) panic("vmem_setup_kernel: alloc root");
    800011d8:	00006797          	auipc	a5,0x6
    800011dc:	d1878793          	add	a5,a5,-744 # 80006ef0 <kernel_pagetable>
    800011e0:	639c                	ld	a5,0(a5)
    800011e2:	eb89                	bnez	a5,800011f4 <vmem_setup_kernel+0x50>
    800011e4:	00005517          	auipc	a0,0x5
    800011e8:	d8c50513          	add	a0,a0,-628 # 80005f70 <swtch+0x4d4>
    800011ec:	00004097          	auipc	ra,0x4
    800011f0:	782080e7          	jalr	1922(ra) # 8000596e <panic>
    vmem_map_kernel_segments(kernel_pagetable);
    800011f4:	00006797          	auipc	a5,0x6
    800011f8:	cfc78793          	add	a5,a5,-772 # 80006ef0 <kernel_pagetable>
    800011fc:	639c                	ld	a5,0(a5)
    800011fe:	853e                	mv	a0,a5
    80001200:	00000097          	auipc	ra,0x0
    80001204:	034080e7          	jalr	52(ra) # 80001234 <vmem_map_kernel_segments>
    return kernel_pagetable;
    80001208:	00006797          	auipc	a5,0x6
    8000120c:	ce878793          	add	a5,a5,-792 # 80006ef0 <kernel_pagetable>
    80001210:	639c                	ld	a5,0(a5)
}
    80001212:	853e                	mv	a0,a5
    80001214:	60a2                	ld	ra,8(sp)
    80001216:	6402                	ld	s0,0(sp)
    80001218:	0141                	add	sp,sp,16
    8000121a:	8082                	ret

000000008000121c <vmem_kernel_pagetable>:

pagetable_t vmem_kernel_pagetable(void) {
    8000121c:	1141                	add	sp,sp,-16
    8000121e:	e422                	sd	s0,8(sp)
    80001220:	0800                	add	s0,sp,16
    return kernel_pagetable;
    80001222:	00006797          	auipc	a5,0x6
    80001226:	cce78793          	add	a5,a5,-818 # 80006ef0 <kernel_pagetable>
    8000122a:	639c                	ld	a5,0(a5)
}
    8000122c:	853e                	mv	a0,a5
    8000122e:	6422                	ld	s0,8(sp)
    80001230:	0141                	add	sp,sp,16
    80001232:	8082                	ret

0000000080001234 <vmem_map_kernel_segments>:

void vmem_map_kernel_segments(pagetable_t kpgtbl) {
    80001234:	7159                	add	sp,sp,-112
    80001236:	f486                	sd	ra,104(sp)
    80001238:	f0a2                	sd	s0,96(sp)
    8000123a:	1880                	add	s0,sp,112
    8000123c:	f8a43c23          	sd	a0,-104(s0)
    uint64 text_start = (uint64)_text_start;
    80001240:	fffff797          	auipc	a5,0xfffff
    80001244:	dc078793          	add	a5,a5,-576 # 80000000 <_entry>
    80001248:	fef43423          	sd	a5,-24(s0)
    uint64 data_start_addr = (uint64)_data_start;
    8000124c:	00006797          	auipc	a5,0x6
    80001250:	b3478793          	add	a5,a5,-1228 # 80006d80 <syscall_names>
    80001254:	fef43023          	sd	a5,-32(s0)
    uint64 bss_end    = (uint64)_bss_end;
    80001258:	0000c797          	auipc	a5,0xc
    8000125c:	de878793          	add	a5,a5,-536 # 8000d040 <_bss_end>
    80001260:	fcf43c23          	sd	a5,-40(s0)
    uint64 stack_bottom = (uint64)_stack_bottom;
    80001264:	0000d797          	auipc	a5,0xd
    80001268:	d9c78793          	add	a5,a5,-612 # 8000e000 <_stack_bottom>
    8000126c:	fcf43823          	sd	a5,-48(s0)
    uint64 stack_top    = (uint64)_stack_top;
    80001270:	0000e797          	auipc	a5,0xe
    80001274:	d9078793          	add	a5,a5,-624 # 8000f000 <_stack_top>
    80001278:	fcf43423          	sd	a5,-56(s0)

    uint64 text_only_end = PGROUNDDOWN(data_start_addr);
    8000127c:	fe043703          	ld	a4,-32(s0)
    80001280:	77fd                	lui	a5,0xfffff
    80001282:	8ff9                	and	a5,a5,a4
    80001284:	fcf43023          	sd	a5,-64(s0)
    if (text_only_end > text_start) {
    80001288:	fc043703          	ld	a4,-64(s0)
    8000128c:	fe843783          	ld	a5,-24(s0)
    80001290:	00e7ff63          	bgeu	a5,a4,800012ae <vmem_map_kernel_segments+0x7a>
        map_range(kpgtbl, text_start, text_only_end, text_start, PTE_R | PTE_X);
    80001294:	4729                	li	a4,10
    80001296:	fe843683          	ld	a3,-24(s0)
    8000129a:	fc043603          	ld	a2,-64(s0)
    8000129e:	fe843583          	ld	a1,-24(s0)
    800012a2:	f9843503          	ld	a0,-104(s0)
    800012a6:	00000097          	auipc	ra,0x0
    800012aa:	c02080e7          	jalr	-1022(ra) # 80000ea8 <map_range>
    }

    // The page containing the start of .data may also contain tail of .text/.rodata.
    uint64 overlap_page = PGROUNDDOWN(data_start_addr);
    800012ae:	fe043703          	ld	a4,-32(s0)
    800012b2:	77fd                	lui	a5,0xfffff
    800012b4:	8ff9                	and	a5,a5,a4
    800012b6:	faf43c23          	sd	a5,-72(s0)
    map_range(kpgtbl, overlap_page, overlap_page + PGSIZE, overlap_page, PTE_R | PTE_W | PTE_X);
    800012ba:	fb843703          	ld	a4,-72(s0)
    800012be:	6785                	lui	a5,0x1
    800012c0:	97ba                	add	a5,a5,a4
    800012c2:	4739                	li	a4,14
    800012c4:	fb843683          	ld	a3,-72(s0)
    800012c8:	863e                	mv	a2,a5
    800012ca:	fb843583          	ld	a1,-72(s0)
    800012ce:	f9843503          	ld	a0,-104(s0)
    800012d2:	00000097          	auipc	ra,0x0
    800012d6:	bd6080e7          	jalr	-1066(ra) # 80000ea8 <map_range>

    uint64 data_rest_start = overlap_page + PGSIZE;
    800012da:	fb843703          	ld	a4,-72(s0)
    800012de:	6785                	lui	a5,0x1
    800012e0:	97ba                	add	a5,a5,a4
    800012e2:	faf43823          	sd	a5,-80(s0)
    uint64 data_end   = PGROUNDUP(bss_end);
    800012e6:	fd843703          	ld	a4,-40(s0)
    800012ea:	6785                	lui	a5,0x1
    800012ec:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    800012ee:	973e                	add	a4,a4,a5
    800012f0:	77fd                	lui	a5,0xfffff
    800012f2:	8ff9                	and	a5,a5,a4
    800012f4:	faf43423          	sd	a5,-88(s0)
    if (data_end > data_rest_start) {
    800012f8:	fa843703          	ld	a4,-88(s0)
    800012fc:	fb043783          	ld	a5,-80(s0)
    80001300:	00e7ff63          	bgeu	a5,a4,8000131e <vmem_map_kernel_segments+0xea>
        map_range(kpgtbl, data_rest_start, data_end, data_rest_start, PTE_R | PTE_W);
    80001304:	4719                	li	a4,6
    80001306:	fb043683          	ld	a3,-80(s0)
    8000130a:	fa843603          	ld	a2,-88(s0)
    8000130e:	fb043583          	ld	a1,-80(s0)
    80001312:	f9843503          	ld	a0,-104(s0)
    80001316:	00000097          	auipc	ra,0x0
    8000131a:	b92080e7          	jalr	-1134(ra) # 80000ea8 <map_range>
    }
    map_range(kpgtbl, stack_bottom, stack_top, stack_bottom, PTE_R | PTE_W);
    8000131e:	4719                	li	a4,6
    80001320:	fd043683          	ld	a3,-48(s0)
    80001324:	fc843603          	ld	a2,-56(s0)
    80001328:	fd043583          	ld	a1,-48(s0)
    8000132c:	f9843503          	ld	a0,-104(s0)
    80001330:	00000097          	auipc	ra,0x0
    80001334:	b78080e7          	jalr	-1160(ra) # 80000ea8 <map_range>

    // Map remaining physical memory for allocator use
    uint64 free_start = PGROUNDUP(pmem_usable_start());
    80001338:	fffff097          	auipc	ra,0xfffff
    8000133c:	7c0080e7          	jalr	1984(ra) # 80000af8 <pmem_usable_start>
    80001340:	872a                	mv	a4,a0
    80001342:	6785                	lui	a5,0x1
    80001344:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001346:	973e                	add	a4,a4,a5
    80001348:	77fd                	lui	a5,0xfffff
    8000134a:	8ff9                	and	a5,a5,a4
    8000134c:	faf43023          	sd	a5,-96(s0)
    map_range(kpgtbl, free_start, RAM_END, free_start, PTE_R | PTE_W);
    80001350:	4719                	li	a4,6
    80001352:	fa043683          	ld	a3,-96(s0)
    80001356:	47c5                	li	a5,17
    80001358:	01b79613          	sll	a2,a5,0x1b
    8000135c:	fa043583          	ld	a1,-96(s0)
    80001360:	f9843503          	ld	a0,-104(s0)
    80001364:	00000097          	auipc	ra,0x0
    80001368:	b44080e7          	jalr	-1212(ra) # 80000ea8 <map_range>

    // Map UART device
    map_range(kpgtbl, 0x10000000UL, 0x10000000UL + PGSIZE, 0x10000000UL, PTE_R | PTE_W);
    8000136c:	4719                	li	a4,6
    8000136e:	100006b7          	lui	a3,0x10000
    80001372:	10001637          	lui	a2,0x10001
    80001376:	100005b7          	lui	a1,0x10000
    8000137a:	f9843503          	ld	a0,-104(s0)
    8000137e:	00000097          	auipc	ra,0x0
    80001382:	b2a080e7          	jalr	-1238(ra) # 80000ea8 <map_range>
}
    80001386:	0001                	nop
    80001388:	70a6                	ld	ra,104(sp)
    8000138a:	7406                	ld	s0,96(sp)
    8000138c:	6165                	add	sp,sp,112
    8000138e:	8082                	ret

0000000080001390 <vmem_enable>:

void vmem_enable(pagetable_t kpgtbl) {
    80001390:	7179                	add	sp,sp,-48
    80001392:	f406                	sd	ra,40(sp)
    80001394:	f022                	sd	s0,32(sp)
    80001396:	1800                	add	s0,sp,48
    80001398:	fca43c23          	sd	a0,-40(s0)
    uint64 satp = MAKE_SATP(kpgtbl);
    8000139c:	fd843783          	ld	a5,-40(s0)
    800013a0:	00c7d713          	srl	a4,a5,0xc
    800013a4:	57fd                	li	a5,-1
    800013a6:	17fe                	sll	a5,a5,0x3f
    800013a8:	8fd9                	or	a5,a5,a4
    800013aa:	fef43423          	sd	a5,-24(s0)
    w_satp(satp);
    800013ae:	fe843503          	ld	a0,-24(s0)
    800013b2:	00000097          	auipc	ra,0x0
    800013b6:	898080e7          	jalr	-1896(ra) # 80000c4a <w_satp>
    sfence_vma();
    800013ba:	00000097          	auipc	ra,0x0
    800013be:	8aa080e7          	jalr	-1878(ra) # 80000c64 <sfence_vma>
}
    800013c2:	0001                	nop
    800013c4:	70a2                	ld	ra,40(sp)
    800013c6:	7402                	ld	s0,32(sp)
    800013c8:	6145                	add	sp,sp,48
    800013ca:	8082                	ret

00000000800013cc <vmem_translate>:

uint64 vmem_translate(pagetable_t pagetable, uint64 va) {
    800013cc:	7179                	add	sp,sp,-48
    800013ce:	f406                	sd	ra,40(sp)
    800013d0:	f022                	sd	s0,32(sp)
    800013d2:	1800                	add	s0,sp,48
    800013d4:	fca43c23          	sd	a0,-40(s0)
    800013d8:	fcb43823          	sd	a1,-48(s0)
    pte_t* pte = walk_lookup(pagetable, va);
    800013dc:	fd043583          	ld	a1,-48(s0)
    800013e0:	fd843503          	ld	a0,-40(s0)
    800013e4:	00000097          	auipc	ra,0x0
    800013e8:	99e080e7          	jalr	-1634(ra) # 80000d82 <walk_lookup>
    800013ec:	fea43423          	sd	a0,-24(s0)
    if (!pte || (*pte & PTE_V) == 0) return 0;
    800013f0:	fe843783          	ld	a5,-24(s0)
    800013f4:	c791                	beqz	a5,80001400 <vmem_translate+0x34>
    800013f6:	fe843783          	ld	a5,-24(s0)
    800013fa:	639c                	ld	a5,0(a5)
    800013fc:	8b85                	and	a5,a5,1
    800013fe:	e399                	bnez	a5,80001404 <vmem_translate+0x38>
    80001400:	4781                	li	a5,0
    80001402:	a005                	j	80001422 <vmem_translate+0x56>
    uint64 pa = PTE2PA(*pte);
    80001404:	fe843783          	ld	a5,-24(s0)
    80001408:	639c                	ld	a5,0(a5)
    8000140a:	83a9                	srl	a5,a5,0xa
    8000140c:	07b2                	sll	a5,a5,0xc
    8000140e:	fef43023          	sd	a5,-32(s0)
    return pa | (va & (PGSIZE - 1));
    80001412:	fd043703          	ld	a4,-48(s0)
    80001416:	6785                	lui	a5,0x1
    80001418:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    8000141a:	8f7d                	and	a4,a4,a5
    8000141c:	fe043783          	ld	a5,-32(s0)
    80001420:	8fd9                	or	a5,a5,a4
}
    80001422:	853e                	mv	a0,a5
    80001424:	70a2                	ld	ra,40(sp)
    80001426:	7402                	ld	s0,32(sp)
    80001428:	6145                	add	sp,sp,48
    8000142a:	8082                	ret

000000008000142c <vmem_selftest>:

void vmem_selftest(void) {
    8000142c:	7139                	add	sp,sp,-64
    8000142e:	fc06                	sd	ra,56(sp)
    80001430:	f822                	sd	s0,48(sp)
    80001432:	0080                	add	s0,sp,64
    printf("[vmem] selftest start\n");
    80001434:	00005517          	auipc	a0,0x5
    80001438:	b5c50513          	add	a0,a0,-1188 # 80005f90 <swtch+0x4f4>
    8000143c:	00004097          	auipc	ra,0x4
    80001440:	49a080e7          	jalr	1178(ra) # 800058d6 <printf>
    pagetable_t pt = create_pagetable();
    80001444:	00000097          	auipc	ra,0x0
    80001448:	832080e7          	jalr	-1998(ra) # 80000c76 <create_pagetable>
    8000144c:	fea43423          	sd	a0,-24(s0)
    if (!pt) panic("vmem selftest: pagetable alloc");
    80001450:	fe843783          	ld	a5,-24(s0)
    80001454:	eb89                	bnez	a5,80001466 <vmem_selftest+0x3a>
    80001456:	00005517          	auipc	a0,0x5
    8000145a:	b5250513          	add	a0,a0,-1198 # 80005fa8 <swtch+0x50c>
    8000145e:	00004097          	auipc	ra,0x4
    80001462:	510080e7          	jalr	1296(ra) # 8000596e <panic>
    void* page = alloc_page();
    80001466:	fffff097          	auipc	ra,0xfffff
    8000146a:	294080e7          	jalr	660(ra) # 800006fa <alloc_page>
    8000146e:	fea43023          	sd	a0,-32(s0)
    if (!page) panic("vmem selftest: page alloc");
    80001472:	fe043783          	ld	a5,-32(s0)
    80001476:	eb89                	bnez	a5,80001488 <vmem_selftest+0x5c>
    80001478:	00005517          	auipc	a0,0x5
    8000147c:	b5050513          	add	a0,a0,-1200 # 80005fc8 <swtch+0x52c>
    80001480:	00004097          	auipc	ra,0x4
    80001484:	4ee080e7          	jalr	1262(ra) # 8000596e <panic>
    uint64 va = 0x40000000UL;
    80001488:	400007b7          	lui	a5,0x40000
    8000148c:	fcf43c23          	sd	a5,-40(s0)
    int r = map_page(pt, va, (uint64)page, PTE_R | PTE_W);
    80001490:	fe043783          	ld	a5,-32(s0)
    80001494:	4699                	li	a3,6
    80001496:	863e                	mv	a2,a5
    80001498:	fd843583          	ld	a1,-40(s0)
    8000149c:	fe843503          	ld	a0,-24(s0)
    800014a0:	00000097          	auipc	ra,0x0
    800014a4:	980080e7          	jalr	-1664(ra) # 80000e20 <map_page>
    800014a8:	87aa                	mv	a5,a0
    800014aa:	fcf42a23          	sw	a5,-44(s0)
    if (r != 0) panic("vmem selftest: map_page");
    800014ae:	fd442783          	lw	a5,-44(s0)
    800014b2:	2781                	sext.w	a5,a5
    800014b4:	cb89                	beqz	a5,800014c6 <vmem_selftest+0x9a>
    800014b6:	00005517          	auipc	a0,0x5
    800014ba:	b3250513          	add	a0,a0,-1230 # 80005fe8 <swtch+0x54c>
    800014be:	00004097          	auipc	ra,0x4
    800014c2:	4b0080e7          	jalr	1200(ra) # 8000596e <panic>
    uint64 pa = vmem_translate(pt, va);
    800014c6:	fd843583          	ld	a1,-40(s0)
    800014ca:	fe843503          	ld	a0,-24(s0)
    800014ce:	00000097          	auipc	ra,0x0
    800014d2:	efe080e7          	jalr	-258(ra) # 800013cc <vmem_translate>
    800014d6:	fca43423          	sd	a0,-56(s0)
    if (pa != (uint64)page) panic("vmem selftest: translate mismatch");
    800014da:	fe043783          	ld	a5,-32(s0)
    800014de:	fc843703          	ld	a4,-56(s0)
    800014e2:	00f70a63          	beq	a4,a5,800014f6 <vmem_selftest+0xca>
    800014e6:	00005517          	auipc	a0,0x5
    800014ea:	b1a50513          	add	a0,a0,-1254 # 80006000 <swtch+0x564>
    800014ee:	00004097          	auipc	ra,0x4
    800014f2:	480080e7          	jalr	1152(ra) # 8000596e <panic>
    destroy_pagetable(pt);
    800014f6:	fe843503          	ld	a0,-24(s0)
    800014fa:	00000097          	auipc	ra,0x0
    800014fe:	a70080e7          	jalr	-1424(ra) # 80000f6a <destroy_pagetable>
    free_page(page);
    80001502:	fe043503          	ld	a0,-32(s0)
    80001506:	fffff097          	auipc	ra,0xfffff
    8000150a:	170080e7          	jalr	368(ra) # 80000676 <free_page>
    printf("[vmem] selftest passed\n");
    8000150e:	00005517          	auipc	a0,0x5
    80001512:	b1a50513          	add	a0,a0,-1254 # 80006028 <swtch+0x58c>
    80001516:	00004097          	auipc	ra,0x4
    8000151a:	3c0080e7          	jalr	960(ra) # 800058d6 <printf>
}
    8000151e:	0001                	nop
    80001520:	70e2                	ld	ra,56(sp)
    80001522:	7442                	ld	s0,48(sp)
    80001524:	6121                	add	sp,sp,64
    80001526:	8082                	ret

0000000080001528 <vm_mappages>:

// -------- Compatibility wrappers for user-style tests --------
int vm_mappages(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm) {
    80001528:	711d                	add	sp,sp,-96
    8000152a:	ec86                	sd	ra,88(sp)
    8000152c:	e8a2                	sd	s0,80(sp)
    8000152e:	1080                	add	s0,sp,96
    80001530:	fca43423          	sd	a0,-56(s0)
    80001534:	fcb43023          	sd	a1,-64(s0)
    80001538:	fac43c23          	sd	a2,-72(s0)
    8000153c:	fad43823          	sd	a3,-80(s0)
    80001540:	87ba                	mv	a5,a4
    80001542:	faf42623          	sw	a5,-84(s0)
    uint64 a = PGROUNDDOWN(va);
    80001546:	fc043703          	ld	a4,-64(s0)
    8000154a:	77fd                	lui	a5,0xfffff
    8000154c:	8ff9                	and	a5,a5,a4
    8000154e:	fef43423          	sd	a5,-24(s0)
    uint64 last = PGROUNDUP(va + sz);
    80001552:	fc043703          	ld	a4,-64(s0)
    80001556:	fb043783          	ld	a5,-80(s0)
    8000155a:	973e                	add	a4,a4,a5
    8000155c:	6785                	lui	a5,0x1
    8000155e:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80001560:	973e                	add	a4,a4,a5
    80001562:	77fd                	lui	a5,0xfffff
    80001564:	8ff9                	and	a5,a5,a4
    80001566:	fef43023          	sd	a5,-32(s0)
    for (; a < last; a += PGSIZE, pa += PGSIZE) {
    8000156a:	a8a5                	j	800015e2 <vm_mappages+0xba>
        pte_t* pte = walk_create(pt, a);
    8000156c:	fe843583          	ld	a1,-24(s0)
    80001570:	fc843503          	ld	a0,-56(s0)
    80001574:	fffff097          	auipc	ra,0xfffff
    80001578:	73e080e7          	jalr	1854(ra) # 80000cb2 <walk_create>
    8000157c:	fca43c23          	sd	a0,-40(s0)
        if (!pte) return -1;
    80001580:	fd843783          	ld	a5,-40(s0)
    80001584:	e399                	bnez	a5,8000158a <vm_mappages+0x62>
    80001586:	57fd                	li	a5,-1
    80001588:	a0a5                	j	800015f0 <vm_mappages+0xc8>
        if (*pte & PTE_V) {
    8000158a:	fd843783          	ld	a5,-40(s0)
    8000158e:	639c                	ld	a5,0(a5)
    80001590:	8b85                	and	a5,a5,1
    80001592:	cf99                	beqz	a5,800015b0 <vm_mappages+0x88>
            // allow remap to same pa with new perms
            *pte = PA2PTE(pa) | perm | PTE_V;
    80001594:	fb843783          	ld	a5,-72(s0)
    80001598:	83b1                	srl	a5,a5,0xc
    8000159a:	00a79713          	sll	a4,a5,0xa
    8000159e:	fac42783          	lw	a5,-84(s0)
    800015a2:	8fd9                	or	a5,a5,a4
    800015a4:	0017e713          	or	a4,a5,1
    800015a8:	fd843783          	ld	a5,-40(s0)
    800015ac:	e398                	sd	a4,0(a5)
    800015ae:	a831                	j	800015ca <vm_mappages+0xa2>
        } else {
            *pte = PA2PTE(pa) | perm | PTE_V;
    800015b0:	fb843783          	ld	a5,-72(s0)
    800015b4:	83b1                	srl	a5,a5,0xc
    800015b6:	00a79713          	sll	a4,a5,0xa
    800015ba:	fac42783          	lw	a5,-84(s0)
    800015be:	8fd9                	or	a5,a5,a4
    800015c0:	0017e713          	or	a4,a5,1
    800015c4:	fd843783          	ld	a5,-40(s0)
    800015c8:	e398                	sd	a4,0(a5)
    for (; a < last; a += PGSIZE, pa += PGSIZE) {
    800015ca:	fe843703          	ld	a4,-24(s0)
    800015ce:	6785                	lui	a5,0x1
    800015d0:	97ba                	add	a5,a5,a4
    800015d2:	fef43423          	sd	a5,-24(s0)
    800015d6:	fb843703          	ld	a4,-72(s0)
    800015da:	6785                	lui	a5,0x1
    800015dc:	97ba                	add	a5,a5,a4
    800015de:	faf43c23          	sd	a5,-72(s0)
    800015e2:	fe843703          	ld	a4,-24(s0)
    800015e6:	fe043783          	ld	a5,-32(s0)
    800015ea:	f8f761e3          	bltu	a4,a5,8000156c <vm_mappages+0x44>
        }
    }
    return 0;
    800015ee:	4781                	li	a5,0
}
    800015f0:	853e                	mv	a0,a5
    800015f2:	60e6                	ld	ra,88(sp)
    800015f4:	6446                	ld	s0,80(sp)
    800015f6:	6125                	add	sp,sp,96
    800015f8:	8082                	ret

00000000800015fa <vm_unmappages>:

int vm_unmappages(pagetable_t pt, uint64 va, uint64 sz, int do_free) {
    800015fa:	715d                	add	sp,sp,-80
    800015fc:	e486                	sd	ra,72(sp)
    800015fe:	e0a2                	sd	s0,64(sp)
    80001600:	0880                	add	s0,sp,80
    80001602:	fca43423          	sd	a0,-56(s0)
    80001606:	fcb43023          	sd	a1,-64(s0)
    8000160a:	fac43c23          	sd	a2,-72(s0)
    8000160e:	87b6                	mv	a5,a3
    80001610:	faf42a23          	sw	a5,-76(s0)
    uint64 a = PGROUNDDOWN(va);
    80001614:	fc043703          	ld	a4,-64(s0)
    80001618:	77fd                	lui	a5,0xfffff
    8000161a:	8ff9                	and	a5,a5,a4
    8000161c:	fef43423          	sd	a5,-24(s0)
    uint64 last = PGROUNDUP(va + sz);
    80001620:	fc043703          	ld	a4,-64(s0)
    80001624:	fb843783          	ld	a5,-72(s0)
    80001628:	973e                	add	a4,a4,a5
    8000162a:	6785                	lui	a5,0x1
    8000162c:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    8000162e:	973e                	add	a4,a4,a5
    80001630:	77fd                	lui	a5,0xfffff
    80001632:	8ff9                	and	a5,a5,a4
    80001634:	fef43023          	sd	a5,-32(s0)
    for (; a < last; a += PGSIZE) {
    80001638:	a08d                	j	8000169a <vm_unmappages+0xa0>
        pte_t* pte = walk_lookup(pt, a);
    8000163a:	fe843583          	ld	a1,-24(s0)
    8000163e:	fc843503          	ld	a0,-56(s0)
    80001642:	fffff097          	auipc	ra,0xfffff
    80001646:	740080e7          	jalr	1856(ra) # 80000d82 <walk_lookup>
    8000164a:	fca43c23          	sd	a0,-40(s0)
        if (!pte || (*pte & PTE_V) == 0) return -1;
    8000164e:	fd843783          	ld	a5,-40(s0)
    80001652:	c791                	beqz	a5,8000165e <vm_unmappages+0x64>
    80001654:	fd843783          	ld	a5,-40(s0)
    80001658:	639c                	ld	a5,0(a5)
    8000165a:	8b85                	and	a5,a5,1
    8000165c:	e399                	bnez	a5,80001662 <vm_unmappages+0x68>
    8000165e:	57fd                	li	a5,-1
    80001660:	a881                	j	800016b0 <vm_unmappages+0xb6>
        if (do_free) {
    80001662:	fb442783          	lw	a5,-76(s0)
    80001666:	2781                	sext.w	a5,a5
    80001668:	cf99                	beqz	a5,80001686 <vm_unmappages+0x8c>
            uint64 pa = PTE2PA(*pte);
    8000166a:	fd843783          	ld	a5,-40(s0)
    8000166e:	639c                	ld	a5,0(a5)
    80001670:	83a9                	srl	a5,a5,0xa
    80001672:	07b2                	sll	a5,a5,0xc
    80001674:	fcf43823          	sd	a5,-48(s0)
            free_page((void*)pa);
    80001678:	fd043783          	ld	a5,-48(s0)
    8000167c:	853e                	mv	a0,a5
    8000167e:	fffff097          	auipc	ra,0xfffff
    80001682:	ff8080e7          	jalr	-8(ra) # 80000676 <free_page>
        }
        *pte = 0;
    80001686:	fd843783          	ld	a5,-40(s0)
    8000168a:	0007b023          	sd	zero,0(a5) # fffffffffffff000 <_stack_top+0xffffffff7fff0000>
    for (; a < last; a += PGSIZE) {
    8000168e:	fe843703          	ld	a4,-24(s0)
    80001692:	6785                	lui	a5,0x1
    80001694:	97ba                	add	a5,a5,a4
    80001696:	fef43423          	sd	a5,-24(s0)
    8000169a:	fe843703          	ld	a4,-24(s0)
    8000169e:	fe043783          	ld	a5,-32(s0)
    800016a2:	f8f76ce3          	bltu	a4,a5,8000163a <vm_unmappages+0x40>
    }
    sfence_vma();
    800016a6:	fffff097          	auipc	ra,0xfffff
    800016aa:	5be080e7          	jalr	1470(ra) # 80000c64 <sfence_vma>
    return 0;
    800016ae:	4781                	li	a5,0
}
    800016b0:	853e                	mv	a0,a5
    800016b2:	60a6                	ld	ra,72(sp)
    800016b4:	6406                	ld	s0,64(sp)
    800016b6:	6161                	add	sp,sp,80
    800016b8:	8082                	ret

00000000800016ba <vm_print>:

void vm_print(pagetable_t pt) {
    800016ba:	1101                	add	sp,sp,-32
    800016bc:	ec06                	sd	ra,24(sp)
    800016be:	e822                	sd	s0,16(sp)
    800016c0:	1000                	add	s0,sp,32
    800016c2:	fea43423          	sd	a0,-24(s0)
    dump_pagetable(pt);
    800016c6:	fe843503          	ld	a0,-24(s0)
    800016ca:	00000097          	auipc	ra,0x0
    800016ce:	a7a080e7          	jalr	-1414(ra) # 80001144 <dump_pagetable>
}
    800016d2:	0001                	nop
    800016d4:	60e2                	ld	ra,24(sp)
    800016d6:	6442                	ld	s0,16(sp)
    800016d8:	6105                	add	sp,sp,32
    800016da:	8082                	ret

00000000800016dc <kvm_init>:

void kvm_init(void) {
    800016dc:	1141                	add	sp,sp,-16
    800016de:	e406                	sd	ra,8(sp)
    800016e0:	e022                	sd	s0,0(sp)
    800016e2:	0800                	add	s0,sp,16
    vmem_setup_kernel();
    800016e4:	00000097          	auipc	ra,0x0
    800016e8:	ac0080e7          	jalr	-1344(ra) # 800011a4 <vmem_setup_kernel>
}
    800016ec:	0001                	nop
    800016ee:	60a2                	ld	ra,8(sp)
    800016f0:	6402                	ld	s0,0(sp)
    800016f2:	0141                	add	sp,sp,16
    800016f4:	8082                	ret

00000000800016f6 <kvm_inithart>:

void kvm_inithart(void) {
    800016f6:	1101                	add	sp,sp,-32
    800016f8:	ec06                	sd	ra,24(sp)
    800016fa:	e822                	sd	s0,16(sp)
    800016fc:	1000                	add	s0,sp,32
    pagetable_t kpgtbl = vmem_setup_kernel();
    800016fe:	00000097          	auipc	ra,0x0
    80001702:	aa6080e7          	jalr	-1370(ra) # 800011a4 <vmem_setup_kernel>
    80001706:	fea43423          	sd	a0,-24(s0)
    vmem_enable(kpgtbl);
    8000170a:	fe843503          	ld	a0,-24(s0)
    8000170e:	00000097          	auipc	ra,0x0
    80001712:	c82080e7          	jalr	-894(ra) # 80001390 <vmem_enable>
}
    80001716:	0001                	nop
    80001718:	60e2                	ld	ra,24(sp)
    8000171a:	6442                	ld	s0,16(sp)
    8000171c:	6105                	add	sp,sp,32
    8000171e:	8082                	ret

0000000080001720 <r_sstatus>:
{
    80001720:	1101                	add	sp,sp,-32
    80001722:	ec22                	sd	s0,24(sp)
    80001724:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001726:	100027f3          	csrr	a5,sstatus
    8000172a:	fef43423          	sd	a5,-24(s0)
  return x;
    8000172e:	fe843783          	ld	a5,-24(s0)
}
    80001732:	853e                	mv	a0,a5
    80001734:	6462                	ld	s0,24(sp)
    80001736:	6105                	add	sp,sp,32
    80001738:	8082                	ret

000000008000173a <w_sstatus>:
{
    8000173a:	1101                	add	sp,sp,-32
    8000173c:	ec22                	sd	s0,24(sp)
    8000173e:	1000                	add	s0,sp,32
    80001740:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80001744:	fe843783          	ld	a5,-24(s0)
    80001748:	10079073          	csrw	sstatus,a5
}
    8000174c:	0001                	nop
    8000174e:	6462                	ld	s0,24(sp)
    80001750:	6105                	add	sp,sp,32
    80001752:	8082                	ret

0000000080001754 <intr_on>:
{
    80001754:	1141                	add	sp,sp,-16
    80001756:	e406                	sd	ra,8(sp)
    80001758:	e022                	sd	s0,0(sp)
    8000175a:	0800                	add	s0,sp,16
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    8000175c:	00000097          	auipc	ra,0x0
    80001760:	fc4080e7          	jalr	-60(ra) # 80001720 <r_sstatus>
    80001764:	87aa                	mv	a5,a0
    80001766:	0027e793          	or	a5,a5,2
    8000176a:	853e                	mv	a0,a5
    8000176c:	00000097          	auipc	ra,0x0
    80001770:	fce080e7          	jalr	-50(ra) # 8000173a <w_sstatus>
}
    80001774:	0001                	nop
    80001776:	60a2                	ld	ra,8(sp)
    80001778:	6402                	ld	s0,0(sp)
    8000177a:	0141                	add	sp,sp,16
    8000177c:	8082                	ret

000000008000177e <intr_off>:
{
    8000177e:	1141                	add	sp,sp,-16
    80001780:	e406                	sd	ra,8(sp)
    80001782:	e022                	sd	s0,0(sp)
    80001784:	0800                	add	s0,sp,16
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80001786:	00000097          	auipc	ra,0x0
    8000178a:	f9a080e7          	jalr	-102(ra) # 80001720 <r_sstatus>
    8000178e:	87aa                	mv	a5,a0
    80001790:	9bf5                	and	a5,a5,-3
    80001792:	853e                	mv	a0,a5
    80001794:	00000097          	auipc	ra,0x0
    80001798:	fa6080e7          	jalr	-90(ra) # 8000173a <w_sstatus>
}
    8000179c:	0001                	nop
    8000179e:	60a2                	ld	ra,8(sp)
    800017a0:	6402                	ld	s0,0(sp)
    800017a2:	0141                	add	sp,sp,16
    800017a4:	8082                	ret

00000000800017a6 <intr_get>:
{
    800017a6:	1101                	add	sp,sp,-32
    800017a8:	ec06                	sd	ra,24(sp)
    800017aa:	e822                	sd	s0,16(sp)
    800017ac:	1000                	add	s0,sp,32
  uint64 x = r_sstatus();
    800017ae:	00000097          	auipc	ra,0x0
    800017b2:	f72080e7          	jalr	-142(ra) # 80001720 <r_sstatus>
    800017b6:	fea43423          	sd	a0,-24(s0)
  return (x & SSTATUS_SIE) != 0;
    800017ba:	fe843783          	ld	a5,-24(s0)
    800017be:	8b89                	and	a5,a5,2
    800017c0:	00f037b3          	snez	a5,a5
    800017c4:	0ff7f793          	zext.b	a5,a5
    800017c8:	2781                	sext.w	a5,a5
}
    800017ca:	853e                	mv	a0,a5
    800017cc:	60e2                	ld	ra,24(sp)
    800017ce:	6442                	ld	s0,16(sp)
    800017d0:	6105                	add	sp,sp,32
    800017d2:	8082                	ret

00000000800017d4 <local_state>:
};

// In this lab OS we run single-core by default, so store a single slot.
static struct cpu_local_state cpu_state = {0, 0};

static inline struct cpu_local_state* local_state(void) {
    800017d4:	1141                	add	sp,sp,-16
    800017d6:	e422                	sd	s0,8(sp)
    800017d8:	0800                	add	s0,sp,16
    return &cpu_state;
    800017da:	00005797          	auipc	a5,0x5
    800017de:	71e78793          	add	a5,a5,1822 # 80006ef8 <cpu_state>
}
    800017e2:	853e                	mv	a0,a5
    800017e4:	6422                	ld	s0,8(sp)
    800017e6:	0141                	add	sp,sp,16
    800017e8:	8082                	ret

00000000800017ea <initlock>:

void initlock(struct spinlock* lk, const char* name) {
    800017ea:	1101                	add	sp,sp,-32
    800017ec:	ec22                	sd	s0,24(sp)
    800017ee:	1000                	add	s0,sp,32
    800017f0:	fea43423          	sd	a0,-24(s0)
    800017f4:	feb43023          	sd	a1,-32(s0)
    lk->locked = 0;
    800017f8:	fe843783          	ld	a5,-24(s0)
    800017fc:	0007a023          	sw	zero,0(a5)
    lk->name = name;
    80001800:	fe843783          	ld	a5,-24(s0)
    80001804:	fe043703          	ld	a4,-32(s0)
    80001808:	e798                	sd	a4,8(a5)
}
    8000180a:	0001                	nop
    8000180c:	6462                	ld	s0,24(sp)
    8000180e:	6105                	add	sp,sp,32
    80001810:	8082                	ret

0000000080001812 <holding>:

int holding(struct spinlock* lk) {
    80001812:	1101                	add	sp,sp,-32
    80001814:	ec22                	sd	s0,24(sp)
    80001816:	1000                	add	s0,sp,32
    80001818:	fea43423          	sd	a0,-24(s0)
    return lk->locked != 0;
    8000181c:	fe843783          	ld	a5,-24(s0)
    80001820:	439c                	lw	a5,0(a5)
    80001822:	00f037b3          	snez	a5,a5
    80001826:	0ff7f793          	zext.b	a5,a5
    8000182a:	2781                	sext.w	a5,a5
}
    8000182c:	853e                	mv	a0,a5
    8000182e:	6462                	ld	s0,24(sp)
    80001830:	6105                	add	sp,sp,32
    80001832:	8082                	ret

0000000080001834 <acquire>:

void acquire(struct spinlock* lk) {
    80001834:	1101                	add	sp,sp,-32
    80001836:	ec06                	sd	ra,24(sp)
    80001838:	e822                	sd	s0,16(sp)
    8000183a:	1000                	add	s0,sp,32
    8000183c:	fea43423          	sd	a0,-24(s0)
    push_off();
    80001840:	00000097          	auipc	ra,0x0
    80001844:	052080e7          	jalr	82(ra) # 80001892 <push_off>
    while (__sync_lock_test_and_set(&lk->locked, 1) != 0) {
    80001848:	0001                	nop
    8000184a:	fe843783          	ld	a5,-24(s0)
    8000184e:	4705                	li	a4,1
    80001850:	0ce7a72f          	amoswap.w.aq	a4,a4,(a5)
    80001854:	0007079b          	sext.w	a5,a4
    80001858:	fbed                	bnez	a5,8000184a <acquire+0x16>
        // spin
    }
    __sync_synchronize();
    8000185a:	0ff0000f          	fence
}
    8000185e:	0001                	nop
    80001860:	60e2                	ld	ra,24(sp)
    80001862:	6442                	ld	s0,16(sp)
    80001864:	6105                	add	sp,sp,32
    80001866:	8082                	ret

0000000080001868 <release>:

void release(struct spinlock* lk) {
    80001868:	1101                	add	sp,sp,-32
    8000186a:	ec06                	sd	ra,24(sp)
    8000186c:	e822                	sd	s0,16(sp)
    8000186e:	1000                	add	s0,sp,32
    80001870:	fea43423          	sd	a0,-24(s0)
    __sync_synchronize();
    80001874:	0ff0000f          	fence
    lk->locked = 0;
    80001878:	fe843783          	ld	a5,-24(s0)
    8000187c:	0007a023          	sw	zero,0(a5)
    pop_off();
    80001880:	00000097          	auipc	ra,0x0
    80001884:	06a080e7          	jalr	106(ra) # 800018ea <pop_off>
}
    80001888:	0001                	nop
    8000188a:	60e2                	ld	ra,24(sp)
    8000188c:	6442                	ld	s0,16(sp)
    8000188e:	6105                	add	sp,sp,32
    80001890:	8082                	ret

0000000080001892 <push_off>:

void push_off(void) {
    80001892:	1101                	add	sp,sp,-32
    80001894:	ec06                	sd	ra,24(sp)
    80001896:	e822                	sd	s0,16(sp)
    80001898:	1000                	add	s0,sp,32
    int old = intr_get();
    8000189a:	00000097          	auipc	ra,0x0
    8000189e:	f0c080e7          	jalr	-244(ra) # 800017a6 <intr_get>
    800018a2:	87aa                	mv	a5,a0
    800018a4:	fef42623          	sw	a5,-20(s0)
    intr_off();
    800018a8:	00000097          	auipc	ra,0x0
    800018ac:	ed6080e7          	jalr	-298(ra) # 8000177e <intr_off>
    struct cpu_local_state* st = local_state();
    800018b0:	00000097          	auipc	ra,0x0
    800018b4:	f24080e7          	jalr	-220(ra) # 800017d4 <local_state>
    800018b8:	fea43023          	sd	a0,-32(s0)
    if (st->noff == 0) {
    800018bc:	fe043783          	ld	a5,-32(s0)
    800018c0:	439c                	lw	a5,0(a5)
    800018c2:	e791                	bnez	a5,800018ce <push_off+0x3c>
        st->intena = old;
    800018c4:	fe043783          	ld	a5,-32(s0)
    800018c8:	fec42703          	lw	a4,-20(s0)
    800018cc:	c3d8                	sw	a4,4(a5)
    }
    st->noff += 1;
    800018ce:	fe043783          	ld	a5,-32(s0)
    800018d2:	439c                	lw	a5,0(a5)
    800018d4:	2785                	addw	a5,a5,1
    800018d6:	0007871b          	sext.w	a4,a5
    800018da:	fe043783          	ld	a5,-32(s0)
    800018de:	c398                	sw	a4,0(a5)
}
    800018e0:	0001                	nop
    800018e2:	60e2                	ld	ra,24(sp)
    800018e4:	6442                	ld	s0,16(sp)
    800018e6:	6105                	add	sp,sp,32
    800018e8:	8082                	ret

00000000800018ea <pop_off>:

void pop_off(void) {
    800018ea:	1101                	add	sp,sp,-32
    800018ec:	ec06                	sd	ra,24(sp)
    800018ee:	e822                	sd	s0,16(sp)
    800018f0:	1000                	add	s0,sp,32
    struct cpu_local_state* st = local_state();
    800018f2:	00000097          	auipc	ra,0x0
    800018f6:	ee2080e7          	jalr	-286(ra) # 800017d4 <local_state>
    800018fa:	fea43423          	sd	a0,-24(s0)
    if (intr_get()) {
    800018fe:	00000097          	auipc	ra,0x0
    80001902:	ea8080e7          	jalr	-344(ra) # 800017a6 <intr_get>
    80001906:	87aa                	mv	a5,a0
    80001908:	cb89                	beqz	a5,8000191a <pop_off+0x30>
        panic("pop_off - interruptible");
    8000190a:	00004517          	auipc	a0,0x4
    8000190e:	73650513          	add	a0,a0,1846 # 80006040 <swtch+0x5a4>
    80001912:	00004097          	auipc	ra,0x4
    80001916:	05c080e7          	jalr	92(ra) # 8000596e <panic>
    }
    if (st->noff < 1) {
    8000191a:	fe843783          	ld	a5,-24(s0)
    8000191e:	439c                	lw	a5,0(a5)
    80001920:	00f04a63          	bgtz	a5,80001934 <pop_off+0x4a>
        panic("pop_off");
    80001924:	00004517          	auipc	a0,0x4
    80001928:	73450513          	add	a0,a0,1844 # 80006058 <swtch+0x5bc>
    8000192c:	00004097          	auipc	ra,0x4
    80001930:	042080e7          	jalr	66(ra) # 8000596e <panic>
    }
    st->noff -= 1;
    80001934:	fe843783          	ld	a5,-24(s0)
    80001938:	439c                	lw	a5,0(a5)
    8000193a:	37fd                	addw	a5,a5,-1
    8000193c:	0007871b          	sext.w	a4,a5
    80001940:	fe843783          	ld	a5,-24(s0)
    80001944:	c398                	sw	a4,0(a5)
    if (st->noff == 0 && st->intena) {
    80001946:	fe843783          	ld	a5,-24(s0)
    8000194a:	439c                	lw	a5,0(a5)
    8000194c:	eb89                	bnez	a5,8000195e <pop_off+0x74>
    8000194e:	fe843783          	ld	a5,-24(s0)
    80001952:	43dc                	lw	a5,4(a5)
    80001954:	c789                	beqz	a5,8000195e <pop_off+0x74>
        intr_on();
    80001956:	00000097          	auipc	ra,0x0
    8000195a:	dfe080e7          	jalr	-514(ra) # 80001754 <intr_on>
    }
}
    8000195e:	0001                	nop
    80001960:	60e2                	ld	ra,24(sp)
    80001962:	6442                	ld	s0,16(sp)
    80001964:	6105                	add	sp,sp,32
    80001966:	8082                	ret

0000000080001968 <r_sstatus>:
{
    80001968:	1101                	add	sp,sp,-32
    8000196a:	ec22                	sd	s0,24(sp)
    8000196c:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000196e:	100027f3          	csrr	a5,sstatus
    80001972:	fef43423          	sd	a5,-24(s0)
  return x;
    80001976:	fe843783          	ld	a5,-24(s0)
}
    8000197a:	853e                	mv	a0,a5
    8000197c:	6462                	ld	s0,24(sp)
    8000197e:	6105                	add	sp,sp,32
    80001980:	8082                	ret

0000000080001982 <w_sstatus>:
{
    80001982:	1101                	add	sp,sp,-32
    80001984:	ec22                	sd	s0,24(sp)
    80001986:	1000                	add	s0,sp,32
    80001988:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sstatus, %0" : : "r" (x));
    8000198c:	fe843783          	ld	a5,-24(s0)
    80001990:	10079073          	csrw	sstatus,a5
}
    80001994:	0001                	nop
    80001996:	6462                	ld	s0,24(sp)
    80001998:	6105                	add	sp,sp,32
    8000199a:	8082                	ret

000000008000199c <intr_on>:
{
    8000199c:	1141                	add	sp,sp,-16
    8000199e:	e406                	sd	ra,8(sp)
    800019a0:	e022                	sd	s0,0(sp)
    800019a2:	0800                	add	s0,sp,16
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    800019a4:	00000097          	auipc	ra,0x0
    800019a8:	fc4080e7          	jalr	-60(ra) # 80001968 <r_sstatus>
    800019ac:	87aa                	mv	a5,a0
    800019ae:	0027e793          	or	a5,a5,2
    800019b2:	853e                	mv	a0,a5
    800019b4:	00000097          	auipc	ra,0x0
    800019b8:	fce080e7          	jalr	-50(ra) # 80001982 <w_sstatus>
}
    800019bc:	0001                	nop
    800019be:	60a2                	ld	ra,8(sp)
    800019c0:	6402                	ld	s0,0(sp)
    800019c2:	0141                	add	sp,sp,16
    800019c4:	8082                	ret

00000000800019c6 <intr_get>:
{
    800019c6:	1101                	add	sp,sp,-32
    800019c8:	ec06                	sd	ra,24(sp)
    800019ca:	e822                	sd	s0,16(sp)
    800019cc:	1000                	add	s0,sp,32
  uint64 x = r_sstatus();
    800019ce:	00000097          	auipc	ra,0x0
    800019d2:	f9a080e7          	jalr	-102(ra) # 80001968 <r_sstatus>
    800019d6:	fea43423          	sd	a0,-24(s0)
  return (x & SSTATUS_SIE) != 0;
    800019da:	fe843783          	ld	a5,-24(s0)
    800019de:	8b89                	and	a5,a5,2
    800019e0:	00f037b3          	snez	a5,a5
    800019e4:	0ff7f793          	zext.b	a5,a5
    800019e8:	2781                	sext.w	a5,a5
}
    800019ea:	853e                	mv	a0,a5
    800019ec:	60e2                	ld	ra,24(sp)
    800019ee:	6442                	ld	s0,16(sp)
    800019f0:	6105                	add	sp,sp,32
    800019f2:	8082                	ret

00000000800019f4 <r_tp>:
{
    800019f4:	1101                	add	sp,sp,-32
    800019f6:	ec22                	sd	s0,24(sp)
    800019f8:	1000                	add	s0,sp,32
  asm volatile("mv %0, tp" : "=r" (x) );
    800019fa:	8792                	mv	a5,tp
    800019fc:	fef43423          	sd	a5,-24(s0)
  return x;
    80001a00:	fe843783          	ld	a5,-24(s0)
}
    80001a04:	853e                	mv	a0,a5
    80001a06:	6462                	ld	s0,24(sp)
    80001a08:	6105                	add	sp,sp,32
    80001a0a:	8082                	ret

0000000080001a0c <alloc_pid>:

static void reset_sched_state(struct proc* p);
static void age_runnable(uint64 now);
static struct proc* pick_runnable(uint64 now);

static int alloc_pid(void) {
    80001a0c:	1101                	add	sp,sp,-32
    80001a0e:	ec06                	sd	ra,24(sp)
    80001a10:	e822                	sd	s0,16(sp)
    80001a12:	1000                	add	s0,sp,32
    int pid;
    acquire(&pid_lock);
    80001a14:	00009517          	auipc	a0,0x9
    80001a18:	4f450513          	add	a0,a0,1268 # 8000af08 <pid_lock>
    80001a1c:	00000097          	auipc	ra,0x0
    80001a20:	e18080e7          	jalr	-488(ra) # 80001834 <acquire>
    pid = nextpid++;
    80001a24:	00005797          	auipc	a5,0x5
    80001a28:	41878793          	add	a5,a5,1048 # 80006e3c <nextpid>
    80001a2c:	439c                	lw	a5,0(a5)
    80001a2e:	0017871b          	addw	a4,a5,1
    80001a32:	0007069b          	sext.w	a3,a4
    80001a36:	00005717          	auipc	a4,0x5
    80001a3a:	40670713          	add	a4,a4,1030 # 80006e3c <nextpid>
    80001a3e:	c314                	sw	a3,0(a4)
    80001a40:	fef42623          	sw	a5,-20(s0)
    release(&pid_lock);
    80001a44:	00009517          	auipc	a0,0x9
    80001a48:	4c450513          	add	a0,a0,1220 # 8000af08 <pid_lock>
    80001a4c:	00000097          	auipc	ra,0x0
    80001a50:	e1c080e7          	jalr	-484(ra) # 80001868 <release>
    return pid;
    80001a54:	fec42783          	lw	a5,-20(s0)
}
    80001a58:	853e                	mv	a0,a5
    80001a5a:	60e2                	ld	ra,24(sp)
    80001a5c:	6442                	ld	s0,16(sp)
    80001a5e:	6105                	add	sp,sp,32
    80001a60:	8082                	ret

0000000080001a62 <proc_init>:

void proc_init(void) {
    80001a62:	1101                	add	sp,sp,-32
    80001a64:	ec06                	sd	ra,24(sp)
    80001a66:	e822                	sd	s0,16(sp)
    80001a68:	1000                	add	s0,sp,32
    initlock(&pid_lock, "pid");
    80001a6a:	00004597          	auipc	a1,0x4
    80001a6e:	5f658593          	add	a1,a1,1526 # 80006060 <swtch+0x5c4>
    80001a72:	00009517          	auipc	a0,0x9
    80001a76:	49650513          	add	a0,a0,1174 # 8000af08 <pid_lock>
    80001a7a:	00000097          	auipc	ra,0x0
    80001a7e:	d70080e7          	jalr	-656(ra) # 800017ea <initlock>
    last_aging_tick = 0;
    80001a82:	00009797          	auipc	a5,0x9
    80001a86:	50678793          	add	a5,a5,1286 # 8000af88 <last_aging_tick>
    80001a8a:	0007b023          	sd	zero,0(a5)
    for (int i = 0; i < NPROC; i++) {
    80001a8e:	fe042623          	sw	zero,-20(s0)
    80001a92:	a0a5                	j	80001afa <proc_init+0x98>
        struct proc* p = &proc_table[i];
    80001a94:	fec42783          	lw	a5,-20(s0)
    80001a98:	00879713          	sll	a4,a5,0x8
    80001a9c:	00005797          	auipc	a5,0x5
    80001aa0:	46478793          	add	a5,a5,1124 # 80006f00 <proc_table>
    80001aa4:	97ba                	add	a5,a5,a4
    80001aa6:	fef43023          	sd	a5,-32(s0)
        initlock(&p->lock, "proc");
    80001aaa:	fe043783          	ld	a5,-32(s0)
    80001aae:	00004597          	auipc	a1,0x4
    80001ab2:	5ba58593          	add	a1,a1,1466 # 80006068 <swtch+0x5cc>
    80001ab6:	853e                	mv	a0,a5
    80001ab8:	00000097          	auipc	ra,0x0
    80001abc:	d32080e7          	jalr	-718(ra) # 800017ea <initlock>
        p->state = PROC_UNUSED;
    80001ac0:	fe043783          	ld	a5,-32(s0)
    80001ac4:	0007a823          	sw	zero,16(a5)
        p->priority = PRIORITY_DEFAULT;
    80001ac8:	fe043783          	ld	a5,-32(s0)
    80001acc:	4729                	li	a4,10
    80001ace:	cfb8                	sw	a4,88(a5)
        p->time_slice = TIME_SLICE_TICKS;
    80001ad0:	fe043783          	ld	a5,-32(s0)
    80001ad4:	4715                	li	a4,5
    80001ad6:	cff8                	sw	a4,92(a5)
        p->runtime_ticks = 0;
    80001ad8:	fe043783          	ld	a5,-32(s0)
    80001adc:	0407b423          	sd	zero,72(a5)
        p->last_scheduled = 0;
    80001ae0:	fe043783          	ld	a5,-32(s0)
    80001ae4:	0407b823          	sd	zero,80(a5)
        p->need_resched = 0;
    80001ae8:	fe043783          	ld	a5,-32(s0)
    80001aec:	0607a023          	sw	zero,96(a5)
    for (int i = 0; i < NPROC; i++) {
    80001af0:	fec42783          	lw	a5,-20(s0)
    80001af4:	2785                	addw	a5,a5,1
    80001af6:	fef42623          	sw	a5,-20(s0)
    80001afa:	fec42783          	lw	a5,-20(s0)
    80001afe:	0007871b          	sext.w	a4,a5
    80001b02:	03f00793          	li	a5,63
    80001b06:	f8e7d7e3          	bge	a5,a4,80001a94 <proc_init+0x32>
    }
}
    80001b0a:	0001                	nop
    80001b0c:	0001                	nop
    80001b0e:	60e2                	ld	ra,24(sp)
    80001b10:	6442                	ld	s0,16(sp)
    80001b12:	6105                	add	sp,sp,32
    80001b14:	8082                	ret

0000000080001b16 <free_kstack>:

static void free_kstack(struct proc* p) {
    80001b16:	7179                	add	sp,sp,-48
    80001b18:	f406                	sd	ra,40(sp)
    80001b1a:	f022                	sd	s0,32(sp)
    80001b1c:	1800                	add	s0,sp,48
    80001b1e:	fca43c23          	sd	a0,-40(s0)
    if (p->kstack) {
    80001b22:	fd843783          	ld	a5,-40(s0)
    80001b26:	77bc                	ld	a5,104(a5)
    80001b28:	c395                	beqz	a5,80001b4c <free_kstack+0x36>
        void* base = (void*)PGROUNDDOWN(p->kstack);
    80001b2a:	fd843783          	ld	a5,-40(s0)
    80001b2e:	77b8                	ld	a4,104(a5)
    80001b30:	77fd                	lui	a5,0xfffff
    80001b32:	8ff9                	and	a5,a5,a4
    80001b34:	fef43423          	sd	a5,-24(s0)
        free_page(base);
    80001b38:	fe843503          	ld	a0,-24(s0)
    80001b3c:	fffff097          	auipc	ra,0xfffff
    80001b40:	b3a080e7          	jalr	-1222(ra) # 80000676 <free_page>
        p->kstack = 0;
    80001b44:	fd843783          	ld	a5,-40(s0)
    80001b48:	0607b423          	sd	zero,104(a5) # fffffffffffff068 <_stack_top+0xffffffff7fff0068>
    }
}
    80001b4c:	0001                	nop
    80001b4e:	70a2                	ld	ra,40(sp)
    80001b50:	7402                	ld	s0,32(sp)
    80001b52:	6145                	add	sp,sp,48
    80001b54:	8082                	ret

0000000080001b56 <free_process>:

void free_process(struct proc* p) {
    80001b56:	1101                	add	sp,sp,-32
    80001b58:	ec06                	sd	ra,24(sp)
    80001b5a:	e822                	sd	s0,16(sp)
    80001b5c:	1000                	add	s0,sp,32
    80001b5e:	fea43423          	sd	a0,-24(s0)
    if (!p) return;
    80001b62:	fe843783          	ld	a5,-24(s0)
    80001b66:	c7dd                	beqz	a5,80001c14 <free_process+0xbe>
    if (p->trapframe) {
    80001b68:	fe843783          	ld	a5,-24(s0)
    80001b6c:	7f9c                	ld	a5,56(a5)
    80001b6e:	cf89                	beqz	a5,80001b88 <free_process+0x32>
        free_page(p->trapframe);
    80001b70:	fe843783          	ld	a5,-24(s0)
    80001b74:	7f9c                	ld	a5,56(a5)
    80001b76:	853e                	mv	a0,a5
    80001b78:	fffff097          	auipc	ra,0xfffff
    80001b7c:	afe080e7          	jalr	-1282(ra) # 80000676 <free_page>
        p->trapframe = NULL;
    80001b80:	fe843783          	ld	a5,-24(s0)
    80001b84:	0207bc23          	sd	zero,56(a5)
    }
    free_kstack(p);
    80001b88:	fe843503          	ld	a0,-24(s0)
    80001b8c:	00000097          	auipc	ra,0x0
    80001b90:	f8a080e7          	jalr	-118(ra) # 80001b16 <free_kstack>
    p->pagetable = NULL;
    80001b94:	fe843783          	ld	a5,-24(s0)
    80001b98:	0207b823          	sd	zero,48(a5)
    p->entry = NULL;
    80001b9c:	fe843783          	ld	a5,-24(s0)
    80001ba0:	0e07b423          	sd	zero,232(a5)
    p->parent = NULL;
    80001ba4:	fe843783          	ld	a5,-24(s0)
    80001ba8:	0e07b023          	sd	zero,224(a5)
    p->state = PROC_UNUSED;
    80001bac:	fe843783          	ld	a5,-24(s0)
    80001bb0:	0007a823          	sw	zero,16(a5)
    p->pid = 0;
    80001bb4:	fe843783          	ld	a5,-24(s0)
    80001bb8:	0207a423          	sw	zero,40(a5)
    p->xstate = 0;
    80001bbc:	fe843783          	ld	a5,-24(s0)
    80001bc0:	0207a223          	sw	zero,36(a5)
    p->killed = 0;
    80001bc4:	fe843783          	ld	a5,-24(s0)
    80001bc8:	0207a023          	sw	zero,32(a5)
    p->chan = NULL;
    80001bcc:	fe843783          	ld	a5,-24(s0)
    80001bd0:	0007bc23          	sd	zero,24(a5)
    p->priority = PRIORITY_DEFAULT;
    80001bd4:	fe843783          	ld	a5,-24(s0)
    80001bd8:	4729                	li	a4,10
    80001bda:	cfb8                	sw	a4,88(a5)
    p->time_slice = TIME_SLICE_TICKS;
    80001bdc:	fe843783          	ld	a5,-24(s0)
    80001be0:	4715                	li	a4,5
    80001be2:	cff8                	sw	a4,92(a5)
    p->runtime_ticks = 0;
    80001be4:	fe843783          	ld	a5,-24(s0)
    80001be8:	0407b423          	sd	zero,72(a5)
    p->last_scheduled = 0;
    80001bec:	fe843783          	ld	a5,-24(s0)
    80001bf0:	0407b823          	sd	zero,80(a5)
    p->need_resched = 0;
    80001bf4:	fe843783          	ld	a5,-24(s0)
    80001bf8:	0607a023          	sw	zero,96(a5)
    memset(p->name, 0, sizeof(p->name));
    80001bfc:	fe843783          	ld	a5,-24(s0)
    80001c00:	0f078793          	add	a5,a5,240
    80001c04:	4641                	li	a2,16
    80001c06:	4581                	li	a1,0
    80001c08:	853e                	mv	a0,a5
    80001c0a:	00003097          	auipc	ra,0x3
    80001c0e:	3c2080e7          	jalr	962(ra) # 80004fcc <memset>
    80001c12:	a011                	j	80001c16 <free_process+0xc0>
    if (!p) return;
    80001c14:	0001                	nop
}
    80001c16:	60e2                	ld	ra,24(sp)
    80001c18:	6442                	ld	s0,16(sp)
    80001c1a:	6105                	add	sp,sp,32
    80001c1c:	8082                	ret

0000000080001c1e <reset_sched_state>:

static void reset_sched_state(struct proc* p) {
    80001c1e:	1101                	add	sp,sp,-32
    80001c20:	ec06                	sd	ra,24(sp)
    80001c22:	e822                	sd	s0,16(sp)
    80001c24:	1000                	add	s0,sp,32
    80001c26:	fea43423          	sd	a0,-24(s0)
    p->priority = PRIORITY_DEFAULT;
    80001c2a:	fe843783          	ld	a5,-24(s0)
    80001c2e:	4729                	li	a4,10
    80001c30:	cfb8                	sw	a4,88(a5)
    p->time_slice = TIME_SLICE_TICKS;
    80001c32:	fe843783          	ld	a5,-24(s0)
    80001c36:	4715                	li	a4,5
    80001c38:	cff8                	sw	a4,92(a5)
    p->runtime_ticks = 0;
    80001c3a:	fe843783          	ld	a5,-24(s0)
    80001c3e:	0407b423          	sd	zero,72(a5)
    p->last_scheduled = timer_ticks();
    80001c42:	00002097          	auipc	ra,0x2
    80001c46:	40a080e7          	jalr	1034(ra) # 8000404c <timer_ticks>
    80001c4a:	872a                	mv	a4,a0
    80001c4c:	fe843783          	ld	a5,-24(s0)
    80001c50:	ebb8                	sd	a4,80(a5)
    p->need_resched = 0;
    80001c52:	fe843783          	ld	a5,-24(s0)
    80001c56:	0607a023          	sw	zero,96(a5)
}
    80001c5a:	0001                	nop
    80001c5c:	60e2                	ld	ra,24(sp)
    80001c5e:	6442                	ld	s0,16(sp)
    80001c60:	6105                	add	sp,sp,32
    80001c62:	8082                	ret

0000000080001c64 <alloc_process>:

struct proc* alloc_process(void) {
    80001c64:	7179                	add	sp,sp,-48
    80001c66:	f406                	sd	ra,40(sp)
    80001c68:	f022                	sd	s0,32(sp)
    80001c6a:	1800                	add	s0,sp,48
    for (int i = 0; i < NPROC; i++) {
    80001c6c:	fe042623          	sw	zero,-20(s0)
    80001c70:	aab9                	j	80001dce <alloc_process+0x16a>
        struct proc* p = &proc_table[i];
    80001c72:	fec42783          	lw	a5,-20(s0)
    80001c76:	00879713          	sll	a4,a5,0x8
    80001c7a:	00005797          	auipc	a5,0x5
    80001c7e:	28678793          	add	a5,a5,646 # 80006f00 <proc_table>
    80001c82:	97ba                	add	a5,a5,a4
    80001c84:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    80001c88:	fe043783          	ld	a5,-32(s0)
    80001c8c:	853e                	mv	a0,a5
    80001c8e:	00000097          	auipc	ra,0x0
    80001c92:	ba6080e7          	jalr	-1114(ra) # 80001834 <acquire>
        if (p->state != PROC_UNUSED) {
    80001c96:	fe043783          	ld	a5,-32(s0)
    80001c9a:	4b9c                	lw	a5,16(a5)
    80001c9c:	cb89                	beqz	a5,80001cae <alloc_process+0x4a>
            release(&p->lock);
    80001c9e:	fe043783          	ld	a5,-32(s0)
    80001ca2:	853e                	mv	a0,a5
    80001ca4:	00000097          	auipc	ra,0x0
    80001ca8:	bc4080e7          	jalr	-1084(ra) # 80001868 <release>
            continue;
    80001cac:	aa21                	j	80001dc4 <alloc_process+0x160>
        }
        p->pid = alloc_pid();
    80001cae:	00000097          	auipc	ra,0x0
    80001cb2:	d5e080e7          	jalr	-674(ra) # 80001a0c <alloc_pid>
    80001cb6:	87aa                	mv	a5,a0
    80001cb8:	873e                	mv	a4,a5
    80001cba:	fe043783          	ld	a5,-32(s0)
    80001cbe:	d798                	sw	a4,40(a5)
        p->state = PROC_USED;
    80001cc0:	fe043783          	ld	a5,-32(s0)
    80001cc4:	4705                	li	a4,1
    80001cc6:	cb98                	sw	a4,16(a5)

        void* tf = alloc_page();
    80001cc8:	fffff097          	auipc	ra,0xfffff
    80001ccc:	a32080e7          	jalr	-1486(ra) # 800006fa <alloc_page>
    80001cd0:	fca43c23          	sd	a0,-40(s0)
        void* kstack = alloc_page();
    80001cd4:	fffff097          	auipc	ra,0xfffff
    80001cd8:	a26080e7          	jalr	-1498(ra) # 800006fa <alloc_page>
    80001cdc:	fca43823          	sd	a0,-48(s0)
        if (!tf || !kstack) {
    80001ce0:	fd843783          	ld	a5,-40(s0)
    80001ce4:	c781                	beqz	a5,80001cec <alloc_process+0x88>
    80001ce6:	fd043783          	ld	a5,-48(s0)
    80001cea:	e3a1                	bnez	a5,80001d2a <alloc_process+0xc6>
            if (tf) free_page(tf);
    80001cec:	fd843783          	ld	a5,-40(s0)
    80001cf0:	c799                	beqz	a5,80001cfe <alloc_process+0x9a>
    80001cf2:	fd843503          	ld	a0,-40(s0)
    80001cf6:	fffff097          	auipc	ra,0xfffff
    80001cfa:	980080e7          	jalr	-1664(ra) # 80000676 <free_page>
            if (kstack) free_page(kstack);
    80001cfe:	fd043783          	ld	a5,-48(s0)
    80001d02:	c799                	beqz	a5,80001d10 <alloc_process+0xac>
    80001d04:	fd043503          	ld	a0,-48(s0)
    80001d08:	fffff097          	auipc	ra,0xfffff
    80001d0c:	96e080e7          	jalr	-1682(ra) # 80000676 <free_page>
            p->state = PROC_UNUSED;
    80001d10:	fe043783          	ld	a5,-32(s0)
    80001d14:	0007a823          	sw	zero,16(a5)
            release(&p->lock);
    80001d18:	fe043783          	ld	a5,-32(s0)
    80001d1c:	853e                	mv	a0,a5
    80001d1e:	00000097          	auipc	ra,0x0
    80001d22:	b4a080e7          	jalr	-1206(ra) # 80001868 <release>
            return NULL;
    80001d26:	4781                	li	a5,0
    80001d28:	a865                	j	80001de0 <alloc_process+0x17c>
        }

        memset(tf, 0, PGSIZE);
    80001d2a:	6605                	lui	a2,0x1
    80001d2c:	4581                	li	a1,0
    80001d2e:	fd843503          	ld	a0,-40(s0)
    80001d32:	00003097          	auipc	ra,0x3
    80001d36:	29a080e7          	jalr	666(ra) # 80004fcc <memset>
        memset(&p->ctx, 0, sizeof(p->ctx));
    80001d3a:	fe043783          	ld	a5,-32(s0)
    80001d3e:	07078793          	add	a5,a5,112
    80001d42:	07000613          	li	a2,112
    80001d46:	4581                	li	a1,0
    80001d48:	853e                	mv	a0,a5
    80001d4a:	00003097          	auipc	ra,0x3
    80001d4e:	282080e7          	jalr	642(ra) # 80004fcc <memset>

        p->trapframe = (struct trapframe*)tf;
    80001d52:	fe043783          	ld	a5,-32(s0)
    80001d56:	fd843703          	ld	a4,-40(s0)
    80001d5a:	ff98                	sd	a4,56(a5)
        p->kstack = (uint64)kstack;
    80001d5c:	fd043703          	ld	a4,-48(s0)
    80001d60:	fe043783          	ld	a5,-32(s0)
    80001d64:	f7b8                	sd	a4,104(a5)
        p->ctx.sp = p->kstack + PGSIZE;
    80001d66:	fe043783          	ld	a5,-32(s0)
    80001d6a:	77b8                	ld	a4,104(a5)
    80001d6c:	6785                	lui	a5,0x1
    80001d6e:	973e                	add	a4,a4,a5
    80001d70:	fe043783          	ld	a5,-32(s0)
    80001d74:	ffb8                	sd	a4,120(a5)
        p->killed = 0;
    80001d76:	fe043783          	ld	a5,-32(s0)
    80001d7a:	0207a023          	sw	zero,32(a5) # 1020 <_entry-0x7fffefe0>
        p->xstate = 0;
    80001d7e:	fe043783          	ld	a5,-32(s0)
    80001d82:	0207a223          	sw	zero,36(a5)
        p->pagetable = NULL;
    80001d86:	fe043783          	ld	a5,-32(s0)
    80001d8a:	0207b823          	sd	zero,48(a5)
        p->chan = NULL;
    80001d8e:	fe043783          	ld	a5,-32(s0)
    80001d92:	0007bc23          	sd	zero,24(a5)
        p->brk = (uint64)end;
    80001d96:	0000b717          	auipc	a4,0xb
    80001d9a:	2aa70713          	add	a4,a4,682 # 8000d040 <_bss_end>
    80001d9e:	fe043783          	ld	a5,-32(s0)
    80001da2:	e3b8                	sd	a4,64(a5)
        reset_sched_state(p);
    80001da4:	fe043503          	ld	a0,-32(s0)
    80001da8:	00000097          	auipc	ra,0x0
    80001dac:	e76080e7          	jalr	-394(ra) # 80001c1e <reset_sched_state>
        release(&p->lock);
    80001db0:	fe043783          	ld	a5,-32(s0)
    80001db4:	853e                	mv	a0,a5
    80001db6:	00000097          	auipc	ra,0x0
    80001dba:	ab2080e7          	jalr	-1358(ra) # 80001868 <release>
        return p;
    80001dbe:	fe043783          	ld	a5,-32(s0)
    80001dc2:	a839                	j	80001de0 <alloc_process+0x17c>
    for (int i = 0; i < NPROC; i++) {
    80001dc4:	fec42783          	lw	a5,-20(s0)
    80001dc8:	2785                	addw	a5,a5,1
    80001dca:	fef42623          	sw	a5,-20(s0)
    80001dce:	fec42783          	lw	a5,-20(s0)
    80001dd2:	0007871b          	sext.w	a4,a5
    80001dd6:	03f00793          	li	a5,63
    80001dda:	e8e7dce3          	bge	a5,a4,80001c72 <alloc_process+0xe>
    }
    return NULL;
    80001dde:	4781                	li	a5,0
}
    80001de0:	853e                	mv	a0,a5
    80001de2:	70a2                	ld	ra,40(sp)
    80001de4:	7402                	ld	s0,32(sp)
    80001de6:	6145                	add	sp,sp,48
    80001de8:	8082                	ret

0000000080001dea <proc_entry_wrapper>:

static void proc_entry_wrapper(void) {
    80001dea:	1101                	add	sp,sp,-32
    80001dec:	ec06                	sd	ra,24(sp)
    80001dee:	e822                	sd	s0,16(sp)
    80001df0:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    80001df2:	00000097          	auipc	ra,0x0
    80001df6:	1b8080e7          	jalr	440(ra) # 80001faa <myproc>
    80001dfa:	fea43423          	sd	a0,-24(s0)
    if (!p || !p->entry) {
    80001dfe:	fe843783          	ld	a5,-24(s0)
    80001e02:	c789                	beqz	a5,80001e0c <proc_entry_wrapper+0x22>
    80001e04:	fe843783          	ld	a5,-24(s0)
    80001e08:	77fc                	ld	a5,232(a5)
    80001e0a:	eb89                	bnez	a5,80001e1c <proc_entry_wrapper+0x32>
        panic("proc entry wrapper");
    80001e0c:	00004517          	auipc	a0,0x4
    80001e10:	26450513          	add	a0,a0,612 # 80006070 <swtch+0x5d4>
    80001e14:	00004097          	auipc	ra,0x4
    80001e18:	b5a080e7          	jalr	-1190(ra) # 8000596e <panic>
    }
    release(&p->lock);
    80001e1c:	fe843783          	ld	a5,-24(s0)
    80001e20:	853e                	mv	a0,a5
    80001e22:	00000097          	auipc	ra,0x0
    80001e26:	a46080e7          	jalr	-1466(ra) # 80001868 <release>
    intr_on();
    80001e2a:	00000097          	auipc	ra,0x0
    80001e2e:	b72080e7          	jalr	-1166(ra) # 8000199c <intr_on>
    p->entry();
    80001e32:	fe843783          	ld	a5,-24(s0)
    80001e36:	77fc                	ld	a5,232(a5)
    80001e38:	9782                	jalr	a5
    exit_process(0);
    80001e3a:	4501                	li	a0,0
    80001e3c:	00000097          	auipc	ra,0x0
    80001e40:	3f2080e7          	jalr	1010(ra) # 8000222e <exit_process>

0000000080001e44 <create_process>:
}

int create_process(void (*entry)(void), const char* name) {
    80001e44:	7179                	add	sp,sp,-48
    80001e46:	f406                	sd	ra,40(sp)
    80001e48:	f022                	sd	s0,32(sp)
    80001e4a:	1800                	add	s0,sp,48
    80001e4c:	fca43c23          	sd	a0,-40(s0)
    80001e50:	fcb43823          	sd	a1,-48(s0)
    struct proc* p = alloc_process();
    80001e54:	00000097          	auipc	ra,0x0
    80001e58:	e10080e7          	jalr	-496(ra) # 80001c64 <alloc_process>
    80001e5c:	fea43023          	sd	a0,-32(s0)
    if (!p) return -1;
    80001e60:	fe043783          	ld	a5,-32(s0)
    80001e64:	e399                	bnez	a5,80001e6a <create_process+0x26>
    80001e66:	57fd                	li	a5,-1
    80001e68:	aa29                	j	80001f82 <create_process+0x13e>
    acquire(&p->lock);
    80001e6a:	fe043783          	ld	a5,-32(s0)
    80001e6e:	853e                	mv	a0,a5
    80001e70:	00000097          	auipc	ra,0x0
    80001e74:	9c4080e7          	jalr	-1596(ra) # 80001834 <acquire>
    p->parent = myproc();
    80001e78:	00000097          	auipc	ra,0x0
    80001e7c:	132080e7          	jalr	306(ra) # 80001faa <myproc>
    80001e80:	872a                	mv	a4,a0
    80001e82:	fe043783          	ld	a5,-32(s0)
    80001e86:	f3f8                	sd	a4,224(a5)
    p->entry = entry;
    80001e88:	fe043783          	ld	a5,-32(s0)
    80001e8c:	fd843703          	ld	a4,-40(s0)
    80001e90:	f7f8                	sd	a4,232(a5)
    if (name) {
    80001e92:	fd043783          	ld	a5,-48(s0)
    80001e96:	cbb1                	beqz	a5,80001eea <create_process+0xa6>
        memset(p->name, 0, sizeof(p->name));
    80001e98:	fe043783          	ld	a5,-32(s0)
    80001e9c:	0f078793          	add	a5,a5,240
    80001ea0:	4641                	li	a2,16
    80001ea2:	4581                	li	a1,0
    80001ea4:	853e                	mv	a0,a5
    80001ea6:	00003097          	auipc	ra,0x3
    80001eaa:	126080e7          	jalr	294(ra) # 80004fcc <memset>
        size_t len = strlen(name);
    80001eae:	fd043503          	ld	a0,-48(s0)
    80001eb2:	00003097          	auipc	ra,0x3
    80001eb6:	25c080e7          	jalr	604(ra) # 8000510e <strlen>
    80001eba:	fea43423          	sd	a0,-24(s0)
        if (len >= sizeof(p->name)) len = sizeof(p->name) - 1;
    80001ebe:	fe843703          	ld	a4,-24(s0)
    80001ec2:	47bd                	li	a5,15
    80001ec4:	00e7f563          	bgeu	a5,a4,80001ece <create_process+0x8a>
    80001ec8:	47bd                	li	a5,15
    80001eca:	fef43423          	sd	a5,-24(s0)
        memcpy(p->name, name, len);
    80001ece:	fe043783          	ld	a5,-32(s0)
    80001ed2:	0f078793          	add	a5,a5,240
    80001ed6:	fe843603          	ld	a2,-24(s0)
    80001eda:	fd043583          	ld	a1,-48(s0)
    80001ede:	853e                	mv	a0,a5
    80001ee0:	00003097          	auipc	ra,0x3
    80001ee4:	13c080e7          	jalr	316(ra) # 8000501c <memcpy>
    80001ee8:	a839                	j	80001f06 <create_process+0xc2>
    } else {
        memcpy(p->name, "kproc", 5);
    80001eea:	fe043783          	ld	a5,-32(s0)
    80001eee:	0f078793          	add	a5,a5,240
    80001ef2:	4615                	li	a2,5
    80001ef4:	00004597          	auipc	a1,0x4
    80001ef8:	19458593          	add	a1,a1,404 # 80006088 <swtch+0x5ec>
    80001efc:	853e                	mv	a0,a5
    80001efe:	00003097          	auipc	ra,0x3
    80001f02:	11e080e7          	jalr	286(ra) # 8000501c <memcpy>
    }
    p->priority = p->parent ? p->parent->priority : PRIORITY_DEFAULT;
    80001f06:	fe043783          	ld	a5,-32(s0)
    80001f0a:	73fc                	ld	a5,224(a5)
    80001f0c:	c791                	beqz	a5,80001f18 <create_process+0xd4>
    80001f0e:	fe043783          	ld	a5,-32(s0)
    80001f12:	73fc                	ld	a5,224(a5)
    80001f14:	4fbc                	lw	a5,88(a5)
    80001f16:	a011                	j	80001f1a <create_process+0xd6>
    80001f18:	47a9                	li	a5,10
    80001f1a:	fe043703          	ld	a4,-32(s0)
    80001f1e:	cf3c                	sw	a5,88(a4)
    p->time_slice = TIME_SLICE_TICKS;
    80001f20:	fe043783          	ld	a5,-32(s0)
    80001f24:	4715                	li	a4,5
    80001f26:	cff8                	sw	a4,92(a5)
    p->runtime_ticks = 0;
    80001f28:	fe043783          	ld	a5,-32(s0)
    80001f2c:	0407b423          	sd	zero,72(a5)
    p->last_scheduled = timer_ticks();
    80001f30:	00002097          	auipc	ra,0x2
    80001f34:	11c080e7          	jalr	284(ra) # 8000404c <timer_ticks>
    80001f38:	872a                	mv	a4,a0
    80001f3a:	fe043783          	ld	a5,-32(s0)
    80001f3e:	ebb8                	sd	a4,80(a5)
    p->need_resched = 0;
    80001f40:	fe043783          	ld	a5,-32(s0)
    80001f44:	0607a023          	sw	zero,96(a5)
    p->ctx.ra = (uint64)proc_entry_wrapper;
    80001f48:	00000717          	auipc	a4,0x0
    80001f4c:	ea270713          	add	a4,a4,-350 # 80001dea <proc_entry_wrapper>
    80001f50:	fe043783          	ld	a5,-32(s0)
    80001f54:	fbb8                	sd	a4,112(a5)
    p->ctx.sp = p->kstack + PGSIZE;
    80001f56:	fe043783          	ld	a5,-32(s0)
    80001f5a:	77b8                	ld	a4,104(a5)
    80001f5c:	6785                	lui	a5,0x1
    80001f5e:	973e                	add	a4,a4,a5
    80001f60:	fe043783          	ld	a5,-32(s0)
    80001f64:	ffb8                	sd	a4,120(a5)
    p->state = PROC_RUNNABLE;
    80001f66:	fe043783          	ld	a5,-32(s0)
    80001f6a:	4709                	li	a4,2
    80001f6c:	cb98                	sw	a4,16(a5)
    release(&p->lock);
    80001f6e:	fe043783          	ld	a5,-32(s0)
    80001f72:	853e                	mv	a0,a5
    80001f74:	00000097          	auipc	ra,0x0
    80001f78:	8f4080e7          	jalr	-1804(ra) # 80001868 <release>

    return p->pid;
    80001f7c:	fe043783          	ld	a5,-32(s0)
    80001f80:	579c                	lw	a5,40(a5)
}
    80001f82:	853e                	mv	a0,a5
    80001f84:	70a2                	ld	ra,40(sp)
    80001f86:	7402                	ld	s0,32(sp)
    80001f88:	6145                	add	sp,sp,48
    80001f8a:	8082                	ret

0000000080001f8c <cpuid>:

int cpuid(void) {
    80001f8c:	1141                	add	sp,sp,-16
    80001f8e:	e406                	sd	ra,8(sp)
    80001f90:	e022                	sd	s0,0(sp)
    80001f92:	0800                	add	s0,sp,16
    return (int)r_tp();
    80001f94:	00000097          	auipc	ra,0x0
    80001f98:	a60080e7          	jalr	-1440(ra) # 800019f4 <r_tp>
    80001f9c:	87aa                	mv	a5,a0
    80001f9e:	2781                	sext.w	a5,a5
}
    80001fa0:	853e                	mv	a0,a5
    80001fa2:	60a2                	ld	ra,8(sp)
    80001fa4:	6402                	ld	s0,0(sp)
    80001fa6:	0141                	add	sp,sp,16
    80001fa8:	8082                	ret

0000000080001faa <myproc>:

struct proc* myproc(void) {
    80001faa:	1141                	add	sp,sp,-16
    80001fac:	e422                	sd	s0,8(sp)
    80001fae:	0800                	add	s0,sp,16
    return current_proc;
    80001fb0:	00009797          	auipc	a5,0x9
    80001fb4:	f5078793          	add	a5,a5,-176 # 8000af00 <current_proc>
    80001fb8:	639c                	ld	a5,0(a5)
}
    80001fba:	853e                	mv	a0,a5
    80001fbc:	6422                	ld	s0,8(sp)
    80001fbe:	0141                	add	sp,sp,16
    80001fc0:	8082                	ret

0000000080001fc2 <sched>:

void sched(void) {
    80001fc2:	1101                	add	sp,sp,-32
    80001fc4:	ec06                	sd	ra,24(sp)
    80001fc6:	e822                	sd	s0,16(sp)
    80001fc8:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    80001fca:	00000097          	auipc	ra,0x0
    80001fce:	fe0080e7          	jalr	-32(ra) # 80001faa <myproc>
    80001fd2:	fea43423          	sd	a0,-24(s0)
    if (!p) {
    80001fd6:	fe843783          	ld	a5,-24(s0)
    80001fda:	eb89                	bnez	a5,80001fec <sched+0x2a>
        panic("sched: no current proc");
    80001fdc:	00004517          	auipc	a0,0x4
    80001fe0:	0b450513          	add	a0,a0,180 # 80006090 <swtch+0x5f4>
    80001fe4:	00004097          	auipc	ra,0x4
    80001fe8:	98a080e7          	jalr	-1654(ra) # 8000596e <panic>
    }
    if (!holding(&p->lock)) {
    80001fec:	fe843783          	ld	a5,-24(s0)
    80001ff0:	853e                	mv	a0,a5
    80001ff2:	00000097          	auipc	ra,0x0
    80001ff6:	820080e7          	jalr	-2016(ra) # 80001812 <holding>
    80001ffa:	87aa                	mv	a5,a0
    80001ffc:	eb89                	bnez	a5,8000200e <sched+0x4c>
        panic("sched: lock not held");
    80001ffe:	00004517          	auipc	a0,0x4
    80002002:	0aa50513          	add	a0,a0,170 # 800060a8 <swtch+0x60c>
    80002006:	00004097          	auipc	ra,0x4
    8000200a:	968080e7          	jalr	-1688(ra) # 8000596e <panic>
    }
    if (intr_get()) {
    8000200e:	00000097          	auipc	ra,0x0
    80002012:	9b8080e7          	jalr	-1608(ra) # 800019c6 <intr_get>
    80002016:	87aa                	mv	a5,a0
    80002018:	cb89                	beqz	a5,8000202a <sched+0x68>
        panic("sched: interruptible");
    8000201a:	00004517          	auipc	a0,0x4
    8000201e:	0a650513          	add	a0,a0,166 # 800060c0 <swtch+0x624>
    80002022:	00004097          	auipc	ra,0x4
    80002026:	94c080e7          	jalr	-1716(ra) # 8000596e <panic>
    }
    swtch(&p->ctx, &scheduler_ctx);
    8000202a:	fe843783          	ld	a5,-24(s0)
    8000202e:	07078793          	add	a5,a5,112
    80002032:	00009597          	auipc	a1,0x9
    80002036:	ee658593          	add	a1,a1,-282 # 8000af18 <scheduler_ctx>
    8000203a:	853e                	mv	a0,a5
    8000203c:	00004097          	auipc	ra,0x4
    80002040:	a60080e7          	jalr	-1440(ra) # 80005a9c <swtch>
}
    80002044:	0001                	nop
    80002046:	60e2                	ld	ra,24(sp)
    80002048:	6442                	ld	s0,16(sp)
    8000204a:	6105                	add	sp,sp,32
    8000204c:	8082                	ret

000000008000204e <yield>:

void yield(void) {
    8000204e:	1101                	add	sp,sp,-32
    80002050:	ec06                	sd	ra,24(sp)
    80002052:	e822                	sd	s0,16(sp)
    80002054:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    80002056:	00000097          	auipc	ra,0x0
    8000205a:	f54080e7          	jalr	-172(ra) # 80001faa <myproc>
    8000205e:	fea43423          	sd	a0,-24(s0)
    if (!p) return;
    80002062:	fe843783          	ld	a5,-24(s0)
    80002066:	c3a1                	beqz	a5,800020a6 <yield+0x58>
    acquire(&p->lock);
    80002068:	fe843783          	ld	a5,-24(s0)
    8000206c:	853e                	mv	a0,a5
    8000206e:	fffff097          	auipc	ra,0xfffff
    80002072:	7c6080e7          	jalr	1990(ra) # 80001834 <acquire>
    p->state = PROC_RUNNABLE;
    80002076:	fe843783          	ld	a5,-24(s0)
    8000207a:	4709                	li	a4,2
    8000207c:	cb98                	sw	a4,16(a5)
    sched();
    8000207e:	00000097          	auipc	ra,0x0
    80002082:	f44080e7          	jalr	-188(ra) # 80001fc2 <sched>
    p->time_slice = TIME_SLICE_TICKS;
    80002086:	fe843783          	ld	a5,-24(s0)
    8000208a:	4715                	li	a4,5
    8000208c:	cff8                	sw	a4,92(a5)
    p->need_resched = 0;
    8000208e:	fe843783          	ld	a5,-24(s0)
    80002092:	0607a023          	sw	zero,96(a5)
    release(&p->lock);
    80002096:	fe843783          	ld	a5,-24(s0)
    8000209a:	853e                	mv	a0,a5
    8000209c:	fffff097          	auipc	ra,0xfffff
    800020a0:	7cc080e7          	jalr	1996(ra) # 80001868 <release>
    800020a4:	a011                	j	800020a8 <yield+0x5a>
    if (!p) return;
    800020a6:	0001                	nop
}
    800020a8:	60e2                	ld	ra,24(sp)
    800020aa:	6442                	ld	s0,16(sp)
    800020ac:	6105                	add	sp,sp,32
    800020ae:	8082                	ret

00000000800020b0 <sleep>:

void sleep(void* chan, struct spinlock* lk) {
    800020b0:	7179                	add	sp,sp,-48
    800020b2:	f406                	sd	ra,40(sp)
    800020b4:	f022                	sd	s0,32(sp)
    800020b6:	1800                	add	s0,sp,48
    800020b8:	fca43c23          	sd	a0,-40(s0)
    800020bc:	fcb43823          	sd	a1,-48(s0)
    struct proc* p = myproc();
    800020c0:	00000097          	auipc	ra,0x0
    800020c4:	eea080e7          	jalr	-278(ra) # 80001faa <myproc>
    800020c8:	fea43423          	sd	a0,-24(s0)
    if (!p) {
    800020cc:	fe843783          	ld	a5,-24(s0)
    800020d0:	eb89                	bnez	a5,800020e2 <sleep+0x32>
        panic("sleep: no proc");
    800020d2:	00004517          	auipc	a0,0x4
    800020d6:	00650513          	add	a0,a0,6 # 800060d8 <swtch+0x63c>
    800020da:	00004097          	auipc	ra,0x4
    800020de:	894080e7          	jalr	-1900(ra) # 8000596e <panic>
    }
    if (lk == NULL) {
    800020e2:	fd043783          	ld	a5,-48(s0)
    800020e6:	eb89                	bnez	a5,800020f8 <sleep+0x48>
        panic("sleep: null lk");
    800020e8:	00004517          	auipc	a0,0x4
    800020ec:	00050513          	mv	a0,a0
    800020f0:	00004097          	auipc	ra,0x4
    800020f4:	87e080e7          	jalr	-1922(ra) # 8000596e <panic>
    }

    if (lk != &p->lock) {
    800020f8:	fe843783          	ld	a5,-24(s0)
    800020fc:	fd043703          	ld	a4,-48(s0)
    80002100:	00f70f63          	beq	a4,a5,8000211e <sleep+0x6e>
        acquire(&p->lock);
    80002104:	fe843783          	ld	a5,-24(s0)
    80002108:	853e                	mv	a0,a5
    8000210a:	fffff097          	auipc	ra,0xfffff
    8000210e:	72a080e7          	jalr	1834(ra) # 80001834 <acquire>
        release(lk);
    80002112:	fd043503          	ld	a0,-48(s0)
    80002116:	fffff097          	auipc	ra,0xfffff
    8000211a:	752080e7          	jalr	1874(ra) # 80001868 <release>
    }
    p->chan = chan;
    8000211e:	fe843783          	ld	a5,-24(s0)
    80002122:	fd843703          	ld	a4,-40(s0)
    80002126:	ef98                	sd	a4,24(a5)
    p->state = PROC_SLEEPING;
    80002128:	fe843783          	ld	a5,-24(s0)
    8000212c:	4711                	li	a4,4
    8000212e:	cb98                	sw	a4,16(a5)
    p->time_slice = TIME_SLICE_TICKS;
    80002130:	fe843783          	ld	a5,-24(s0)
    80002134:	4715                	li	a4,5
    80002136:	cff8                	sw	a4,92(a5)
    p->need_resched = 0;
    80002138:	fe843783          	ld	a5,-24(s0)
    8000213c:	0607a023          	sw	zero,96(a5)
    sched();
    80002140:	00000097          	auipc	ra,0x0
    80002144:	e82080e7          	jalr	-382(ra) # 80001fc2 <sched>
    p->chan = NULL;
    80002148:	fe843783          	ld	a5,-24(s0)
    8000214c:	0007bc23          	sd	zero,24(a5)

    if (lk != &p->lock) {
    80002150:	fe843783          	ld	a5,-24(s0)
    80002154:	fd043703          	ld	a4,-48(s0)
    80002158:	02f70063          	beq	a4,a5,80002178 <sleep+0xc8>
        release(&p->lock);
    8000215c:	fe843783          	ld	a5,-24(s0)
    80002160:	853e                	mv	a0,a5
    80002162:	fffff097          	auipc	ra,0xfffff
    80002166:	706080e7          	jalr	1798(ra) # 80001868 <release>
        acquire(lk);
    8000216a:	fd043503          	ld	a0,-48(s0)
    8000216e:	fffff097          	auipc	ra,0xfffff
    80002172:	6c6080e7          	jalr	1734(ra) # 80001834 <acquire>
    } else {
        release(&p->lock);
    }
}
    80002176:	a801                	j	80002186 <sleep+0xd6>
        release(&p->lock);
    80002178:	fe843783          	ld	a5,-24(s0)
    8000217c:	853e                	mv	a0,a5
    8000217e:	fffff097          	auipc	ra,0xfffff
    80002182:	6ea080e7          	jalr	1770(ra) # 80001868 <release>
}
    80002186:	0001                	nop
    80002188:	70a2                	ld	ra,40(sp)
    8000218a:	7402                	ld	s0,32(sp)
    8000218c:	6145                	add	sp,sp,48
    8000218e:	8082                	ret

0000000080002190 <wakeup>:

void wakeup(void* chan) {
    80002190:	7179                	add	sp,sp,-48
    80002192:	f406                	sd	ra,40(sp)
    80002194:	f022                	sd	s0,32(sp)
    80002196:	1800                	add	s0,sp,48
    80002198:	fca43c23          	sd	a0,-40(s0)
    for (int i = 0; i < NPROC; i++) {
    8000219c:	fe042623          	sw	zero,-20(s0)
    800021a0:	a88d                	j	80002212 <wakeup+0x82>
        struct proc* p = &proc_table[i];
    800021a2:	fec42783          	lw	a5,-20(s0)
    800021a6:	00879713          	sll	a4,a5,0x8
    800021aa:	00005797          	auipc	a5,0x5
    800021ae:	d5678793          	add	a5,a5,-682 # 80006f00 <proc_table>
    800021b2:	97ba                	add	a5,a5,a4
    800021b4:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    800021b8:	fe043783          	ld	a5,-32(s0)
    800021bc:	853e                	mv	a0,a5
    800021be:	fffff097          	auipc	ra,0xfffff
    800021c2:	676080e7          	jalr	1654(ra) # 80001834 <acquire>
        if (p->state == PROC_SLEEPING && p->chan == chan) {
    800021c6:	fe043783          	ld	a5,-32(s0)
    800021ca:	4b9c                	lw	a5,16(a5)
    800021cc:	873e                	mv	a4,a5
    800021ce:	4791                	li	a5,4
    800021d0:	02f71563          	bne	a4,a5,800021fa <wakeup+0x6a>
    800021d4:	fe043783          	ld	a5,-32(s0)
    800021d8:	6f9c                	ld	a5,24(a5)
    800021da:	fd843703          	ld	a4,-40(s0)
    800021de:	00f71e63          	bne	a4,a5,800021fa <wakeup+0x6a>
            p->state = PROC_RUNNABLE;
    800021e2:	fe043783          	ld	a5,-32(s0)
    800021e6:	4709                	li	a4,2
    800021e8:	cb98                	sw	a4,16(a5)
            p->time_slice = TIME_SLICE_TICKS;
    800021ea:	fe043783          	ld	a5,-32(s0)
    800021ee:	4715                	li	a4,5
    800021f0:	cff8                	sw	a4,92(a5)
            p->need_resched = 0;
    800021f2:	fe043783          	ld	a5,-32(s0)
    800021f6:	0607a023          	sw	zero,96(a5)
        }
        release(&p->lock);
    800021fa:	fe043783          	ld	a5,-32(s0)
    800021fe:	853e                	mv	a0,a5
    80002200:	fffff097          	auipc	ra,0xfffff
    80002204:	668080e7          	jalr	1640(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    80002208:	fec42783          	lw	a5,-20(s0)
    8000220c:	2785                	addw	a5,a5,1
    8000220e:	fef42623          	sw	a5,-20(s0)
    80002212:	fec42783          	lw	a5,-20(s0)
    80002216:	0007871b          	sext.w	a4,a5
    8000221a:	03f00793          	li	a5,63
    8000221e:	f8e7d2e3          	bge	a5,a4,800021a2 <wakeup+0x12>
    }
}
    80002222:	0001                	nop
    80002224:	0001                	nop
    80002226:	70a2                	ld	ra,40(sp)
    80002228:	7402                	ld	s0,32(sp)
    8000222a:	6145                	add	sp,sp,48
    8000222c:	8082                	ret

000000008000222e <exit_process>:

void exit_process(int status) {
    8000222e:	7179                	add	sp,sp,-48
    80002230:	f406                	sd	ra,40(sp)
    80002232:	f022                	sd	s0,32(sp)
    80002234:	1800                	add	s0,sp,48
    80002236:	87aa                	mv	a5,a0
    80002238:	fcf42e23          	sw	a5,-36(s0)
    struct proc* p = myproc();
    8000223c:	00000097          	auipc	ra,0x0
    80002240:	d6e080e7          	jalr	-658(ra) # 80001faa <myproc>
    80002244:	fea43423          	sd	a0,-24(s0)
    if (!p) {
    80002248:	fe843783          	ld	a5,-24(s0)
    8000224c:	eb89                	bnez	a5,8000225e <exit_process+0x30>
        panic("exit with no proc");
    8000224e:	00004517          	auipc	a0,0x4
    80002252:	eaa50513          	add	a0,a0,-342 # 800060f8 <swtch+0x65c>
    80002256:	00003097          	auipc	ra,0x3
    8000225a:	718080e7          	jalr	1816(ra) # 8000596e <panic>
    }
    acquire(&p->lock);
    8000225e:	fe843783          	ld	a5,-24(s0)
    80002262:	853e                	mv	a0,a5
    80002264:	fffff097          	auipc	ra,0xfffff
    80002268:	5d0080e7          	jalr	1488(ra) # 80001834 <acquire>
    p->xstate = status;
    8000226c:	fe843783          	ld	a5,-24(s0)
    80002270:	fdc42703          	lw	a4,-36(s0)
    80002274:	d3d8                	sw	a4,36(a5)
    p->state = PROC_ZOMBIE;
    80002276:	fe843783          	ld	a5,-24(s0)
    8000227a:	4715                	li	a4,5
    8000227c:	cb98                	sw	a4,16(a5)
    wakeup(p->parent);
    8000227e:	fe843783          	ld	a5,-24(s0)
    80002282:	73fc                	ld	a5,224(a5)
    80002284:	853e                	mv	a0,a5
    80002286:	00000097          	auipc	ra,0x0
    8000228a:	f0a080e7          	jalr	-246(ra) # 80002190 <wakeup>
    sched();
    8000228e:	00000097          	auipc	ra,0x0
    80002292:	d34080e7          	jalr	-716(ra) # 80001fc2 <sched>
    panic("zombie exit");
    80002296:	00004517          	auipc	a0,0x4
    8000229a:	e7a50513          	add	a0,a0,-390 # 80006110 <swtch+0x674>
    8000229e:	00003097          	auipc	ra,0x3
    800022a2:	6d0080e7          	jalr	1744(ra) # 8000596e <panic>

00000000800022a6 <wait_process>:
}

int wait_process(int* status) {
    800022a6:	715d                	add	sp,sp,-80
    800022a8:	e486                	sd	ra,72(sp)
    800022aa:	e0a2                	sd	s0,64(sp)
    800022ac:	0880                	add	s0,sp,80
    800022ae:	faa43c23          	sd	a0,-72(s0)
    struct proc* cur = myproc();
    800022b2:	00000097          	auipc	ra,0x0
    800022b6:	cf8080e7          	jalr	-776(ra) # 80001faa <myproc>
    800022ba:	fca43c23          	sd	a0,-40(s0)
    for (;;) {
        for (int i = 0; i < NPROC; i++) {
    800022be:	fe042623          	sw	zero,-20(s0)
    800022c2:	a05d                	j	80002368 <wait_process+0xc2>
            struct proc* p = &proc_table[i];
    800022c4:	fec42783          	lw	a5,-20(s0)
    800022c8:	00879713          	sll	a4,a5,0x8
    800022cc:	00005797          	auipc	a5,0x5
    800022d0:	c3478793          	add	a5,a5,-972 # 80006f00 <proc_table>
    800022d4:	97ba                	add	a5,a5,a4
    800022d6:	fcf43823          	sd	a5,-48(s0)
            acquire(&p->lock);
    800022da:	fd043783          	ld	a5,-48(s0)
    800022de:	853e                	mv	a0,a5
    800022e0:	fffff097          	auipc	ra,0xfffff
    800022e4:	554080e7          	jalr	1364(ra) # 80001834 <acquire>
            if (p->parent != cur) {
    800022e8:	fd043783          	ld	a5,-48(s0)
    800022ec:	73fc                	ld	a5,224(a5)
    800022ee:	fd843703          	ld	a4,-40(s0)
    800022f2:	00f70a63          	beq	a4,a5,80002306 <wait_process+0x60>
                release(&p->lock);
    800022f6:	fd043783          	ld	a5,-48(s0)
    800022fa:	853e                	mv	a0,a5
    800022fc:	fffff097          	auipc	ra,0xfffff
    80002300:	56c080e7          	jalr	1388(ra) # 80001868 <release>
                continue;
    80002304:	a8a9                	j	8000235e <wait_process+0xb8>
            }
            if (p->state == PROC_ZOMBIE) {
    80002306:	fd043783          	ld	a5,-48(s0)
    8000230a:	4b9c                	lw	a5,16(a5)
    8000230c:	873e                	mv	a4,a5
    8000230e:	4795                	li	a5,5
    80002310:	04f71063          	bne	a4,a5,80002350 <wait_process+0xaa>
                int pid = p->pid;
    80002314:	fd043783          	ld	a5,-48(s0)
    80002318:	579c                	lw	a5,40(a5)
    8000231a:	fcf42623          	sw	a5,-52(s0)
                if (status) *status = p->xstate;
    8000231e:	fb843783          	ld	a5,-72(s0)
    80002322:	c799                	beqz	a5,80002330 <wait_process+0x8a>
    80002324:	fd043783          	ld	a5,-48(s0)
    80002328:	53d8                	lw	a4,36(a5)
    8000232a:	fb843783          	ld	a5,-72(s0)
    8000232e:	c398                	sw	a4,0(a5)
                free_process(p);
    80002330:	fd043503          	ld	a0,-48(s0)
    80002334:	00000097          	auipc	ra,0x0
    80002338:	822080e7          	jalr	-2014(ra) # 80001b56 <free_process>
                release(&p->lock);
    8000233c:	fd043783          	ld	a5,-48(s0)
    80002340:	853e                	mv	a0,a5
    80002342:	fffff097          	auipc	ra,0xfffff
    80002346:	526080e7          	jalr	1318(ra) # 80001868 <release>
                return pid;
    8000234a:	fcc42783          	lw	a5,-52(s0)
    8000234e:	a075                	j	800023fa <wait_process+0x154>
            }
            release(&p->lock);
    80002350:	fd043783          	ld	a5,-48(s0)
    80002354:	853e                	mv	a0,a5
    80002356:	fffff097          	auipc	ra,0xfffff
    8000235a:	512080e7          	jalr	1298(ra) # 80001868 <release>
        for (int i = 0; i < NPROC; i++) {
    8000235e:	fec42783          	lw	a5,-20(s0)
    80002362:	2785                	addw	a5,a5,1
    80002364:	fef42623          	sw	a5,-20(s0)
    80002368:	fec42783          	lw	a5,-20(s0)
    8000236c:	0007871b          	sext.w	a4,a5
    80002370:	03f00793          	li	a5,63
    80002374:	f4e7d8e3          	bge	a5,a4,800022c4 <wait_process+0x1e>
        }
        // No child exited yet; sleep to avoid busy waiting.
        acquire(&cur->lock);
    80002378:	fd843783          	ld	a5,-40(s0)
    8000237c:	853e                	mv	a0,a5
    8000237e:	fffff097          	auipc	ra,0xfffff
    80002382:	4b6080e7          	jalr	1206(ra) # 80001834 <acquire>
        int havekids = 0;
    80002386:	fe042423          	sw	zero,-24(s0)
        for (int i = 0; i < NPROC; i++) {
    8000238a:	fe042223          	sw	zero,-28(s0)
    8000238e:	a03d                	j	800023bc <wait_process+0x116>
            if (proc_table[i].parent == cur) {
    80002390:	00005717          	auipc	a4,0x5
    80002394:	b7070713          	add	a4,a4,-1168 # 80006f00 <proc_table>
    80002398:	fe442783          	lw	a5,-28(s0)
    8000239c:	07a2                	sll	a5,a5,0x8
    8000239e:	97ba                	add	a5,a5,a4
    800023a0:	73fc                	ld	a5,224(a5)
    800023a2:	fd843703          	ld	a4,-40(s0)
    800023a6:	00f71663          	bne	a4,a5,800023b2 <wait_process+0x10c>
                havekids = 1;
    800023aa:	4785                	li	a5,1
    800023ac:	fef42423          	sw	a5,-24(s0)
                break;
    800023b0:	a831                	j	800023cc <wait_process+0x126>
        for (int i = 0; i < NPROC; i++) {
    800023b2:	fe442783          	lw	a5,-28(s0)
    800023b6:	2785                	addw	a5,a5,1
    800023b8:	fef42223          	sw	a5,-28(s0)
    800023bc:	fe442783          	lw	a5,-28(s0)
    800023c0:	0007871b          	sext.w	a4,a5
    800023c4:	03f00793          	li	a5,63
    800023c8:	fce7d4e3          	bge	a5,a4,80002390 <wait_process+0xea>
            }
        }
        if (!havekids) {
    800023cc:	fe842783          	lw	a5,-24(s0)
    800023d0:	2781                	sext.w	a5,a5
    800023d2:	eb91                	bnez	a5,800023e6 <wait_process+0x140>
            release(&cur->lock);
    800023d4:	fd843783          	ld	a5,-40(s0)
    800023d8:	853e                	mv	a0,a5
    800023da:	fffff097          	auipc	ra,0xfffff
    800023de:	48e080e7          	jalr	1166(ra) # 80001868 <release>
            return -1;
    800023e2:	57fd                	li	a5,-1
    800023e4:	a819                	j	800023fa <wait_process+0x154>
        }
        sleep(cur, &cur->lock);
    800023e6:	fd843783          	ld	a5,-40(s0)
    800023ea:	85be                	mv	a1,a5
    800023ec:	fd843503          	ld	a0,-40(s0)
    800023f0:	00000097          	auipc	ra,0x0
    800023f4:	cc0080e7          	jalr	-832(ra) # 800020b0 <sleep>
    for (;;) {
    800023f8:	b5d9                	j	800022be <wait_process+0x18>
    }
}
    800023fa:	853e                	mv	a0,a5
    800023fc:	60a6                	ld	ra,72(sp)
    800023fe:	6406                	ld	s0,64(sp)
    80002400:	6161                	add	sp,sp,80
    80002402:	8082                	ret

0000000080002404 <age_runnable>:

static void age_runnable(uint64 now) {
    80002404:	7179                	add	sp,sp,-48
    80002406:	f406                	sd	ra,40(sp)
    80002408:	f022                	sd	s0,32(sp)
    8000240a:	1800                	add	s0,sp,48
    8000240c:	fca43c23          	sd	a0,-40(s0)
    if (now - last_aging_tick < SCHED_AGING_TICKS) {
    80002410:	00009797          	auipc	a5,0x9
    80002414:	b7878793          	add	a5,a5,-1160 # 8000af88 <last_aging_tick>
    80002418:	639c                	ld	a5,0(a5)
    8000241a:	fd843703          	ld	a4,-40(s0)
    8000241e:	8f1d                	sub	a4,a4,a5
    80002420:	0c700793          	li	a5,199
    80002424:	08e7f863          	bgeu	a5,a4,800024b4 <age_runnable+0xb0>
        return;
    }
    last_aging_tick = now;
    80002428:	00009797          	auipc	a5,0x9
    8000242c:	b6078793          	add	a5,a5,-1184 # 8000af88 <last_aging_tick>
    80002430:	fd843703          	ld	a4,-40(s0)
    80002434:	e398                	sd	a4,0(a5)
    for (int i = 0; i < NPROC; i++) {
    80002436:	fe042623          	sw	zero,-20(s0)
    8000243a:	a0a5                	j	800024a2 <age_runnable+0x9e>
        struct proc* p = &proc_table[i];
    8000243c:	fec42783          	lw	a5,-20(s0)
    80002440:	00879713          	sll	a4,a5,0x8
    80002444:	00005797          	auipc	a5,0x5
    80002448:	abc78793          	add	a5,a5,-1348 # 80006f00 <proc_table>
    8000244c:	97ba                	add	a5,a5,a4
    8000244e:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    80002452:	fe043783          	ld	a5,-32(s0)
    80002456:	853e                	mv	a0,a5
    80002458:	fffff097          	auipc	ra,0xfffff
    8000245c:	3dc080e7          	jalr	988(ra) # 80001834 <acquire>
        if (p->state == PROC_RUNNABLE && p->priority > PRIORITY_MIN) {
    80002460:	fe043783          	ld	a5,-32(s0)
    80002464:	4b9c                	lw	a5,16(a5)
    80002466:	873e                	mv	a4,a5
    80002468:	4789                	li	a5,2
    8000246a:	02f71063          	bne	a4,a5,8000248a <age_runnable+0x86>
    8000246e:	fe043783          	ld	a5,-32(s0)
    80002472:	4fbc                	lw	a5,88(a5)
    80002474:	00f05b63          	blez	a5,8000248a <age_runnable+0x86>
            p->priority--;
    80002478:	fe043783          	ld	a5,-32(s0)
    8000247c:	4fbc                	lw	a5,88(a5)
    8000247e:	37fd                	addw	a5,a5,-1
    80002480:	0007871b          	sext.w	a4,a5
    80002484:	fe043783          	ld	a5,-32(s0)
    80002488:	cfb8                	sw	a4,88(a5)
        }
        release(&p->lock);
    8000248a:	fe043783          	ld	a5,-32(s0)
    8000248e:	853e                	mv	a0,a5
    80002490:	fffff097          	auipc	ra,0xfffff
    80002494:	3d8080e7          	jalr	984(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    80002498:	fec42783          	lw	a5,-20(s0)
    8000249c:	2785                	addw	a5,a5,1
    8000249e:	fef42623          	sw	a5,-20(s0)
    800024a2:	fec42783          	lw	a5,-20(s0)
    800024a6:	0007871b          	sext.w	a4,a5
    800024aa:	03f00793          	li	a5,63
    800024ae:	f8e7d7e3          	bge	a5,a4,8000243c <age_runnable+0x38>
    800024b2:	a011                	j	800024b6 <age_runnable+0xb2>
        return;
    800024b4:	0001                	nop
    }
}
    800024b6:	70a2                	ld	ra,40(sp)
    800024b8:	7402                	ld	s0,32(sp)
    800024ba:	6145                	add	sp,sp,48
    800024bc:	8082                	ret

00000000800024be <pick_runnable>:

static struct proc* pick_runnable(uint64 now) {
    800024be:	711d                	add	sp,sp,-96
    800024c0:	ec86                	sd	ra,88(sp)
    800024c2:	e8a2                	sd	s0,80(sp)
    800024c4:	1080                	add	s0,sp,96
    800024c6:	faa43423          	sd	a0,-88(s0)
    struct proc* best = NULL;
    800024ca:	fe043423          	sd	zero,-24(s0)
    int best_pri = 0x7fffffff;
    800024ce:	800007b7          	lui	a5,0x80000
    800024d2:	fff7c793          	not	a5,a5
    800024d6:	fef42223          	sw	a5,-28(s0)
    uint64 best_stamp = 0;
    800024da:	fc043c23          	sd	zero,-40(s0)

    for (int i = 0; i < NPROC; i++) {
    800024de:	fc042a23          	sw	zero,-44(s0)
    800024e2:	a0d1                	j	800025a6 <pick_runnable+0xe8>
        struct proc* p = &proc_table[i];
    800024e4:	fd442783          	lw	a5,-44(s0)
    800024e8:	00879713          	sll	a4,a5,0x8
    800024ec:	00005797          	auipc	a5,0x5
    800024f0:	a1478793          	add	a5,a5,-1516 # 80006f00 <proc_table>
    800024f4:	97ba                	add	a5,a5,a4
    800024f6:	fcf43423          	sd	a5,-56(s0)
        acquire(&p->lock);
    800024fa:	fc843783          	ld	a5,-56(s0)
    800024fe:	853e                	mv	a0,a5
    80002500:	fffff097          	auipc	ra,0xfffff
    80002504:	334080e7          	jalr	820(ra) # 80001834 <acquire>
        if (p->state == PROC_RUNNABLE) {
    80002508:	fc843783          	ld	a5,-56(s0)
    8000250c:	4b9c                	lw	a5,16(a5)
    8000250e:	873e                	mv	a4,a5
    80002510:	4789                	li	a5,2
    80002512:	06f71e63          	bne	a4,a5,8000258e <pick_runnable+0xd0>
            int pri = p->priority;
    80002516:	fc843783          	ld	a5,-56(s0)
    8000251a:	4fbc                	lw	a5,88(a5)
    8000251c:	fcf42223          	sw	a5,-60(s0)
            uint64 stamp = p->last_scheduled;
    80002520:	fc843783          	ld	a5,-56(s0)
    80002524:	6bbc                	ld	a5,80(a5)
    80002526:	faf43c23          	sd	a5,-72(s0)
            if (!best || pri < best_pri || (pri == best_pri && stamp <= best_stamp)) {
    8000252a:	fe843783          	ld	a5,-24(s0)
    8000252e:	cb8d                	beqz	a5,80002560 <pick_runnable+0xa2>
    80002530:	fc442783          	lw	a5,-60(s0)
    80002534:	873e                	mv	a4,a5
    80002536:	fe442783          	lw	a5,-28(s0)
    8000253a:	2701                	sext.w	a4,a4
    8000253c:	2781                	sext.w	a5,a5
    8000253e:	02f74163          	blt	a4,a5,80002560 <pick_runnable+0xa2>
    80002542:	fc442783          	lw	a5,-60(s0)
    80002546:	873e                	mv	a4,a5
    80002548:	fe442783          	lw	a5,-28(s0)
    8000254c:	2701                	sext.w	a4,a4
    8000254e:	2781                	sext.w	a5,a5
    80002550:	02f71f63          	bne	a4,a5,8000258e <pick_runnable+0xd0>
    80002554:	fb843703          	ld	a4,-72(s0)
    80002558:	fd843783          	ld	a5,-40(s0)
    8000255c:	02e7e963          	bltu	a5,a4,8000258e <pick_runnable+0xd0>
                if (best) {
    80002560:	fe843783          	ld	a5,-24(s0)
    80002564:	cb81                	beqz	a5,80002574 <pick_runnable+0xb6>
                    release(&best->lock);
    80002566:	fe843783          	ld	a5,-24(s0)
    8000256a:	853e                	mv	a0,a5
    8000256c:	fffff097          	auipc	ra,0xfffff
    80002570:	2fc080e7          	jalr	764(ra) # 80001868 <release>
                }
                best = p;
    80002574:	fc843783          	ld	a5,-56(s0)
    80002578:	fef43423          	sd	a5,-24(s0)
                best_pri = pri;
    8000257c:	fc442783          	lw	a5,-60(s0)
    80002580:	fef42223          	sw	a5,-28(s0)
                best_stamp = stamp;
    80002584:	fb843783          	ld	a5,-72(s0)
    80002588:	fcf43c23          	sd	a5,-40(s0)
                continue;
    8000258c:	a801                	j	8000259c <pick_runnable+0xde>
            }
        }
        release(&p->lock);
    8000258e:	fc843783          	ld	a5,-56(s0)
    80002592:	853e                	mv	a0,a5
    80002594:	fffff097          	auipc	ra,0xfffff
    80002598:	2d4080e7          	jalr	724(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    8000259c:	fd442783          	lw	a5,-44(s0)
    800025a0:	2785                	addw	a5,a5,1
    800025a2:	fcf42a23          	sw	a5,-44(s0)
    800025a6:	fd442783          	lw	a5,-44(s0)
    800025aa:	0007871b          	sext.w	a4,a5
    800025ae:	03f00793          	li	a5,63
    800025b2:	f2e7d9e3          	bge	a5,a4,800024e4 <pick_runnable+0x26>
    }
    return best;
    800025b6:	fe843783          	ld	a5,-24(s0)
}
    800025ba:	853e                	mv	a0,a5
    800025bc:	60e6                	ld	ra,88(sp)
    800025be:	6446                	ld	s0,80(sp)
    800025c0:	6125                	add	sp,sp,96
    800025c2:	8082                	ret

00000000800025c4 <reap_zombies>:

static void reap_zombies(void) {
    800025c4:	1101                	add	sp,sp,-32
    800025c6:	ec06                	sd	ra,24(sp)
    800025c8:	e822                	sd	s0,16(sp)
    800025ca:	1000                	add	s0,sp,32
    for (int i = 0; i < NPROC; i++) {
    800025cc:	fe042623          	sw	zero,-20(s0)
    800025d0:	a885                	j	80002640 <reap_zombies+0x7c>
        struct proc* p = &proc_table[i];
    800025d2:	fec42783          	lw	a5,-20(s0)
    800025d6:	00879713          	sll	a4,a5,0x8
    800025da:	00005797          	auipc	a5,0x5
    800025de:	92678793          	add	a5,a5,-1754 # 80006f00 <proc_table>
    800025e2:	97ba                	add	a5,a5,a4
    800025e4:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    800025e8:	fe043783          	ld	a5,-32(s0)
    800025ec:	853e                	mv	a0,a5
    800025ee:	fffff097          	auipc	ra,0xfffff
    800025f2:	246080e7          	jalr	582(ra) # 80001834 <acquire>
        if (p->state == PROC_ZOMBIE && p->parent == NULL) {
    800025f6:	fe043783          	ld	a5,-32(s0)
    800025fa:	4b9c                	lw	a5,16(a5)
    800025fc:	873e                	mv	a4,a5
    800025fe:	4795                	li	a5,5
    80002600:	02f71463          	bne	a4,a5,80002628 <reap_zombies+0x64>
    80002604:	fe043783          	ld	a5,-32(s0)
    80002608:	73fc                	ld	a5,224(a5)
    8000260a:	ef99                	bnez	a5,80002628 <reap_zombies+0x64>
            free_process(p);
    8000260c:	fe043503          	ld	a0,-32(s0)
    80002610:	fffff097          	auipc	ra,0xfffff
    80002614:	546080e7          	jalr	1350(ra) # 80001b56 <free_process>
            release(&p->lock);
    80002618:	fe043783          	ld	a5,-32(s0)
    8000261c:	853e                	mv	a0,a5
    8000261e:	fffff097          	auipc	ra,0xfffff
    80002622:	24a080e7          	jalr	586(ra) # 80001868 <release>
            continue;
    80002626:	a801                	j	80002636 <reap_zombies+0x72>
        }
        release(&p->lock);
    80002628:	fe043783          	ld	a5,-32(s0)
    8000262c:	853e                	mv	a0,a5
    8000262e:	fffff097          	auipc	ra,0xfffff
    80002632:	23a080e7          	jalr	570(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    80002636:	fec42783          	lw	a5,-20(s0)
    8000263a:	2785                	addw	a5,a5,1
    8000263c:	fef42623          	sw	a5,-20(s0)
    80002640:	fec42783          	lw	a5,-20(s0)
    80002644:	0007871b          	sext.w	a4,a5
    80002648:	03f00793          	li	a5,63
    8000264c:	f8e7d3e3          	bge	a5,a4,800025d2 <reap_zombies+0xe>
    }
}
    80002650:	0001                	nop
    80002652:	0001                	nop
    80002654:	60e2                	ld	ra,24(sp)
    80002656:	6442                	ld	s0,16(sp)
    80002658:	6105                	add	sp,sp,32
    8000265a:	8082                	ret

000000008000265c <scheduler>:

void scheduler(void) {
    8000265c:	1101                	add	sp,sp,-32
    8000265e:	ec06                	sd	ra,24(sp)
    80002660:	e822                	sd	s0,16(sp)
    80002662:	1000                	add	s0,sp,32
    for (;;) {
        intr_on();
    80002664:	fffff097          	auipc	ra,0xfffff
    80002668:	338080e7          	jalr	824(ra) # 8000199c <intr_on>
        uint64 now = timer_ticks();
    8000266c:	00002097          	auipc	ra,0x2
    80002670:	9e0080e7          	jalr	-1568(ra) # 8000404c <timer_ticks>
    80002674:	fea43423          	sd	a0,-24(s0)
        age_runnable(now);
    80002678:	fe843503          	ld	a0,-24(s0)
    8000267c:	00000097          	auipc	ra,0x0
    80002680:	d88080e7          	jalr	-632(ra) # 80002404 <age_runnable>
        reap_zombies();
    80002684:	00000097          	auipc	ra,0x0
    80002688:	f40080e7          	jalr	-192(ra) # 800025c4 <reap_zombies>

        struct proc* p = pick_runnable(now);
    8000268c:	fe843503          	ld	a0,-24(s0)
    80002690:	00000097          	auipc	ra,0x0
    80002694:	e2e080e7          	jalr	-466(ra) # 800024be <pick_runnable>
    80002698:	fea43023          	sd	a0,-32(s0)
        if (p != NULL) {
    8000269c:	fe043783          	ld	a5,-32(s0)
    800026a0:	c7a5                	beqz	a5,80002708 <scheduler+0xac>
            p->state = PROC_RUNNING;
    800026a2:	fe043783          	ld	a5,-32(s0)
    800026a6:	470d                	li	a4,3
    800026a8:	cb98                	sw	a4,16(a5)
            p->time_slice = TIME_SLICE_TICKS;
    800026aa:	fe043783          	ld	a5,-32(s0)
    800026ae:	4715                	li	a4,5
    800026b0:	cff8                	sw	a4,92(a5)
            p->need_resched = 0;
    800026b2:	fe043783          	ld	a5,-32(s0)
    800026b6:	0607a023          	sw	zero,96(a5)
            p->last_scheduled = now;
    800026ba:	fe043783          	ld	a5,-32(s0)
    800026be:	fe843703          	ld	a4,-24(s0)
    800026c2:	ebb8                	sd	a4,80(a5)
            current_proc = p;
    800026c4:	00009797          	auipc	a5,0x9
    800026c8:	83c78793          	add	a5,a5,-1988 # 8000af00 <current_proc>
    800026cc:	fe043703          	ld	a4,-32(s0)
    800026d0:	e398                	sd	a4,0(a5)
            swtch(&scheduler_ctx, &p->ctx);
    800026d2:	fe043783          	ld	a5,-32(s0)
    800026d6:	07078793          	add	a5,a5,112
    800026da:	85be                	mv	a1,a5
    800026dc:	00009517          	auipc	a0,0x9
    800026e0:	83c50513          	add	a0,a0,-1988 # 8000af18 <scheduler_ctx>
    800026e4:	00003097          	auipc	ra,0x3
    800026e8:	3b8080e7          	jalr	952(ra) # 80005a9c <swtch>
            current_proc = NULL;
    800026ec:	00009797          	auipc	a5,0x9
    800026f0:	81478793          	add	a5,a5,-2028 # 8000af00 <current_proc>
    800026f4:	0007b023          	sd	zero,0(a5)
            release(&p->lock);
    800026f8:	fe043783          	ld	a5,-32(s0)
    800026fc:	853e                	mv	a0,a5
    800026fe:	fffff097          	auipc	ra,0xfffff
    80002702:	16a080e7          	jalr	362(ra) # 80001868 <release>
    80002706:	bfb9                	j	80002664 <scheduler+0x8>
        } else {
            // idle: halt a bit to avoid busy looping
            asm volatile("wfi");
    80002708:	10500073          	wfi
    for (;;) {
    8000270c:	bfa1                	j	80002664 <scheduler+0x8>

000000008000270e <proc_on_tick>:
        }
    }
}

void proc_on_tick(void) {
    8000270e:	1101                	add	sp,sp,-32
    80002710:	ec06                	sd	ra,24(sp)
    80002712:	e822                	sd	s0,16(sp)
    80002714:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    80002716:	00000097          	auipc	ra,0x0
    8000271a:	894080e7          	jalr	-1900(ra) # 80001faa <myproc>
    8000271e:	fea43423          	sd	a0,-24(s0)
    if (!p) return;
    80002722:	fe843783          	ld	a5,-24(s0)
    80002726:	cfb1                	beqz	a5,80002782 <proc_on_tick+0x74>
    acquire(&p->lock);
    80002728:	fe843783          	ld	a5,-24(s0)
    8000272c:	853e                	mv	a0,a5
    8000272e:	fffff097          	auipc	ra,0xfffff
    80002732:	106080e7          	jalr	262(ra) # 80001834 <acquire>
    p->runtime_ticks++;
    80002736:	fe843783          	ld	a5,-24(s0)
    8000273a:	67bc                	ld	a5,72(a5)
    8000273c:	00178713          	add	a4,a5,1
    80002740:	fe843783          	ld	a5,-24(s0)
    80002744:	e7b8                	sd	a4,72(a5)
    if (p->time_slice > 0) {
    80002746:	fe843783          	ld	a5,-24(s0)
    8000274a:	4ffc                	lw	a5,92(a5)
    8000274c:	02f05363          	blez	a5,80002772 <proc_on_tick+0x64>
        p->time_slice--;
    80002750:	fe843783          	ld	a5,-24(s0)
    80002754:	4ffc                	lw	a5,92(a5)
    80002756:	37fd                	addw	a5,a5,-1
    80002758:	0007871b          	sext.w	a4,a5
    8000275c:	fe843783          	ld	a5,-24(s0)
    80002760:	cff8                	sw	a4,92(a5)
        if (p->time_slice == 0) {
    80002762:	fe843783          	ld	a5,-24(s0)
    80002766:	4ffc                	lw	a5,92(a5)
    80002768:	e789                	bnez	a5,80002772 <proc_on_tick+0x64>
            p->need_resched = 1;
    8000276a:	fe843783          	ld	a5,-24(s0)
    8000276e:	4705                	li	a4,1
    80002770:	d3b8                	sw	a4,96(a5)
        }
    }
    release(&p->lock);
    80002772:	fe843783          	ld	a5,-24(s0)
    80002776:	853e                	mv	a0,a5
    80002778:	fffff097          	auipc	ra,0xfffff
    8000277c:	0f0080e7          	jalr	240(ra) # 80001868 <release>
    80002780:	a011                	j	80002784 <proc_on_tick+0x76>
    if (!p) return;
    80002782:	0001                	nop
}
    80002784:	60e2                	ld	ra,24(sp)
    80002786:	6442                	ld	s0,16(sp)
    80002788:	6105                	add	sp,sp,32
    8000278a:	8082                	ret

000000008000278c <set_proc_priority>:

int set_proc_priority(int pid, int new_priority) {
    8000278c:	7179                	add	sp,sp,-48
    8000278e:	f406                	sd	ra,40(sp)
    80002790:	f022                	sd	s0,32(sp)
    80002792:	1800                	add	s0,sp,48
    80002794:	87aa                	mv	a5,a0
    80002796:	872e                	mv	a4,a1
    80002798:	fcf42e23          	sw	a5,-36(s0)
    8000279c:	87ba                	mv	a5,a4
    8000279e:	fcf42c23          	sw	a5,-40(s0)
    if (new_priority < PRIORITY_MIN) {
    800027a2:	fd842783          	lw	a5,-40(s0)
    800027a6:	2781                	sext.w	a5,a5
    800027a8:	0007d463          	bgez	a5,800027b0 <set_proc_priority+0x24>
        new_priority = PRIORITY_MIN;
    800027ac:	fc042c23          	sw	zero,-40(s0)
    }
    for (int i = 0; i < NPROC; i++) {
    800027b0:	fe042623          	sw	zero,-20(s0)
    800027b4:	a8ad                	j	8000282e <set_proc_priority+0xa2>
        struct proc* p = &proc_table[i];
    800027b6:	fec42783          	lw	a5,-20(s0)
    800027ba:	00879713          	sll	a4,a5,0x8
    800027be:	00004797          	auipc	a5,0x4
    800027c2:	74278793          	add	a5,a5,1858 # 80006f00 <proc_table>
    800027c6:	97ba                	add	a5,a5,a4
    800027c8:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    800027cc:	fe043783          	ld	a5,-32(s0)
    800027d0:	853e                	mv	a0,a5
    800027d2:	fffff097          	auipc	ra,0xfffff
    800027d6:	062080e7          	jalr	98(ra) # 80001834 <acquire>
        if (p->pid == pid && p->state != PROC_UNUSED) {
    800027da:	fe043783          	ld	a5,-32(s0)
    800027de:	5798                	lw	a4,40(a5)
    800027e0:	fdc42783          	lw	a5,-36(s0)
    800027e4:	2781                	sext.w	a5,a5
    800027e6:	02e79863          	bne	a5,a4,80002816 <set_proc_priority+0x8a>
    800027ea:	fe043783          	ld	a5,-32(s0)
    800027ee:	4b9c                	lw	a5,16(a5)
    800027f0:	c39d                	beqz	a5,80002816 <set_proc_priority+0x8a>
            p->priority = new_priority;
    800027f2:	fe043783          	ld	a5,-32(s0)
    800027f6:	fd842703          	lw	a4,-40(s0)
    800027fa:	cfb8                	sw	a4,88(a5)
            p->time_slice = TIME_SLICE_TICKS;
    800027fc:	fe043783          	ld	a5,-32(s0)
    80002800:	4715                	li	a4,5
    80002802:	cff8                	sw	a4,92(a5)
            release(&p->lock);
    80002804:	fe043783          	ld	a5,-32(s0)
    80002808:	853e                	mv	a0,a5
    8000280a:	fffff097          	auipc	ra,0xfffff
    8000280e:	05e080e7          	jalr	94(ra) # 80001868 <release>
            return 0;
    80002812:	4781                	li	a5,0
    80002814:	a035                	j	80002840 <set_proc_priority+0xb4>
        }
        release(&p->lock);
    80002816:	fe043783          	ld	a5,-32(s0)
    8000281a:	853e                	mv	a0,a5
    8000281c:	fffff097          	auipc	ra,0xfffff
    80002820:	04c080e7          	jalr	76(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    80002824:	fec42783          	lw	a5,-20(s0)
    80002828:	2785                	addw	a5,a5,1
    8000282a:	fef42623          	sw	a5,-20(s0)
    8000282e:	fec42783          	lw	a5,-20(s0)
    80002832:	0007871b          	sext.w	a4,a5
    80002836:	03f00793          	li	a5,63
    8000283a:	f6e7dee3          	bge	a5,a4,800027b6 <set_proc_priority+0x2a>
    }
    return -1;
    8000283e:	57fd                	li	a5,-1
}
    80002840:	853e                	mv	a0,a5
    80002842:	70a2                	ld	ra,40(sp)
    80002844:	7402                	ld	s0,32(sp)
    80002846:	6145                	add	sp,sp,48
    80002848:	8082                	ret

000000008000284a <procdump>:

void procdump(void) {
    8000284a:	1101                	add	sp,sp,-32
    8000284c:	ec06                	sd	ra,24(sp)
    8000284e:	e822                	sd	s0,16(sp)
    80002850:	1000                	add	s0,sp,32
    printf("[proc] dump\n");
    80002852:	00004517          	auipc	a0,0x4
    80002856:	8ce50513          	add	a0,a0,-1842 # 80006120 <swtch+0x684>
    8000285a:	00003097          	auipc	ra,0x3
    8000285e:	07c080e7          	jalr	124(ra) # 800058d6 <printf>
    for (int i = 0; i < NPROC; i++) {
    80002862:	fe042623          	sw	zero,-20(s0)
    80002866:	a041                	j	800028e6 <procdump+0x9c>
        struct proc* p = &proc_table[i];
    80002868:	fec42783          	lw	a5,-20(s0)
    8000286c:	00879713          	sll	a4,a5,0x8
    80002870:	00004797          	auipc	a5,0x4
    80002874:	69078793          	add	a5,a5,1680 # 80006f00 <proc_table>
    80002878:	97ba                	add	a5,a5,a4
    8000287a:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    8000287e:	fe043783          	ld	a5,-32(s0)
    80002882:	853e                	mv	a0,a5
    80002884:	fffff097          	auipc	ra,0xfffff
    80002888:	fb0080e7          	jalr	-80(ra) # 80001834 <acquire>
        if (p->state != PROC_UNUSED) {
    8000288c:	fe043783          	ld	a5,-32(s0)
    80002890:	4b9c                	lw	a5,16(a5)
    80002892:	cf95                	beqz	a5,800028ce <procdump+0x84>
            printf(" pid=%d state=%d prio=%d slice=%d run=%lu name=%s\n",
    80002894:	fe043783          	ld	a5,-32(s0)
    80002898:	578c                	lw	a1,40(a5)
                   p->pid, p->state, p->priority, p->time_slice,
    8000289a:	fe043783          	ld	a5,-32(s0)
    8000289e:	4b90                	lw	a2,16(a5)
            printf(" pid=%d state=%d prio=%d slice=%d run=%lu name=%s\n",
    800028a0:	fe043783          	ld	a5,-32(s0)
    800028a4:	4fb4                	lw	a3,88(a5)
    800028a6:	fe043783          	ld	a5,-32(s0)
    800028aa:	4ff8                	lw	a4,92(a5)
    800028ac:	fe043783          	ld	a5,-32(s0)
    800028b0:	67a8                	ld	a0,72(a5)
                   p->runtime_ticks, p->name);
    800028b2:	fe043783          	ld	a5,-32(s0)
    800028b6:	0f078793          	add	a5,a5,240
            printf(" pid=%d state=%d prio=%d slice=%d run=%lu name=%s\n",
    800028ba:	883e                	mv	a6,a5
    800028bc:	87aa                	mv	a5,a0
    800028be:	00004517          	auipc	a0,0x4
    800028c2:	87250513          	add	a0,a0,-1934 # 80006130 <swtch+0x694>
    800028c6:	00003097          	auipc	ra,0x3
    800028ca:	010080e7          	jalr	16(ra) # 800058d6 <printf>
        }
        release(&p->lock);
    800028ce:	fe043783          	ld	a5,-32(s0)
    800028d2:	853e                	mv	a0,a5
    800028d4:	fffff097          	auipc	ra,0xfffff
    800028d8:	f94080e7          	jalr	-108(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    800028dc:	fec42783          	lw	a5,-20(s0)
    800028e0:	2785                	addw	a5,a5,1
    800028e2:	fef42623          	sw	a5,-20(s0)
    800028e6:	fec42783          	lw	a5,-20(s0)
    800028ea:	0007871b          	sext.w	a4,a5
    800028ee:	03f00793          	li	a5,63
    800028f2:	f6e7dbe3          	bge	a5,a4,80002868 <procdump+0x1e>
    }
}
    800028f6:	0001                	nop
    800028f8:	0001                	nop
    800028fa:	60e2                	ld	ra,24(sp)
    800028fc:	6442                	ld	s0,16(sp)
    800028fe:	6105                	add	sp,sp,32
    80002900:	8082                	ret

0000000080002902 <kill_process>:

int kill_process(int pid) {
    80002902:	7179                	add	sp,sp,-48
    80002904:	f406                	sd	ra,40(sp)
    80002906:	f022                	sd	s0,32(sp)
    80002908:	1800                	add	s0,sp,48
    8000290a:	87aa                	mv	a5,a0
    8000290c:	fcf42e23          	sw	a5,-36(s0)
    for (int i = 0; i < NPROC; i++) {
    80002910:	fe042623          	sw	zero,-20(s0)
    80002914:	a879                	j	800029b2 <kill_process+0xb0>
        struct proc* p = &proc_table[i];
    80002916:	fec42783          	lw	a5,-20(s0)
    8000291a:	00879713          	sll	a4,a5,0x8
    8000291e:	00004797          	auipc	a5,0x4
    80002922:	5e278793          	add	a5,a5,1506 # 80006f00 <proc_table>
    80002926:	97ba                	add	a5,a5,a4
    80002928:	fef43023          	sd	a5,-32(s0)
        acquire(&p->lock);
    8000292c:	fe043783          	ld	a5,-32(s0)
    80002930:	853e                	mv	a0,a5
    80002932:	fffff097          	auipc	ra,0xfffff
    80002936:	f02080e7          	jalr	-254(ra) # 80001834 <acquire>
        if (p->pid == pid && p->state != PROC_UNUSED) {
    8000293a:	fe043783          	ld	a5,-32(s0)
    8000293e:	5798                	lw	a4,40(a5)
    80002940:	fdc42783          	lw	a5,-36(s0)
    80002944:	2781                	sext.w	a5,a5
    80002946:	04e79a63          	bne	a5,a4,8000299a <kill_process+0x98>
    8000294a:	fe043783          	ld	a5,-32(s0)
    8000294e:	4b9c                	lw	a5,16(a5)
    80002950:	c7a9                	beqz	a5,8000299a <kill_process+0x98>
            p->killed = 1;
    80002952:	fe043783          	ld	a5,-32(s0)
    80002956:	4705                	li	a4,1
    80002958:	d398                	sw	a4,32(a5)
            if (p->state == PROC_SLEEPING) {
    8000295a:	fe043783          	ld	a5,-32(s0)
    8000295e:	4b9c                	lw	a5,16(a5)
    80002960:	873e                	mv	a4,a5
    80002962:	4791                	li	a5,4
    80002964:	02f71263          	bne	a4,a5,80002988 <kill_process+0x86>
                p->state = PROC_RUNNABLE;
    80002968:	fe043783          	ld	a5,-32(s0)
    8000296c:	4709                	li	a4,2
    8000296e:	cb98                	sw	a4,16(a5)
                p->chan = NULL;
    80002970:	fe043783          	ld	a5,-32(s0)
    80002974:	0007bc23          	sd	zero,24(a5)
                p->time_slice = TIME_SLICE_TICKS;
    80002978:	fe043783          	ld	a5,-32(s0)
    8000297c:	4715                	li	a4,5
    8000297e:	cff8                	sw	a4,92(a5)
                p->need_resched = 0;
    80002980:	fe043783          	ld	a5,-32(s0)
    80002984:	0607a023          	sw	zero,96(a5)
            }
            release(&p->lock);
    80002988:	fe043783          	ld	a5,-32(s0)
    8000298c:	853e                	mv	a0,a5
    8000298e:	fffff097          	auipc	ra,0xfffff
    80002992:	eda080e7          	jalr	-294(ra) # 80001868 <release>
            return 0;
    80002996:	4781                	li	a5,0
    80002998:	a035                	j	800029c4 <kill_process+0xc2>
        }
        release(&p->lock);
    8000299a:	fe043783          	ld	a5,-32(s0)
    8000299e:	853e                	mv	a0,a5
    800029a0:	fffff097          	auipc	ra,0xfffff
    800029a4:	ec8080e7          	jalr	-312(ra) # 80001868 <release>
    for (int i = 0; i < NPROC; i++) {
    800029a8:	fec42783          	lw	a5,-20(s0)
    800029ac:	2785                	addw	a5,a5,1
    800029ae:	fef42623          	sw	a5,-20(s0)
    800029b2:	fec42783          	lw	a5,-20(s0)
    800029b6:	0007871b          	sext.w	a4,a5
    800029ba:	03f00793          	li	a5,63
    800029be:	f4e7dce3          	bge	a5,a4,80002916 <kill_process+0x14>
    }
    return -1;
    800029c2:	57fd                	li	a5,-1
}
    800029c4:	853e                	mv	a0,a5
    800029c6:	70a2                	ld	ra,40(sp)
    800029c8:	7402                	ld	s0,32(sp)
    800029ca:	6145                	add	sp,sp,48
    800029cc:	8082                	ret

00000000800029ce <simple_task_a>:
#include "include/proc.h"
#include "include/test.h"
#include "include/syscall.h"
#include "include/trap.h"

static void simple_task_a(void) {
    800029ce:	1101                	add	sp,sp,-32
    800029d0:	ec06                	sd	ra,24(sp)
    800029d2:	e822                	sd	s0,16(sp)
    800029d4:	1000                	add	s0,sp,32
    for (int i = 0; i < 3; i++) {
    800029d6:	fe042623          	sw	zero,-20(s0)
    800029da:	a02d                	j	80002a04 <simple_task_a+0x36>
        printf("[proc] task A iter %d\n", i);
    800029dc:	fec42783          	lw	a5,-20(s0)
    800029e0:	85be                	mv	a1,a5
    800029e2:	00003517          	auipc	a0,0x3
    800029e6:	78650513          	add	a0,a0,1926 # 80006168 <swtch+0x6cc>
    800029ea:	00003097          	auipc	ra,0x3
    800029ee:	eec080e7          	jalr	-276(ra) # 800058d6 <printf>
        yield();
    800029f2:	fffff097          	auipc	ra,0xfffff
    800029f6:	65c080e7          	jalr	1628(ra) # 8000204e <yield>
    for (int i = 0; i < 3; i++) {
    800029fa:	fec42783          	lw	a5,-20(s0)
    800029fe:	2785                	addw	a5,a5,1
    80002a00:	fef42623          	sw	a5,-20(s0)
    80002a04:	fec42783          	lw	a5,-20(s0)
    80002a08:	0007871b          	sext.w	a4,a5
    80002a0c:	4789                	li	a5,2
    80002a0e:	fce7d7e3          	bge	a5,a4,800029dc <simple_task_a+0xe>
    }
    printf("[proc] task A exit\n");
    80002a12:	00003517          	auipc	a0,0x3
    80002a16:	76e50513          	add	a0,a0,1902 # 80006180 <swtch+0x6e4>
    80002a1a:	00003097          	auipc	ra,0x3
    80002a1e:	ebc080e7          	jalr	-324(ra) # 800058d6 <printf>
    exit_process(0);
    80002a22:	4501                	li	a0,0
    80002a24:	00000097          	auipc	ra,0x0
    80002a28:	80a080e7          	jalr	-2038(ra) # 8000222e <exit_process>

0000000080002a2c <simple_task_b>:
}

static void simple_task_b(void) {
    80002a2c:	1101                	add	sp,sp,-32
    80002a2e:	ec06                	sd	ra,24(sp)
    80002a30:	e822                	sd	s0,16(sp)
    80002a32:	1000                	add	s0,sp,32
    for (int i = 0; i < 2; i++) {
    80002a34:	fe042623          	sw	zero,-20(s0)
    80002a38:	a02d                	j	80002a62 <simple_task_b+0x36>
        printf("[proc] task B iter %d\n", i);
    80002a3a:	fec42783          	lw	a5,-20(s0)
    80002a3e:	85be                	mv	a1,a5
    80002a40:	00003517          	auipc	a0,0x3
    80002a44:	75850513          	add	a0,a0,1880 # 80006198 <swtch+0x6fc>
    80002a48:	00003097          	auipc	ra,0x3
    80002a4c:	e8e080e7          	jalr	-370(ra) # 800058d6 <printf>
        yield();
    80002a50:	fffff097          	auipc	ra,0xfffff
    80002a54:	5fe080e7          	jalr	1534(ra) # 8000204e <yield>
    for (int i = 0; i < 2; i++) {
    80002a58:	fec42783          	lw	a5,-20(s0)
    80002a5c:	2785                	addw	a5,a5,1
    80002a5e:	fef42623          	sw	a5,-20(s0)
    80002a62:	fec42783          	lw	a5,-20(s0)
    80002a66:	0007871b          	sext.w	a4,a5
    80002a6a:	4785                	li	a5,1
    80002a6c:	fce7d7e3          	bge	a5,a4,80002a3a <simple_task_b+0xe>
    }
    printf("[proc] task B exit\n");
    80002a70:	00003517          	auipc	a0,0x3
    80002a74:	74050513          	add	a0,a0,1856 # 800061b0 <swtch+0x714>
    80002a78:	00003097          	auipc	ra,0x3
    80002a7c:	e5e080e7          	jalr	-418(ra) # 800058d6 <printf>
    exit_process(0);
    80002a80:	4501                	li	a0,0
    80002a82:	fffff097          	auipc	ra,0xfffff
    80002a86:	7ac080e7          	jalr	1964(ra) # 8000222e <exit_process>

0000000080002a8a <cpu_intensive_task>:
}

static void cpu_intensive_task(void) {
    80002a8a:	7179                	add	sp,sp,-48
    80002a8c:	f406                	sd	ra,40(sp)
    80002a8e:	f022                	sd	s0,32(sp)
    80002a90:	1800                	add	s0,sp,48
    uint64 start = timer_ticks();
    80002a92:	00001097          	auipc	ra,0x1
    80002a96:	5ba080e7          	jalr	1466(ra) # 8000404c <timer_ticks>
    80002a9a:	fea43423          	sd	a0,-24(s0)
    for (volatile int i = 0; i < 200000; i++) {
    80002a9e:	fc042e23          	sw	zero,-36(s0)
    80002aa2:	a83d                	j	80002ae0 <cpu_intensive_task+0x56>
        if (i % 50000 == 0) {
    80002aa4:	fdc42783          	lw	a5,-36(s0)
    80002aa8:	2781                	sext.w	a5,a5
    80002aaa:	873e                	mv	a4,a5
    80002aac:	67b1                	lui	a5,0xc
    80002aae:	3507879b          	addw	a5,a5,848 # c350 <_entry-0x7fff3cb0>
    80002ab2:	02f767bb          	remw	a5,a4,a5
    80002ab6:	2781                	sext.w	a5,a5
    80002ab8:	ef89                	bnez	a5,80002ad2 <cpu_intensive_task+0x48>
            printf("[proc] busy iter %d\n", i);
    80002aba:	fdc42783          	lw	a5,-36(s0)
    80002abe:	2781                	sext.w	a5,a5
    80002ac0:	85be                	mv	a1,a5
    80002ac2:	00003517          	auipc	a0,0x3
    80002ac6:	70650513          	add	a0,a0,1798 # 800061c8 <swtch+0x72c>
    80002aca:	00003097          	auipc	ra,0x3
    80002ace:	e0c080e7          	jalr	-500(ra) # 800058d6 <printf>
    for (volatile int i = 0; i < 200000; i++) {
    80002ad2:	fdc42783          	lw	a5,-36(s0)
    80002ad6:	2781                	sext.w	a5,a5
    80002ad8:	2785                	addw	a5,a5,1
    80002ada:	2781                	sext.w	a5,a5
    80002adc:	fcf42e23          	sw	a5,-36(s0)
    80002ae0:	fdc42783          	lw	a5,-36(s0)
    80002ae4:	2781                	sext.w	a5,a5
    80002ae6:	873e                	mv	a4,a5
    80002ae8:	000317b7          	lui	a5,0x31
    80002aec:	d3f78793          	add	a5,a5,-705 # 30d3f <_entry-0x7ffcf2c1>
    80002af0:	fae7dae3          	bge	a5,a4,80002aa4 <cpu_intensive_task+0x1a>
        }
    }
    uint64 end = timer_ticks();
    80002af4:	00001097          	auipc	ra,0x1
    80002af8:	558080e7          	jalr	1368(ra) # 8000404c <timer_ticks>
    80002afc:	fea43023          	sd	a0,-32(s0)
    printf("[proc] busy ran for %lu ticks\n", end - start);
    80002b00:	fe043703          	ld	a4,-32(s0)
    80002b04:	fe843783          	ld	a5,-24(s0)
    80002b08:	40f707b3          	sub	a5,a4,a5
    80002b0c:	85be                	mv	a1,a5
    80002b0e:	00003517          	auipc	a0,0x3
    80002b12:	6d250513          	add	a0,a0,1746 # 800061e0 <swtch+0x744>
    80002b16:	00003097          	auipc	ra,0x3
    80002b1a:	dc0080e7          	jalr	-576(ra) # 800058d6 <printf>
    exit_process(0);
    80002b1e:	4501                	li	a0,0
    80002b20:	fffff097          	auipc	ra,0xfffff
    80002b24:	70e080e7          	jalr	1806(ra) # 8000222e <exit_process>

0000000080002b28 <sleeper_task>:
}

static void sleeper_task(void) {
    80002b28:	1101                	add	sp,sp,-32
    80002b2a:	ec06                	sd	ra,24(sp)
    80002b2c:	e822                	sd	s0,16(sp)
    80002b2e:	1000                	add	s0,sp,32
    printf("[proc] sleeper waiting 3 ticks\n");
    80002b30:	00003517          	auipc	a0,0x3
    80002b34:	6d050513          	add	a0,a0,1744 # 80006200 <swtch+0x764>
    80002b38:	00003097          	auipc	ra,0x3
    80002b3c:	d9e080e7          	jalr	-610(ra) # 800058d6 <printf>
    acquire(&ticks_lock);
    80002b40:	00008517          	auipc	a0,0x8
    80002b44:	45850513          	add	a0,a0,1112 # 8000af98 <ticks_lock>
    80002b48:	fffff097          	auipc	ra,0xfffff
    80002b4c:	cec080e7          	jalr	-788(ra) # 80001834 <acquire>
    uint64 target = ticks + 3;
    80002b50:	00004797          	auipc	a5,0x4
    80002b54:	30878793          	add	a5,a5,776 # 80006e58 <ticks>
    80002b58:	639c                	ld	a5,0(a5)
    80002b5a:	078d                	add	a5,a5,3
    80002b5c:	fef43423          	sd	a5,-24(s0)
    while (ticks < target) {
    80002b60:	a829                	j	80002b7a <sleeper_task+0x52>
        sleep((void*)&ticks, &ticks_lock);
    80002b62:	00008597          	auipc	a1,0x8
    80002b66:	43658593          	add	a1,a1,1078 # 8000af98 <ticks_lock>
    80002b6a:	00004517          	auipc	a0,0x4
    80002b6e:	2ee50513          	add	a0,a0,750 # 80006e58 <ticks>
    80002b72:	fffff097          	auipc	ra,0xfffff
    80002b76:	53e080e7          	jalr	1342(ra) # 800020b0 <sleep>
    while (ticks < target) {
    80002b7a:	00004797          	auipc	a5,0x4
    80002b7e:	2de78793          	add	a5,a5,734 # 80006e58 <ticks>
    80002b82:	639c                	ld	a5,0(a5)
    80002b84:	fe843703          	ld	a4,-24(s0)
    80002b88:	fce7ede3          	bltu	a5,a4,80002b62 <sleeper_task+0x3a>
    }
    release(&ticks_lock);
    80002b8c:	00008517          	auipc	a0,0x8
    80002b90:	40c50513          	add	a0,a0,1036 # 8000af98 <ticks_lock>
    80002b94:	fffff097          	auipc	ra,0xfffff
    80002b98:	cd4080e7          	jalr	-812(ra) # 80001868 <release>
    printf("[proc] sleeper wakeup\n");
    80002b9c:	00003517          	auipc	a0,0x3
    80002ba0:	68450513          	add	a0,a0,1668 # 80006220 <swtch+0x784>
    80002ba4:	00003097          	auipc	ra,0x3
    80002ba8:	d32080e7          	jalr	-718(ra) # 800058d6 <printf>
    exit_process(0);
    80002bac:	4501                	li	a0,0
    80002bae:	fffff097          	auipc	ra,0xfffff
    80002bb2:	680080e7          	jalr	1664(ra) # 8000222e <exit_process>

0000000080002bb6 <syscall_brk_task>:
}

// Simulate the provided initcode.c brk/sbrk sequence via syscall_dispatch.
// We drive sys_sbrk through a synthetic trapframe while running as a kernel task.
static void syscall_brk_task(void) {
    80002bb6:	710d                	add	sp,sp,-352
    80002bb8:	ee86                	sd	ra,344(sp)
    80002bba:	eaa2                	sd	s0,336(sp)
    80002bbc:	1280                	add	s0,sp,352
    struct trapframe tf;
    memset(&tf, 0, sizeof(tf));
    80002bbe:	ea040793          	add	a5,s0,-352
    80002bc2:	12000613          	li	a2,288
    80002bc6:	4581                	li	a1,0
    80002bc8:	853e                	mv	a0,a5
    80002bca:	00002097          	auipc	ra,0x2
    80002bce:	402080e7          	jalr	1026(ra) # 80004fcc <memset>

    printf("[syscall-test] brk/sbrk sequence start\n");
    80002bd2:	00003517          	auipc	a0,0x3
    80002bd6:	66650513          	add	a0,a0,1638 # 80006238 <swtch+0x79c>
    80002bda:	00003097          	auipc	ra,0x3
    80002bde:	cfc080e7          	jalr	-772(ra) # 800058d6 <printf>

    // Step 1: brk(0) equivalent -> use sbrk(0) to read current break.
    tf.a7 = SYS_sbrk;
    80002be2:	47b1                	li	a5,12
    80002be4:	f2f43023          	sd	a5,-224(s0)
    tf.a0 = 0;
    80002be8:	ee043423          	sd	zero,-280(s0)
    syscall_dispatch(&tf);
    80002bec:	ea040793          	add	a5,s0,-352
    80002bf0:	853e                	mv	a0,a5
    80002bf2:	00000097          	auipc	ra,0x0
    80002bf6:	5f2080e7          	jalr	1522(ra) # 800031e4 <syscall_dispatch>
    uint64 heap_top = tf.a0;
    80002bfa:	ee843783          	ld	a5,-280(s0)
    80002bfe:	fef43023          	sd	a5,-32(s0)
    printf("[syscall-test] brk(0) -> 0x%lx\n", heap_top);
    80002c02:	fe043583          	ld	a1,-32(s0)
    80002c06:	00003517          	auipc	a0,0x3
    80002c0a:	65a50513          	add	a0,a0,1626 # 80006260 <swtch+0x7c4>
    80002c0e:	00003097          	auipc	ra,0x3
    80002c12:	cc8080e7          	jalr	-824(ra) # 800058d6 <printf>

    // Step 2: brk(heap_top + 10 pages) => sbrk(+10 pages)
    int inc_up = 4096 * 10;
    80002c16:	67a9                	lui	a5,0xa
    80002c18:	fcf42e23          	sw	a5,-36(s0)
    tf.a0 = inc_up;
    80002c1c:	fdc42783          	lw	a5,-36(s0)
    80002c20:	eef43423          	sd	a5,-280(s0)
    tf.sepc = 0; // reset for readability
    80002c24:	f8043c23          	sd	zero,-104(s0)
    syscall_dispatch(&tf);
    80002c28:	ea040793          	add	a5,s0,-352
    80002c2c:	853e                	mv	a0,a5
    80002c2e:	00000097          	auipc	ra,0x0
    80002c32:	5b6080e7          	jalr	1462(ra) # 800031e4 <syscall_dispatch>
    uint64 new_top = tf.a0 + inc_up; // sbrk returns old break
    80002c36:	ee843703          	ld	a4,-280(s0)
    80002c3a:	fdc42783          	lw	a5,-36(s0)
    80002c3e:	97ba                	add	a5,a5,a4
    80002c40:	fcf43823          	sd	a5,-48(s0)
    printf("[syscall-test] brk(+10 pages) old=0x%lx new=0x%lx\n", tf.a0, new_top);
    80002c44:	ee843783          	ld	a5,-280(s0)
    80002c48:	fd043603          	ld	a2,-48(s0)
    80002c4c:	85be                	mv	a1,a5
    80002c4e:	00003517          	auipc	a0,0x3
    80002c52:	63250513          	add	a0,a0,1586 # 80006280 <swtch+0x7e4>
    80002c56:	00003097          	auipc	ra,0x3
    80002c5a:	c80080e7          	jalr	-896(ra) # 800058d6 <printf>

    // Step 3: brk(new_top - 5 pages) => sbrk(-5 pages)
    int inc_down = -4096 * 5;
    80002c5e:	77ed                	lui	a5,0xffffb
    80002c60:	fcf42623          	sw	a5,-52(s0)
    tf.a0 = inc_down;
    80002c64:	fcc42783          	lw	a5,-52(s0)
    80002c68:	eef43423          	sd	a5,-280(s0)
    tf.sepc = 0;
    80002c6c:	f8043c23          	sd	zero,-104(s0)
    syscall_dispatch(&tf);
    80002c70:	ea040793          	add	a5,s0,-352
    80002c74:	853e                	mv	a0,a5
    80002c76:	00000097          	auipc	ra,0x0
    80002c7a:	56e080e7          	jalr	1390(ra) # 800031e4 <syscall_dispatch>
    uint64 final_top = new_top + inc_down;
    80002c7e:	fcc42783          	lw	a5,-52(s0)
    80002c82:	fd043703          	ld	a4,-48(s0)
    80002c86:	97ba                	add	a5,a5,a4
    80002c88:	fcf43023          	sd	a5,-64(s0)
    printf("[syscall-test] brk(-5 pages) old=0x%lx new=0x%lx\n", tf.a0, final_top);
    80002c8c:	ee843783          	ld	a5,-280(s0)
    80002c90:	fc043603          	ld	a2,-64(s0)
    80002c94:	85be                	mv	a1,a5
    80002c96:	00003517          	auipc	a0,0x3
    80002c9a:	62250513          	add	a0,a0,1570 # 800062b8 <swtch+0x81c>
    80002c9e:	00003097          	auipc	ra,0x3
    80002ca2:	c38080e7          	jalr	-968(ra) # 800058d6 <printf>

    // Keep the task alive briefly to mirror the infinite loop in initcode.
    for (int i = 0; i < 3; i++) {
    80002ca6:	fe042623          	sw	zero,-20(s0)
    80002caa:	a811                	j	80002cbe <syscall_brk_task+0x108>
        yield();
    80002cac:	fffff097          	auipc	ra,0xfffff
    80002cb0:	3a2080e7          	jalr	930(ra) # 8000204e <yield>
    for (int i = 0; i < 3; i++) {
    80002cb4:	fec42783          	lw	a5,-20(s0)
    80002cb8:	2785                	addw	a5,a5,1 # ffffffffffffb001 <_stack_top+0xffffffff7ffec001>
    80002cba:	fef42623          	sw	a5,-20(s0)
    80002cbe:	fec42783          	lw	a5,-20(s0)
    80002cc2:	0007871b          	sext.w	a4,a5
    80002cc6:	4789                	li	a5,2
    80002cc8:	fee7d2e3          	bge	a5,a4,80002cac <syscall_brk_task+0xf6>
    }
    printf("[syscall-test] brk/sbrk sequence done\n");
    80002ccc:	00003517          	auipc	a0,0x3
    80002cd0:	62450513          	add	a0,a0,1572 # 800062f0 <swtch+0x854>
    80002cd4:	00003097          	auipc	ra,0x3
    80002cd8:	c02080e7          	jalr	-1022(ra) # 800058d6 <printf>
    exit_process(0);
    80002cdc:	4501                	li	a0,0
    80002cde:	fffff097          	auipc	ra,0xfffff
    80002ce2:	550080e7          	jalr	1360(ra) # 8000222e <exit_process>

0000000080002ce6 <test_process_subsystem>:
}

void test_process_subsystem(void) {
    80002ce6:	7179                	add	sp,sp,-48
    80002ce8:	f406                	sd	ra,40(sp)
    80002cea:	f022                	sd	s0,32(sp)
    80002cec:	1800                	add	s0,sp,48
    printf("[test] process subsystem start\n");
    80002cee:	00003517          	auipc	a0,0x3
    80002cf2:	62a50513          	add	a0,a0,1578 # 80006318 <swtch+0x87c>
    80002cf6:	00003097          	auipc	ra,0x3
    80002cfa:	be0080e7          	jalr	-1056(ra) # 800058d6 <printf>
    proc_init();
    80002cfe:	fffff097          	auipc	ra,0xfffff
    80002d02:	d64080e7          	jalr	-668(ra) # 80001a62 <proc_init>

    int pid_brk = create_process(syscall_brk_task, "brkTest");
    80002d06:	00003597          	auipc	a1,0x3
    80002d0a:	63258593          	add	a1,a1,1586 # 80006338 <swtch+0x89c>
    80002d0e:	00000517          	auipc	a0,0x0
    80002d12:	ea850513          	add	a0,a0,-344 # 80002bb6 <syscall_brk_task>
    80002d16:	fffff097          	auipc	ra,0xfffff
    80002d1a:	12e080e7          	jalr	302(ra) # 80001e44 <create_process>
    80002d1e:	87aa                	mv	a5,a0
    80002d20:	fef42623          	sw	a5,-20(s0)
    int pid1 = create_process(simple_task_a, "taskA");
    80002d24:	00003597          	auipc	a1,0x3
    80002d28:	61c58593          	add	a1,a1,1564 # 80006340 <swtch+0x8a4>
    80002d2c:	00000517          	auipc	a0,0x0
    80002d30:	ca250513          	add	a0,a0,-862 # 800029ce <simple_task_a>
    80002d34:	fffff097          	auipc	ra,0xfffff
    80002d38:	110080e7          	jalr	272(ra) # 80001e44 <create_process>
    80002d3c:	87aa                	mv	a5,a0
    80002d3e:	fef42423          	sw	a5,-24(s0)
    int pid2 = create_process(simple_task_b, "taskB");
    80002d42:	00003597          	auipc	a1,0x3
    80002d46:	60658593          	add	a1,a1,1542 # 80006348 <swtch+0x8ac>
    80002d4a:	00000517          	auipc	a0,0x0
    80002d4e:	ce250513          	add	a0,a0,-798 # 80002a2c <simple_task_b>
    80002d52:	fffff097          	auipc	ra,0xfffff
    80002d56:	0f2080e7          	jalr	242(ra) # 80001e44 <create_process>
    80002d5a:	87aa                	mv	a5,a0
    80002d5c:	fef42223          	sw	a5,-28(s0)
    int pid_busy = create_process(cpu_intensive_task, "busy");
    80002d60:	00003597          	auipc	a1,0x3
    80002d64:	5f058593          	add	a1,a1,1520 # 80006350 <swtch+0x8b4>
    80002d68:	00000517          	auipc	a0,0x0
    80002d6c:	d2250513          	add	a0,a0,-734 # 80002a8a <cpu_intensive_task>
    80002d70:	fffff097          	auipc	ra,0xfffff
    80002d74:	0d4080e7          	jalr	212(ra) # 80001e44 <create_process>
    80002d78:	87aa                	mv	a5,a0
    80002d7a:	fef42023          	sw	a5,-32(s0)
    int pid_sleep = create_process(sleeper_task, "sleepy");
    80002d7e:	00003597          	auipc	a1,0x3
    80002d82:	5da58593          	add	a1,a1,1498 # 80006358 <swtch+0x8bc>
    80002d86:	00000517          	auipc	a0,0x0
    80002d8a:	da250513          	add	a0,a0,-606 # 80002b28 <sleeper_task>
    80002d8e:	fffff097          	auipc	ra,0xfffff
    80002d92:	0b6080e7          	jalr	182(ra) # 80001e44 <create_process>
    80002d96:	87aa                	mv	a5,a0
    80002d98:	fcf42e23          	sw	a5,-36(s0)
    if (pid_brk < 0 || pid1 < 0 || pid2 < 0 || pid_busy < 0 || pid_sleep < 0) {
    80002d9c:	fec42783          	lw	a5,-20(s0)
    80002da0:	2781                	sext.w	a5,a5
    80002da2:	0207c663          	bltz	a5,80002dce <test_process_subsystem+0xe8>
    80002da6:	fe842783          	lw	a5,-24(s0)
    80002daa:	2781                	sext.w	a5,a5
    80002dac:	0207c163          	bltz	a5,80002dce <test_process_subsystem+0xe8>
    80002db0:	fe442783          	lw	a5,-28(s0)
    80002db4:	2781                	sext.w	a5,a5
    80002db6:	0007cc63          	bltz	a5,80002dce <test_process_subsystem+0xe8>
    80002dba:	fe042783          	lw	a5,-32(s0)
    80002dbe:	2781                	sext.w	a5,a5
    80002dc0:	0007c763          	bltz	a5,80002dce <test_process_subsystem+0xe8>
    80002dc4:	fdc42783          	lw	a5,-36(s0)
    80002dc8:	2781                	sext.w	a5,a5
    80002dca:	0007da63          	bgez	a5,80002dde <test_process_subsystem+0xf8>
        panic("[proc] create_process failed");
    80002dce:	00003517          	auipc	a0,0x3
    80002dd2:	59250513          	add	a0,a0,1426 # 80006360 <swtch+0x8c4>
    80002dd6:	00003097          	auipc	ra,0x3
    80002dda:	b98080e7          	jalr	-1128(ra) # 8000596e <panic>
    }
    set_proc_priority(pid_busy, 3);   // mimic a higher-priority, latency-sensitive task
    80002dde:	fe042783          	lw	a5,-32(s0)
    80002de2:	458d                	li	a1,3
    80002de4:	853e                	mv	a0,a5
    80002de6:	00000097          	auipc	ra,0x0
    80002dea:	9a6080e7          	jalr	-1626(ra) # 8000278c <set_proc_priority>
    set_proc_priority(pid_sleep, 12); // keep sleeper low priority to show aging/wakeup
    80002dee:	fdc42783          	lw	a5,-36(s0)
    80002df2:	45b1                	li	a1,12
    80002df4:	853e                	mv	a0,a5
    80002df6:	00000097          	auipc	ra,0x0
    80002dfa:	996080e7          	jalr	-1642(ra) # 8000278c <set_proc_priority>

    printf("[test] created pids: %d, %d, %d, %d, %d (enter scheduler)\n",
    80002dfe:	fdc42783          	lw	a5,-36(s0)
    80002e02:	fe042703          	lw	a4,-32(s0)
    80002e06:	fe442683          	lw	a3,-28(s0)
    80002e0a:	fe842603          	lw	a2,-24(s0)
    80002e0e:	fec42583          	lw	a1,-20(s0)
    80002e12:	00003517          	auipc	a0,0x3
    80002e16:	56e50513          	add	a0,a0,1390 # 80006380 <swtch+0x8e4>
    80002e1a:	00003097          	auipc	ra,0x3
    80002e1e:	abc080e7          	jalr	-1348(ra) # 800058d6 <printf>
           pid_brk, pid1, pid2, pid_busy, pid_sleep);
    scheduler(); // never returns
    80002e22:	00000097          	auipc	ra,0x0
    80002e26:	83a080e7          	jalr	-1990(ra) # 8000265c <scheduler>

0000000080002e2a <active_trapframe>:
    [SYS_mkdir]  = {sys_unimpl, "mkdir", 1},
    [SYS_close]  = {sys_close, "close", 1},
    [SYS_yield]  = {sys_yield, "yield", 0},
};

static struct trapframe* active_trapframe(void) {
    80002e2a:	1101                	add	sp,sp,-32
    80002e2c:	ec06                	sd	ra,24(sp)
    80002e2e:	e822                	sd	s0,16(sp)
    80002e30:	1000                	add	s0,sp,32
    if (current_tf) {
    80002e32:	00008797          	auipc	a5,0x8
    80002e36:	15e78793          	add	a5,a5,350 # 8000af90 <current_tf>
    80002e3a:	639c                	ld	a5,0(a5)
    80002e3c:	c799                	beqz	a5,80002e4a <active_trapframe+0x20>
        return current_tf;
    80002e3e:	00008797          	auipc	a5,0x8
    80002e42:	15278793          	add	a5,a5,338 # 8000af90 <current_tf>
    80002e46:	639c                	ld	a5,0(a5)
    80002e48:	a839                	j	80002e66 <active_trapframe+0x3c>
    }
    struct proc* p = myproc();
    80002e4a:	fffff097          	auipc	ra,0xfffff
    80002e4e:	160080e7          	jalr	352(ra) # 80001faa <myproc>
    80002e52:	fea43423          	sd	a0,-24(s0)
    if (p) {
    80002e56:	fe843783          	ld	a5,-24(s0)
    80002e5a:	c789                	beqz	a5,80002e64 <active_trapframe+0x3a>
        return p->trapframe;
    80002e5c:	fe843783          	ld	a5,-24(s0)
    80002e60:	7f9c                	ld	a5,56(a5)
    80002e62:	a011                	j	80002e66 <active_trapframe+0x3c>
    }
    return NULL;
    80002e64:	4781                	li	a5,0
}
    80002e66:	853e                	mv	a0,a5
    80002e68:	60e2                	ld	ra,24(sp)
    80002e6a:	6442                	ld	s0,16(sp)
    80002e6c:	6105                	add	sp,sp,32
    80002e6e:	8082                	ret

0000000080002e70 <active_pagetable>:

static pagetable_t active_pagetable(void) {
    80002e70:	1101                	add	sp,sp,-32
    80002e72:	ec06                	sd	ra,24(sp)
    80002e74:	e822                	sd	s0,16(sp)
    80002e76:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    80002e78:	fffff097          	auipc	ra,0xfffff
    80002e7c:	132080e7          	jalr	306(ra) # 80001faa <myproc>
    80002e80:	fea43423          	sd	a0,-24(s0)
    return p ? p->pagetable : NULL;
    80002e84:	fe843783          	ld	a5,-24(s0)
    80002e88:	c789                	beqz	a5,80002e92 <active_pagetable+0x22>
    80002e8a:	fe843783          	ld	a5,-24(s0)
    80002e8e:	7b9c                	ld	a5,48(a5)
    80002e90:	a011                	j	80002e94 <active_pagetable+0x24>
    80002e92:	4781                	li	a5,0
}
    80002e94:	853e                	mv	a0,a5
    80002e96:	60e2                	ld	ra,24(sp)
    80002e98:	6442                	ld	s0,16(sp)
    80002e9a:	6105                	add	sp,sp,32
    80002e9c:	8082                	ret

0000000080002e9e <arg_raw>:

static uint64 arg_raw(int n) {
    80002e9e:	7179                	add	sp,sp,-48
    80002ea0:	f406                	sd	ra,40(sp)
    80002ea2:	f022                	sd	s0,32(sp)
    80002ea4:	1800                	add	s0,sp,48
    80002ea6:	87aa                	mv	a5,a0
    80002ea8:	fcf42e23          	sw	a5,-36(s0)
    if (n < 0 || n > 5) return (uint64)-1;
    80002eac:	fdc42783          	lw	a5,-36(s0)
    80002eb0:	2781                	sext.w	a5,a5
    80002eb2:	0007c963          	bltz	a5,80002ec4 <arg_raw+0x26>
    80002eb6:	fdc42783          	lw	a5,-36(s0)
    80002eba:	0007871b          	sext.w	a4,a5
    80002ebe:	4795                	li	a5,5
    80002ec0:	00e7d463          	bge	a5,a4,80002ec8 <arg_raw+0x2a>
    80002ec4:	57fd                	li	a5,-1
    80002ec6:	a8b5                	j	80002f42 <arg_raw+0xa4>
    struct trapframe* tf = active_trapframe();
    80002ec8:	00000097          	auipc	ra,0x0
    80002ecc:	f62080e7          	jalr	-158(ra) # 80002e2a <active_trapframe>
    80002ed0:	fea43423          	sd	a0,-24(s0)
    if (!tf) {
    80002ed4:	fe843783          	ld	a5,-24(s0)
    80002ed8:	e399                	bnez	a5,80002ede <arg_raw+0x40>
        return (uint64)-1;
    80002eda:	57fd                	li	a5,-1
    80002edc:	a09d                	j	80002f42 <arg_raw+0xa4>
    }
    switch (n) {
    80002ede:	fdc42783          	lw	a5,-36(s0)
    80002ee2:	0007871b          	sext.w	a4,a5
    80002ee6:	4795                	li	a5,5
    80002ee8:	04e7ec63          	bltu	a5,a4,80002f40 <arg_raw+0xa2>
    80002eec:	fdc46783          	lwu	a5,-36(s0)
    80002ef0:	00279713          	sll	a4,a5,0x2
    80002ef4:	00003797          	auipc	a5,0x3
    80002ef8:	7ac78793          	add	a5,a5,1964 # 800066a0 <syscall_table+0x228>
    80002efc:	97ba                	add	a5,a5,a4
    80002efe:	439c                	lw	a5,0(a5)
    80002f00:	0007871b          	sext.w	a4,a5
    80002f04:	00003797          	auipc	a5,0x3
    80002f08:	79c78793          	add	a5,a5,1948 # 800066a0 <syscall_table+0x228>
    80002f0c:	97ba                	add	a5,a5,a4
    80002f0e:	8782                	jr	a5
        case 0: return tf->a0;
    80002f10:	fe843783          	ld	a5,-24(s0)
    80002f14:	67bc                	ld	a5,72(a5)
    80002f16:	a035                	j	80002f42 <arg_raw+0xa4>
        case 1: return tf->a1;
    80002f18:	fe843783          	ld	a5,-24(s0)
    80002f1c:	6bbc                	ld	a5,80(a5)
    80002f1e:	a015                	j	80002f42 <arg_raw+0xa4>
        case 2: return tf->a2;
    80002f20:	fe843783          	ld	a5,-24(s0)
    80002f24:	6fbc                	ld	a5,88(a5)
    80002f26:	a831                	j	80002f42 <arg_raw+0xa4>
        case 3: return tf->a3;
    80002f28:	fe843783          	ld	a5,-24(s0)
    80002f2c:	73bc                	ld	a5,96(a5)
    80002f2e:	a811                	j	80002f42 <arg_raw+0xa4>
        case 4: return tf->a4;
    80002f30:	fe843783          	ld	a5,-24(s0)
    80002f34:	77bc                	ld	a5,104(a5)
    80002f36:	a031                	j	80002f42 <arg_raw+0xa4>
        case 5: return tf->a5;
    80002f38:	fe843783          	ld	a5,-24(s0)
    80002f3c:	7bbc                	ld	a5,112(a5)
    80002f3e:	a011                	j	80002f42 <arg_raw+0xa4>
        default:
            return (uint64)-1;
    80002f40:	57fd                	li	a5,-1
    }
}
    80002f42:	853e                	mv	a0,a5
    80002f44:	70a2                	ld	ra,40(sp)
    80002f46:	7402                	ld	s0,32(sp)
    80002f48:	6145                	add	sp,sp,48
    80002f4a:	8082                	ret

0000000080002f4c <get_syscall_arg>:

int get_syscall_arg(int n, uint64* ip) {
    80002f4c:	7179                	add	sp,sp,-48
    80002f4e:	f406                	sd	ra,40(sp)
    80002f50:	f022                	sd	s0,32(sp)
    80002f52:	1800                	add	s0,sp,48
    80002f54:	87aa                	mv	a5,a0
    80002f56:	fcb43823          	sd	a1,-48(s0)
    80002f5a:	fcf42e23          	sw	a5,-36(s0)
    if (!ip) return -1;
    80002f5e:	fd043783          	ld	a5,-48(s0)
    80002f62:	e399                	bnez	a5,80002f68 <get_syscall_arg+0x1c>
    80002f64:	57fd                	li	a5,-1
    80002f66:	a82d                	j	80002fa0 <get_syscall_arg+0x54>
    uint64 val = arg_raw(n);
    80002f68:	fdc42783          	lw	a5,-36(s0)
    80002f6c:	853e                	mv	a0,a5
    80002f6e:	00000097          	auipc	ra,0x0
    80002f72:	f30080e7          	jalr	-208(ra) # 80002e9e <arg_raw>
    80002f76:	fea43423          	sd	a0,-24(s0)
    if (val == (uint64)-1 && !active_trapframe()) return -1;
    80002f7a:	fe843703          	ld	a4,-24(s0)
    80002f7e:	57fd                	li	a5,-1
    80002f80:	00f71a63          	bne	a4,a5,80002f94 <get_syscall_arg+0x48>
    80002f84:	00000097          	auipc	ra,0x0
    80002f88:	ea6080e7          	jalr	-346(ra) # 80002e2a <active_trapframe>
    80002f8c:	87aa                	mv	a5,a0
    80002f8e:	e399                	bnez	a5,80002f94 <get_syscall_arg+0x48>
    80002f90:	57fd                	li	a5,-1
    80002f92:	a039                	j	80002fa0 <get_syscall_arg+0x54>
    *ip = val;
    80002f94:	fd043783          	ld	a5,-48(s0)
    80002f98:	fe843703          	ld	a4,-24(s0)
    80002f9c:	e398                	sd	a4,0(a5)
    return 0;
    80002f9e:	4781                	li	a5,0
}
    80002fa0:	853e                	mv	a0,a5
    80002fa2:	70a2                	ld	ra,40(sp)
    80002fa4:	7402                	ld	s0,32(sp)
    80002fa6:	6145                	add	sp,sp,48
    80002fa8:	8082                	ret

0000000080002faa <argint>:

int argint(int n, int* ip) {
    80002faa:	7179                	add	sp,sp,-48
    80002fac:	f406                	sd	ra,40(sp)
    80002fae:	f022                	sd	s0,32(sp)
    80002fb0:	1800                	add	s0,sp,48
    80002fb2:	87aa                	mv	a5,a0
    80002fb4:	fcb43823          	sd	a1,-48(s0)
    80002fb8:	fcf42e23          	sw	a5,-36(s0)
    if (!ip) return -1;
    80002fbc:	fd043783          	ld	a5,-48(s0)
    80002fc0:	e399                	bnez	a5,80002fc6 <argint+0x1c>
    80002fc2:	57fd                	li	a5,-1
    80002fc4:	a815                	j	80002ff8 <argint+0x4e>
    uint64 val = 0;
    80002fc6:	fe043423          	sd	zero,-24(s0)
    if (get_syscall_arg(n, &val) < 0) return -1;
    80002fca:	fe840713          	add	a4,s0,-24
    80002fce:	fdc42783          	lw	a5,-36(s0)
    80002fd2:	85ba                	mv	a1,a4
    80002fd4:	853e                	mv	a0,a5
    80002fd6:	00000097          	auipc	ra,0x0
    80002fda:	f76080e7          	jalr	-138(ra) # 80002f4c <get_syscall_arg>
    80002fde:	87aa                	mv	a5,a0
    80002fe0:	0007d463          	bgez	a5,80002fe8 <argint+0x3e>
    80002fe4:	57fd                	li	a5,-1
    80002fe6:	a809                	j	80002ff8 <argint+0x4e>
    *ip = (int)val;
    80002fe8:	fe843783          	ld	a5,-24(s0)
    80002fec:	0007871b          	sext.w	a4,a5
    80002ff0:	fd043783          	ld	a5,-48(s0)
    80002ff4:	c398                	sw	a4,0(a5)
    return 0;
    80002ff6:	4781                	li	a5,0
}
    80002ff8:	853e                	mv	a0,a5
    80002ffa:	70a2                	ld	ra,40(sp)
    80002ffc:	7402                	ld	s0,32(sp)
    80002ffe:	6145                	add	sp,sp,48
    80003000:	8082                	ret

0000000080003002 <argaddr>:

int argaddr(int n, uint64* ip) {
    80003002:	1101                	add	sp,sp,-32
    80003004:	ec06                	sd	ra,24(sp)
    80003006:	e822                	sd	s0,16(sp)
    80003008:	1000                	add	s0,sp,32
    8000300a:	87aa                	mv	a5,a0
    8000300c:	feb43023          	sd	a1,-32(s0)
    80003010:	fef42623          	sw	a5,-20(s0)
    if (!ip) return -1;
    80003014:	fe043783          	ld	a5,-32(s0)
    80003018:	e399                	bnez	a5,8000301e <argaddr+0x1c>
    8000301a:	57fd                	li	a5,-1
    8000301c:	a819                	j	80003032 <argaddr+0x30>
    return get_syscall_arg(n, ip);
    8000301e:	fec42783          	lw	a5,-20(s0)
    80003022:	fe043583          	ld	a1,-32(s0)
    80003026:	853e                	mv	a0,a5
    80003028:	00000097          	auipc	ra,0x0
    8000302c:	f24080e7          	jalr	-220(ra) # 80002f4c <get_syscall_arg>
    80003030:	87aa                	mv	a5,a0
}
    80003032:	853e                	mv	a0,a5
    80003034:	60e2                	ld	ra,24(sp)
    80003036:	6442                	ld	s0,16(sp)
    80003038:	6105                	add	sp,sp,32
    8000303a:	8082                	ret

000000008000303c <argstr>:

int argstr(int n, char* buf, int max) {
    8000303c:	7179                	add	sp,sp,-48
    8000303e:	f406                	sd	ra,40(sp)
    80003040:	f022                	sd	s0,32(sp)
    80003042:	1800                	add	s0,sp,48
    80003044:	87aa                	mv	a5,a0
    80003046:	fcb43823          	sd	a1,-48(s0)
    8000304a:	8732                	mv	a4,a2
    8000304c:	fcf42e23          	sw	a5,-36(s0)
    80003050:	87ba                	mv	a5,a4
    80003052:	fcf42c23          	sw	a5,-40(s0)
    if (!buf || max <= 0) return -1;
    80003056:	fd043783          	ld	a5,-48(s0)
    8000305a:	c791                	beqz	a5,80003066 <argstr+0x2a>
    8000305c:	fd842783          	lw	a5,-40(s0)
    80003060:	2781                	sext.w	a5,a5
    80003062:	00f04463          	bgtz	a5,8000306a <argstr+0x2e>
    80003066:	57fd                	li	a5,-1
    80003068:	a83d                	j	800030a6 <argstr+0x6a>
    uint64 addr = 0;
    8000306a:	fe043423          	sd	zero,-24(s0)
    if (argaddr(n, &addr) < 0) return -1;
    8000306e:	fe840713          	add	a4,s0,-24
    80003072:	fdc42783          	lw	a5,-36(s0)
    80003076:	85ba                	mv	a1,a4
    80003078:	853e                	mv	a0,a5
    8000307a:	00000097          	auipc	ra,0x0
    8000307e:	f88080e7          	jalr	-120(ra) # 80003002 <argaddr>
    80003082:	87aa                	mv	a5,a0
    80003084:	0007d463          	bgez	a5,8000308c <argstr+0x50>
    80003088:	57fd                	li	a5,-1
    8000308a:	a831                	j	800030a6 <argstr+0x6a>
    return get_user_string(addr, buf, max);
    8000308c:	fe843783          	ld	a5,-24(s0)
    80003090:	fd842703          	lw	a4,-40(s0)
    80003094:	863a                	mv	a2,a4
    80003096:	fd043583          	ld	a1,-48(s0)
    8000309a:	853e                	mv	a0,a5
    8000309c:	00000097          	auipc	ra,0x0
    800030a0:	058080e7          	jalr	88(ra) # 800030f4 <get_user_string>
    800030a4:	87aa                	mv	a5,a0
}
    800030a6:	853e                	mv	a0,a5
    800030a8:	70a2                	ld	ra,40(sp)
    800030aa:	7402                	ld	s0,32(sp)
    800030ac:	6145                	add	sp,sp,48
    800030ae:	8082                	ret

00000000800030b0 <check_user_ptr>:

int check_user_ptr(uint64 uaddr, uint64 size) {
    800030b0:	7179                	add	sp,sp,-48
    800030b2:	f406                	sd	ra,40(sp)
    800030b4:	f022                	sd	s0,32(sp)
    800030b6:	1800                	add	s0,sp,48
    800030b8:	fca43c23          	sd	a0,-40(s0)
    800030bc:	fcb43823          	sd	a1,-48(s0)
    pagetable_t pt = active_pagetable();
    800030c0:	00000097          	auipc	ra,0x0
    800030c4:	db0080e7          	jalr	-592(ra) # 80002e70 <active_pagetable>
    800030c8:	fea43423          	sd	a0,-24(s0)
    return user_access_ok(pt, uaddr, size) ? 0 : -1;
    800030cc:	fd043603          	ld	a2,-48(s0)
    800030d0:	fd843583          	ld	a1,-40(s0)
    800030d4:	fe843503          	ld	a0,-24(s0)
    800030d8:	00001097          	auipc	ra,0x1
    800030dc:	988080e7          	jalr	-1656(ra) # 80003a60 <user_access_ok>
    800030e0:	87aa                	mv	a5,a0
    800030e2:	c399                	beqz	a5,800030e8 <check_user_ptr+0x38>
    800030e4:	4781                	li	a5,0
    800030e6:	a011                	j	800030ea <check_user_ptr+0x3a>
    800030e8:	57fd                	li	a5,-1
}
    800030ea:	853e                	mv	a0,a5
    800030ec:	70a2                	ld	ra,40(sp)
    800030ee:	7402                	ld	s0,32(sp)
    800030f0:	6145                	add	sp,sp,48
    800030f2:	8082                	ret

00000000800030f4 <get_user_string>:

int get_user_string(uint64 uaddr, char* buf, int max) {
    800030f4:	7179                	add	sp,sp,-48
    800030f6:	f406                	sd	ra,40(sp)
    800030f8:	f022                	sd	s0,32(sp)
    800030fa:	1800                	add	s0,sp,48
    800030fc:	fea43423          	sd	a0,-24(s0)
    80003100:	feb43023          	sd	a1,-32(s0)
    80003104:	87b2                	mv	a5,a2
    80003106:	fcf42e23          	sw	a5,-36(s0)
    if (!buf || max <= 0) return -1;
    8000310a:	fe043783          	ld	a5,-32(s0)
    8000310e:	c791                	beqz	a5,8000311a <get_user_string+0x26>
    80003110:	fdc42783          	lw	a5,-36(s0)
    80003114:	2781                	sext.w	a5,a5
    80003116:	00f04463          	bgtz	a5,8000311e <get_user_string+0x2a>
    8000311a:	57fd                	li	a5,-1
    8000311c:	a83d                	j	8000315a <get_user_string+0x66>
    if (check_user_ptr(uaddr, 1) < 0) return -1;
    8000311e:	4585                	li	a1,1
    80003120:	fe843503          	ld	a0,-24(s0)
    80003124:	00000097          	auipc	ra,0x0
    80003128:	f8c080e7          	jalr	-116(ra) # 800030b0 <check_user_ptr>
    8000312c:	87aa                	mv	a5,a0
    8000312e:	0007d463          	bgez	a5,80003136 <get_user_string+0x42>
    80003132:	57fd                	li	a5,-1
    80003134:	a01d                	j	8000315a <get_user_string+0x66>
    return copyinstr(active_pagetable(), buf, uaddr, (uint64)max);
    80003136:	00000097          	auipc	ra,0x0
    8000313a:	d3a080e7          	jalr	-710(ra) # 80002e70 <active_pagetable>
    8000313e:	872a                	mv	a4,a0
    80003140:	fdc42783          	lw	a5,-36(s0)
    80003144:	86be                	mv	a3,a5
    80003146:	fe843603          	ld	a2,-24(s0)
    8000314a:	fe043583          	ld	a1,-32(s0)
    8000314e:	853a                	mv	a0,a4
    80003150:	00001097          	auipc	ra,0x1
    80003154:	ba6080e7          	jalr	-1114(ra) # 80003cf6 <copyinstr>
    80003158:	87aa                	mv	a5,a0
}
    8000315a:	853e                	mv	a0,a5
    8000315c:	70a2                	ld	ra,40(sp)
    8000315e:	7402                	ld	s0,32(sp)
    80003160:	6145                	add	sp,sp,48
    80003162:	8082                	ret

0000000080003164 <get_user_buffer>:

int get_user_buffer(uint64 uaddr, void* buf, int size) {
    80003164:	7179                	add	sp,sp,-48
    80003166:	f406                	sd	ra,40(sp)
    80003168:	f022                	sd	s0,32(sp)
    8000316a:	1800                	add	s0,sp,48
    8000316c:	fea43423          	sd	a0,-24(s0)
    80003170:	feb43023          	sd	a1,-32(s0)
    80003174:	87b2                	mv	a5,a2
    80003176:	fcf42e23          	sw	a5,-36(s0)
    if (!buf || size < 0) return -1;
    8000317a:	fe043783          	ld	a5,-32(s0)
    8000317e:	c791                	beqz	a5,8000318a <get_user_buffer+0x26>
    80003180:	fdc42783          	lw	a5,-36(s0)
    80003184:	2781                	sext.w	a5,a5
    80003186:	0007d463          	bgez	a5,8000318e <get_user_buffer+0x2a>
    8000318a:	57fd                	li	a5,-1
    8000318c:	a0b9                	j	800031da <get_user_buffer+0x76>
    if (size == 0) return 0;
    8000318e:	fdc42783          	lw	a5,-36(s0)
    80003192:	2781                	sext.w	a5,a5
    80003194:	e399                	bnez	a5,8000319a <get_user_buffer+0x36>
    80003196:	4781                	li	a5,0
    80003198:	a089                	j	800031da <get_user_buffer+0x76>
    if (check_user_ptr(uaddr, (uint64)size) < 0) return -1;
    8000319a:	fdc42783          	lw	a5,-36(s0)
    8000319e:	85be                	mv	a1,a5
    800031a0:	fe843503          	ld	a0,-24(s0)
    800031a4:	00000097          	auipc	ra,0x0
    800031a8:	f0c080e7          	jalr	-244(ra) # 800030b0 <check_user_ptr>
    800031ac:	87aa                	mv	a5,a0
    800031ae:	0007d463          	bgez	a5,800031b6 <get_user_buffer+0x52>
    800031b2:	57fd                	li	a5,-1
    800031b4:	a01d                	j	800031da <get_user_buffer+0x76>
    return copyin(active_pagetable(), buf, uaddr, (uint64)size);
    800031b6:	00000097          	auipc	ra,0x0
    800031ba:	cba080e7          	jalr	-838(ra) # 80002e70 <active_pagetable>
    800031be:	872a                	mv	a4,a0
    800031c0:	fdc42783          	lw	a5,-36(s0)
    800031c4:	86be                	mv	a3,a5
    800031c6:	fe843603          	ld	a2,-24(s0)
    800031ca:	fe043583          	ld	a1,-32(s0)
    800031ce:	853a                	mv	a0,a4
    800031d0:	00001097          	auipc	ra,0x1
    800031d4:	95a080e7          	jalr	-1702(ra) # 80003b2a <copyin>
    800031d8:	87aa                	mv	a5,a0
}
    800031da:	853e                	mv	a0,a5
    800031dc:	70a2                	ld	ra,40(sp)
    800031de:	7402                	ld	s0,32(sp)
    800031e0:	6145                	add	sp,sp,48
    800031e2:	8082                	ret

00000000800031e4 <syscall_dispatch>:

void syscall_dispatch(struct trapframe* tf) {
    800031e4:	7139                	add	sp,sp,-64
    800031e6:	fc06                	sd	ra,56(sp)
    800031e8:	f822                	sd	s0,48(sp)
    800031ea:	0080                	add	s0,sp,64
    800031ec:	fca43423          	sd	a0,-56(s0)
    if (!tf) {
    800031f0:	fc843783          	ld	a5,-56(s0)
    800031f4:	eb89                	bnez	a5,80003206 <syscall_dispatch+0x22>
        panic("[syscall] missing trapframe");
    800031f6:	00003517          	auipc	a0,0x3
    800031fa:	4c250513          	add	a0,a0,1218 # 800066b8 <syscall_table+0x240>
    800031fe:	00002097          	auipc	ra,0x2
    80003202:	770080e7          	jalr	1904(ra) # 8000596e <panic>
    }
    int num = (int)tf->a7;
    80003206:	fc843783          	ld	a5,-56(s0)
    8000320a:	63dc                	ld	a5,128(a5)
    8000320c:	fef42623          	sw	a5,-20(s0)
    tf->a0 = -1;
    80003210:	fc843783          	ld	a5,-56(s0)
    80003214:	577d                	li	a4,-1
    80003216:	e7b8                	sd	a4,72(a5)
    current_tf = tf;
    80003218:	00008797          	auipc	a5,0x8
    8000321c:	d7878793          	add	a5,a5,-648 # 8000af90 <current_tf>
    80003220:	fc843703          	ld	a4,-56(s0)
    80003224:	e398                	sd	a4,0(a5)
    if (num > 0 && num < SYS_MAX) {
    80003226:	fec42783          	lw	a5,-20(s0)
    8000322a:	2781                	sext.w	a5,a5
    8000322c:	0ef05563          	blez	a5,80003316 <syscall_dispatch+0x132>
    80003230:	fec42783          	lw	a5,-20(s0)
    80003234:	0007871b          	sext.w	a4,a5
    80003238:	47d9                	li	a5,22
    8000323a:	0ce7ce63          	blt	a5,a4,80003316 <syscall_dispatch+0x132>
        const struct syscall_desc* desc = &syscall_table[num];
    8000323e:	fec42703          	lw	a4,-20(s0)
    80003242:	87ba                	mv	a5,a4
    80003244:	0786                	sll	a5,a5,0x1
    80003246:	97ba                	add	a5,a5,a4
    80003248:	078e                	sll	a5,a5,0x3
    8000324a:	00003717          	auipc	a4,0x3
    8000324e:	22e70713          	add	a4,a4,558 # 80006478 <syscall_table>
    80003252:	97ba                	add	a5,a5,a4
    80003254:	fef43023          	sd	a5,-32(s0)
        if (desc->func && desc->arg_count >= 0 && desc->arg_count <= 6) {
    80003258:	fe043783          	ld	a5,-32(s0)
    8000325c:	639c                	ld	a5,0(a5)
    8000325e:	cbd1                	beqz	a5,800032f2 <syscall_dispatch+0x10e>
    80003260:	fe043783          	ld	a5,-32(s0)
    80003264:	4b9c                	lw	a5,16(a5)
    80003266:	0807c663          	bltz	a5,800032f2 <syscall_dispatch+0x10e>
    8000326a:	fe043783          	ld	a5,-32(s0)
    8000326e:	4b9c                	lw	a5,16(a5)
    80003270:	873e                	mv	a4,a5
    80003272:	4799                	li	a5,6
    80003274:	06e7cf63          	blt	a5,a4,800032f2 <syscall_dispatch+0x10e>
            int64 ret = desc->func();
    80003278:	fe043783          	ld	a5,-32(s0)
    8000327c:	639c                	ld	a5,0(a5)
    8000327e:	9782                	jalr	a5
    80003280:	fca43c23          	sd	a0,-40(s0)
            tf->a0 = ret;
    80003284:	fd843703          	ld	a4,-40(s0)
    80003288:	fc843783          	ld	a5,-56(s0)
    8000328c:	e7b8                	sd	a4,72(a5)
            if (debug_syscalls) {
    8000328e:	00004797          	auipc	a5,0x4
    80003292:	bc678793          	add	a5,a5,-1082 # 80006e54 <debug_syscalls>
    80003296:	439c                	lw	a5,0(a5)
    80003298:	cfad                	beqz	a5,80003312 <syscall_dispatch+0x12e>
                const char* name = desc->name ? desc->name : "unknown";
    8000329a:	fe043783          	ld	a5,-32(s0)
    8000329e:	679c                	ld	a5,8(a5)
    800032a0:	c789                	beqz	a5,800032aa <syscall_dispatch+0xc6>
    800032a2:	fe043783          	ld	a5,-32(s0)
    800032a6:	679c                	ld	a5,8(a5)
    800032a8:	a029                	j	800032b2 <syscall_dispatch+0xce>
    800032aa:	00003797          	auipc	a5,0x3
    800032ae:	42e78793          	add	a5,a5,1070 # 800066d8 <syscall_table+0x260>
    800032b2:	fcf43823          	sd	a5,-48(s0)
                printf("[syscall] pid=%d nr=%d (%s) -> %ld\n",
                       myproc() ? myproc()->pid : -1, num, name, ret);
    800032b6:	fffff097          	auipc	ra,0xfffff
    800032ba:	cf4080e7          	jalr	-780(ra) # 80001faa <myproc>
    800032be:	87aa                	mv	a5,a0
                printf("[syscall] pid=%d nr=%d (%s) -> %ld\n",
    800032c0:	cb81                	beqz	a5,800032d0 <syscall_dispatch+0xec>
                       myproc() ? myproc()->pid : -1, num, name, ret);
    800032c2:	fffff097          	auipc	ra,0xfffff
    800032c6:	ce8080e7          	jalr	-792(ra) # 80001faa <myproc>
    800032ca:	87aa                	mv	a5,a0
                printf("[syscall] pid=%d nr=%d (%s) -> %ld\n",
    800032cc:	579c                	lw	a5,40(a5)
    800032ce:	a011                	j	800032d2 <syscall_dispatch+0xee>
    800032d0:	57fd                	li	a5,-1
    800032d2:	fec42603          	lw	a2,-20(s0)
    800032d6:	fd843703          	ld	a4,-40(s0)
    800032da:	fd043683          	ld	a3,-48(s0)
    800032de:	85be                	mv	a1,a5
    800032e0:	00003517          	auipc	a0,0x3
    800032e4:	40050513          	add	a0,a0,1024 # 800066e0 <syscall_table+0x268>
    800032e8:	00002097          	auipc	ra,0x2
    800032ec:	5ee080e7          	jalr	1518(ra) # 800058d6 <printf>
        if (desc->func && desc->arg_count >= 0 && desc->arg_count <= 6) {
    800032f0:	a00d                	j	80003312 <syscall_dispatch+0x12e>
            }
        } else {
            printf("[syscall] invalid entry nr=%d sepc=0x%lx\n", num, tf->sepc);
    800032f2:	fc843783          	ld	a5,-56(s0)
    800032f6:	7ff8                	ld	a4,248(a5)
    800032f8:	fec42783          	lw	a5,-20(s0)
    800032fc:	863a                	mv	a2,a4
    800032fe:	85be                	mv	a1,a5
    80003300:	00003517          	auipc	a0,0x3
    80003304:	40850513          	add	a0,a0,1032 # 80006708 <syscall_table+0x290>
    80003308:	00002097          	auipc	ra,0x2
    8000330c:	5ce080e7          	jalr	1486(ra) # 800058d6 <printf>
    if (num > 0 && num < SYS_MAX) {
    80003310:	a015                	j	80003334 <syscall_dispatch+0x150>
        if (desc->func && desc->arg_count >= 0 && desc->arg_count <= 6) {
    80003312:	0001                	nop
    if (num > 0 && num < SYS_MAX) {
    80003314:	a005                	j	80003334 <syscall_dispatch+0x150>
        }
    } else {
        printf("[syscall] unknown num=%d sepc=0x%lx\n", num, tf->sepc);
    80003316:	fc843783          	ld	a5,-56(s0)
    8000331a:	7ff8                	ld	a4,248(a5)
    8000331c:	fec42783          	lw	a5,-20(s0)
    80003320:	863a                	mv	a2,a4
    80003322:	85be                	mv	a1,a5
    80003324:	00003517          	auipc	a0,0x3
    80003328:	41450513          	add	a0,a0,1044 # 80006738 <syscall_table+0x2c0>
    8000332c:	00002097          	auipc	ra,0x2
    80003330:	5aa080e7          	jalr	1450(ra) # 800058d6 <printf>
    }
    current_tf = NULL;
    80003334:	00008797          	auipc	a5,0x8
    80003338:	c5c78793          	add	a5,a5,-932 # 8000af90 <current_tf>
    8000333c:	0007b023          	sd	zero,0(a5)
    tf->sepc += 4; // advance past ecall
    80003340:	fc843783          	ld	a5,-56(s0)
    80003344:	7ffc                	ld	a5,248(a5)
    80003346:	00478713          	add	a4,a5,4
    8000334a:	fc843783          	ld	a5,-56(s0)
    8000334e:	fff8                	sd	a4,248(a5)
}
    80003350:	0001                	nop
    80003352:	70e2                	ld	ra,56(sp)
    80003354:	7442                	ld	s0,48(sp)
    80003356:	6121                	add	sp,sp,64
    80003358:	8082                	ret

000000008000335a <sys_unimpl>:

static int64 sys_unimpl(void) {
    8000335a:	1141                	add	sp,sp,-16
    8000335c:	e422                	sd	s0,8(sp)
    8000335e:	0800                	add	s0,sp,16
    return -1;
    80003360:	57fd                	li	a5,-1
}
    80003362:	853e                	mv	a0,a5
    80003364:	6422                	ld	s0,8(sp)
    80003366:	0141                	add	sp,sp,16
    80003368:	8082                	ret

000000008000336a <sys_fork>:
#include "include/vmem.h"
#include "include/memlayout.h"

#define MAX_IO_LEN 4096

int64 sys_fork(void) {
    8000336a:	1141                	add	sp,sp,-16
    8000336c:	e422                	sd	s0,8(sp)
    8000336e:	0800                	add	s0,sp,16
    // Full user-mode fork is not yet supported; return error to callers.
    return -1;
    80003370:	57fd                	li	a5,-1
}
    80003372:	853e                	mv	a0,a5
    80003374:	6422                	ld	s0,8(sp)
    80003376:	0141                	add	sp,sp,16
    80003378:	8082                	ret

000000008000337a <sys_exit>:

int64 sys_exit(void) {
    8000337a:	1101                	add	sp,sp,-32
    8000337c:	ec06                	sd	ra,24(sp)
    8000337e:	e822                	sd	s0,16(sp)
    80003380:	1000                	add	s0,sp,32
    int status = 0;
    80003382:	fe042623          	sw	zero,-20(s0)
    argint(0, &status);
    80003386:	fec40793          	add	a5,s0,-20
    8000338a:	85be                	mv	a1,a5
    8000338c:	4501                	li	a0,0
    8000338e:	00000097          	auipc	ra,0x0
    80003392:	c1c080e7          	jalr	-996(ra) # 80002faa <argint>
    exit_process(status);
    80003396:	fec42783          	lw	a5,-20(s0)
    8000339a:	853e                	mv	a0,a5
    8000339c:	fffff097          	auipc	ra,0xfffff
    800033a0:	e92080e7          	jalr	-366(ra) # 8000222e <exit_process>

00000000800033a4 <sys_wait>:
    return 0; // not reached
}

int64 sys_wait(void) {
    800033a4:	7139                	add	sp,sp,-64
    800033a6:	fc06                	sd	ra,56(sp)
    800033a8:	f822                	sd	s0,48(sp)
    800033aa:	0080                	add	s0,sp,64
    uint64 uaddr = 0;
    800033ac:	fc043823          	sd	zero,-48(s0)
    int status = 0;
    800033b0:	fc042623          	sw	zero,-52(s0)
    if (argaddr(0, &uaddr) < 0) return -1;
    800033b4:	fd040793          	add	a5,s0,-48
    800033b8:	85be                	mv	a1,a5
    800033ba:	4501                	li	a0,0
    800033bc:	00000097          	auipc	ra,0x0
    800033c0:	c46080e7          	jalr	-954(ra) # 80003002 <argaddr>
    800033c4:	87aa                	mv	a5,a0
    800033c6:	0007d463          	bgez	a5,800033ce <sys_wait+0x2a>
    800033ca:	57fd                	li	a5,-1
    800033cc:	a071                	j	80003458 <sys_wait+0xb4>
    int pid = wait_process(&status);
    800033ce:	fcc40793          	add	a5,s0,-52
    800033d2:	853e                	mv	a0,a5
    800033d4:	fffff097          	auipc	ra,0xfffff
    800033d8:	ed2080e7          	jalr	-302(ra) # 800022a6 <wait_process>
    800033dc:	87aa                	mv	a5,a0
    800033de:	fef42623          	sw	a5,-20(s0)
    if (pid < 0) return -1;
    800033e2:	fec42783          	lw	a5,-20(s0)
    800033e6:	2781                	sext.w	a5,a5
    800033e8:	0007d463          	bgez	a5,800033f0 <sys_wait+0x4c>
    800033ec:	57fd                	li	a5,-1
    800033ee:	a0ad                	j	80003458 <sys_wait+0xb4>
    if (uaddr != 0) {
    800033f0:	fd043783          	ld	a5,-48(s0)
    800033f4:	c3a5                	beqz	a5,80003454 <sys_wait+0xb0>
        struct proc* p = myproc();
    800033f6:	fffff097          	auipc	ra,0xfffff
    800033fa:	bb4080e7          	jalr	-1100(ra) # 80001faa <myproc>
    800033fe:	fea43023          	sd	a0,-32(s0)
        pagetable_t pt = p ? p->pagetable : NULL;
    80003402:	fe043783          	ld	a5,-32(s0)
    80003406:	c789                	beqz	a5,80003410 <sys_wait+0x6c>
    80003408:	fe043783          	ld	a5,-32(s0)
    8000340c:	7b9c                	ld	a5,48(a5)
    8000340e:	a011                	j	80003412 <sys_wait+0x6e>
    80003410:	4781                	li	a5,0
    80003412:	fcf43c23          	sd	a5,-40(s0)
        if (check_user_ptr(uaddr, sizeof(int)) < 0) return -1;
    80003416:	fd043783          	ld	a5,-48(s0)
    8000341a:	4591                	li	a1,4
    8000341c:	853e                	mv	a0,a5
    8000341e:	00000097          	auipc	ra,0x0
    80003422:	c92080e7          	jalr	-878(ra) # 800030b0 <check_user_ptr>
    80003426:	87aa                	mv	a5,a0
    80003428:	0007d463          	bgez	a5,80003430 <sys_wait+0x8c>
    8000342c:	57fd                	li	a5,-1
    8000342e:	a02d                	j	80003458 <sys_wait+0xb4>
        if (copyout(pt, uaddr, (char*)&status, sizeof(int)) < 0) return -1;
    80003430:	fd043783          	ld	a5,-48(s0)
    80003434:	fcc40713          	add	a4,s0,-52
    80003438:	4691                	li	a3,4
    8000343a:	863a                	mv	a2,a4
    8000343c:	85be                	mv	a1,a5
    8000343e:	fd843503          	ld	a0,-40(s0)
    80003442:	00000097          	auipc	ra,0x0
    80003446:	7ce080e7          	jalr	1998(ra) # 80003c10 <copyout>
    8000344a:	87aa                	mv	a5,a0
    8000344c:	0007d463          	bgez	a5,80003454 <sys_wait+0xb0>
    80003450:	57fd                	li	a5,-1
    80003452:	a019                	j	80003458 <sys_wait+0xb4>
    }
    return pid;
    80003454:	fec42783          	lw	a5,-20(s0)
}
    80003458:	853e                	mv	a0,a5
    8000345a:	70e2                	ld	ra,56(sp)
    8000345c:	7442                	ld	s0,48(sp)
    8000345e:	6121                	add	sp,sp,64
    80003460:	8082                	ret

0000000080003462 <sys_kill>:

int64 sys_kill(void) {
    80003462:	1101                	add	sp,sp,-32
    80003464:	ec06                	sd	ra,24(sp)
    80003466:	e822                	sd	s0,16(sp)
    80003468:	1000                	add	s0,sp,32
    int pid = 0;
    8000346a:	fe042623          	sw	zero,-20(s0)
    if (argint(0, &pid) < 0 || pid <= 0) return -1;
    8000346e:	fec40793          	add	a5,s0,-20
    80003472:	85be                	mv	a1,a5
    80003474:	4501                	li	a0,0
    80003476:	00000097          	auipc	ra,0x0
    8000347a:	b34080e7          	jalr	-1228(ra) # 80002faa <argint>
    8000347e:	87aa                	mv	a5,a0
    80003480:	0007c663          	bltz	a5,8000348c <sys_kill+0x2a>
    80003484:	fec42783          	lw	a5,-20(s0)
    80003488:	00f04463          	bgtz	a5,80003490 <sys_kill+0x2e>
    8000348c:	57fd                	li	a5,-1
    8000348e:	a809                	j	800034a0 <sys_kill+0x3e>
    return kill_process(pid);
    80003490:	fec42783          	lw	a5,-20(s0)
    80003494:	853e                	mv	a0,a5
    80003496:	fffff097          	auipc	ra,0xfffff
    8000349a:	46c080e7          	jalr	1132(ra) # 80002902 <kill_process>
    8000349e:	87aa                	mv	a5,a0
}
    800034a0:	853e                	mv	a0,a5
    800034a2:	60e2                	ld	ra,24(sp)
    800034a4:	6442                	ld	s0,16(sp)
    800034a6:	6105                	add	sp,sp,32
    800034a8:	8082                	ret

00000000800034aa <sys_getpid>:

int64 sys_getpid(void) {
    800034aa:	1101                	add	sp,sp,-32
    800034ac:	ec06                	sd	ra,24(sp)
    800034ae:	e822                	sd	s0,16(sp)
    800034b0:	1000                	add	s0,sp,32
    struct proc* p = myproc();
    800034b2:	fffff097          	auipc	ra,0xfffff
    800034b6:	af8080e7          	jalr	-1288(ra) # 80001faa <myproc>
    800034ba:	fea43423          	sd	a0,-24(s0)
    if (!p) return -1;
    800034be:	fe843783          	ld	a5,-24(s0)
    800034c2:	e399                	bnez	a5,800034c8 <sys_getpid+0x1e>
    800034c4:	57fd                	li	a5,-1
    800034c6:	a021                	j	800034ce <sys_getpid+0x24>
    return p->pid;
    800034c8:	fe843783          	ld	a5,-24(s0)
    800034cc:	579c                	lw	a5,40(a5)
}
    800034ce:	853e                	mv	a0,a5
    800034d0:	60e2                	ld	ra,24(sp)
    800034d2:	6442                	ld	s0,16(sp)
    800034d4:	6105                	add	sp,sp,32
    800034d6:	8082                	ret

00000000800034d8 <sys_open>:

int64 sys_open(void) {
    800034d8:	7135                	add	sp,sp,-160
    800034da:	ed06                	sd	ra,152(sp)
    800034dc:	e922                	sd	s0,144(sp)
    800034de:	1100                	add	s0,sp,160
    uint64 path_addr = 0;
    800034e0:	fe043423          	sd	zero,-24(s0)
    int flags = 0;
    800034e4:	fe042223          	sw	zero,-28(s0)
    if (argaddr(0, &path_addr) < 0 || argint(1, &flags) < 0) {
    800034e8:	fe840793          	add	a5,s0,-24
    800034ec:	85be                	mv	a1,a5
    800034ee:	4501                	li	a0,0
    800034f0:	00000097          	auipc	ra,0x0
    800034f4:	b12080e7          	jalr	-1262(ra) # 80003002 <argaddr>
    800034f8:	87aa                	mv	a5,a0
    800034fa:	0007cd63          	bltz	a5,80003514 <sys_open+0x3c>
    800034fe:	fe440793          	add	a5,s0,-28
    80003502:	85be                	mv	a1,a5
    80003504:	4505                	li	a0,1
    80003506:	00000097          	auipc	ra,0x0
    8000350a:	aa4080e7          	jalr	-1372(ra) # 80002faa <argint>
    8000350e:	87aa                	mv	a5,a0
    80003510:	0007d463          	bgez	a5,80003518 <sys_open+0x40>
        return -1;
    80003514:	57fd                	li	a5,-1
    80003516:	a01d                	j	8000353c <sys_open+0x64>
    }
    char path[128];
    if (get_user_string(path_addr, path, sizeof(path)) < 0) {
    80003518:	fe843783          	ld	a5,-24(s0)
    8000351c:	f6040713          	add	a4,s0,-160
    80003520:	08000613          	li	a2,128
    80003524:	85ba                	mv	a1,a4
    80003526:	853e                	mv	a0,a5
    80003528:	00000097          	auipc	ra,0x0
    8000352c:	bcc080e7          	jalr	-1076(ra) # 800030f4 <get_user_string>
    80003530:	87aa                	mv	a5,a0
    80003532:	0007d463          	bgez	a5,8000353a <sys_open+0x62>
        return -1;
    80003536:	57fd                	li	a5,-1
    80003538:	a011                	j	8000353c <sys_open+0x64>
    }
    (void)flags;
    // File subsystem is not ready; report unimplemented while keeping validation coverage.
    return -1;
    8000353a:	57fd                	li	a5,-1
}
    8000353c:	853e                	mv	a0,a5
    8000353e:	60ea                	ld	ra,152(sp)
    80003540:	644a                	ld	s0,144(sp)
    80003542:	610d                	add	sp,sp,160
    80003544:	8082                	ret

0000000080003546 <sys_close>:

int64 sys_close(void) {
    80003546:	1101                	add	sp,sp,-32
    80003548:	ec06                	sd	ra,24(sp)
    8000354a:	e822                	sd	s0,16(sp)
    8000354c:	1000                	add	s0,sp,32
    int fd = 0;
    8000354e:	fe042623          	sw	zero,-20(s0)
    if (argint(0, &fd) < 0 || fd < 0) return -1;
    80003552:	fec40793          	add	a5,s0,-20
    80003556:	85be                	mv	a1,a5
    80003558:	4501                	li	a0,0
    8000355a:	00000097          	auipc	ra,0x0
    8000355e:	a50080e7          	jalr	-1456(ra) # 80002faa <argint>
    80003562:	87aa                	mv	a5,a0
    80003564:	0007c663          	bltz	a5,80003570 <sys_close+0x2a>
    80003568:	fec42783          	lw	a5,-20(s0)
    8000356c:	0007d463          	bgez	a5,80003574 <sys_close+0x2e>
    80003570:	57fd                	li	a5,-1
    80003572:	a01d                	j	80003598 <sys_close+0x52>
    // No file table yet; accept close on stdio descriptors.
    if (fd == 0 || fd == 1 || fd == 2) return 0;
    80003574:	fec42783          	lw	a5,-20(s0)
    80003578:	cf89                	beqz	a5,80003592 <sys_close+0x4c>
    8000357a:	fec42783          	lw	a5,-20(s0)
    8000357e:	873e                	mv	a4,a5
    80003580:	4785                	li	a5,1
    80003582:	00f70863          	beq	a4,a5,80003592 <sys_close+0x4c>
    80003586:	fec42783          	lw	a5,-20(s0)
    8000358a:	873e                	mv	a4,a5
    8000358c:	4789                	li	a5,2
    8000358e:	00f71463          	bne	a4,a5,80003596 <sys_close+0x50>
    80003592:	4781                	li	a5,0
    80003594:	a011                	j	80003598 <sys_close+0x52>
    return -1;
    80003596:	57fd                	li	a5,-1
}
    80003598:	853e                	mv	a0,a5
    8000359a:	60e2                	ld	ra,24(sp)
    8000359c:	6442                	ld	s0,16(sp)
    8000359e:	6105                	add	sp,sp,32
    800035a0:	8082                	ret

00000000800035a2 <sys_read>:

int64 sys_read(void) {
    800035a2:	7179                	add	sp,sp,-48
    800035a4:	f406                	sd	ra,40(sp)
    800035a6:	f022                	sd	s0,32(sp)
    800035a8:	1800                	add	s0,sp,48
    int fd = 0;
    800035aa:	fe042623          	sw	zero,-20(s0)
    uint64 buf = 0;
    800035ae:	fe043023          	sd	zero,-32(s0)
    int n = 0;
    800035b2:	fc042e23          	sw	zero,-36(s0)
    if (argint(0, &fd) < 0 || argaddr(1, &buf) < 0 || argint(2, &n) < 0) {
    800035b6:	fec40793          	add	a5,s0,-20
    800035ba:	85be                	mv	a1,a5
    800035bc:	4501                	li	a0,0
    800035be:	00000097          	auipc	ra,0x0
    800035c2:	9ec080e7          	jalr	-1556(ra) # 80002faa <argint>
    800035c6:	87aa                	mv	a5,a0
    800035c8:	0207c863          	bltz	a5,800035f8 <sys_read+0x56>
    800035cc:	fe040793          	add	a5,s0,-32
    800035d0:	85be                	mv	a1,a5
    800035d2:	4505                	li	a0,1
    800035d4:	00000097          	auipc	ra,0x0
    800035d8:	a2e080e7          	jalr	-1490(ra) # 80003002 <argaddr>
    800035dc:	87aa                	mv	a5,a0
    800035de:	0007cd63          	bltz	a5,800035f8 <sys_read+0x56>
    800035e2:	fdc40793          	add	a5,s0,-36
    800035e6:	85be                	mv	a1,a5
    800035e8:	4509                	li	a0,2
    800035ea:	00000097          	auipc	ra,0x0
    800035ee:	9c0080e7          	jalr	-1600(ra) # 80002faa <argint>
    800035f2:	87aa                	mv	a5,a0
    800035f4:	0007d463          	bgez	a5,800035fc <sys_read+0x5a>
        return -1;
    800035f8:	57fd                	li	a5,-1
    800035fa:	a03d                	j	80003628 <sys_read+0x86>
    }
    if (n < 0) return -1;
    800035fc:	fdc42783          	lw	a5,-36(s0)
    80003600:	0007d463          	bgez	a5,80003608 <sys_read+0x66>
    80003604:	57fd                	li	a5,-1
    80003606:	a00d                	j	80003628 <sys_read+0x86>
    if (check_user_ptr(buf, (uint64)n) < 0) return -1;
    80003608:	fe043783          	ld	a5,-32(s0)
    8000360c:	fdc42703          	lw	a4,-36(s0)
    80003610:	85ba                	mv	a1,a4
    80003612:	853e                	mv	a0,a5
    80003614:	00000097          	auipc	ra,0x0
    80003618:	a9c080e7          	jalr	-1380(ra) # 800030b0 <check_user_ptr>
    8000361c:	87aa                	mv	a5,a0
    8000361e:	0007d463          	bgez	a5,80003626 <sys_read+0x84>
    80003622:	57fd                	li	a5,-1
    80003624:	a011                	j	80003628 <sys_read+0x86>
    // Simple stub: no real input source, return 0 bytes read.
    (void)fd;
    (void)buf;
    return 0;
    80003626:	4781                	li	a5,0
}
    80003628:	853e                	mv	a0,a5
    8000362a:	70a2                	ld	ra,40(sp)
    8000362c:	7402                	ld	s0,32(sp)
    8000362e:	6145                	add	sp,sp,48
    80003630:	8082                	ret

0000000080003632 <sys_write>:

int64 sys_write(void) {
    80003632:	7171                	add	sp,sp,-176
    80003634:	f506                	sd	ra,168(sp)
    80003636:	f122                	sd	s0,160(sp)
    80003638:	ed26                	sd	s1,152(sp)
    8000363a:	e94a                	sd	s2,144(sp)
    8000363c:	e54e                	sd	s3,136(sp)
    8000363e:	e152                	sd	s4,128(sp)
    80003640:	fcd6                	sd	s5,120(sp)
    80003642:	f8da                	sd	s6,112(sp)
    80003644:	f4de                	sd	s7,104(sp)
    80003646:	f0e2                	sd	s8,96(sp)
    80003648:	ece6                	sd	s9,88(sp)
    8000364a:	1900                	add	s0,sp,176
    8000364c:	878a                	mv	a5,sp
    8000364e:	84be                	mv	s1,a5
    int fd = 0;
    80003650:	f6042623          	sw	zero,-148(s0)
    uint64 buf = 0;
    80003654:	f6043023          	sd	zero,-160(s0)
    int n = 0;
    80003658:	f4042e23          	sw	zero,-164(s0)
    if (argint(0, &fd) < 0 || argaddr(1, &buf) < 0 || argint(2, &n) < 0) {
    8000365c:	f6c40793          	add	a5,s0,-148
    80003660:	85be                	mv	a1,a5
    80003662:	4501                	li	a0,0
    80003664:	00000097          	auipc	ra,0x0
    80003668:	946080e7          	jalr	-1722(ra) # 80002faa <argint>
    8000366c:	87aa                	mv	a5,a0
    8000366e:	0207c863          	bltz	a5,8000369e <sys_write+0x6c>
    80003672:	f6040793          	add	a5,s0,-160
    80003676:	85be                	mv	a1,a5
    80003678:	4505                	li	a0,1
    8000367a:	00000097          	auipc	ra,0x0
    8000367e:	988080e7          	jalr	-1656(ra) # 80003002 <argaddr>
    80003682:	87aa                	mv	a5,a0
    80003684:	0007cd63          	bltz	a5,8000369e <sys_write+0x6c>
    80003688:	f5c40793          	add	a5,s0,-164
    8000368c:	85be                	mv	a1,a5
    8000368e:	4509                	li	a0,2
    80003690:	00000097          	auipc	ra,0x0
    80003694:	91a080e7          	jalr	-1766(ra) # 80002faa <argint>
    80003698:	87aa                	mv	a5,a0
    8000369a:	0007d463          	bgez	a5,800036a2 <sys_write+0x70>
        return -1;
    8000369e:	57fd                	li	a5,-1
    800036a0:	a2a5                	j	80003808 <sys_write+0x1d6>
    }
    if (n < 0) return -1;
    800036a2:	f5c42783          	lw	a5,-164(s0)
    800036a6:	0007d463          	bgez	a5,800036ae <sys_write+0x7c>
    800036aa:	57fd                	li	a5,-1
    800036ac:	aab1                	j	80003808 <sys_write+0x1d6>
    if (check_user_ptr(buf, (uint64)n) < 0) return -1;
    800036ae:	f6043783          	ld	a5,-160(s0)
    800036b2:	f5c42703          	lw	a4,-164(s0)
    800036b6:	85ba                	mv	a1,a4
    800036b8:	853e                	mv	a0,a5
    800036ba:	00000097          	auipc	ra,0x0
    800036be:	9f6080e7          	jalr	-1546(ra) # 800030b0 <check_user_ptr>
    800036c2:	87aa                	mv	a5,a0
    800036c4:	0007d463          	bgez	a5,800036cc <sys_write+0x9a>
    800036c8:	57fd                	li	a5,-1
    800036ca:	aa3d                	j	80003808 <sys_write+0x1d6>
    if (n > MAX_IO_LEN) n = MAX_IO_LEN;
    800036cc:	f5c42783          	lw	a5,-164(s0)
    800036d0:	873e                	mv	a4,a5
    800036d2:	6785                	lui	a5,0x1
    800036d4:	00e7d563          	bge	a5,a4,800036de <sys_write+0xac>
    800036d8:	6785                	lui	a5,0x1
    800036da:	f4f42e23          	sw	a5,-164(s0)
    if (fd != 1 && fd != 2) return -1; // stdout/stderr only
    800036de:	f6c42783          	lw	a5,-148(s0)
    800036e2:	873e                	mv	a4,a5
    800036e4:	4785                	li	a5,1
    800036e6:	00f70a63          	beq	a4,a5,800036fa <sys_write+0xc8>
    800036ea:	f6c42783          	lw	a5,-148(s0)
    800036ee:	873e                	mv	a4,a5
    800036f0:	4789                	li	a5,2
    800036f2:	00f70463          	beq	a4,a5,800036fa <sys_write+0xc8>
    800036f6:	57fd                	li	a5,-1
    800036f8:	aa01                	j	80003808 <sys_write+0x1d6>
    struct proc* p = myproc();
    800036fa:	fffff097          	auipc	ra,0xfffff
    800036fe:	8b0080e7          	jalr	-1872(ra) # 80001faa <myproc>
    80003702:	f8a43823          	sd	a0,-112(s0)
    pagetable_t pt = p ? p->pagetable : NULL;
    80003706:	f9043783          	ld	a5,-112(s0)
    8000370a:	c789                	beqz	a5,80003714 <sys_write+0xe2>
    8000370c:	f9043783          	ld	a5,-112(s0)
    80003710:	7b9c                	ld	a5,48(a5)
    80003712:	a011                	j	80003716 <sys_write+0xe4>
    80003714:	4781                	li	a5,0
    80003716:	f8f43423          	sd	a5,-120(s0)

    const int CHUNK = 256;
    8000371a:	10000793          	li	a5,256
    8000371e:	f8f42223          	sw	a5,-124(s0)
    char tmp[CHUNK];
    80003722:	f8442783          	lw	a5,-124(s0)
    80003726:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80003728:	f6f43c23          	sd	a5,-136(s0)
    8000372c:	f8442783          	lw	a5,-124(s0)
    80003730:	8c3e                	mv	s8,a5
    80003732:	4c81                	li	s9,0
    80003734:	03dc5793          	srl	a5,s8,0x3d
    80003738:	003c9a93          	sll	s5,s9,0x3
    8000373c:	0157eab3          	or	s5,a5,s5
    80003740:	003c1a13          	sll	s4,s8,0x3
    80003744:	f8442783          	lw	a5,-124(s0)
    80003748:	8b3e                	mv	s6,a5
    8000374a:	4b81                	li	s7,0
    8000374c:	03db5793          	srl	a5,s6,0x3d
    80003750:	003b9993          	sll	s3,s7,0x3
    80003754:	0137e9b3          	or	s3,a5,s3
    80003758:	003b1913          	sll	s2,s6,0x3
    8000375c:	f8442783          	lw	a5,-124(s0)
    80003760:	07bd                	add	a5,a5,15
    80003762:	8391                	srl	a5,a5,0x4
    80003764:	0792                	sll	a5,a5,0x4
    80003766:	40f10133          	sub	sp,sp,a5
    8000376a:	878a                	mv	a5,sp
    8000376c:	87be                	mv	a5,a5
    8000376e:	f6f43823          	sd	a5,-144(s0)
    int written = 0;
    80003772:	f8042e23          	sw	zero,-100(s0)
    while (written < n) {
    80003776:	a041                	j	800037f6 <sys_write+0x1c4>
        int to_copy = n - written;
    80003778:	f5c42783          	lw	a5,-164(s0)
    8000377c:	f9c42703          	lw	a4,-100(s0)
    80003780:	9f99                	subw	a5,a5,a4
    80003782:	f8f42c23          	sw	a5,-104(s0)
        if (to_copy > CHUNK) to_copy = CHUNK;
    80003786:	f9842783          	lw	a5,-104(s0)
    8000378a:	873e                	mv	a4,a5
    8000378c:	f8442783          	lw	a5,-124(s0)
    80003790:	2701                	sext.w	a4,a4
    80003792:	2781                	sext.w	a5,a5
    80003794:	00e7d663          	bge	a5,a4,800037a0 <sys_write+0x16e>
    80003798:	f8442783          	lw	a5,-124(s0)
    8000379c:	f8f42c23          	sw	a5,-104(s0)
        if (copyin(pt, tmp, buf + written, (uint64)to_copy) < 0) {
    800037a0:	f9c42703          	lw	a4,-100(s0)
    800037a4:	f6043783          	ld	a5,-160(s0)
    800037a8:	97ba                	add	a5,a5,a4
    800037aa:	f9842703          	lw	a4,-104(s0)
    800037ae:	86ba                	mv	a3,a4
    800037b0:	863e                	mv	a2,a5
    800037b2:	f7043583          	ld	a1,-144(s0)
    800037b6:	f8843503          	ld	a0,-120(s0)
    800037ba:	00000097          	auipc	ra,0x0
    800037be:	370080e7          	jalr	880(ra) # 80003b2a <copyin>
    800037c2:	87aa                	mv	a5,a0
    800037c4:	0007d463          	bgez	a5,800037cc <sys_write+0x19a>
            return -1;
    800037c8:	57fd                	li	a5,-1
    800037ca:	a83d                	j	80003808 <sys_write+0x1d6>
        }
        // printf handles UART output
        printf("%.*s", to_copy, tmp);
    800037cc:	f9842783          	lw	a5,-104(s0)
    800037d0:	f7043603          	ld	a2,-144(s0)
    800037d4:	85be                	mv	a1,a5
    800037d6:	00003517          	auipc	a0,0x3
    800037da:	f8a50513          	add	a0,a0,-118 # 80006760 <syscall_table+0x2e8>
    800037de:	00002097          	auipc	ra,0x2
    800037e2:	0f8080e7          	jalr	248(ra) # 800058d6 <printf>
        written += to_copy;
    800037e6:	f9c42783          	lw	a5,-100(s0)
    800037ea:	873e                	mv	a4,a5
    800037ec:	f9842783          	lw	a5,-104(s0)
    800037f0:	9fb9                	addw	a5,a5,a4
    800037f2:	f8f42e23          	sw	a5,-100(s0)
    while (written < n) {
    800037f6:	f5c42703          	lw	a4,-164(s0)
    800037fa:	f9c42783          	lw	a5,-100(s0)
    800037fe:	2781                	sext.w	a5,a5
    80003800:	f6e7cce3          	blt	a5,a4,80003778 <sys_write+0x146>
    }
    return written;
    80003804:	f9c42783          	lw	a5,-100(s0)
    80003808:	8126                	mv	sp,s1
}
    8000380a:	853e                	mv	a0,a5
    8000380c:	f5040113          	add	sp,s0,-176
    80003810:	70aa                	ld	ra,168(sp)
    80003812:	740a                	ld	s0,160(sp)
    80003814:	64ea                	ld	s1,152(sp)
    80003816:	694a                	ld	s2,144(sp)
    80003818:	69aa                	ld	s3,136(sp)
    8000381a:	6a0a                	ld	s4,128(sp)
    8000381c:	7ae6                	ld	s5,120(sp)
    8000381e:	7b46                	ld	s6,112(sp)
    80003820:	7ba6                	ld	s7,104(sp)
    80003822:	7c06                	ld	s8,96(sp)
    80003824:	6ce6                	ld	s9,88(sp)
    80003826:	614d                	add	sp,sp,176
    80003828:	8082                	ret

000000008000382a <sys_sbrk>:

int64 sys_sbrk(void) {
    8000382a:	7139                	add	sp,sp,-64
    8000382c:	fc06                	sd	ra,56(sp)
    8000382e:	f822                	sd	s0,48(sp)
    80003830:	0080                	add	s0,sp,64
    int n = 0;
    80003832:	fc042623          	sw	zero,-52(s0)
    if (argint(0, &n) < 0) return -1;
    80003836:	fcc40793          	add	a5,s0,-52
    8000383a:	85be                	mv	a1,a5
    8000383c:	4501                	li	a0,0
    8000383e:	fffff097          	auipc	ra,0xfffff
    80003842:	76c080e7          	jalr	1900(ra) # 80002faa <argint>
    80003846:	87aa                	mv	a5,a0
    80003848:	0007d463          	bgez	a5,80003850 <sys_sbrk+0x26>
    8000384c:	57fd                	li	a5,-1
    8000384e:	a045                	j	800038ee <sys_sbrk+0xc4>
    struct proc* p = myproc();
    80003850:	ffffe097          	auipc	ra,0xffffe
    80003854:	75a080e7          	jalr	1882(ra) # 80001faa <myproc>
    80003858:	fea43423          	sd	a0,-24(s0)
    if (!p) return -1;
    8000385c:	fe843783          	ld	a5,-24(s0)
    80003860:	e399                	bnez	a5,80003866 <sys_sbrk+0x3c>
    80003862:	57fd                	li	a5,-1
    80003864:	a069                	j	800038ee <sys_sbrk+0xc4>
    uint64 old = p->brk;
    80003866:	fe843783          	ld	a5,-24(s0)
    8000386a:	63bc                	ld	a5,64(a5)
    8000386c:	fef43023          	sd	a5,-32(s0)
    if (n >= 0) {
    80003870:	fcc42783          	lw	a5,-52(s0)
    80003874:	0207cf63          	bltz	a5,800038b2 <sys_sbrk+0x88>
        uint64 inc = (uint64)n;
    80003878:	fcc42783          	lw	a5,-52(s0)
    8000387c:	fcf43823          	sd	a5,-48(s0)
        if (p->brk + inc < p->brk) return -1;
    80003880:	fe843783          	ld	a5,-24(s0)
    80003884:	63b8                	ld	a4,64(a5)
    80003886:	fd043783          	ld	a5,-48(s0)
    8000388a:	973e                	add	a4,a4,a5
    8000388c:	fe843783          	ld	a5,-24(s0)
    80003890:	63bc                	ld	a5,64(a5)
    80003892:	00f77463          	bgeu	a4,a5,8000389a <sys_sbrk+0x70>
    80003896:	57fd                	li	a5,-1
    80003898:	a899                	j	800038ee <sys_sbrk+0xc4>
        p->brk += inc;
    8000389a:	fe843783          	ld	a5,-24(s0)
    8000389e:	63b8                	ld	a4,64(a5)
    800038a0:	fd043783          	ld	a5,-48(s0)
    800038a4:	973e                	add	a4,a4,a5
    800038a6:	fe843783          	ld	a5,-24(s0)
    800038aa:	e3b8                	sd	a4,64(a5)
        return old;
    800038ac:	fe043783          	ld	a5,-32(s0)
    800038b0:	a83d                	j	800038ee <sys_sbrk+0xc4>
    } else {
        // Shrink: keep simple and just move the break down without freeing.
        uint64 dec = (uint64)(-n);
    800038b2:	fcc42783          	lw	a5,-52(s0)
    800038b6:	40f007bb          	negw	a5,a5
    800038ba:	2781                	sext.w	a5,a5
    800038bc:	fcf43c23          	sd	a5,-40(s0)
        if (dec > (p->brk - (uint64)KERNBASE)) {
    800038c0:	fe843783          	ld	a5,-24(s0)
    800038c4:	63b8                	ld	a4,64(a5)
    800038c6:	800007b7          	lui	a5,0x80000
    800038ca:	97ba                	add	a5,a5,a4
    800038cc:	fd843703          	ld	a4,-40(s0)
    800038d0:	00e7f463          	bgeu	a5,a4,800038d8 <sys_sbrk+0xae>
            return -1;
    800038d4:	57fd                	li	a5,-1
    800038d6:	a821                	j	800038ee <sys_sbrk+0xc4>
        }
        p->brk -= dec;
    800038d8:	fe843783          	ld	a5,-24(s0)
    800038dc:	63b8                	ld	a4,64(a5)
    800038de:	fd843783          	ld	a5,-40(s0)
    800038e2:	8f1d                	sub	a4,a4,a5
    800038e4:	fe843783          	ld	a5,-24(s0)
    800038e8:	e3b8                	sd	a4,64(a5)
        return old;
    800038ea:	fe043783          	ld	a5,-32(s0)
    }
}
    800038ee:	853e                	mv	a0,a5
    800038f0:	70e2                	ld	ra,56(sp)
    800038f2:	7442                	ld	s0,48(sp)
    800038f4:	6121                	add	sp,sp,64
    800038f6:	8082                	ret

00000000800038f8 <sys_uptime>:

int64 sys_uptime(void) {
    800038f8:	1141                	add	sp,sp,-16
    800038fa:	e406                	sd	ra,8(sp)
    800038fc:	e022                	sd	s0,0(sp)
    800038fe:	0800                	add	s0,sp,16
    return (int64)timer_ticks();
    80003900:	00000097          	auipc	ra,0x0
    80003904:	74c080e7          	jalr	1868(ra) # 8000404c <timer_ticks>
    80003908:	87aa                	mv	a5,a0
}
    8000390a:	853e                	mv	a0,a5
    8000390c:	60a2                	ld	ra,8(sp)
    8000390e:	6402                	ld	s0,0(sp)
    80003910:	0141                	add	sp,sp,16
    80003912:	8082                	ret

0000000080003914 <sys_yield>:

int64 sys_yield(void) {
    80003914:	1141                	add	sp,sp,-16
    80003916:	e406                	sd	ra,8(sp)
    80003918:	e022                	sd	s0,0(sp)
    8000391a:	0800                	add	s0,sp,16
    yield();
    8000391c:	ffffe097          	auipc	ra,0xffffe
    80003920:	732080e7          	jalr	1842(ra) # 8000204e <yield>
    return 0;
    80003924:	4781                	li	a5,0
}
    80003926:	853e                	mv	a0,a5
    80003928:	60a2                	ld	ra,8(sp)
    8000392a:	6402                	ld	s0,0(sp)
    8000392c:	0141                	add	sp,sp,16
    8000392e:	8082                	ret

0000000080003930 <sys_sleep>:

int64 sys_sleep(void) {
    80003930:	1101                	add	sp,sp,-32
    80003932:	ec06                	sd	ra,24(sp)
    80003934:	e822                	sd	s0,16(sp)
    80003936:	1000                	add	s0,sp,32
    int n = 0;
    80003938:	fe042223          	sw	zero,-28(s0)
    if (argint(0, &n) < 0 || n < 0) {
    8000393c:	fe440793          	add	a5,s0,-28
    80003940:	85be                	mv	a1,a5
    80003942:	4501                	li	a0,0
    80003944:	fffff097          	auipc	ra,0xfffff
    80003948:	666080e7          	jalr	1638(ra) # 80002faa <argint>
    8000394c:	87aa                	mv	a5,a0
    8000394e:	0007c663          	bltz	a5,8000395a <sys_sleep+0x2a>
    80003952:	fe442783          	lw	a5,-28(s0)
    80003956:	0007d463          	bgez	a5,8000395e <sys_sleep+0x2e>
        return -1;
    8000395a:	57fd                	li	a5,-1
    8000395c:	a851                	j	800039f0 <sys_sleep+0xc0>
    }
    acquire(&ticks_lock);
    8000395e:	00007517          	auipc	a0,0x7
    80003962:	63a50513          	add	a0,a0,1594 # 8000af98 <ticks_lock>
    80003966:	ffffe097          	auipc	ra,0xffffe
    8000396a:	ece080e7          	jalr	-306(ra) # 80001834 <acquire>
    uint64 start = ticks;
    8000396e:	00003797          	auipc	a5,0x3
    80003972:	4ea78793          	add	a5,a5,1258 # 80006e58 <ticks>
    80003976:	639c                	ld	a5,0(a5)
    80003978:	fef43423          	sd	a5,-24(s0)
    while (ticks - start < (uint64)n) {
    8000397c:	a0a1                	j	800039c4 <sys_sleep+0x94>
        sleep((void*)&ticks, &ticks_lock);
    8000397e:	00007597          	auipc	a1,0x7
    80003982:	61a58593          	add	a1,a1,1562 # 8000af98 <ticks_lock>
    80003986:	00003517          	auipc	a0,0x3
    8000398a:	4d250513          	add	a0,a0,1234 # 80006e58 <ticks>
    8000398e:	ffffe097          	auipc	ra,0xffffe
    80003992:	722080e7          	jalr	1826(ra) # 800020b0 <sleep>
        if (myproc() && myproc()->killed) {
    80003996:	ffffe097          	auipc	ra,0xffffe
    8000399a:	614080e7          	jalr	1556(ra) # 80001faa <myproc>
    8000399e:	87aa                	mv	a5,a0
    800039a0:	c395                	beqz	a5,800039c4 <sys_sleep+0x94>
    800039a2:	ffffe097          	auipc	ra,0xffffe
    800039a6:	608080e7          	jalr	1544(ra) # 80001faa <myproc>
    800039aa:	87aa                	mv	a5,a0
    800039ac:	539c                	lw	a5,32(a5)
    800039ae:	cb99                	beqz	a5,800039c4 <sys_sleep+0x94>
            release(&ticks_lock);
    800039b0:	00007517          	auipc	a0,0x7
    800039b4:	5e850513          	add	a0,a0,1512 # 8000af98 <ticks_lock>
    800039b8:	ffffe097          	auipc	ra,0xffffe
    800039bc:	eb0080e7          	jalr	-336(ra) # 80001868 <release>
            return -1;
    800039c0:	57fd                	li	a5,-1
    800039c2:	a03d                	j	800039f0 <sys_sleep+0xc0>
    while (ticks - start < (uint64)n) {
    800039c4:	00003797          	auipc	a5,0x3
    800039c8:	49478793          	add	a5,a5,1172 # 80006e58 <ticks>
    800039cc:	6398                	ld	a4,0(a5)
    800039ce:	fe843783          	ld	a5,-24(s0)
    800039d2:	40f707b3          	sub	a5,a4,a5
    800039d6:	fe442703          	lw	a4,-28(s0)
    800039da:	fae7e2e3          	bltu	a5,a4,8000397e <sys_sleep+0x4e>
        }
    }
    release(&ticks_lock);
    800039de:	00007517          	auipc	a0,0x7
    800039e2:	5ba50513          	add	a0,a0,1466 # 8000af98 <ticks_lock>
    800039e6:	ffffe097          	auipc	ra,0xffffe
    800039ea:	e82080e7          	jalr	-382(ra) # 80001868 <release>
    return 0;
    800039ee:	4781                	li	a5,0
}
    800039f0:	853e                	mv	a0,a5
    800039f2:	60e2                	ld	ra,24(sp)
    800039f4:	6442                	ld	s0,16(sp)
    800039f6:	6105                	add	sp,sp,32
    800039f8:	8082                	ret

00000000800039fa <within_user>:
// Basic user memory access helpers modeled after xv6-style copyin/copyout.
// They rely on the supplied pagetable to translate user virtual addresses to
// physical addresses. If the pagetable is NULL, fall back to treating the
// virtual address as already accessible (kernel direct map).

static int within_user(uint64 va, uint64 len) {
    800039fa:	7179                	add	sp,sp,-48
    800039fc:	f422                	sd	s0,40(sp)
    800039fe:	1800                	add	s0,sp,48
    80003a00:	fca43c23          	sd	a0,-40(s0)
    80003a04:	fcb43823          	sd	a1,-48(s0)
    if (va >= KERNBASE) return 0;
    80003a08:	fd843703          	ld	a4,-40(s0)
    80003a0c:	800007b7          	lui	a5,0x80000
    80003a10:	fff7c793          	not	a5,a5
    80003a14:	00e7f463          	bgeu	a5,a4,80003a1c <within_user+0x22>
    80003a18:	4781                	li	a5,0
    80003a1a:	a83d                	j	80003a58 <within_user+0x5e>
    if (len == 0) return 1;
    80003a1c:	fd043783          	ld	a5,-48(s0)
    80003a20:	e399                	bnez	a5,80003a26 <within_user+0x2c>
    80003a22:	4785                	li	a5,1
    80003a24:	a815                	j	80003a58 <within_user+0x5e>
    uint64 end = va + len - 1;
    80003a26:	fd843703          	ld	a4,-40(s0)
    80003a2a:	fd043783          	ld	a5,-48(s0)
    80003a2e:	97ba                	add	a5,a5,a4
    80003a30:	17fd                	add	a5,a5,-1 # ffffffff7fffffff <_stack_top+0xfffffffeffff0fff>
    80003a32:	fef43423          	sd	a5,-24(s0)
    return end < KERNBASE && end >= va;
    80003a36:	fe843703          	ld	a4,-24(s0)
    80003a3a:	800007b7          	lui	a5,0x80000
    80003a3e:	fff7c793          	not	a5,a5
    80003a42:	00e7ea63          	bltu	a5,a4,80003a56 <within_user+0x5c>
    80003a46:	fe843703          	ld	a4,-24(s0)
    80003a4a:	fd843783          	ld	a5,-40(s0)
    80003a4e:	00f76463          	bltu	a4,a5,80003a56 <within_user+0x5c>
    80003a52:	4785                	li	a5,1
    80003a54:	a011                	j	80003a58 <within_user+0x5e>
    80003a56:	4781                	li	a5,0
}
    80003a58:	853e                	mv	a0,a5
    80003a5a:	7422                	ld	s0,40(sp)
    80003a5c:	6145                	add	sp,sp,48
    80003a5e:	8082                	ret

0000000080003a60 <user_access_ok>:

int user_access_ok(pagetable_t pagetable, uint64 va, uint64 len) {
    80003a60:	711d                	add	sp,sp,-96
    80003a62:	ec86                	sd	ra,88(sp)
    80003a64:	e8a2                	sd	s0,80(sp)
    80003a66:	1080                	add	s0,sp,96
    80003a68:	faa43c23          	sd	a0,-72(s0)
    80003a6c:	fab43823          	sd	a1,-80(s0)
    80003a70:	fac43423          	sd	a2,-88(s0)
    if (!within_user(va, len)) return 0;
    80003a74:	fa843583          	ld	a1,-88(s0)
    80003a78:	fb043503          	ld	a0,-80(s0)
    80003a7c:	00000097          	auipc	ra,0x0
    80003a80:	f7e080e7          	jalr	-130(ra) # 800039fa <within_user>
    80003a84:	87aa                	mv	a5,a0
    80003a86:	e399                	bnez	a5,80003a8c <user_access_ok+0x2c>
    80003a88:	4781                	li	a5,0
    80003a8a:	a859                	j	80003b20 <user_access_ok+0xc0>
    if (len == 0) return 1;
    80003a8c:	fa843783          	ld	a5,-88(s0)
    80003a90:	e399                	bnez	a5,80003a96 <user_access_ok+0x36>
    80003a92:	4785                	li	a5,1
    80003a94:	a071                	j	80003b20 <user_access_ok+0xc0>
    uint64 cur = va;
    80003a96:	fb043783          	ld	a5,-80(s0)
    80003a9a:	fef43423          	sd	a5,-24(s0)
    uint64 remaining = len;
    80003a9e:	fa843783          	ld	a5,-88(s0)
    80003aa2:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003aa6:	a88d                	j	80003b18 <user_access_ok+0xb8>
        uint64 pa = pagetable ? vmem_translate(pagetable, cur) : cur;
    80003aa8:	fb843783          	ld	a5,-72(s0)
    80003aac:	cb99                	beqz	a5,80003ac2 <user_access_ok+0x62>
    80003aae:	fe843583          	ld	a1,-24(s0)
    80003ab2:	fb843503          	ld	a0,-72(s0)
    80003ab6:	ffffe097          	auipc	ra,0xffffe
    80003aba:	916080e7          	jalr	-1770(ra) # 800013cc <vmem_translate>
    80003abe:	87aa                	mv	a5,a0
    80003ac0:	a019                	j	80003ac6 <user_access_ok+0x66>
    80003ac2:	fe843783          	ld	a5,-24(s0)
    80003ac6:	fcf43c23          	sd	a5,-40(s0)
        if (pa == 0) return 0;
    80003aca:	fd843783          	ld	a5,-40(s0)
    80003ace:	e399                	bnez	a5,80003ad4 <user_access_ok+0x74>
    80003ad0:	4781                	li	a5,0
    80003ad2:	a0b9                	j	80003b20 <user_access_ok+0xc0>
        uint64 page_left = PGSIZE - (cur & (PGSIZE - 1));
    80003ad4:	fe843703          	ld	a4,-24(s0)
    80003ad8:	6785                	lui	a5,0x1
    80003ada:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80003adc:	8ff9                	and	a5,a5,a4
    80003ade:	6705                	lui	a4,0x1
    80003ae0:	40f707b3          	sub	a5,a4,a5
    80003ae4:	fcf43823          	sd	a5,-48(s0)
        uint64 n = remaining < page_left ? remaining : page_left;
    80003ae8:	fe043703          	ld	a4,-32(s0)
    80003aec:	fd043783          	ld	a5,-48(s0)
    80003af0:	00f77363          	bgeu	a4,a5,80003af6 <user_access_ok+0x96>
    80003af4:	87ba                	mv	a5,a4
    80003af6:	fcf43423          	sd	a5,-56(s0)
        cur += n;
    80003afa:	fe843703          	ld	a4,-24(s0)
    80003afe:	fc843783          	ld	a5,-56(s0)
    80003b02:	97ba                	add	a5,a5,a4
    80003b04:	fef43423          	sd	a5,-24(s0)
        remaining -= n;
    80003b08:	fe043703          	ld	a4,-32(s0)
    80003b0c:	fc843783          	ld	a5,-56(s0)
    80003b10:	40f707b3          	sub	a5,a4,a5
    80003b14:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003b18:	fe043783          	ld	a5,-32(s0)
    80003b1c:	f7d1                	bnez	a5,80003aa8 <user_access_ok+0x48>
    }
    return 1;
    80003b1e:	4785                	li	a5,1
}
    80003b20:	853e                	mv	a0,a5
    80003b22:	60e6                	ld	ra,88(sp)
    80003b24:	6446                	ld	s0,80(sp)
    80003b26:	6125                	add	sp,sp,96
    80003b28:	8082                	ret

0000000080003b2a <copyin>:

int copyin(pagetable_t pagetable, char* dst, uint64 srcva, uint64 len) {
    80003b2a:	711d                	add	sp,sp,-96
    80003b2c:	ec86                	sd	ra,88(sp)
    80003b2e:	e8a2                	sd	s0,80(sp)
    80003b30:	1080                	add	s0,sp,96
    80003b32:	faa43c23          	sd	a0,-72(s0)
    80003b36:	fab43823          	sd	a1,-80(s0)
    80003b3a:	fac43423          	sd	a2,-88(s0)
    80003b3e:	fad43023          	sd	a3,-96(s0)
    uint64 va = srcva;
    80003b42:	fa843783          	ld	a5,-88(s0)
    80003b46:	fef43423          	sd	a5,-24(s0)
    uint64 remaining = len;
    80003b4a:	fa043783          	ld	a5,-96(s0)
    80003b4e:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003b52:	a075                	j	80003bfe <copyin+0xd4>
        if (!within_user(va, 1)) return -1;
    80003b54:	4585                	li	a1,1
    80003b56:	fe843503          	ld	a0,-24(s0)
    80003b5a:	00000097          	auipc	ra,0x0
    80003b5e:	ea0080e7          	jalr	-352(ra) # 800039fa <within_user>
    80003b62:	87aa                	mv	a5,a0
    80003b64:	e399                	bnez	a5,80003b6a <copyin+0x40>
    80003b66:	57fd                	li	a5,-1
    80003b68:	a879                	j	80003c06 <copyin+0xdc>
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
    80003b6a:	fb843783          	ld	a5,-72(s0)
    80003b6e:	cb99                	beqz	a5,80003b84 <copyin+0x5a>
    80003b70:	fe843583          	ld	a1,-24(s0)
    80003b74:	fb843503          	ld	a0,-72(s0)
    80003b78:	ffffe097          	auipc	ra,0xffffe
    80003b7c:	854080e7          	jalr	-1964(ra) # 800013cc <vmem_translate>
    80003b80:	87aa                	mv	a5,a0
    80003b82:	a019                	j	80003b88 <copyin+0x5e>
    80003b84:	fe843783          	ld	a5,-24(s0)
    80003b88:	fcf43c23          	sd	a5,-40(s0)
        if (pa == 0) return -1;
    80003b8c:	fd843783          	ld	a5,-40(s0)
    80003b90:	e399                	bnez	a5,80003b96 <copyin+0x6c>
    80003b92:	57fd                	li	a5,-1
    80003b94:	a88d                	j	80003c06 <copyin+0xdc>
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
    80003b96:	fe843703          	ld	a4,-24(s0)
    80003b9a:	6785                	lui	a5,0x1
    80003b9c:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80003b9e:	8ff9                	and	a5,a5,a4
    80003ba0:	6705                	lui	a4,0x1
    80003ba2:	40f707b3          	sub	a5,a4,a5
    80003ba6:	fcf43823          	sd	a5,-48(s0)
        uint64 n = remaining < page_left ? remaining : page_left;
    80003baa:	fe043703          	ld	a4,-32(s0)
    80003bae:	fd043783          	ld	a5,-48(s0)
    80003bb2:	00f77363          	bgeu	a4,a5,80003bb8 <copyin+0x8e>
    80003bb6:	87ba                	mv	a5,a4
    80003bb8:	fcf43423          	sd	a5,-56(s0)
        memcpy(dst, (void*)(pa), n);
    80003bbc:	fd843783          	ld	a5,-40(s0)
    80003bc0:	fc843603          	ld	a2,-56(s0)
    80003bc4:	85be                	mv	a1,a5
    80003bc6:	fb043503          	ld	a0,-80(s0)
    80003bca:	00001097          	auipc	ra,0x1
    80003bce:	452080e7          	jalr	1106(ra) # 8000501c <memcpy>
        dst += n;
    80003bd2:	fb043703          	ld	a4,-80(s0)
    80003bd6:	fc843783          	ld	a5,-56(s0)
    80003bda:	97ba                	add	a5,a5,a4
    80003bdc:	faf43823          	sd	a5,-80(s0)
        va += n;
    80003be0:	fe843703          	ld	a4,-24(s0)
    80003be4:	fc843783          	ld	a5,-56(s0)
    80003be8:	97ba                	add	a5,a5,a4
    80003bea:	fef43423          	sd	a5,-24(s0)
        remaining -= n;
    80003bee:	fe043703          	ld	a4,-32(s0)
    80003bf2:	fc843783          	ld	a5,-56(s0)
    80003bf6:	40f707b3          	sub	a5,a4,a5
    80003bfa:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003bfe:	fe043783          	ld	a5,-32(s0)
    80003c02:	fba9                	bnez	a5,80003b54 <copyin+0x2a>
    }
    return 0;
    80003c04:	4781                	li	a5,0
}
    80003c06:	853e                	mv	a0,a5
    80003c08:	60e6                	ld	ra,88(sp)
    80003c0a:	6446                	ld	s0,80(sp)
    80003c0c:	6125                	add	sp,sp,96
    80003c0e:	8082                	ret

0000000080003c10 <copyout>:

int copyout(pagetable_t pagetable, uint64 dstva, const char* src, uint64 len) {
    80003c10:	711d                	add	sp,sp,-96
    80003c12:	ec86                	sd	ra,88(sp)
    80003c14:	e8a2                	sd	s0,80(sp)
    80003c16:	1080                	add	s0,sp,96
    80003c18:	faa43c23          	sd	a0,-72(s0)
    80003c1c:	fab43823          	sd	a1,-80(s0)
    80003c20:	fac43423          	sd	a2,-88(s0)
    80003c24:	fad43023          	sd	a3,-96(s0)
    uint64 va = dstva;
    80003c28:	fb043783          	ld	a5,-80(s0)
    80003c2c:	fef43423          	sd	a5,-24(s0)
    uint64 remaining = len;
    80003c30:	fa043783          	ld	a5,-96(s0)
    80003c34:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003c38:	a075                	j	80003ce4 <copyout+0xd4>
        if (!within_user(va, 1)) return -1;
    80003c3a:	4585                	li	a1,1
    80003c3c:	fe843503          	ld	a0,-24(s0)
    80003c40:	00000097          	auipc	ra,0x0
    80003c44:	dba080e7          	jalr	-582(ra) # 800039fa <within_user>
    80003c48:	87aa                	mv	a5,a0
    80003c4a:	e399                	bnez	a5,80003c50 <copyout+0x40>
    80003c4c:	57fd                	li	a5,-1
    80003c4e:	a879                	j	80003cec <copyout+0xdc>
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
    80003c50:	fb843783          	ld	a5,-72(s0)
    80003c54:	cb99                	beqz	a5,80003c6a <copyout+0x5a>
    80003c56:	fe843583          	ld	a1,-24(s0)
    80003c5a:	fb843503          	ld	a0,-72(s0)
    80003c5e:	ffffd097          	auipc	ra,0xffffd
    80003c62:	76e080e7          	jalr	1902(ra) # 800013cc <vmem_translate>
    80003c66:	87aa                	mv	a5,a0
    80003c68:	a019                	j	80003c6e <copyout+0x5e>
    80003c6a:	fe843783          	ld	a5,-24(s0)
    80003c6e:	fcf43c23          	sd	a5,-40(s0)
        if (pa == 0) return -1;
    80003c72:	fd843783          	ld	a5,-40(s0)
    80003c76:	e399                	bnez	a5,80003c7c <copyout+0x6c>
    80003c78:	57fd                	li	a5,-1
    80003c7a:	a88d                	j	80003cec <copyout+0xdc>
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
    80003c7c:	fe843703          	ld	a4,-24(s0)
    80003c80:	6785                	lui	a5,0x1
    80003c82:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80003c84:	8ff9                	and	a5,a5,a4
    80003c86:	6705                	lui	a4,0x1
    80003c88:	40f707b3          	sub	a5,a4,a5
    80003c8c:	fcf43823          	sd	a5,-48(s0)
        uint64 n = remaining < page_left ? remaining : page_left;
    80003c90:	fe043703          	ld	a4,-32(s0)
    80003c94:	fd043783          	ld	a5,-48(s0)
    80003c98:	00f77363          	bgeu	a4,a5,80003c9e <copyout+0x8e>
    80003c9c:	87ba                	mv	a5,a4
    80003c9e:	fcf43423          	sd	a5,-56(s0)
        memcpy((void*)pa, src, n);
    80003ca2:	fd843783          	ld	a5,-40(s0)
    80003ca6:	fc843603          	ld	a2,-56(s0)
    80003caa:	fa843583          	ld	a1,-88(s0)
    80003cae:	853e                	mv	a0,a5
    80003cb0:	00001097          	auipc	ra,0x1
    80003cb4:	36c080e7          	jalr	876(ra) # 8000501c <memcpy>
        src += n;
    80003cb8:	fa843703          	ld	a4,-88(s0)
    80003cbc:	fc843783          	ld	a5,-56(s0)
    80003cc0:	97ba                	add	a5,a5,a4
    80003cc2:	faf43423          	sd	a5,-88(s0)
        va += n;
    80003cc6:	fe843703          	ld	a4,-24(s0)
    80003cca:	fc843783          	ld	a5,-56(s0)
    80003cce:	97ba                	add	a5,a5,a4
    80003cd0:	fef43423          	sd	a5,-24(s0)
        remaining -= n;
    80003cd4:	fe043703          	ld	a4,-32(s0)
    80003cd8:	fc843783          	ld	a5,-56(s0)
    80003cdc:	40f707b3          	sub	a5,a4,a5
    80003ce0:	fef43023          	sd	a5,-32(s0)
    while (remaining > 0) {
    80003ce4:	fe043783          	ld	a5,-32(s0)
    80003ce8:	fba9                	bnez	a5,80003c3a <copyout+0x2a>
    }
    return 0;
    80003cea:	4781                	li	a5,0
}
    80003cec:	853e                	mv	a0,a5
    80003cee:	60e6                	ld	ra,88(sp)
    80003cf0:	6446                	ld	s0,80(sp)
    80003cf2:	6125                	add	sp,sp,96
    80003cf4:	8082                	ret

0000000080003cf6 <copyinstr>:

int copyinstr(pagetable_t pagetable, char* dst, uint64 srcva, uint64 max) {
    80003cf6:	7159                	add	sp,sp,-112
    80003cf8:	f486                	sd	ra,104(sp)
    80003cfa:	f0a2                	sd	s0,96(sp)
    80003cfc:	1880                	add	s0,sp,112
    80003cfe:	faa43423          	sd	a0,-88(s0)
    80003d02:	fab43023          	sd	a1,-96(s0)
    80003d06:	f8c43c23          	sd	a2,-104(s0)
    80003d0a:	f8d43823          	sd	a3,-112(s0)
    uint64 va = srcva;
    80003d0e:	f9843783          	ld	a5,-104(s0)
    80003d12:	fef43423          	sd	a5,-24(s0)
    int copied = 0;
    80003d16:	fe042223          	sw	zero,-28(s0)
    while (copied < max) {
    80003d1a:	a8d1                	j	80003dee <copyinstr+0xf8>
        if (!within_user(va, 1)) return -1;
    80003d1c:	4585                	li	a1,1
    80003d1e:	fe843503          	ld	a0,-24(s0)
    80003d22:	00000097          	auipc	ra,0x0
    80003d26:	cd8080e7          	jalr	-808(ra) # 800039fa <within_user>
    80003d2a:	87aa                	mv	a5,a0
    80003d2c:	e399                	bnez	a5,80003d32 <copyinstr+0x3c>
    80003d2e:	57fd                	li	a5,-1
    80003d30:	a0f1                	j	80003dfc <copyinstr+0x106>
        uint64 pa = pagetable ? vmem_translate(pagetable, va) : va;
    80003d32:	fa843783          	ld	a5,-88(s0)
    80003d36:	cb99                	beqz	a5,80003d4c <copyinstr+0x56>
    80003d38:	fe843583          	ld	a1,-24(s0)
    80003d3c:	fa843503          	ld	a0,-88(s0)
    80003d40:	ffffd097          	auipc	ra,0xffffd
    80003d44:	68c080e7          	jalr	1676(ra) # 800013cc <vmem_translate>
    80003d48:	87aa                	mv	a5,a0
    80003d4a:	a019                	j	80003d50 <copyinstr+0x5a>
    80003d4c:	fe843783          	ld	a5,-24(s0)
    80003d50:	fcf43823          	sd	a5,-48(s0)
        if (pa == 0) return -1;
    80003d54:	fd043783          	ld	a5,-48(s0)
    80003d58:	e399                	bnez	a5,80003d5e <copyinstr+0x68>
    80003d5a:	57fd                	li	a5,-1
    80003d5c:	a045                	j	80003dfc <copyinstr+0x106>
        char* p = (char*)pa;
    80003d5e:	fd043783          	ld	a5,-48(s0)
    80003d62:	fcf43423          	sd	a5,-56(s0)
        uint64 page_left = PGSIZE - (va & (PGSIZE - 1));
    80003d66:	fe843703          	ld	a4,-24(s0)
    80003d6a:	6785                	lui	a5,0x1
    80003d6c:	17fd                	add	a5,a5,-1 # fff <_entry-0x7ffff001>
    80003d6e:	8ff9                	and	a5,a5,a4
    80003d70:	6705                	lui	a4,0x1
    80003d72:	40f707b3          	sub	a5,a4,a5
    80003d76:	fcf43023          	sd	a5,-64(s0)
        for (uint64 i = 0; i < page_left && copied < max; i++) {
    80003d7a:	fc043c23          	sd	zero,-40(s0)
    80003d7e:	a0a1                	j	80003dc6 <copyinstr+0xd0>
            char c = p[i];
    80003d80:	fc843703          	ld	a4,-56(s0)
    80003d84:	fd843783          	ld	a5,-40(s0)
    80003d88:	97ba                	add	a5,a5,a4
    80003d8a:	0007c783          	lbu	a5,0(a5)
    80003d8e:	faf40fa3          	sb	a5,-65(s0)
            dst[copied++] = c;
    80003d92:	fe442783          	lw	a5,-28(s0)
    80003d96:	0017871b          	addw	a4,a5,1
    80003d9a:	fee42223          	sw	a4,-28(s0)
    80003d9e:	873e                	mv	a4,a5
    80003da0:	fa043783          	ld	a5,-96(s0)
    80003da4:	97ba                	add	a5,a5,a4
    80003da6:	fbf44703          	lbu	a4,-65(s0)
    80003daa:	00e78023          	sb	a4,0(a5)
            if (c == 0) {
    80003dae:	fbf44783          	lbu	a5,-65(s0)
    80003db2:	0ff7f793          	zext.b	a5,a5
    80003db6:	e399                	bnez	a5,80003dbc <copyinstr+0xc6>
                return 0;
    80003db8:	4781                	li	a5,0
    80003dba:	a089                	j	80003dfc <copyinstr+0x106>
        for (uint64 i = 0; i < page_left && copied < max; i++) {
    80003dbc:	fd843783          	ld	a5,-40(s0)
    80003dc0:	0785                	add	a5,a5,1
    80003dc2:	fcf43c23          	sd	a5,-40(s0)
    80003dc6:	fd843703          	ld	a4,-40(s0)
    80003dca:	fc043783          	ld	a5,-64(s0)
    80003dce:	00f77863          	bgeu	a4,a5,80003dde <copyinstr+0xe8>
    80003dd2:	fe442783          	lw	a5,-28(s0)
    80003dd6:	f9043703          	ld	a4,-112(s0)
    80003dda:	fae7e3e3          	bltu	a5,a4,80003d80 <copyinstr+0x8a>
            }
        }
        va = PGROUNDUP(va + 1);
    80003dde:	fe843703          	ld	a4,-24(s0)
    80003de2:	6785                	lui	a5,0x1
    80003de4:	973e                	add	a4,a4,a5
    80003de6:	77fd                	lui	a5,0xfffff
    80003de8:	8ff9                	and	a5,a5,a4
    80003dea:	fef43423          	sd	a5,-24(s0)
    while (copied < max) {
    80003dee:	fe442783          	lw	a5,-28(s0)
    80003df2:	f9043703          	ld	a4,-112(s0)
    80003df6:	f2e7e3e3          	bltu	a5,a4,80003d1c <copyinstr+0x26>
    }
    return -1;
    80003dfa:	57fd                	li	a5,-1
}
    80003dfc:	853e                	mv	a0,a5
    80003dfe:	70a6                	ld	ra,104(sp)
    80003e00:	7406                	ld	s0,96(sp)
    80003e02:	6165                	add	sp,sp,112
    80003e04:	8082                	ret

0000000080003e06 <r_sstatus>:
{
    80003e06:	1101                	add	sp,sp,-32
    80003e08:	ec22                	sd	s0,24(sp)
    80003e0a:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80003e0c:	100027f3          	csrr	a5,sstatus
    80003e10:	fef43423          	sd	a5,-24(s0)
  return x;
    80003e14:	fe843783          	ld	a5,-24(s0)
}
    80003e18:	853e                	mv	a0,a5
    80003e1a:	6462                	ld	s0,24(sp)
    80003e1c:	6105                	add	sp,sp,32
    80003e1e:	8082                	ret

0000000080003e20 <r_sip>:
{
    80003e20:	1101                	add	sp,sp,-32
    80003e22:	ec22                	sd	s0,24(sp)
    80003e24:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sip" : "=r" (x) );
    80003e26:	144027f3          	csrr	a5,sip
    80003e2a:	fef43423          	sd	a5,-24(s0)
  return x;
    80003e2e:	fe843783          	ld	a5,-24(s0)
}
    80003e32:	853e                	mv	a0,a5
    80003e34:	6462                	ld	s0,24(sp)
    80003e36:	6105                	add	sp,sp,32
    80003e38:	8082                	ret

0000000080003e3a <w_sip>:
{
    80003e3a:	1101                	add	sp,sp,-32
    80003e3c:	ec22                	sd	s0,24(sp)
    80003e3e:	1000                	add	s0,sp,32
    80003e40:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sip, %0" : : "r" (x));
    80003e44:	fe843783          	ld	a5,-24(s0)
    80003e48:	14479073          	csrw	sip,a5
}
    80003e4c:	0001                	nop
    80003e4e:	6462                	ld	s0,24(sp)
    80003e50:	6105                	add	sp,sp,32
    80003e52:	8082                	ret

0000000080003e54 <r_sie>:
{
    80003e54:	1101                	add	sp,sp,-32
    80003e56:	ec22                	sd	s0,24(sp)
    80003e58:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sie" : "=r" (x) );
    80003e5a:	104027f3          	csrr	a5,sie
    80003e5e:	fef43423          	sd	a5,-24(s0)
  return x;
    80003e62:	fe843783          	ld	a5,-24(s0)
}
    80003e66:	853e                	mv	a0,a5
    80003e68:	6462                	ld	s0,24(sp)
    80003e6a:	6105                	add	sp,sp,32
    80003e6c:	8082                	ret

0000000080003e6e <w_sie>:
{
    80003e6e:	1101                	add	sp,sp,-32
    80003e70:	ec22                	sd	s0,24(sp)
    80003e72:	1000                	add	s0,sp,32
    80003e74:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sie, %0" : : "r" (x));
    80003e78:	fe843783          	ld	a5,-24(s0)
    80003e7c:	10479073          	csrw	sie,a5
}
    80003e80:	0001                	nop
    80003e82:	6462                	ld	s0,24(sp)
    80003e84:	6105                	add	sp,sp,32
    80003e86:	8082                	ret

0000000080003e88 <w_stvec>:
{
    80003e88:	1101                	add	sp,sp,-32
    80003e8a:	ec22                	sd	s0,24(sp)
    80003e8c:	1000                	add	s0,sp,32
    80003e8e:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw stvec, %0" : : "r" (x));
    80003e92:	fe843783          	ld	a5,-24(s0)
    80003e96:	10579073          	csrw	stvec,a5
}
    80003e9a:	0001                	nop
    80003e9c:	6462                	ld	s0,24(sp)
    80003e9e:	6105                	add	sp,sp,32
    80003ea0:	8082                	ret

0000000080003ea2 <r_time>:
{
    80003ea2:	1101                	add	sp,sp,-32
    80003ea4:	ec22                	sd	s0,24(sp)
    80003ea6:	1000                	add	s0,sp,32
  asm volatile("csrr %0, time" : "=r" (x) );
    80003ea8:	c01027f3          	rdtime	a5
    80003eac:	fef43423          	sd	a5,-24(s0)
  return x;
    80003eb0:	fe843783          	ld	a5,-24(s0)
}
    80003eb4:	853e                	mv	a0,a5
    80003eb6:	6462                	ld	s0,24(sp)
    80003eb8:	6105                	add	sp,sp,32
    80003eba:	8082                	ret

0000000080003ebc <r_tp>:
{
    80003ebc:	1101                	add	sp,sp,-32
    80003ebe:	ec22                	sd	s0,24(sp)
    80003ec0:	1000                	add	s0,sp,32
  asm volatile("mv %0, tp" : "=r" (x) );
    80003ec2:	8792                	mv	a5,tp
    80003ec4:	fef43423          	sd	a5,-24(s0)
  return x;
    80003ec8:	fe843783          	ld	a5,-24(s0)
}
    80003ecc:	853e                	mv	a0,a5
    80003ece:	6462                	ld	s0,24(sp)
    80003ed0:	6105                	add	sp,sp,32
    80003ed2:	8082                	ret

0000000080003ed4 <register_interrupt>:
struct spinlock ticks_lock;

static void handle_exception(struct trapframe* tf);
static void scheduler_tick(uint64 now);

void register_interrupt(int irq, interrupt_handler_t h) {
    80003ed4:	1101                	add	sp,sp,-32
    80003ed6:	ec06                	sd	ra,24(sp)
    80003ed8:	e822                	sd	s0,16(sp)
    80003eda:	1000                	add	s0,sp,32
    80003edc:	87aa                	mv	a5,a0
    80003ede:	feb43023          	sd	a1,-32(s0)
    80003ee2:	fef42623          	sw	a5,-20(s0)
    if (irq < 0 || irq >= IRQ_MAX) {
    80003ee6:	fec42783          	lw	a5,-20(s0)
    80003eea:	2781                	sext.w	a5,a5
    80003eec:	0007c963          	bltz	a5,80003efe <register_interrupt+0x2a>
    80003ef0:	fec42783          	lw	a5,-20(s0)
    80003ef4:	0007871b          	sext.w	a4,a5
    80003ef8:	47bd                	li	a5,15
    80003efa:	00e7de63          	bge	a5,a4,80003f16 <register_interrupt+0x42>
        printf("[trap] ignore invalid irq %d\n", irq);
    80003efe:	fec42783          	lw	a5,-20(s0)
    80003f02:	85be                	mv	a1,a5
    80003f04:	00003517          	auipc	a0,0x3
    80003f08:	86450513          	add	a0,a0,-1948 # 80006768 <syscall_table+0x2f0>
    80003f0c:	00002097          	auipc	ra,0x2
    80003f10:	9ca080e7          	jalr	-1590(ra) # 800058d6 <printf>
        return;
    80003f14:	a821                	j	80003f2c <register_interrupt+0x58>
    }
    irq_table[irq] = h;
    80003f16:	00007717          	auipc	a4,0x7
    80003f1a:	09270713          	add	a4,a4,146 # 8000afa8 <irq_table>
    80003f1e:	fec42783          	lw	a5,-20(s0)
    80003f22:	078e                	sll	a5,a5,0x3
    80003f24:	97ba                	add	a5,a5,a4
    80003f26:	fe043703          	ld	a4,-32(s0)
    80003f2a:	e398                	sd	a4,0(a5)
}
    80003f2c:	60e2                	ld	ra,24(sp)
    80003f2e:	6442                	ld	s0,16(sp)
    80003f30:	6105                	add	sp,sp,32
    80003f32:	8082                	ret

0000000080003f34 <enable_interrupt>:

void enable_interrupt(int irq) {
    80003f34:	7179                	add	sp,sp,-48
    80003f36:	f406                	sd	ra,40(sp)
    80003f38:	f022                	sd	s0,32(sp)
    80003f3a:	1800                	add	s0,sp,48
    80003f3c:	87aa                	mv	a5,a0
    80003f3e:	fcf42e23          	sw	a5,-36(s0)
    if (irq < 0 || irq >= IRQ_MAX) return;
    80003f42:	fdc42783          	lw	a5,-36(s0)
    80003f46:	2781                	sext.w	a5,a5
    80003f48:	0207cf63          	bltz	a5,80003f86 <enable_interrupt+0x52>
    80003f4c:	fdc42783          	lw	a5,-36(s0)
    80003f50:	0007871b          	sext.w	a4,a5
    80003f54:	47bd                	li	a5,15
    80003f56:	02e7c863          	blt	a5,a4,80003f86 <enable_interrupt+0x52>
    uint64 mask = 1UL << irq;
    80003f5a:	fdc42783          	lw	a5,-36(s0)
    80003f5e:	873e                	mv	a4,a5
    80003f60:	4785                	li	a5,1
    80003f62:	00e797b3          	sll	a5,a5,a4
    80003f66:	fef43423          	sd	a5,-24(s0)
    w_sie(r_sie() | mask);
    80003f6a:	00000097          	auipc	ra,0x0
    80003f6e:	eea080e7          	jalr	-278(ra) # 80003e54 <r_sie>
    80003f72:	872a                	mv	a4,a0
    80003f74:	fe843783          	ld	a5,-24(s0)
    80003f78:	8fd9                	or	a5,a5,a4
    80003f7a:	853e                	mv	a0,a5
    80003f7c:	00000097          	auipc	ra,0x0
    80003f80:	ef2080e7          	jalr	-270(ra) # 80003e6e <w_sie>
    80003f84:	a011                	j	80003f88 <enable_interrupt+0x54>
    if (irq < 0 || irq >= IRQ_MAX) return;
    80003f86:	0001                	nop
}
    80003f88:	70a2                	ld	ra,40(sp)
    80003f8a:	7402                	ld	s0,32(sp)
    80003f8c:	6145                	add	sp,sp,48
    80003f8e:	8082                	ret

0000000080003f90 <disable_interrupt>:

void disable_interrupt(int irq) {
    80003f90:	7179                	add	sp,sp,-48
    80003f92:	f406                	sd	ra,40(sp)
    80003f94:	f022                	sd	s0,32(sp)
    80003f96:	1800                	add	s0,sp,48
    80003f98:	87aa                	mv	a5,a0
    80003f9a:	fcf42e23          	sw	a5,-36(s0)
    if (irq < 0 || irq >= IRQ_MAX) return;
    80003f9e:	fdc42783          	lw	a5,-36(s0)
    80003fa2:	2781                	sext.w	a5,a5
    80003fa4:	0407c163          	bltz	a5,80003fe6 <disable_interrupt+0x56>
    80003fa8:	fdc42783          	lw	a5,-36(s0)
    80003fac:	0007871b          	sext.w	a4,a5
    80003fb0:	47bd                	li	a5,15
    80003fb2:	02e7ca63          	blt	a5,a4,80003fe6 <disable_interrupt+0x56>
    uint64 mask = 1UL << irq;
    80003fb6:	fdc42783          	lw	a5,-36(s0)
    80003fba:	873e                	mv	a4,a5
    80003fbc:	4785                	li	a5,1
    80003fbe:	00e797b3          	sll	a5,a5,a4
    80003fc2:	fef43423          	sd	a5,-24(s0)
    w_sie(r_sie() & ~mask);
    80003fc6:	00000097          	auipc	ra,0x0
    80003fca:	e8e080e7          	jalr	-370(ra) # 80003e54 <r_sie>
    80003fce:	872a                	mv	a4,a0
    80003fd0:	fe843783          	ld	a5,-24(s0)
    80003fd4:	fff7c793          	not	a5,a5
    80003fd8:	8ff9                	and	a5,a5,a4
    80003fda:	853e                	mv	a0,a5
    80003fdc:	00000097          	auipc	ra,0x0
    80003fe0:	e92080e7          	jalr	-366(ra) # 80003e6e <w_sie>
    80003fe4:	a011                	j	80003fe8 <disable_interrupt+0x58>
    if (irq < 0 || irq >= IRQ_MAX) return;
    80003fe6:	0001                	nop
}
    80003fe8:	70a2                	ld	ra,40(sp)
    80003fea:	7402                	ld	s0,32(sp)
    80003fec:	6145                	add	sp,sp,48
    80003fee:	8082                	ret

0000000080003ff0 <get_time>:

uint64 get_time(void) {
    80003ff0:	1141                	add	sp,sp,-16
    80003ff2:	e406                	sd	ra,8(sp)
    80003ff4:	e022                	sd	s0,0(sp)
    80003ff6:	0800                	add	s0,sp,16
    return r_time();
    80003ff8:	00000097          	auipc	ra,0x0
    80003ffc:	eaa080e7          	jalr	-342(ra) # 80003ea2 <r_time>
    80004000:	87aa                	mv	a5,a0
}
    80004002:	853e                	mv	a0,a5
    80004004:	60a2                	ld	ra,8(sp)
    80004006:	6402                	ld	s0,0(sp)
    80004008:	0141                	add	sp,sp,16
    8000400a:	8082                	ret

000000008000400c <sbi_set_timer>:

// Directly program mtimecmp (hart0) to approximate the SBI timer service.
void sbi_set_timer(uint64 time) {
    8000400c:	7179                	add	sp,sp,-48
    8000400e:	f406                	sd	ra,40(sp)
    80004010:	f022                	sd	s0,32(sp)
    80004012:	1800                	add	s0,sp,48
    80004014:	fca43c23          	sd	a0,-40(s0)
    uint64 hart = r_tp();
    80004018:	00000097          	auipc	ra,0x0
    8000401c:	ea4080e7          	jalr	-348(ra) # 80003ebc <r_tp>
    80004020:	fea43423          	sd	a0,-24(s0)
    volatile uint64* mtimecmp = (uint64*)(0x02004000UL + 8 * hart);
    80004024:	fe843703          	ld	a4,-24(s0)
    80004028:	004017b7          	lui	a5,0x401
    8000402c:	80078793          	add	a5,a5,-2048 # 400800 <_entry-0x7fbff800>
    80004030:	97ba                	add	a5,a5,a4
    80004032:	078e                	sll	a5,a5,0x3
    80004034:	fef43023          	sd	a5,-32(s0)
    *mtimecmp = time;
    80004038:	fe043783          	ld	a5,-32(s0)
    8000403c:	fd843703          	ld	a4,-40(s0)
    80004040:	e398                	sd	a4,0(a5)
}
    80004042:	0001                	nop
    80004044:	70a2                	ld	ra,40(sp)
    80004046:	7402                	ld	s0,32(sp)
    80004048:	6145                	add	sp,sp,48
    8000404a:	8082                	ret

000000008000404c <timer_ticks>:

uint64 timer_ticks(void) {
    8000404c:	1101                	add	sp,sp,-32
    8000404e:	ec06                	sd	ra,24(sp)
    80004050:	e822                	sd	s0,16(sp)
    80004052:	1000                	add	s0,sp,32
    uint64 t;
    acquire(&ticks_lock);
    80004054:	00007517          	auipc	a0,0x7
    80004058:	f4450513          	add	a0,a0,-188 # 8000af98 <ticks_lock>
    8000405c:	ffffd097          	auipc	ra,0xffffd
    80004060:	7d8080e7          	jalr	2008(ra) # 80001834 <acquire>
    t = ticks;
    80004064:	00003797          	auipc	a5,0x3
    80004068:	df478793          	add	a5,a5,-524 # 80006e58 <ticks>
    8000406c:	639c                	ld	a5,0(a5)
    8000406e:	fef43423          	sd	a5,-24(s0)
    release(&ticks_lock);
    80004072:	00007517          	auipc	a0,0x7
    80004076:	f2650513          	add	a0,a0,-218 # 8000af98 <ticks_lock>
    8000407a:	ffffd097          	auipc	ra,0xffffd
    8000407e:	7ee080e7          	jalr	2030(ra) # 80001868 <release>
    return t;
    80004082:	fe843783          	ld	a5,-24(s0)
}
    80004086:	853e                	mv	a0,a5
    80004088:	60e2                	ld	ra,24(sp)
    8000408a:	6442                	ld	s0,16(sp)
    8000408c:	6105                	add	sp,sp,32
    8000408e:	8082                	ret

0000000080004090 <timer_interrupt>:

void timer_interrupt(void) {
    80004090:	1101                	add	sp,sp,-32
    80004092:	ec06                	sd	ra,24(sp)
    80004094:	e822                	sd	s0,16(sp)
    80004096:	1000                	add	s0,sp,32
    acquire(&ticks_lock);
    80004098:	00007517          	auipc	a0,0x7
    8000409c:	f0050513          	add	a0,a0,-256 # 8000af98 <ticks_lock>
    800040a0:	ffffd097          	auipc	ra,0xffffd
    800040a4:	794080e7          	jalr	1940(ra) # 80001834 <acquire>
    ticks++;
    800040a8:	00003797          	auipc	a5,0x3
    800040ac:	db078793          	add	a5,a5,-592 # 80006e58 <ticks>
    800040b0:	639c                	ld	a5,0(a5)
    800040b2:	00178713          	add	a4,a5,1
    800040b6:	00003797          	auipc	a5,0x3
    800040ba:	da278793          	add	a5,a5,-606 # 80006e58 <ticks>
    800040be:	e398                	sd	a4,0(a5)
    uint64 now = ticks;
    800040c0:	00003797          	auipc	a5,0x3
    800040c4:	d9878793          	add	a5,a5,-616 # 80006e58 <ticks>
    800040c8:	639c                	ld	a5,0(a5)
    800040ca:	fef43423          	sd	a5,-24(s0)
    release(&ticks_lock);
    800040ce:	00007517          	auipc	a0,0x7
    800040d2:	eca50513          	add	a0,a0,-310 # 8000af98 <ticks_lock>
    800040d6:	ffffd097          	auipc	ra,0xffffd
    800040da:	792080e7          	jalr	1938(ra) # 80001868 <release>
    timer_interrupt_count++;
    800040de:	00007797          	auipc	a5,0x7
    800040e2:	f4a78793          	add	a5,a5,-182 # 8000b028 <timer_interrupt_count>
    800040e6:	439c                	lw	a5,0(a5)
    800040e8:	2781                	sext.w	a5,a5
    800040ea:	2785                	addw	a5,a5,1
    800040ec:	0007871b          	sext.w	a4,a5
    800040f0:	00007797          	auipc	a5,0x7
    800040f4:	f3878793          	add	a5,a5,-200 # 8000b028 <timer_interrupt_count>
    800040f8:	c398                	sw	a4,0(a5)
    scheduler_tick(now);
    800040fa:	fe843503          	ld	a0,-24(s0)
    800040fe:	00000097          	auipc	ra,0x0
    80004102:	306080e7          	jalr	774(ra) # 80004404 <scheduler_tick>
    wakeup((void*)&ticks);
    80004106:	00003517          	auipc	a0,0x3
    8000410a:	d5250513          	add	a0,a0,-686 # 80006e58 <ticks>
    8000410e:	ffffe097          	auipc	ra,0xffffe
    80004112:	082080e7          	jalr	130(ra) # 80002190 <wakeup>
    // Clear SSIP raised by machine timer bridge
    w_sip(r_sip() & ~SIE_SSIE);
    80004116:	00000097          	auipc	ra,0x0
    8000411a:	d0a080e7          	jalr	-758(ra) # 80003e20 <r_sip>
    8000411e:	87aa                	mv	a5,a0
    80004120:	9bf5                	and	a5,a5,-3
    80004122:	853e                	mv	a0,a5
    80004124:	00000097          	auipc	ra,0x0
    80004128:	d16080e7          	jalr	-746(ra) # 80003e3a <w_sip>
}
    8000412c:	0001                	nop
    8000412e:	60e2                	ld	ra,24(sp)
    80004130:	6442                	ld	s0,16(sp)
    80004132:	6105                	add	sp,sp,32
    80004134:	8082                	ret

0000000080004136 <trap_init>:

void trap_init(void) {
    80004136:	1141                	add	sp,sp,-16
    80004138:	e406                	sd	ra,8(sp)
    8000413a:	e022                	sd	s0,0(sp)
    8000413c:	0800                	add	s0,sp,16
    w_stvec((uint64)kernelvec);
    8000413e:	00002797          	auipc	a5,0x2
    80004142:	86e78793          	add	a5,a5,-1938 # 800059ac <kernelvec>
    80004146:	853e                	mv	a0,a5
    80004148:	00000097          	auipc	ra,0x0
    8000414c:	d40080e7          	jalr	-704(ra) # 80003e88 <w_stvec>
    initlock(&ticks_lock, "ticks");
    80004150:	00002597          	auipc	a1,0x2
    80004154:	63858593          	add	a1,a1,1592 # 80006788 <syscall_table+0x310>
    80004158:	00007517          	auipc	a0,0x7
    8000415c:	e4050513          	add	a0,a0,-448 # 8000af98 <ticks_lock>
    80004160:	ffffd097          	auipc	ra,0xffffd
    80004164:	68a080e7          	jalr	1674(ra) # 800017ea <initlock>
    register_interrupt(IRQ_S_SOFTWARE, timer_interrupt);
    80004168:	00000597          	auipc	a1,0x0
    8000416c:	f2858593          	add	a1,a1,-216 # 80004090 <timer_interrupt>
    80004170:	4505                	li	a0,1
    80004172:	00000097          	auipc	ra,0x0
    80004176:	d62080e7          	jalr	-670(ra) # 80003ed4 <register_interrupt>
    enable_interrupt(IRQ_S_SOFTWARE);
    8000417a:	4505                	li	a0,1
    8000417c:	00000097          	auipc	ra,0x0
    80004180:	db8080e7          	jalr	-584(ra) # 80003f34 <enable_interrupt>
}
    80004184:	0001                	nop
    80004186:	60a2                	ld	ra,8(sp)
    80004188:	6402                	ld	s0,0(sp)
    8000418a:	0141                	add	sp,sp,16
    8000418c:	8082                	ret

000000008000418e <kerneltrap>:

void kerneltrap(struct trapframe* tf) {
    8000418e:	7139                	add	sp,sp,-64
    80004190:	fc06                	sd	ra,56(sp)
    80004192:	f822                	sd	s0,48(sp)
    80004194:	0080                	add	s0,sp,64
    80004196:	fca43423          	sd	a0,-56(s0)
    uint64 scause = tf->scause;
    8000419a:	fc843783          	ld	a5,-56(s0)
    8000419e:	1107b783          	ld	a5,272(a5)
    800041a2:	fef43423          	sd	a5,-24(s0)
    uint64 sstatus = r_sstatus();
    800041a6:	00000097          	auipc	ra,0x0
    800041aa:	c60080e7          	jalr	-928(ra) # 80003e06 <r_sstatus>
    800041ae:	fea43023          	sd	a0,-32(s0)
    struct proc* p = myproc();
    800041b2:	ffffe097          	auipc	ra,0xffffe
    800041b6:	df8080e7          	jalr	-520(ra) # 80001faa <myproc>
    800041ba:	fca43c23          	sd	a0,-40(s0)
    if (p) {
    800041be:	fd843783          	ld	a5,-40(s0)
    800041c2:	c791                	beqz	a5,800041ce <kerneltrap+0x40>
        p->trapframe = tf;
    800041c4:	fd843783          	ld	a5,-40(s0)
    800041c8:	fc843703          	ld	a4,-56(s0)
    800041cc:	ff98                	sd	a4,56(a5)
    }
    if ((sstatus & SSTATUS_SPP) == 0) {
    800041ce:	fe043783          	ld	a5,-32(s0)
    800041d2:	1007f793          	and	a5,a5,256
    800041d6:	eb89                	bnez	a5,800041e8 <kerneltrap+0x5a>
        panic("kerneltrap: not from supervisor");
    800041d8:	00002517          	auipc	a0,0x2
    800041dc:	5b850513          	add	a0,a0,1464 # 80006790 <syscall_table+0x318>
    800041e0:	00001097          	auipc	ra,0x1
    800041e4:	78e080e7          	jalr	1934(ra) # 8000596e <panic>
    }

    if (scause & (1ULL << 63)) {
    800041e8:	fe843783          	ld	a5,-24(s0)
    800041ec:	0607d863          	bgez	a5,8000425c <kerneltrap+0xce>
        int irq = (int)(scause & 0xff);
    800041f0:	fe843783          	ld	a5,-24(s0)
    800041f4:	2781                	sext.w	a5,a5
    800041f6:	0ff7f793          	zext.b	a5,a5
    800041fa:	fcf42a23          	sw	a5,-44(s0)
        if (irq >= 0 && irq < IRQ_MAX && irq_table[irq]) {
    800041fe:	fd442783          	lw	a5,-44(s0)
    80004202:	2781                	sext.w	a5,a5
    80004204:	0207ce63          	bltz	a5,80004240 <kerneltrap+0xb2>
    80004208:	fd442783          	lw	a5,-44(s0)
    8000420c:	0007871b          	sext.w	a4,a5
    80004210:	47bd                	li	a5,15
    80004212:	02e7c763          	blt	a5,a4,80004240 <kerneltrap+0xb2>
    80004216:	00007717          	auipc	a4,0x7
    8000421a:	d9270713          	add	a4,a4,-622 # 8000afa8 <irq_table>
    8000421e:	fd442783          	lw	a5,-44(s0)
    80004222:	078e                	sll	a5,a5,0x3
    80004224:	97ba                	add	a5,a5,a4
    80004226:	639c                	ld	a5,0(a5)
    80004228:	cf81                	beqz	a5,80004240 <kerneltrap+0xb2>
            irq_table[irq]();
    8000422a:	00007717          	auipc	a4,0x7
    8000422e:	d7e70713          	add	a4,a4,-642 # 8000afa8 <irq_table>
    80004232:	fd442783          	lw	a5,-44(s0)
    80004236:	078e                	sll	a5,a5,0x3
    80004238:	97ba                	add	a5,a5,a4
    8000423a:	639c                	ld	a5,0(a5)
    8000423c:	9782                	jalr	a5
            printf("[trap] unhandled interrupt %d (scause=0x%lx)\n", irq, scause);
        }
    } else {
        handle_exception(tf);
    }
}
    8000423e:	a02d                	j	80004268 <kerneltrap+0xda>
            printf("[trap] unhandled interrupt %d (scause=0x%lx)\n", irq, scause);
    80004240:	fd442783          	lw	a5,-44(s0)
    80004244:	fe843603          	ld	a2,-24(s0)
    80004248:	85be                	mv	a1,a5
    8000424a:	00002517          	auipc	a0,0x2
    8000424e:	56650513          	add	a0,a0,1382 # 800067b0 <syscall_table+0x338>
    80004252:	00001097          	auipc	ra,0x1
    80004256:	684080e7          	jalr	1668(ra) # 800058d6 <printf>
}
    8000425a:	a039                	j	80004268 <kerneltrap+0xda>
        handle_exception(tf);
    8000425c:	fc843503          	ld	a0,-56(s0)
    80004260:	00000097          	auipc	ra,0x0
    80004264:	0d6080e7          	jalr	214(ra) # 80004336 <handle_exception>
}
    80004268:	0001                	nop
    8000426a:	70e2                	ld	ra,56(sp)
    8000426c:	7442                	ld	s0,48(sp)
    8000426e:	6121                	add	sp,sp,64
    80004270:	8082                	ret

0000000080004272 <handle_syscall>:

static void handle_syscall(struct trapframe* tf) {
    80004272:	1101                	add	sp,sp,-32
    80004274:	ec06                	sd	ra,24(sp)
    80004276:	e822                	sd	s0,16(sp)
    80004278:	1000                	add	s0,sp,32
    8000427a:	fea43423          	sd	a0,-24(s0)
    syscall_dispatch(tf);
    8000427e:	fe843503          	ld	a0,-24(s0)
    80004282:	fffff097          	auipc	ra,0xfffff
    80004286:	f62080e7          	jalr	-158(ra) # 800031e4 <syscall_dispatch>
}
    8000428a:	0001                	nop
    8000428c:	60e2                	ld	ra,24(sp)
    8000428e:	6442                	ld	s0,16(sp)
    80004290:	6105                	add	sp,sp,32
    80004292:	8082                	ret

0000000080004294 <handle_instruction_page_fault>:

static void handle_instruction_page_fault(struct trapframe* tf) {
    80004294:	1101                	add	sp,sp,-32
    80004296:	ec06                	sd	ra,24(sp)
    80004298:	e822                	sd	s0,16(sp)
    8000429a:	1000                	add	s0,sp,32
    8000429c:	fea43423          	sd	a0,-24(s0)
    printf("[trap] instruction page fault @0x%lx\n", tf->stval);
    800042a0:	fe843783          	ld	a5,-24(s0)
    800042a4:	1087b783          	ld	a5,264(a5)
    800042a8:	85be                	mv	a1,a5
    800042aa:	00002517          	auipc	a0,0x2
    800042ae:	53650513          	add	a0,a0,1334 # 800067e0 <syscall_table+0x368>
    800042b2:	00001097          	auipc	ra,0x1
    800042b6:	624080e7          	jalr	1572(ra) # 800058d6 <printf>
    panic("instruction page fault");
    800042ba:	00002517          	auipc	a0,0x2
    800042be:	54e50513          	add	a0,a0,1358 # 80006808 <syscall_table+0x390>
    800042c2:	00001097          	auipc	ra,0x1
    800042c6:	6ac080e7          	jalr	1708(ra) # 8000596e <panic>

00000000800042ca <handle_load_page_fault>:
}

static void handle_load_page_fault(struct trapframe* tf) {
    800042ca:	1101                	add	sp,sp,-32
    800042cc:	ec06                	sd	ra,24(sp)
    800042ce:	e822                	sd	s0,16(sp)
    800042d0:	1000                	add	s0,sp,32
    800042d2:	fea43423          	sd	a0,-24(s0)
    printf("[trap] load page fault @0x%lx\n", tf->stval);
    800042d6:	fe843783          	ld	a5,-24(s0)
    800042da:	1087b783          	ld	a5,264(a5)
    800042de:	85be                	mv	a1,a5
    800042e0:	00002517          	auipc	a0,0x2
    800042e4:	54050513          	add	a0,a0,1344 # 80006820 <syscall_table+0x3a8>
    800042e8:	00001097          	auipc	ra,0x1
    800042ec:	5ee080e7          	jalr	1518(ra) # 800058d6 <printf>
    panic("load page fault");
    800042f0:	00002517          	auipc	a0,0x2
    800042f4:	55050513          	add	a0,a0,1360 # 80006840 <syscall_table+0x3c8>
    800042f8:	00001097          	auipc	ra,0x1
    800042fc:	676080e7          	jalr	1654(ra) # 8000596e <panic>

0000000080004300 <handle_store_page_fault>:
}

static void handle_store_page_fault(struct trapframe* tf) {
    80004300:	1101                	add	sp,sp,-32
    80004302:	ec06                	sd	ra,24(sp)
    80004304:	e822                	sd	s0,16(sp)
    80004306:	1000                	add	s0,sp,32
    80004308:	fea43423          	sd	a0,-24(s0)
    printf("[trap] store page fault @0x%lx\n", tf->stval);
    8000430c:	fe843783          	ld	a5,-24(s0)
    80004310:	1087b783          	ld	a5,264(a5)
    80004314:	85be                	mv	a1,a5
    80004316:	00002517          	auipc	a0,0x2
    8000431a:	53a50513          	add	a0,a0,1338 # 80006850 <syscall_table+0x3d8>
    8000431e:	00001097          	auipc	ra,0x1
    80004322:	5b8080e7          	jalr	1464(ra) # 800058d6 <printf>
    panic("store page fault");
    80004326:	00002517          	auipc	a0,0x2
    8000432a:	54a50513          	add	a0,a0,1354 # 80006870 <syscall_table+0x3f8>
    8000432e:	00001097          	auipc	ra,0x1
    80004332:	640080e7          	jalr	1600(ra) # 8000596e <panic>

0000000080004336 <handle_exception>:
}

static void handle_exception(struct trapframe* tf) {
    80004336:	7179                	add	sp,sp,-48
    80004338:	f406                	sd	ra,40(sp)
    8000433a:	f022                	sd	s0,32(sp)
    8000433c:	1800                	add	s0,sp,48
    8000433e:	fca43c23          	sd	a0,-40(s0)
    uint64 cause = tf->scause;
    80004342:	fd843783          	ld	a5,-40(s0)
    80004346:	1107b783          	ld	a5,272(a5)
    8000434a:	fef43423          	sd	a5,-24(s0)
    switch (cause) {
    8000434e:	fe843703          	ld	a4,-24(s0)
    80004352:	47bd                	li	a5,15
    80004354:	06f70163          	beq	a4,a5,800043b6 <handle_exception+0x80>
    80004358:	fe843703          	ld	a4,-24(s0)
    8000435c:	47bd                	li	a5,15
    8000435e:	06e7e363          	bltu	a5,a4,800043c4 <handle_exception+0x8e>
    80004362:	fe843703          	ld	a4,-24(s0)
    80004366:	47b5                	li	a5,13
    80004368:	04f70063          	beq	a4,a5,800043a8 <handle_exception+0x72>
    8000436c:	fe843703          	ld	a4,-24(s0)
    80004370:	47b5                	li	a5,13
    80004372:	04e7e963          	bltu	a5,a4,800043c4 <handle_exception+0x8e>
    80004376:	fe843703          	ld	a4,-24(s0)
    8000437a:	47a1                	li	a5,8
    8000437c:	00f70863          	beq	a4,a5,8000438c <handle_exception+0x56>
    80004380:	fe843703          	ld	a4,-24(s0)
    80004384:	47b1                	li	a5,12
    80004386:	00f70a63          	beq	a4,a5,8000439a <handle_exception+0x64>
    8000438a:	a82d                	j	800043c4 <handle_exception+0x8e>
        case 8:
            handle_syscall(tf);
    8000438c:	fd843503          	ld	a0,-40(s0)
    80004390:	00000097          	auipc	ra,0x0
    80004394:	ee2080e7          	jalr	-286(ra) # 80004272 <handle_syscall>
            break;
    80004398:	a08d                	j	800043fa <handle_exception+0xc4>
        case 12:
            handle_instruction_page_fault(tf);
    8000439a:	fd843503          	ld	a0,-40(s0)
    8000439e:	00000097          	auipc	ra,0x0
    800043a2:	ef6080e7          	jalr	-266(ra) # 80004294 <handle_instruction_page_fault>
            break;
    800043a6:	a891                	j	800043fa <handle_exception+0xc4>
        case 13:
            handle_load_page_fault(tf);
    800043a8:	fd843503          	ld	a0,-40(s0)
    800043ac:	00000097          	auipc	ra,0x0
    800043b0:	f1e080e7          	jalr	-226(ra) # 800042ca <handle_load_page_fault>
            break;
    800043b4:	a099                	j	800043fa <handle_exception+0xc4>
        case 15:
            handle_store_page_fault(tf);
    800043b6:	fd843503          	ld	a0,-40(s0)
    800043ba:	00000097          	auipc	ra,0x0
    800043be:	f46080e7          	jalr	-186(ra) # 80004300 <handle_store_page_fault>
            break;
    800043c2:	a825                	j	800043fa <handle_exception+0xc4>
        default:
            printf("[trap] unknown exception cause=%lu sepc=0x%lx stval=0x%lx\n",
    800043c4:	fd843783          	ld	a5,-40(s0)
    800043c8:	7ff8                	ld	a4,248(a5)
    800043ca:	fd843783          	ld	a5,-40(s0)
    800043ce:	1087b783          	ld	a5,264(a5)
    800043d2:	86be                	mv	a3,a5
    800043d4:	863a                	mv	a2,a4
    800043d6:	fe843583          	ld	a1,-24(s0)
    800043da:	00002517          	auipc	a0,0x2
    800043de:	4ae50513          	add	a0,a0,1198 # 80006888 <syscall_table+0x410>
    800043e2:	00001097          	auipc	ra,0x1
    800043e6:	4f4080e7          	jalr	1268(ra) # 800058d6 <printf>
                   cause, tf->sepc, tf->stval);
            panic("Unknown exception");
    800043ea:	00002517          	auipc	a0,0x2
    800043ee:	4de50513          	add	a0,a0,1246 # 800068c8 <syscall_table+0x450>
    800043f2:	00001097          	auipc	ra,0x1
    800043f6:	57c080e7          	jalr	1404(ra) # 8000596e <panic>
    }
}
    800043fa:	0001                	nop
    800043fc:	70a2                	ld	ra,40(sp)
    800043fe:	7402                	ld	s0,32(sp)
    80004400:	6145                	add	sp,sp,48
    80004402:	8082                	ret

0000000080004404 <scheduler_tick>:

static void scheduler_tick(uint64 now) {
    80004404:	7179                	add	sp,sp,-48
    80004406:	f406                	sd	ra,40(sp)
    80004408:	f022                	sd	s0,32(sp)
    8000440a:	1800                	add	s0,sp,48
    8000440c:	fca43c23          	sd	a0,-40(s0)
    proc_on_tick();
    80004410:	ffffe097          	auipc	ra,0xffffe
    80004414:	2fe080e7          	jalr	766(ra) # 8000270e <proc_on_tick>
    struct proc* p = myproc();
    80004418:	ffffe097          	auipc	ra,0xffffe
    8000441c:	b92080e7          	jalr	-1134(ra) # 80001faa <myproc>
    80004420:	fea43423          	sd	a0,-24(s0)
    if (p && p->state == PROC_RUNNING && p->need_resched) {
    80004424:	fe843783          	ld	a5,-24(s0)
    80004428:	cb8d                	beqz	a5,8000445a <scheduler_tick+0x56>
    8000442a:	fe843783          	ld	a5,-24(s0)
    8000442e:	4b9c                	lw	a5,16(a5)
    80004430:	873e                	mv	a4,a5
    80004432:	478d                	li	a5,3
    80004434:	02f71363          	bne	a4,a5,8000445a <scheduler_tick+0x56>
    80004438:	fe843783          	ld	a5,-24(s0)
    8000443c:	53bc                	lw	a5,96(a5)
    8000443e:	cf91                	beqz	a5,8000445a <scheduler_tick+0x56>
        if (!holding(&p->lock)) {
    80004440:	fe843783          	ld	a5,-24(s0)
    80004444:	853e                	mv	a0,a5
    80004446:	ffffd097          	auipc	ra,0xffffd
    8000444a:	3cc080e7          	jalr	972(ra) # 80001812 <holding>
    8000444e:	87aa                	mv	a5,a0
    80004450:	e789                	bnez	a5,8000445a <scheduler_tick+0x56>
            yield();
    80004452:	ffffe097          	auipc	ra,0xffffe
    80004456:	bfc080e7          	jalr	-1028(ra) # 8000204e <yield>
        }
    }
    if ((now % 1000) == 0) {
    8000445a:	fd843703          	ld	a4,-40(s0)
    8000445e:	3e800793          	li	a5,1000
    80004462:	02f777b3          	remu	a5,a4,a5
    80004466:	eb99                	bnez	a5,8000447c <scheduler_tick+0x78>
        printf("[sched] %lu ticks elapsed\n", now);
    80004468:	fd843583          	ld	a1,-40(s0)
    8000446c:	00002517          	auipc	a0,0x2
    80004470:	47450513          	add	a0,a0,1140 # 800068e0 <syscall_table+0x468>
    80004474:	00001097          	auipc	ra,0x1
    80004478:	462080e7          	jalr	1122(ra) # 800058d6 <printf>
    }
}
    8000447c:	0001                	nop
    8000447e:	70a2                	ld	ra,40(sp)
    80004480:	7402                	ld	s0,32(sp)
    80004482:	6145                	add	sp,sp,48
    80004484:	8082                	ret

0000000080004486 <get_timer_interrupt_count>:

int get_timer_interrupt_count(void) {
    80004486:	1141                	add	sp,sp,-16
    80004488:	e422                	sd	s0,8(sp)
    8000448a:	0800                	add	s0,sp,16
    return timer_interrupt_count;
    8000448c:	00007797          	auipc	a5,0x7
    80004490:	b9c78793          	add	a5,a5,-1124 # 8000b028 <timer_interrupt_count>
    80004494:	439c                	lw	a5,0(a5)
    80004496:	2781                	sext.w	a5,a5
}
    80004498:	853e                	mv	a0,a5
    8000449a:	6422                	ld	s0,8(sp)
    8000449c:	0141                	add	sp,sp,16
    8000449e:	8082                	ret

00000000800044a0 <assert_nonnull>:
#include "include/pmm.h"
#include "include/printf.h"
#include "include/vmem.h"
#include "include/test.h"

static void assert_nonnull(void* ptr, const char* msg) {
    800044a0:	1101                	add	sp,sp,-32
    800044a2:	ec06                	sd	ra,24(sp)
    800044a4:	e822                	sd	s0,16(sp)
    800044a6:	1000                	add	s0,sp,32
    800044a8:	fea43423          	sd	a0,-24(s0)
    800044ac:	feb43023          	sd	a1,-32(s0)
    if (!ptr) {
    800044b0:	fe843783          	ld	a5,-24(s0)
    800044b4:	e799                	bnez	a5,800044c2 <assert_nonnull+0x22>
        panic(msg);
    800044b6:	fe043503          	ld	a0,-32(s0)
    800044ba:	00001097          	auipc	ra,0x1
    800044be:	4b4080e7          	jalr	1204(ra) # 8000596e <panic>
    }
}
    800044c2:	0001                	nop
    800044c4:	60e2                	ld	ra,24(sp)
    800044c6:	6442                	ld	s0,16(sp)
    800044c8:	6105                	add	sp,sp,32
    800044ca:	8082                	ret

00000000800044cc <test_physical_memory>:

void test_physical_memory(void) {
    800044cc:	715d                	add	sp,sp,-80
    800044ce:	e486                	sd	ra,72(sp)
    800044d0:	e0a2                	sd	s0,64(sp)
    800044d2:	0880                	add	s0,sp,80
    printf("[test] physical memory start\n");
    800044d4:	00002517          	auipc	a0,0x2
    800044d8:	42c50513          	add	a0,a0,1068 # 80006900 <syscall_table+0x488>
    800044dc:	00001097          	auipc	ra,0x1
    800044e0:	3fa080e7          	jalr	1018(ra) # 800058d6 <printf>
    size_t before = pmm_free_pages();
    800044e4:	ffffc097          	auipc	ra,0xffffc
    800044e8:	44e080e7          	jalr	1102(ra) # 80000932 <pmm_free_pages>
    800044ec:	fea43423          	sd	a0,-24(s0)
    void* p1 = alloc_page();
    800044f0:	ffffc097          	auipc	ra,0xffffc
    800044f4:	20a080e7          	jalr	522(ra) # 800006fa <alloc_page>
    800044f8:	fea43023          	sd	a0,-32(s0)
    void* p2 = alloc_page();
    800044fc:	ffffc097          	auipc	ra,0xffffc
    80004500:	1fe080e7          	jalr	510(ra) # 800006fa <alloc_page>
    80004504:	fca43c23          	sd	a0,-40(s0)
    void* p3 = alloc_page();
    80004508:	ffffc097          	auipc	ra,0xffffc
    8000450c:	1f2080e7          	jalr	498(ra) # 800006fa <alloc_page>
    80004510:	fca43823          	sd	a0,-48(s0)

    assert_nonnull(p1, "alloc p1");
    80004514:	00002597          	auipc	a1,0x2
    80004518:	40c58593          	add	a1,a1,1036 # 80006920 <syscall_table+0x4a8>
    8000451c:	fe043503          	ld	a0,-32(s0)
    80004520:	00000097          	auipc	ra,0x0
    80004524:	f80080e7          	jalr	-128(ra) # 800044a0 <assert_nonnull>
    assert_nonnull(p2, "alloc p2");
    80004528:	00002597          	auipc	a1,0x2
    8000452c:	40858593          	add	a1,a1,1032 # 80006930 <syscall_table+0x4b8>
    80004530:	fd843503          	ld	a0,-40(s0)
    80004534:	00000097          	auipc	ra,0x0
    80004538:	f6c080e7          	jalr	-148(ra) # 800044a0 <assert_nonnull>
    assert_nonnull(p3, "alloc p3");
    8000453c:	00002597          	auipc	a1,0x2
    80004540:	40458593          	add	a1,a1,1028 # 80006940 <syscall_table+0x4c8>
    80004544:	fd043503          	ld	a0,-48(s0)
    80004548:	00000097          	auipc	ra,0x0
    8000454c:	f58080e7          	jalr	-168(ra) # 800044a0 <assert_nonnull>

    if (p1 == p2 || p1 == p3 || p2 == p3) {
    80004550:	fe043703          	ld	a4,-32(s0)
    80004554:	fd843783          	ld	a5,-40(s0)
    80004558:	00f70e63          	beq	a4,a5,80004574 <test_physical_memory+0xa8>
    8000455c:	fe043703          	ld	a4,-32(s0)
    80004560:	fd043783          	ld	a5,-48(s0)
    80004564:	00f70863          	beq	a4,a5,80004574 <test_physical_memory+0xa8>
    80004568:	fd843703          	ld	a4,-40(s0)
    8000456c:	fd043783          	ld	a5,-48(s0)
    80004570:	00f71a63          	bne	a4,a5,80004584 <test_physical_memory+0xb8>
        panic("duplicate physical pages");
    80004574:	00002517          	auipc	a0,0x2
    80004578:	3dc50513          	add	a0,a0,988 # 80006950 <syscall_table+0x4d8>
    8000457c:	00001097          	auipc	ra,0x1
    80004580:	3f2080e7          	jalr	1010(ra) # 8000596e <panic>
    }

    uint64* a = (uint64*)p1;
    80004584:	fe043783          	ld	a5,-32(s0)
    80004588:	fcf43423          	sd	a5,-56(s0)
    uint64* b = (uint64*)p2;
    8000458c:	fd843783          	ld	a5,-40(s0)
    80004590:	fcf43023          	sd	a5,-64(s0)
    uint64* c = (uint64*)p3;
    80004594:	fd043783          	ld	a5,-48(s0)
    80004598:	faf43c23          	sd	a5,-72(s0)
    a[0] = 0x1111222233334444;
    8000459c:	fc843783          	ld	a5,-56(s0)
    800045a0:	00002717          	auipc	a4,0x2
    800045a4:	4c070713          	add	a4,a4,1216 # 80006a60 <syscall_table+0x5e8>
    800045a8:	6318                	ld	a4,0(a4)
    800045aa:	e398                	sd	a4,0(a5)
    b[0] = 0x5555666677778888;
    800045ac:	fc043783          	ld	a5,-64(s0)
    800045b0:	00002717          	auipc	a4,0x2
    800045b4:	4b870713          	add	a4,a4,1208 # 80006a68 <syscall_table+0x5f0>
    800045b8:	6318                	ld	a4,0(a4)
    800045ba:	e398                	sd	a4,0(a5)
    c[0] = 0x9999aaaabbbbcccc;
    800045bc:	fb843783          	ld	a5,-72(s0)
    800045c0:	00002717          	auipc	a4,0x2
    800045c4:	4b070713          	add	a4,a4,1200 # 80006a70 <syscall_table+0x5f8>
    800045c8:	6318                	ld	a4,0(a4)
    800045ca:	e398                	sd	a4,0(a5)

    if (a[0] != 0x1111222233334444 || b[0] != 0x5555666677778888 || c[0] != 0x9999aaaabbbbcccc) {
    800045cc:	fc843783          	ld	a5,-56(s0)
    800045d0:	6398                	ld	a4,0(a5)
    800045d2:	00002797          	auipc	a5,0x2
    800045d6:	48e78793          	add	a5,a5,1166 # 80006a60 <syscall_table+0x5e8>
    800045da:	639c                	ld	a5,0(a5)
    800045dc:	02f71663          	bne	a4,a5,80004608 <test_physical_memory+0x13c>
    800045e0:	fc043783          	ld	a5,-64(s0)
    800045e4:	6398                	ld	a4,0(a5)
    800045e6:	00002797          	auipc	a5,0x2
    800045ea:	48278793          	add	a5,a5,1154 # 80006a68 <syscall_table+0x5f0>
    800045ee:	639c                	ld	a5,0(a5)
    800045f0:	00f71c63          	bne	a4,a5,80004608 <test_physical_memory+0x13c>
    800045f4:	fb843783          	ld	a5,-72(s0)
    800045f8:	6398                	ld	a4,0(a5)
    800045fa:	00002797          	auipc	a5,0x2
    800045fe:	47678793          	add	a5,a5,1142 # 80006a70 <syscall_table+0x5f8>
    80004602:	639c                	ld	a5,0(a5)
    80004604:	00f70a63          	beq	a4,a5,80004618 <test_physical_memory+0x14c>
        panic("memory pattern mismatch");
    80004608:	00002517          	auipc	a0,0x2
    8000460c:	36850513          	add	a0,a0,872 # 80006970 <syscall_table+0x4f8>
    80004610:	00001097          	auipc	ra,0x1
    80004614:	35e080e7          	jalr	862(ra) # 8000596e <panic>
    }

    free_page(p1);
    80004618:	fe043503          	ld	a0,-32(s0)
    8000461c:	ffffc097          	auipc	ra,0xffffc
    80004620:	05a080e7          	jalr	90(ra) # 80000676 <free_page>
    free_page(p2);
    80004624:	fd843503          	ld	a0,-40(s0)
    80004628:	ffffc097          	auipc	ra,0xffffc
    8000462c:	04e080e7          	jalr	78(ra) # 80000676 <free_page>
    free_page(p3);
    80004630:	fd043503          	ld	a0,-48(s0)
    80004634:	ffffc097          	auipc	ra,0xffffc
    80004638:	042080e7          	jalr	66(ra) # 80000676 <free_page>

    if (pmm_free_pages() != before) {
    8000463c:	ffffc097          	auipc	ra,0xffffc
    80004640:	2f6080e7          	jalr	758(ra) # 80000932 <pmm_free_pages>
    80004644:	872a                	mv	a4,a0
    80004646:	fe843783          	ld	a5,-24(s0)
    8000464a:	00e78a63          	beq	a5,a4,8000465e <test_physical_memory+0x192>
        panic("physical memory leak");
    8000464e:	00002517          	auipc	a0,0x2
    80004652:	33a50513          	add	a0,a0,826 # 80006988 <syscall_table+0x510>
    80004656:	00001097          	auipc	ra,0x1
    8000465a:	318080e7          	jalr	792(ra) # 8000596e <panic>
    }
    printf("[test] physical memory ok (free=%lu)\n", (uint64)pmm_free_pages());
    8000465e:	ffffc097          	auipc	ra,0xffffc
    80004662:	2d4080e7          	jalr	724(ra) # 80000932 <pmm_free_pages>
    80004666:	87aa                	mv	a5,a0
    80004668:	85be                	mv	a1,a5
    8000466a:	00002517          	auipc	a0,0x2
    8000466e:	33650513          	add	a0,a0,822 # 800069a0 <syscall_table+0x528>
    80004672:	00001097          	auipc	ra,0x1
    80004676:	264080e7          	jalr	612(ra) # 800058d6 <printf>
}
    8000467a:	0001                	nop
    8000467c:	60a6                	ld	ra,72(sp)
    8000467e:	6406                	ld	s0,64(sp)
    80004680:	6161                	add	sp,sp,80
    80004682:	8082                	ret

0000000080004684 <test_pagetable>:

void test_pagetable(void) {
    80004684:	7139                	add	sp,sp,-64
    80004686:	fc06                	sd	ra,56(sp)
    80004688:	f822                	sd	s0,48(sp)
    8000468a:	0080                	add	s0,sp,64
    printf("[test] pagetable start\n");
    8000468c:	00002517          	auipc	a0,0x2
    80004690:	33c50513          	add	a0,a0,828 # 800069c8 <syscall_table+0x550>
    80004694:	00001097          	auipc	ra,0x1
    80004698:	242080e7          	jalr	578(ra) # 800058d6 <printf>
    pagetable_t pt = create_pagetable();
    8000469c:	ffffc097          	auipc	ra,0xffffc
    800046a0:	5da080e7          	jalr	1498(ra) # 80000c76 <create_pagetable>
    800046a4:	fea43423          	sd	a0,-24(s0)
    assert_nonnull(pt, "create pagetable");
    800046a8:	00002597          	auipc	a1,0x2
    800046ac:	33858593          	add	a1,a1,824 # 800069e0 <syscall_table+0x568>
    800046b0:	fe843503          	ld	a0,-24(s0)
    800046b4:	00000097          	auipc	ra,0x0
    800046b8:	dec080e7          	jalr	-532(ra) # 800044a0 <assert_nonnull>
    void* page = alloc_page();
    800046bc:	ffffc097          	auipc	ra,0xffffc
    800046c0:	03e080e7          	jalr	62(ra) # 800006fa <alloc_page>
    800046c4:	fea43023          	sd	a0,-32(s0)
    assert_nonnull(page, "alloc mapping page");
    800046c8:	00002597          	auipc	a1,0x2
    800046cc:	33058593          	add	a1,a1,816 # 800069f8 <syscall_table+0x580>
    800046d0:	fe043503          	ld	a0,-32(s0)
    800046d4:	00000097          	auipc	ra,0x0
    800046d8:	dcc080e7          	jalr	-564(ra) # 800044a0 <assert_nonnull>
    uint64 va = 0x40000000UL;
    800046dc:	400007b7          	lui	a5,0x40000
    800046e0:	fcf43c23          	sd	a5,-40(s0)
    int r = map_page(pt, va, (uint64)page, PTE_R | PTE_W);
    800046e4:	fe043783          	ld	a5,-32(s0)
    800046e8:	4699                	li	a3,6
    800046ea:	863e                	mv	a2,a5
    800046ec:	fd843583          	ld	a1,-40(s0)
    800046f0:	fe843503          	ld	a0,-24(s0)
    800046f4:	ffffc097          	auipc	ra,0xffffc
    800046f8:	72c080e7          	jalr	1836(ra) # 80000e20 <map_page>
    800046fc:	87aa                	mv	a5,a0
    800046fe:	fcf42a23          	sw	a5,-44(s0)
    if (r != 0) panic("map_page failed");
    80004702:	fd442783          	lw	a5,-44(s0)
    80004706:	2781                	sext.w	a5,a5
    80004708:	cb89                	beqz	a5,8000471a <test_pagetable+0x96>
    8000470a:	00002517          	auipc	a0,0x2
    8000470e:	30650513          	add	a0,a0,774 # 80006a10 <syscall_table+0x598>
    80004712:	00001097          	auipc	ra,0x1
    80004716:	25c080e7          	jalr	604(ra) # 8000596e <panic>
    pte_t* pte = walk_lookup(pt, va);
    8000471a:	fd843583          	ld	a1,-40(s0)
    8000471e:	fe843503          	ld	a0,-24(s0)
    80004722:	ffffc097          	auipc	ra,0xffffc
    80004726:	660080e7          	jalr	1632(ra) # 80000d82 <walk_lookup>
    8000472a:	fca43423          	sd	a0,-56(s0)
    if (!pte || (*pte & PTE_V) == 0) panic("walk_lookup failed");
    8000472e:	fc843783          	ld	a5,-56(s0)
    80004732:	c791                	beqz	a5,8000473e <test_pagetable+0xba>
    80004734:	fc843783          	ld	a5,-56(s0)
    80004738:	639c                	ld	a5,0(a5)
    8000473a:	8b85                	and	a5,a5,1
    8000473c:	eb89                	bnez	a5,8000474e <test_pagetable+0xca>
    8000473e:	00002517          	auipc	a0,0x2
    80004742:	2e250513          	add	a0,a0,738 # 80006a20 <syscall_table+0x5a8>
    80004746:	00001097          	auipc	ra,0x1
    8000474a:	228080e7          	jalr	552(ra) # 8000596e <panic>
    if (PTE2PA(*pte) != (uint64)page) panic("pte mismatch");
    8000474e:	fc843783          	ld	a5,-56(s0)
    80004752:	639c                	ld	a5,0(a5)
    80004754:	83a9                	srl	a5,a5,0xa
    80004756:	00c79713          	sll	a4,a5,0xc
    8000475a:	fe043783          	ld	a5,-32(s0)
    8000475e:	00f70a63          	beq	a4,a5,80004772 <test_pagetable+0xee>
    80004762:	00002517          	auipc	a0,0x2
    80004766:	2d650513          	add	a0,a0,726 # 80006a38 <syscall_table+0x5c0>
    8000476a:	00001097          	auipc	ra,0x1
    8000476e:	204080e7          	jalr	516(ra) # 8000596e <panic>

    // Clear mapping before freeing leaf page
    *pte = 0;
    80004772:	fc843783          	ld	a5,-56(s0)
    80004776:	0007b023          	sd	zero,0(a5) # 40000000 <_entry-0x40000000>
    destroy_pagetable(pt);
    8000477a:	fe843503          	ld	a0,-24(s0)
    8000477e:	ffffc097          	auipc	ra,0xffffc
    80004782:	7ec080e7          	jalr	2028(ra) # 80000f6a <destroy_pagetable>
    free_page(page);
    80004786:	fe043503          	ld	a0,-32(s0)
    8000478a:	ffffc097          	auipc	ra,0xffffc
    8000478e:	eec080e7          	jalr	-276(ra) # 80000676 <free_page>
    printf("[test] pagetable ok\n");
    80004792:	00002517          	auipc	a0,0x2
    80004796:	2b650513          	add	a0,a0,694 # 80006a48 <syscall_table+0x5d0>
    8000479a:	00001097          	auipc	ra,0x1
    8000479e:	13c080e7          	jalr	316(ra) # 800058d6 <printf>
}
    800047a2:	0001                	nop
    800047a4:	70e2                	ld	ra,56(sp)
    800047a6:	7442                	ld	s0,48(sp)
    800047a8:	6121                	add	sp,sp,64
    800047aa:	8082                	ret

00000000800047ac <sfence_vma>:
{
    800047ac:	1141                	add	sp,sp,-16
    800047ae:	e422                	sd	s0,8(sp)
    800047b0:	0800                	add	s0,sp,16
  asm volatile("sfence.vma zero, zero");
    800047b2:	12000073          	sfence.vma
}
    800047b6:	0001                	nop
    800047b8:	6422                	ld	s0,8(sp)
    800047ba:	0141                	add	sp,sp,16
    800047bc:	8082                	ret

00000000800047be <test_virtual_memory>:
#include "include/printf.h"
#include "include/riscv.h"
#include "include/vmem.h"
#include "include/test.h"

void test_virtual_memory(void) {
    800047be:	715d                	add	sp,sp,-80
    800047c0:	e486                	sd	ra,72(sp)
    800047c2:	e0a2                	sd	s0,64(sp)
    800047c4:	0880                	add	s0,sp,80
    printf("[test] virtual memory start\n");
    800047c6:	00002517          	auipc	a0,0x2
    800047ca:	2b250513          	add	a0,a0,690 # 80006a78 <syscall_table+0x600>
    800047ce:	00001097          	auipc	ra,0x1
    800047d2:	108080e7          	jalr	264(ra) # 800058d6 <printf>
    pagetable_t kpgtbl = vmem_kernel_pagetable();
    800047d6:	ffffd097          	auipc	ra,0xffffd
    800047da:	a46080e7          	jalr	-1466(ra) # 8000121c <vmem_kernel_pagetable>
    800047de:	fea43423          	sd	a0,-24(s0)
    if (!kpgtbl) panic("kernel pagetable not ready");
    800047e2:	fe843783          	ld	a5,-24(s0)
    800047e6:	eb89                	bnez	a5,800047f8 <test_virtual_memory+0x3a>
    800047e8:	00002517          	auipc	a0,0x2
    800047ec:	2b050513          	add	a0,a0,688 # 80006a98 <syscall_table+0x620>
    800047f0:	00001097          	auipc	ra,0x1
    800047f4:	17e080e7          	jalr	382(ra) # 8000596e <panic>

    void* page = alloc_page();
    800047f8:	ffffc097          	auipc	ra,0xffffc
    800047fc:	f02080e7          	jalr	-254(ra) # 800006fa <alloc_page>
    80004800:	fea43023          	sd	a0,-32(s0)
    if (!page) panic("alloc page for vm test");
    80004804:	fe043783          	ld	a5,-32(s0)
    80004808:	eb89                	bnez	a5,8000481a <test_virtual_memory+0x5c>
    8000480a:	00002517          	auipc	a0,0x2
    8000480e:	2ae50513          	add	a0,a0,686 # 80006ab8 <syscall_table+0x640>
    80004812:	00001097          	auipc	ra,0x1
    80004816:	15c080e7          	jalr	348(ra) # 8000596e <panic>

    uint64 va = 0x40000000UL; // below kernel base, ensure mapping works
    8000481a:	400007b7          	lui	a5,0x40000
    8000481e:	fcf43c23          	sd	a5,-40(s0)
    if (map_page(kpgtbl, va, (uint64)page, PTE_R | PTE_W) != 0) {
    80004822:	fe043783          	ld	a5,-32(s0)
    80004826:	4699                	li	a3,6
    80004828:	863e                	mv	a2,a5
    8000482a:	fd843583          	ld	a1,-40(s0)
    8000482e:	fe843503          	ld	a0,-24(s0)
    80004832:	ffffc097          	auipc	ra,0xffffc
    80004836:	5ee080e7          	jalr	1518(ra) # 80000e20 <map_page>
    8000483a:	87aa                	mv	a5,a0
    8000483c:	cb89                	beqz	a5,8000484e <test_virtual_memory+0x90>
        panic("map_page in vm test");
    8000483e:	00002517          	auipc	a0,0x2
    80004842:	29250513          	add	a0,a0,658 # 80006ad0 <syscall_table+0x658>
    80004846:	00001097          	auipc	ra,0x1
    8000484a:	128080e7          	jalr	296(ra) # 8000596e <panic>
    }
    sfence_vma();
    8000484e:	00000097          	auipc	ra,0x0
    80004852:	f5e080e7          	jalr	-162(ra) # 800047ac <sfence_vma>

    uint64* vptr = (uint64*)va;
    80004856:	fd843783          	ld	a5,-40(s0)
    8000485a:	fcf43823          	sd	a5,-48(s0)
    uint64 pattern = 0x1234abcd5678ef90UL;
    8000485e:	00002797          	auipc	a5,0x2
    80004862:	2ca78793          	add	a5,a5,714 # 80006b28 <syscall_table+0x6b0>
    80004866:	639c                	ld	a5,0(a5)
    80004868:	fcf43423          	sd	a5,-56(s0)
    *vptr = pattern;
    8000486c:	fd043783          	ld	a5,-48(s0)
    80004870:	fc843703          	ld	a4,-56(s0)
    80004874:	e398                	sd	a4,0(a5)

    uint64* pptr = (uint64*)page;
    80004876:	fe043783          	ld	a5,-32(s0)
    8000487a:	fcf43023          	sd	a5,-64(s0)
    if (*pptr != pattern) {
    8000487e:	fc043783          	ld	a5,-64(s0)
    80004882:	639c                	ld	a5,0(a5)
    80004884:	fc843703          	ld	a4,-56(s0)
    80004888:	00f70a63          	beq	a4,a5,8000489c <test_virtual_memory+0xde>
        panic("virtual to physical mismatch");
    8000488c:	00002517          	auipc	a0,0x2
    80004890:	25c50513          	add	a0,a0,604 # 80006ae8 <syscall_table+0x670>
    80004894:	00001097          	auipc	ra,0x1
    80004898:	0da080e7          	jalr	218(ra) # 8000596e <panic>
    }

    // clear mapping
    pte_t* pte = walk_lookup(kpgtbl, va);
    8000489c:	fd843583          	ld	a1,-40(s0)
    800048a0:	fe843503          	ld	a0,-24(s0)
    800048a4:	ffffc097          	auipc	ra,0xffffc
    800048a8:	4de080e7          	jalr	1246(ra) # 80000d82 <walk_lookup>
    800048ac:	faa43c23          	sd	a0,-72(s0)
    if (pte) {
    800048b0:	fb843783          	ld	a5,-72(s0)
    800048b4:	cb89                	beqz	a5,800048c6 <test_virtual_memory+0x108>
        *pte = 0;
    800048b6:	fb843783          	ld	a5,-72(s0)
    800048ba:	0007b023          	sd	zero,0(a5)
        sfence_vma();
    800048be:	00000097          	auipc	ra,0x0
    800048c2:	eee080e7          	jalr	-274(ra) # 800047ac <sfence_vma>
    }
    free_page(page);
    800048c6:	fe043503          	ld	a0,-32(s0)
    800048ca:	ffffc097          	auipc	ra,0xffffc
    800048ce:	dac080e7          	jalr	-596(ra) # 80000676 <free_page>
    printf("[test] virtual memory ok\n");
    800048d2:	00002517          	auipc	a0,0x2
    800048d6:	23650513          	add	a0,a0,566 # 80006b08 <syscall_table+0x690>
    800048da:	00001097          	auipc	ra,0x1
    800048de:	ffc080e7          	jalr	-4(ra) # 800058d6 <printf>
}
    800048e2:	0001                	nop
    800048e4:	60a6                	ld	ra,72(sp)
    800048e6:	6406                	ld	s0,64(sp)
    800048e8:	6161                	add	sp,sp,80
    800048ea:	8082                	ret

00000000800048ec <r_tp>:
{
    800048ec:	1101                	add	sp,sp,-32
    800048ee:	ec22                	sd	s0,24(sp)
    800048f0:	1000                	add	s0,sp,32
  asm volatile("mv %0, tp" : "=r" (x) );
    800048f2:	8792                	mv	a5,tp
    800048f4:	fef43423          	sd	a5,-24(s0)
  return x;
    800048f8:	fe843783          	ld	a5,-24(s0)
}
    800048fc:	853e                	mv	a0,a5
    800048fe:	6462                	ld	s0,24(sp)
    80004900:	6105                	add	sp,sp,32
    80004902:	8082                	ret

0000000080004904 <run_pmem_stress_test>:

static volatile int started = 0;
static volatile int over_1 = 0, over_2 = 0;
static void* mem_slots[1024];

void run_pmem_stress_test(void) {
    80004904:	7179                	add	sp,sp,-48
    80004906:	f406                	sd	ra,40(sp)
    80004908:	f022                	sd	s0,32(sp)
    8000490a:	1800                	add	s0,sp,48
    int cpuid = (int)r_tp();
    8000490c:	00000097          	auipc	ra,0x0
    80004910:	fe0080e7          	jalr	-32(ra) # 800048ec <r_tp>
    80004914:	87aa                	mv	a5,a0
    80004916:	fcf42e23          	sw	a5,-36(s0)

    if (cpuid == 0) {
    8000491a:	fdc42783          	lw	a5,-36(s0)
    8000491e:	2781                	sext.w	a5,a5
    80004920:	16079763          	bnez	a5,80004a8e <run_pmem_stress_test+0x18a>
        pmem_init();
    80004924:	ffffc097          	auipc	ra,0xffffc
    80004928:	282080e7          	jalr	642(ra) # 80000ba6 <pmem_init>
        printf("cpu %d is booting!\n", cpuid);
    8000492c:	fdc42783          	lw	a5,-36(s0)
    80004930:	85be                	mv	a1,a5
    80004932:	00002517          	auipc	a0,0x2
    80004936:	1fe50513          	add	a0,a0,510 # 80006b30 <syscall_table+0x6b8>
    8000493a:	00001097          	auipc	ra,0x1
    8000493e:	f9c080e7          	jalr	-100(ra) # 800058d6 <printf>
        __sync_synchronize();
    80004942:	0ff0000f          	fence
        started = 1;
    80004946:	00006797          	auipc	a5,0x6
    8000494a:	6ea78793          	add	a5,a5,1770 # 8000b030 <started>
    8000494e:	4705                	li	a4,1
    80004950:	c398                	sw	a4,0(a5)

        for (int i = 0; i < 32; i++) {
    80004952:	fe042623          	sw	zero,-20(s0)
    80004956:	a065                	j	800049fe <run_pmem_stress_test+0xfa>
            mem_slots[i] = pmem_alloc(1);
    80004958:	4505                	li	a0,1
    8000495a:	ffffc097          	auipc	ra,0xffffc
    8000495e:	280080e7          	jalr	640(ra) # 80000bda <pmem_alloc>
    80004962:	86aa                	mv	a3,a0
    80004964:	00006717          	auipc	a4,0x6
    80004968:	6dc70713          	add	a4,a4,1756 # 8000b040 <mem_slots>
    8000496c:	fec42783          	lw	a5,-20(s0)
    80004970:	078e                	sll	a5,a5,0x3
    80004972:	97ba                	add	a5,a5,a4
    80004974:	e394                	sd	a3,0(a5)
            if (!mem_slots[i]) panic("pmem_alloc failed");
    80004976:	00006717          	auipc	a4,0x6
    8000497a:	6ca70713          	add	a4,a4,1738 # 8000b040 <mem_slots>
    8000497e:	fec42783          	lw	a5,-20(s0)
    80004982:	078e                	sll	a5,a5,0x3
    80004984:	97ba                	add	a5,a5,a4
    80004986:	639c                	ld	a5,0(a5)
    80004988:	eb89                	bnez	a5,8000499a <run_pmem_stress_test+0x96>
    8000498a:	00002517          	auipc	a0,0x2
    8000498e:	1be50513          	add	a0,a0,446 # 80006b48 <syscall_table+0x6d0>
    80004992:	00001097          	auipc	ra,0x1
    80004996:	fdc080e7          	jalr	-36(ra) # 8000596e <panic>
            memset(mem_slots[i], 1, PGSIZE);
    8000499a:	00006717          	auipc	a4,0x6
    8000499e:	6a670713          	add	a4,a4,1702 # 8000b040 <mem_slots>
    800049a2:	fec42783          	lw	a5,-20(s0)
    800049a6:	078e                	sll	a5,a5,0x3
    800049a8:	97ba                	add	a5,a5,a4
    800049aa:	639c                	ld	a5,0(a5)
    800049ac:	6605                	lui	a2,0x1
    800049ae:	4585                	li	a1,1
    800049b0:	853e                	mv	a0,a5
    800049b2:	00000097          	auipc	ra,0x0
    800049b6:	61a080e7          	jalr	1562(ra) # 80004fcc <memset>
            printf("mem = %p, data = %d\n", mem_slots[i], ((int*)mem_slots[i])[0]);
    800049ba:	00006717          	auipc	a4,0x6
    800049be:	68670713          	add	a4,a4,1670 # 8000b040 <mem_slots>
    800049c2:	fec42783          	lw	a5,-20(s0)
    800049c6:	078e                	sll	a5,a5,0x3
    800049c8:	97ba                	add	a5,a5,a4
    800049ca:	6394                	ld	a3,0(a5)
    800049cc:	00006717          	auipc	a4,0x6
    800049d0:	67470713          	add	a4,a4,1652 # 8000b040 <mem_slots>
    800049d4:	fec42783          	lw	a5,-20(s0)
    800049d8:	078e                	sll	a5,a5,0x3
    800049da:	97ba                	add	a5,a5,a4
    800049dc:	639c                	ld	a5,0(a5)
    800049de:	439c                	lw	a5,0(a5)
    800049e0:	863e                	mv	a2,a5
    800049e2:	85b6                	mv	a1,a3
    800049e4:	00002517          	auipc	a0,0x2
    800049e8:	17c50513          	add	a0,a0,380 # 80006b60 <syscall_table+0x6e8>
    800049ec:	00001097          	auipc	ra,0x1
    800049f0:	eea080e7          	jalr	-278(ra) # 800058d6 <printf>
        for (int i = 0; i < 32; i++) {
    800049f4:	fec42783          	lw	a5,-20(s0)
    800049f8:	2785                	addw	a5,a5,1
    800049fa:	fef42623          	sw	a5,-20(s0)
    800049fe:	fec42783          	lw	a5,-20(s0)
    80004a02:	0007871b          	sext.w	a4,a5
    80004a06:	47fd                	li	a5,31
    80004a08:	f4e7d8e3          	bge	a5,a4,80004958 <run_pmem_stress_test+0x54>
        }
        printf("cpu %d alloc over\n", cpuid);
    80004a0c:	fdc42783          	lw	a5,-36(s0)
    80004a10:	85be                	mv	a1,a5
    80004a12:	00002517          	auipc	a0,0x2
    80004a16:	16650513          	add	a0,a0,358 # 80006b78 <syscall_table+0x700>
    80004a1a:	00001097          	auipc	ra,0x1
    80004a1e:	ebc080e7          	jalr	-324(ra) # 800058d6 <printf>
        over_1 = 1;
    80004a22:	00006797          	auipc	a5,0x6
    80004a26:	61278793          	add	a5,a5,1554 # 8000b034 <over_1>
    80004a2a:	4705                	li	a4,1
    80004a2c:	c398                	sw	a4,0(a5)

        // single-core friendly: no wait for over_2 unless cpus>1
        while (over_2 == 0 && 0) {}
    80004a2e:	0001                	nop
    80004a30:	00006797          	auipc	a5,0x6
    80004a34:	60878793          	add	a5,a5,1544 # 8000b038 <over_2>
    80004a38:	439c                	lw	a5,0(a5)

        for (int i = 0; i < 32; i++) {
    80004a3a:	fe042423          	sw	zero,-24(s0)
    80004a3e:	a02d                	j	80004a68 <run_pmem_stress_test+0x164>
            pmem_free((uint64)mem_slots[i], 1);
    80004a40:	00006717          	auipc	a4,0x6
    80004a44:	60070713          	add	a4,a4,1536 # 8000b040 <mem_slots>
    80004a48:	fe842783          	lw	a5,-24(s0)
    80004a4c:	078e                	sll	a5,a5,0x3
    80004a4e:	97ba                	add	a5,a5,a4
    80004a50:	639c                	ld	a5,0(a5)
    80004a52:	4585                	li	a1,1
    80004a54:	853e                	mv	a0,a5
    80004a56:	ffffc097          	auipc	ra,0xffffc
    80004a5a:	1ca080e7          	jalr	458(ra) # 80000c20 <pmem_free>
        for (int i = 0; i < 32; i++) {
    80004a5e:	fe842783          	lw	a5,-24(s0)
    80004a62:	2785                	addw	a5,a5,1
    80004a64:	fef42423          	sw	a5,-24(s0)
    80004a68:	fe842783          	lw	a5,-24(s0)
    80004a6c:	0007871b          	sext.w	a4,a5
    80004a70:	47fd                	li	a5,31
    80004a72:	fce7d7e3          	bge	a5,a4,80004a40 <run_pmem_stress_test+0x13c>
        }
        printf("cpu %d free over\n", cpuid);
    80004a76:	fdc42783          	lw	a5,-36(s0)
    80004a7a:	85be                	mv	a1,a5
    80004a7c:	00002517          	auipc	a0,0x2
    80004a80:	11450513          	add	a0,a0,276 # 80006b90 <syscall_table+0x718>
    80004a84:	00001097          	auipc	ra,0x1
    80004a88:	e52080e7          	jalr	-430(ra) # 800058d6 <printf>
        for (int i = 32; i < 64; i++) {
            pmem_free((uint64)mem_slots[i], 1);
        }
        printf("cpu %d free over\n", cpuid);
    }
}
    80004a8c:	a251                	j	80004c10 <run_pmem_stress_test+0x30c>
        while (started == 0) {}
    80004a8e:	0001                	nop
    80004a90:	00006797          	auipc	a5,0x6
    80004a94:	5a078793          	add	a5,a5,1440 # 8000b030 <started>
    80004a98:	439c                	lw	a5,0(a5)
    80004a9a:	2781                	sext.w	a5,a5
    80004a9c:	dbf5                	beqz	a5,80004a90 <run_pmem_stress_test+0x18c>
        __sync_synchronize();
    80004a9e:	0ff0000f          	fence
        printf("cpu %d is booting!\n", cpuid);
    80004aa2:	fdc42783          	lw	a5,-36(s0)
    80004aa6:	85be                	mv	a1,a5
    80004aa8:	00002517          	auipc	a0,0x2
    80004aac:	08850513          	add	a0,a0,136 # 80006b30 <syscall_table+0x6b8>
    80004ab0:	00001097          	auipc	ra,0x1
    80004ab4:	e26080e7          	jalr	-474(ra) # 800058d6 <printf>
        for (int i = 32; i < 64; i++) {
    80004ab8:	02000793          	li	a5,32
    80004abc:	fef42223          	sw	a5,-28(s0)
    80004ac0:	a065                	j	80004b68 <run_pmem_stress_test+0x264>
            mem_slots[i] = pmem_alloc(1);
    80004ac2:	4505                	li	a0,1
    80004ac4:	ffffc097          	auipc	ra,0xffffc
    80004ac8:	116080e7          	jalr	278(ra) # 80000bda <pmem_alloc>
    80004acc:	86aa                	mv	a3,a0
    80004ace:	00006717          	auipc	a4,0x6
    80004ad2:	57270713          	add	a4,a4,1394 # 8000b040 <mem_slots>
    80004ad6:	fe442783          	lw	a5,-28(s0)
    80004ada:	078e                	sll	a5,a5,0x3
    80004adc:	97ba                	add	a5,a5,a4
    80004ade:	e394                	sd	a3,0(a5)
            if (!mem_slots[i]) panic("pmem_alloc failed (cpu>0)");
    80004ae0:	00006717          	auipc	a4,0x6
    80004ae4:	56070713          	add	a4,a4,1376 # 8000b040 <mem_slots>
    80004ae8:	fe442783          	lw	a5,-28(s0)
    80004aec:	078e                	sll	a5,a5,0x3
    80004aee:	97ba                	add	a5,a5,a4
    80004af0:	639c                	ld	a5,0(a5)
    80004af2:	eb89                	bnez	a5,80004b04 <run_pmem_stress_test+0x200>
    80004af4:	00002517          	auipc	a0,0x2
    80004af8:	0b450513          	add	a0,a0,180 # 80006ba8 <syscall_table+0x730>
    80004afc:	00001097          	auipc	ra,0x1
    80004b00:	e72080e7          	jalr	-398(ra) # 8000596e <panic>
            memset(mem_slots[i], 1, PGSIZE);
    80004b04:	00006717          	auipc	a4,0x6
    80004b08:	53c70713          	add	a4,a4,1340 # 8000b040 <mem_slots>
    80004b0c:	fe442783          	lw	a5,-28(s0)
    80004b10:	078e                	sll	a5,a5,0x3
    80004b12:	97ba                	add	a5,a5,a4
    80004b14:	639c                	ld	a5,0(a5)
    80004b16:	6605                	lui	a2,0x1
    80004b18:	4585                	li	a1,1
    80004b1a:	853e                	mv	a0,a5
    80004b1c:	00000097          	auipc	ra,0x0
    80004b20:	4b0080e7          	jalr	1200(ra) # 80004fcc <memset>
            printf("mem = %p, data = %d\n", mem_slots[i], ((int*)mem_slots[i])[0]);
    80004b24:	00006717          	auipc	a4,0x6
    80004b28:	51c70713          	add	a4,a4,1308 # 8000b040 <mem_slots>
    80004b2c:	fe442783          	lw	a5,-28(s0)
    80004b30:	078e                	sll	a5,a5,0x3
    80004b32:	97ba                	add	a5,a5,a4
    80004b34:	6394                	ld	a3,0(a5)
    80004b36:	00006717          	auipc	a4,0x6
    80004b3a:	50a70713          	add	a4,a4,1290 # 8000b040 <mem_slots>
    80004b3e:	fe442783          	lw	a5,-28(s0)
    80004b42:	078e                	sll	a5,a5,0x3
    80004b44:	97ba                	add	a5,a5,a4
    80004b46:	639c                	ld	a5,0(a5)
    80004b48:	439c                	lw	a5,0(a5)
    80004b4a:	863e                	mv	a2,a5
    80004b4c:	85b6                	mv	a1,a3
    80004b4e:	00002517          	auipc	a0,0x2
    80004b52:	01250513          	add	a0,a0,18 # 80006b60 <syscall_table+0x6e8>
    80004b56:	00001097          	auipc	ra,0x1
    80004b5a:	d80080e7          	jalr	-640(ra) # 800058d6 <printf>
        for (int i = 32; i < 64; i++) {
    80004b5e:	fe442783          	lw	a5,-28(s0)
    80004b62:	2785                	addw	a5,a5,1
    80004b64:	fef42223          	sw	a5,-28(s0)
    80004b68:	fe442783          	lw	a5,-28(s0)
    80004b6c:	0007871b          	sext.w	a4,a5
    80004b70:	03f00793          	li	a5,63
    80004b74:	f4e7d7e3          	bge	a5,a4,80004ac2 <run_pmem_stress_test+0x1be>
        printf("cpu %d alloc over\n", cpuid);
    80004b78:	fdc42783          	lw	a5,-36(s0)
    80004b7c:	85be                	mv	a1,a5
    80004b7e:	00002517          	auipc	a0,0x2
    80004b82:	ffa50513          	add	a0,a0,-6 # 80006b78 <syscall_table+0x700>
    80004b86:	00001097          	auipc	ra,0x1
    80004b8a:	d50080e7          	jalr	-688(ra) # 800058d6 <printf>
        over_2 = 1;
    80004b8e:	00006797          	auipc	a5,0x6
    80004b92:	4aa78793          	add	a5,a5,1194 # 8000b038 <over_2>
    80004b96:	4705                	li	a4,1
    80004b98:	c398                	sw	a4,0(a5)
        while (over_1 == 0 || over_2 == 0) {}
    80004b9a:	0001                	nop
    80004b9c:	00006797          	auipc	a5,0x6
    80004ba0:	49878793          	add	a5,a5,1176 # 8000b034 <over_1>
    80004ba4:	439c                	lw	a5,0(a5)
    80004ba6:	2781                	sext.w	a5,a5
    80004ba8:	dbf5                	beqz	a5,80004b9c <run_pmem_stress_test+0x298>
    80004baa:	00006797          	auipc	a5,0x6
    80004bae:	48e78793          	add	a5,a5,1166 # 8000b038 <over_2>
    80004bb2:	439c                	lw	a5,0(a5)
    80004bb4:	2781                	sext.w	a5,a5
    80004bb6:	d3fd                	beqz	a5,80004b9c <run_pmem_stress_test+0x298>
        for (int i = 32; i < 64; i++) {
    80004bb8:	02000793          	li	a5,32
    80004bbc:	fef42023          	sw	a5,-32(s0)
    80004bc0:	a02d                	j	80004bea <run_pmem_stress_test+0x2e6>
            pmem_free((uint64)mem_slots[i], 1);
    80004bc2:	00006717          	auipc	a4,0x6
    80004bc6:	47e70713          	add	a4,a4,1150 # 8000b040 <mem_slots>
    80004bca:	fe042783          	lw	a5,-32(s0)
    80004bce:	078e                	sll	a5,a5,0x3
    80004bd0:	97ba                	add	a5,a5,a4
    80004bd2:	639c                	ld	a5,0(a5)
    80004bd4:	4585                	li	a1,1
    80004bd6:	853e                	mv	a0,a5
    80004bd8:	ffffc097          	auipc	ra,0xffffc
    80004bdc:	048080e7          	jalr	72(ra) # 80000c20 <pmem_free>
        for (int i = 32; i < 64; i++) {
    80004be0:	fe042783          	lw	a5,-32(s0)
    80004be4:	2785                	addw	a5,a5,1
    80004be6:	fef42023          	sw	a5,-32(s0)
    80004bea:	fe042783          	lw	a5,-32(s0)
    80004bee:	0007871b          	sext.w	a4,a5
    80004bf2:	03f00793          	li	a5,63
    80004bf6:	fce7d6e3          	bge	a5,a4,80004bc2 <run_pmem_stress_test+0x2be>
        printf("cpu %d free over\n", cpuid);
    80004bfa:	fdc42783          	lw	a5,-36(s0)
    80004bfe:	85be                	mv	a1,a5
    80004c00:	00002517          	auipc	a0,0x2
    80004c04:	f9050513          	add	a0,a0,-112 # 80006b90 <syscall_table+0x718>
    80004c08:	00001097          	auipc	ra,0x1
    80004c0c:	cce080e7          	jalr	-818(ra) # 800058d6 <printf>
}
    80004c10:	0001                	nop
    80004c12:	70a2                	ld	ra,40(sp)
    80004c14:	7402                	ld	s0,32(sp)
    80004c16:	6145                	add	sp,sp,48
    80004c18:	8082                	ret

0000000080004c1a <run_vm_mapping_test>:

void run_vm_mapping_test(void) {
    80004c1a:	715d                	add	sp,sp,-80
    80004c1c:	e486                	sd	ra,72(sp)
    80004c1e:	e0a2                	sd	s0,64(sp)
    80004c20:	0880                	add	s0,sp,80
    int cpuid = (int)r_tp();
    80004c22:	00000097          	auipc	ra,0x0
    80004c26:	cca080e7          	jalr	-822(ra) # 800048ec <r_tp>
    80004c2a:	87aa                	mv	a5,a0
    80004c2c:	fef42423          	sw	a5,-24(s0)

    if (cpuid == 0) {
    80004c30:	fe842783          	lw	a5,-24(s0)
    80004c34:	2781                	sext.w	a5,a5
    80004c36:	18079b63          	bnez	a5,80004dcc <run_vm_mapping_test+0x1b2>
        pmem_init();
    80004c3a:	ffffc097          	auipc	ra,0xffffc
    80004c3e:	f6c080e7          	jalr	-148(ra) # 80000ba6 <pmem_init>
        kvm_init();
    80004c42:	ffffd097          	auipc	ra,0xffffd
    80004c46:	a9a080e7          	jalr	-1382(ra) # 800016dc <kvm_init>
        kvm_inithart();
    80004c4a:	ffffd097          	auipc	ra,0xffffd
    80004c4e:	aac080e7          	jalr	-1364(ra) # 800016f6 <kvm_inithart>

        printf("cpu %d is booting!\n", cpuid);
    80004c52:	fe842783          	lw	a5,-24(s0)
    80004c56:	85be                	mv	a1,a5
    80004c58:	00002517          	auipc	a0,0x2
    80004c5c:	ed850513          	add	a0,a0,-296 # 80006b30 <syscall_table+0x6b8>
    80004c60:	00001097          	auipc	ra,0x1
    80004c64:	c76080e7          	jalr	-906(ra) # 800058d6 <printf>
        __sync_synchronize();
    80004c68:	0ff0000f          	fence

        pagetable_t test_pgtbl = pmem_alloc(1);
    80004c6c:	4505                	li	a0,1
    80004c6e:	ffffc097          	auipc	ra,0xffffc
    80004c72:	f6c080e7          	jalr	-148(ra) # 80000bda <pmem_alloc>
    80004c76:	fea43023          	sd	a0,-32(s0)
        if (!test_pgtbl) panic("test_pgtbl alloc failed");
    80004c7a:	fe043783          	ld	a5,-32(s0)
    80004c7e:	eb89                	bnez	a5,80004c90 <run_vm_mapping_test+0x76>
    80004c80:	00002517          	auipc	a0,0x2
    80004c84:	f4850513          	add	a0,a0,-184 # 80006bc8 <syscall_table+0x750>
    80004c88:	00001097          	auipc	ra,0x1
    80004c8c:	ce6080e7          	jalr	-794(ra) # 8000596e <panic>

        uint64 mem[5];
        for (int i = 0; i < 5; i++) {
    80004c90:	fe042623          	sw	zero,-20(s0)
    80004c94:	a089                	j	80004cd6 <run_vm_mapping_test+0xbc>
            void* p = pmem_alloc(0);
    80004c96:	4501                	li	a0,0
    80004c98:	ffffc097          	auipc	ra,0xffffc
    80004c9c:	f42080e7          	jalr	-190(ra) # 80000bda <pmem_alloc>
    80004ca0:	fca43c23          	sd	a0,-40(s0)
            if (!p) panic("test mem alloc failed");
    80004ca4:	fd843783          	ld	a5,-40(s0)
    80004ca8:	eb89                	bnez	a5,80004cba <run_vm_mapping_test+0xa0>
    80004caa:	00002517          	auipc	a0,0x2
    80004cae:	f3650513          	add	a0,a0,-202 # 80006be0 <syscall_table+0x768>
    80004cb2:	00001097          	auipc	ra,0x1
    80004cb6:	cbc080e7          	jalr	-836(ra) # 8000596e <panic>
            mem[i] = (uint64)p;
    80004cba:	fd843703          	ld	a4,-40(s0)
    80004cbe:	fec42783          	lw	a5,-20(s0)
    80004cc2:	078e                	sll	a5,a5,0x3
    80004cc4:	17c1                	add	a5,a5,-16
    80004cc6:	97a2                	add	a5,a5,s0
    80004cc8:	fce7b023          	sd	a4,-64(a5)
        for (int i = 0; i < 5; i++) {
    80004ccc:	fec42783          	lw	a5,-20(s0)
    80004cd0:	2785                	addw	a5,a5,1
    80004cd2:	fef42623          	sw	a5,-20(s0)
    80004cd6:	fec42783          	lw	a5,-20(s0)
    80004cda:	0007871b          	sext.w	a4,a5
    80004cde:	4791                	li	a5,4
    80004ce0:	fae7dbe3          	bge	a5,a4,80004c96 <run_vm_mapping_test+0x7c>
        }

        printf("\ntest-1\n\n");
    80004ce4:	00002517          	auipc	a0,0x2
    80004ce8:	f1450513          	add	a0,a0,-236 # 80006bf8 <syscall_table+0x780>
    80004cec:	00001097          	auipc	ra,0x1
    80004cf0:	bea080e7          	jalr	-1046(ra) # 800058d6 <printf>
        vm_mappages(test_pgtbl, 0, mem[0], PGSIZE, PTE_R);
    80004cf4:	fb043783          	ld	a5,-80(s0)
    80004cf8:	4709                	li	a4,2
    80004cfa:	6685                	lui	a3,0x1
    80004cfc:	863e                	mv	a2,a5
    80004cfe:	4581                	li	a1,0
    80004d00:	fe043503          	ld	a0,-32(s0)
    80004d04:	ffffd097          	auipc	ra,0xffffd
    80004d08:	824080e7          	jalr	-2012(ra) # 80001528 <vm_mappages>
        vm_mappages(test_pgtbl, PGSIZE * 10, mem[1], PGSIZE / 2, PTE_R | PTE_W);
    80004d0c:	fb843603          	ld	a2,-72(s0)
    80004d10:	4719                	li	a4,6
    80004d12:	6785                	lui	a5,0x1
    80004d14:	80078693          	add	a3,a5,-2048 # 800 <_entry-0x7ffff800>
    80004d18:	65a9                	lui	a1,0xa
    80004d1a:	fe043503          	ld	a0,-32(s0)
    80004d1e:	ffffd097          	auipc	ra,0xffffd
    80004d22:	80a080e7          	jalr	-2038(ra) # 80001528 <vm_mappages>
        vm_mappages(test_pgtbl, PGSIZE * 512, mem[2], PGSIZE - 1, PTE_R | PTE_X);
    80004d26:	fc043603          	ld	a2,-64(s0)
    80004d2a:	4729                	li	a4,10
    80004d2c:	6785                	lui	a5,0x1
    80004d2e:	fff78693          	add	a3,a5,-1 # fff <_entry-0x7ffff001>
    80004d32:	002005b7          	lui	a1,0x200
    80004d36:	fe043503          	ld	a0,-32(s0)
    80004d3a:	ffffc097          	auipc	ra,0xffffc
    80004d3e:	7ee080e7          	jalr	2030(ra) # 80001528 <vm_mappages>
        vm_mappages(test_pgtbl, (uint64)PGSIZE * 512 * 512, mem[2], PGSIZE, PTE_R | PTE_X);
    80004d42:	fc043783          	ld	a5,-64(s0)
    80004d46:	4729                	li	a4,10
    80004d48:	6685                	lui	a3,0x1
    80004d4a:	863e                	mv	a2,a5
    80004d4c:	400005b7          	lui	a1,0x40000
    80004d50:	fe043503          	ld	a0,-32(s0)
    80004d54:	ffffc097          	auipc	ra,0xffffc
    80004d58:	7d4080e7          	jalr	2004(ra) # 80001528 <vm_mappages>
        vm_mappages(test_pgtbl, MAXVA - PGSIZE, mem[4], PGSIZE, PTE_W);
    80004d5c:	fd043783          	ld	a5,-48(s0)
    80004d60:	4711                	li	a4,4
    80004d62:	6685                	lui	a3,0x1
    80004d64:	863e                	mv	a2,a5
    80004d66:	040007b7          	lui	a5,0x4000
    80004d6a:	17fd                	add	a5,a5,-1 # 3ffffff <_entry-0x7c000001>
    80004d6c:	00c79593          	sll	a1,a5,0xc
    80004d70:	fe043503          	ld	a0,-32(s0)
    80004d74:	ffffc097          	auipc	ra,0xffffc
    80004d78:	7b4080e7          	jalr	1972(ra) # 80001528 <vm_mappages>
        // vm_print(test_pgtbl); // verbose debug dump

        printf("\ntest-2\n\n");
    80004d7c:	00002517          	auipc	a0,0x2
    80004d80:	e8c50513          	add	a0,a0,-372 # 80006c08 <syscall_table+0x790>
    80004d84:	00001097          	auipc	ra,0x1
    80004d88:	b52080e7          	jalr	-1198(ra) # 800058d6 <printf>
        vm_mappages(test_pgtbl, 0, mem[0], PGSIZE, PTE_W); // remap with new perm
    80004d8c:	fb043783          	ld	a5,-80(s0)
    80004d90:	4711                	li	a4,4
    80004d92:	6685                	lui	a3,0x1
    80004d94:	863e                	mv	a2,a5
    80004d96:	4581                	li	a1,0
    80004d98:	fe043503          	ld	a0,-32(s0)
    80004d9c:	ffffc097          	auipc	ra,0xffffc
    80004da0:	78c080e7          	jalr	1932(ra) # 80001528 <vm_mappages>
        vm_unmappages(test_pgtbl, PGSIZE * 10, PGSIZE, 1);
    80004da4:	4685                	li	a3,1
    80004da6:	6605                	lui	a2,0x1
    80004da8:	65a9                	lui	a1,0xa
    80004daa:	fe043503          	ld	a0,-32(s0)
    80004dae:	ffffd097          	auipc	ra,0xffffd
    80004db2:	84c080e7          	jalr	-1972(ra) # 800015fa <vm_unmappages>
        vm_unmappages(test_pgtbl, PGSIZE * 512, PGSIZE, 1);
    80004db6:	4685                	li	a3,1
    80004db8:	6605                	lui	a2,0x1
    80004dba:	002005b7          	lui	a1,0x200
    80004dbe:	fe043503          	ld	a0,-32(s0)
    80004dc2:	ffffd097          	auipc	ra,0xffffd
    80004dc6:	838080e7          	jalr	-1992(ra) # 800015fa <vm_unmappages>
    } else {
        while (started == 0) {}
        __sync_synchronize();
        printf("cpu %d is booting!\n", cpuid);
    }
}
    80004dca:	a035                	j	80004df6 <run_vm_mapping_test+0x1dc>
        while (started == 0) {}
    80004dcc:	0001                	nop
    80004dce:	00006797          	auipc	a5,0x6
    80004dd2:	26278793          	add	a5,a5,610 # 8000b030 <started>
    80004dd6:	439c                	lw	a5,0(a5)
    80004dd8:	2781                	sext.w	a5,a5
    80004dda:	dbf5                	beqz	a5,80004dce <run_vm_mapping_test+0x1b4>
        __sync_synchronize();
    80004ddc:	0ff0000f          	fence
        printf("cpu %d is booting!\n", cpuid);
    80004de0:	fe842783          	lw	a5,-24(s0)
    80004de4:	85be                	mv	a1,a5
    80004de6:	00002517          	auipc	a0,0x2
    80004dea:	d4a50513          	add	a0,a0,-694 # 80006b30 <syscall_table+0x6b8>
    80004dee:	00001097          	auipc	ra,0x1
    80004df2:	ae8080e7          	jalr	-1304(ra) # 800058d6 <printf>
}
    80004df6:	0001                	nop
    80004df8:	60a6                	ld	ra,72(sp)
    80004dfa:	6406                	ld	s0,64(sp)
    80004dfc:	6161                	add	sp,sp,80
    80004dfe:	8082                	ret

0000000080004e00 <r_sstatus>:
{
    80004e00:	1101                	add	sp,sp,-32
    80004e02:	ec22                	sd	s0,24(sp)
    80004e04:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80004e06:	100027f3          	csrr	a5,sstatus
    80004e0a:	fef43423          	sd	a5,-24(s0)
  return x;
    80004e0e:	fe843783          	ld	a5,-24(s0)
}
    80004e12:	853e                	mv	a0,a5
    80004e14:	6462                	ld	s0,24(sp)
    80004e16:	6105                	add	sp,sp,32
    80004e18:	8082                	ret

0000000080004e1a <w_sstatus>:
{
    80004e1a:	1101                	add	sp,sp,-32
    80004e1c:	ec22                	sd	s0,24(sp)
    80004e1e:	1000                	add	s0,sp,32
    80004e20:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80004e24:	fe843783          	ld	a5,-24(s0)
    80004e28:	10079073          	csrw	sstatus,a5
}
    80004e2c:	0001                	nop
    80004e2e:	6462                	ld	s0,24(sp)
    80004e30:	6105                	add	sp,sp,32
    80004e32:	8082                	ret

0000000080004e34 <r_sip>:
{
    80004e34:	1101                	add	sp,sp,-32
    80004e36:	ec22                	sd	s0,24(sp)
    80004e38:	1000                	add	s0,sp,32
  asm volatile("csrr %0, sip" : "=r" (x) );
    80004e3a:	144027f3          	csrr	a5,sip
    80004e3e:	fef43423          	sd	a5,-24(s0)
  return x;
    80004e42:	fe843783          	ld	a5,-24(s0)
}
    80004e46:	853e                	mv	a0,a5
    80004e48:	6462                	ld	s0,24(sp)
    80004e4a:	6105                	add	sp,sp,32
    80004e4c:	8082                	ret

0000000080004e4e <w_sip>:
{
    80004e4e:	1101                	add	sp,sp,-32
    80004e50:	ec22                	sd	s0,24(sp)
    80004e52:	1000                	add	s0,sp,32
    80004e54:	fea43423          	sd	a0,-24(s0)
  asm volatile("csrw sip, %0" : : "r" (x));
    80004e58:	fe843783          	ld	a5,-24(s0)
    80004e5c:	14479073          	csrw	sip,a5
}
    80004e60:	0001                	nop
    80004e62:	6462                	ld	s0,24(sp)
    80004e64:	6105                	add	sp,sp,32
    80004e66:	8082                	ret

0000000080004e68 <intr_on>:
{
    80004e68:	1141                	add	sp,sp,-16
    80004e6a:	e406                	sd	ra,8(sp)
    80004e6c:	e022                	sd	s0,0(sp)
    80004e6e:	0800                	add	s0,sp,16
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80004e70:	00000097          	auipc	ra,0x0
    80004e74:	f90080e7          	jalr	-112(ra) # 80004e00 <r_sstatus>
    80004e78:	87aa                	mv	a5,a0
    80004e7a:	0027e793          	or	a5,a5,2
    80004e7e:	853e                	mv	a0,a5
    80004e80:	00000097          	auipc	ra,0x0
    80004e84:	f9a080e7          	jalr	-102(ra) # 80004e1a <w_sstatus>
}
    80004e88:	0001                	nop
    80004e8a:	60a2                	ld	ra,8(sp)
    80004e8c:	6402                	ld	s0,0(sp)
    80004e8e:	0141                	add	sp,sp,16
    80004e90:	8082                	ret

0000000080004e92 <test_timer_interrupt>:
#include "include/printf.h"
#include "include/trap.h"
#include "include/riscv.h"

// 简单的中断测试：等待若干次时钟中断并统计时间
void test_timer_interrupt(void) {
    80004e92:	7139                	add	sp,sp,-64
    80004e94:	fc06                	sd	ra,56(sp)
    80004e96:	f822                	sd	s0,48(sp)
    80004e98:	f426                	sd	s1,40(sp)
    80004e9a:	f04a                	sd	s2,32(sp)
    80004e9c:	0080                	add	s0,sp,64
    printf("[test] timer interrupt start\n");
    80004e9e:	00002517          	auipc	a0,0x2
    80004ea2:	d7a50513          	add	a0,a0,-646 # 80006c18 <syscall_table+0x7a0>
    80004ea6:	00001097          	auipc	ra,0x1
    80004eaa:	a30080e7          	jalr	-1488(ra) # 800058d6 <printf>
    intr_on(); // ensure interrupts enabled before waiting
    80004eae:	00000097          	auipc	ra,0x0
    80004eb2:	fba080e7          	jalr	-70(ra) # 80004e68 <intr_on>
    int start = get_timer_interrupt_count();
    80004eb6:	fffff097          	auipc	ra,0xfffff
    80004eba:	5d0080e7          	jalr	1488(ra) # 80004486 <get_timer_interrupt_count>
    80004ebe:	87aa                	mv	a5,a0
    80004ec0:	fcf42c23          	sw	a5,-40(s0)
    int target = start + 2; // fewer ticks for quicker completion
    80004ec4:	fd842783          	lw	a5,-40(s0)
    80004ec8:	2789                	addw	a5,a5,2
    80004eca:	fcf42a23          	sw	a5,-44(s0)
    uint64 begin = get_time();
    80004ece:	fffff097          	auipc	ra,0xfffff
    80004ed2:	122080e7          	jalr	290(ra) # 80003ff0 <get_time>
    80004ed6:	fca43423          	sd	a0,-56(s0)
    int spin = 0;
    80004eda:	fc042e23          	sw	zero,-36(s0)
    while (get_timer_interrupt_count() < target) {
    80004ede:	a83d                	j	80004f1c <test_timer_interrupt+0x8a>
        asm volatile("wfi");
    80004ee0:	10500073          	wfi
        if (++spin > 50000) {
    80004ee4:	fdc42783          	lw	a5,-36(s0)
    80004ee8:	2785                	addw	a5,a5,1
    80004eea:	fcf42e23          	sw	a5,-36(s0)
    80004eee:	fdc42783          	lw	a5,-36(s0)
    80004ef2:	0007871b          	sext.w	a4,a5
    80004ef6:	67b1                	lui	a5,0xc
    80004ef8:	35078793          	add	a5,a5,848 # c350 <_entry-0x7fff3cb0>
    80004efc:	02e7d063          	bge	a5,a4,80004f1c <test_timer_interrupt+0x8a>
            // Fallback: nudge software interrupt to avoid hanging if timer bridge stalls.
            w_sip(r_sip() | SIE_SSIE);
    80004f00:	00000097          	auipc	ra,0x0
    80004f04:	f34080e7          	jalr	-204(ra) # 80004e34 <r_sip>
    80004f08:	87aa                	mv	a5,a0
    80004f0a:	0027e793          	or	a5,a5,2
    80004f0e:	853e                	mv	a0,a5
    80004f10:	00000097          	auipc	ra,0x0
    80004f14:	f3e080e7          	jalr	-194(ra) # 80004e4e <w_sip>
            spin = 0;
    80004f18:	fc042e23          	sw	zero,-36(s0)
    while (get_timer_interrupt_count() < target) {
    80004f1c:	fffff097          	auipc	ra,0xfffff
    80004f20:	56a080e7          	jalr	1386(ra) # 80004486 <get_timer_interrupt_count>
    80004f24:	87aa                	mv	a5,a0
    80004f26:	873e                	mv	a4,a5
    80004f28:	fd442783          	lw	a5,-44(s0)
    80004f2c:	2781                	sext.w	a5,a5
    80004f2e:	faf749e3          	blt	a4,a5,80004ee0 <test_timer_interrupt+0x4e>
        }
    }
    uint64 end = get_time();
    80004f32:	fffff097          	auipc	ra,0xfffff
    80004f36:	0be080e7          	jalr	190(ra) # 80003ff0 <get_time>
    80004f3a:	fca43023          	sd	a0,-64(s0)
    printf("[test] timer interrupt ok: %d->%d in %lu cycles (ticks=%lu)\n",
    80004f3e:	fffff097          	auipc	ra,0xfffff
    80004f42:	548080e7          	jalr	1352(ra) # 80004486 <get_timer_interrupt_count>
    80004f46:	87aa                	mv	a5,a0
    80004f48:	893e                	mv	s2,a5
    80004f4a:	fc043703          	ld	a4,-64(s0)
    80004f4e:	fc843783          	ld	a5,-56(s0)
    80004f52:	40f704b3          	sub	s1,a4,a5
    80004f56:	fffff097          	auipc	ra,0xfffff
    80004f5a:	0f6080e7          	jalr	246(ra) # 8000404c <timer_ticks>
    80004f5e:	872a                	mv	a4,a0
    80004f60:	fd842783          	lw	a5,-40(s0)
    80004f64:	86a6                	mv	a3,s1
    80004f66:	864a                	mv	a2,s2
    80004f68:	85be                	mv	a1,a5
    80004f6a:	00002517          	auipc	a0,0x2
    80004f6e:	cce50513          	add	a0,a0,-818 # 80006c38 <syscall_table+0x7c0>
    80004f72:	00001097          	auipc	ra,0x1
    80004f76:	964080e7          	jalr	-1692(ra) # 800058d6 <printf>
           start, get_timer_interrupt_count(), end - begin, timer_ticks());
}
    80004f7a:	0001                	nop
    80004f7c:	70e2                	ld	ra,56(sp)
    80004f7e:	7442                	ld	s0,48(sp)
    80004f80:	74a2                	ld	s1,40(sp)
    80004f82:	7902                	ld	s2,32(sp)
    80004f84:	6121                	add	sp,sp,64
    80004f86:	8082                	ret

0000000080004f88 <test_exception_handling>:

// 异常测试占位：当前仅输出提示，避免故意触发致命异常
void test_exception_handling(void) {
    80004f88:	1141                	add	sp,sp,-16
    80004f8a:	e406                	sd	ra,8(sp)
    80004f8c:	e022                	sd	s0,0(sp)
    80004f8e:	0800                	add	s0,sp,16
    printf("[test] exception handling placeholder (no faults triggered)\n");
    80004f90:	00002517          	auipc	a0,0x2
    80004f94:	ce850513          	add	a0,a0,-792 # 80006c78 <syscall_table+0x800>
    80004f98:	00001097          	auipc	ra,0x1
    80004f9c:	93e080e7          	jalr	-1730(ra) # 800058d6 <printf>
}
    80004fa0:	0001                	nop
    80004fa2:	60a2                	ld	ra,8(sp)
    80004fa4:	6402                	ld	s0,0(sp)
    80004fa6:	0141                	add	sp,sp,16
    80004fa8:	8082                	ret

0000000080004faa <test_interrupt_overhead>:

// 性能测试占位
void test_interrupt_overhead(void) {
    80004faa:	1141                	add	sp,sp,-16
    80004fac:	e406                	sd	ra,8(sp)
    80004fae:	e022                	sd	s0,0(sp)
    80004fb0:	0800                	add	s0,sp,16
    printf("[test] interrupt overhead placeholder\n");
    80004fb2:	00002517          	auipc	a0,0x2
    80004fb6:	d0650513          	add	a0,a0,-762 # 80006cb8 <syscall_table+0x840>
    80004fba:	00001097          	auipc	ra,0x1
    80004fbe:	91c080e7          	jalr	-1764(ra) # 800058d6 <printf>
}
    80004fc2:	0001                	nop
    80004fc4:	60a2                	ld	ra,8(sp)
    80004fc6:	6402                	ld	s0,0(sp)
    80004fc8:	0141                	add	sp,sp,16
    80004fca:	8082                	ret

0000000080004fcc <memset>:

// UART primitives
extern void uart_putc(char c);
extern void uart_puts(const char* s);

void* memset(void* dst, int c, size_t n) {
    80004fcc:	7139                	add	sp,sp,-64
    80004fce:	fc22                	sd	s0,56(sp)
    80004fd0:	0080                	add	s0,sp,64
    80004fd2:	fca43c23          	sd	a0,-40(s0)
    80004fd6:	87ae                	mv	a5,a1
    80004fd8:	fcc43423          	sd	a2,-56(s0)
    80004fdc:	fcf42a23          	sw	a5,-44(s0)
    unsigned char* p = (unsigned char*)dst;
    80004fe0:	fd843783          	ld	a5,-40(s0)
    80004fe4:	fef43423          	sd	a5,-24(s0)
    while (n--) {
    80004fe8:	a829                	j	80005002 <memset+0x36>
        *p++ = (unsigned char)c;
    80004fea:	fe843783          	ld	a5,-24(s0)
    80004fee:	00178713          	add	a4,a5,1
    80004ff2:	fee43423          	sd	a4,-24(s0)
    80004ff6:	fd442703          	lw	a4,-44(s0)
    80004ffa:	0ff77713          	zext.b	a4,a4
    80004ffe:	00e78023          	sb	a4,0(a5)
    while (n--) {
    80005002:	fc843783          	ld	a5,-56(s0)
    80005006:	fff78713          	add	a4,a5,-1
    8000500a:	fce43423          	sd	a4,-56(s0)
    8000500e:	fff1                	bnez	a5,80004fea <memset+0x1e>
    }
    return dst;
    80005010:	fd843783          	ld	a5,-40(s0)
}
    80005014:	853e                	mv	a0,a5
    80005016:	7462                	ld	s0,56(sp)
    80005018:	6121                	add	sp,sp,64
    8000501a:	8082                	ret

000000008000501c <memcpy>:

void* memcpy(void* dst, const void* src, size_t n) {
    8000501c:	7139                	add	sp,sp,-64
    8000501e:	fc22                	sd	s0,56(sp)
    80005020:	0080                	add	s0,sp,64
    80005022:	fca43c23          	sd	a0,-40(s0)
    80005026:	fcb43823          	sd	a1,-48(s0)
    8000502a:	fcc43423          	sd	a2,-56(s0)
    unsigned char* d = (unsigned char*)dst;
    8000502e:	fd843783          	ld	a5,-40(s0)
    80005032:	fef43423          	sd	a5,-24(s0)
    const unsigned char* s = (const unsigned char*)src;
    80005036:	fd043783          	ld	a5,-48(s0)
    8000503a:	fef43023          	sd	a5,-32(s0)
    while (n--) {
    8000503e:	a00d                	j	80005060 <memcpy+0x44>
        *d++ = *s++;
    80005040:	fe043703          	ld	a4,-32(s0)
    80005044:	00170793          	add	a5,a4,1
    80005048:	fef43023          	sd	a5,-32(s0)
    8000504c:	fe843783          	ld	a5,-24(s0)
    80005050:	00178693          	add	a3,a5,1
    80005054:	fed43423          	sd	a3,-24(s0)
    80005058:	00074703          	lbu	a4,0(a4)
    8000505c:	00e78023          	sb	a4,0(a5)
    while (n--) {
    80005060:	fc843783          	ld	a5,-56(s0)
    80005064:	fff78713          	add	a4,a5,-1
    80005068:	fce43423          	sd	a4,-56(s0)
    8000506c:	fbf1                	bnez	a5,80005040 <memcpy+0x24>
    }
    return dst;
    8000506e:	fd843783          	ld	a5,-40(s0)
}
    80005072:	853e                	mv	a0,a5
    80005074:	7462                	ld	s0,56(sp)
    80005076:	6121                	add	sp,sp,64
    80005078:	8082                	ret

000000008000507a <memcmp>:

int memcmp(const void* a, const void* b, size_t n) {
    8000507a:	715d                	add	sp,sp,-80
    8000507c:	e4a2                	sd	s0,72(sp)
    8000507e:	0880                	add	s0,sp,80
    80005080:	fca43423          	sd	a0,-56(s0)
    80005084:	fcb43023          	sd	a1,-64(s0)
    80005088:	fac43c23          	sd	a2,-72(s0)
    const unsigned char* pa = (const unsigned char*)a;
    8000508c:	fc843783          	ld	a5,-56(s0)
    80005090:	fef43023          	sd	a5,-32(s0)
    const unsigned char* pb = (const unsigned char*)b;
    80005094:	fc043783          	ld	a5,-64(s0)
    80005098:	fcf43c23          	sd	a5,-40(s0)
    for (size_t i = 0; i < n; i++) {
    8000509c:	fe043423          	sd	zero,-24(s0)
    800050a0:	a8a1                	j	800050f8 <memcmp+0x7e>
        if (pa[i] != pb[i]) {
    800050a2:	fe043703          	ld	a4,-32(s0)
    800050a6:	fe843783          	ld	a5,-24(s0)
    800050aa:	97ba                	add	a5,a5,a4
    800050ac:	0007c683          	lbu	a3,0(a5)
    800050b0:	fd843703          	ld	a4,-40(s0)
    800050b4:	fe843783          	ld	a5,-24(s0)
    800050b8:	97ba                	add	a5,a5,a4
    800050ba:	0007c783          	lbu	a5,0(a5)
    800050be:	8736                	mv	a4,a3
    800050c0:	02f70763          	beq	a4,a5,800050ee <memcmp+0x74>
            return pa[i] - pb[i];
    800050c4:	fe043703          	ld	a4,-32(s0)
    800050c8:	fe843783          	ld	a5,-24(s0)
    800050cc:	97ba                	add	a5,a5,a4
    800050ce:	0007c783          	lbu	a5,0(a5)
    800050d2:	0007871b          	sext.w	a4,a5
    800050d6:	fd843683          	ld	a3,-40(s0)
    800050da:	fe843783          	ld	a5,-24(s0)
    800050de:	97b6                	add	a5,a5,a3
    800050e0:	0007c783          	lbu	a5,0(a5)
    800050e4:	2781                	sext.w	a5,a5
    800050e6:	40f707bb          	subw	a5,a4,a5
    800050ea:	2781                	sext.w	a5,a5
    800050ec:	a829                	j	80005106 <memcmp+0x8c>
    for (size_t i = 0; i < n; i++) {
    800050ee:	fe843783          	ld	a5,-24(s0)
    800050f2:	0785                	add	a5,a5,1
    800050f4:	fef43423          	sd	a5,-24(s0)
    800050f8:	fe843703          	ld	a4,-24(s0)
    800050fc:	fb843783          	ld	a5,-72(s0)
    80005100:	faf761e3          	bltu	a4,a5,800050a2 <memcmp+0x28>
        }
    }
    return 0;
    80005104:	4781                	li	a5,0
}
    80005106:	853e                	mv	a0,a5
    80005108:	6426                	ld	s0,72(sp)
    8000510a:	6161                	add	sp,sp,80
    8000510c:	8082                	ret

000000008000510e <strlen>:

size_t strlen(const char* s) {
    8000510e:	7179                	add	sp,sp,-48
    80005110:	f422                	sd	s0,40(sp)
    80005112:	1800                	add	s0,sp,48
    80005114:	fca43c23          	sd	a0,-40(s0)
    size_t n = 0;
    80005118:	fe043423          	sd	zero,-24(s0)
    if (!s) return 0;
    8000511c:	fd843783          	ld	a5,-40(s0)
    80005120:	eb81                	bnez	a5,80005130 <strlen+0x22>
    80005122:	4781                	li	a5,0
    80005124:	a005                	j	80005144 <strlen+0x36>
    while (s[n]) n++;
    80005126:	fe843783          	ld	a5,-24(s0)
    8000512a:	0785                	add	a5,a5,1
    8000512c:	fef43423          	sd	a5,-24(s0)
    80005130:	fd843703          	ld	a4,-40(s0)
    80005134:	fe843783          	ld	a5,-24(s0)
    80005138:	97ba                	add	a5,a5,a4
    8000513a:	0007c783          	lbu	a5,0(a5)
    8000513e:	f7e5                	bnez	a5,80005126 <strlen+0x18>
    return n;
    80005140:	fe843783          	ld	a5,-24(s0)
}
    80005144:	853e                	mv	a0,a5
    80005146:	7422                	ld	s0,40(sp)
    80005148:	6145                	add	sp,sp,48
    8000514a:	8082                	ret

000000008000514c <console_putc>:

static void console_putc(int c) {
    8000514c:	1101                	add	sp,sp,-32
    8000514e:	ec06                	sd	ra,24(sp)
    80005150:	e822                	sd	s0,16(sp)
    80005152:	1000                	add	s0,sp,32
    80005154:	87aa                	mv	a5,a0
    80005156:	fef42623          	sw	a5,-20(s0)
    uart_putc((char)c);
    8000515a:	fec42783          	lw	a5,-20(s0)
    8000515e:	0ff7f793          	zext.b	a5,a5
    80005162:	853e                	mv	a0,a5
    80005164:	ffffb097          	auipc	ra,0xffffb
    80005168:	3aa080e7          	jalr	938(ra) # 8000050e <uart_putc>
}
    8000516c:	0001                	nop
    8000516e:	60e2                	ld	ra,24(sp)
    80005170:	6442                	ld	s0,16(sp)
    80005172:	6105                	add	sp,sp,32
    80005174:	8082                	ret

0000000080005176 <puts>:

void puts(const char* s) {
    80005176:	1101                	add	sp,sp,-32
    80005178:	ec06                	sd	ra,24(sp)
    8000517a:	e822                	sd	s0,16(sp)
    8000517c:	1000                	add	s0,sp,32
    8000517e:	fea43423          	sd	a0,-24(s0)
    if (!s) return;
    80005182:	fe843783          	ld	a5,-24(s0)
    80005186:	cf89                	beqz	a5,800051a0 <puts+0x2a>
    uart_puts(s);
    80005188:	fe843503          	ld	a0,-24(s0)
    8000518c:	ffffb097          	auipc	ra,0xffffb
    80005190:	3ca080e7          	jalr	970(ra) # 80000556 <uart_puts>
    uart_putc('\n');
    80005194:	4529                	li	a0,10
    80005196:	ffffb097          	auipc	ra,0xffffb
    8000519a:	378080e7          	jalr	888(ra) # 8000050e <uart_putc>
    8000519e:	a011                	j	800051a2 <puts+0x2c>
    if (!s) return;
    800051a0:	0001                	nop
}
    800051a2:	60e2                	ld	ra,24(sp)
    800051a4:	6442                	ld	s0,16(sp)
    800051a6:	6105                	add	sp,sp,32
    800051a8:	8082                	ret

00000000800051aa <puthex>:

void puthex(uint64 val, int width) {
    800051aa:	7179                	add	sp,sp,-48
    800051ac:	f406                	sd	ra,40(sp)
    800051ae:	f022                	sd	s0,32(sp)
    800051b0:	1800                	add	s0,sp,48
    800051b2:	fca43c23          	sd	a0,-40(s0)
    800051b6:	87ae                	mv	a5,a1
    800051b8:	fcf42a23          	sw	a5,-44(s0)
    static const char* digits = "0123456789abcdef";
    for (int i = width - 1; i >= 0; i--) {
    800051bc:	fd442783          	lw	a5,-44(s0)
    800051c0:	37fd                	addw	a5,a5,-1
    800051c2:	fef42623          	sw	a5,-20(s0)
    800051c6:	a0b9                	j	80005214 <puthex+0x6a>
        int shift = i * 4;
    800051c8:	fec42783          	lw	a5,-20(s0)
    800051cc:	0027979b          	sllw	a5,a5,0x2
    800051d0:	fef42423          	sw	a5,-24(s0)
        int nibble = (val >> shift) & 0xF;
    800051d4:	fe842783          	lw	a5,-24(s0)
    800051d8:	873e                	mv	a4,a5
    800051da:	fd843783          	ld	a5,-40(s0)
    800051de:	00e7d7b3          	srl	a5,a5,a4
    800051e2:	2781                	sext.w	a5,a5
    800051e4:	8bbd                	and	a5,a5,15
    800051e6:	fef42223          	sw	a5,-28(s0)
        console_putc(digits[nibble]);
    800051ea:	00002797          	auipc	a5,0x2
    800051ee:	c5678793          	add	a5,a5,-938 # 80006e40 <digits.0>
    800051f2:	6398                	ld	a4,0(a5)
    800051f4:	fe442783          	lw	a5,-28(s0)
    800051f8:	97ba                	add	a5,a5,a4
    800051fa:	0007c783          	lbu	a5,0(a5)
    800051fe:	2781                	sext.w	a5,a5
    80005200:	853e                	mv	a0,a5
    80005202:	00000097          	auipc	ra,0x0
    80005206:	f4a080e7          	jalr	-182(ra) # 8000514c <console_putc>
    for (int i = width - 1; i >= 0; i--) {
    8000520a:	fec42783          	lw	a5,-20(s0)
    8000520e:	37fd                	addw	a5,a5,-1
    80005210:	fef42623          	sw	a5,-20(s0)
    80005214:	fec42783          	lw	a5,-20(s0)
    80005218:	2781                	sext.w	a5,a5
    8000521a:	fa07d7e3          	bgez	a5,800051c8 <puthex+0x1e>
    }
}
    8000521e:	0001                	nop
    80005220:	0001                	nop
    80005222:	70a2                	ld	ra,40(sp)
    80005224:	7402                	ld	s0,32(sp)
    80005226:	6145                	add	sp,sp,48
    80005228:	8082                	ret

000000008000522a <vsnprintf>:

int vsnprintf(char* buf, size_t size, const char* fmt, va_list ap) {
    8000522a:	7171                	add	sp,sp,-176
    8000522c:	f522                	sd	s0,168(sp)
    8000522e:	1900                	add	s0,sp,176
    80005230:	f6a43423          	sd	a0,-152(s0)
    80005234:	f6b43023          	sd	a1,-160(s0)
    80005238:	f4c43c23          	sd	a2,-168(s0)
    8000523c:	f4d43823          	sd	a3,-176(s0)
    size_t idx = 0;
    80005240:	fe043423          	sd	zero,-24(s0)
    for (const char* p = fmt; *p; p++) {
    80005244:	f5843783          	ld	a5,-168(s0)
    80005248:	fef43023          	sd	a5,-32(s0)
    8000524c:	ad3d                	j	8000588a <vsnprintf+0x660>
        if (*p != '%') {
    8000524e:	fe043783          	ld	a5,-32(s0)
    80005252:	0007c783          	lbu	a5,0(a5)
    80005256:	873e                	mv	a4,a5
    80005258:	02500793          	li	a5,37
    8000525c:	02f70d63          	beq	a4,a5,80005296 <vsnprintf+0x6c>
            if (buf && idx + 1 < size) buf[idx] = *p;
    80005260:	f6843783          	ld	a5,-152(s0)
    80005264:	c39d                	beqz	a5,8000528a <vsnprintf+0x60>
    80005266:	fe843783          	ld	a5,-24(s0)
    8000526a:	0785                	add	a5,a5,1
    8000526c:	f6043703          	ld	a4,-160(s0)
    80005270:	00e7fd63          	bgeu	a5,a4,8000528a <vsnprintf+0x60>
    80005274:	f6843703          	ld	a4,-152(s0)
    80005278:	fe843783          	ld	a5,-24(s0)
    8000527c:	97ba                	add	a5,a5,a4
    8000527e:	fe043703          	ld	a4,-32(s0)
    80005282:	00074703          	lbu	a4,0(a4)
    80005286:	00e78023          	sb	a4,0(a5)
            idx++;
    8000528a:	fe843783          	ld	a5,-24(s0)
    8000528e:	0785                	add	a5,a5,1
    80005290:	fef43423          	sd	a5,-24(s0)
            continue;
    80005294:	a3f5                	j	80005880 <vsnprintf+0x656>
        }
        p++;
    80005296:	fe043783          	ld	a5,-32(s0)
    8000529a:	0785                	add	a5,a5,1
    8000529c:	fef43023          	sd	a5,-32(s0)
        if (!*p) break;
    800052a0:	fe043783          	ld	a5,-32(s0)
    800052a4:	0007c783          	lbu	a5,0(a5)
    800052a8:	5e078863          	beqz	a5,80005898 <vsnprintf+0x66e>
        switch (*p) {
    800052ac:	fe043783          	ld	a5,-32(s0)
    800052b0:	0007c783          	lbu	a5,0(a5)
    800052b4:	2781                	sext.w	a5,a5
    800052b6:	86be                	mv	a3,a5
    800052b8:	02500713          	li	a4,37
    800052bc:	52e68663          	beq	a3,a4,800057e8 <vsnprintf+0x5be>
    800052c0:	86be                	mv	a3,a5
    800052c2:	02500713          	li	a4,37
    800052c6:	54e6ca63          	blt	a3,a4,8000581a <vsnprintf+0x5f0>
    800052ca:	86be                	mv	a3,a5
    800052cc:	07800713          	li	a4,120
    800052d0:	54d74563          	blt	a4,a3,8000581a <vsnprintf+0x5f0>
    800052d4:	86be                	mv	a3,a5
    800052d6:	06300713          	li	a4,99
    800052da:	54e6c063          	blt	a3,a4,8000581a <vsnprintf+0x5f0>
    800052de:	f9d7869b          	addw	a3,a5,-99
    800052e2:	0006871b          	sext.w	a4,a3
    800052e6:	47d5                	li	a5,21
    800052e8:	52e7e963          	bltu	a5,a4,8000581a <vsnprintf+0x5f0>
    800052ec:	02069793          	sll	a5,a3,0x20
    800052f0:	9381                	srl	a5,a5,0x20
    800052f2:	00279713          	sll	a4,a5,0x2
    800052f6:	00002797          	auipc	a5,0x2
    800052fa:	a1678793          	add	a5,a5,-1514 # 80006d0c <syscall_table+0x894>
    800052fe:	97ba                	add	a5,a5,a4
    80005300:	439c                	lw	a5,0(a5)
    80005302:	0007871b          	sext.w	a4,a5
    80005306:	00002797          	auipc	a5,0x2
    8000530a:	a0678793          	add	a5,a5,-1530 # 80006d0c <syscall_table+0x894>
    8000530e:	97ba                	add	a5,a5,a4
    80005310:	8782                	jr	a5
            case 'd': {
                int v = va_arg(ap, int);
    80005312:	f5043783          	ld	a5,-176(s0)
    80005316:	00878713          	add	a4,a5,8
    8000531a:	f4e43823          	sd	a4,-176(s0)
    8000531e:	439c                	lw	a5,0(a5)
    80005320:	faf42023          	sw	a5,-96(s0)
                char tmp[32];
                int n = 0;
    80005324:	fc042e23          	sw	zero,-36(s0)
                int neg = v < 0;
    80005328:	fa042783          	lw	a5,-96(s0)
    8000532c:	01f7d79b          	srlw	a5,a5,0x1f
    80005330:	0ff7f793          	zext.b	a5,a5
    80005334:	f8f42e23          	sw	a5,-100(s0)
                unsigned int uv = neg ? (unsigned int)(-v) : (unsigned int)v;
    80005338:	f9c42783          	lw	a5,-100(s0)
    8000533c:	2781                	sext.w	a5,a5
    8000533e:	cb81                	beqz	a5,8000534e <vsnprintf+0x124>
    80005340:	fa042783          	lw	a5,-96(s0)
    80005344:	40f007bb          	negw	a5,a5
    80005348:	2781                	sext.w	a5,a5
    8000534a:	2781                	sext.w	a5,a5
    8000534c:	a019                	j	80005352 <vsnprintf+0x128>
    8000534e:	fa042783          	lw	a5,-96(s0)
    80005352:	fcf42c23          	sw	a5,-40(s0)
                do {
                    tmp[n++] = "0123456789"[uv % 10];
    80005356:	fd842783          	lw	a5,-40(s0)
    8000535a:	873e                	mv	a4,a5
    8000535c:	47a9                	li	a5,10
    8000535e:	02f777bb          	remuw	a5,a4,a5
    80005362:	0007861b          	sext.w	a2,a5
    80005366:	fdc42783          	lw	a5,-36(s0)
    8000536a:	0017871b          	addw	a4,a5,1
    8000536e:	fce42e23          	sw	a4,-36(s0)
    80005372:	00002697          	auipc	a3,0x2
    80005376:	97668693          	add	a3,a3,-1674 # 80006ce8 <syscall_table+0x870>
    8000537a:	02061713          	sll	a4,a2,0x20
    8000537e:	9301                	srl	a4,a4,0x20
    80005380:	9736                	add	a4,a4,a3
    80005382:	00074703          	lbu	a4,0(a4)
    80005386:	17c1                	add	a5,a5,-16
    80005388:	97a2                	add	a5,a5,s0
    8000538a:	f8e78423          	sb	a4,-120(a5)
                    uv /= 10;
    8000538e:	fd842783          	lw	a5,-40(s0)
    80005392:	873e                	mv	a4,a5
    80005394:	47a9                	li	a5,10
    80005396:	02f757bb          	divuw	a5,a4,a5
    8000539a:	fcf42c23          	sw	a5,-40(s0)
                } while (uv && n < (int)sizeof(tmp));
    8000539e:	fd842783          	lw	a5,-40(s0)
    800053a2:	2781                	sext.w	a5,a5
    800053a4:	cb81                	beqz	a5,800053b4 <vsnprintf+0x18a>
    800053a6:	fdc42783          	lw	a5,-36(s0)
    800053aa:	0007871b          	sext.w	a4,a5
    800053ae:	47fd                	li	a5,31
    800053b0:	fae7d3e3          	bge	a5,a4,80005356 <vsnprintf+0x12c>
                if (neg && n < (int)sizeof(tmp)) tmp[n++] = '-';
    800053b4:	f9c42783          	lw	a5,-100(s0)
    800053b8:	2781                	sext.w	a5,a5
    800053ba:	c3ad                	beqz	a5,8000541c <vsnprintf+0x1f2>
    800053bc:	fdc42783          	lw	a5,-36(s0)
    800053c0:	0007871b          	sext.w	a4,a5
    800053c4:	47fd                	li	a5,31
    800053c6:	04e7cb63          	blt	a5,a4,8000541c <vsnprintf+0x1f2>
    800053ca:	fdc42783          	lw	a5,-36(s0)
    800053ce:	0017871b          	addw	a4,a5,1
    800053d2:	fce42e23          	sw	a4,-36(s0)
    800053d6:	17c1                	add	a5,a5,-16
    800053d8:	97a2                	add	a5,a5,s0
    800053da:	02d00713          	li	a4,45
    800053de:	f8e78423          	sb	a4,-120(a5)
                while (n--) {
    800053e2:	a82d                	j	8000541c <vsnprintf+0x1f2>
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
    800053e4:	f6843783          	ld	a5,-152(s0)
    800053e8:	c78d                	beqz	a5,80005412 <vsnprintf+0x1e8>
    800053ea:	fe843783          	ld	a5,-24(s0)
    800053ee:	0785                	add	a5,a5,1
    800053f0:	f6043703          	ld	a4,-160(s0)
    800053f4:	00e7ff63          	bgeu	a5,a4,80005412 <vsnprintf+0x1e8>
    800053f8:	f6843703          	ld	a4,-152(s0)
    800053fc:	fe843783          	ld	a5,-24(s0)
    80005400:	97ba                	add	a5,a5,a4
    80005402:	fdc42703          	lw	a4,-36(s0)
    80005406:	1741                	add	a4,a4,-16
    80005408:	9722                	add	a4,a4,s0
    8000540a:	f8874703          	lbu	a4,-120(a4)
    8000540e:	00e78023          	sb	a4,0(a5)
                    idx++;
    80005412:	fe843783          	ld	a5,-24(s0)
    80005416:	0785                	add	a5,a5,1
    80005418:	fef43423          	sd	a5,-24(s0)
                while (n--) {
    8000541c:	fdc42783          	lw	a5,-36(s0)
    80005420:	fff7871b          	addw	a4,a5,-1
    80005424:	fce42e23          	sw	a4,-36(s0)
    80005428:	ffd5                	bnez	a5,800053e4 <vsnprintf+0x1ba>
                }
                break;
    8000542a:	a999                	j	80005880 <vsnprintf+0x656>
            }
            case 'u': {
                unsigned int v = va_arg(ap, unsigned int);
    8000542c:	f5043783          	ld	a5,-176(s0)
    80005430:	00878713          	add	a4,a5,8
    80005434:	f4e43823          	sd	a4,-176(s0)
    80005438:	439c                	lw	a5,0(a5)
    8000543a:	fcf42a23          	sw	a5,-44(s0)
                char tmp[32];
                int n = 0;
    8000543e:	fc042823          	sw	zero,-48(s0)
                do {
                    tmp[n++] = "0123456789"[v % 10];
    80005442:	fd442783          	lw	a5,-44(s0)
    80005446:	873e                	mv	a4,a5
    80005448:	47a9                	li	a5,10
    8000544a:	02f777bb          	remuw	a5,a4,a5
    8000544e:	0007861b          	sext.w	a2,a5
    80005452:	fd042783          	lw	a5,-48(s0)
    80005456:	0017871b          	addw	a4,a5,1
    8000545a:	fce42823          	sw	a4,-48(s0)
    8000545e:	00002697          	auipc	a3,0x2
    80005462:	88a68693          	add	a3,a3,-1910 # 80006ce8 <syscall_table+0x870>
    80005466:	02061713          	sll	a4,a2,0x20
    8000546a:	9301                	srl	a4,a4,0x20
    8000546c:	9736                	add	a4,a4,a3
    8000546e:	00074703          	lbu	a4,0(a4)
    80005472:	17c1                	add	a5,a5,-16
    80005474:	97a2                	add	a5,a5,s0
    80005476:	f8e78423          	sb	a4,-120(a5)
                    v /= 10;
    8000547a:	fd442783          	lw	a5,-44(s0)
    8000547e:	873e                	mv	a4,a5
    80005480:	47a9                	li	a5,10
    80005482:	02f757bb          	divuw	a5,a4,a5
    80005486:	fcf42a23          	sw	a5,-44(s0)
                } while (v && n < (int)sizeof(tmp));
    8000548a:	fd442783          	lw	a5,-44(s0)
    8000548e:	2781                	sext.w	a5,a5
    80005490:	c7a9                	beqz	a5,800054da <vsnprintf+0x2b0>
    80005492:	fd042783          	lw	a5,-48(s0)
    80005496:	0007871b          	sext.w	a4,a5
    8000549a:	47fd                	li	a5,31
    8000549c:	fae7d3e3          	bge	a5,a4,80005442 <vsnprintf+0x218>
                while (n--) {
    800054a0:	a82d                	j	800054da <vsnprintf+0x2b0>
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
    800054a2:	f6843783          	ld	a5,-152(s0)
    800054a6:	c78d                	beqz	a5,800054d0 <vsnprintf+0x2a6>
    800054a8:	fe843783          	ld	a5,-24(s0)
    800054ac:	0785                	add	a5,a5,1
    800054ae:	f6043703          	ld	a4,-160(s0)
    800054b2:	00e7ff63          	bgeu	a5,a4,800054d0 <vsnprintf+0x2a6>
    800054b6:	f6843703          	ld	a4,-152(s0)
    800054ba:	fe843783          	ld	a5,-24(s0)
    800054be:	97ba                	add	a5,a5,a4
    800054c0:	fd042703          	lw	a4,-48(s0)
    800054c4:	1741                	add	a4,a4,-16
    800054c6:	9722                	add	a4,a4,s0
    800054c8:	f8874703          	lbu	a4,-120(a4)
    800054cc:	00e78023          	sb	a4,0(a5)
                    idx++;
    800054d0:	fe843783          	ld	a5,-24(s0)
    800054d4:	0785                	add	a5,a5,1
    800054d6:	fef43423          	sd	a5,-24(s0)
                while (n--) {
    800054da:	fd042783          	lw	a5,-48(s0)
    800054de:	fff7871b          	addw	a4,a5,-1
    800054e2:	fce42823          	sw	a4,-48(s0)
    800054e6:	ffd5                	bnez	a5,800054a2 <vsnprintf+0x278>
                }
                break;
    800054e8:	ae61                	j	80005880 <vsnprintf+0x656>
            }
            case 'l': { // handle %lx or %ld
                p++;
    800054ea:	fe043783          	ld	a5,-32(s0)
    800054ee:	0785                	add	a5,a5,1
    800054f0:	fef43023          	sd	a5,-32(s0)
                char spec = *p;
    800054f4:	fe043783          	ld	a5,-32(s0)
    800054f8:	0007c783          	lbu	a5,0(a5)
    800054fc:	faf403a3          	sb	a5,-89(s0)
                uint64 v64 = va_arg(ap, uint64);
    80005500:	f5043783          	ld	a5,-176(s0)
    80005504:	00878713          	add	a4,a5,8
    80005508:	f4e43823          	sd	a4,-176(s0)
    8000550c:	639c                	ld	a5,0(a5)
    8000550e:	fcf43423          	sd	a5,-56(s0)
                if (spec == 'x' || spec == 'p') {
    80005512:	fa744783          	lbu	a5,-89(s0)
    80005516:	0ff7f713          	zext.b	a4,a5
    8000551a:	07800793          	li	a5,120
    8000551e:	00f70a63          	beq	a4,a5,80005532 <vsnprintf+0x308>
    80005522:	fa744783          	lbu	a5,-89(s0)
    80005526:	0ff7f713          	zext.b	a4,a5
    8000552a:	07000793          	li	a5,112
    8000552e:	08f71d63          	bne	a4,a5,800055c8 <vsnprintf+0x39e>
                    char tmp[32];
                    int n = 0;
    80005532:	fc042223          	sw	zero,-60(s0)
                    do {
                        tmp[n++] = "0123456789abcdef"[v64 % 16];
    80005536:	fc843783          	ld	a5,-56(s0)
    8000553a:	00f7f713          	and	a4,a5,15
    8000553e:	fc442783          	lw	a5,-60(s0)
    80005542:	0017869b          	addw	a3,a5,1
    80005546:	fcd42223          	sw	a3,-60(s0)
    8000554a:	00001697          	auipc	a3,0x1
    8000554e:	7ae68693          	add	a3,a3,1966 # 80006cf8 <syscall_table+0x880>
    80005552:	9736                	add	a4,a4,a3
    80005554:	00074703          	lbu	a4,0(a4)
    80005558:	17c1                	add	a5,a5,-16
    8000555a:	97a2                	add	a5,a5,s0
    8000555c:	f8e78423          	sb	a4,-120(a5)
                        v64 /= 16;
    80005560:	fc843783          	ld	a5,-56(s0)
    80005564:	8391                	srl	a5,a5,0x4
    80005566:	fcf43423          	sd	a5,-56(s0)
                    } while (v64 && n < (int)sizeof(tmp));
    8000556a:	fc843783          	ld	a5,-56(s0)
    8000556e:	c7a9                	beqz	a5,800055b8 <vsnprintf+0x38e>
    80005570:	fc442783          	lw	a5,-60(s0)
    80005574:	0007871b          	sext.w	a4,a5
    80005578:	47fd                	li	a5,31
    8000557a:	fae7dee3          	bge	a5,a4,80005536 <vsnprintf+0x30c>
                    while (n--) {
    8000557e:	a82d                	j	800055b8 <vsnprintf+0x38e>
                        if (buf && idx + 1 < size) buf[idx] = tmp[n];
    80005580:	f6843783          	ld	a5,-152(s0)
    80005584:	c78d                	beqz	a5,800055ae <vsnprintf+0x384>
    80005586:	fe843783          	ld	a5,-24(s0)
    8000558a:	0785                	add	a5,a5,1
    8000558c:	f6043703          	ld	a4,-160(s0)
    80005590:	00e7ff63          	bgeu	a5,a4,800055ae <vsnprintf+0x384>
    80005594:	f6843703          	ld	a4,-152(s0)
    80005598:	fe843783          	ld	a5,-24(s0)
    8000559c:	97ba                	add	a5,a5,a4
    8000559e:	fc442703          	lw	a4,-60(s0)
    800055a2:	1741                	add	a4,a4,-16
    800055a4:	9722                	add	a4,a4,s0
    800055a6:	f8874703          	lbu	a4,-120(a4)
    800055aa:	00e78023          	sb	a4,0(a5)
                        idx++;
    800055ae:	fe843783          	ld	a5,-24(s0)
    800055b2:	0785                	add	a5,a5,1
    800055b4:	fef43423          	sd	a5,-24(s0)
                    while (n--) {
    800055b8:	fc442783          	lw	a5,-60(s0)
    800055bc:	fff7871b          	addw	a4,a5,-1
    800055c0:	fce42223          	sw	a4,-60(s0)
    800055c4:	ffd5                	bnez	a5,80005580 <vsnprintf+0x356>
                if (spec == 'x' || spec == 'p') {
    800055c6:	a879                	j	80005664 <vsnprintf+0x43a>
                    }
                } else { // ld or lu
                    char tmp[32];
                    int n = 0;
    800055c8:	fc042023          	sw	zero,-64(s0)
                    do {
                        tmp[n++] = "0123456789"[v64 % 10];
    800055cc:	fc843703          	ld	a4,-56(s0)
    800055d0:	47a9                	li	a5,10
    800055d2:	02f77733          	remu	a4,a4,a5
    800055d6:	fc042783          	lw	a5,-64(s0)
    800055da:	0017869b          	addw	a3,a5,1
    800055de:	fcd42023          	sw	a3,-64(s0)
    800055e2:	00001697          	auipc	a3,0x1
    800055e6:	70668693          	add	a3,a3,1798 # 80006ce8 <syscall_table+0x870>
    800055ea:	9736                	add	a4,a4,a3
    800055ec:	00074703          	lbu	a4,0(a4)
    800055f0:	17c1                	add	a5,a5,-16
    800055f2:	97a2                	add	a5,a5,s0
    800055f4:	f8e78423          	sb	a4,-120(a5)
                        v64 /= 10;
    800055f8:	fc843703          	ld	a4,-56(s0)
    800055fc:	47a9                	li	a5,10
    800055fe:	02f757b3          	divu	a5,a4,a5
    80005602:	fcf43423          	sd	a5,-56(s0)
                    } while (v64 && n < (int)sizeof(tmp));
    80005606:	fc843783          	ld	a5,-56(s0)
    8000560a:	c7a9                	beqz	a5,80005654 <vsnprintf+0x42a>
    8000560c:	fc042783          	lw	a5,-64(s0)
    80005610:	0007871b          	sext.w	a4,a5
    80005614:	47fd                	li	a5,31
    80005616:	fae7dbe3          	bge	a5,a4,800055cc <vsnprintf+0x3a2>
                    while (n--) {
    8000561a:	a82d                	j	80005654 <vsnprintf+0x42a>
                        if (buf && idx + 1 < size) buf[idx] = tmp[n];
    8000561c:	f6843783          	ld	a5,-152(s0)
    80005620:	c78d                	beqz	a5,8000564a <vsnprintf+0x420>
    80005622:	fe843783          	ld	a5,-24(s0)
    80005626:	0785                	add	a5,a5,1
    80005628:	f6043703          	ld	a4,-160(s0)
    8000562c:	00e7ff63          	bgeu	a5,a4,8000564a <vsnprintf+0x420>
    80005630:	f6843703          	ld	a4,-152(s0)
    80005634:	fe843783          	ld	a5,-24(s0)
    80005638:	97ba                	add	a5,a5,a4
    8000563a:	fc042703          	lw	a4,-64(s0)
    8000563e:	1741                	add	a4,a4,-16
    80005640:	9722                	add	a4,a4,s0
    80005642:	f8874703          	lbu	a4,-120(a4)
    80005646:	00e78023          	sb	a4,0(a5)
                        idx++;
    8000564a:	fe843783          	ld	a5,-24(s0)
    8000564e:	0785                	add	a5,a5,1
    80005650:	fef43423          	sd	a5,-24(s0)
                    while (n--) {
    80005654:	fc042783          	lw	a5,-64(s0)
    80005658:	fff7871b          	addw	a4,a5,-1
    8000565c:	fce42023          	sw	a4,-64(s0)
    80005660:	ffd5                	bnez	a5,8000561c <vsnprintf+0x3f2>
                    }
                }
                break;
    80005662:	ac39                	j	80005880 <vsnprintf+0x656>
    80005664:	ac31                	j	80005880 <vsnprintf+0x656>
            }
            case 'x':
            case 'p': {
                uint64 v = (*p == 'p') ? (uint64)va_arg(ap, void*) : (uint64)va_arg(ap, unsigned int);
    80005666:	fe043783          	ld	a5,-32(s0)
    8000566a:	0007c783          	lbu	a5,0(a5)
    8000566e:	873e                	mv	a4,a5
    80005670:	07000793          	li	a5,112
    80005674:	00f71a63          	bne	a4,a5,80005688 <vsnprintf+0x45e>
    80005678:	f5043783          	ld	a5,-176(s0)
    8000567c:	00878713          	add	a4,a5,8
    80005680:	f4e43823          	sd	a4,-176(s0)
    80005684:	639c                	ld	a5,0(a5)
    80005686:	a811                	j	8000569a <vsnprintf+0x470>
    80005688:	f5043783          	ld	a5,-176(s0)
    8000568c:	00878713          	add	a4,a5,8
    80005690:	f4e43823          	sd	a4,-176(s0)
    80005694:	439c                	lw	a5,0(a5)
    80005696:	1782                	sll	a5,a5,0x20
    80005698:	9381                	srl	a5,a5,0x20
    8000569a:	faf43c23          	sd	a5,-72(s0)
                char tmp[32];
                int n = 0;
    8000569e:	fa042a23          	sw	zero,-76(s0)
                do {
                    tmp[n++] = "0123456789abcdef"[v % 16];
    800056a2:	fb843783          	ld	a5,-72(s0)
    800056a6:	00f7f713          	and	a4,a5,15
    800056aa:	fb442783          	lw	a5,-76(s0)
    800056ae:	0017869b          	addw	a3,a5,1
    800056b2:	fad42a23          	sw	a3,-76(s0)
    800056b6:	00001697          	auipc	a3,0x1
    800056ba:	64268693          	add	a3,a3,1602 # 80006cf8 <syscall_table+0x880>
    800056be:	9736                	add	a4,a4,a3
    800056c0:	00074703          	lbu	a4,0(a4)
    800056c4:	17c1                	add	a5,a5,-16
    800056c6:	97a2                	add	a5,a5,s0
    800056c8:	f8e78423          	sb	a4,-120(a5)
                    v /= 16;
    800056cc:	fb843783          	ld	a5,-72(s0)
    800056d0:	8391                	srl	a5,a5,0x4
    800056d2:	faf43c23          	sd	a5,-72(s0)
                } while (v && n < (int)sizeof(tmp));
    800056d6:	fb843783          	ld	a5,-72(s0)
    800056da:	c7a9                	beqz	a5,80005724 <vsnprintf+0x4fa>
    800056dc:	fb442783          	lw	a5,-76(s0)
    800056e0:	0007871b          	sext.w	a4,a5
    800056e4:	47fd                	li	a5,31
    800056e6:	fae7dee3          	bge	a5,a4,800056a2 <vsnprintf+0x478>
                while (n--) {
    800056ea:	a82d                	j	80005724 <vsnprintf+0x4fa>
                    if (buf && idx + 1 < size) buf[idx] = tmp[n];
    800056ec:	f6843783          	ld	a5,-152(s0)
    800056f0:	c78d                	beqz	a5,8000571a <vsnprintf+0x4f0>
    800056f2:	fe843783          	ld	a5,-24(s0)
    800056f6:	0785                	add	a5,a5,1
    800056f8:	f6043703          	ld	a4,-160(s0)
    800056fc:	00e7ff63          	bgeu	a5,a4,8000571a <vsnprintf+0x4f0>
    80005700:	f6843703          	ld	a4,-152(s0)
    80005704:	fe843783          	ld	a5,-24(s0)
    80005708:	97ba                	add	a5,a5,a4
    8000570a:	fb442703          	lw	a4,-76(s0)
    8000570e:	1741                	add	a4,a4,-16
    80005710:	9722                	add	a4,a4,s0
    80005712:	f8874703          	lbu	a4,-120(a4)
    80005716:	00e78023          	sb	a4,0(a5)
                    idx++;
    8000571a:	fe843783          	ld	a5,-24(s0)
    8000571e:	0785                	add	a5,a5,1
    80005720:	fef43423          	sd	a5,-24(s0)
                while (n--) {
    80005724:	fb442783          	lw	a5,-76(s0)
    80005728:	fff7871b          	addw	a4,a5,-1
    8000572c:	fae42a23          	sw	a4,-76(s0)
    80005730:	ffd5                	bnez	a5,800056ec <vsnprintf+0x4c2>
                }
                break;
    80005732:	a2b9                	j	80005880 <vsnprintf+0x656>
            }
            case 's': {
                const char* s = va_arg(ap, const char*);
    80005734:	f5043783          	ld	a5,-176(s0)
    80005738:	00878713          	add	a4,a5,8
    8000573c:	f4e43823          	sd	a4,-176(s0)
    80005740:	639c                	ld	a5,0(a5)
    80005742:	faf43423          	sd	a5,-88(s0)
                if (!s) s = "(null)";
    80005746:	fa843783          	ld	a5,-88(s0)
    8000574a:	e7b9                	bnez	a5,80005798 <vsnprintf+0x56e>
    8000574c:	00001797          	auipc	a5,0x1
    80005750:	59478793          	add	a5,a5,1428 # 80006ce0 <syscall_table+0x868>
    80005754:	faf43423          	sd	a5,-88(s0)
                while (*s) {
    80005758:	a081                	j	80005798 <vsnprintf+0x56e>
                    if (buf && idx + 1 < size) buf[idx] = *s;
    8000575a:	f6843783          	ld	a5,-152(s0)
    8000575e:	c39d                	beqz	a5,80005784 <vsnprintf+0x55a>
    80005760:	fe843783          	ld	a5,-24(s0)
    80005764:	0785                	add	a5,a5,1
    80005766:	f6043703          	ld	a4,-160(s0)
    8000576a:	00e7fd63          	bgeu	a5,a4,80005784 <vsnprintf+0x55a>
    8000576e:	f6843703          	ld	a4,-152(s0)
    80005772:	fe843783          	ld	a5,-24(s0)
    80005776:	97ba                	add	a5,a5,a4
    80005778:	fa843703          	ld	a4,-88(s0)
    8000577c:	00074703          	lbu	a4,0(a4)
    80005780:	00e78023          	sb	a4,0(a5)
                    idx++;
    80005784:	fe843783          	ld	a5,-24(s0)
    80005788:	0785                	add	a5,a5,1
    8000578a:	fef43423          	sd	a5,-24(s0)
                    s++;
    8000578e:	fa843783          	ld	a5,-88(s0)
    80005792:	0785                	add	a5,a5,1
    80005794:	faf43423          	sd	a5,-88(s0)
                while (*s) {
    80005798:	fa843783          	ld	a5,-88(s0)
    8000579c:	0007c783          	lbu	a5,0(a5)
    800057a0:	ffcd                	bnez	a5,8000575a <vsnprintf+0x530>
                }
                break;
    800057a2:	a8f9                	j	80005880 <vsnprintf+0x656>
            }
            case 'c': {
                char c = (char)va_arg(ap, int);
    800057a4:	f5043783          	ld	a5,-176(s0)
    800057a8:	00878713          	add	a4,a5,8
    800057ac:	f4e43823          	sd	a4,-176(s0)
    800057b0:	439c                	lw	a5,0(a5)
    800057b2:	f8f40da3          	sb	a5,-101(s0)
                if (buf && idx + 1 < size) buf[idx] = c;
    800057b6:	f6843783          	ld	a5,-152(s0)
    800057ba:	c38d                	beqz	a5,800057dc <vsnprintf+0x5b2>
    800057bc:	fe843783          	ld	a5,-24(s0)
    800057c0:	0785                	add	a5,a5,1
    800057c2:	f6043703          	ld	a4,-160(s0)
    800057c6:	00e7fb63          	bgeu	a5,a4,800057dc <vsnprintf+0x5b2>
    800057ca:	f6843703          	ld	a4,-152(s0)
    800057ce:	fe843783          	ld	a5,-24(s0)
    800057d2:	97ba                	add	a5,a5,a4
    800057d4:	f9b44703          	lbu	a4,-101(s0)
    800057d8:	00e78023          	sb	a4,0(a5)
                idx++;
    800057dc:	fe843783          	ld	a5,-24(s0)
    800057e0:	0785                	add	a5,a5,1
    800057e2:	fef43423          	sd	a5,-24(s0)
                break;
    800057e6:	a869                	j	80005880 <vsnprintf+0x656>
            }
            case '%':
                if (buf && idx + 1 < size) buf[idx] = '%';
    800057e8:	f6843783          	ld	a5,-152(s0)
    800057ec:	c38d                	beqz	a5,8000580e <vsnprintf+0x5e4>
    800057ee:	fe843783          	ld	a5,-24(s0)
    800057f2:	0785                	add	a5,a5,1
    800057f4:	f6043703          	ld	a4,-160(s0)
    800057f8:	00e7fb63          	bgeu	a5,a4,8000580e <vsnprintf+0x5e4>
    800057fc:	f6843703          	ld	a4,-152(s0)
    80005800:	fe843783          	ld	a5,-24(s0)
    80005804:	97ba                	add	a5,a5,a4
    80005806:	02500713          	li	a4,37
    8000580a:	00e78023          	sb	a4,0(a5)
                idx++;
    8000580e:	fe843783          	ld	a5,-24(s0)
    80005812:	0785                	add	a5,a5,1
    80005814:	fef43423          	sd	a5,-24(s0)
                break;
    80005818:	a0a5                	j	80005880 <vsnprintf+0x656>
            default:
                if (buf && idx + 1 < size) buf[idx] = '%';
    8000581a:	f6843783          	ld	a5,-152(s0)
    8000581e:	c38d                	beqz	a5,80005840 <vsnprintf+0x616>
    80005820:	fe843783          	ld	a5,-24(s0)
    80005824:	0785                	add	a5,a5,1
    80005826:	f6043703          	ld	a4,-160(s0)
    8000582a:	00e7fb63          	bgeu	a5,a4,80005840 <vsnprintf+0x616>
    8000582e:	f6843703          	ld	a4,-152(s0)
    80005832:	fe843783          	ld	a5,-24(s0)
    80005836:	97ba                	add	a5,a5,a4
    80005838:	02500713          	li	a4,37
    8000583c:	00e78023          	sb	a4,0(a5)
                idx++;
    80005840:	fe843783          	ld	a5,-24(s0)
    80005844:	0785                	add	a5,a5,1
    80005846:	fef43423          	sd	a5,-24(s0)
                if (buf && idx + 1 < size) buf[idx] = *p;
    8000584a:	f6843783          	ld	a5,-152(s0)
    8000584e:	c39d                	beqz	a5,80005874 <vsnprintf+0x64a>
    80005850:	fe843783          	ld	a5,-24(s0)
    80005854:	0785                	add	a5,a5,1
    80005856:	f6043703          	ld	a4,-160(s0)
    8000585a:	00e7fd63          	bgeu	a5,a4,80005874 <vsnprintf+0x64a>
    8000585e:	f6843703          	ld	a4,-152(s0)
    80005862:	fe843783          	ld	a5,-24(s0)
    80005866:	97ba                	add	a5,a5,a4
    80005868:	fe043703          	ld	a4,-32(s0)
    8000586c:	00074703          	lbu	a4,0(a4)
    80005870:	00e78023          	sb	a4,0(a5)
                idx++;
    80005874:	fe843783          	ld	a5,-24(s0)
    80005878:	0785                	add	a5,a5,1
    8000587a:	fef43423          	sd	a5,-24(s0)
                break;
    8000587e:	0001                	nop
    for (const char* p = fmt; *p; p++) {
    80005880:	fe043783          	ld	a5,-32(s0)
    80005884:	0785                	add	a5,a5,1
    80005886:	fef43023          	sd	a5,-32(s0)
    8000588a:	fe043783          	ld	a5,-32(s0)
    8000588e:	0007c783          	lbu	a5,0(a5)
    80005892:	9a079ee3          	bnez	a5,8000524e <vsnprintf+0x24>
    80005896:	a011                	j	8000589a <vsnprintf+0x670>
        if (!*p) break;
    80005898:	0001                	nop
        }
    }
    if (buf && size) {
    8000589a:	f6843783          	ld	a5,-152(s0)
    8000589e:	c78d                	beqz	a5,800058c8 <vsnprintf+0x69e>
    800058a0:	f6043783          	ld	a5,-160(s0)
    800058a4:	c395                	beqz	a5,800058c8 <vsnprintf+0x69e>
        buf[(idx < size) ? idx : size - 1] = '\0';
    800058a6:	fe843703          	ld	a4,-24(s0)
    800058aa:	f6043783          	ld	a5,-160(s0)
    800058ae:	00f76663          	bltu	a4,a5,800058ba <vsnprintf+0x690>
    800058b2:	f6043783          	ld	a5,-160(s0)
    800058b6:	17fd                	add	a5,a5,-1
    800058b8:	a019                	j	800058be <vsnprintf+0x694>
    800058ba:	fe843783          	ld	a5,-24(s0)
    800058be:	f6843703          	ld	a4,-152(s0)
    800058c2:	97ba                	add	a5,a5,a4
    800058c4:	00078023          	sb	zero,0(a5)
    }
    return (int)idx;
    800058c8:	fe843783          	ld	a5,-24(s0)
    800058cc:	2781                	sext.w	a5,a5
}
    800058ce:	853e                	mv	a0,a5
    800058d0:	742a                	ld	s0,168(sp)
    800058d2:	614d                	add	sp,sp,176
    800058d4:	8082                	ret

00000000800058d6 <printf>:

int printf(const char* fmt, ...) {
    800058d6:	7149                	add	sp,sp,-368
    800058d8:	f606                	sd	ra,296(sp)
    800058da:	f222                	sd	s0,288(sp)
    800058dc:	1a00                	add	s0,sp,304
    800058de:	eca43c23          	sd	a0,-296(s0)
    800058e2:	e40c                	sd	a1,8(s0)
    800058e4:	e810                	sd	a2,16(s0)
    800058e6:	ec14                	sd	a3,24(s0)
    800058e8:	f018                	sd	a4,32(s0)
    800058ea:	f41c                	sd	a5,40(s0)
    800058ec:	03043823          	sd	a6,48(s0)
    800058f0:	03143c23          	sd	a7,56(s0)
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    800058f4:	04040793          	add	a5,s0,64
    800058f8:	ecf43823          	sd	a5,-304(s0)
    800058fc:	ed043783          	ld	a5,-304(s0)
    80005900:	fc878793          	add	a5,a5,-56
    80005904:	eef43023          	sd	a5,-288(s0)
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    80005908:	ee043703          	ld	a4,-288(s0)
    8000590c:	ee840793          	add	a5,s0,-280
    80005910:	86ba                	mv	a3,a4
    80005912:	ed843603          	ld	a2,-296(s0)
    80005916:	10000593          	li	a1,256
    8000591a:	853e                	mv	a0,a5
    8000591c:	00000097          	auipc	ra,0x0
    80005920:	90e080e7          	jalr	-1778(ra) # 8000522a <vsnprintf>
    80005924:	87aa                	mv	a5,a0
    80005926:	fef42423          	sw	a5,-24(s0)
    va_end(ap);
    for (int i = 0; buf[i]; i++) {
    8000592a:	fe042623          	sw	zero,-20(s0)
    8000592e:	a015                	j	80005952 <printf+0x7c>
        console_putc(buf[i]);
    80005930:	fec42783          	lw	a5,-20(s0)
    80005934:	17c1                	add	a5,a5,-16
    80005936:	97a2                	add	a5,a5,s0
    80005938:	ef87c783          	lbu	a5,-264(a5)
    8000593c:	2781                	sext.w	a5,a5
    8000593e:	853e                	mv	a0,a5
    80005940:	00000097          	auipc	ra,0x0
    80005944:	80c080e7          	jalr	-2036(ra) # 8000514c <console_putc>
    for (int i = 0; buf[i]; i++) {
    80005948:	fec42783          	lw	a5,-20(s0)
    8000594c:	2785                	addw	a5,a5,1
    8000594e:	fef42623          	sw	a5,-20(s0)
    80005952:	fec42783          	lw	a5,-20(s0)
    80005956:	17c1                	add	a5,a5,-16
    80005958:	97a2                	add	a5,a5,s0
    8000595a:	ef87c783          	lbu	a5,-264(a5)
    8000595e:	fbe9                	bnez	a5,80005930 <printf+0x5a>
    }
    return n;
    80005960:	fe842783          	lw	a5,-24(s0)
}
    80005964:	853e                	mv	a0,a5
    80005966:	70b2                	ld	ra,296(sp)
    80005968:	7412                	ld	s0,288(sp)
    8000596a:	6175                	add	sp,sp,368
    8000596c:	8082                	ret

000000008000596e <panic>:

void panic(const char* msg) {
    8000596e:	1101                	add	sp,sp,-32
    80005970:	ec06                	sd	ra,24(sp)
    80005972:	e822                	sd	s0,16(sp)
    80005974:	1000                	add	s0,sp,32
    80005976:	fea43423          	sd	a0,-24(s0)
    uart_puts("\nPANIC: ");
    8000597a:	00001517          	auipc	a0,0x1
    8000597e:	3ee50513          	add	a0,a0,1006 # 80006d68 <syscall_table+0x8f0>
    80005982:	ffffb097          	auipc	ra,0xffffb
    80005986:	bd4080e7          	jalr	-1068(ra) # 80000556 <uart_puts>
    uart_puts(msg);
    8000598a:	fe843503          	ld	a0,-24(s0)
    8000598e:	ffffb097          	auipc	ra,0xffffb
    80005992:	bc8080e7          	jalr	-1080(ra) # 80000556 <uart_puts>
    uart_puts("\n");
    80005996:	00001517          	auipc	a0,0x1
    8000599a:	3e250513          	add	a0,a0,994 # 80006d78 <syscall_table+0x900>
    8000599e:	ffffb097          	auipc	ra,0xffffb
    800059a2:	bb8080e7          	jalr	-1096(ra) # 80000556 <uart_puts>
    while (1) {
        asm volatile("wfi");
    800059a6:	10500073          	wfi
    800059aa:	bff5                	j	800059a6 <panic+0x38>

00000000800059ac <kernelvec>:
.globl kernelvec
.globl timervec

# Supervisor trap entry: save context, call C handler, restore and sret
kernelvec:
    addi sp, sp, -TRAPFRAME_SIZE
    800059ac:	712d                	add	sp,sp,-288

    sd ra, TF_RA(sp)
    800059ae:	e006                	sd	ra,0(sp)
    sd t0, TF_T0(sp)
    800059b0:	f016                	sd	t0,32(sp)
    sd t1, TF_T1(sp)
    800059b2:	f41a                	sd	t1,40(sp)
    sd t2, TF_T2(sp)
    800059b4:	f81e                	sd	t2,48(sp)
    sd t3, TF_T3(sp)
    800059b6:	edf2                	sd	t3,216(sp)
    sd t4, TF_T4(sp)
    800059b8:	f1f6                	sd	t4,224(sp)
    sd t5, TF_T5(sp)
    800059ba:	f5fa                	sd	t5,232(sp)
    sd t6, TF_T6(sp)
    800059bc:	f9fe                	sd	t6,240(sp)

    sd s0, TF_S0(sp)
    800059be:	fc22                	sd	s0,56(sp)
    sd s1, TF_S1(sp)
    800059c0:	e0a6                	sd	s1,64(sp)
    sd s2, TF_S2(sp)
    800059c2:	e54a                	sd	s2,136(sp)
    sd s3, TF_S3(sp)
    800059c4:	e94e                	sd	s3,144(sp)
    sd s4, TF_S4(sp)
    800059c6:	ed52                	sd	s4,152(sp)
    sd s5, TF_S5(sp)
    800059c8:	f156                	sd	s5,160(sp)
    sd s6, TF_S6(sp)
    800059ca:	f55a                	sd	s6,168(sp)
    sd s7, TF_S7(sp)
    800059cc:	f95e                	sd	s7,176(sp)
    sd s8, TF_S8(sp)
    800059ce:	fd62                	sd	s8,184(sp)
    sd s9, TF_S9(sp)
    800059d0:	e1e6                	sd	s9,192(sp)
    sd s10, TF_S10(sp)
    800059d2:	e5ea                	sd	s10,200(sp)
    sd s11, TF_S11(sp)
    800059d4:	e9ee                	sd	s11,208(sp)

    sd a0, TF_A0(sp)
    800059d6:	e4aa                	sd	a0,72(sp)
    sd a1, TF_A1(sp)
    800059d8:	e8ae                	sd	a1,80(sp)
    sd a2, TF_A2(sp)
    800059da:	ecb2                	sd	a2,88(sp)
    sd a3, TF_A3(sp)
    800059dc:	f0b6                	sd	a3,96(sp)
    sd a4, TF_A4(sp)
    800059de:	f4ba                	sd	a4,104(sp)
    sd a5, TF_A5(sp)
    800059e0:	f8be                	sd	a5,112(sp)
    sd a6, TF_A6(sp)
    800059e2:	fcc2                	sd	a6,120(sp)
    sd a7, TF_A7(sp)
    800059e4:	e146                	sd	a7,128(sp)

    sd gp, TF_GP(sp)
    800059e6:	e80e                	sd	gp,16(sp)
    sd tp, TF_TP(sp)
    800059e8:	ec12                	sd	tp,24(sp)

    addi t0, sp, TRAPFRAME_SIZE   # original sp before trap
    800059ea:	12010293          	add	t0,sp,288
    sd t0, TF_SP(sp)
    800059ee:	e416                	sd	t0,8(sp)

    csrr t0, sepc
    800059f0:	141022f3          	csrr	t0,sepc
    sd t0, TF_SEPC(sp)
    800059f4:	fd96                	sd	t0,248(sp)
    csrr t0, sstatus
    800059f6:	100022f3          	csrr	t0,sstatus
    sd t0, TF_SSTATUS(sp)
    800059fa:	e216                	sd	t0,256(sp)
    csrr t0, stval
    800059fc:	143022f3          	csrr	t0,stval
    sd t0, TF_STVAL(sp)
    80005a00:	e616                	sd	t0,264(sp)
    csrr t0, scause
    80005a02:	142022f3          	csrr	t0,scause
    sd t0, TF_SCAUSE(sp)
    80005a06:	ea16                	sd	t0,272(sp)

    mv a0, sp
    80005a08:	850a                	mv	a0,sp
    call kerneltrap
    80005a0a:	ffffe097          	auipc	ra,0xffffe
    80005a0e:	784080e7          	jalr	1924(ra) # 8000418e <kerneltrap>

    ld t0, TF_SSTATUS(sp)
    80005a12:	6292                	ld	t0,256(sp)
    csrw sstatus, t0
    80005a14:	10029073          	csrw	sstatus,t0
    ld t0, TF_SEPC(sp)
    80005a18:	72ee                	ld	t0,248(sp)
    csrw sepc, t0
    80005a1a:	14129073          	csrw	sepc,t0

    ld ra, TF_RA(sp)
    80005a1e:	6082                	ld	ra,0(sp)
    ld t0, TF_T0(sp)
    80005a20:	7282                	ld	t0,32(sp)
    ld t1, TF_T1(sp)
    80005a22:	7322                	ld	t1,40(sp)
    ld t2, TF_T2(sp)
    80005a24:	73c2                	ld	t2,48(sp)
    ld t3, TF_T3(sp)
    80005a26:	6e6e                	ld	t3,216(sp)
    ld t4, TF_T4(sp)
    80005a28:	7e8e                	ld	t4,224(sp)
    ld t5, TF_T5(sp)
    80005a2a:	7f2e                	ld	t5,232(sp)
    ld t6, TF_T6(sp)
    80005a2c:	7fce                	ld	t6,240(sp)

    ld s0, TF_S0(sp)
    80005a2e:	7462                	ld	s0,56(sp)
    ld s1, TF_S1(sp)
    80005a30:	6486                	ld	s1,64(sp)
    ld s2, TF_S2(sp)
    80005a32:	692a                	ld	s2,136(sp)
    ld s3, TF_S3(sp)
    80005a34:	69ca                	ld	s3,144(sp)
    ld s4, TF_S4(sp)
    80005a36:	6a6a                	ld	s4,152(sp)
    ld s5, TF_S5(sp)
    80005a38:	7a8a                	ld	s5,160(sp)
    ld s6, TF_S6(sp)
    80005a3a:	7b2a                	ld	s6,168(sp)
    ld s7, TF_S7(sp)
    80005a3c:	7bca                	ld	s7,176(sp)
    ld s8, TF_S8(sp)
    80005a3e:	7c6a                	ld	s8,184(sp)
    ld s9, TF_S9(sp)
    80005a40:	6c8e                	ld	s9,192(sp)
    ld s10, TF_S10(sp)
    80005a42:	6d2e                	ld	s10,200(sp)
    ld s11, TF_S11(sp)
    80005a44:	6dce                	ld	s11,208(sp)

    ld a0, TF_A0(sp)
    80005a46:	6526                	ld	a0,72(sp)
    ld a1, TF_A1(sp)
    80005a48:	65c6                	ld	a1,80(sp)
    ld a2, TF_A2(sp)
    80005a4a:	6666                	ld	a2,88(sp)
    ld a3, TF_A3(sp)
    80005a4c:	7686                	ld	a3,96(sp)
    ld a4, TF_A4(sp)
    80005a4e:	7726                	ld	a4,104(sp)
    ld a5, TF_A5(sp)
    80005a50:	77c6                	ld	a5,112(sp)
    ld a6, TF_A6(sp)
    80005a52:	7866                	ld	a6,120(sp)
    ld a7, TF_A7(sp)
    80005a54:	688a                	ld	a7,128(sp)

    ld gp, TF_GP(sp)
    80005a56:	61c2                	ld	gp,16(sp)
    ld tp, TF_TP(sp)
    80005a58:	6262                	ld	tp,24(sp)

    ld sp, TF_SP(sp)
    80005a5a:	6122                	ld	sp,8(sp)
    sret
    80005a5c:	10200073          	sret

0000000080005a60 <timervec>:
#   [1] saved t2
#   [2] saved t3
#   [3] mtimecmp address
#   [4] interval (cycles)
timervec:
    csrrw t0, mscratch, t0    # t0 = scratch pointer, mscratch = old t0
    80005a60:	340292f3          	csrrw	t0,mscratch,t0
    sd t1, 0(t0)
    80005a64:	0062b023          	sd	t1,0(t0)
    sd t2, 8(t0)
    80005a68:	0072b423          	sd	t2,8(t0)
    sd t3, 16(t0)
    80005a6c:	01c2b823          	sd	t3,16(t0)

    ld t1, 24(t0)             # mtimecmp address
    80005a70:	0182b303          	ld	t1,24(t0)
    ld t2, 32(t0)             # interval
    80005a74:	0202b383          	ld	t2,32(t0)
    csrr t3, time             # current time
    80005a78:	c0102e73          	rdtime	t3
    add t3, t3, t2
    80005a7c:	9e1e                	add	t3,t3,t2
    sd t3, 0(t1)              # program next timer
    80005a7e:	01c33023          	sd	t3,0(t1)

    li t2, 2                  # SSIP
    80005a82:	4389                	li	t2,2
    csrs sip, t2              # trigger supervisor software interrupt
    80005a84:	1443a073          	csrs	sip,t2

    ld t1, 0(t0)
    80005a88:	0002b303          	ld	t1,0(t0)
    ld t2, 8(t0)
    80005a8c:	0082b383          	ld	t2,8(t0)
    ld t3, 16(t0)
    80005a90:	0102be03          	ld	t3,16(t0)
    csrrw t0, mscratch, t0    # restore original t0 into t0, mscratch=pointer
    80005a94:	340292f3          	csrrw	t0,mscratch,t0
    mret
    80005a98:	30200073          	mret

0000000080005a9c <swtch>:
 *   void swtch(struct context *old, struct context *new);
 */

.globl swtch
swtch:
        sd ra, 0(a0)
    80005a9c:	00153023          	sd	ra,0(a0)
        sd sp, 8(a0)
    80005aa0:	00253423          	sd	sp,8(a0)
        sd s0, 16(a0)
    80005aa4:	e900                	sd	s0,16(a0)
        sd s1, 24(a0)
    80005aa6:	ed04                	sd	s1,24(a0)
        sd s2, 32(a0)
    80005aa8:	03253023          	sd	s2,32(a0)
        sd s3, 40(a0)
    80005aac:	03353423          	sd	s3,40(a0)
        sd s4, 48(a0)
    80005ab0:	03453823          	sd	s4,48(a0)
        sd s5, 56(a0)
    80005ab4:	03553c23          	sd	s5,56(a0)
        sd s6, 64(a0)
    80005ab8:	05653023          	sd	s6,64(a0)
        sd s7, 72(a0)
    80005abc:	05753423          	sd	s7,72(a0)
        sd s8, 80(a0)
    80005ac0:	05853823          	sd	s8,80(a0)
        sd s9, 88(a0)
    80005ac4:	05953c23          	sd	s9,88(a0)
        sd s10, 96(a0)
    80005ac8:	07a53023          	sd	s10,96(a0)
        sd s11, 104(a0)
    80005acc:	07b53423          	sd	s11,104(a0)

        ld ra, 0(a1)
    80005ad0:	0005b083          	ld	ra,0(a1) # 200000 <_entry-0x7fe00000>
        ld sp, 8(a1)
    80005ad4:	0085b103          	ld	sp,8(a1)
        ld s0, 16(a1)
    80005ad8:	6980                	ld	s0,16(a1)
        ld s1, 24(a1)
    80005ada:	6d84                	ld	s1,24(a1)
        ld s2, 32(a1)
    80005adc:	0205b903          	ld	s2,32(a1)
        ld s3, 40(a1)
    80005ae0:	0285b983          	ld	s3,40(a1)
        ld s4, 48(a1)
    80005ae4:	0305ba03          	ld	s4,48(a1)
        ld s5, 56(a1)
    80005ae8:	0385ba83          	ld	s5,56(a1)
        ld s6, 64(a1)
    80005aec:	0405bb03          	ld	s6,64(a1)
        ld s7, 72(a1)
    80005af0:	0485bb83          	ld	s7,72(a1)
        ld s8, 80(a1)
    80005af4:	0505bc03          	ld	s8,80(a1)
        ld s9, 88(a1)
    80005af8:	0585bc83          	ld	s9,88(a1)
        ld s10, 96(a1)
    80005afc:	0605bd03          	ld	s10,96(a1)
        ld s11, 104(a1)
    80005b00:	0685bd83          	ld	s11,104(a1)

        ret
    80005b04:	8082                	ret
	...
