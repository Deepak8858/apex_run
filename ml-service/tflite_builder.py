"""
ApexRun TFLite Model Builder — On-Device ML Model Generation

Builds, trains, and exports TensorFlow Lite models for on-device inference:
1. Gait Analysis Model     → Running form scoring from pose landmarks
2. Injury Risk Model       → Injury risk prediction from biomechanics
3. Performance Model       → Race time prediction from training data

All models are quantized for mobile deployment (int8/float16).
"""

import os
import numpy as np
import tensorflow as tf
from pathlib import Path
from typing import Tuple, Optional

# Output directory for exported .tflite files
MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)


# ================================================================
# Synthetic Training Data Generators
# ================================================================

def generate_gait_training_data(n_samples: int = 5000) -> Tuple[np.ndarray, np.ndarray]:
    """
    Generate synthetic gait biomechanics data for form score prediction.

    Features (8):
        0: ground_contact_time_ms   (180-350)
        1: vertical_oscillation_cm  (5-15)
        2: cadence_spm              (140-200)
        3: stride_length_m          (0.7-1.5)
        4: forward_lean_degrees     (2-15)
        5: hip_drop_degrees         (2-12)
        6: arm_swing_symmetry_pct   (70-100)
        7: avg_pace_min_per_km      (3.5-8.0)

    Labels: form_score (0-100)
    """
    np.random.seed(42)

    gct = np.random.uniform(180, 350, n_samples)
    osc = np.random.uniform(5, 15, n_samples)
    cadence = np.random.uniform(140, 200, n_samples)
    stride = np.random.uniform(0.7, 1.5, n_samples)
    lean = np.random.uniform(2, 15, n_samples)
    hip_drop = np.random.uniform(2, 12, n_samples)
    arm_sym = np.random.uniform(70, 100, n_samples)
    pace = np.random.uniform(3.5, 8.0, n_samples)

    # Form score heuristic (higher is better)
    score = (
        30 * np.clip((cadence - 140) / 60, 0, 1)            # Higher cadence = better
        + 20 * np.clip((300 - gct) / 120, 0, 1)             # Lower GCT = better
        + 15 * np.clip((12 - osc) / 7, 0, 1)                # Lower oscillation = better
        + 10 * np.clip((10 - hip_drop) / 8, 0, 1)           # Lower hip drop = better
        + 10 * np.clip((arm_sym - 70) / 30, 0, 1)           # Higher symmetry = better
        + 10 * np.clip((10 - lean) / 8, 0, 1)               # Moderate lean = better
        + 5  * np.clip((1.3 - stride) / 0.6, 0, 1)          # Moderate stride = better
    )
    score = np.clip(score + np.random.normal(0, 3, n_samples), 0, 100)

    X = np.column_stack([gct, osc, cadence, stride, lean, hip_drop, arm_sym, pace]).astype(np.float32)
    y = score.astype(np.float32)

    return X, y


def generate_injury_risk_data(n_samples: int = 5000) -> Tuple[np.ndarray, np.ndarray]:
    """
    Generate synthetic data for injury risk classification.

    Features (7):
        0: ground_contact_time_ms
        1: vertical_oscillation_cm
        2: cadence_spm
        3: stride_length_m
        4: hip_drop_degrees
        5: weekly_distance_km
        6: acute_chronic_ratio

    Labels: risk_level (0=low, 1=moderate, 2=high)
    """
    np.random.seed(43)

    gct = np.random.uniform(180, 350, n_samples)
    osc = np.random.uniform(5, 15, n_samples)
    cadence = np.random.uniform(140, 200, n_samples)
    stride = np.random.uniform(0.7, 1.5, n_samples)
    hip_drop = np.random.uniform(2, 12, n_samples)
    weekly_km = np.random.uniform(5, 120, n_samples)
    acwr = np.random.uniform(0.5, 2.0, n_samples)

    # Risk score based on biomechanics + training load
    risk = (
        0.15 * np.clip((gct - 250) / 100, 0, 1)
        + 0.15 * np.clip((osc - 10) / 5, 0, 1)
        + 0.15 * np.clip((170 - cadence) / 30, 0, 1)
        + 0.1  * np.clip((stride - 1.1) / 0.4, 0, 1)
        + 0.15 * np.clip((hip_drop - 6) / 6, 0, 1)
        + 0.1  * np.clip((weekly_km - 60) / 60, 0, 1)
        + 0.2  * np.clip((acwr - 1.3) / 0.7, 0, 1)
    )
    risk += np.random.normal(0, 0.05, n_samples)
    risk = np.clip(risk, 0, 1)

    # Convert to classes
    labels = np.zeros(n_samples, dtype=np.int32)
    labels[risk >= 0.3] = 1  # moderate
    labels[risk >= 0.6] = 2  # high

    X = np.column_stack([gct, osc, cadence, stride, hip_drop, weekly_km, acwr]).astype(np.float32)

    return X, labels


