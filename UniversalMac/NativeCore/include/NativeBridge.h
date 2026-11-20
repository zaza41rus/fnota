#pragma once
#include <stdint.h>
char *UMRecognize(const char *model, const char *tokens, const float *samples, int32_t count, int32_t sample_rate);
char *UMRecognizeWithDecoder(const char *model, const char *decoder, const char *tokens, const float *samples, int32_t count, int32_t sample_rate);
void UMFree(char *text);
#ifdef __cplusplus
extern "C" {
#endif
void *UMCreateTranslator(const char *model, const char *spm);
char *UMTranslate(void *translator, const char *text);
char *UMTranslateTokens(void *translator, const char *tokens);
void UMDestroyTranslator(void *translator);
#ifdef __cplusplus
}
#endif

void *UMCreateSpeechRecognizer(const char *folder, int32_t architecture);
char *UMTranscribeSpeech(void *recognizer, const float *samples, int32_t count, int32_t sample_rate);
void UMDestroySpeechRecognizer(void *recognizer);
