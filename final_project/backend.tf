terraform {
  backend "s3" {
    bucket         = "mykyta-terraform-state-bucket"
    key            = "final_project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
