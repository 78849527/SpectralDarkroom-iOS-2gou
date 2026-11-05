// Deliberately replaces the native C++/Metal renderer for UI/dyld isolation.
// Not a production render implementation. No malloc, global initialization,
// or Metal framework dependencies.
#include "spektrafilm/spk_engine.h"

spk_engine* spk_engine_create(const char* dir, void* device) {
    (void)dir; (void)device;
    return (spk_engine*)0;
}
const char* spk_last_error(spk_engine* engine) {
    (void)engine;
    return "Diagnostic: native C++/Metal engine intentionally not linked";
}
spk_session* spk_open(spk_engine* e, const spk_image* input,
                      const char* delta, char** reply) {
    (void)e; (void)input; (void)delta;
    if (reply) *reply = 0;
    return (spk_session*)0;
}
spk_status spk_reprint(spk_session* s, const char* tier, spk_result* out) {
    (void)s; (void)tier; (void)out;
    return (spk_status)-1;
}
void spk_result_free(spk_result* out) { (void)out; }
void spk_session_release(spk_session* s) { (void)s; }
void spk_string_free(char* s) { (void)s; }
