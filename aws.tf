provider "aws" {
    region = "us-west-2"
    access_key = "AKIAIBAOMVHPGXGFVUOQ"
    secret_key = "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"
}

resource "aws_key_pair" "prasath" {
  key_name = "prasath"
  public_key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx0Jf1esX92CKy8ue88VJ5LK/PCHWvz8JMHpgS8lOIfFj3wIjxs418Ty9uVHsDjST19oSldFbgjGJCE9GyI57tuDCvh8Iesoitb8lLFioFmHcl9nDu378Ts5sbAOQyJa5Ec2Br/xIu2w8XAhz5FwczXrtdNCNhh9WzpgfM1Vy6wr/Mrtv3B1f2yc4ajEcvDtPiHlHaDWjlCYcdQ3MPf/rhjOOmwekDyzxlzObOxt0hXJ4vac9wtnUbNNXrQ2E9HoYeHFZtqWvU31108XXtBtFKh/GAhiDitVT4lnKQvcKDukvp8HXsuTROSnSRLcFAPJEmxo4DykPyolJdy3VhlMa1QIDAQAB"
}

resource "aws_instance" "example" {
    ami = "ami-6e1a0117"
    instance_type = "t2.micro"
    tags {
       Name = "Terraform"
}
}
