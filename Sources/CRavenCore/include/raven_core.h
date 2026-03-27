#ifndef RAVEN_CORE_H
#define RAVEN_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

const char* raven_core_version(void);
int raven_core_init(void);
const char* raven_core_platform_name(void);
char* raven_core_os_version(void);
void raven_core_free_string(char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* RAVEN_CORE_H */
