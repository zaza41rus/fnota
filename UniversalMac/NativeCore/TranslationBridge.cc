#include "include/NativeBridge.h"
#include "ctranslate2/translator.h"
#include "sentencepiece_processor.h"
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <sstream>
struct TranslationHandle {
 ctranslate2::Translator translator;
 sentencepiece::SentencePieceProcessor tokenizer;
 TranslationHandle(const char *model, const char *spm):translator(model,ctranslate2::Device::CPU,ctranslate2::ComputeType::INT8) {
  if (spm) { auto status = tokenizer.Load(spm);if (!status.ok()) throw std::runtime_error(status.ToString()); }
 }
};
extern "C" void *UMCreateTranslator(const char *model, const char *spm) {
 try { return new TranslationHandle(model,spm); } catch (...) { return nullptr; }
}
extern "C" char *UMTranslate(void *raw, const char *text) {
 try {
  if (!raw || !text) return nullptr;
  auto *h = static_cast<TranslationHandle *>(raw);
  std::vector<std::string> tokens;
  if (!h->tokenizer.Encode(text,&tokens).ok()) return nullptr;
  ctranslate2::TranslationOptions options;
  options.beam_size = 1; options.max_decoding_length = 512;
  auto results = h->translator.translate_batch({tokens}, options);
  if (results.empty() || results[0].hypotheses.empty()) return nullptr;
  std::string output;
  if (!h->tokenizer.Decode(results[0].hypotheses[0],&output).ok()) return nullptr;
  return strdup(output.c_str());
 } catch (...) { return nullptr; }
}
extern "C" char *UMTranslateTokens(void *raw, const char *text) {
 try {
  if (!raw || !text) return nullptr;
  auto *h=static_cast<TranslationHandle *>(raw);
  std::vector<std::string> tokens;std::istringstream input(text);std::string token;
  while(std::getline(input,token)) { if(!token.empty()) tokens.push_back(token); }
  ctranslate2::TranslationOptions options;options.beam_size=1;options.max_decoding_length=512;
  auto results=h->translator.translate_batch({tokens},options);
  if(results.empty() || results[0].hypotheses.empty()) return nullptr;
  std::string output;
  for(const auto &piece:results[0].hypotheses[0]) { if(!output.empty()) output += "\n";output += piece; }
  return strdup(output.c_str());
 } catch (...) { return nullptr; }
}
extern "C" void UMDestroyTranslator(void *raw) { delete static_cast<TranslationHandle *>(raw); }
