# Import necessary libraries
import streamlit as st
import sys
from sentence_transformers import SentenceTransformer

# Load the pre-trained model
model_id = "BAAI/bge-small-en"
model = SentenceTransformer(model_id)

# Define a function to get embeddings
def get_embeddings(text):
    return model.encode(text, convert_to_tensor=True)

# Create a Streamlit web interface
st.title("Sentence Embeddings Web Interface")
st.write("Enter a sentence to get its embedding:")

# User input
input_text = st.text_input("Enter a sentence")

if input_text:
    # Get embeddings and display
    embeddings = get_embeddings(input_text)
    st.write("Embeddings:")
    st.write(embeddings)

if __name__ == "__main__":
    # Remove the CWD from sys.path while we load stuff.
    # This is added back by InteractiveShellApp.init_path()
    if sys.path[0] == "":  # noqa
        del sys.path[0]

    from ipykernel import kernelapp as app

    app.launch_new_instance()
