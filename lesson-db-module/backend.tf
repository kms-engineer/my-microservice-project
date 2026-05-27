terraform {
  backend "s3" {
    bucket         = "mykyta-terraform-state-bucket"
    key            = "lesson-db-module/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
