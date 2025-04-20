FROM public.ecr.aws/lambda/python:3.11

# Set the working directory for Lambda to find code and dependencies
WORKDIR /var/task

# Install Python dependencies into /var/task
COPY requirements.txt .
RUN pip install -r requirements.txt --target .

# Copy only the handler code
COPY main.py .

# Lambda will run this handler function
CMD ["main.lambda_handler"]
