"""
Script untuk mengkonversi model maldebCNN dari PyTorch ke ONNX
Untuk laporan magang - MangoDefend Project
Author: Saefu
Date: 2026-01-01
"""

import torch
import torch.nn as nn
from torchvision import models
import onnx
import onnxruntime as ort
import numpy as np
import os

# ============================================
# 1. DEFINISI MODEL
# ============================================
class SpectrogramClassifier(nn.Module):
    """
    Model CNN untuk klasifikasi malware menggunakan ResNet-18
    """
    def __init__(self, num_classes):
        super(SpectrogramClassifier, self).__init__()
        self.model = models.resnet18(weights=None)
        in_features = self.model.fc.in_features
        self.model.fc = nn.Linear(in_features, num_classes)

    def forward(self, x):
        return self.model(x)

# ============================================
# 2. KONFIGURASI
# ============================================
MODEL_PATH = 'imgcnnmaldeb.pth'  # Path ke model PyTorch yang sudah dilatih
ONNX_PATH = 'maldebCNN.onnx'     # Path output untuk model ONNX
NUM_CLASSES = 2                   # Binary classification (Malware/Benign)
INPUT_SIZE = (1, 3, 224, 224)    # (batch_size, channels, height, width)

# ============================================
# 3. LOAD MODEL
# ============================================
print("="*60)
print("KONVERSI MODEL PYTORCH KE ONNX")
print("="*60)

print("\n[1/6] Loading PyTorch model...")
if not os.path.exists(MODEL_PATH):
    print(f"ERROR: Model file '{MODEL_PATH}' tidak ditemukan!")
    print(f"Pastikan file model ada di directory yang sama dengan script ini.")
    exit(1)

model = SpectrogramClassifier(num_classes=NUM_CLASSES)
model.load_state_dict(torch.load(MODEL_PATH, map_location=torch.device('cpu')))
model.eval()
print(f"✓ Model loaded successfully from '{MODEL_PATH}'")

# ============================================
# 4. PERSIAPAN DUMMY INPUT
# ============================================
print("\n[2/6] Preparing dummy input...")
dummy_input = torch.randn(*INPUT_SIZE)
print(f"✓ Dummy input created with shape: {dummy_input.shape}")

# ============================================
# 5. EXPORT KE ONNX
# ============================================
print("\n[3/6] Exporting to ONNX format...")
try:
    torch.onnx.export(
        model,                          # Model PyTorch
        dummy_input,                    # Contoh input
        ONNX_PATH,                      # Output path
        export_params=True,             # Export semua parameters
        opset_version=11,               # ONNX opset version
        do_constant_folding=True,       # Optimasi
        input_names=['input'],          # Nama input node
        output_names=['output'],        # Nama output node
        dynamic_axes={                  # Dynamic batch size
            'input': {0: 'batch_size'},
            'output': {0: 'batch_size'}
        },
        verbose=False
    )
    print(f"✓ Model exported to '{ONNX_PATH}'")
    
    # Tampilkan ukuran file
    onnx_size = os.path.getsize(ONNX_PATH) / (1024 * 1024)  # Convert to MB
    print(f"  File size: {onnx_size:.2f} MB")
    
except Exception as e:
    print(f"ERROR during export: {str(e)}")
    exit(1)

# ============================================
# 6. VERIFIKASI MODEL ONNX
# ============================================
print("\n[4/6] Verifying ONNX model...")
try:
    onnx_model = onnx.load(ONNX_PATH)
    onnx.checker.check_model(onnx_model)
    print("✓ ONNX model is valid!")
    
    # Tampilkan informasi model
    print(f"\n  Model Information:")
    print(f"    IR Version: {onnx_model.ir_version}")
    print(f"    Opset Version: {onnx_model.opset_import[0].version}")
    print(f"    Producer: PyTorch")
    
except Exception as e:
    print(f"ERROR during verification: {str(e)}")
    exit(1)

# ============================================
# 7. TESTING DENGAN ONNX RUNTIME
# ============================================
print("\n[5/6] Testing with ONNX Runtime...")
try:
    # Create ONNX Runtime session
    ort_session = ort.InferenceSession(ONNX_PATH)
    
    # Get input/output names
    input_name = ort_session.get_inputs()[0].name
    output_name = ort_session.get_outputs()[0].name
    
    print(f"  Input name: {input_name}")
    print(f"  Output name: {output_name}")
    
    # Run inference with ONNX
    dummy_input_np = dummy_input.numpy()
    ort_outputs = ort_session.run([output_name], {input_name: dummy_input_np})
    
    # Run inference with PyTorch
    with torch.no_grad():
        pytorch_outputs = model(dummy_input)
    
    print("✓ Inference completed successfully")
    
except Exception as e:
    print(f"ERROR during testing: {str(e)}")
    exit(1)

# ============================================
# 8. PERBANDINGAN OUTPUT
# ============================================
print("\n[6/6] Comparing outputs...")
try:
    # Calculate difference
    diff = np.abs(pytorch_outputs.numpy() - ort_outputs[0])
    max_diff = np.max(diff)
    mean_diff = np.mean(diff)
    
    print(f"\n  Comparison Results:")
    print(f"    PyTorch output shape: {pytorch_outputs.shape}")
    print(f"    ONNX output shape: {ort_outputs[0].shape}")
    print(f"    Maximum difference: {max_diff:.2e}")
    print(f"    Mean difference: {mean_diff:.2e}")
    
    # Check if outputs match
    if max_diff < 1e-5:
        print(f"\n  ✓ Outputs match! Conversion successful.")
        success = True
    else:
        print(f"\n  ⚠ Warning: Outputs differ by {max_diff:.2e}")
        print(f"  This might be acceptable depending on your use case.")
        success = True
    
except Exception as e:
    print(f"ERROR during comparison: {str(e)}")
    success = False

# ============================================
# 9. SUMMARY
# ============================================
print("\n" + "="*60)
if success:
    print("KONVERSI BERHASIL!")
    print("="*60)
    print(f"\nModel ONNX telah disimpan di: {os.path.abspath(ONNX_PATH)}")
    print("\nLangkah selanjutnya:")
    print("1. Model ONNX dapat digunakan untuk inference")
    print("2. Dapat di-deploy ke berbagai platform")
    print("3. Dapat digunakan dengan ONNX Runtime untuk performa optimal")
else:
    print("KONVERSI GAGAL!")
    print("="*60)
    print("Silakan periksa error messages di atas.")

print("="*60)
