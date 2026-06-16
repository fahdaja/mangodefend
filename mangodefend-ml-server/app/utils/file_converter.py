# app/utils/file_converter.py
import numpy as np
from PIL import Image
import math

class FileConverter:
    @staticmethod
    def get_width(file_size):
        """Menentukan lebar gambar berdasarkan ukuran file"""
        if file_size < 10 * 1024: return 32
        if file_size < 30 * 1024: return 64
        if file_size < 60 * 1024: return 128
        if file_size < 100 * 1024: return 256
        if file_size < 200 * 1024: return 384
        if file_size < 500 * 1024: return 512
        if file_size < 1000 * 1024: return 768
        return 1024

    @staticmethod
    def bytes_to_image(file_bytes: bytes) -> Image.Image:
        """
        Mengubah raw bytes menjadi Grayscale Image secara In-Memory.
        """
        # 1. Ubah bytes jadi numpy array uint8
        arr = np.frombuffer(file_bytes, dtype=np.uint8)
        
        # 2. Hitung dimensi
        file_size = len(arr)
        width = FileConverter.get_width(file_size)
        height = int(math.ceil(file_size / width))
        
        # 3. Padding array agar pas
        required_size = width * height
        if file_size < required_size:
            arr = np.pad(arr, (0, required_size - file_size), 'constant')
            
        # 4. Reshape & Create Image
        arr = arr.reshape((height, width))
        return Image.fromarray(arr, 'L')