#include "../NativeCore/include/NativeBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
 if(argc!=4)return 2;
 FILE *f=fopen(argv[3],"rb"); if(!f)return 3;
 unsigned char header[12]; if(fread(header,1,12,f)!=12)return 4;
 unsigned int size=0; char tag[4];
 while(fread(tag,1,4,f)==4 && fread(&size,4,1,f)==1){if(!memcmp(tag,"data",4))break;fseek(f,size+(size&1),SEEK_CUR);}
 int count=size/2;if(count<1600)return 5;
 short *pcm=malloc(size);float *samples=malloc(count*sizeof(float));
 if(fread(pcm,2,count,f)!=(size_t)count)return 6;fclose(f);
 for(int i=0;i<count;i++)samples[i]=pcm[i]/32768.0f;
 char *text=UMRecognize(argv[1],argv[2],samples,count,16000);
 if(!text)return 7;puts(text);
 int ok=strstr(text,"распознавание") && strstr(text,"без интернета");
 UMFree(text);free(pcm);free(samples);return ok?0:8;
}
