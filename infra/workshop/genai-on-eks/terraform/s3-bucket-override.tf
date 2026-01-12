locals {
  s3_bucket_name_with_account = "${var.s3_models_bucket_name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "models_bucket_override" {
  count         = var.enable_s3_models_storage && var.s3_models_bucket_create ? 1 : 0
  bucket        = local.s3_bucket_name_with_account
  force_destroy = true

  tags = merge(local.tags, {
    Purpose = "ML Model Storage"
  })

  lifecycle {
    ignore_changes = [bucket]
  }
}
