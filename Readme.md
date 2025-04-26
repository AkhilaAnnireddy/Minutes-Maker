# Minutes Maker – Video Transcription and Summarization Pipeline

Welcome! 🎉  
This project automatically takes uploaded meeting videos, transcribes them using a Whisper model, and summarizes them into clean minutes of meeting — all built using AWS Serverless architecture.

---

## 🚀 Project Architecture

- **Frontend**: User uploads a video file via API Gateway.
- **Upload Lambda**:

  - Uploads the video to **S3 Input Bucket**.
  - Sends a notification to **SQS Queue**.

- **Video Transcriber Lambda** (Dockerized):

  - Triggered by SQS.
  - Downloads the video and Whisper model files from S3.
  - Transcribes the audio using Faster-Whisper.
  - Uploads the transcript text to an Intermediate S3 Bucket.
  - Sends another notification to the Summarizer queue.

- **Summarizer Lambda**:
  - (Coming soon!) It reads the transcript and generates final meeting minutes.

---

## 🛠 Tech Stack

- **AWS Services**:  
  S3, Lambda, API Gateway, SQS, CloudWatch, ECR, IAM, Terraform
- **Languages & Tools**:  
  Python, Docker, GitHub Actions (CI/CD), Terraform (IaC)

---

## 🧠 How Deployment Works

1. Code changes pushed to GitHub (especially inside `Backend/Services/VideoTranscriber/`).
2. GitHub Actions automatically:
   - Builds the Docker image for Transcriber Lambda.
   - Pushes the image to ECR (Elastic Container Registry).
   - Runs Terraform to:
     - Detect changes
     - Redeploy the Lambda with the new Docker image

✅ No manual deployment needed after pushing code!

---

## ⚙️ Project Folders

| Folder                               | Purpose                                                              |
| :----------------------------------- | :------------------------------------------------------------------- |
| `Backend/Services/VideoUploader/`    | Code for Upload Lambda (Python, zipped upload)                       |
| `Backend/Services/VideoTranscriber/` | Code for Transcriber Lambda (Dockerized, Whisper model)              |
| `Infrastructure/`                    | Terraform code for infrastructure setup (Lambda, SQS, S3, IAM, etc.) |

---

## 🔥 Quick Commands (Manual)

When needed manually:

```bash
# Build and Push Docker Image
cd Backend/Services/VideoTranscriber
docker build -t minute-maker-video-transcriber:latest .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-ecr-url>
docker tag minute-maker-video-transcriber:latest <your-ecr-url>:latest
docker push <your-ecr-url>:latest

# Deploy Infrastructure
cd Infrastructure
terraform init
terraform plan
terraform apply
```
