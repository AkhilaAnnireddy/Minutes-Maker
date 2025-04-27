import os
import json
import boto3
import logging
import zipfile
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3 = boto3.client("s3")

# Environment variables
MODEL_BUCKET = os.environ["MODEL_BUCKET"]
MODEL_ZIP_KEY = os.environ["MODEL_ZIP_KEY"]
INTERMEDIATE_BUCKET = os.environ["INTERMEDIATE_BUCKET"]
OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
TMP_DIR = "/tmp"

# File paths
MODEL_DIR = os.path.join(TMP_DIR, "summarizer-model")
MODEL_ZIP_PATH = os.path.join(TMP_DIR, "summarizer-models.zip")
TRANSCRIPT_PATH = os.path.join(TMP_DIR, "transcript.txt")

def download_file(bucket, key, destination):
    logger.info(f"Downloading s3://{bucket}/{key} -> {destination}")
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    s3.download_file(bucket, key, destination)

def upload_file(source, bucket, key):
    logger.info(f"Uploading {source} -> s3://{bucket}/{key}")
    s3.upload_file(source, bucket, key)

def unzip_model(zip_path, extract_dir):
    logger.info(f"Unzipping model from {zip_path} to {extract_dir}")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)

def generate_minutes(transcript_text):
    logger.info("Loading tokenizer and model from local directory...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_DIR)

    prompt = f"Summarize this meeting transcript into clear bullet points:\n\n{transcript_text}"
    inputs = tokenizer(prompt, return_tensors="pt", truncation=True)

    logger.info("Generating summary using FLAN-T5...")
    outputs = model.generate(**inputs, max_length=512)
    summary = tokenizer.decode(outputs[0], skip_special_tokens=True)

    return summary

def lambda_handler(event, context):
    try:
        logger.info(f"Lambda triggered with event: {json.dumps(event)}")

        # Step 1: Parse transcript key from SQS event
        body = json.loads(event["Records"][0]["body"])
        transcript_key = body["transcript_key"]
        logger.info(f"Processing transcript file: {transcript_key}")

        # Step 2: Download transcript
        download_file(INTERMEDIATE_BUCKET, transcript_key, TRANSCRIPT_PATH)

        # Step 3: Download and unzip model only if not already present
        if not os.path.exists(MODEL_DIR):
            logger.info(f"Model directory not found at {MODEL_DIR}. Downloading model zip...")
            download_file(MODEL_BUCKET, MODEL_ZIP_KEY, MODEL_ZIP_PATH)
            unzip_model(MODEL_ZIP_PATH, MODEL_DIR)
        else:
            logger.info(f"Model directory already exists at {MODEL_DIR}. Skipping model download.")

        # Step 4: Read transcript
        with open(TRANSCRIPT_PATH, "r") as f:
            transcript_text = f.read()

        # Step 5: Summarize
        summary = generate_minutes(transcript_text)

        # Step 6: Save output file
        output_key = transcript_key.replace(".txt", "_minutes.txt")
        output_local_path = os.path.join(TMP_DIR, os.path.basename(output_key))
        
        with open(output_local_path, "w") as f:
            f.write(summary)

        # Step 7: Upload summarized minutes
        upload_file(output_local_path, OUTPUT_BUCKET, output_key)

        logger.info(f"Summarization complete. Minutes saved to {OUTPUT_BUCKET}/{output_key}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Summarization complete",
                "output_key": output_key
            })
        }

    except Exception as e:
        logger.error("Error during Lambda execution", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
