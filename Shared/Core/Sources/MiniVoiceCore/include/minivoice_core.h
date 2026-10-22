#ifndef MINIVOICE_CORE_H
#define MINIVOICE_CORE_H
#if defined(_WIN32)
#define MV_API __declspec(dllexport)
#else
#define MV_API __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
/* UTF-8 JSON contract v1. Output is owned by the caller; release with mv_core_free.
   No platform objects, files, audio, clocks or persistence enter the core. */
MV_API char *mv_core_execute(const char *request);
MV_API void mv_core_free(char *response);
MV_API int mv_core_contract_version(void);
#ifdef __cplusplus
}
#endif
#endif
