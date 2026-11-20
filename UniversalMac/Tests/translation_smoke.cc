#include "../NativeCore/include/NativeBridge.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
int main(int argc,char **argv){if(argc!=2)return 2; auto base=std::string(argv[1]);void *h=UMCreateTranslator((base+"/model").c_str(),(base+"/sentencepiece.model").c_str());if(!h)return 3;char *text=UMTranslate(h,"The application works without the internet.");if(!text)return 4;puts(text);bool ok=strstr(text,"интернет")!=nullptr;free(text);UMDestroyTranslator(h);return ok?0:5;}
