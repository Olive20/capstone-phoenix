terraform {
   required_version = ">= 1.11"

   backend "s3" {
     bucket         = "phoenix-tfstate-2b08529f"
     key            = "phoenix/terraform.tfstate"
     region         = "eu-north-1"
     encrypt        = true
     use_lockfile   = true
   }   
}