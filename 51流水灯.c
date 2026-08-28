/*
 * ===========================================================================
 *  51单片机流水灯控制程序（SDCC + 普中 STC89C52 开发板适配版）
 * ===========================================================================
 *  开发板硬件对应（以普中 A2/A3/A4 为参考，请按自己板子原理图核对）
 *  ----------------------------------------------------------
 *   - 主控芯片：STC89C52RC（DIP40）
 *   - 晶振    ：11.0592 MHz
 *   - LED     ：8个 LED 接 P2 口，共阳接法（低电平点亮）
 *   - 独立按键：K1~K4 接 P3.0~P3.3，按下为低电平
 *  ----------------------------------------------------------
 *  编译器：SDCC（Small Device C Compiler）
 *  编译命令：sdcc 51流水灯.c
 *  烧录：STC-ISP（Windows）或 stcgal（Linux: pip install stcgal）
 * ===========================================================================
 */
#include <mcs51/8052.h>    // SDCC 的 8052 寄存器定义（替代 Keil 的 reg52.h）

#define LED_PORT  P2        // 宏：LED 端口，换板子改这里
#define KEY_SPEED P3_0      // SDCC 位定义语法：P3_0（Keil 用 P3^0）

/* 循环左移 1 位的宏实现（SDCC 无 _crol_ 库函数）*/
#define CROL(c)  ((unsigned char)(((c) << 1) | ((c) >> 7)))

/* --------------------------------------------------------------------------
 *  延时函数：11.0592MHz 下粗略 1ms
 * -------------------------------------------------------------------------- */
void delay_ms(unsigned int ms)
{
    unsigned int i, j;
    for (i = 0; i < ms; i++)
        for (j = 0; j < 110; j++);
}

void main(void)
{
    unsigned char led = 0xFE;      // 1111 1110，P2.0 亮
    unsigned int  speed = 300;    // 流水间隔 ms（用 int，因 300/600 超过 unsigned char 范围）

    while (1)
    {
        LED_PORT = led;          // 输出到 LED
        delay_ms(speed);         // 延时

        led = CROL(led);         // 循环左移 1 位

        /* K1 三档调速 */
        if (KEY_SPEED == 0)
        {
            delay_ms(20);       // 消抖
            if (KEY_SPEED == 0)
            {
                if (speed == 300)      speed = 150;
                else if (speed == 150) speed = 600;
                else                  speed = 300;
                while (KEY_SPEED == 0); /* 松手检测 */
            }
        }
    }
}
