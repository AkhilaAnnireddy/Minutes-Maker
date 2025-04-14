# Use the official AWS Lambda Python 3.11 base image
FROM public.ecr.aws/lambda/python:3.11

# Set working directory
WORKDIR /tmp

# Install system-level dependencies (ffmpeg)
RUN yum -y update && \
    yum -y install \
    ffmpeg \
    gcc \
    git \
    wget \
    xz && \
    yum clean all

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy your function code
COPY . .

# Set entry point (lambda handler)
CMD ["main.lambda_handler"]
