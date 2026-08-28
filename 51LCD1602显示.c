/*
 * ===========================================================================
 *  51单片机 LCD1602 显示示例（SDCC + 普中 STC89C52）
 * ===========================================================================
 *  硬件接线（普中板常见接法，按你板子原理图核对）：
 *    LCD数据口 D0~D7  → P0.0~P0.7（需接 10k 上拉电阻排）
 *    LCD RS          → P2.6
 *    LCD RW          → P2.5
 *    LCD EN          → P2.7
 *  显示内容：第一行 "C51 Learning"
 *           第二行 "by SDCC + Trae"
 * ===========================================================================
 */
#include <mcs51/8052.h>

#define LCD_DATA P0     // 数据口
#define LCD_RS P2_6      // 寄存器选择：0=命令，1=数据
#define LCD_RW P2_5      // 读写：0=写，1=读
#define LCD_EN P2_7      // 使能：下降沿锁存

/* 简单延时 */
void delay_ms(unsigned int ms)
{
    unsigned int i, j;
    for (i = 0; i < ms; i++)
        for (j = 0; j < 110; j++);
}

/* 短延时（LCD使能脉冲）*/
void delay_us(unsigned int us)
{
    while (us--);
}

/* 写命令到 LCD */
void lcd_write_cmd(unsigned char cmd)
{
    LCD_RS = 0;          // 命令
    LCD_RW = 0;          // 写
    LCD_DATA = cmd;
    LCD_EN = 1;
    delay_us(5);
    LCD_EN = 0;          // 下降沿锁存
    delay_ms(2);         // 等命令执行
}

/* 写数据到 LCD */
void lcd_write_data(unsigned char dat)
{
    LCD_RS = 1;          // 数据
    LCD_RW = 0;
    LCD_DATA = dat;
    LCD_EN = 1;
    delay_us(5);
    LCD_EN = 0;
    delay_ms(2);
}

/* 光标定位：x=列(0~15)，y=行(0~1) */
void lcd_goto(unsigned char x, unsigned char y)
{
    unsigned char addr;
    if (y == 0) addr = 0x80 + x;        // 第一行起始地址 0x80
    else        addr = 0xC0 + x;        // 第二行起始地址 0xC0
    lcd_write_cmd(addr);
}

/* 显示字符串 */
void lcd_print(const char *s)
{
    while (*s)
        lcd_write_data(*s++);
}

/* LCD 初始化（按 HD44780 控制器标准流程）*/
void lcd_init(void)
{
    delay_ms(15);            // 上电等待 >15ms
    lcd_write_cmd(0x38);    // 8位接口，双行，5×8 点阵
    lcd_write_cmd(0x0C);    // 显示开，光标关，闪烁关
    lcd_write_cmd(0x06);    // 写入后地址自增，不移屏
    lcd_write_cmd(0x01);    // 清屏
    delay_ms(2);
}

void main(void)
{
    lcd_init();

    lcd_goto(0, 0);                     // 第1行第0列
    lcd_print("C51 Learning");

    lcd_goto(0, 1);                     // 第2行第0列
    lcd_print("by SDCC + Trae");

    while (1)
    {
        /* 显示完成后保持，可在此加流水灯/按键逻辑 */
    }
}
