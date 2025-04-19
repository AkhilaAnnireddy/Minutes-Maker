import json
import boto3
import base64
import uuid
import os

s3 = boto3.client("s3")
sqs = boto3.client("sqs")

# These will be provided as Lambda environment variables
BUCKET_NAME = "minute-maker-resources"
S3_FOLDER = "input/"
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")

def lambda_handler(event, context):
    try:
        # Extract and decode file from API Gateway payload
        file_data = event["body"]
        if event.get("isBase64Encoded"):
            file_data = base64.b64decode(file_data)
        else:
            file_data = file_data.encode("utf-8")

        # Create a unique filename
        filename = f"meeting_{uuid.uuid4()}.mp4"
        s3_key = f"{S3_FOLDER}{filename}"

        # Upload video to S3
        s3.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=file_data)

        # Send filename to transcription queue
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({"s3_key": s3_key})
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "File uploaded successfully.",
                "filename": filename,
                "s3_key": s3_key
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
