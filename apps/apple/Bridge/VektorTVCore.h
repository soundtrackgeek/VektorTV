#ifndef VEKTORTV_CORE_H
#define VEKTORTV_CORE_H
typedef struct AppleCore AppleCore;
// The handle supports concurrent requests. Close only after requests finish.
AppleCore *vektortv_core_open(const char *database_path);
// Each request returns owned UTF-8 JSON: {"value":...} or {"error":"..."}.
char *vektortv_core_request(AppleCore *core, const char *request_json);
void vektortv_string_free(char *value);
void vektortv_core_close(AppleCore *core);
#endif
