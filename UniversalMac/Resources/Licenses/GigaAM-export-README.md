---
license: mit
language:
- ru
- en
pipeline_tag: automatic-speech-recognition
tags:
  - asr
  - gigaam
  - stt
  - audio
  - speech
  - rnnt
  - ctc
---

# GigaAM-v3

[GigaAM-v3](https://github.com/salute-developers/GigaAM/) is a Conformer-based foundation model with 220–240M parameters, pretrained on diverse Russian speech data using the HuBERT-CTC objective.
It is the third generation of the GigaAM family and provides state-of-the-art performance on Russian ASR across a wide range of domains.

**Sherpa-ONNX Compatibility**: These models have been modified for use with the sherpa-onnx runtime. The ONNX files include embedded metadata and have been adapted to meet the inference engine requirements.

GigaAM-v3-sherpa-onnx includes the following model variants:
- `ctc` — ASR model fine-tuned with a CTC decoder  
- `rnnt` — ASR model fine-tuned with an RNN-T decoder 
- `e2e_ctc` — end-to-end CTC model with punctuation and text normalization  
- `e2e_rnnt` — end-to-end RNN-T model with punctuation and text normalization  

## Usage

```bash
./sherpa-onnx-offline-websocket-server \
--nemo-ctc-model=gigaam_v3_e2e_ctc.onnx \
--tokens=gigaam_v3_e2e_ctc_tokens.txt \
--port=6006
```

```bash
./sherpa-onnx-offline-websocket-server \
--encoder=gigaam_v3_e2e_rnnt_encoder.onnx \
--decoder=gigaam_v3_e2e_rnnt_decoder.onnx \
--joiner=gigaam_v3_e2e_rnnt_joint.onnx \
--tokens=gigaam_v3_e2e_rnnt_tokens.txt \
--port=6006
```

```python
import asyncio
import numpy
import wave
import websockets

SHERPA_ONNX_SERVER = "127.0.0.1:6006"

async def transcribe_audio(wave_filename: str):
    with wave.open(wave_filename, 'rb') as f:
        samples_int16 = numpy.frombuffer(f.readframes(-1), dtype=numpy.int16)
        samples_float32 = samples_int16.astype(numpy.float32) / 32768.0

    async with websockets.connect(f"ws://{SHERPA_ONNX_SERVER}") as websocket:
        buf = (16000).to_bytes(4, "little")
        buf+= (samples_float32.nbytes).to_bytes(4, "little")
        buf+= samples_float32.tobytes()
        payload_len = 10240
        for i in range(0, len(buf), payload_len):
            await websocket.send(buf[i : i + payload_len])

        result = await websocket.recv()
        await websocket.send("Done")
        return result

answer = asyncio.run(transcribe_audio("example.wav"))
print(answer)
```

**License:** MIT

**Paper:** [GigaAM: Efficient Self-Supervised Learner for Speech Recognition (InterSpeech 2025)](https://arxiv.org/abs/2506.01192)