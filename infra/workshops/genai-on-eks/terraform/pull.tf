# We use the kubectl provider here because:
# 1. Its one less provider and the kubectl provider is already in use elsewhere
# 2. The Kubernetes provider is problematic, wanting to reach out to the API server
#    quite earlier in the process and usually fails, plus it does not support retries
#    which the kubectl provider does (making it more resilient to transient issues)
# 3. Its easier to copy+paste the YAML body and deploy directly, outside of Terraform

################################################################################
# Download model from Mistral CDN and upload to S3 bucket
# This:
# 1. Avoids the need for dealing with HuggingFace API tokens
# 2. Pre-pulls the image during account provisioning which avoids this
#    time penalty during the workshop event
# 3. Uses S3 for scalable, cost-effective model storage
# 4. Leverages EKS Pod Identity for secure S3 access
################################################################################
resource "kubectl_manifest" "job_model_download" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    kubectl_manifest.model_storage_service_account,
    aws_eks_pod_identity_association.model_storage,
    aws_s3_bucket.model_storage
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: model-download
    spec:
      backoffLimit: 10
      activeDeadlineSeconds: 3600  # 1 hour timeout
      completionMode: NonIndexed
      completions: 1
      template:
        spec:
          initContainers:
            - name: validate-pod-identity
              image: public.ecr.aws/aws-cli/aws-cli:latest
              command: ['/bin/sh', '-c']
              args:
                - |
                  set -e
                  
                  echo 'Checking Pod Identity...'
                  EXPECTED_ROLE="genai-model-storage-role"
                  CURRENT_ROLE=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2 2>/dev/null || echo "unknown")
                  
                  echo "Expected role: $EXPECTED_ROLE"
                  echo "Current role: $CURRENT_ROLE"
                  
                  if [ "$CURRENT_ROLE" != "$EXPECTED_ROLE" ]; then
                    echo "ERROR: Pod Identity not working. Using node role instead of Pod Identity role."
                    echo "Pod will be recreated to retry Pod Identity association."
                    exit 1
                  fi
                  
                  echo "Pod Identity verified successfully!"
            - name: download
              image: public.ecr.aws/ubuntu/ubuntu:22.04
              command: ['/bin/bash', '-c']
              args:
                - |
                  set -e
                  set -o pipefail
                  
                  echo 'Installing required packages...'
                  export DEBIAN_FRONTEND=noninteractive
                  export TZ=UTC
                  apt-get update -qq
                  apt-get install -y -qq curl unzip tar
                  
                  echo 'Starting model download process...'
                  
                  # Function for retrying commands with exponential backoff
                  retry_with_backoff() {
                    local max_attempts=3
                    local delay=1
                    local attempt=1
                    
                    while [ $$attempt -le $$max_attempts ]; do
                      if "$$@"; then
                        return 0
                      else
                        echo "Attempt $$attempt failed. Retrying in $${delay}s..." >&2
                        sleep $$delay
                        delay=$$((delay * 2))
                        attempt=$$((attempt + 1))
                      fi
                    done
                    
                    echo "All $$max_attempts attempts failed." >&2
                    return 1
                  }
                  
                  # Create shared directory for model files
                  SHARED_DIR=/shared/mistral-7b-v0-3
                  mkdir -p $$SHARED_DIR
                  
                  # Download Mistral model from CDN with retry
                  echo 'Downloading Mistral model from CDN...'
                  retry_with_backoff curl -sL --fail --connect-timeout 30 --max-time 1800 \
                    https://models.mistralcdn.com/mistral-7b-v0-3/mistral-7B-Instruct-v0.3.tar \
                    -o /tmp/mistral-model.tar
                  
                  tar -xv --directory=$$SHARED_DIR/ -f /tmp/mistral-model.tar
                  rm -f /tmp/mistral-model.tar
                  
                  # Download tokenizer files with retry
                  echo 'Downloading tokenizer files...'
                  retry_with_backoff curl -sL --fail --connect-timeout 30 --max-time 300 \
                    https://ws-assets-prod-iad-r-iad-ed304a55c2ca1aee.s3.us-east-1.amazonaws.com/029d6c4e-4775-41c9-85ff-9f5360f32a15/mistral-tokenizer.zip \
                    -o /tmp/mistral-tokenizer.zip
                  
                  unzip /tmp/mistral-tokenizer.zip -d /tmp/
                  cp -r /tmp/*.json /tmp/*.model $$SHARED_DIR/
                  rm -rf /tmp/mistral-tokenizer.zip
                  
                  # Verify downloaded files exist
                  echo 'Verifying downloaded files...'
                  [ -f "$$SHARED_DIR/consolidated.safetensors" ] || { echo 'Error: consolidated.safetensors not found'; exit 1; }
                  [ -f "$$SHARED_DIR/config.json" ] || { echo 'Error: config.json not found'; exit 1; }
                  [ -f "$$SHARED_DIR/tokenizer.json" ] || { echo 'Error: tokenizer.json not found'; exit 1; }
                  echo 'All required files downloaded successfully to shared volume'
              volumeMounts:
                - name: shared-data
                  mountPath: /shared
              securityContext:
                allowPrivilegeEscalation: false
                runAsUser: 0
          containers:
            - name: upload
              image: public.ecr.aws/aws-cli/aws-cli:latest
              command: ['/bin/sh', '-c']
              env:
                - name: S3_BUCKET_NAME
                  value: "${aws_s3_bucket.model_storage.bucket}"
              args:
                - |
                  set -e
                  set -o pipefail
                  
                  echo 'Starting S3 upload process...'
                  
                  # Function for retrying commands with exponential backoff
                  retry_with_backoff() {
                    local max_attempts=3
                    local delay=1
                    local attempt=1
                    
                    while [ $$attempt -le $$max_attempts ]; do
                      if "$$@"; then
                        return 0
                      else
                        echo "Attempt $$attempt failed. Retrying in $${delay}s..." >&2
                        sleep $$delay
                        delay=$$((delay * 2))
                        attempt=$$((attempt + 1))
                      fi
                    done
                    
                    echo "All $$max_attempts attempts failed." >&2
                    return 1
                  }
                  
                  # Use S3 bucket name from environment variable
                  echo "Using S3 bucket: $$S3_BUCKET_NAME"
                  
                  # Test S3 access
                  echo 'Testing S3 access...'
                  aws s3 ls "s3://$$S3_BUCKET_NAME/" || { echo 'Error: Cannot access S3 bucket'; exit 1; }
                  
                  # Upload files to S3 with retry logic
                  echo 'Uploading model files to S3...'
                  SHARED_DIR=/shared/mistral-7b-v0-3
                  upload_failed=false
                  
                  for file in $$SHARED_DIR/*; do
                    if [ -f "$$file" ]; then
                      filename=$$(basename "$$file")
                      echo "Uploading $$filename..."
                      if ! retry_with_backoff aws s3 cp "$$file" "s3://$$S3_BUCKET_NAME/mistral-7b-v0-3/$$filename" --no-progress; then
                        echo "Error: Failed to upload $$filename" >&2
                        upload_failed=true
                      else
                        echo "Successfully uploaded $$filename"
                      fi
                    fi
                  done
                  
                  # Check if any uploads failed
                  if [ "$$upload_failed" = "true" ]; then
                    echo 'Error: One or more file uploads failed' >&2
                    exit 1
                  fi
                  
                  # Verify upload by listing S3 objects
                  echo 'Verifying S3 upload...'
                  retry_with_backoff aws s3 ls "s3://$$S3_BUCKET_NAME/mistral-7b-v0-3/" --human-readable --summarize
                  
                  # Verify critical files exist with retry
                  echo 'Checking for critical model files...'
                  retry_with_backoff aws s3api head-object --bucket "$$S3_BUCKET_NAME" --key "mistral-7b-v0-3/consolidated.safetensors" > /dev/null
                  retry_with_backoff aws s3api head-object --bucket "$$S3_BUCKET_NAME" --key "mistral-7b-v0-3/config.json" > /dev/null
                  retry_with_backoff aws s3api head-object --bucket "$$S3_BUCKET_NAME" --key "mistral-7b-v0-3/tokenizer.json" > /dev/null
                  echo 'All critical files verified in S3'
                  
                  echo 'Model download and S3 upload completed successfully!'
              volumeMounts:
                - name: shared-data
                  mountPath: /shared
              securityContext:
                allowPrivilegeEscalation: false
          volumes:
            - name: shared-data
              emptyDir: {}
          restartPolicy: Never
          serviceAccountName: model-storage-sa
  YAML
}
