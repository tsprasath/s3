provider "aws" {
    region = "us-west-2"
    access_key = "AKIAIBAOMVHPGXGFVUOQ"
    secret_key = "aT9j3KvhwAE91lnNO9cMNg1w4CU9htBzpnT92TnJ"
}


resource "aws_instance" "example" {
    ami = "ami-6e1a0117"
    instance_type = "t2.micro"
    tags {
       Name = "Terraform"
}
}
