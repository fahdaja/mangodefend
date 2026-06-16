"""
Malware Scanner - ONNX ONLY
Optimized for fast startup & optimized full scan
"""

import os
import numpy as np
from PIL import Image
from datetime import datetime
from pathlib import Path
import psutil
import hashlib

from utils.file_converter import FileConverter

try:
    import onnxruntime as ort
except ImportError:
    raise RuntimeError("Install onnxruntime first")

DEFAULT_MODEL_PATH = "models/Modelv3.onnx"
CLASS_NAMES = ["Benign", "Malware"]

# Max file size allowed for scanning (10 MB)
_MAX_FILE_SIZE: int = 10 * 1024 * 1024

# Extensions treated as potentially dangerous executables
_DANGEROUS_EXTENSIONS = frozenset({
    ".exe", ".dll", ".scr", ".bat", ".cmd",
    ".ps1", ".vbs", ".js", ".jar",
    ".msi", ".com", ".pif", ".wsf", ".hta",
    ".cpl", ".sys", ".drv", ".bin", ".dat",
})


class MalwareScanner:
    def __init__(self, model_path: str | None = None):
        if model_path is None:
            base_dir = Path(__file__).resolve().parent.parent
            model_path = base_dir / DEFAULT_MODEL_PATH

        self.model_path = str(model_path)
        self.session = None
        self.device = "CPU"
        self.converter = FileConverter()
        self._aggressive = False

    # ====================================================
    # LOAD MODEL
    # ====================================================
    def load_model(self, aggressive: bool = False):
        # Reload session if mode changes
        if self.session is not None and aggressive == self._aggressive:
            return

        self._aggressive = aggressive
        self.session = None

        if not os.path.exists(self.model_path):
            raise FileNotFoundError(self.model_path)

        providers = ["CPUExecutionProvider"]
        if "CUDAExecutionProvider" in ort.get_available_providers():
            providers.insert(0, "CUDAExecutionProvider")
            self.device = "CUDA"

        cpu_count = psutil.cpu_count(logical=True)

        sess_options = ort.SessionOptions()

        if aggressive:
            # Full device scan: higher parallelism for faster throughput
            sess_options.intra_op_num_threads = min(4, cpu_count)
            sess_options.execution_mode = ort.ExecutionMode.ORT_PARALLEL
        else:
            # Realtime / single scan: conservative threading to avoid overhead
            sess_options.intra_op_num_threads = min(2, cpu_count)
            sess_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL

        sess_options.inter_op_num_threads = 1
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC

        self.session = ort.InferenceSession(
            self.model_path,
            providers=providers,
            sess_options=sess_options
        )

    # ====================================================
    # SCAN FILE
    # ====================================================
    def scan_file(self, file_path: str, is_full_scan: bool = False) -> dict:
        self.load_model(aggressive=is_full_scan)

        file_path_obj = Path(file_path)
        is_image = file_path_obj.suffix.lower() in [".png", ".jpg", ".jpeg"]

        if is_image:
            image_path = file_path
        else:
            conversion = self.converter.convert_file_to_image(file_path)
            image_path = conversion["output_image"]

        image = Image.open(image_path).convert("L")
        output, predicted = self._predict(image)

        if not is_image and os.path.exists(image_path):
            try:
                os.remove(image_path)
            except OSError:
                pass

        return {
            "result": CLASS_NAMES[predicted],
            "timestamp": datetime.now().strftime("%d-%m-%Y %H:%M:%S"),
            "model": {
                "model": Path(self.model_path).name,
                "predicted_output": output,
            },
            "device": {
                "device": self.device,
            },
            "file": {
                "file_name": file_path_obj.name,
                "file_path": str(file_path),
                "file_size": os.path.getsize(file_path),
                "file_hash": self._hash_file(file_path),
            },
        }

    # ====================================================
    # ONNX INFERENCE
    # ====================================================
    def _predict(self, image: Image.Image):
        image = image.resize((224, 224))
        img = np.array(image).astype(np.float32) / 255.0
        img = np.stack([img] * 3, axis=0)
        img = np.expand_dims(img, axis=0)

        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name
        result = self.session.run([output_name], {input_name: img})

        output = result[0][0]
        predicted = int(np.argmax(output))
        return output.tolist(), predicted

    def _hash_file(self, file_path: str) -> str:
        sha256 = hashlib.sha256()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256.update(chunk)
            return sha256.hexdigest()
        except OSError:
            return hashlib.sha256(file_path.encode()).hexdigest()
