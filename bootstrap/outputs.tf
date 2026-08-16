output "state_bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "state_kms_key_arn" {
  value = aws_kms_key.tfstate.arn
}