"""
File Converter - Convert binary files to images for ML processing
"""
import math
import numpy as np
from PIL import Image
from pathlib import Path
from datetime import datetime
import tempfile
import os


class FileConverter:
    def __init__(self, output_dir=None):
        # Use system temp directory if no output_dir specified
        if output_dir is None:
            output_dir = os.path.join(tempfile.gettempdir(), "mangodefend_temp")
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def calculate_width(file_size_kb: float) -> int:
        """
        Calculate optimal image width based on file size (UCSB method)

        Args:
            file_size_kb: File size in kilobytes

        Returns:
            int: Optimal width for the image
        """
        if file_size_kb < 10:
            return 32
        elif file_size_kb < 30:
            return 64
        elif file_size_kb < 60:
            return 128
        elif file_size_kb < 100:
            return 256
        elif file_size_kb < 200:
            return 384
        elif file_size_kb < 500:
            return 512
        elif file_size_kb < 1000:
            return 768
        elif file_size_kb < 10000:
            return 1024
        elif file_size_kb < 50000:
            return 2048
        elif file_size_kb < 100000:
            return 4096
        elif file_size_kb < 500000:
            return 8192
        else:
            return 16384

    @staticmethod
    def binary_to_matrix(byte_data: bytes, width: int) -> np.ndarray:
        """
        Convert binary data to 2D matrix

        Args:
            byte_data: Raw binary data
            width: Width of the resulting matrix

        Returns:
            np.ndarray: 2D matrix representation
        """
        byte_array = np.frombuffer(byte_data, dtype=np.uint8)
        height = math.ceil(len(byte_array) / width)
        padded = np.pad(byte_array, (0, width * height - len(byte_array)), "constant")
        return padded.reshape((height, width))

    def convert_file_to_image(
        self,
        file_path: str,
        width_override: int = None,
        color_mode: str = "gray"
    ) -> dict:
        """
        Convert a binary file to a grayscale image
        """
        file_path_obj = Path(file_path)

        # Read binary data
        with open(file_path, "rb") as f:
            binary_data = f.read()

        # Empty file – represent as a blank 32×32 image (no executable content)
        if len(binary_data) == 0:
            binary_data = bytes(32 * 32)

        # Calculate file size
        file_size_kb = len(binary_data) / 1024

        # Determine width
        width = width_override if width_override else self.calculate_width(file_size_kb)

        # Convert to matrix
        matrix = self.binary_to_matrix(binary_data, width)

        # Generate output filename
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        output_filename = f"{file_path_obj.stem}_{color_mode}_{timestamp}.png"
        output_path = self.output_dir / output_filename

        # Save image
        img = Image.fromarray(matrix.astype(np.uint8), mode="L")
        if color_mode == "rgb":
            img = img.convert("RGB")
        img.save(output_path)

        return {
            "original_filename": file_path_obj.name,
            "output_image": str(output_path),
            "color_mode": color_mode,
            "width": width,
            "size_kb": round(file_size_kb, 2),
        }
