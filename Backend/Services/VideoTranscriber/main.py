import os
import boto3
import logging
import subprocess
from faster_whisper import WhisperModel

# AWS Clients
s3_client = boto3.client("s3")

# Logger Configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

formatter = logging.Formatter(
    fmt="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
if not logger.handlers:
    console = logging.StreamHandler()
    console.setFormatter(formatter)
    logger.addHandler(console)

# Constants
BUCKET_NAME = "minute-maker-resources"
INPUT_PREFIX = "input/"
MODEL_PREFIX = "models/"
OUTPUT_PREFIX = "intermediate/"
TMP_DIR = "/tmp"
MODEL_DIR = os.path.join(TMP_DIR, "faster-whisper")
FFMPEG_PATH = os.path.join(MODEL_DIR, "ffmpeg")


def download_from_s3(prefix, local_dir):
    logger.info(f"Starting download from s3://{BUCKET_NAME}/{prefix} to {local_dir}")
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue  # skip folders
            local_path = os.path.join(local_dir, os.path.relpath(key, prefix))
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            s3_client.download_file(BUCKET_NAME, key, local_path)
            logger.info(f"Downloaded: {key} to {local_path}")
    logger.info("Model and dependencies downloaded successfully.")


def ensure_ffmpeg(model_dir):
    ffmpeg_exec = os.path.join(model_dir, "ffmpeg")
    if not os.path.isfile(ffmpeg_exec):
        logger.error("FFmpeg binary not found in model directory.")
        raise FileNotFoundError("FFmpeg binary not found.")
    os.chmod(ffmpeg_exec, 0o755)
    os.environ["PATH"] = f"{model_dir}:{os.environ['PATH']}"
    logger.info("FFmpeg setup completed and executable path updated.")


def lambda_handler(event, context):
    input_path = ""
    output_path = ""
    try:
        logger.info("Lambda execution started.")

        # 1. Parse S3 event
        key = event['Records'][0]['s3']['object']['key']
        logger.info(f"Triggered by file: {key}")

        if not key.startswith(INPUT_PREFIX):
            logger.warning("Event file not in input/ folder. Ignoring.")
            return

        file_name = os.path.basename(key)
        input_path = os.path.join(TMP_DIR, file_name)

        # 2. Download input video
        logger.info("Downloading video file...")
        s3_client.download_file(BUCKET_NAME, key, input_path)
        logger.info(f"Downloaded video: {input_path}")

        # 3. Download model and ffmpeg from S3
        download_from_s3(MODEL_PREFIX, MODEL_DIR)

        # 4. Setup FFmpeg
        ensure_ffmpeg(MODEL_DIR)

        # 5. Transcribe
        logger.info("Starting transcription with Faster-Whisper...")
        model = WhisperModel(MODEL_DIR, compute_type="int8")
        segments, _ = model.transcribe(input_path)

        transcript = "\n".join([f"{seg.start:.2f}-{seg.end:.2f}: {seg.text}" for seg in segments])
        output_file_name = f"{os.path.splitext(file_name)[0]}.txt"
        output_path = os.path.join(TMP_DIR, output_file_name)

        with open(output_path, "w") as f:
            f.write(transcript)

        # 6. Upload transcript
        output_key = f"{OUTPUT_PREFIX}{output_file_name}"
        logger.info(f"Uploading transcript to s3://{BUCKET_NAME}/{output_key}")
        s3_client.upload_file(output_path, BUCKET_NAME, output_key)
        logger.info("Transcript successfully uploaded.")

    except Exception as e:
        logger.error(f"Exception occurred: {e}", exc_info=True)
    finally:
        # 7. Cleanup temp files
        for path in [input_path, output_path, MODEL_DIR]:
            if os.path.exists(path):
                subprocess.call(["rm", "-rf", path])
                logger.info(f"Cleaned: {path}")

        logger.info("Lambda execution completed.")
