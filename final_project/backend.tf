terraform {
  backend "s3" {
    bucket         = "mykyta-final-project-state"
    key            = "final_project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "final-project-locks"
    encrypt        = true
  }
}
