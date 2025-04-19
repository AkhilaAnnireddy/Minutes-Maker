import json
import boto3
import base64
import uuid
import os
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3 = boto3.client("s3")
sqs = boto3.client("sqs")

# Environment variables
BUCKET_NAME = os.environ.get("BUCKET_NAME")
S3_FOLDER = os.environ.get("S3_FOLDER", "input/")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")

def lambda_handler(event, context):
    try:
        logger.info("Lambda triggered with event metadata: %s", json.dumps(event.get("headers", {})))

        # Step 1: Get base64-encoded file content from API Gateway
        file_data = event["body"]
        if event.get("isBase64Encoded", False):
            file_data = base64.b64decode(file_data)
            logger.info("Received base64-encoded file and successfully decoded.")
        else:
            file_data = file_data.encode("utf-8")
            logger.info("Received plain text data, encoded to bytes.")

        # Step 2: Generate a unique filename
        filename = f"meeting_{uuid.uuid4()}.mp4"
        s3_key = f"{S3_FOLDER}{filename}"
        logger.info(f"Generated S3 key: {s3_key}")

        # Step 3: Upload file to S3
        s3.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=file_data)
        logger.info(f"Successfully uploaded to s3://{BUCKET_NAME}/{s3_key}")

        # Step 4: Notify SQS for transcription
        message_body = json.dumps({"s3_key": s3_key})
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=message_body
        )
        logger.info(f"Message sent to SQS with MessageId: {response['MessageId']}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "File uploaded and queued successfully.",
                "filename": filename,
                "s3_key": s3_key
            })
        }

    except Exception as e:
        logger.error("Error occurred during Lambda execution", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
