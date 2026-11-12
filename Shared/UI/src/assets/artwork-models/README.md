# PP-OCRv4 mobile text detector

- Model: `ppocr-v4-text-det.onnx`, 4,745,517 bytes.
- Source: https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv4/det/ch_PP-OCRv4_det_mobile.onnx
- Upstream manifest: https://github.com/RapidAI/RapidOCR/blob/main/python/rapidocr/default_models.yaml
- SHA-256: `d2a7720d45a54257208b1e13e36a8479894cb74155a5efe29462512d42f49da9`
- License: Apache License 2.0, see https://huggingface.co/SWHL/RapidOCR and https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE . Original model by PaddlePaddle/PaddleOCR. The ONNX conversion is redistributed by RapidOCR.
- This model locates text regions only; it does not recognize text contents. `artworkTextDetector.js` applies an independently implemented bounded component approximation of DB postprocessing.
