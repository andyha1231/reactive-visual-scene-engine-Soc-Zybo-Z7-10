/**
 * uart_menu.h
 * UART terminal menu interface for the Reactive Scene Engine.
 */

#ifndef UART_MENU_H
#define UART_MENU_H

/* Display the main menu */
void uart_menu_show(void);

/* Check for UART input and process commands. Non-blocking. */
void uart_menu_process(void);

#endif /* UART_MENU_H */
