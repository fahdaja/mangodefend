# app/ml/engine.py
import numpy as np
import onnxruntime as ort
from PIL import Image
from pathlib import Path


# Label mapping — sesuaikan dengan label yang digunakan saat training
LABELS = ["benign", "malware"]

# Path ke file model ONNX
MODEL_PATH = Path(__file__).parent / "Modelv2.onnx"

# Input size yang diharapkan model (width, height) — sesuaikan jika berbeda
MODEL_INPUT_SIZE = (224, 224)


class MalwareDetectionEngine:
    """
    Engine untuk inferensi deteksi malware menggunakan ONNX Runtime.
    Model di-load sekali saat inisialisasi agar efisien.
    """

    def __init__(self):
        if not MODEL_PATH.exists():
            raise FileNotFoundError(f"Model tidak ditemukan di: {MODEL_PATH}")

        self.session = ort.InferenceSession(
            str(MODEL_PATH),
            providers=["CPUExecutionProvider"],
        )
        self.input_name = self.session.get_inputs()[0].name
        self.input_shape = self.session.get_inputs()[0].shape  # e.g. [1, 1, 224, 224]

    def _preprocess(self, image: Image.Image) -> np.ndarray:
        """
        Preprocess grayscale PIL Image menjadi numpy array
        yang siap untuk inferensi ONNX.
        Model mengharapkan input shape: [batch, 3, 224, 224]
        """
        # Resize ke ukuran yang diharapkan model
        image = image.resize(MODEL_INPUT_SIZE, Image.Resampling.BILINEAR)

        # Konversi grayscale (L) ke RGB dengan menduplikasi channel
        if image.mode == "L":
            image = image.convert("RGB")

        # Convert ke numpy float32 dan normalisasi [0, 255] -> [0.0, 1.0]
        arr = np.array(image, dtype=np.float32) / 255.0

        # Transpose: (H, W, C) -> (C, H, W), lalu tambahkan batch dimension
        arr = arr.transpose(2, 0, 1)  # (3, 224, 224)
        arr = np.expand_dims(arr, axis=0)  # (1, 3, 224, 224)

        return arr

    def predict(self, image: Image.Image) -> str:
        """
        Jalankan inferensi pada sebuah grayscale image.

        Returns:
            str: file_name
            str: file_size
            str: "malware" atau "benign"
        """
        input_tensor = self._preprocess(image)

        outputs = self.session.run(None, {self.input_name: input_tensor})

        raw_output = outputs[0][0]  # Ambil batch pertama
        predicted_index = int(np.argmax(raw_output))

        return LABELS[predicted_index]


# Singleton instance — di-import oleh service layer
engine = MalwareDetectionEngine()
