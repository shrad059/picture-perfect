import coremltools as ct
import tensorflow as tf

def convert_model(model_path, output_path):
    """
    Convert a TensorFlow/Keras model to Core ML format and save it.

    Parameters:
    model_path (str): Path to the TensorFlow/Keras model file.
    output_path (str): Path to save the converted Core ML model file.
    """
    # Load your TensorFlow/Keras model
    model = tf.keras.models.load_model(model_path)
    
    # Convert the TensorFlow/Keras model to Core ML
    coreml_model = ct.convert(
        model,
        source='tensorflow',
        convert_to='neuralnetwork',  # Use 'neuralnetwork' for .mlmodel format
        minimum_deployment_target=ct.target.iOS14,  # Adjust if needed
        inputs=[ct.ImageType(shape=(1, 28, 28, 1))]  # Specify the input shape
    )
    
    # Save the Core ML model
    coreml_model.save(output_path)

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python coreML.py <model_path> <output_path>")
        sys.exit(1)
    
    model_path = sys.argv[1]
    output_path = sys.argv[2]
    
    convert_model(model_path, output_path)
