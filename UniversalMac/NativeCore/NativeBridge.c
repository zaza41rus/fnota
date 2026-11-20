#include "include/NativeBridge.h"
#include "sherpa-c-api.h"
#include <stdlib.h>
#include <string.h>
char *UMRecognizeWithDecoder(const char *model, const char *decoder, const char *tokens, const float *samples, int32_t count, int32_t sample_rate) {
  if (!model || !tokens || !samples || count < 1) return NULL;
  SherpaOnnxOfflineRecognizerConfig config = {0};
  config.feat_config.sample_rate = 16000;
  config.feat_config.feature_dim = decoder ? 80 : 64;
  if (decoder) {
    config.model_config.whisper.encoder = model;
    config.model_config.whisper.decoder = decoder;
    config.model_config.whisper.task = "transcribe";
    config.model_config.whisper.language = "";
    config.model_config.whisper.tail_paddings = -1;
  } else { config.model_config.nemo_ctc.model = model; }
  config.model_config.tokens = tokens;
  config.model_config.num_threads = 4;
  config.model_config.provider = "cpu";
  config.decoding_method = "greedy_search";
  const SherpaOnnxOfflineRecognizer *r = SherpaOnnxCreateOfflineRecognizer(&config);
  if (!r) return NULL;
  const SherpaOnnxOfflineStream *s = SherpaOnnxCreateOfflineStream(r);
  if (!s) { SherpaOnnxDestroyOfflineRecognizer(r); return NULL; }
  SherpaOnnxAcceptWaveformOffline(s, sample_rate, samples, count);
  SherpaOnnxDecodeOfflineStream(r,s);
  const SherpaOnnxOfflineRecognizerResult *result = SherpaOnnxGetOfflineStreamResult(s);
  char *text = result && result->text ? strdup(result->text) : NULL;
  if (result) SherpaOnnxDestroyOfflineRecognizerResult(result);
  SherpaOnnxDestroyOfflineStream(s);
  SherpaOnnxDestroyOfflineRecognizer(r);
  return text;
}
char *UMRecognize(const char *model, const char *tokens, const float *samples, int32_t count, int32_t sample_rate) {
 return UMRecognizeWithDecoder(model,NULL,tokens,samples,count,sample_rate);
}
void UMFree(char *text) { free(text); }

#include <stdio.h>
void *UMCreateSpeechRecognizer(const char *folder, int32_t architecture) {
 if (!folder || architecture < 0 || architecture > 3) return NULL;
 char model[4096],decoder[4096],joiner[4096],tokens[4096];
 if (snprintf(model,sizeof(model),"%s/model.onnx",folder)>=sizeof(model) ||
     snprintf(decoder,sizeof(decoder),"%s/decoder.onnx",folder)>=sizeof(decoder) ||
     snprintf(joiner,sizeof(joiner),"%s/joiner.onnx",folder)>=sizeof(joiner) ||
     snprintf(tokens,sizeof(tokens),"%s/tokens.txt",folder)>=sizeof(tokens)) return NULL;
 SherpaOnnxOfflineRecognizerConfig config={0};
 config.feat_config.sample_rate=16000;
 config.feat_config.feature_dim=architecture==0 ? 64 : 80;
 config.model_config.tokens=tokens;
 config.model_config.num_threads=4;
 config.model_config.provider="cpu";
 config.decoding_method="greedy_search";
 switch(architecture) {
  case 0:config.model_config.nemo_ctc.model=model;break;
  case 1:
   config.model_config.whisper.encoder=model;config.model_config.whisper.decoder=decoder;
   config.model_config.whisper.task="transcribe";config.model_config.whisper.language="";
   config.model_config.whisper.tail_paddings=-1;break;
  case 2:
   config.model_config.transducer.encoder=model;config.model_config.transducer.decoder=decoder;
   config.model_config.transducer.joiner=joiner;config.model_config.model_type="nemo_transducer";break;
  case 3:
   config.model_config.sense_voice.model=model;config.model_config.sense_voice.language="auto";
   config.model_config.sense_voice.use_itn=1;break;
 }
 return (void *)SherpaOnnxCreateOfflineRecognizer(&config);
}
char *UMTranscribeSpeech(void *recognizer,const float *samples,int32_t count,int32_t sample_rate) {
 if (!recognizer || !samples || count<1 || sample_rate<1) return NULL;
 const SherpaOnnxOfflineRecognizer *r=recognizer;
 const SherpaOnnxOfflineStream *s=SherpaOnnxCreateOfflineStream(r);
 if (!s) return NULL;
 SherpaOnnxAcceptWaveformOffline(s,sample_rate,samples,count);
 SherpaOnnxDecodeOfflineStream(r,s);
 const SherpaOnnxOfflineRecognizerResult *result=SherpaOnnxGetOfflineStreamResult(s);
 char *text=result && result->text ? strdup(result->text) : NULL;
 if (result) SherpaOnnxDestroyOfflineRecognizerResult(result);
 SherpaOnnxDestroyOfflineStream(s);
 return text;
}
void UMDestroySpeechRecognizer(void *recognizer) {
 if (recognizer) SherpaOnnxDestroyOfflineRecognizer(recognizer);
}
