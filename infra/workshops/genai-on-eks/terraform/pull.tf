# We use the kubectl provider here because:
# 1. Its one less provider and the kubectl provider is already in use elsewhere
# 2. The Kubernetes provider is problematic, wanting to reach out to the API server
#    quite earlier in the process and usually fails, plus it does not support retries
#    which the kubectl provider does (making it more resilient to transient issues)
# 3. Its easier to copy+paste the YAML body and deploy directly, outside of Terraform

################################################################################
# Download model from HuggingFace and upload to S3 bucket
# This:
# 1. Downloads directly from HuggingFace Hub
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
      backoffLimit: 3
      activeDeadlineSeconds: 7200
      template:
        spec:
          serviceAccountName: model-storage-sa
          restartPolicy: Never
          containers:
          - name: downloader
            image: python:3.11-slim
            command: ["/bin/bash", "-c"]
            args:
            - |
              set -e
              pip install -q huggingface_hub boto3
              
              echo "Downloading Mistral-7B-Instruct-v0.3 from HuggingFace..."
              python3 -c "from huggingface_hub import snapshot_download; snapshot_download('mistralai/Mistral-7B-Instruct-v0.3', local_dir='/tmp/mistral-7b')"
              
              echo "Uploading to S3 bucket: ${aws_s3_bucket.model_storage.bucket}"
              python3 << 'EOF'
              import boto3
              import os
              from pathlib import Path
              
              s3 = boto3.client('s3')
              bucket = "${aws_s3_bucket.model_storage.bucket}"
              local_dir = Path("/tmp/mistral-7b")
              
              for file_path in local_dir.rglob("*"):
                  if file_path.is_file():
                      s3_key = f"mistral-7b-v0-3/{file_path.relative_to(local_dir)}"
                      print(f"Uploading {file_path.name}...")
                      s3.upload_file(str(file_path), bucket, s3_key)
              
              print("Upload complete!")
              EOF
            resources:
              requests:
                memory: "4Gi"
                cpu: "2"
              limits:
                memory: "8Gi"
                cpu: "4"
  YAML
}