def generate_performance_data(n_samples: int = 5000) -> Tuple[np.ndarray, np.ndarray]:
    """
    Generate synthetic training data for race time prediction.

    Features (6):
        0: weekly_distance_km
        1: avg_pace_min_per_km
        2: run_count_per_week
        3: longest_run_km
        4: resting_heart_rate
        5: hrv_rmssd

    Labels: predicted_5k_seconds
    """
    np.random.seed(44)

    weekly_km = np.random.uniform(10, 100, n_samples)
    pace = np.random.uniform(3.5, 8.0, n_samples)
    runs_per_week = np.random.uniform(2, 7, n_samples)
    longest_run = np.random.uniform(3, 30, n_samples)
    rhr = np.random.uniform(40, 80, n_samples)
    hrv = np.random.uniform(20, 100, n_samples)

    # 5K time estimation (seconds)
    base_5k = pace * 5 * 60 * 0.88  # Race pace ~12% faster than training

    # Adjustments
    volume_adj = -np.clip((weekly_km - 30) / 70, 0, 1) * 120  # More volume = faster
    fitness_adj = -np.clip((70 - rhr) / 30, 0, 1) * 90         # Lower RHR = faster
    hrv_adj = -np.clip((hrv - 40) / 60, 0, 1) * 60             # Higher HRV = faster
    consistency_adj = -np.clip((runs_per_week - 3) / 4, 0, 1) * 45

    t_5k = base_5k + volume_adj + fitness_adj + hrv_adj + consistency_adj
    t_5k += np.random.normal(0, 30, n_samples)
    t_5k = np.clip(t_5k, 720, 2400)  # 12min to 40min range

    X = np.column_stack([weekly_km, pace, runs_per_week, longest_run, rhr, hrv]).astype(np.float32)
    y = t_5k.astype(np.float32)

    return X, y


# ================================================================
# Model Builders
# ================================================================

def build_gait_model() -> tf.keras.Model:
    """Build a lightweight MLP for gait form scoring (regression)."""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(8,), name="gait_input"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(16, activation="relu"),
        tf.keras.layers.Dropout(0.1),
        tf.keras.layers.Dense(1, name="form_score"),
    ], name="gait_form_model")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="mse",
        metrics=["mae"],
    )
    return model


def build_injury_model() -> tf.keras.Model:
    """Build a classifier for injury risk (3 classes: low/moderate/high)."""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(7,), name="injury_input"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(16, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(3, activation="softmax", name="risk_level"),
    ], name="injury_risk_model")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def build_performance_model() -> tf.keras.Model:
    """Build a regression model for race time prediction."""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(6,), name="perf_input"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(16, activation="relu"),
        tf.keras.layers.Dense(1, name="predicted_5k_seconds"),
    ], name="performance_model")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="mse",
        metrics=["mae"],
    )
    return model


# ================================================================
# Training
# ================================================================

def train_model(
    model: tf.keras.Model,
    X_train: np.ndarray,
    y_train: np.ndarray,
    epochs: int = 50,
    batch_size: int = 32,
    validation_split: float = 0.2,
) -> tf.keras.callbacks.History:
    """Train a Keras model with early stopping."""
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            patience=10,
            restore_best_weights=True,
            monitor="val_loss",
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            factor=0.5,
            patience=5,
            min_lr=1e-6,
        ),
    ]

    history = model.fit(
        X_train, y_train,
        epochs=epochs,
        batch_size=batch_size,
        validation_split=validation_split,
        callbacks=callbacks,
        verbose=1,
    )
    return history


# ================================================================
# TFLite Export with Quantization
# ================================================================

