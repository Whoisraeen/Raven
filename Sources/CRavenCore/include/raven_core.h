#ifndef RAVEN_CORE_H
#define RAVEN_CORE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

const char* raven_core_version(void);
int raven_core_init(void);
const char* raven_core_platform_name(void);
char* raven_core_os_version(void);
const char* raven_core_last_error(void);
void raven_core_free_string(char* ptr);

/* Platform API - Clipboard */
char* raven_clipboard_get_text(void);
int raven_clipboard_set_text(const char* text);

/* Platform API - File Dialogs */
char* raven_file_dialog_open(const char* title, const char* filter);
char* raven_file_dialog_save(const char* title, const char* default_name);
char* raven_file_dialog_select_folder(const char* title);

/* Platform API - Notifications */
int raven_notification_show(const char* title, const char* body);

/* Platform API - System Tray */
typedef void (*RavenTrayCallback)(void);
void raven_tray_add(const char* title, const char* icon_path, RavenTrayCallback on_click);
void raven_tray_remove(void);

/* Platform API - Window Controls */
void raven_window_minimize(void* hwnd);
void raven_window_maximize(void* hwnd);
void raven_window_close(void* hwnd);
void raven_window_set_borderless(void* hwnd, bool borderless);

#ifdef __cplusplus
}
#endif

#endif /* RAVEN_CORE_H */
