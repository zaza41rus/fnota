#include "sherpa-c-api.h"
#include <stdio.h>
#include <string.h>
int main(int argc,char**v){
 if(argc!=4)return 2;
 char m[2048],d[2048],t[2048],j[2048];
 snprintf(m,sizeof(m),"%s/model.onnx",v[1]);snprintf(d,sizeof(d),"%s/decoder.onnx",v[1]);snprintf(t,sizeof(t),"%s/tokens.txt",v[1]);snprintf(j,sizeof(j),"%s/joiner.onnx",v[1]);
 SherpaOnnxOfflineRecognizerConfig c={0};c.feat_config.sample_rate=16000;c.feat_config.feature_dim=80;c.model_config.tokens=t;c.model_config.num_threads=4;c.model_config.provider="cpu";c.decoding_method="greedy_search";
 if(!strcmp(v[2],"whisper")){c.model_config.whisper.encoder=m;c.model_config.whisper.decoder=d;c.model_config.whisper.task="transcribe";c.model_config.whisper.language="";c.model_config.whisper.tail_paddings=-1;}
 else if(!strcmp(v[2],"parakeet")){c.model_config.transducer.encoder=m;c.model_config.transducer.decoder=d;c.model_config.transducer.joiner=j;c.model_config.model_type="nemo_transducer";}
 else if(!strcmp(v[2],"sense")){c.model_config.sense_voice.model=m;c.model_config.sense_voice.language="auto";c.model_config.sense_voice.use_itn=1;}
 else {c.feat_config.feature_dim=64;c.model_config.nemo_ctc.model=m;}
 const SherpaOnnxWave*w=SherpaOnnxReadWave(v[3]);if(!w)return 3;
 const SherpaOnnxOfflineRecognizer*r=SherpaOnnxCreateOfflineRecognizer(&c);if(!r)return 4;
 const SherpaOnnxOfflineStream*s=SherpaOnnxCreateOfflineStream(r);SherpaOnnxAcceptWaveformOffline(s,w->sample_rate,w->samples,w->num_samples);SherpaOnnxDecodeOfflineStream(r,s);
 const SherpaOnnxOfflineRecognizerResult*o=SherpaOnnxGetOfflineStreamResult(s);int ok=o&&o->text&&strlen(o->text);if(ok)puts(o->text);
 if(o)SherpaOnnxDestroyOfflineRecognizerResult(o);SherpaOnnxDestroyOfflineStream(s);SherpaOnnxDestroyOfflineRecognizer(r);SherpaOnnxFreeWave(w);return ok?0:5;
}