def export_tflite(
    model: tf.keras.Model,
    output_path: str,
    representative_data: Optional[np.ndarray] = None,
    quantize: str = "float16",
) -> dict:
    """
    Export a Keras model to TFLite with optional quantization.

    Args:
        model: Trained Keras model
        output_path: Path for .tflite file
        representative_data: Sample data for full integer quantization
        quantize: "none", "float16", "int8", or "dynamic"

    Returns:
        dict with model metadata (size, input/output shapes)
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantize == "float16":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    elif quantize == "dynamic":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
    elif quantize == "int8" and representative_data is not None:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]

        def representative_dataset():
            for i in range(min(200, len(representative_data))):
                yield [representative_data[i:i+1]]

        converter.representative_dataset = representative_dataset
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8

    tflite_model = converter.convert()

    # Save
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    # Get metadata
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    metadata = {
        "path": output_path,
        "size_bytes": len(tflite_model),
        "size_kb": round(len(tflite_model) / 1024, 1),
        "quantization": quantize,
        "input_shape": input_details[0]["shape"].tolist(),
        "input_dtype": str(input_details[0]["dtype"]),
        "output_shape": output_details[0]["shape"].tolist(),
        "output_dtype": str(output_details[0]["dtype"]),
    }

    return metadata


# ================================================================
# TFLite Inference (for testing)
# ================================================================

def run_tflite_inference(model_path: str, input_data: np.ndarray) -> np.ndarray:
    """Run inference on a TFLite model for validation."""
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Handle quantized inputs
    input_dtype = input_details[0]["dtype"]
    if input_dtype == np.uint8:
        input_scale, input_zero = input_details[0]["quantization"]
        input_data = (input_data / input_scale + input_zero).astype(np.uint8)
    else:
        input_data = input_data.astype(np.float32)

    interpreter.set_tensor(input_details[0]["index"], input_data.reshape(1, -1))
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]["index"])

    # Dequantize output
    output_dtype = output_details[0]["dtype"]
    if output_dtype == np.uint8:
        output_scale, output_zero = output_details[0]["quantization"]
        output = (output.astype(np.float32) - output_zero) * output_scale

    return output


# ================================================================
# Normalization Data Export (for on-device use)
# ================================================================

def export_normalization_params(X: np.ndarray, name: str) -> dict:
    """Export mean/std for feature normalization on device."""
    params = {
        "mean": X.mean(axis=0).tolist(),
        "std": X.std(axis=0).tolist(),
    }

    import json
    path = str(MODELS_DIR / f"{name}_norm_params.json")
    with open(path, "w") as f:
        json.dump(params, f, indent=2)

    return params


# ================================================================
# Build All Models
# ================================================================

def build_all_models(epochs: int = 50) -> dict:
    """
    Train and export all 3 TFLite models.

    Returns a summary dict with metadata for each model.
    """
    results = {}

    # ── 1. Gait Form Model ──────────────────────────────────────
    print("\n" + "="*60)
    print("Training Gait Form Analysis Model...")
    print("="*60)
    X_gait, y_gait = generate_gait_training_data()
    gait_model = build_gait_model()
    train_model(gait_model, X_gait, y_gait, epochs=epochs)

    gait_path = str(MODELS_DIR / "gait_form_model.tflite")
    results["gait_form"] = export_tflite(gait_model, gait_path, X_gait, quantize="float16")
    export_normalization_params(X_gait, "gait_form")
    print(f"  → Exported: {gait_path} ({results['gait_form']['size_kb']} KB)")

    # ── 2. Injury Risk Model ────────────────────────────────────
    print("\n" + "="*60)
    print("Training Injury Risk Prediction Model...")
    print("="*60)
    X_injury, y_injury = generate_injury_risk_data()
    injury_model = build_injury_model()
    train_model(injury_model, X_injury, y_injury, epochs=epochs)

    injury_path = str(MODELS_DIR / "injury_risk_model.tflite")
    results["injury_risk"] = export_tflite(injury_model, injury_path, X_injury, quantize="float16")
    export_normalization_params(X_injury, "injury_risk")
    print(f"  → Exported: {injury_path} ({results['injury_risk']['size_kb']} KB)")

    # ── 3. Performance Prediction Model ─────────────────────────
    print("\n" + "="*60)
    print("Training Performance Prediction Model...")
    print("="*60)
    X_perf, y_perf = generate_performance_data()
    perf_model = build_performance_model()
    train_model(perf_model, X_perf, y_perf, epochs=epochs)

    perf_path = str(MODELS_DIR / "performance_model.tflite")
    results["performance"] = export_tflite(perf_model, perf_path, X_perf, quantize="float16")
    export_normalization_params(X_perf, "performance")
    print(f"  → Exported: {perf_path} ({results['performance']['size_kb']} KB)")

    # ── Summary ─────────────────────────────────────────────────
    print("\n" + "="*60)
    print("BUILD COMPLETE — TFLite Models Ready for Deployment")
    print("="*60)
    total_kb = sum(r["size_kb"] for r in results.values())
    print(f"  Total size: {total_kb} KB ({round(total_kb/1024, 2)} MB)")
    print(f"  Models dir: {MODELS_DIR}")
    for name, meta in results.items():
        print(f"  • {name}: {meta['size_kb']} KB | input={meta['input_shape']} | quant={meta['quantization']}")

    return results


if __name__ == "__main__":
    build_all_models(epochs=50)
