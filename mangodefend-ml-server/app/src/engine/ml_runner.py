import os
import io
import math
import logging
from typing import Tuple
import numpy as np
from PIL import Image

logger = logging.getLogger("mangodefend.ml_runner")

ONNX_MODEL_PATH = os.getenv("ONNX_MODEL_PATH", "app/src/engine/models/malware_model.onnx")


class BinaryToImageTransformer:
    """
    Mengonversi file biner (Windows EXE/DLL, Android APK/DEX/SO) menjadi citra Grayscale/RGB
    (Malware Visualization Matrix) untuk inferensi model ML berbasis Computer Vision / Image Classification.
    """

    @classmethod
    def bytes_to_png_bytes(cls, file_bytes: bytes, target_size: Tuple[int, int] = (224, 224)) -> bytes:
        """Mengonversi byte biner file menjadi citra PNG 2D Grayscale matrix untuk dataset training."""
        img = cls.bytes_to_image(file_bytes, target_size=target_size)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    @staticmethod
    def bytes_to_image(file_bytes: bytes, target_size: Tuple[int, int] = (224, 224)) -> Image.Image:
        """Mengonversi byte mentah file menjadi objek PIL Image Grayscale dan di-resize ke target_size."""
        if not file_bytes:
            return Image.new("L", target_size, color=0)

        byte_array = np.frombuffer(file_bytes, dtype=np.uint8)
        size = len(byte_array)

        if size < 10 * 1024:
            width = 32
        elif size < 30 * 1024:
            width = 64
        elif size < 60 * 1024:
            width = 128
        elif size < 100 * 1024:
            width = 256
        elif size < 200 * 1024:
            width = 384
        else:
            width = 512

        height = int(np.ceil(size / width))
        padded_len = width * height

        if len(byte_array) < padded_len:
            byte_array = np.pad(byte_array, (0, padded_len - len(byte_array)), mode='constant')

        image_matrix = byte_array[:padded_len].reshape((height, width))
        img = Image.fromarray(image_matrix, mode="L")
        return img.resize(target_size, Image.Resampling.BILINEAR)

    @classmethod
    def bytes_to_tensor(
        cls,
        file_bytes: bytes,
        target_size: Tuple[int, int] = (224, 224),
        num_channels: int = 3
    ) -> np.ndarray:
        """Mengonversi byte file menjadi NumPy Tensor Siap Pakai untuk ONNX Vision Model. Shape: (1, 3, 224, 224)."""
        img = cls.bytes_to_image(file_bytes, target_size=target_size)
        img_np = np.array(img, dtype=np.float32) / 255.0

        if num_channels == 3:
            img_tensor = np.stack([img_np] * 3, axis=0)
        else:
            img_tensor = np.expand_dims(img_np, axis=0)

        return np.expand_dims(img_tensor, axis=0)


class MLInferenceEngine:
    """
    Engine Inferensi Image-based Machine Learning untuk Platform Windows & Android.
    Mengonversi file biner menjadi citra gambar dan melakukan vonis klasifikasi.
    """

    def __init__(self, model_path: str = ONNX_MODEL_PATH):
        self.model_path = model_path
        self.session = None
        self._load_model()

    def _load_model(self):
        if os.path.exists(self.model_path):
            try:
                import onnxruntime as ort
                self.session = ort.InferenceSession(self.model_path)
                logger.info(f"[MLEngine] Loaded Image-based ONNX model from {self.model_path}")
            except Exception as e:
                logger.error(f"[MLEngine] Failed to load ONNX model: {e}")
                self.session = None
        else:
            logger.info(f"[MLEngine] Image ONNX model not found at {self.model_path}. Using Fallback Engine.")

    def predict(self, file_bytes: bytes) -> str:
        """
        Mengonversi biner file (Windows / Android) menjadi Tensor Citra Gambar (1, 3, 224, 224)
        lalu mengeksekusi inferensi pada ONNX Vision Model.
        
        Returns:
            str: "MALICIOUS" atau "BENIGN"
        """
        if self.session is not None:
            try:
                input_tensor = BinaryToImageTransformer.bytes_to_tensor(
                    file_bytes,
                    target_size=(224, 224),
                    num_channels=3
                )
                input_name = self.session.get_inputs()[0].name
                outputs = self.session.run(None, {input_name: input_tensor})
                
                predicted_class = int(np.argmax(outputs[0]))
                return "MALICIOUS" if predicted_class == 1 else "BENIGN"

            except Exception as e:
                logger.error(f"[MLEngine] ONNX Image Model inference error: {e}. Falling back to heuristic.")

        # Fallback Heuristik berbasis Entropi & Format File
        if not file_bytes:
            return "BENIGN"

        byte_counts = [0] * 256
        for b in file_bytes:
            byte_counts[b] += 1
        entropy = 0.0
        total = len(file_bytes)
        for count in byte_counts:
            if count > 0:
                p = count / total
                entropy -= p * math.log2(p)

        is_windows_pe = file_bytes.startswith(b"MZ")
        is_android_dex = file_bytes.startswith(b"dex\n")
        is_android_so = file_bytes.startswith(b"\x7fELF")

        if entropy > 7.15 and total > 1024:
            return "MALICIOUS"
        elif (is_windows_pe or is_android_dex or is_android_so) and entropy > 6.8:
            return "MALICIOUS"
        else:
            return "BENIGN"


# Singleton Instance Engine
ml_engine = MLInferenceEngine()
