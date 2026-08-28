/*
 * ===========================================================================
 *  51单片机双向流水灯控制程序（SDCC + 普中 STC89C52 开发板适配版）
 * ===========================================================================
 *  硬件：8 LED 接 P2 口，共阳；K1/K2 接 P3.0/P3.1
 *  晶振：11.0592 MHz
 *  编译：sdcc 51双向流水灯.c
 * ===========================================================================
 */
#include <mcs51/8052.h>

#define LED_PORT  P2
#define KEY_DIR   P3_0     // K1 切换方向
#define KEY_SPEED P3_1     // K2 切换速度

/* 循环左/右移 1 位的宏（SDCC 无 _crol_/_cror_）*/
#define CROL(c)  ((unsigned char)(((c) << 1) | ((c) >> 7)))
#define CROR(c)  ((unsigned char)(((c) >> 1) | ((c) << 7)))

void delay_ms(unsigned int ms)
{
    unsigned int i, j;
    for (i = 0; i < ms; i++)
        for (j = 0; j < 110; j++);
}

void main(void)
{
    unsigned char led   = 0xFE;   // 1111 1110，P2.0 亮
    unsigned char dir   = 0;      // 0=左移，1=右移
    unsigned int  speed = 300;   // 用 int，因 300/600 超过 unsigned char 范围

    while (1)
    {
        LED_PORT = led;
        delay_ms(speed);

        /* ---------- 双向移位 ---------- */
        if (dir == 0)
        {
            led = CROL(led);
            if (led == 0x7F) dir = 1;     // 到 P2.7 切换
        }
        else
        {
            led = CROR(led);
            if (led == 0xFE) dir = 0;     // 回 P2.0 切换
        }

        /* K1 切换方向 */
        if (KEY_DIR == 0)
        {
            delay_ms(20);
            if (KEY_DIR == 0)
            {
                dir = !dir;
                while (KEY_DIR == 0);
            }
        }

        /* K2 切换速度档 */
        if (KEY_SPEED == 0)
        {
            delay_ms(20);
            if (KEY_SPEED == 0)
            {
                if (speed == 300)      speed = 150;
                else if (speed == 150) speed = 600;
                else                  speed = 300;
                while (KEY_SPEED == 0);
            }
        }
    }
}
