#ifndef RAVEN_CORE_H
#define RAVEN_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

const char* raven_core_version(void);
int raven_core_init(void);
const char* raven_core_platform_name(void);
char* raven_core_os_version(void);
const char* raven_core_last_error(void);
void raven_core_free_string(char* ptr);

/* Clipboard */
char* raven_core_clipboard_get(void);
int raven_core_clipboard_set(const char* text);

/* File Dialogs */
char* raven_core_open_file_dialog(const char* title, const char* filter);
char* raven_core_save_file_dialog(const char* title, const char* default_name);
char* raven_core_select_folder_dialog(const char* title);

#ifdef __cplusplus
}
#endif

#endif /* RAVEN_CORE_H */
